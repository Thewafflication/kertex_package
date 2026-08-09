#!/usr/bin/env python3
"""Compare representative WSP PDF pages while tolerating rasterizer noise."""

import argparse
import difflib
import json
import re
import unicodedata
from pathlib import Path

import pypdfium2 as pdfium
from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageStat
from pypdf import PdfReader


REPRESENTATIVE_PAGES = {
    "title": 1,
    "toc-early": 2,
    "toc-last": 9,
    "chapter-opening": 10,
    "table-heavy": 11,
    "colored-links": 19,
    "code-heavy": 96,
}

LIGATURES = str.maketrans({"ﬀ": "ff", "ﬁ": "fi", "ﬂ": "fl", "ﬃ": "ffi", "ﬄ": "ffl"})


def normalized_text(text: str) -> str:
    text = unicodedata.normalize("NFKC", text.translate(LIGATURES))
    return re.sub(r"\s+", "", text).casefold()


def render_page(document: pdfium.PdfDocument, page_number: int) -> Image.Image:
    page = document[page_number - 1]
    return page.render(scale=2.0, rev_byteorder=True).to_pil().convert("RGB")


def ink_bbox(image: Image.Image):
    gray = image.convert("L")
    mask = gray.point(lambda value: 255 if value < 245 else 0)
    return mask.getbbox()


def colored_pixel_count(image: Image.Image) -> int:
    return sum(
        1
        for red, green, blue in image.get_flattened_data()
        if max(red, green, blue) - min(red, green, blue) > 20
        and min(red, green, blue) < 230
    )


def base_fonts(reader: PdfReader):
    result = set()
    for page in reader.pages:
        resources = page.get("/Resources")
        if not resources or "/Font" not in resources:
            continue
        for font in resources["/Font"].get_object().values():
            font = font.get_object()
            name = str(font.get("/BaseFont", "unknown"))
            result.add(re.sub(r"^/[A-Z]{6}\+", "", name))
    return sorted(result)


