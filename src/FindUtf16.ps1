# FindUtf16.ps1 - find (and optionally convert) UTF-16 encoded files in a folder tree.
#
# Usage:
#   FindUtf16.ps1 list [-Root <folder>]   List UTF-16 files.
#   FindUtf16.ps1 fix  [-Root <folder>]   Convert UTF-16 files to UTF-8 (without BOM).
#
# Root defaults to the current directory. FindUtf16.cmd passes --path or the current directory.
# Excluded folders: .git, $tf, .vs, bin, obj.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('list', 'fix')]
    [string] $Mode,

    [string] $Root = '.'
)

$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Root folder not found: $root"
}

$exclude = '\\(bin|obj|\.git|\$tf|\$tf1|\.vs)\\'
$utf8    = New-Object Text.UTF8Encoding($false)
$count   = 0

function Get-Utf16Encoding {
    param(
        [byte[]] $Bytes,
        [int]    $Length
    )

    if ($Length -lt 2) {
        return $null
    }

    # UTF-16 with BOM.
    if ($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) { return [Text.Encoding]::Unicode }
    if ($Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) { return [Text.Encoding]::BigEndianUnicode }

    # BOM-less UTF-16: ASCII text contains a NUL byte in every second byte.
    if ($Bytes[1] -eq 0 -and $Bytes[0] -ge 9 -and $Bytes[0] -lt 127) { return [Text.Encoding]::Unicode }
    if ($Bytes[0] -eq 0 -and $Bytes[1] -ge 9 -and $Bytes[1] -lt 127) { return [Text.Encoding]::BigEndianUnicode }

    return $null
}

Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $exclude } |
    ForEach-Object {
        $item   = $_
        $stream = $item.OpenRead()
        try {
            $bytes = New-Object byte[] 4
            $read  = $stream.Read($bytes, 0, 4)
        }
        finally {
            $stream.Dispose()
        }

        $enc = Get-Utf16Encoding -Bytes $bytes -Length $read
        if ($null -eq $enc) {
            return
        }

        $count = $count + 1
        $rel   = $item.FullName.Substring($root.Length + 1)

        switch ($Mode) {
            'list' {
                Write-Output $rel
            }
            'fix' {
                $text = [IO.File]::ReadAllText($item.FullName, $enc)
                [IO.File]::WriteAllText($item.FullName, $text, $utf8)
                Write-Output ('fixed: ' + $rel)
            }
        }
    }

Write-Output ('Total: ' + $count + ' file(s).')
