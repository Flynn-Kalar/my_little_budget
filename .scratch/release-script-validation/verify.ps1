#Requires -Version 7.0
# Offline review harness. Only fixture files are used; git, Flutter, Inno Setup
# and every HTTP request made by the copied scripts are replaced with mocks.
$ErrorActionPreference = 'Stop'
$reviewRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixtureRoot = Join-Path $reviewRoot ('build/release-script-review/' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$results = [Collections.Generic.List[object]]::new()
$originalToken = $env:GH_TOKEN
$env:GH_TOKEN = 'offline-review-placeholder'

function Assert-Review([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "Review assertion failed: $Message" }
}

function Invoke-ReviewCase {
  param(
    [string]$Name,
    [ValidateSet('Windows', 'Play')][string]$Target = 'Windows',
    [hashtable]$Options = @{},
    [string]$ExpectedError,
    [bool]$ExpectPublish = $false,
    [bool]$KnownGap = $false,
    [scriptblock]$Verify
  )
  $caseRoot = Join-Path $fixtureRoot $Name
  $null = New-Item -ItemType Directory -Path (Join-Path $caseRoot 'scripts') -Force
  $null = New-Item -ItemType Directory -Path (Join-Path $caseRoot 'installer/output') -Force
  $null = New-Item -ItemType Directory -Path (Join-Path $caseRoot 'build/windows/x64/runner/Release') -Force
  foreach ($scriptName in @('publish_windows_release.ps1', 'build_windows_installer.ps1', 'publish_google_play.ps1')) {
    Copy-Item -LiteralPath (Join-Path $reviewRoot "scripts/$scriptName") -Destination (Join-Path $caseRoot "scripts/$scriptName")
  }
  [IO.File]::WriteAllText((Join-Path $caseRoot 'pubspec.yaml'), "name: offline_fixture`nversion: 1.0.0-rc.17+66`n")
  [IO.File]::WriteAllText((Join-Path $caseRoot 'notes.md'), 'Offline release review')
  # Deliberately not a ZIP/AAB: publishing this demonstrates missing local validation.
  $bundlePath = Join-Path $caseRoot 'unverified.aab'
  [IO.File]::WriteAllText($bundlePath, 'not an Android App Bundle')
  if ($Options.LongNotes) { [IO.File]::WriteAllText((Join-Path $caseRoot 'notes.md'), ('x' * 501)) }
  $fakeCompiler = Join-Path $caseRoot 'fake_iscc.ps1'
  [IO.File]::WriteAllText($fakeCompiler, @'
$global:LASTEXITCODE = 0
$reviewState.BuildCalls.Add('inno')
if ($reviewState.Options.InnoFailure) { $global:LASTEXITCODE = 1; return }
[IO.File]::WriteAllText((Join-Path $reviewState.Root 'installer/output/MyLittleBudget-Setup-1.0.0-rc.17.exe'), 'fixture installer bytes')
'@)
  $reviewState = @{
    Root = $caseRoot; Compiler = $fakeCompiler; Options = $Options
    Calls = [Collections.Generic.List[string]]::new()
    GitCalls = [Collections.Generic.List[string]]::new()
    BuildCalls = [Collections.Generic.List[string]]::new()
    Published = $false; Committed = $false; DeletedEdits = 0; EditCount = 0
    SourceCommit = ('a' * 40); CurrentCommit = ('a' * 40)
    BundlePath = $bundlePath; BundleHash = (Get-FileHash -LiteralPath $bundlePath).Hash.ToLowerInvariant()
    Release = [pscustomobject]@{
      id = 99; draft = -not [bool]$Options.AlreadyPublished
      upload_url = 'https://offline.invalid/uploads/99{?name,label}'
      html_url = 'https://offline.invalid/releases/v1.0.0-rc.17'
      assets = @()
    }
  }
  if ($Options.ExistingAssetMismatch) {
    $reviewState.Release.assets = @([pscustomobject]@{
      name = 'MyLittleBudget-Setup-1.0.0-rc.17.exe'; size = 1; digest = ('sha256:' + ('0' * 64))
    })
  }
  if ($Target -eq 'Play') {
    # Synthetic, disposable service-account material. No real credentials are read.
    $key = [Security.Cryptography.RSA]::Create(2048)
    try {
      @{ type = 'service_account'; private_key = $key.ExportPkcs8PrivateKeyPem(); client_email = 'offline@example.invalid' } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $caseRoot 'fake-account.json') -Encoding utf8
    } finally { $key.Dispose() }
  }

  $caseError = $null
  $output = & {
    function git {
      $command = $args -join ' '
      $reviewState.GitCalls.Add($command)
      $global:LASTEXITCODE = 0
      switch -Regex ($command) {
        '^status --porcelain$' {
          if ($reviewState.Options.GitStatusFailure) { $global:LASTEXITCODE = 128; return }
          if ($reviewState.Options.Dirty -or ($reviewState.Options.BuildDirty -and $reviewState.BuildCalls.Count)) { ' M fixture.dart' }
          return
        }
        '^rev-parse HEAD$' { $reviewState.CurrentCommit; return }
        '^rev-parse -q --verify refs/tags/' {
          if ($reviewState.Options.ConflictingTag) { 'b' * 40; return }
          $global:LASTEXITCODE = 1; return
        }
        '^tag ' { $reviewState.TaggedCommit = $args[-1]; return }
        '^push origin HEAD$' {
          $reviewState.PushedCommit = $reviewState.CurrentCommit
          if ($reviewState.Options.PushFailure) { $global:LASTEXITCODE = 1 }
          return
        }
        '^push origin refs/tags/' { return }
        default { throw "Unexpected git command: $command" }
      }
    }
    function flutter {
      $command = $args -join ' '
      $reviewState.BuildCalls.Add("flutter $command")
      $global:LASTEXITCODE = 0
      switch ($command) {
        'pub get' { if ($reviewState.Options.PubFailure) { $global:LASTEXITCODE = 1 }; return }
        'build windows --release' {
          if ($reviewState.Options.FlutterBuildFailure) { $global:LASTEXITCODE = 1; return }
          [IO.File]::WriteAllText((Join-Path $reviewState.Root 'build/windows/x64/runner/Release/my_little_budget.exe'), 'fixture app bytes')
          if ($reviewState.Options.HeadChanges) { $reviewState.CurrentCommit = 'c' * 40 }
          return
        }
        default { throw "Unexpected Flutter command: $command" }
      }
    }
    function Get-Command {
      param([string]$Name, $ErrorAction)
      if ($Name -ne 'ISCC.exe') { throw "Unexpected executable lookup: $Name" }
      [pscustomobject]@{ Source = $reviewState.Compiler }
    }
    function Get-Item {
      param([string]$LiteralPath)
      if ($LiteralPath.EndsWith('my_little_budget.exe')) {
        $version = if ($reviewState.Options.ExeVersionMismatch) { '1.0.0-rc.16+65' } else { '1.0.0-rc.17+66' }
        return [pscustomobject]@{ VersionInfo = [pscustomobject]@{ ProductVersion = $version } }
      }
      Microsoft.PowerShell.Management\Get-Item -LiteralPath $LiteralPath
    }
    function Start-Sleep { param([int]$Seconds) }
    function Invoke-RestMethod {
      param([string]$Method, [string]$Uri, $Body, [string]$InFile, $Headers, $ContentType, $TimeoutSec)
      $reviewState.Calls.Add("$Method $Uri")
      if ($Target -eq 'Windows') {
        if ($Method -eq 'Get' -and $Uri -match '/repos/[^/]+/[^/]+$') {
          return [pscustomobject]@{ permissions = [pscustomobject]@{ push = $true } }
        }
        if ($Method -eq 'Get' -and $Uri -match '/releases/tags/' -and $reviewState.Options.NoRelease) {
          throw [Microsoft.PowerShell.Commands.HttpResponseException]::new(
            'Synthetic missing release', [Net.Http.HttpResponseMessage]::new([Net.HttpStatusCode]::NotFound))
        }
        if ($Method -eq 'Post' -and $Uri -match '/releases$') {
          $reviewState.CreateRequest = [Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
          return $reviewState.Release
        }
        if ($Method -eq 'Get' -and ($Uri -match '/releases/tags/' -or $Uri -match '/releases/99$')) {
          return $reviewState.Release
        }
        # The current script never requests a release list to compare public versions.
        if ($Method -eq 'Get' -and $Uri -match '/releases(\?|$)') {
          return @([pscustomobject]@{ tag_name = 'v1.0.0-rc.18'; draft = $false })
        }
        if ($Method -eq 'Post' -and $Uri -match '^https://offline.invalid/uploads/99\?name=') {
          $file = Microsoft.PowerShell.Management\Get-Item -LiteralPath $InFile
          $digest = (Get-FileHash -LiteralPath $InFile).Hash.ToLowerInvariant()
          if ($reviewState.Options.DigestMismatch) { $digest = '0' * 64 }
          $reviewState.Release.assets += [pscustomobject]@{ name = $file.Name; size = $file.Length; digest = "sha256:$digest" }
          return [pscustomobject]@{ id = 1 }
        }
        if ($Method -eq 'Patch' -and $Uri -match '/releases/99$') {
          $reviewState.Published = $true
          $reviewState.Release.draft = $false
          return $reviewState.Release
        }
      } else {
        if ($Uri -eq 'https://oauth2.googleapis.com/token') { return @{ access_token = 'offline-token' } }
        if ($Method -eq 'Post' -and $Uri -match '/edits$') {
          $reviewState.EditCount++
          return @{ id = [string]$reviewState.EditCount }
        }
        if ($Method -eq 'Get' -and $Uri -match '/edits/1/tracks$') {
          $release = if ($reviewState.Options.OtherDraft) {
            @{ name = 'other'; versionCodes = @('67'); status = 'draft' }
          } else { @{ name = 'newer'; versionCodes = @('67'); status = 'completed' } }
          return @{ tracks = @(@{ track = 'internal'; releases = @($release) }) }
        }
        if ($Method -eq 'Get' -and $Uri -match '/edits/1/bundles$') {
          $bundles = if ($reviewState.Options.ExistingBundle) {
            $hash = if ($reviewState.Options.BundleHashMismatch) { '0' * 64 } else { $reviewState.BundleHash }
            @(@{ versionCode = '66'; sha256 = $hash })
          } else { @() }
          return @{ bundles = $bundles }
        }
        if ($Method -eq 'Post' -and $Uri -match '/upload/.*/bundles\?uploadType=media$') {
          $code = if ($reviewState.Options.BundleVersionMismatch) { '65' } else { '66' }
          return @{ versionCode = $code; sha256 = $reviewState.BundleHash }
        }
        if ($Method -eq 'Put' -and $Uri -match '/edits/1/tracks/internal$') {
          $reviewState.TrackRequest = [Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
          return @{}
        }
        if ($Method -eq 'Post' -and $Uri -match '/edits/1:validate$') {
          if ($reviewState.Options.ValidateFailure) { throw 'synthetic validation failure' }
          return @{}
        }
        if ($Method -eq 'Post' -and $Uri -match '/edits/1:commit$') { $reviewState.Committed = $true; return @{} }
        if ($Method -eq 'Get' -and $Uri -match '/edits/2/tracks/internal$') {
          if ($reviewState.Options.VerifyFailure) { return @{ releases = @() } }
          return @{ releases = @(@{ status = 'completed'; versionCodes = @('66') }) }
        }
        if ($Method -eq 'Delete' -and $Uri -match '/edits/[12]$') { $reviewState.DeletedEdits++; return @{} }
      }
      throw "Unexpected HTTP request (network is disabled by the harness): $Method $Uri"
    }
    try {
      if ($Target -eq 'Windows') {
        $parameters = @{ NotesFile = (Join-Path $caseRoot 'notes.md') }
        if ($Options.WithBundle) { $parameters.AndroidBundle = $bundlePath }
        & (Join-Path $caseRoot 'scripts/publish_windows_release.ps1') @parameters
      } else {
        & (Join-Path $caseRoot 'scripts/publish_google_play.ps1') -Action Release -CredentialsFile (Join-Path $caseRoot 'fake-account.json') -BundlePath $bundlePath -NotesFile (Join-Path $caseRoot 'notes.md')
      }
    } catch { $reviewState.Error = $_.Exception.Message }
  }
  $caseError = $reviewState.Error
  if ($ExpectedError) {
    Assert-Review ([bool]($caseError -like "*$ExpectedError*")) "$Name expected '$ExpectedError', got '$caseError'"
  } else { Assert-Review (-not $caseError) "$Name unexpectedly failed: $caseError" }
  $didPublish = $reviewState.Published -or $reviewState.Committed
  Assert-Review ($didPublish -eq $ExpectPublish) "$Name publishing state mismatch"
  if ($Verify) { & $Verify $reviewState }
  $results.Add([pscustomobject]@{
    Case = $Name; Target = $Target; Finding = $(if ($KnownGap) { 'gap-reproduced' } else { 'protection-verified' })
    MockPublished = $didPublish; Error = $caseError
    GitCalls = @($reviewState.GitCalls); BuildCalls = @($reviewState.BuildCalls); HttpCalls = @($reviewState.Calls)
  })
  Write-Output ("{0}: {1}" -f $results[-1].Finding, $Name)
}

try {
  Invoke-ReviewCase 'windows-happy-path' -ExpectPublish $true -Verify {
    param($s)
    $setup = Get-FileHash -LiteralPath (Join-Path $s.Root 'installer/output/MyLittleBudget-Setup-1.0.0-rc.17.exe')
    $update = Get-FileHash -LiteralPath (Join-Path $s.Root 'installer/output/MyLittleBudget-Update-1.0.0-rc.17.exe')
    Assert-Review ($setup.Hash -eq $update.Hash) 'Setup and Update hashes differ'
    Assert-Review ($s.Release.assets.Count -eq 3) 'Expected both EXEs and checksum asset'
    $manifest = Get-Content -LiteralPath (Join-Path $s.Root 'installer/output/SHA256SUMS.txt')
    foreach ($kind in @('Setup', 'Update')) {
      Assert-Review ($manifest -contains ($setup.Hash.ToLowerInvariant() + "  MyLittleBudget-$kind-1.0.0-rc.17.exe")) 'Checksum manifest mismatch'
    }
  }
  Invoke-ReviewCase 'windows-new-draft' -Options @{ NoRelease = $true } -ExpectPublish $true -Verify {
    param($s)
    Assert-Review $s.CreateRequest.draft 'Release was not created as draft'
    Assert-Review ($s.CreateRequest.target_commitish -eq $s.SourceCommit) 'Wrong draft source commit'
    Assert-Review ($s.Calls[-1] -match '^Patch .*releases/99$') 'Publication must happen after asset verification'
  }
  Invoke-ReviewCase 'dirty-tree' -Options @{ Dirty = $true } -ExpectedError 'Commit source changes' -Verify {
    param($s); Assert-Review ($s.Calls.Count -eq 0 -and $s.BuildCalls.Count -eq 0) 'Dirty source reached build or HTTP'
  }
  Invoke-ReviewCase 'pub-fails' -Options @{ PubFailure = $true } -ExpectedError 'flutter pub get failed'
  Invoke-ReviewCase 'flutter-build-fails' -Options @{ FlutterBuildFailure = $true } -ExpectedError 'Flutter Windows release build failed'
  Invoke-ReviewCase 'inno-fails' -Options @{ InnoFailure = $true } -ExpectedError 'Inno Setup compilation failed'
  Invoke-ReviewCase 'wrong-exe-version' -Options @{ ExeVersionMismatch = $true } -ExpectedError 'does not match'
  Invoke-ReviewCase 'build-modifies-source' -Options @{ BuildDirty = $true } -ExpectedError 'build changed source files'
  Invoke-ReviewCase 'source-push-fails' -Options @{ PushFailure = $true } -ExpectedError 'Source push failed'
  Invoke-ReviewCase 'conflicting-tag' -Options @{ ConflictingTag = $true } -ExpectedError 'tag points to different source'
  Invoke-ReviewCase 'different-existing-asset' -Options @{ ExistingAssetMismatch = $true } -ExpectedError 'Existing asset differs'
  Invoke-ReviewCase 'published-release-missing-assets' -Options @{ AlreadyPublished = $true } -ExpectedError 'published release is missing assets'
  Invoke-ReviewCase 'remote-digest-mismatch' -Options @{ DigestMismatch = $true } -ExpectedError 'Asset verification failed' -Verify {
    param($s); Assert-Review $s.Release.draft 'Failed verification published a draft'
  }
  Invoke-ReviewCase 'no-test-gate' -ExpectPublish $true -KnownGap $true -Verify {
    param($s); Assert-Review (-not ($s.BuildCalls -match '^flutter (analyze|test)')) 'Unexpected test gate was added'
  }
  Invoke-ReviewCase 'no-public-version-gate' -ExpectPublish $true -KnownGap $true -Verify {
    param($s); Assert-Review (-not ($s.Calls -match '/releases(\?|$)')) 'A public version comparison was attempted'
  }
  Invoke-ReviewCase 'malformed-aab-accepted' -Options @{ WithBundle = $true } -ExpectPublish $true -KnownGap $true -Verify {
    param($s); Assert-Review ($s.Release.assets.Count -eq 4) 'Malformed AAB was not included'
  }
  Invoke-ReviewCase 'git-status-error-accepted' -Options @{ GitStatusFailure = $true } -ExpectPublish $true -KnownGap $true
  Invoke-ReviewCase 'head-changes-during-build' -Options @{ HeadChanges = $true } -ExpectPublish $true -KnownGap $true -Verify {
    param($s); Assert-Review ($s.PushedCommit -ne $s.TaggedCommit) 'Expected pushed HEAD and tag to diverge'
  }
  Invoke-ReviewCase 'play-other-draft' -Target Play -Options @{ OtherDraft = $true } -ExpectedError 'Another internal draft exists'
  Invoke-ReviewCase 'play-long-notes' -Target Play -Options @{ LongNotes = $true } -ExpectedError '1 to 500 characters'
  Invoke-ReviewCase 'play-existing-bundle-mismatch' -Target Play -Options @{ ExistingBundle = $true; BundleHashMismatch = $true } -ExpectedError 'different contents'
  Invoke-ReviewCase 'play-upload-version-mismatch' -Target Play -Options @{ BundleVersionMismatch = $true } -ExpectedError 'version or hash does not match'
  Invoke-ReviewCase 'play-validate-fails' -Target Play -Options @{ ValidateFailure = $true } -ExpectedError 'Google Play API' -Verify {
    param($s); Assert-Review ($s.DeletedEdits -eq 1) 'Uncommitted Play edit was not discarded'
  }
  Invoke-ReviewCase 'play-post-commit-verification-fails' -Target Play -Options @{ VerifyFailure = $true } -ExpectedError 'could not be verified' -ExpectPublish $true
  Invoke-ReviewCase 'play-higher-version-not-guarded' -Target Play -Options @{ ExistingBundle = $true } -ExpectPublish $true -KnownGap $true -Verify {
    param($s); Assert-Review ($s.TrackRequest.releases[0].versionCodes[0] -eq '66') 'Expected candidate 66 to replace mocked current 67'
  }
  $report = Join-Path $PSScriptRoot 'results.json'
  @($results) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $report -Encoding utf8
  Write-Output "Verified $($results.Count) offline scenarios. Results: $report"
} finally {
  $env:GH_TOKEN = $originalToken
}
