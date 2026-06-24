# Crée le keystore release et android/key.properties pour SPIRIT-LIVRAISON.
# À lancer une seule fois avant le premier build release signé.

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AndroidDir = Join-Path $Root "android"
$Keystore = Join-Path $AndroidDir "spirit-livraison-release.jks"
$KeyProps = Join-Path $AndroidDir "key.properties"
$KeyAlias = "spirit-livraison"
$ValidityDays = 10000

function Find-Keytool {
    $javaHome = $env:JAVA_HOME
    if ($javaHome -and (Test-Path (Join-Path $javaHome "bin\keytool.exe"))) {
        return Join-Path $javaHome "bin\keytool.exe"
    }
    $studioJbr = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    if (Test-Path $studioJbr) { return $studioJbr }
    $keytool = Get-Command keytool -ErrorAction SilentlyContinue
    if ($keytool) { return $keytool.Source }
    throw "keytool introuvable. Installez le JDK ou définissez JAVA_HOME."
}

if (Test-Path $Keystore) {
    Write-Host "Keystore déjà présent : $Keystore"
    Write-Host "Supprimez-le manuellement si vous souhaitez en recréer un."
    exit 0
}

if (Test-Path $KeyProps) {
    Write-Host "key.properties existe déjà : $KeyProps"
    exit 0
}

Write-Host "=== Configuration signature release Android ==="
Write-Host ""
Write-Host "Conservez le keystore et les mots de passe en lieu sûr."
Write-Host "Sans eux, vous ne pourrez plus publier de mises à jour sur le même identifiant d'app."
Write-Host ""

$storePass = Read-Host "Mot de passe du keystore (min. 6 caractères)" -AsSecureString
$storePassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePass)
)
if ($storePassPlain.Length -lt 6) {
    throw "Le mot de passe du keystore doit contenir au moins 6 caractères."
}

$keyPassChoice = Read-Host "Utiliser le même mot de passe pour la clé ? (O/n)"
$keyPassPlain = if ($keyPassChoice -match '^[nN]') {
    $keyPass = Read-Host "Mot de passe de la clé" -AsSecureString
    [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPass)
    )
} else {
    $storePassPlain
}

$keytool = Find-Keytool
$dname = "CN=SPIRIT-LIVRAISON, OU=Mobile, O=Spirit, L=Unknown, ST=Unknown, C=FR"

& $keytool -genkeypair `
    -v `
    -keystore $Keystore `
    -alias $KeyAlias `
    -keyalg RSA `
    -keysize 2048 `
    -validity $ValidityDays `
    -storepass $storePassPlain `
    -keypass $keyPassPlain `
    -dname $dname

@"
storePassword=$storePassPlain
keyPassword=$keyPassPlain
keyAlias=$KeyAlias
storeFile=spirit-livraison-release.jks
"@ | Set-Content -Path $KeyProps -Encoding ascii

Write-Host ""
Write-Host "Keystore  : $Keystore"
Write-Host "Config    : $KeyProps"
Write-Host ""
Write-Host "Sauvegardez ces fichiers hors du dépôt git (clé USB, coffre-fort, etc.)."
Write-Host "Build APK : .\scripts\build_apk.ps1"
