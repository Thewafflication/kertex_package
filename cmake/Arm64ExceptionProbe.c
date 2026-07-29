/*
 * ARM64 TinyCC crash probe for the generated TeX entry point.
 *
 * Keep this independent of WCRT: an exception in the C runtime must still
 * produce an address that can be matched against a locally built image.
 */
#include <winapi/windows.h>

extern int kertex_tex_main(int argc, char **argv);

static char *
append_text(char *output, const char *text)
{
	while (*text != '\0')
		*output++ = *text++;
	return output;
}

static char *
append_hex(char *output, DWORD64 value, unsigned int digits)
{
	static const char hex[] = "0123456789abcdef";
	unsigned int shift;

	for (shift = digits * 4; shift != 0; shift -= 4)
		*output++ = hex[(value >> (shift - 4)) & 0xf];
	return output;
}

static void
write_stderr(const char *text, DWORD length)
{
	DWORD written;

	(void)WriteFile(GetStdHandle(STD_ERROR_HANDLE), text, length, &written, NULL);
}

static LONG WINAPI
report_exception(PEXCEPTION_POINTERS details)
{
	char message[192];
	char *output = message;
	DWORD64 pc = details->ContextRecord->Pc;
	DWORD64 sp = details->ContextRecord->Sp;
	DWORD64 base = (DWORD64)(ULONG_PTR)GetModuleHandleA(NULL);
	DWORD64 operation = 0;
	DWORD64 target = 0;

	if (details->ExceptionRecord->NumberParameters >= 2) {
		operation = details->ExceptionRecord->ExceptionInformation[0];
		target = details->ExceptionRecord->ExceptionInformation[1];
	}

	output = append_text(output, "KERTEX_ARM64_EXCEPTION code=0x");
	output = append_hex(output, details->ExceptionRecord->ExceptionCode, 8);
	output = append_text(output, " pc=0x");
	output = append_hex(output, pc, 16);
	output = append_text(output, " rva=0x");
	output = append_hex(output, pc - base, 16);
	output = append_text(output, " address=0x");
	output = append_hex(output,
		(DWORD64)(ULONG_PTR)details->ExceptionRecord->ExceptionAddress, 16);
	output = append_text(output, " sp=0x");
	output = append_hex(output, sp, 16);
	output = append_text(output, " op=0x");
	output = append_hex(output, operation, 16);
	output = append_text(output, " target=0x");
	output = append_hex(output, target, 16);
	*output++ = '\r';
	*output++ = '\n';
	write_stderr(message, (DWORD)(output - message));
	return EXCEPTION_CONTINUE_SEARCH;
}

int
main(int argc, char **argv)
{
	static const char armed[] = "KERTEX_ARM64_EXCEPTION_PROBE armed\r\n";

	(void)AddVectoredExceptionHandler(1, report_exception);
	write_stderr(armed, (DWORD)(sizeof(armed) - 1));
	return kertex_tex_main(argc, argv);
}
