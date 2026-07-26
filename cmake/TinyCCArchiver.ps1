param(
    [Parameter(Mandatory = $true)][string] $TinyCCBase64,
    [Parameter(Mandatory = $true)][string] $Mode,
    [Parameter(Mandatory = $true)][string] $Archive,
    [Parameter(ValueFromRemainingArguments = $true)][string[]] $Objects
)

$tinyCc = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($TinyCCBase64)
)
& $tinyCc -ar $Mode $Archive @Objects
exit $LASTEXITCODE
