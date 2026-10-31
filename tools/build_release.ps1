# Compila el APK de Android y el instalador de Windows (Inno Setup) y ejecuta
# el preflight. Deja todo en distribution\ y el log en distribution\build_release.log.
# Uso: doble clic en tools\build_release.bat  (o: powershell -File tools\build_release.ps1)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $repo 'frontend'
$dist = Join-Path $repo 'distribution'
$log = Join-Path $dist 'build_release.log'

Start-Transcript -Path $log -Force | Out-Null
try {
    function Step($name, [scriptblock]$block) {
        Write-Host "`n=== $name ===" -ForegroundColor Cyan
        & $block
        if ($LASTEXITCODE -ne 0) { throw "Fallo en: $name (exit $LASTEXITCODE)" }
    }

    # Version desde pubspec.yaml (1.0.3+4 -> 1.0.3)
    $versionLine = Select-String -Path (Join-Path $frontend 'pubspec.yaml') -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    $version = ($versionLine.Matches[0].Groups[1].Value.Trim() -split '\+')[0]
    Write-Host "Version: $version"

    # Inno Setup (ISCC.exe)
    $iscc = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $iscc) { throw 'No se encontro ISCC.exe de Inno Setup 6.' }
    Write-Host "ISCC: $iscc"

    # Limpiar solo artefactos de Android/Windows anteriores (se conservan
    # installer.iss, setup_assets y los zips de macOS descargados de Actions)
    Get-ChildItem $dist -File | Where-Object {
        $_.Extension -in '.apk', '.exe' -or $_.Name -eq 'checksums.sha256'
    } | Remove-Item -Force

    Push-Location $frontend
    try {
        Step 'flutter clean'               { flutter clean }
        Step 'flutter pub get'             { flutter pub get }
        Step 'flutter build apk --release' { flutter build apk --release }
        Step 'flutter build windows --release' { flutter build windows --release }
    } finally { Pop-Location }

    # Si Gradle no dejo el APK en distribution\, copiarlo con el nombre estandar
    if (-not (Get-ChildItem $dist -Filter *.apk -ErrorAction SilentlyContinue)) {
        $apk = Join-Path $frontend 'build\app\outputs\flutter-apk\app-release.apk'
        if (-not (Test-Path $apk)) { throw 'No se encontro app-release.apk.' }
        Copy-Item $apk (Join-Path $dist "BDJ_Studio_Sample_Pad_$version.apk")
    }

    Push-Location $dist
    try {
        Step 'Inno Setup' { & $iscc "/DMyAppVersion=$version" 'installer.iss' }
    } finally { Pop-Location }

    Push-Location $repo
    try {
        $py = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { 'py' }
        Step 'Preflight' { & $py 'tools\preflight_release.py' '--write-checksums' }
    } finally { Pop-Location }

    Write-Host "`nLISTO. Artefactos en $dist" -ForegroundColor Green
    Get-ChildItem $dist -File | Format-Table Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}} -AutoSize
}
catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    exit 1
}
finally {
    Stop-Transcript | Out-Null
}
