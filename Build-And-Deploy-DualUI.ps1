<#
.SYNOPSIS
    Build-And-Deploy-DualUI: Official Build, Scoped importScript, Roundtrip Verify, and Deployment
.DESCRIPTION
    Compiles verified source code from D:\s2-ui into official dual UI binaries (CoreDLL & FramePlayer)
    following the Scoped importScript minimal replacement paradigm. Enforces AST syntax checks,
    anti-hollow SWF size and symbol assertions, official 7x0x00+zlib level 9 CoreDLL packaging with
    byte-exact roundtrip verification, and synchronized deployment to D:\seer2-x32-hotfix\local-res\skin-mode\.
.PARAMETER SourceRoot
    Path to canonical UI source repository. Default: D:\s2-ui
.PARAMETER ShellRoot
    Path to lightweight test harness / shell. Default: D:\seer2-lightweight-harness
.PARAMETER HotfixRoot
    Path to official hotfix runtime. Default: D:\seer2-x32-hotfix
.PARAMETER Deploy
    Deploy output binaries to official hotfix directory (local-res\skin-mode).
.PARAMETER ForceAll
    Import all arena source files instead of active modified files.
.PARAMETER SkipReadback
    Skip decompilation readback check.
#>

[CmdletBinding()]
param(
    [string]$SourceRoot = 'D:\s2-ui',
    [string]$ShellRoot = 'D:\seer2-lightweight-harness',
    [string]$HotfixRoot = 'D:\seer2-x32-hotfix',
    [switch]$Deploy,
    [switch]$ForceAll,
    [switch]$SkipReadback,
    [switch]$CoreOnly
)

$ErrorActionPreference = 'Stop'

$swTotal = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host '================================================================================' -ForegroundColor Cyan
Write-Host '  Build-And-Deploy-DualUI: Official Build, Roundtrip Verify & Deploy' -ForegroundColor Cyan
Write-Host '================================================================================' -ForegroundColor Cyan
Write-Host "源码基线 (Source): $SourceRoot"
Write-Host "测试壳区 (Shell):  $ShellRoot"
Write-Host "正式热修 (Hotfix): $HotfixRoot $(if ($Deploy) { '[将执行部署]' } else { '[仅构建检验，不写入热修]' })"

# -----------------------------------------------------------------------------
# 0. Check Environment & Prerequisites
# -----------------------------------------------------------------------------
$javaExe = 'D:\swf-work-622\downloads\temurin8-jre\runtime\jdk8u502-b07-jre\bin\java.exe'
$ffdecJar = Join-Path $SourceRoot 'tools\ffdec\ffdec.jar'
if (-not (Test-Path -LiteralPath $ffdecJar)) {
    $ffdecJar = 'D:\codex-reusable-tools\seer-uclient-generic-renderer\toolchain\ffdec.jar'
}

if (-not (Test-Path -LiteralPath $javaExe)) {
    throw "Java 8 运行时不存在: $javaExe"
}
if (-not (Test-Path -LiteralPath $ffdecJar)) {
    throw "FFDec jar 工具包不存在: $ffdecJar"
}

$sourceCorePlainSwf = Join-Path $SourceRoot 'CoreDLL\CoreDLL.decrypted.swf'
$sourceCoreWrappedSwf = Join-Path $SourceRoot 'CoreDLL\CoreDLL.swf'
$sourceFramePlayerSwf = Join-Path $SourceRoot 'FramePlayer\FramePlayer.swf'

if (-not (Test-Path -LiteralPath $sourceCorePlainSwf)) {
    throw "CoreDLL 明文基准 SWF 不存在: $sourceCorePlainSwf"
}
if (-not (Test-Path -LiteralPath $sourceFramePlayerSwf)) {
    throw "FramePlayer 基准 SWF 不存在: $sourceFramePlayerSwf"
}

