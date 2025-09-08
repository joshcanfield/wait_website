param(
    [string]$RepoRoot = (Get-Location).Path,
    [string]$MissingCsv = 'missing_report.csv'
)

$ErrorActionPreference = 'Stop'

function Repair-HtmlFile {
    param([string]$Path)
    $c = Get-Content -LiteralPath $Path -Raw
    $o = $c
    # Prefix internal paths with '/'
    $c = $c -replace '(?i)(\b(?:href|src|data|background)\s*=\s*["])(content/)', '$1/$2'
    $c = $c -replace "(?i)(\b(?:href|src|data|background)\s*=\s*\[\'])(content/)", '$1/$2'
    $c = $c -replace '(?i)(\b(?:href|src|data|background)\s*=\s*["])(misc/)', '$1/$2'
    $c = $c -replace "(?i)(\b(?:href|src|data|background)\s*=\s*\[\'])(misc/)", '$1/$2'
    $c = $c -replace '(?i)(\b(?:href|src|data|background)\s*=\s*["])(modules/)', '$1/$2'
    $c = $c -replace "(?i)(\b(?:href|src|data|background)\s*=\s*\[\'])(modules/)", '$1/$2'
    $c = $c -replace '(?i)(\b(?:href|src|data|background)\s*=\s*["])(sites/)', '$1/$2'
    $c = $c -replace "(?i)(\b(?:href|src|data|background)\s*=\s*\[\'])(sites/)", '$1/$2'
    # Top-level pages
    $c = $c -replace '(?i)(\b(?:href|src)\s*=\s*["])(index\.html|home\.html|calendars\.html)', '$1/$2'
    $c = $c -replace "(?i)(\b(?:href|src)\s*=\s*\[\'])(index\.html|home\.html|calendars\.html)", '$1/$2'
    if ($c -ne $o) { Set-Content -LiteralPath $Path -Value $c -Encoding UTF8; return $true }
    return $false
}

function Repair-CssFile {
    param([string]$Path)
    $c = Get-Content -LiteralPath $Path -Raw
    $o = $c
    $c = $c -replace '(?i)url\(\s*["]?content/', 'url(/content/'
    $c = $c -replace '(?i)url\(\s*["]?misc/', 'url(/misc/'
    $c = $c -replace '(?i)url\(\s*["]?modules/', 'url(/modules/'
    $c = $c -replace '(?i)url\(\s*["]?sites/', 'url(/sites/'
    if ($c -ne $o) { Set-Content -LiteralPath $Path -Value $c -Encoding UTF8; return $true }
    return $false
}

function Download-ArchivedAssets {
    param([string]$RepoRoot, [string]$CsvPath)
    if (-not (Test-Path -LiteralPath $CsvPath)) { Write-Warning "CSV not found: $CsvPath"; return @() }
    $rows = Import-Csv -Path $CsvPath
    $downloaded = @()
    foreach ($row in $rows) {
        if ($row.WaybackAvailable -ne 'True') { continue }
        $rel = $row.Path; if (-not $rel) { continue }
        $target = Join-Path $RepoRoot ($rel -replace '/', '\\')
        $dir = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $url = $row.WaybackUrl; if (-not $url) { continue }
        try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $target -TimeoutSec 60; $downloaded += $rel; Write-Host "Downloaded: $rel" -ForegroundColor Green }
        catch { Write-Warning "Failed download: $rel => $url : $($_.Exception.Message)" }
    }
    return $downloaded
}

Write-Host "Repairing links in HTML/CSS under: $RepoRoot" -ForegroundColor Cyan
$changed = 0
Get-ChildItem -Path $RepoRoot -Recurse -File -Include *.html,*.htm | ForEach-Object { if (Repair-HtmlFile -Path $_.FullName) { $changed++ } }
Get-ChildItem -Path $RepoRoot -Recurse -File -Include *.css | ForEach-Object { if (Repair-CssFile -Path $_.FullName) { $changed++ } }
Write-Host ("Files updated: {0}" -f $changed) -ForegroundColor Yellow

Write-Host "Attempting to download archived assets from: $MissingCsv" -ForegroundColor Cyan
$downloaded = Download-ArchivedAssets -RepoRoot $RepoRoot -CsvPath (Join-Path $RepoRoot $MissingCsv)
Write-Host ("Assets downloaded: {0}" -f $downloaded.Count) -ForegroundColor Yellow

