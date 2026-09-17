<#
.SYNOPSIS
    ActionScript 3 AST & Lexical Syntax Validator (Test-ActionScriptAST)
.DESCRIPTION
    Analyzes ActionScript 3 (.as) source files for syntax errors, bracket/brace imbalances,
    package/class declaration alignment, and corrupted tokens before passing to FFDec compiler.
.PARAMETER Path
    Target .as file or directory containing .as files.
.PARAMETER Recurse
    If Path is a directory, recursively find all .as files.
.PARAMETER Quiet
    Suppress informational output; only output errors and exit code.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]
    [string[]]$Path,
    [switch]$Recurse,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Test-SingleActionScriptFile {
    param([string]$FilePath)

    $errors = [System.Collections.Generic.List[string]]::new()
    $item = Get-Item -LiteralPath $FilePath -ErrorAction Stop
    $fileName = $item.Name
    $fileStem = [System.IO.Path]::GetFileNameWithoutExtension($fileName)

    $content = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)

    # 1. Check for unresolved Git conflict markers
    $lines = $content -split "\r?\n"
    for ($lineIdx = 0; $lineIdx -lt $lines.Length; $lineIdx++) {
        $lineText = $lines[$lineIdx]
        if ($lineText -match '^(<{7}|={7}|>{7})') {
            $errors.Add("Line $($lineIdx + 1): Unresolved Git conflict marker detected: '$($matches[0])'")
        }
    }

    # 2. Tokenize and verify brace, parenthesis, and bracket balance
    # Stack entries store: @{ Char = '{'; Line = 1; Col = 1 }
    $stack = [System.Collections.Generic.Stack[hashtable]]::new()
    $len = $content.Length
    $i = 0
    $line = 1
    $col = 1

    $inStringDouble = $false
    $inStringSingle = $false
    $inLineComment = $false
    $inBlockComment = $false
    $stringStartLine = 0
    $blockCommentStartLine = 0

    $declaredPackage = $null
    $declaredClasses = [System.Collections.Generic.List[string]]::new()

    while ($i -lt $len) {
        $ch = $content[$i]
        $nextCh = if ($i + 1 -lt $len) { $content[$i + 1] } else { [char]0 }

        # Track line and column numbers
        if ($ch -eq "`n") {
            $line++
            $col = 1
            if ($inLineComment) {
                 $inLineComment = $false
            }
            $i++
            continue
        } elseif ($ch -eq "`r") {
            $i++
            continue
        }

        # Handle line comments
        if ($inLineComment) {
            $col++
            $i++
            continue
        }

        # Handle block comments
        if ($inBlockComment) {
            if ($ch -eq '*' -and $nextCh -eq '/') {
                $inBlockComment = $false
                $i += 2
                $col += 2
                continue
            }
            $col++
            $i++
            continue
        }

        # Handle string literals
        if ($inStringDouble) {
            if ($ch -eq '\') {
                $i += 2
                $col += 2
                continue
            }
            if ($ch -eq '"') {
                $inStringDouble = $false
            }
            $col++
            $i++
            continue
        }

        if ($inStringSingle) {
            if ($ch -eq '\') {
                $i += 2
                $col += 2
                continue
            }
            if ($ch -eq "'") {
                $inStringSingle = $false
            }
            $col++
            $i++
            continue
        }

        # Not in string or comment: check comment starters
        if ($ch -eq '/' -and $nextCh -eq '/') {
            $inLineComment = $true
            $i += 2
            $col += 2
            continue
        }
        if ($ch -eq '/' -and $nextCh -eq '*') {
            $inBlockComment = $true
            $blockCommentStartLine = $line
            $i += 2
            $col += 2
            continue
        }

        # Check string starters
        if ($ch -eq '"') {
            $inStringDouble = $true
            $stringStartLine = $line
            $col++
            $i++
            continue
        }
        if ($ch -eq "'") {
            $inStringSingle = $true
            $stringStartLine = $line
            $col++
            $i++
            continue
        }

        # Brackets and delimiters checking
       if ($ch -eq '{' -or $ch -eq '(' -or $ch -eq '[') {
           $stack.Push(@{ Char = $ch; Line = $line; Col = $col })
       } elseif ($ch -eq '}') {
           if ($stack.Count -eq 0) {
                $errors.Add("Line $line, Col $($col): Unexpected closing brace '}' without opening match.")
           } else {
               $top = $stack.Pop()
               if ($top.Char -ne '{') {
                    $errors.Add("Line $line, Col $($col): Mismatched closing brace '}'. Expected closing for '$($top.Char)' from Line $($top.Line), Col $($top.Col).")
               }
           }
       } elseif ($ch -eq ')') {
           if ($stack.Count -eq 0) {
                $errors.Add("Line $line, Col $($col): Unexpected closing parenthesis ')' without opening match.")
           } else {
               $top = $stack.Pop()
               if ($top.Char -ne '(') {
                    $errors.Add("Line $line, Col $($col): Mismatched closing parenthesis ')'. Expected closing for '$($top.Char)' from Line $($top.Line), Col $($top.Col).")
               }
           }
       } elseif ($ch -eq ']') {
           if ($stack.Count -eq 0) {
                $errors.Add("Line $line, Col $($col): Unexpected closing bracket ']' without opening match.")
           } else {
               $top = $stack.Pop()
               if ($top.Char -ne '[') {
                    $errors.Add("Line $line, Col $($col): Mismatched closing bracket ']'. Expected closing for '$($top.Char)' from Line $($top.Line), Col $($top.Col).")
               }
           }
       }

        $col++
        $i++
    }

   if ($inBlockComment) {
        $errors.Add("Line $($blockCommentStartLine): Unterminated block comment /* reaching end of file.")
   }
   if ($inStringDouble -or $inStringSingle) {
        $errors.Add("Line $($stringStartLine): Unterminated string literal reaching end of file.")
   }
   while ($stack.Count -gt 0) {
       $unclosed = $stack.Pop()
        $errors.Add("Line $($unclosed.Line), Col $($unclosed.Col): Unclosed delimiter '$($unclosed.Char)' reaching end of file.")
   }

    # 3. Class name verification (ensure public class/interface matches filename)
    if ($content -match '(?m)^\s*(?:public\s+|final\s+|dynamic\s+)*(?:class|interface)\s+([A-Za-z0-9_]+)') {
        $mainClass = $matches[1]
        if ($mainClass -ne $fileStem) {
            $errors.Add("Declaration mismatch: Primary class '$mainClass' does not match filename stem '$fileStem.as'")
        }
    }

    # 4. Package declaration check
    if ($content -match '(?m)^\s*package(?:\s+([A-Za-z0-9_\.]+))?\s*\{') {
        $declaredPackage = if ($matches[1]) { $matches[1] } else { "" }
    } else {
        $errors.Add("Missing or malformed 'package { ... }' declaration in $fileName")
    }

    return [PSCustomObject]@{
        FilePath   = $FilePath
        FileName   = $fileName
        Package    = $declaredPackage
        IsValid    = ($errors.Count -eq 0)
        ErrorCount = $errors.Count
        Errors     = $errors
    }
}

