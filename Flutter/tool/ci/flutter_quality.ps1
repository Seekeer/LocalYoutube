param(
  [ValidateSet('dev', 'stage', 'prod')]
  [string]$Flavor = 'prod',
  [switch]$SkipTest,
  [switch]$BuildAndroid,
  [switch]$BuildWindows,
  [switch]$HardenRelease,
  [switch]$StrictAnalyze
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
  Invoke-CheckedFlutter @('pub', 'get')
  if ($StrictAnalyze) {
    Invoke-CheckedFlutter @(
      'analyze',
      '--fatal-infos',
      '--fatal-warnings'
    )
  }
  else {
    Invoke-CheckedFlutter @(
      'analyze',
      '--no-fatal-infos',
      '--no-fatal-warnings'
    )
  }
  if (-not $SkipTest) {
    Invoke-CheckedFlutter @('test')
  }

  $envFile = Join-Path 'config\env' "$Flavor.json"
  if (-not (Test-Path $envFile)) {
    throw "Flavor config file not found: $envFile"
  }

  $hasAndroidScaffold = (Test-Path 'android\app\build.gradle.kts') -or
    (Test-Path 'android\app\build.gradle')
  if ($BuildAndroid) {
    if (-not $hasAndroidScaffold) {
      Write-Host 'Skipping Android build: Android scaffold files are missing.'
    }
    else {
      $androidArgs = @(
        'build',
        'apk',
        '--release',
        '--flavor',
        $Flavor,
        "--target=lib/main_$Flavor.dart",
        "--dart-define-from-file=$envFile"
      )
      if ($HardenRelease) {
        $androidArgs += '--obfuscate'
        $androidArgs += "--split-debug-info=build/symbols/$Flavor/android"
      }
      Invoke-CheckedFlutter -Arguments $androidArgs
    }
  }

  $hasWindowsScaffold = Test-Path 'windows\CMakeLists.txt'
  if ($BuildWindows) {
    if (-not $hasWindowsScaffold) {
      Write-Host 'Skipping Windows build: Windows scaffold files are missing.'
    }
    else {
      Invoke-CheckedFlutter @('config', '--enable-windows-desktop')
      $windowsArgs = @(
        'build',
        'windows',
        '--release',
        "--target=lib/main_$Flavor.dart",
        "--dart-define-from-file=$envFile"
      )
      Invoke-CheckedFlutter -Arguments $windowsArgs
    }
  }
}
finally {
  Pop-Location
}
