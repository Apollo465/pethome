# Build a release HAP and sign it with the AGC release certificate.
#
# Build only (self check, no signing):
#   powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 -BuildOnly
#
# Build and sign (after creating the app in AppGallery Connect and downloading
# the release certificate + profile):
#   powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 `
#     -Keystore signing\release.p12 -KeystorePwd YOUR_STORE_PWD `
#     -KeyPwd YOUR_KEY_PWD -KeyAlias debugKey `
#     -Cert signing\release.cer -Profile signing\release.p7b
#
# Note: keep this file ASCII only. Windows PowerShell 5.1 reads .ps1 files
# without a BOM as ANSI, which corrupts non-ASCII text on Chinese systems.

param(
    [string]$Keystore,
    [string]$KeystorePwd,
    [string]$KeyPwd,
    [string]$KeyAlias = 'debugKey',
    [string]$Cert,
    [string]$Profile,
    [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'

$ideRoot = 'C:\Program Files\Huawei\DevEco Studio'
if (-not (Test-Path $ideRoot)) { $ideRoot = "$env:LOCALAPPDATA\Huawei\DevEco Studio" }

$env:NODE_HOME = "$ideRoot\tools\node"
$env:DEVECO_SDK_HOME = "$ideRoot\sdk"
$env:JAVA_HOME = "$ideRoot\jbr"
$env:HVIGOR_USER_HOME = "$env:LOCALAPPDATA\Huawei\hvigor_home"
$env:Path = "$ideRoot\tools\node;$ideRoot\jbr\bin;" + $env:Path

$projectRoot = Split-Path -Parent $PSScriptRoot
$hvigorw = "$ideRoot\tools\hvigor\bin\hvigorw.bat"
$signTool = "$ideRoot\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar"
$java = "$ideRoot\jbr\bin\java.exe"
$outDir = Join-Path $projectRoot 'entry\build\default\outputs\default'
$unsigned = Join-Path $outDir 'entry-default-unsigned.hap'

Write-Host '[1/3] Building release HAP ...' -ForegroundColor Cyan
Push-Location $projectRoot
try {
    & $hvigorw assembleHap --mode module -p product=default -p buildMode=release --no-daemon
    if ($LASTEXITCODE -ne 0) { throw 'hvigor build failed' }
}
finally { Pop-Location }

if (-not (Test-Path $unsigned)) { throw "Artifact not found: $unsigned" }
Write-Host "      artifact: $unsigned" -ForegroundColor Green

if ($BuildOnly -or -not $Keystore) {
    Write-Host '[2/3] No signing arguments, skip signing.' -ForegroundColor Yellow
    Write-Host '      Pass -Keystore / -Cert / -Profile to produce a signed release HAP.' -ForegroundColor Yellow
    exit 0
}

foreach ($f in @($Keystore, $Cert, $Profile)) {
    if (-not (Test-Path $f)) { throw "File not found: $f" }
}
if (-not (Test-Path $signTool)) { throw "hap-sign-tool not found: $signTool" }

$signed = Join-Path $outDir 'entry-default-signed.hap'
Write-Host '[2/3] Signing with the release certificate ...' -ForegroundColor Cyan

$signArgs = @(
    '-jar', $signTool, 'sign-app',
    '-mode', 'localSign',
    '-keyAlias', $KeyAlias,
    '-signAlg', 'SHA256withECDSA',
    '-appCertFile', (Resolve-Path $Cert).Path,
    '-profileFile', (Resolve-Path $Profile).Path,
    '-keystoreFile', (Resolve-Path $Keystore).Path,
    '-inFile', $unsigned,
    '-outFile', $signed
)
if ($KeyPwd) { $signArgs += @('-keyPwd', $KeyPwd) }
if ($KeystorePwd) { $signArgs += @('-keystorePwd', $KeystorePwd) }

& $java @signArgs
if ($LASTEXITCODE -ne 0) { throw 'Signing failed. Check certificate, profile and passwords.' }

Write-Host '[3/3] Done.' -ForegroundColor Green
Write-Host "      signed HAP: $signed" -ForegroundColor Green
Write-Host '      Verify module.json inside the HAP: debug=false, buildMode=release.' -ForegroundColor DarkGray
