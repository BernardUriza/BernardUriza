param(
  [Parameter(Mandatory = $true)][string]$Path,
  [double]$Volume = 1.0
)

# Plays an mp3 through the default output device and BLOCKS for its real
# duration. MediaPlayer opens asynchronously, so NaturalDuration is not
# available on the first tick — poll for it before trusting the length.
# Verified working on Windows PowerShell 5.1, 2026-08-04.

if (-not (Test-Path -LiteralPath $Path)) {
  Write-Error "susurro-play: file not found: $Path"
  exit 1
}

Add-Type -AssemblyName PresentationCore

$player = New-Object System.Windows.Media.MediaPlayer
try {
  $player.Open([Uri]::new((Resolve-Path -LiteralPath $Path).Path))

  $waited = 0
  while (-not $player.NaturalDuration.HasTimeSpan -and $waited -lt 100) {
    Start-Sleep -Milliseconds 100
    $waited++
  }
  if (-not $player.NaturalDuration.HasTimeSpan) {
    Write-Error "susurro-play: media never opened after $($waited * 100)ms"
    exit 1
  }

  $seconds = $player.NaturalDuration.TimeSpan.TotalSeconds
  $player.Volume = $Volume
  $player.Play()
  Start-Sleep -Milliseconds ([int](($seconds + 0.6) * 1000))
  Write-Output ("played_s={0:N1}" -f $seconds)
}
finally {
  $player.Stop()
  $player.Close()
}
