param(
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$AnonKey = $env:SUPABASE_ANON_KEY,
  [switch]$Release
)

# Script: build_apk_and_install.ps1
# Usage examples:
#   .\build_apk_and_install.ps1 -SupabaseUrl "https://..." -AnonKey "key"    # builds debug and installs
#   .\build_apk_and_install.ps1 -Release -SupabaseUrl "..." -AnonKey "..."  # builds release

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "flutter not found in PATH. Open Flutter SDK and add to PATH or run from Android Studio terminal."; exit 1
}

if (-not $SupabaseUrl) {
  # Default Supabase URL provided by user; change here if you want a different default.
  $SupabaseUrl = 'https://tneipiyfgcrzlwkhnokg.supabase.co'
}

if (-not $AnonKey) {
  # Default to the provided publishable/anon key if not supplied via param or env.
  $AnonKey = $env:SUPABASE_ANON_KEY
  if (-not $AnonKey) {
    $AnonKey = 'sb_publishable_TBhW933ecRFISm8yVBZq2g_h2RwVzs4'
    Write-Host "Using embedded SUPABASE_ANON_KEY from script (change script to avoid committing secrets)."
  }
}

Set-Location "$PSScriptRoot\.."
Set-Location (Resolve-Path '.')

Write-Host "Running flutter pub get..."
flutter pub get

Write-Host "Running flutter analyze..."
flutter analyze

if ($Release) {
  Write-Host "Building release APK..."
  flutter build apk --release --dart-define=SUPABASE_URL="$SupabaseUrl" --dart-define=SUPABASE_ANON_KEY="$AnonKey"
  $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
} else {
  Write-Host "Building debug APK..."
  flutter build apk --debug --dart-define=SUPABASE_URL="$SupabaseUrl" --dart-define=SUPABASE_ANON_KEY="$AnonKey"
  $apkPath = "build\app\outputs\flutter-apk\app-debug.apk"
}

if (-not (Test-Path $apkPath)) {
  Write-Error "APK not found at $apkPath. Build may have failed."; exit 1
}

# Install via ADB
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  Write-Warning "ADB not found in PATH. Install Android Platform Tools or open Android Studio and use Device File Explorer." 
  Write-Host "APK is at: $apkPath"; exit 0
}

Write-Host "Installing APK: $apkPath"
adb devices
adb install -r $apkPath

Write-Host "Done. If the app doesn't open automatically, launch it from the device."