param(
  [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$appExe = Join-Path $releaseDir 'my_little_budget.exe'
$installerScript = Join-Path $root 'installer\my_little_budget.iss'

Push-Location $root
try {
  if (-not $SkipFlutterBuild) {
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
      throw 'flutter pub get failed.'
    }

    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
      throw 'Flutter Windows release build failed.'
    }
  }

  if (-not (Test-Path -LiteralPath $appExe)) {
    throw "Release executable not found: $appExe"
  }

  $iscc = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Source -First 1
  if (-not $iscc) {
    $isccCandidates = @(
      (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
      (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
      (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe')
    )
    $iscc = $isccCandidates |
      Where-Object { Test-Path -LiteralPath $_ } |
      Select-Object -First 1
  }

  if (-not $iscc) {
    throw 'Inno Setup 6 was not found. Install it with: winget install --id JRSoftware.InnoSetup -e'
  }

  & $iscc $installerScript
  if ($LASTEXITCODE -ne 0) {
    throw 'Inno Setup compilation failed.'
  }

  $output = Join-Path $root 'installer\output\MyLittleBudget-Setup-1.0.0-rc.1.exe'
  if (-not (Test-Path -LiteralPath $output)) {
    throw "Installer output not found: $output"
  }

  Write-Output "Installer created: $output"
} finally {
  Pop-Location
}
