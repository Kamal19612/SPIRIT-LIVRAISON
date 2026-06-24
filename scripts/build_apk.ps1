# Build APK release (split par architecture) pour SPIRIT-LIVRAISON.
# Nécessite ~5-10 Go d'espace disque libre sur C:

param(
    [switch]$Universal,
    [switch]$SkipPubGet
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$KeyProps = Join-Path $Root "android\key.properties"
$OutDir = Join-Path $Root "releases"

Set-Location $Root

if (-not (Test-Path $KeyProps)) {
    Write-Host "Avertissement : android\key.properties absent — APK signé avec la clé debug."
    Write-Host "Pour une distribution réelle : .\scripts\setup_release_signing.ps1"
    Write-Host ""
}

$versionLine = Select-String -Path (Join-Path $Root "pubspec.yaml") -Pattern '^version:\s*(\S+)' |
    ForEach-Object { $_.Matches[0].Groups[1].Value }
$versionName = ($versionLine -split '\+')[0]

if (-not $SkipPubGet) {
    Write-Host "==> flutter pub get"
    flutter pub get
}

if ($Universal) {
    Write-Host "==> flutter build apk --release (APK universel, plus lourd)"
    flutter build apk --release
    $src = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
    $dest = Join-Path $OutDir "SPIRIT-LIVRAISON-v$versionName-universal.apk"
} else {
    Write-Host "==> flutter build apk --release --split-per-abi"
    flutter build apk --release --split-per-abi
    $apkDir = Join-Path $Root "build\app\outputs\flutter-apk"
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

    $copied = @()
    foreach ($abi in @("arm64-v8a", "armeabi-v7a", "x86_64")) {
        $src = Join-Path $apkDir "app-$abi-release.apk"
        if (Test-Path $src) {
            $dest = Join-Path $OutDir "SPIRIT-LIVRAISON-v$versionName-$abi.apk"
            Copy-Item -Force $src $dest
            $copied += $dest
        }
    }

    Write-Host ""
    Write-Host "APK prêts dans releases\ :"
    foreach ($path in $copied) {
        $sizeMb = [math]::Round((Get-Item $path).Length / 1MB, 1)
        Write-Host "  $path  ($sizeMb Mo)"
    }
    Write-Host ""
    Write-Host "Pour la plupart des téléphones récents, distribuez : SPIRIT-LIVRAISON-v$versionName-arm64-v8a.apk"
    exit 0
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Copy-Item -Force $src $dest
$sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
Write-Host ""
Write-Host "APK prêt : $dest  ($sizeMb Mo)"
