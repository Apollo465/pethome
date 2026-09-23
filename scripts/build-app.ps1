# Build a SUBMITTABLE App Pack (.app) for AppGallery Connect.
#
# 背景：
#   * AGC 的「软件包管理 → 上传」只接受 APP 格式（.app），不接受 .hap。
#   * hvigor 的 assembleApp 需要 DevEco 加密格式的签名口令（明文会被拒绝：
#     "The length of the storePassword or keyPassword field is less than 32"），
#     所以命令行出的 .app 里内层 HAP 是未签名的，AGC 解析会一直卡在"处理中"。
#   * 本脚本：先用 hap-sign-tool 签好 HAP，再把签好的 HAP 装回 App 包，
#     最后用同一套证书/Profile 给 App 包签名。pack.info / pac.json 不含内层
#     HAP 的摘要，所以替换 HAP 是安全的。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\build-app.ps1 `
#     -Keystore signing\release.p12 -KeystorePwd *** -KeyPwd *** `
#     -KeyAlias debugKey -Cert signing\release.cer -Profile signing\release.p7b
#
# Note: keep this file ASCII only (PowerShell 5.1 reads non-BOM .ps1 as ANSI).

param(
    [Parameter(Mandatory = $true)][string]$Keystore,
    [Parameter(Mandatory = $true)][string]$KeystorePwd,
    [Parameter(Mandatory = $true)][string]$KeyPwd,
    [string]$KeyAlias = 'debugKey',
    [Parameter(Mandatory = $true)][string]$Cert,
    [Parameter(Mandatory = $true)][string]$Profile,
    [string]$OutName = 'pethome-signed.app'
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

foreach ($f in @($Keystore, $Cert, $Profile)) {
    if (-not (Test-Path $f)) { throw "File not found: $f" }
}
if (-not (Test-Path $signTool)) { throw "hap-sign-tool not found: $signTool" }

function Invoke-SignApp([string]$inFile, [string]$outFile) {
    $signArgs = @(
        '-jar', $signTool, 'sign-app',
        '-mode', 'localSign',
        '-keyAlias', $KeyAlias,
        '-signAlg', 'SHA256withECDSA',
        '-appCertFile', (Resolve-Path $Cert).Path,
        '-profileFile', (Resolve-Path $Profile).Path,
        '-keystoreFile', (Resolve-Path $Keystore).Path,
        '-inFile', $inFile,
        '-outFile', $outFile,
        '-keyPwd', $KeyPwd,
        '-keystorePwd', $KeystorePwd
    )
    & $java @signArgs
    if ($LASTEXITCODE -ne 0) { throw "Signing failed: $inFile" }
}

# 注意顺序：assembleApp 会重建模块产物目录，所以必须先出骨架、再签 HAP，
# 否则签好的 HAP 会被这一步清掉。
Write-Host '[1/4] Building App Pack skeleton ...' -ForegroundColor Cyan
Push-Location $projectRoot
try {
    & $hvigorw assembleApp --mode project -p product=default -p buildMode=release --no-daemon | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'hvigor assembleApp failed' }
}
finally { Pop-Location }

$appOutDir = Join-Path $projectRoot 'build\outputs\default'
$packInfo = Join-Path $appOutDir 'pack.info'
$pacJson = Join-Path $appOutDir 'pac.json'
if (-not (Test-Path $packInfo)) { throw "pack.info not found: $packInfo" }
if (-not (Test-Path $pacJson)) { throw "pac.json not found: $pacJson" }

Write-Host '[2/4] Building release HAP (signed) ...' -ForegroundColor Cyan
$hapScript = Join-Path $PSScriptRoot 'build-release.ps1'
$signedHap = Join-Path $projectRoot 'entry\build\default\outputs\default\entry-default-signed.hap'
& powershell -ExecutionPolicy Bypass -File $hapScript -Keystore $Keystore -KeystorePwd $KeystorePwd `
    -KeyPwd $KeyPwd -KeyAlias $KeyAlias -Cert $Cert -Profile $Profile | Out-Null
if (-not (Test-Path $signedHap)) { throw "Signed HAP not found: $signedHap" }
Write-Host "      $signedHap" -ForegroundColor Green

Write-Host '[3/4] Repacking App Pack with the signed HAP ...' -ForegroundColor Cyan
$stage = Join-Path $projectRoot 'build\apppack'
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item $pacJson $stage -Force
Copy-Item $packInfo $stage -Force
Copy-Item $signedHap (Join-Path $stage 'entry-default.hap') -Force

$unsignedApp = Join-Path $appOutDir 'pethome-repacked-unsigned.app'
if (Test-Path $unsignedApp) { Remove-Item -LiteralPath $unsignedApp -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($unsignedApp, 'Create')
try {
    foreach ($n in @('pac.json', 'pack.info', 'entry-default.hap')) {
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, (Join-Path $stage $n), $n, [System.IO.Compression.CompressionLevel]::Optimal)
    }
}
finally { $zip.Dispose() }

Write-Host '[4/4] Signing App Pack ...' -ForegroundColor Cyan
$signedApp = Join-Path $appOutDir $OutName
Invoke-SignApp $unsignedApp $signedApp

Write-Host "      signed App Pack: $signedApp" -ForegroundColor Green
