# Lance l'app sur un téléphone ARM64 (ex. Pixel) — évite de compiler x86/arm inutiles.
# Usage : .\scripts\run_android_device.ps1
Set-Location $PSScriptRoot\..
flutter run --target-platform android-arm64 @args
