# RunTests.ps1 - self-test for the FindUtf16 tool.
#
# Recreates tests\sandbox from tests\examples, runs the tool (list / fix)
# and prints a PASS/FAIL report. Exit code: 0 when all checks pass, 1 otherwise.
#
# Expected to be launched by RunTests.cmd.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$testsDir = $PSScriptRoot
$tool     = [IO.Path]::GetFullPath((Join-Path $testsDir '..\src\FindUtf16.cmd'))
$examples = Join-Path $testsDir 'examples'
$sandbox  = Join-Path $testsDir 'sandbox'

$script:passed = 0
$script:failed = 0

function Check {
    param(
        [string] $Name,
        [bool]   $Condition,
        [string] $Detail = ''
    )

    if ($Condition) {
        $script:passed = $script:passed + 1
        Write-Output ('PASS  ' + $Name)
    }
    else {
        $script:failed = $script:failed + 1
        Write-Output ('FAIL  ' + $Name)
        if ($Detail) {
            Write-Output ('      ' + $Detail)
        }
    }
}

function Invoke-Tool {
    param([string[]] $ToolArgs)

    $output = & $tool @ToolArgs
    [pscustomobject]@{
        Output = @($output)
        Code   = $LASTEXITCODE
    }
}

function Get-ListedFiles {
    param([string[]] $Output)

    @($Output | Where-Object { $_ -notmatch '^Total: ' })
}

function Test-Utf16File {
    param([string] $Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 2 -and (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF))
    $hasNul = $bytes -contains 0

    return $hasBom -or $hasNul
}

# Arrange: recreate the sandbox and copy the example files into it.
if (Test-Path -LiteralPath $sandbox) {
    Get-ChildItem -LiteralPath $sandbox -Force | Where-Object { $_.Name -ne '.gitkeep' } | Remove-Item -Recurse -Force
}
else {
    New-Item -ItemType Directory -Path $sandbox | Out-Null
}

Copy-Item -Path (Join-Path $examples '*') -Destination $sandbox

Write-Output '== list =='

$expected = @('be_bom.sql', 'le_bom.sql', 'le_cyr.sql', 'le_nobom.sql')

$result = Invoke-Tool -ToolArgs @('--list', '--path', $sandbox)
$listed = Get-ListedFiles $result.Output

Check 'list exit code is 0' ($result.Code -eq 0) ("exit code: " + $result.Code)
Check 'list finds exactly the expected files' (((@($listed) | Sort-Object) -join '|') -eq ((@($expected) | Sort-Object) -join '|')) ("found: " + ((@($listed) | Sort-Object) -join ', '))
Check 'list does not include utf8.sql' (@($listed) -notcontains 'utf8.sql')

Write-Output ''
Write-Output '== fix =='

$result = Invoke-Tool -ToolArgs @('--fix', '--path', $sandbox)
Check 'fix exit code is 0' ($result.Code -eq 0) ("exit code: " + $result.Code)

$result = Invoke-Tool -ToolArgs @('--list', '--path', $sandbox)
Check 'no UTF-16 files left after fix' ((Get-ListedFiles $result.Output).Count -eq 0)

# Content checks: bytes must survive the conversion (CRLF and Cyrillic included).
$leBom = [IO.File]::ReadAllText((Join-Path $sandbox 'le_bom.sql'))
Check 'le_bom.sql content preserved' ($leBom -eq "TEST`r`n") ("actual: " + [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($leBom)))

$beBom = [IO.File]::ReadAllText((Join-Path $sandbox 'be_bom.sql'))
Check 'be_bom.sql content preserved' ($beBom -eq "TEST`r`n") ("actual: " + [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($beBom)))

$leNoBom = [IO.File]::ReadAllText((Join-Path $sandbox 'le_nobom.sql'))
Check 'le_nobom.sql content preserved' ($leNoBom -eq "TEST`r`n") ("actual: " + [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($leNoBom)))

$expectedCyr = [string][char]0x0422 + [char]0x0435 + [char]0x0441 + [char]0x0442
$leCyr = [IO.File]::ReadAllText((Join-Path $sandbox 'le_cyr.sql'))
Check 'le_cyr.sql (Cyrillic) content preserved' ($leCyr -eq $expectedCyr) ("actual: " + $leCyr)

$utf8 = [IO.File]::ReadAllText((Join-Path $sandbox 'utf8.sql'))
Check 'utf8.sql was not modified' ($utf8 -eq "TEST`n")

$bad = @(Get-ChildItem -LiteralPath $sandbox -File | Where-Object { Test-Utf16File $_.FullName })
Check 'all sandbox files are UTF-8 without BOM' ($bad.Count -eq 0) ("still UTF-16: " + (($bad | ForEach-Object { $_.Name }) -join ', '))

Write-Output ''
Write-Output ('Total: ' + ($script:passed + $script:failed) + ', passed: ' + $script:passed + ', failed: ' + $script:failed)

if ($script:failed -gt 0) {
    exit 1
}

exit 0