# Collect target files
$targetFiles = [System.Collections.Generic.List[string]]::new()
foreach ($rawP in $Path) {
    foreach ($p in ($rawP -split ',')) {
        $p = $p.Trim().Trim('"').Trim("'")
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Error "Target path does not exist: $p"
        continue
    }
    $item = Get-Item -LiteralPath $p
    if ($item.PSIsContainer) {
        $opt = if ($Recurse) { [System.IO.SearchOption]::AllDirectories } else { [System.IO.SearchOption]::TopDirectoryOnly }
        $found = [System.IO.Directory]::GetFiles($item.FullName, "*.as", $opt)
        foreach ($f in $found) { $targetFiles.Add($f) }
    } elseif ($item.Name.EndsWith(".as", [System.StringComparison]::OrdinalIgnoreCase)) {
        $targetFiles.Add($item.FullName)
    }
    }
}

if ($targetFiles.Count -eq 0) {
    if (-not $Quiet) { Write-Host "No ActionScript 3 (.as) files found to validate." -ForegroundColor Yellow }
    exit 0
}

$passCount = 0
$failCount = 0
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($file in $targetFiles) {
    $res = Test-SingleActionScriptFile -FilePath $file
    $results.Add($res)
    if ($res.IsValid) {
        $passCount++
        if (-not $Quiet) {
            Write-Host "  [PASS] $($res.FileName) (package $($res.Package))" -ForegroundColor Green
        }
    } else {
        $failCount++
        Write-Host "  [FAIL] $($res.FileName)" -ForegroundColor Red
        foreach ($err in $res.Errors) {
            Write-Host "         -> $err" -ForegroundColor DarkRed
        }
    }
}

if (-not $Quiet) {
    Write-Host "`nAST Validation Summary: $passCount Passed, $failCount Failed (Total: $($targetFiles.Count))" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })
}

if ($failCount -gt 0) {
    exit 1
}
exit 0
