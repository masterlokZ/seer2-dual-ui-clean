<#
.SYNOPSIS
    Compile-ShellSwf: Rapid In-Place Compiler for Test Shell Runtime
.DESCRIPTION
    Rapidly compiles ActionScript modifications from dev-src into the local test shell's
    CoreDLL.swf and FramePlayer.swf via Scoped importScript, enabling instant 'R' hot-reloads.
.PARAMETER ShellRoot
    Path to lightweight test harness / shell. Default: D:\seer2-lightweight-harness
.PARAMETER Target
    Component to compile: 'all', 'core', or 'frame'. Default: 'all'.
#>

[CmdletBinding()]
param(
    [string]$ShellRoot = 'D:\seer2-lightweight-harness',
    [ValidateSet('all', 'core', 'frame')][string]$Target = 'all'
)

$ErrorActionPreference = 'Stop'

$javaExe = 'D:\swf-work-622\downloads\temurin8-jre\runtime\jdk8u502-b07-jre\bin\java.exe'
$ffdecJar = 'D:\s2-ui\tools\ffdec\ffdec.jar'
if (-not (Test-Path -LiteralPath $ffdecJar)) {
    $ffdecJar = 'D:\codex-reusable-tools\seer-uclient-generic-renderer\toolchain\ffdec.jar'
}

$devSrc = Join-Path $ShellRoot 'dev-src'
$coreDevSrc = Join-Path $devSrc 'CoreDLL'
$frameDevSrc = Join-Path $devSrc 'FramePlayer'

$coreDecryptedSwf = Join-Path $ShellRoot 'CoreDLL.decrypted.swf'
$coreWrappedSwf = Join-Path $ShellRoot 'CoreDLL.swf'
$framePlayerSwf = Join-Path $ShellRoot 'FramePlayer.swf'

Write-Host '================================================================================' -ForegroundColor Cyan
Write-Host '  Compile-ShellSwf: Test Shell Rapid Local Compiler (Hot-Sync)' -ForegroundColor Cyan
Write-Host '================================================================================' -ForegroundColor Cyan

$swTotal = [System.Diagnostics.Stopwatch]::StartNew()

# 1. Pre-Flight AST Syntax Check
Write-Host "`n[1/3] 执行 ActionScript 3 AST 语法检测..." -ForegroundColor Yellow
$astScript = 'D:\s2-ui\toolchain\Test-ActionScriptAST.ps1'
if (Test-Path -LiteralPath $astScript) {
    $checkDirs = [System.Collections.Generic.List[string]]::new()
    if ($Target -eq 'all' -or $Target -eq 'core') {
        if (Test-Path -LiteralPath $coreDevSrc) { $checkDirs.Add($coreDevSrc) }
    }
    if ($Target -eq 'all' -or $Target -eq 'frame') {
        if (Test-Path -LiteralPath $frameDevSrc) { $checkDirs.Add($frameDevSrc) }
    }
    if ($checkDirs.Count -gt 0) {
        & pwsh.exe -NoLogo -NoProfile -File $astScript -Path ($checkDirs -join ',') -Recurse -Quiet
        if ($LASTEXITCODE -ne 0) {
            throw "AST 语法检测未通过! 终止编译以保护运行时稳定性。"
        }
        Write-Host "  [OK] AST 语法检测通过" -ForegroundColor Green
    }
}

# 2. FramePlayer Scoped importScript
if ($Target -eq 'all' -or $Target -eq 'frame') {
    Write-Host "`n[2/3] 编译 FramePlayer (Scoped importScript)..." -ForegroundColor Yellow
    $frameImportDir = Join-Path $ShellRoot 'dev-src\FramePlayer'
    $frameTmpSwf = Join-Path $ShellRoot 'FramePlayer.tmp.swf'

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $javaExe
    $psi.ArgumentList.Add("-Xmx4g")
    $psi.ArgumentList.Add("-Djava.awt.headless=true")
    $psi.ArgumentList.Add("-jar")
    $psi.ArgumentList.Add($ffdecJar)
    $psi.ArgumentList.Add("-onerror")
    $psi.ArgumentList.Add("abort")
    $psi.ArgumentList.Add("-importScript")
    $psi.ArgumentList.Add($framePlayerSwf)
    $psi.ArgumentList.Add($frameTmpSwf)
    $psi.ArgumentList.Add($frameImportDir)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    if ($p.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $frameTmpSwf)) {
        $err = $p.StandardError.ReadToEnd()
        throw "FramePlayer 注入编译失败 (ExitCode: $($p.ExitCode)): $err"
    }

    $tmpItem = Get-Item -LiteralPath $frameTmpSwf
    if ($tmpItem.Length -lt 1400000) {
        Remove-Item -LiteralPath $frameTmpSwf -Force
        throw "FramePlayer 产物体积异常 ($($tmpItem.Length) 字节)，触发防空壳阻断保护!"
    }

    Move-Item -LiteralPath $frameTmpSwf -Destination $framePlayerSwf -Force
    Write-Host "  [OK] FramePlayer.swf 更新成功! 体积: $($tmpItem.Length) 字节" -ForegroundColor Green
}

