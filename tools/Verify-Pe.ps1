[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Path,
    [Parameter(Mandatory = $true)][ValidateSet('x86', 'x64', 'arm64')][string] $Architecture
)

$bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
if ($bytes.Length -lt 256 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
    throw "$Path is not a PE executable"
}
$pe = [BitConverter]::ToInt32($bytes, 0x3c)
if ($pe -lt 0 -or $pe + 96 -ge $bytes.Length -or
    [BitConverter]::ToUInt32($bytes, $pe) -ne 0x00004550) {
    throw "$Path has an invalid PE header"
}
$machine = [BitConverter]::ToUInt16($bytes, $pe + 4)
$expectedMachine = @{ x86 = 0x014c; x64 = 0x8664; arm64 = 0xaa64 }[$Architecture]
if ($machine -ne $expectedMachine) {
    throw ('{0} has machine 0x{1:x4}; expected 0x{2:x4}' -f $Path, $machine, $expectedMachine)
}
$optional = $pe + 24
$subsystemMajor = [BitConverter]::ToUInt16($bytes, $optional + 48)
$subsystemMinor = [BitConverter]::ToUInt16($bytes, $optional + 50)
if ($Architecture -eq 'x86' -and ($subsystemMajor -gt 5)) {
    throw "$Path requests subsystem $subsystemMajor.$subsystemMinor, newer than the legacy x86 baseline"
}
$ascii = [Text.Encoding]::ASCII.GetString($bytes).ToLowerInvariant()
foreach ($forbidden in @('msvcrt.dll', 'ucrtbase.dll', 'vcruntime')) {
    if ($ascii.Contains($forbidden)) { throw "$Path contains forbidden CRT import $forbidden" }
}
[PSCustomObject]@{
    Path = (Resolve-Path -LiteralPath $Path).Path
    Architecture = $Architecture
    Machine = ('0x{0:x4}' -f $machine)
    Subsystem = "$subsystemMajor.$subsystemMinor"
    ExternalCrtImport = 'None'
}
