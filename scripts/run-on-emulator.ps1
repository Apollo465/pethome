# Build, install and launch PetHome on the running emulator or a connected device.
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\run-on-emulator.ps1

$ErrorActionPreference = 'Stop'

$ideRoot = 'C:\Program Files\Huawei\DevEco Studio'
if (-not (Test-Path $ideRoot)) {
    $ideRoot = "$env:LOCALAPPDATA\Huawei\DevEco Studio"
}

$env:NODE_HOME = "$ideRoot\tools\node"
$env:DEVECO_SDK_HOME = "$ideRoot\sdk"
$env:JAVA_HOME = "$ideRoot\jbr"
$env:HVIGOR_USER_HOME = "$env:LOCALAPPDATA\Huawei\hvigor_home"
$env:Path = "$ideRoot\tools\node;$ideRoot\jbr\bin;" + $env:Path

$hvigorw = "$ideRoot\tools\hvigor\bin\hvigorw.bat"
$hdc = "$ideRoot\sdk\default\openharmony\toolchains\hdc.exe"
$projectRoot = Split-Path -Parent $PSScriptRoot
$bundleName = 'com.pethome.xiaohong'
$abilityName = 'EntryAbility'

Write-Host '[1/4] Checking connected devices ...' -ForegroundColor Cyan
$targets = & $hdc list targets
Write-Host ($targets -join ' ')
if ($targets -match '\[Empty\]' -or [string]::IsNullOrWhiteSpace(($targets -join ''))) {
    Write-Host 'No device found. Start the emulator in DevEco Studio first, or plug in a phone.' -ForegroundColor Yellow
    exit 1
}

Write-Host '[2/4] Building HAP ...' -ForegroundColor Cyan
Push-Location $projectRoot
try {
    & $hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
    if ($LASTEXITCODE -ne 0) { throw 'hvigor build failed' }
}
finally {
    Pop-Location
}

$hap = Join-Path $projectRoot 'entry\build\default\outputs\default\entry-default-unsigned.hap'
if (-not (Test-Path $hap)) {
    $found = Get-ChildItem (Join-Path $projectRoot 'entry\build') -Recurse -Filter '*.hap' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $found) { throw 'No hap artifact found' }
    $hap = $found.FullName
}

Write-Host "[3/4] Installing $hap" -ForegroundColor Cyan
# The emulator accepts unsigned HAPs. A real device needs a signing config from DevEco Studio.
& $hdc install -r $hap

Write-Host '[4/4] Launching app ...' -ForegroundColor Cyan
& $hdc shell aa start -a $abilityName -b $bundleName

Write-Host 'Done. PetHome is running.' -ForegroundColor Green
