#Requires -Version 7.0
param(
  [ValidateSet('Check', 'Upload', 'Release')][string]$Action = 'Check',
  [string]$CredentialsFile,
  [string]$BundlePath,
  [string]$NotesFile
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$package = 'com.my_little_budget'
$track = 'internal'
$api = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package/edits"
$headers = $null
$editId = $null
$committed = $false

function ConvertTo-Base64Url([byte[]]$Bytes) {
  [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Invoke-PlayRequest {
  param([string]$Method, [string]$Uri, $Body, [string]$File)
  $parameters = @{ Method = $Method; Uri = $Uri; Headers = $headers; TimeoutSec = 600 }
  if ($File) {
    $parameters.InFile = $File
    $parameters.ContentType = 'application/octet-stream'
  } elseif ($null -ne $Body) {
    $parameters.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 15 -Compress))
    $parameters.ContentType = 'application/json; charset=utf-8'
  }
  try { Invoke-RestMethod @parameters } catch {
    # Do not echo request headers, credentials or signing material on failure.
    $message = 'Request failed.'
    try { $message = ($_.ErrorDetails.Message | ConvertFrom-Json).error.message } catch {}
    throw "Google Play API ($Method): $message"
  }
}

try {
  if (-not $CredentialsFile) { $CredentialsFile = $env:GOOGLE_APPLICATION_CREDENTIALS }
  $localConfig = Join-Path $root '.google-play.local.json'
  if (-not $CredentialsFile -and (Test-Path -LiteralPath $localConfig)) {
    $CredentialsFile = (Get-Content -LiteralPath $localConfig -Raw | ConvertFrom-Json).credentialsFile
  }
  if (-not $CredentialsFile) { throw 'Specify -CredentialsFile or configure .google-play.local.json.' }
  $credential = Get-Content -LiteralPath $CredentialsFile -Raw | ConvertFrom-Json
  if ($credential.type -ne 'service_account' -or -not $credential.private_key -or -not $credential.client_email) {
    throw 'A service account JSON key is required.'
  }
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $jwtHeader = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"RS256","typ":"JWT"}'))
  $claims = @{ iss = $credential.client_email; scope = 'https://www.googleapis.com/auth/androidpublisher';
    aud = 'https://oauth2.googleapis.com/token'; iat = $now; exp = $now + 3600 }
  $jwtClaims = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes(($claims | ConvertTo-Json -Compress)))
  $unsigned = "$jwtHeader.$jwtClaims"
  $rsa = [Security.Cryptography.RSA]::Create()
  try {
    $rsa.ImportFromPem($credential.private_key)
    $signature = $rsa.SignData([Text.Encoding]::UTF8.GetBytes($unsigned),
      [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
  } finally { $rsa.Dispose(); $credential = $null }
  $assertion = "$unsigned.$(ConvertTo-Base64Url $signature)"
  try {
    $token = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
      grant_type = 'urn:ietf:params:oauth:grant-type:jwt-bearer'; assertion = $assertion
    }
  } catch { throw 'Google service account authentication failed. Check the JSON key and system clock.' }
  $headers = @{ Authorization = "Bearer $($token.access_token)" }
  $token = $assertion = $signature = $unsigned = $null

  $edit = Invoke-PlayRequest -Method Post -Uri $api -Body @{}
  $editId = $edit.id
  $editApi = "$api/$editId"
  $tracks = Invoke-PlayRequest -Method Get -Uri "$editApi/tracks"
  $bundles = Invoke-PlayRequest -Method Get -Uri "$editApi/bundles"
  $internal = $tracks.tracks | Where-Object track -eq $track | Select-Object -First 1
  if ($Action -eq 'Check') {
    [pscustomobject]@{ Package = $package; Track = $track; Access = 'OK';
      Releases = @($internal.releases | Select-Object name, status, versionCodes);
      Bundles = @($bundles.bundles | Select-Object versionCode, sha256) } | ConvertTo-Json -Depth 8
    return
  }

  $version = [regex]::Match((Get-Content (Join-Path $root 'pubspec.yaml') -Raw), '(?m)^version:\s*([^\s+]+)\+(\d+)\s*$')
  if (-not $version.Success) { throw 'Cannot parse pubspec.yaml version.' }
  $appVersion = $version.Groups[1].Value
  $code = $version.Groups[2].Value
  if (-not $BundlePath) { $BundlePath = Join-Path $root "installer/output/MyLittleBudget-Android-$appVersion.aab" }
  $BundlePath = (Resolve-Path -LiteralPath $BundlePath).Path
  if ([IO.Path]::GetExtension($BundlePath) -ne '.aab') { throw 'BundlePath must be an AAB file.' }
  $hash = (Get-FileHash -LiteralPath $BundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
  $bundle = $bundles.bundles | Where-Object { [string]$_.versionCode -eq $code } | Select-Object -First 1
  if ($bundle -and $bundle.sha256.ToLowerInvariant() -ne $hash) {
    throw "Version code $code is already uploaded with different contents. Increase the version code."
  }
  $current = $internal.releases | Where-Object { $code -in @($_.versionCodes) } | Select-Object -First 1
  if ($current -and ($current.status -eq 'completed' -or $Action -eq 'Upload')) {
    Write-Output "Already present on internal: $appVersion ($code), status $($current.status)."
    return
  }
  if (@($internal.releases | Where-Object { $_.status -eq 'draft' -and $code -notin @($_.versionCodes) }).Count) {
    throw 'Another internal draft exists. Review it before replacing the track.'
  }
  if (-not $NotesFile) { throw 'Specify -NotesFile with Korean release notes (maximum 500 characters).' }
  $notes = (Get-Content -LiteralPath $NotesFile -Raw -Encoding UTF8).Trim()
  if (-not $notes -or $notes.Length -gt 500) { throw 'Release notes must contain 1 to 500 characters.' }
  if (-not $bundle) {
    $uploadUri = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$package/edits/$editId/bundles?uploadType=media"
    $bundle = Invoke-PlayRequest -Method Post -Uri $uploadUri -File $BundlePath
    if ([string]$bundle.versionCode -ne $code -or $bundle.sha256.ToLowerInvariant() -ne $hash) {
      throw 'Uploaded bundle version or hash does not match the current source. No track changes committed.'
    }
  }
  $status = if ($Action -eq 'Release') { 'completed' } else { 'draft' }
  $release = @{ name = "$appVersion ($code)"; versionCodes = @($code); status = $status;
    releaseNotes = @(@{ language = 'ko-KR'; text = $notes }) }
  $releases = @($release)
  if ($status -eq 'draft') {
    $releases += @($internal.releases | Where-Object { $_.status -eq 'completed' -and $code -notin @($_.versionCodes) })
  }
  $null = Invoke-PlayRequest -Method Put -Uri "$editApi/tracks/$track" -Body @{ track = $track; releases = $releases }
  $null = Invoke-PlayRequest -Method Post -Uri "${editApi}:validate" -Body @{}
  $null = Invoke-PlayRequest -Method Post -Uri "${editApi}:commit" -Body @{}
  $committed = $true

  # Confirm committed state with a separate read edit; always discard that edit.
  $verifyEdit = Invoke-PlayRequest -Method Post -Uri $api -Body @{}
  try {
    $verified = Invoke-PlayRequest -Method Get -Uri "$api/$($verifyEdit.id)/tracks/$track"
    if (-not @($verified.releases | Where-Object { $_.status -eq $status -and $code -in @($_.versionCodes) }).Count) {
      throw 'The committed release could not be verified. Check Play Console before retrying.'
    }
  } finally { $null = Invoke-PlayRequest -Method Delete -Uri "$api/$($verifyEdit.id)" }
  Write-Output "Verified internal $status release: $appVersion ($code)."
} finally {
  if ($editId -and -not $committed -and $headers) {
    try { $null = Invoke-PlayRequest -Method Delete -Uri "$api/$editId" } catch { Write-Warning 'Could not discard the temporary API edit; it will expire.' }
  }
  $credential = $token = $headers = $assertion = $signature = $null
}
