param(
  [Parameter(Mandatory = $true)][string]$NotesFile,
  [string]$AndroidBundle
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$repository = 'Flynn-Kalar/my_little_budget'
$api = "https://api.github.com/repos/$repository"

function Invoke-GitHubRequest {
  param([string]$Method, [string]$Uri, $Body, [string]$File)
  $parameters = @{ Method = $Method; Uri = $Uri; Headers = $script:headers }
  if ($File) {
    $parameters.InFile = $File
    $parameters.ContentType = 'application/octet-stream'
  } elseif ($null -ne $Body) {
    $parameters.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 8))
    $parameters.ContentType = 'application/json; charset=utf-8'
  }
  Invoke-RestMethod @parameters
}

Push-Location $root
try {
  if (git status --porcelain) { throw 'Commit source changes before publishing a release.' }
  $sourceCommit = (git rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Cannot determine the source commit.' }
  $version = [regex]::Match((Get-Content pubspec.yaml -Raw), '(?m)^version:\s*([^\s+]+)\+(\d+)\s*$')
  if (-not $version.Success) { throw 'Cannot parse the app version.' }
  $appVersion = $version.Groups[1].Value
  $buildNumber = $version.Groups[2].Value
  $tag = "v$appVersion"
  $notes = Get-Content -LiteralPath $NotesFile -Raw -Encoding UTF8
  if ($AndroidBundle) {
    $AndroidBundle = (Resolve-Path -LiteralPath $AndroidBundle).Path
    if ([IO.Path]::GetExtension($AndroidBundle) -ne '.aab') { throw 'AndroidBundle must be an AAB file.' }
  }

  # Read an existing GitHub login without printing or persisting credentials.
  $token = $env:GH_TOKEN
  if (-not $token) { $token = $env:GITHUB_TOKEN }
  if (-not $token) {
    $env:GIT_TERMINAL_PROMPT = '0'
    $credentialLines = @("protocol=https`nhost=github.com`n`n" | git -c credential.interactive=never credential fill)
    if ($LASTEXITCODE -ne 0) { throw 'GitHub authentication is required.' }
    foreach ($line in $credentialLines) {
      if ($line.StartsWith('password=')) { $token = $line.Substring(9) }
    }
    $credentialLines = $null
  }
  if (-not $token) { throw 'No GitHub credential is available.' }
  $script:headers = @{
    Authorization = "Bearer $token"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'my-little-budget-release'
  }
  $token = $null
  $repo = Invoke-GitHubRequest -Method Get -Uri $api
  if (-not $repo.permissions.push) { throw 'GitHub write access is required.' }

  & (Join-Path $PSScriptRoot 'build_windows_installer.ps1')
  if (git status --porcelain) { throw 'The build changed source files. Commit and rebuild before publishing.' }
  $outputDir = Join-Path $root 'installer/output'
  $files = @(
    (Join-Path $outputDir "MyLittleBudget-Setup-$appVersion.exe"),
    (Join-Path $outputDir "MyLittleBudget-Update-$appVersion.exe"),
    (Join-Path $outputDir 'SHA256SUMS.txt')
  )
  if ($AndroidBundle) {
    $bundleOutput = Join-Path $outputDir "MyLittleBudget-Android-$appVersion.aab"
    Copy-Item -LiteralPath $AndroidBundle -Destination $bundleOutput -Force
    $files += $bundleOutput
    $checksumLines = $files | Where-Object { [IO.Path]::GetExtension($_) -in @('.exe', '.aab') } | ForEach-Object {
      '{0}  {1}' -f (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant(), (Split-Path -Leaf $_)
    }
    [IO.File]::WriteAllLines((Join-Path $outputDir 'SHA256SUMS.txt'), $checksumLines, [Text.UTF8Encoding]::new($false))
  }
  $expectedAssets = @($files | ForEach-Object {
    $file = Get-Item -LiteralPath $_
    [pscustomobject]@{ Name = $file.Name; Path = $file.FullName; Size = $file.Length; Sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() }
  })

  git push origin HEAD
  if ($LASTEXITCODE -ne 0) { throw 'Source push failed.' }
  $existingTag = git rev-parse -q --verify "refs/tags/${tag}^{commit}" 2>$null
  if ($LASTEXITCODE -eq 0) {
    if ($existingTag.Trim() -ne $sourceCommit) { throw 'The release tag points to different source. Increase the version.' }
  } else {
    git tag $tag $sourceCommit
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create the release tag.' }
  }
  git push origin "refs/tags/$tag"
  if ($LASTEXITCODE -ne 0) { throw 'Tag push failed.' }

  $release = $null
  try {
    $release = Invoke-GitHubRequest -Method Get -Uri "$api/releases/tags/$tag"
  } catch {
    if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }
  }
  if ($null -eq $release) {
    $release = Invoke-GitHubRequest -Method Post -Uri "$api/releases" -Body @{
      tag_name = $tag; target_commitish = $sourceCommit
      name = "My Little Budget $appVersion (build $buildNumber)"
      body = $notes; draft = $true; prerelease = $appVersion.Contains('-')
    }
  }
  foreach ($asset in $expectedAssets) {
    $existing = $release.assets | Where-Object name -eq $asset.Name | Select-Object -First 1
    if ($existing) {
      if ($existing.size -ne $asset.Size -or $existing.digest -ne "sha256:$($asset.Sha256)") {
        throw "Existing asset differs: $($asset.Name). Existing releases will not be overwritten."
      }
    } else {
      if (-not $release.draft) { throw 'A published release is missing assets; it will not be modified.' }
      $uploadBase = $release.upload_url.Replace('{?name,label}', '')
      $name = [Uri]::EscapeDataString($asset.Name)
      $null = Invoke-GitHubRequest -Method Post -Uri "${uploadBase}?name=$name" -File $asset.Path
      Write-Output "Uploaded $($asset.Name)"
    }
  }
  # The release stays a draft until all downloads have a matching server digest.
  for ($attempt = 0; $attempt -lt 15; $attempt++) {
    $release = Invoke-GitHubRequest -Method Get -Uri "$api/releases/$($release.id)"
    $verified = $true
    foreach ($asset in $expectedAssets) {
      $remote = $release.assets | Where-Object name -eq $asset.Name | Select-Object -First 1
      if (-not $remote -or $remote.size -ne $asset.Size -or $remote.digest -ne "sha256:$($asset.Sha256)") { $verified = $false }
    }
    if ($verified) { break }
    Start-Sleep -Seconds 2
  }
  if (-not $verified) { throw 'Asset verification failed. The release remains a draft.' }
  if ($release.draft) {
    $release = Invoke-GitHubRequest -Method Patch -Uri "$api/releases/$($release.id)" -Body @{ draft = $false }
  }
  [pscustomobject]@{
    Version = "$appVersion+$buildNumber"; SourceCommit = $sourceCommit; Tag = $tag; Url = $release.html_url
    Assets = @($expectedAssets | Select-Object Name, Size, Sha256)
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputDir 'release-result.json') -Encoding UTF8
  Write-Output "Published and verified: $($release.html_url)"
} finally {
  $script:headers = $null
  Pop-Location
}
