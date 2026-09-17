<#
.SYNOPSIS
    Sync-SourceToShell: Baseline UI Source (D:\s2-ui) -> Test Shell (D:\seer2-lightweight-harness)
.DESCRIPTION
    Synchronizes the baseline source code and reference binaries from the D:\s2-ui repository
    into the battle test shell development tree (dev-src), configures harness-config.json,
    and optionally executes Hot-Sync compilation to make the shell immediately testable.
.PARAMETER SourceRoot
    Path to pristine UI source repository. Default: D:\s2-ui
.PARAMETER ShellRoot
    Path to lightweight test harness / shell. Default: D:\seer2-lightweight-harness
.PARAMETER HotSync
    Automatically compile/inject dev-src files into local shell SWFs via Scoped importScript.
.PARAMETER Quiet
    Suppress verbose progress logging.
#>

[CmdletBinding()]
param(
    [string]$SourceRoot = 'D:\s2-ui',
    [string]$ShellRoot = 'D:\seer2-lightweight-harness',
    [switch]$HotSync,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$javaExe = 'D:\swf-work-622\downloads\temurin8-jre\runtime\jdk8u502-b07-jre\bin\java.exe'
$ffdecJar = Join-Path $SourceRoot 'tools\ffdec\ffdec.jar'
if (-not (Test-Path -LiteralPath $ffdecJar)) {
    $ffdecJar = 'D:\codex-reusable-tools\seer-uclient-generic-renderer\toolchain\ffdec.jar'
}

Write-Host '================================================================================' -ForegroundColor Cyan
Write-Host '  Seer2 Dual-UI Toolchain: Sync-SourceToShell (Source -> Shell)' -ForegroundColor Cyan
Write-Host '================================================================================' -ForegroundColor Cyan
Write-Host "源码基线目录 (Source): $SourceRoot"
Write-Host "测试壳工作区 (Shell):  $ShellRoot"

# 1. Verify Source Paths
$sourceCoreArena = Join-Path $SourceRoot 'CoreDLL\scripts\scripts\com\taomee\seer2\app\arena'
$sourceFramePetLayer = Join-Path $SourceRoot 'FramePlayer\scripts\scripts\animation\layer\PetLayer.as'
$sourceCoreDecryptedSwf = Join-Path $SourceRoot 'CoreDLL\CoreDLL.decrypted.swf'
$sourceFramePlayerSwf = Join-Path $SourceRoot 'FramePlayer\FramePlayer.swf'

if (-not (Test-Path -LiteralPath $sourceCoreArena)) {
    throw "CoreDLL arena source tree not found: $sourceCoreArena"
}
if (-not (Test-Path -LiteralPath $sourceFramePetLayer)) {
    throw "FramePlayer PetLayer.as source not found: $sourceFramePetLayer"
}
if (-not (Test-Path -LiteralPath $sourceCoreDecryptedSwf)) {
    throw "CoreDLL decrypted baseline SWF not found: $sourceCoreDecryptedSwf"
}
if (-not (Test-Path -LiteralPath $sourceFramePlayerSwf)) {
    throw "FramePlayer baseline SWF not found: $sourceFramePlayerSwf"
}

# 2. Ensure Shell dev-src Workspace Directories
$shellDevSrc = Join-Path $ShellRoot 'dev-src'
$shellCoreArena = Join-Path $shellDevSrc 'CoreDLL\com\taomee\seer2\app\arena'
$shellFrameLayer = Join-Path $shellDevSrc 'FramePlayer\animation\layer'

New-Item -ItemType Directory -Path $shellCoreArena -Force | Out-Null
New-Item -ItemType Directory -Path $shellFrameLayer -Force | Out-Null

Write-Host "`n[步骤 1/4] 同步源码树到测试壳开发目录 (dev-src)..." -ForegroundColor Yellow

# Sync CoreDLL Arena files
$coreFiles = Get-ChildItem -LiteralPath $sourceCoreArena -Recurse -File
$coreCount = 0
foreach ($f in $coreFiles) {
    $rel = $f.FullName.Substring($sourceCoreArena.Length).TrimStart('\', '/')
    $dest = Join-Path $shellCoreArena $rel
    $destDir = [System.IO.Path]::GetDirectoryName($dest)
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    $coreCount++
}
Write-Host "  [OK] 同步 CoreDLL arena 源码: $coreCount 个文件 -> $shellCoreArena" -ForegroundColor Green

# Sync FramePlayer PetLayer.as
$destPetLayer = Join-Path $shellFrameLayer 'PetLayer.as'
Copy-Item -LiteralPath $sourceFramePetLayer -Destination $destPetLayer -Force
Write-Host "  [OK] 同步 FramePlayer PetLayer.as -> $destPetLayer" -ForegroundColor Green

# 3. Sync Reference Binaries to Shell Root
Write-Host "`n[步骤 2/4] 同步参考 SWF 运行组件至测试壳根目录..." -ForegroundColor Yellow
$shellCoreDecryptedSwf = Join-Path $ShellRoot 'CoreDLL.decrypted.swf'
$shellCoreWrappedSwf = Join-Path $ShellRoot 'CoreDLL.swf'
$shellFramePlayerSwf = Join-Path $ShellRoot 'FramePlayer.swf'

Copy-Item -LiteralPath $sourceCoreDecryptedSwf -Destination $shellCoreDecryptedSwf -Force
Copy-Item -LiteralPath $sourceFramePlayerSwf -Destination $shellFramePlayerSwf -Force

# Check / Prepare wrapped CoreDLL.swf for shell
$sourceCoreWrappedSwf = Join-Path $SourceRoot 'CoreDLL\CoreDLL.swf'
if (Test-Path -LiteralPath $sourceCoreWrappedSwf) {
    $header = [System.IO.File]::ReadAllBytes($sourceCoreWrappedSwf)[0..7]
    $isWrapped = ($header[0] -eq 0 -and $header[1] -eq 0 -and $header[2] -eq 0 -and $header[3] -eq 0 -and $header[4] -eq 0 -and $header[5] -eq 0 -and $header[6] -eq 0 -and $header[7] -eq 0x78)
    if ($isWrapped) {
        Copy-Item -LiteralPath $sourceCoreWrappedSwf -Destination $shellCoreWrappedSwf -Force
    } else {
        # Wrap decrypted SWF
        Write-Host "  正在将 CoreDLL 打包为官方 7x0x00+zlib 容器格式..." -ForegroundColor Gray
        $plainBytes = [System.IO.File]::ReadAllBytes($sourceCoreDecryptedSwf)
        $ms = [System.IO.MemoryStream]::new()
        for ($b = 0; $b -lt 7; $b++) { $ms.WriteByte(0) }
        $zs = [System.IO.Compression.ZLibStream]::new($ms, [System.IO.Compression.CompressionLevel]::SmallestSize)
        $zs.Write($plainBytes, 0, $plainBytes.Length)
        $zs.Dispose()
        [System.IO.File]::WriteAllBytes($shellCoreWrappedSwf, $ms.ToArray())
    }
} else {
    $plainBytes = [System.IO.File]::ReadAllBytes($sourceCoreDecryptedSwf)
    $ms = [System.IO.MemoryStream]::new()
    for ($b = 0; $b -lt 7; $b++) { $ms.WriteByte(0) }
    $zs = [System.IO.Compression.ZLibStream]::new($ms, [System.IO.Compression.CompressionLevel]::SmallestSize)
    $zs.Write($plainBytes, 0, $plainBytes.Length)
    $zs.Dispose()
    [System.IO.File]::WriteAllBytes($shellCoreWrappedSwf, $ms.ToArray())
}

Write-Host "  [OK] 测试壳 CoreDLL.decrypted.swf (明文): $((Get-Item -LiteralPath $shellCoreDecryptedSwf).Length) 字节" -ForegroundColor Green
Write-Host "  [OK] 测试壳 CoreDLL.swf (封包):           $((Get-Item -LiteralPath $shellCoreWrappedSwf).Length) 字节" -ForegroundColor Green
Write-Host "  [OK] 测试壳 FramePlayer.swf:             $((Get-Item -LiteralPath $shellFramePlayerSwf).Length) 字节" -ForegroundColor Green

# 4. Update Shell harness-config.json
Write-Host "`n[步骤 3/4] 更新测试壳运行时配置 harness-config.json..." -ForegroundColor Yellow
$configPath = Join-Path $ShellRoot 'harness-config.json'
$cfg = if (Test-Path -LiteralPath $configPath) {
    Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    [PSCustomObject]@{
        engine          = "dual"
        petId           = 1400660
        petPath         = "D:/seer2-x32-hotfix/local-res/skin-mode/fight/1400660.swf"
        action          = "idle"
        groundY         = 375
        autoQuitSeconds = 5
    }
}

$cfg | Add-Member -NotePropertyName 'coreDllPath' -NotePropertyValue ($shellCoreWrappedSwf.Replace('\', '/')) -Force
$cfg | Add-Member -NotePropertyName 'framePlayerPath' -NotePropertyValue ($shellFramePlayerSwf.Replace('\', '/')) -Force

$jsonOutput = $cfg | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($configPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))
Write-Host "  [OK] 已将测试壳 CoreDLL 与 FramePlayer 路径绑定至本地独立运行时" -ForegroundColor Green

# 5. Hot-Sync Compilation (Optional / On-Demand)
if ($HotSync) {
    Write-Host "`n[步骤 4/4] 触发测试壳本地秒级 Hot-Sync 编译..." -ForegroundColor Yellow
    $compileScript = Join-Path $ShellRoot 'Compile-ShellSwf.ps1'
    if (Test-Path -LiteralPath $compileScript) {
        & pwsh.exe -NoLogo -NoProfile -File $compileScript
    } else {
        Write-Host "  [提示] 运行 Compile-ShellSwf 快速重载测试壳本地 SWF。" -ForegroundColor Cyan
    }
} else {
    Write-Host "`n[步骤 4/4] 状态就绪: 源码已同测试壳开发树无缝对接。" -ForegroundColor Green
    Write-Host "  - 编辑位置: $shellDevSrc" -ForegroundColor Cyan
    Write-Host "  - 一键热重载: 编译后在 Flash 播放器中按 'R' 即刻刷新" -ForegroundColor Cyan
    Write-Host "  - 启动测试: pwsh -File $ShellRoot\Test-DualUI.ps1" -ForegroundColor Cyan
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  Sync-SourceToShell 同步圆满完成!" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