# 3. CoreDLL Scoped importScript & Packaging
if ($Target -eq 'all' -or $Target -eq 'core') {
    Write-Host "`n[3/3] 编译 CoreDLL (Scoped importScript + 7x0x00+zlib 封包)..." -ForegroundColor Yellow
    $coreImportDir = Join-Path $ShellRoot 'dev-src\CoreDLL'
    $coreTmpPlainSwf = Join-Path $ShellRoot 'CoreDLL.decrypted.tmp.swf'

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $javaExe
    $psi.ArgumentList.Add("-Xmx6g")
    $psi.ArgumentList.Add("-Djava.awt.headless=true")
    $psi.ArgumentList.Add("-jar")
    $psi.ArgumentList.Add($ffdecJar)
    $psi.ArgumentList.Add("-onerror")
    $psi.ArgumentList.Add("abort")
    $psi.ArgumentList.Add("-importScript")
    $psi.ArgumentList.Add($coreDecryptedSwf)
    $psi.ArgumentList.Add($coreTmpPlainSwf)
    $psi.ArgumentList.Add($coreImportDir)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    if ($p.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $coreTmpPlainSwf)) {
        $err = $p.StandardError.ReadToEnd()
        throw "CoreDLL 注入编译失败 (ExitCode: $($p.ExitCode)): $err"
    }

    $tmpPlainItem = Get-Item -LiteralPath $coreTmpPlainSwf
    if ($tmpPlainItem.Length -lt 5000000) {
        Remove-Item -LiteralPath $coreTmpPlainSwf -Force
        throw "CoreDLL 产物体积异常 ($($tmpPlainItem.Length) 字节)，触发防空壳阻断保护!"
    }

    Move-Item -LiteralPath $coreTmpPlainSwf -Destination $coreDecryptedSwf -Force

    # Official 7x0x00+zlib Level 9 Compression
    $plainBytes = [System.IO.File]::ReadAllBytes($coreDecryptedSwf)
    $ms = [System.IO.MemoryStream]::new()
    for ($b = 0; $b -lt 7; $b++) { $ms.WriteByte(0) }
    $zs = [System.IO.Compression.ZLibStream]::new($ms, [System.IO.Compression.CompressionLevel]::SmallestSize)
    $zs.Write($plainBytes, 0, $plainBytes.Length)
    $zs.Dispose()
    $wrappedBytes = $ms.ToArray()
    [System.IO.File]::WriteAllBytes($coreWrappedSwf, $wrappedBytes)

    # Roundtrip check
    $decompStream = [System.IO.MemoryStream]::new()
    $compStream = [System.IO.MemoryStream]::new($wrappedBytes, 7, $wrappedBytes.Length - 7)
    $decZLib = [System.IO.Compression.ZLibStream]::new($compStream, [System.IO.Compression.CompressionMode]::Decompress)
    $decZLib.CopyTo($decompStream)
    $decZLib.Dispose()
    $roundtripBytes = $decompStream.ToArray()

    if ($roundtripBytes.Length -ne $plainBytes.Length) {
        throw "CoreDLL 封包回环校验失败! 解压大小不一致 ($($roundtripBytes.Length) vs $($plainBytes.Length))"
    }

    Write-Host "  [OK] CoreDLL.decrypted.swf: $($plainBytes.Length) 字节" -ForegroundColor Green
    Write-Host "  [OK] CoreDLL.swf (封包+回环通过): $($wrappedBytes.Length) 字节" -ForegroundColor Green
}

$swTotal.Stop()
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  Hot-Sync 编译成功! 耗时: $([math]::Round($swTotal.Elapsed.TotalSeconds, 2)) 秒" -ForegroundColor Green
Write-Host "  测试壳提示: 若 Flash 播放器已打开，在窗口内按键盘 'R' 即可秒级热重载!" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
