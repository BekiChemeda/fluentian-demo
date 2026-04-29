param(
    [string]$DeviceId = "emulator-5554",
    [string]$ApiBaseUrl = "http://10.0.2.2:8000",
    [string]$Drive = "F:"
)

$ErrorActionPreference = "Stop"

$driveName = $Drive.TrimEnd(":")
$driveRoot = "$driveName`:"
$userRoot = $env:USERPROFILE

if (-not (Test-Path -LiteralPath $userRoot)) {
    throw "USERPROFILE path was not found: $userRoot"
}

$existingSubst = cmd /c subst | Select-String -Pattern ("^{0}\\:" -f [regex]::Escape($driveName))
if (-not $existingSubst) {
    cmd /c "subst $driveRoot `"$userRoot`""
}

$mobileDir = Join-Path $driveRoot "bt\fl\mobile"
$flutterBat = Join-Path $driveRoot "flutter\bin\flutter.bat"
$pubCache = Join-Path $driveRoot "AppData\Local\Pub\Cache"

if (-not (Test-Path -LiteralPath $mobileDir)) {
    throw "Mapped mobile directory was not found: $mobileDir"
}

if (-not (Test-Path -LiteralPath $flutterBat)) {
    throw "Mapped Flutter executable was not found: $flutterBat"
}

$env:PUB_CACHE = $pubCache
$env:FLUTTER_ROOT = Join-Path $driveRoot "flutter"

Set-Location -LiteralPath $mobileDir
& $flutterBat run -d $DeviceId --dart-define=API_BASE_URL=$ApiBaseUrl
