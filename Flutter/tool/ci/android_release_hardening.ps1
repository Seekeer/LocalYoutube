param(
  [ValidateSet('dev', 'stage', 'prod')]
  [string]$Flavor = 'prod',
  [switch]$SkipBuild,
  [switch]$RunSmokeTests,
  [switch]$RequireConnectedDevice
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CheckedFlutter {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & flutter @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

Push-Location (Join-Path $PSScriptRoot '..\..')
try {
  $envFile = Join-Path 'config\env' "$Flavor.json"
  if (-not (Test-Path $envFile)) {
    throw "Flavor config file not found: $envFile"
  }

  $manifestPath = 'android\app\src\main\AndroidManifest.xml'
  if (-not (Test-Path $manifestPath)) {
    throw "Android manifest was not found: $manifestPath"
  }

  $allowedPermissions = @(
    'android.permission.INTERNET',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_DATA_SYNC',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'android.permission.WAKE_LOCK',
    'android.permission.POST_NOTIFICATIONS'
  )

  $manifestText = Get-Content -Path $manifestPath -Raw -Encoding UTF8
  $permissionRegex =
    [regex]'<uses-permission\s+[^>]*android:name="([^"]+)"[^>]*/?>'
  $declaredPermissions = @(
    $permissionRegex.Matches($manifestText) |
      ForEach-Object { $_.Groups[1].Value } |
      Sort-Object -Unique
  )

  Write-Host 'Declared Android permissions:'
  $declaredPermissions | ForEach-Object { Write-Host " - $_" }

  $unexpectedPermissions = @(
    $declaredPermissions | Where-Object { $_ -notin $allowedPermissions }
  )
  if ($unexpectedPermissions.Count -gt 0) {
    throw "Permission audit failed. Unexpected permissions: $($unexpectedPermissions -join ', ')"
  }

  if (-not $SkipBuild) {
    $hasAndroidScaffold = (Test-Path 'android\app\build.gradle.kts') -or
      (Test-Path 'android\app\build.gradle')
    if (-not $hasAndroidScaffold) {
      Write-Host 'Skipping release build: Android scaffold files are missing.'
    }
    else {
      Invoke-CheckedFlutter @(
        'build',
        'apk',
        '--release',
        '--flavor',
        $Flavor,
        "--target=lib/main_$Flavor.dart",
        "--dart-define-from-file=$envFile",
        '--obfuscate',
        "--split-debug-info=build/symbols/$Flavor/android"
      )
    }
  }

  if ($RunSmokeTests) {
    $adbPresent = $null -ne (Get-Command adb -ErrorAction SilentlyContinue)
    if (-not $adbPresent) {
      if ($RequireConnectedDevice) {
        throw 'Smoke tests requested, but adb is not available in PATH.'
      }
      Write-Host 'Skipping smoke tests: adb is not available in PATH.'
      return
    }

    $deviceList = (& adb devices) |
      Select-Object -Skip 1 |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -match '\sdevice$' } |
      ForEach-Object { ($_ -split '\s+')[0] }

    if ($deviceList.Count -eq 0) {
      if ($RequireConnectedDevice) {
        throw 'Smoke tests requested, but no connected Android devices were found.'
      }
      Write-Host 'Skipping smoke tests: no connected Android devices were found.'
      return
    }

    $targetDevice = $deviceList[0]
    Write-Host "Running integration smoke test on device: $targetDevice"
    Invoke-CheckedFlutter @(
      'test',
      'integration_test/android_happy_path_test.dart',
      '-d',
      $targetDevice,
      "--dart-define-from-file=$envFile"
    )
  }
}
finally {
  Pop-Location
}
