param(
  [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$appExe = Join-Path $releaseDir 'my_little_budget.exe'
$installerScript = Join-Path $root 'installer\my_little_budget.iss'
$pubspec = Get-Content -LiteralPath (Join-Path $root 'pubspec.yaml') -Raw
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)(-[0-9A-Za-z.-]+)?\+(\d+)\s*$')
if (-not $versionMatch.Success) {
  throw 'pubspec.yaml must contain a version in major.minor.patch[-prerelease]+build format.'
}
$appVersion = '{0}.{1}.{2}{3}' -f $versionMatch.Groups[1].Value, $versionMatch.Groups[2].Value, $versionMatch.Groups[3].Value, $versionMatch.Groups[4].Value
$numericParts = @(1, 2, 3, 5) | ForEach-Object { [int]$versionMatch.Groups[$_].Value }
if ($numericParts | Where-Object { $_ -gt 65535 }) {
  throw 'Windows version components must not exceed 65535.'
}
$numericVersion = $numericParts -join '.'

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
  $builtVersion = (Get-Item -LiteralPath $appExe).VersionInfo.ProductVersion.Trim()
  $expectedVersion = "$appVersion+$($versionMatch.Groups[5].Value)"
  if ($builtVersion -ne $expectedVersion) {
    throw "Release executable version '$builtVersion' does not match '$expectedVersion'. Rebuild without -SkipFlutterBuild."
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

  & $iscc "/DMyAppVersion=$appVersion" "/DMyAppNumericVersion=$numericVersion" $installerScript
  if ($LASTEXITCODE -ne 0) {
    throw 'Inno Setup compilation failed.'
  }

  $output = Join-Path $root "installer\output\MyLittleBudget-Setup-$appVersion.exe"
  if (-not (Test-Path -LiteralPath $output)) {
    throw "Installer output not found: $output"
  }

  Write-Output "Installer created: $output"
  # Both names contain the same full package; Inno Setup upgrades an existing
  # installation using its stable AppId. Older apps still request Setup.
  $updateOutput = Join-Path $root "installer\output\MyLittleBudget-Update-$appVersion.exe"
  Copy-Item -LiteralPath $output -Destination $updateOutput -Force
  $checksumLines = @($output, $updateOutput) | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant(), (Split-Path -Leaf $_)
  }
  [IO.File]::WriteAllLines((Join-Path $root 'installer\output\SHA256SUMS.txt'), $checksumLines, [Text.UTF8Encoding]::new($false))
  Write-Output "Updater created: $updateOutput"
} finally {
  Pop-Location
}