$taskTempRoot = "C:\Users\Administrator\.codex\tmp\shell_source_sync"
if (-not (Test-Path -LiteralPath $taskTempRoot)) {
    New-Item -ItemType Directory -Path $taskTempRoot -Force | Out-Null
}
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$buildTempDir = Join-Path $taskTempRoot "build_$timestamp"
New-Item -ItemType Directory -Path $buildTempDir -Force | Out-Null

try {
    # -----------------------------------------------------------------------------
    # 1. AST Syntax Pre-Flight Validation
    # -----------------------------------------------------------------------------
    Write-Host "`n[步骤 1/5] 执行 ActionScript 3 AST 语法门禁检测..." -ForegroundColor Yellow
    $astScript = Join-Path $SourceRoot 'toolchain\Test-ActionScriptAST.ps1'
    $coreArenaDir = Join-Path $SourceRoot 'CoreDLL\scripts\scripts\com\taomee\seer2\app\arena'
    $frameLayerDir = Join-Path $SourceRoot 'FramePlayer\scripts\scripts\animation\layer'

    if (Test-Path -LiteralPath $astScript) {
        $checkDirs = @($coreArenaDir, $frameLayerDir)
        & pwsh.exe -NoLogo -NoProfile -File $astScript -Path ($checkDirs -join ',') -Recurse -Quiet
        if ($LASTEXITCODE -ne 0) {
            throw "AST 语法检测失败! 源码存在语法错误，阻断构建以保护 SWF 完整性!"
        }
        Write-Host "  [OK] AST 语法门禁通过: CoreDLL 与 FramePlayer 源码全部合法" -ForegroundColor Green
    }

    # -----------------------------------------------------------------------------
    # 2. FramePlayer Scoped importScript & Anti-Hollow Gate
    # -----------------------------------------------------------------------------
    Write-Host "`n[步骤 2/5] 编译 FramePlayer (Scoped importScript 范式)..." -ForegroundColor Yellow
    if (-not $CoreOnly) {
    $frameImportRoot = Join-Path $buildTempDir 'frame_import\animation\layer'
    New-Item -ItemType Directory -Path $frameImportRoot -Force | Out-Null

    # Copy PetLayer.as (and any modified layer files)
    $petLayerSrc = Join-Path $frameLayerDir 'PetLayer.as'
    Copy-Item -LiteralPath $petLayerSrc -Destination (Join-Path $frameImportRoot 'PetLayer.as') -Force

    $candidateFrameSwf = Join-Path $buildTempDir 'FramePlayer.candidate.swf'
    $importFrameDir = Join-Path $buildTempDir 'frame_import'

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $javaExe
    $psi.ArgumentList.Add("-Xmx4g")
    $psi.ArgumentList.Add("-Djava.awt.headless=true")
    $psi.ArgumentList.Add("-jar")
    $psi.ArgumentList.Add($ffdecJar)
    $psi.ArgumentList.Add("-onerror")
    $psi.ArgumentList.Add("abort")
    $psi.ArgumentList.Add("-importScript")
    $psi.ArgumentList.Add($sourceFramePlayerSwf)
    $psi.ArgumentList.Add($candidateFrameSwf)
    $psi.ArgumentList.Add($importFrameDir)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()

    if ($proc.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $candidateFrameSwf)) {
        $err = $proc.StandardError.ReadToEnd()
        throw "FramePlayer importScript 失败 (ExitCode: $($proc.ExitCode)): $err"
    }

    # Anti-Hollow SWF Gate for FramePlayer
    $frameItem = Get-Item -LiteralPath $candidateFrameSwf
    $frameLength = $frameItem.Length
    if ($frameLength -lt 1400000 -or $frameLength -gt 1800000) {
        throw "FramePlayer 体积异常 ($frameLength 字节，基线 ~1.57MB)，触发防空壳阻断保护!"
    }
    $frameHeader = [System.IO.File]::ReadAllBytes($candidateFrameSwf)[0..2]
    $frameHeaderStr = [System.Text.Encoding]::ASCII.GetString($frameHeader)
    if ($frameHeaderStr -ne 'CWS' -and $frameHeaderStr -ne 'FWS' -and $frameHeaderStr -ne 'ZWS') {
        throw "FramePlayer SWF 文件头异常: $frameHeaderStr (必须为 CWS, FWS 或 ZWS)"
    }

    # Decompilation Readback Verification
    if (-not $SkipReadback) {
        $readbackDir = Join-Path $buildTempDir 'readback_frame'
        New-Item -ItemType Directory -Path $readbackDir -Force | Out-Null
        $psiRb = [System.Diagnostics.ProcessStartInfo]::new()
        $psiRb.FileName = $javaExe
        $psiRb.ArgumentList.Add("-Xmx4g")
        $psiRb.ArgumentList.Add("-Djava.awt.headless=true")
        $psiRb.ArgumentList.Add("-jar")
        $psiRb.ArgumentList.Add($ffdecJar)
        $psiRb.ArgumentList.Add("-onerror")
        $psiRb.ArgumentList.Add("abort")
        $psiRb.ArgumentList.Add("-selectclass")
        $psiRb.ArgumentList.Add("animation.layer.PetLayer")
        $psiRb.ArgumentList.Add("-export")
        $psiRb.ArgumentList.Add("script")
        $psiRb.ArgumentList.Add($readbackDir)
        $psiRb.ArgumentList.Add($candidateFrameSwf)
        $psiRb.UseShellExecute = $false

        $procRb = [System.Diagnostics.Process]::Start($psiRb)
        $procRb.WaitForExit()

        $rbPetLayer = Join-Path $readbackDir 'scripts\animation\layer\PetLayer.as'
        if (-not (Test-Path -LiteralPath $rbPetLayer)) {
            throw "FramePlayer 回读反编译验证失败: 未找到 PetLayer.as 导出脚本!"
        }
        $rbContent = [System.IO.File]::ReadAllText($rbPetLayer, [System.Text.Encoding]::UTF8)
        if (-not $rbContent.Contains('class PetLayer')) {
            throw "FramePlayer 回读类定义不完整: 缺失 'class PetLayer'!"
        }
        Write-Host "  [OK] FramePlayer 防空壳与回读验证通过: PetLayer 类完整存在 ($((Get-Item -LiteralPath $rbPetLayer).Length) 字节)" -ForegroundColor Green
    }
    Write-Host "  [OK] FramePlayer.swf 构建成功! 体积: $frameLength 字节" -ForegroundColor Green
    } else {
        Write-Host "  [跳过] 指定了 -CoreOnly 开关，FramePlayer 保持 100% 原封不动" -ForegroundColor Gray
    }

    # -----------------------------------------------------------------------------
    # 3. CoreDLL Scoped importScript & Anti-Hollow Gate
    # -----------------------------------------------------------------------------
    Write-Host "`n[步骤 3/5] 编译 CoreDLL (Scoped importScript 范式)..." -ForegroundColor Yellow
    $coreImportRoot = Join-Path $buildTempDir 'core_import\com\taomee\seer2\app\arena'
    New-Item -ItemType Directory -Path $coreImportRoot -Force | Out-Null

    # Copy FighterAnimation.as and Fighter.as (and other arena files if requested)
    $candidateArenaFiles = @('FighterAnimation.as', 'Fighter.as', 'ArenaScene.as')
    if ($ForceAll) {
        $allArena = Get-ChildItem -LiteralPath $coreArenaDir -File -Filter '*.as'
        foreach ($af in $allArena) {
            Copy-Item -LiteralPath $af.FullName -Destination (Join-Path $coreImportRoot $af.Name) -Force
        }
    } else {
        foreach ($afName in $candidateArenaFiles) {
            $afPath = Join-Path $coreArenaDir $afName
            if (Test-Path -LiteralPath $afPath) {
                Copy-Item -LiteralPath $afPath -Destination (Join-Path $coreImportRoot $afName) -Force
            }
        }
    }

    $candidateCorePlainSwf = Join-Path $buildTempDir 'CoreDLL.candidate.decrypted.swf'
    $importCoreDir = Join-Path $buildTempDir 'core_import'

    $psiCore = [System.Diagnostics.ProcessStartInfo]::new()
    $psiCore.FileName = $javaExe
    $psiCore.ArgumentList.Add("-Xmx6g")
    $psiCore.ArgumentList.Add("-Djava.awt.headless=true")
    $psiCore.ArgumentList.Add("-jar")
    $psiCore.ArgumentList.Add($ffdecJar)
    $psiCore.ArgumentList.Add("-onerror")
    $psiCore.ArgumentList.Add("abort")
    $psiCore.ArgumentList.Add("-importScript")
    $psiCore.ArgumentList.Add($sourceCorePlainSwf)
    $psiCore.ArgumentList.Add($candidateCorePlainSwf)
    $psiCore.ArgumentList.Add($importCoreDir)
    $psiCore.RedirectStandardOutput = $true
    $psiCore.RedirectStandardError = $true
    $psiCore.UseShellExecute = $false

    $procCore = [System.Diagnostics.Process]::Start($psiCore)
    $procCore.WaitForExit()

    if ($procCore.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $candidateCorePlainSwf)) {
        $err = $procCore.StandardError.ReadToEnd()
        throw "CoreDLL importScript 失败 (ExitCode: $($procCore.ExitCode)): $err"
    }

    # Anti-Hollow SWF Gate for CoreDLL
    $coreItem = Get-Item -LiteralPath $candidateCorePlainSwf
    $coreLength = $coreItem.Length
    if ($coreLength -lt 5000000 -or $coreLength -gt 6200000) {
        throw "CoreDLL 明文体积异常 ($coreLength 字节，基线 ~5.68MB)，触发防空壳阻断保护!"
    }
    $coreHeader = [System.IO.File]::ReadAllBytes($candidateCorePlainSwf)[0..2]
    $coreHeaderStr = [System.Text.Encoding]::ASCII.GetString($coreHeader)
    if ($coreHeaderStr -ne 'CWS' -and $coreHeaderStr -ne 'FWS' -and $coreHeaderStr -ne 'ZWS') {
        throw "CoreDLL 明文 SWF 文件头异常: $coreHeaderStr (必须为 CWS, FWS 或 ZWS)"
    }

    # Decompilation Readback Verification for CoreDLL
    if (-not $SkipReadback) {
        $readbackDirCore = Join-Path $buildTempDir 'readback_core'
        New-Item -ItemType Directory -Path $readbackDirCore -Force | Out-Null
        $psiRbCore = [System.Diagnostics.ProcessStartInfo]::new()
        $psiRbCore.FileName = $javaExe
        $psiRbCore.ArgumentList.Add("-Xmx6g")
        $psiRbCore.ArgumentList.Add("-Djava.awt.headless=true")
        $psiRbCore.ArgumentList.Add("-jar")
        $psiRbCore.ArgumentList.Add($ffdecJar)
        $psiRbCore.ArgumentList.Add("-onerror")
        $psiRbCore.ArgumentList.Add("abort")
        $psiRbCore.ArgumentList.Add("-selectclass")
        $psiRbCore.ArgumentList.Add("com.taomee.seer2.app.arena.FighterAnimation")
        $psiRbCore.ArgumentList.Add("-export")
        $psiRbCore.ArgumentList.Add("script")
        $psiRbCore.ArgumentList.Add($readbackDirCore)
        $psiRbCore.ArgumentList.Add($candidateCorePlainSwf)
        $psiRbCore.UseShellExecute = $false

        $procRbCore = [System.Diagnostics.Process]::Start($psiRbCore)
        $procRbCore.WaitForExit()

        $rbFighterAnim = Join-Path $readbackDirCore 'scripts\com\taomee\seer2\app\arena\FighterAnimation.as'
        if (-not (Test-Path -LiteralPath $rbFighterAnim)) {
            throw "CoreDLL 回读反编译验证失败: 未找到 FighterAnimation.as 导出脚本!"
        }
        $rbContentCore = [System.IO.File]::ReadAllText($rbFighterAnim, [System.Text.Encoding]::UTF8)
        if (-not $rbContentCore.Contains('class FighterAnimation')) {
            throw "CoreDLL 回读类定义不完整: 缺失 'class FighterAnimation'!"
        }
        Write-Host "  [OK] CoreDLL 防空壳与回读验证通过: FighterAnimation 类完整存在 ($((Get-Item -LiteralPath $rbFighterAnim).Length) 字节)" -ForegroundColor Green
    }
    Write-Host "  [OK] CoreDLL 明文 SWF 构建成功! 体积: $coreLength 字节" -ForegroundColor Green

    # -----------------------------------------------------------------------------
    # 4. CoreDLL Official Packaging (7×0x00 + zlib level 9) & Byte Roundtrip Assert
    # -----------------------------------------------------------------------------
    Write-Host "`n[步骤 4/5] 执行 CoreDLL 官方封包 (7×0x00 + zlib level 9) 与逐字节回环校验..." -ForegroundColor Yellow
    $candidateCorePlainBytes = [System.IO.File]::ReadAllBytes($candidateCorePlainSwf)

    # Compress using .NET ZLibStream level 9
    $compMs = [System.IO.MemoryStream]::new()
    for ($b = 0; $b -lt 7; $b++) { $compMs.WriteByte(0) }
    $zsComp = [System.IO.Compression.ZLibStream]::new($compMs, [System.IO.Compression.CompressionLevel]::SmallestSize)
    $zsComp.Write($candidateCorePlainBytes, 0, $candidateCorePlainBytes.Length)
    $zsComp.Dispose()
    $wrappedBytes = $compMs.ToArray()

    $candidateCoreWrappedSwf = Join-Path $buildTempDir 'CoreDLL.candidate.wrapped.swf'
    [System.IO.File]::WriteAllBytes($candidateCoreWrappedSwf, $wrappedBytes)

    # Immediate Roundtrip Decompression Assert
    $decompMs = [System.IO.MemoryStream]::new()
    $compInMs = [System.IO.MemoryStream]::new($wrappedBytes, 7, $wrappedBytes.Length - 7)
    $zsDecomp = [System.IO.Compression.ZLibStream]::new($compInMs, [System.IO.Compression.CompressionMode]::Decompress)
    $zsDecomp.CopyTo($decompMs)
    $zsDecomp.Dispose()
    $roundtripBytes = $decompMs.ToArray()

    if ($roundtripBytes.Length -ne $candidateCorePlainBytes.Length) {
        throw "CoreDLL 封包回环校验致命失败! 解压体积 ($($roundtripBytes.Length)) 与原始明文体积 ($($candidateCorePlainBytes.Length)) 不符!"
    }
    for ($idx = 0; $idx -lt $candidateCorePlainBytes.Length; $idx++) {
        if ($roundtripBytes[$idx] -ne $candidateCorePlainBytes[$idx]) {
            throw "CoreDLL 封包回环校验致命失败! 偏移 $idx 字节内容不匹配!"
        }
    }
    Write-Host "  [OK] CoreDLL 官方封包完成: 原始明文 $($candidateCorePlainBytes.Length) 字节 -> 封包 $($wrappedBytes.Length) 字节" -ForegroundColor Green
    Write-Host "  [OK] 逐字节解密回环断言通过 (100% Byte-Exact Equality Verified)" -ForegroundColor Green

    # -----------------------------------------------------------------------------
    # 5. Atomic Update & Deployment
    # -----------------------------------------------------------------------------
    Write-Host "`n[步骤 5/5] 落盘更新基线源码库、测试壳与正式热修环境..." -ForegroundColor Yellow

    # 5a. Update Source Repository (D:\s2-ui)
    if (-not $CoreOnly) {
        Copy-Item -LiteralPath $candidateFrameSwf -Destination $sourceFramePlayerSwf -Force
    }
    Copy-Item -LiteralPath $candidateCorePlainSwf -Destination $sourceCorePlainSwf -Force
    Copy-Item -LiteralPath $candidateCoreWrappedSwf -Destination $sourceCoreWrappedSwf -Force
    Write-Host "  [OK] 源码库 (D:\s2-ui) 产物同步更新完成" -ForegroundColor Green

    # 5b. Update Test Shell (D:\seer2-lightweight-harness)
    if (Test-Path -LiteralPath $ShellRoot) {
        if (-not $CoreOnly) {
            Copy-Item -LiteralPath $candidateFrameSwf -Destination (Join-Path $ShellRoot 'FramePlayer.swf') -Force
        }
        Copy-Item -LiteralPath $candidateCorePlainSwf -Destination (Join-Path $ShellRoot 'CoreDLL.decrypted.swf') -Force
        Copy-Item -LiteralPath $candidateCoreWrappedSwf -Destination (Join-Path $ShellRoot 'CoreDLL.swf') -Force
        Write-Host "  [OK] 测试壳 (D:\seer2-lightweight-harness) 本地运行 SWF 同步就绪" -ForegroundColor Green
    }

    # 5c. Deploy to Official Hotfix if requested
    $hotfixSkinModeDir = Join-Path $HotfixRoot 'local-res\skin-mode'
    if ($Deploy) {
        if (-not (Test-Path -LiteralPath $hotfixSkinModeDir)) {
            throw "正式热修目标目录不存在: $hotfixSkinModeDir"
        }
        $hotfixCoreSwf = Join-Path $hotfixSkinModeDir 'CoreDLL.swf'
        $hotfixFrameSwf = Join-Path $hotfixSkinModeDir 'FramePlayer.swf'

        # Safe backup before deployment
        if (Test-Path -LiteralPath $hotfixCoreSwf) {
            Copy-Item -LiteralPath $hotfixCoreSwf -Destination "$hotfixCoreSwf.bak_$timestamp" -Force
        }
        if (-not $CoreOnly -and (Test-Path -LiteralPath $hotfixFrameSwf)) {
            Copy-Item -LiteralPath $hotfixFrameSwf -Destination "$hotfixFrameSwf.bak_$timestamp" -Force
        }

        Copy-Item -LiteralPath $candidateCoreWrappedSwf -Destination $hotfixCoreSwf -Force
        if (-not $CoreOnly) {
            Copy-Item -LiteralPath $candidateFrameSwf -Destination $hotfixFrameSwf -Force
        }

        $coreHash = (Get-FileHash -LiteralPath $hotfixCoreSwf -Algorithm SHA256).Hash
        Write-Host "  [OK] 正式热修部署成功!" -ForegroundColor Green
        Write-Host "       CoreDLL.swf (封包): $hotfixCoreSwf" -ForegroundColor Cyan
        Write-Host "       SHA256: $coreHash" -ForegroundColor Gray
        if (-not $CoreOnly) {
            $frameHash = (Get-FileHash -LiteralPath $hotfixFrameSwf -Algorithm SHA256).Hash
            Write-Host "       FramePlayer.swf:    $hotfixFrameSwf" -ForegroundColor Cyan
            Write-Host "       SHA256: $frameHash" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [提示] 未指定 -Deploy 开关，本次构建产物保留于源码库与测试壳中，未注入正式热修目录。" -ForegroundColor Yellow
    }

    $swTotal.Stop()
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "  构建部署闭环全部成功! 总耗时: $([math]::Round($swTotal.Elapsed.TotalSeconds, 2)) 秒" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan

} finally {
    # Clean up temporary build folder
    if (Test-Path -LiteralPath $buildTempDir) {
        Remove-Item -LiteralPath $buildTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
