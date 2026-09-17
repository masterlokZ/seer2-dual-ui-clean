<#
.SYNOPSIS
    Sync-ShellToSource: Test Shell (D:\seer2-lightweight-harness) -> Baseline Source (D:\s2-ui)
.DESCRIPTION
    Safely migrates ActionScript code modifications verified in the test shell back into the
    canonical UI source repository (D:\s2-ui). Enforces AST syntax validation, atomic file
    updates with backup protection, and Git status verification.
.PARAMETER ShellRoot
    Path to lightweight test harness / shell. Default: D:\seer2-lightweight-harness
.PARAMETER SourceRoot
    Path to canonical UI source repository. Default: D:\s2-ui
.PARAMETER Build
    Automatically run Build-And-Deploy-DualUI after synchronization.
.PARAMETER Deploy
    Deploy to official hotfix directory (D:\seer2-x32-hotfix) after build.
.PARAMETER DryRun
    Preview changed files and diffs without modifying source files.
.PARAMETER Force
    Overwrite destination files without creating .bak_sync backup files.
#>

[CmdletBinding()]
param(
    [string]$ShellRoot = 'D:\seer2-lightweight-harness',
    [string]$SourceRoot = 'D:\s2-ui',
    [switch]$Build,
    [switch]$Deploy,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

Write-Host '================================================================================' -ForegroundColor Cyan
Write-Host '  Seer2 Dual-UI Toolchain: Sync-ShellToSource (Shell -> Source)' -ForegroundColor Cyan
Write-Host '================================================================================' -ForegroundColor Cyan
Write-Host "测试壳工作区 (Shell):  $ShellRoot"
Write-Host "源码基线目录 (Source): $SourceRoot"
if ($DryRun) {
    Write-Host "[模式] 预演模式 (DryRun) - 仅分析差异，不写入磁盘" -ForegroundColor Magenta
}

$devSrc = Join-Path $ShellRoot 'dev-src'
$shellCoreArena = Join-Path $devSrc 'CoreDLL\com\taomee\seer2\app\arena'
$shellFrameLayer = Join-Path $devSrc 'FramePlayer\animation\layer'

$sourceCoreArena = Join-Path $SourceRoot 'CoreDLL\scripts\scripts\com\taomee\seer2\app\arena'
$sourceFrameLayer = Join-Path $SourceRoot 'FramePlayer\scripts\scripts\animation\layer'

if (-not (Test-Path -LiteralPath $shellCoreArena)) {
    throw "测试壳 CoreDLL 开发目录不存在: $shellCoreArena"
}
if (-not (Test-Path -LiteralPath $shellFrameLayer)) {
    throw "测试壳 FramePlayer 开发目录不存在: $shellFrameLayer"
}
if (-not (Test-Path -LiteralPath $sourceCoreArena)) {
    throw "源码库 CoreDLL 目标目录不存在: $sourceCoreArena"
}
if (-not (Test-Path -LiteralPath $sourceFrameLayer)) {
    throw "源码库 FramePlayer 目标目录不存在: $sourceFrameLayer"
}

# 1. Pre-Flight AST Syntax Check
Write-Host "`n[步骤 1/4] 执行 ActionScript 3 AST 语法安全门禁检测..." -ForegroundColor Yellow
$astScript = Join-Path $SourceRoot 'toolchain\Test-ActionScriptAST.ps1'
if (-not (Test-Path -LiteralPath $astScript)) {
    $astScript = 'D:\s2-ui\toolchain\Test-ActionScriptAST.ps1'
}

if (Test-Path -LiteralPath $astScript) {
    $checkDirs = @($shellCoreArena, $shellFrameLayer)
    & pwsh.exe -NoLogo -NoProfile -File $astScript -Path ($checkDirs -join ',') -Recurse -Quiet
    if ($LASTEXITCODE -ne 0) {
        throw "AST 语法检测失败! 测试壳源码存在语法错误，严禁回迁至基线源码库!"
    }
    Write-Host "  [OK] AST 语法门禁通过: 测试壳内 ActionScript 语法全部合法" -ForegroundColor Green
} else {
    Write-Warning "未找到 Test-ActionScriptAST.ps1，跳过 AST 语法前置门禁。"
}

# 2. Compute Differences Between Shell and Source
Write-Host "`n[步骤 2/4] 比对测试壳与基线源码差异..." -ForegroundColor Yellow

$candidatePairs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Collect CoreDLL Arena files
$shellCoreFiles = Get-ChildItem -LiteralPath $shellCoreArena -Recurse -File -Filter '*.as'
foreach ($f in $shellCoreFiles) {
    $rel = $f.FullName.Substring($shellCoreArena.Length).TrimStart('\', '/')
    $target = Join-Path $sourceCoreArena $rel
    $candidatePairs.Add([PSCustomObject]@{
        Component  = 'CoreDLL'
        Relative   = "com\taomee\seer2\app\arena\$rel"
        SourceFile = $f.FullName
        TargetFile = $target
    })
}

# Collect FramePlayer files
$shellFrameFiles = Get-ChildItem -LiteralPath $shellFrameLayer -Recurse -File -Filter '*.as'
foreach ($f in $shellFrameFiles) {
    $rel = $f.FullName.Substring($shellFrameLayer.Length).TrimStart('\', '/')
    $target = Join-Path $sourceFrameLayer $rel
    $candidatePairs.Add([PSCustomObject]@{
        Component  = 'FramePlayer'
        Relative   = "animation\layer\$rel"
        SourceFile = $f.FullName
        TargetFile = $target
    })
}

$changedList = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($pair in $candidatePairs) {
    $shellHash = (Get-FileHash -LiteralPath $pair.SourceFile -Algorithm SHA256).Hash
    $targetExists = Test-Path -LiteralPath $pair.TargetFile
    $targetHash = if ($targetExists) { (Get-FileHash -LiteralPath $pair.TargetFile -Algorithm SHA256).Hash } else { $null }

    if (-not $targetExists -or $shellHash -ne $targetHash) {
        $changedList.Add([PSCustomObject]@{
            Component  = $pair.Component
            Relative   = $pair.Relative
            SourceFile = $pair.SourceFile
            TargetFile = $pair.TargetFile
            ShellHash  = $shellHash
            TargetHash = $targetHash
            Status     = if (-not $targetExists) { 'NEW' } else { 'MODIFIED' }
        })
    }
}

if ($changedList.Count -eq 0) {
    Write-Host "  [OK] 测试壳源码与基线源码库完全一致，无任何待回迁改动。" -ForegroundColor Green
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "  回迁检查完毕 (无变更)" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    return
}

Write-Host "  检测到 $($changedList.Count) 个文件发生改动:" -ForegroundColor Cyan
foreach ($item in $changedList) {
    Write-Host "    [$($item.Status)] $($item.Component): $($item.Relative)" -ForegroundColor $(if ($item.Status -eq 'NEW') { 'Magenta' } else { 'Yellow' })
}

# 3. Atomic Sync-Back
Write-Host "`n[步骤 3/4] 执行原子回迁落盘至源码库 (D:\s2-ui)..." -ForegroundColor Yellow

if (-not $DryRun) {
    foreach ($item in $changedList) {
        $targetDir = [System.IO.Path]::GetDirectoryName($item.TargetFile)
        if (-not (Test-Path -LiteralPath $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        # Backup existing target
        if (-not $Force -and (Test-Path -LiteralPath $item.TargetFile)) {
            $bak = "$($item.TargetFile).bak_sync"
            Copy-Item -LiteralPath $item.TargetFile -Destination $bak -Force
        }

        Copy-Item -LiteralPath $item.SourceFile -Destination $item.TargetFile -Force

        # Verify write hash
        $writtenHash = (Get-FileHash -LiteralPath $item.TargetFile -Algorithm SHA256).Hash
        if ($writtenHash -ne $item.ShellHash) {
            throw "原子回迁哈希校验失败! 写入损坏: $($item.TargetFile)"
        }
        Write-Host "  [OK] 回迁完成: $($item.Relative)" -ForegroundColor Green
    }
} else {
    Write-Host "  [DryRun] 跳过实际写入。" -ForegroundColor Gray
}

# 4. Git Repository Status Check
Write-Host "`n[步骤 4/4] 验证源码库 Git 变更状态..." -ForegroundColor Yellow
$gitStatus = git -C $SourceRoot status --short
if (-not [string]::IsNullOrWhiteSpace($gitStatus)) {
    Write-Host "源码库 Git 变更列表:" -ForegroundColor Gray
    $gitStatus -split "`n" | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
} else {
    Write-Host "  源码库处于干净状态 (Clean)。" -ForegroundColor Gray
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  Sync-ShellToSource 回迁成功完成! ($($changedList.Count) 个文件)" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

# 5. Trigger Build & Deploy if requested
if ($Build -or $Deploy) {
    Write-Host "`n正在触发正式双 UI 构建与部署..." -ForegroundColor Cyan
    $buildScript = Join-Path $SourceRoot 'toolchain\Build-And-Deploy-DualUI.ps1'
    $deployParam = if ($Deploy) { @('-Deploy') } else { @() }
    & pwsh.exe -NoLogo -NoProfile -File $buildScript -SourceRoot $SourceRoot -ShellRoot $ShellRoot @deployParam
}
