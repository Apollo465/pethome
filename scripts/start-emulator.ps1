# 从命令行启动 HarmonyOS 本地模拟器。
#
# DevEco Studio 的 Device Manager 实际执行的是：
#   Emulator.exe -hvd "<实例名>" -path <deployed 目录> -t trace_<pid>_commandPipe -imageRoot <SDK 目录>
#
# 其中 -t 指定一个命名管道，模拟器启动时会去连它；管道不存在时模拟器会静默退出，
# 所以这里自己创建一个同名管道当服务端，并一直读走模拟器写过来的数据，保持连接不积压。
#
# 用法：powershell -ExecutionPolicy Bypass -File scripts\start-emulator.ps1

param(
    [string]$Hvd = 'nova 16 Pro',
    [string]$EmulatorExe = "$env:LOCALAPPDATA\Huawei\DevEco Studio\tools\emulator\Emulator.exe",
    [string]$DeployedPath = "$env:LOCALAPPDATA\Huawei\Emulator\deployed",
    [string]$ImageRoot = "$env:LOCALAPPDATA\Huawei\Sdk",
    [switch]$Visible
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $EmulatorExe)) { throw "找不到模拟器可执行文件：$EmulatorExe" }
if (-not (Test-Path $DeployedPath)) { throw "找不到模拟器实例目录：$DeployedPath" }

$pipeName = "trace_$PID" + "_commandPipe"
Write-Host "创建 trace 管道：$pipeName"

$server = New-Object System.IO.Pipes.NamedPipeServerStream(
    $pipeName,
    [System.IO.Pipes.PipeDirection]::InOut,
    1,
    [System.IO.Pipes.PipeTransmissionMode]::Byte,
    [System.IO.Pipes.PipeOptions]::Asynchronous)

# 注意：Start-Process 的 -ArgumentList 传数组时不会自动给带空格的参数加引号，
# "nova 16 Pro" 会被拆成两个参数，模拟器直接报 "Unable to start the emulator"。
# 所以这里拼成一行并手动加引号。
$argLine = '-hvd "{0}" -path "{1}" -t {2} -imageRoot "{3}"' -f $Hvd, $DeployedPath, $pipeName, $ImageRoot
Write-Host ("启动：{0} {1}" -f $EmulatorExe, $argLine)

if ($Visible) {
    $proc = Start-Process -FilePath $EmulatorExe -ArgumentList $argLine -PassThru
} else {
    $proc = Start-Process -FilePath $EmulatorExe -ArgumentList $argLine -PassThru -WindowStyle Hidden
}

Write-Host "等待模拟器连接 trace 管道（pid=$($proc.Id)）..."
$server.WaitForConnection()
Write-Host "模拟器已连接，管道保持开启中。按 Ctrl+C 结束本脚本会同时断开追踪管道。"

$buffer = New-Object byte[] 8192
try {
    while ($true) {
        $read = $server.Read($buffer, 0, $buffer.Length)
        if ($read -le 0) { break }
    }
} catch {
    Write-Host "管道关闭：$($_.Exception.Message)"
} finally {
    $server.Dispose()
}