def compare(args):
    reference_path = Path(args.reference).resolve()
    candidate_path = Path(args.candidate).resolve()
    output_path = Path(args.output).resolve()
    diff_directory = Path(args.diff_directory).resolve()
    diff_directory.mkdir(parents=True, exist_ok=True)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    reference_reader = PdfReader(str(reference_path))
    candidate_reader = PdfReader(str(candidate_path))
    reference_pdf = pdfium.PdfDocument(str(reference_path))
    candidate_pdf = pdfium.PdfDocument(str(candidate_path))
    if len(reference_reader.pages) != len(candidate_reader.pages):
        raise RuntimeError(
            f"page-count mismatch: {len(reference_reader.pages)} != {len(candidate_reader.pages)}"
        )

    failures = []
    page_results = []
    for role, page_number in REPRESENTATIVE_PAGES.items():
        reference = render_page(reference_pdf, page_number)
        candidate = render_page(candidate_pdf, page_number)
        if reference.size != candidate.size:
            failures.append(f"page {page_number} size differs: {reference.size} != {candidate.size}")
            continue

        difference = ImageChops.difference(reference, candidate)
        difference_gray = difference.convert("L")
        mean_difference = ImageStat.Stat(difference_gray).mean[0] / 255.0
        threshold_mask = difference_gray.point(lambda value: 255 if value > 32 else 0)
        changed_fraction = ImageStat.Stat(threshold_mask).mean[0] / 255.0
        blurred_difference = ImageChops.difference(
            reference.filter(ImageFilter.GaussianBlur(0.75)),
            candidate.filter(ImageFilter.GaussianBlur(0.75)),
        ).convert("L")
        blurred_mean_difference = ImageStat.Stat(blurred_difference).mean[0] / 255.0

        reference_bbox = ink_bbox(reference)
        candidate_bbox = ink_bbox(candidate)
        bbox_delta = max(
            abs(left - right)
            for left, right in zip(reference_bbox or (0, 0, 0, 0), candidate_bbox or (0, 0, 0, 0))
        )
        reference_text = normalized_text(reference_reader.pages[page_number - 1].extract_text() or "")
        candidate_text = normalized_text(candidate_reader.pages[page_number - 1].extract_text() or "")
        text_similarity = difflib.SequenceMatcher(
            None, reference_text, candidate_text, autojunk=False
        ).ratio()
        reference_colored = colored_pixel_count(reference)
        candidate_colored = colored_pixel_count(candidate)
        colored_fraction_delta = (
            abs(reference_colored - candidate_colored) / reference_colored
            if reference_colored
            else 0.0
        )

        enhanced = ImageEnhance.Contrast(difference).enhance(4.0)
        enhanced.save(diff_directory / f"{page_number:03d}-{role}.png")
        result = {
            "role": role,
            "page": page_number,
            "pixels": list(reference.size),
            "meanDifference": round(mean_difference, 8),
            "blurredMeanDifference": round(blurred_mean_difference, 8),
            "changedFraction": round(changed_fraction, 8),
            "textSimilarity": round(text_similarity, 8),
            "referenceInkBounds": reference_bbox,
            "candidateInkBounds": candidate_bbox,
            "maxInkBoundsDelta": bbox_delta,
            "referenceColoredPixels": reference_colored,
            "candidateColoredPixels": candidate_colored,
            "coloredPixelFractionDelta": round(colored_fraction_delta, 8),
        }
        page_results.append(result)
        if not args.report_only:
            if mean_difference > args.max_mean_difference:
                failures.append(f"page {page_number} mean difference {mean_difference:.6f}")
            if blurred_mean_difference > args.max_blurred_mean_difference:
                failures.append(
                    f"page {page_number} blurred mean difference {blurred_mean_difference:.6f}"
                )
            if changed_fraction > args.max_changed_fraction:
                failures.append(f"page {page_number} changed fraction {changed_fraction:.6f}")
            if text_similarity < args.min_text_similarity:
                failures.append(f"page {page_number} text similarity {text_similarity:.6f}")
            if bbox_delta > args.max_ink_bounds_delta:
                failures.append(f"page {page_number} ink bounds delta {bbox_delta}")
            if reference_colored > 100 and colored_fraction_delta > args.max_colored_fraction_delta:
                failures.append(
                    f"page {page_number} colored-pixel fraction delta {colored_fraction_delta:.6f}"
                )

    reference_fonts = base_fonts(reference_reader)
    candidate_fonts = base_fonts(candidate_reader)
    if not args.report_only and reference_fonts != candidate_fonts:
        failures.append("embedded font inventories differ")

    report = {
        "reference": str(reference_path),
        "candidate": str(candidate_path),
        "pageCount": len(reference_reader.pages),
        "representativePages": page_results,
        "referenceFonts": reference_fonts,
        "candidateFonts": candidate_fonts,
        "tolerances": {
            "maxMeanDifference": args.max_mean_difference,
            "maxBlurredMeanDifference": args.max_blurred_mean_difference,
            "maxChangedFraction": args.max_changed_fraction,
            "minTextSimilarity": args.min_text_similarity,
            "maxInkBoundsDelta": args.max_ink_bounds_delta,
            "maxColoredFractionDelta": args.max_colored_fraction_delta,
        },
        "failures": failures,
    }
    output_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if failures:
        raise RuntimeError("visual comparison failed: " + "; ".join(failures))
    print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("reference")
    parser.add_argument("candidate")
    parser.add_argument("--output", default="out/wsp-visual/visual-report.json")
    parser.add_argument("--diff-directory", default="out/wsp-visual/diffs")
    parser.add_argument("--max-mean-difference", type=float, default=0.023)
    parser.add_argument("--max-blurred-mean-difference", type=float, default=0.016)
    parser.add_argument("--max-changed-fraction", type=float, default=0.060)
    parser.add_argument("--min-text-similarity", type=float, default=0.989)
    parser.add_argument("--max-ink-bounds-delta", type=int, default=3)
    parser.add_argument("--max-colored-fraction-delta", type=float, default=0.03)
    parser.add_argument("--report-only", action="store_true")
    compare(parser.parse_args())


if __name__ == "__main__":
    main()
