<#
.SYNOPSIS
  Resolve the background color of THIS terminal session as #RRGGBB.

.DESCRIPTION
  Windows counterpart of the macOS `osascript` + TTY-matching path used by
  /colored-coagent and /exchange-coagent Phase 0.

  Anchoring: on macOS the session is identified by its TTY (never `front window`).
  On Windows the equivalent anchor is stronger and cheaper: Windows Terminal exports
  WT_SESSION and WT_PROFILE_ID into THIS process's environment, so the profile we
  resolve is by construction the one this Claude Code session runs in — no window
  focus involved, no multi-session mixup possible.

  Resolution order for Windows Terminal:
    1. profile.background          (explicit hex on the profile)
    2. profile.colorScheme         -> schemes[].background (user scheme, then built-in)
    3. profiles.defaults.background
    4. profiles.defaults.colorScheme -> schemes[].background
    5. WT built-in default scheme "Campbell" (#0C0C0C)

  Fallback for classic conhost (no WT_SESSION): HKCU:\Console ScreenColors + ColorTableNN.

.OUTPUTS
  Two lines on success (exit 0):
    COLOR=#RRGGBB
    SOURCE=<how it was resolved>
  On failure (exit 1):
    COLOR=NOTFOUND
    SOURCE=<why>

  When the color is inferred rather than declared, a third line is emitted:
    WARN=<what to confirm with the user before painting>
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Backgrounds of the schemes Windows Terminal ships with. Used only when a profile
# names a scheme that is not redefined in settings.json.
$BuiltinSchemes = @{
    'Campbell'            = '#0C0C0C'
    'Campbell Powershell' = '#012456'
    'Vintage'             = '#000000'
    'One Half Dark'       = '#282C34'
    'One Half Light'      = '#FAFAFA'
    'Solarized Dark'      = '#002B36'
    'Solarized Light'     = '#FDF6E3'
    'Tango Dark'          = '#000000'
    'Tango Light'         = '#FFFFFF'
}

function Write-Result {
    param([string]$Color, [string]$Source, [string]$Warn)
    Write-Output "COLOR=$Color"
    Write-Output "SOURCE=$Source"
    if ($Warn) { Write-Output "WARN=$Warn" }
}

function Fail {
    param([string]$Why)
    Write-Result -Color 'NOTFOUND' -Source $Why
    exit 1
}

function ConvertFrom-JsonC {
    # WT's settings.json is JSONC. Strip whole-line // comments and /* */ blocks.
    # Whole-line only, so "https://aka.ms/..." inside a string value survives.
    param([string]$Raw)
    $noBlock = [regex]::Replace($Raw, '/\*[\s\S]*?\*/', '')
    $noLine  = [regex]::Replace($noBlock, '(?m)^\s*//.*$', '')
    $noLine | ConvertFrom-Json
}

function Get-SchemeBackground {
    param($Doc, $SchemeRef)
    if (-not $SchemeRef) { return $null }

    # WT >= 1.22 allows colorScheme to be an object: { "dark": "...", "light": "..." }
    $name = $SchemeRef
    if ($SchemeRef -isnot [string]) {
        $name = if ($SchemeRef.dark) { $SchemeRef.dark } else { $SchemeRef.light }
    }
    if (-not $name) { return $null }

    $scheme = $Doc.schemes | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if ($scheme -and $scheme.background) {
        return @{ Color = $scheme.background; Source = "user scheme '$name'" }
    }
    if ($BuiltinSchemes.ContainsKey($name)) {
        return @{ Color = $BuiltinSchemes[$name]; Source = "built-in scheme '$name'" }
    }
    return $null
}

function Get-Prop {
    # PSCustomObject property access that does not throw on a missing key.
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    if ($Obj.PSObject.Properties.Name -contains $Name) { return $Obj.$Name }
    return $null
}

# ---------------------------------------------------------------- Windows Terminal
if ($env:WT_SESSION -and $env:WT_PROFILE_ID) {
    # @(...) around the pipeline is load-bearing: a single-match pipeline collapses to a
    # bare string, and $paths[0] would then index its first CHARACTER ("C").
    $paths = @(@(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    ) | Where-Object { Test-Path $_ })

    if (-not $paths) { Fail "WT_SESSION is set but no settings.json was found" }

    $settingsPath = $paths[0]
    try { $doc = ConvertFrom-JsonC (Get-Content $settingsPath -Raw) }
    catch { Fail "could not parse $settingsPath : $($_.Exception.Message)" }

    $wtProfile = $doc.profiles.list | Where-Object { $_.guid -eq $env:WT_PROFILE_ID } | Select-Object -First 1
    if (-not $wtProfile) { Fail "no profile matching WT_PROFILE_ID=$env:WT_PROFILE_ID in $settingsPath" }

    $profileName = $wtProfile.name
    $defaults    = $doc.profiles.defaults

    foreach ($layer in @(
        @{ Obj = $wtProfile; Label = "profile '$profileName'" }
        @{ Obj = $defaults;  Label = 'profiles.defaults' }
    )) {
        $bg = Get-Prop $layer.Obj 'background'
        if ($bg) { Write-Result -Color $bg -Source "$($layer.Label).background"; exit 0 }

        $hit = Get-SchemeBackground -Doc $doc -SchemeRef (Get-Prop $layer.Obj 'colorScheme')
        if ($hit) { Write-Result -Color $hit.Color -Source "$($layer.Label) -> $($hit.Source)"; exit 0 }
    }

    # Nothing declared anywhere: WT falls back to Campbell.
    $src  = "Windows Terminal default (profile '$profileName' declares no background or colorScheme)"
    $warn = 'color is INFERRED from the WT default, not declared in settings.json - confirm the hex with the user before painting'
    Write-Result -Color $BuiltinSchemes['Campbell'] -Source $src -Warn $warn
    exit 0
}

# ---------------------------------------------------------------- classic conhost
try {
    $console = Get-ItemProperty 'HKCU:\Console' -ErrorAction Stop
} catch {
    Fail 'not a Windows Terminal session (no WT_SESSION) and HKCU:\Console is unreadable'
}

$screenColors = Get-Prop $console 'ScreenColors'
if ($null -eq $screenColors) { Fail 'HKCU:\Console has no ScreenColors value' }

$bgIndex = ([int]$screenColors -shr 4) -band 0xF
$tableKey = 'ColorTable{0:D2}' -f $bgIndex
$colorRef = Get-Prop $console $tableKey
if ($null -eq $colorRef) { Fail "HKCU:\Console has no $tableKey value" }

# COLORREF is 0x00BBGGRR, not RGB.
$v = [int]$colorRef
$r = $v -band 0xFF
$g = ($v -shr 8) -band 0xFF
$b = ($v -shr 16) -band 0xFF
$hex = '#{0:X2}{1:X2}{2:X2}' -f $r, $g, $b
Write-Result -Color $hex -Source "conhost HKCU:\Console $tableKey (bg index $bgIndex)"
exit 0
