param(
    [string]$RepoRoot = (Get-Location).Path,
    [string]$WaybackTimestamp = '20110907152140',
    [string]$OutputCsv = 'missing_report.csv'
)

$ErrorActionPreference = 'Stop'

function Get-InternalLinksFromContent {
    param(
        [string]$Content
    )
    $links = New-Object System.Collections.Generic.List[string]

    # HTML attributes: href/src/data/background
    $attrRegex = [regex]'(?i)(?:href|src|data|background)\s*=\s*["\'']([^"\'']+)["\'']'
    foreach ($m in $attrRegex.Matches($Content)) { $links.Add($m.Groups[1].Value) }

    # CSS url(...)
    $cssUrlRegex = [regex]'(?i)url\(\s*(["\'']?)([^\)"\'']+)\1\s*\)'
    foreach ($m in $cssUrlRegex.Matches($Content)) { $links.Add($m.Groups[2].Value) }

    # Basic JS static asset references (best-effort)
    $jsAssetRegex = [regex]'(?i)["\'']([^"\'']+\.(?:js|css|png|jpe?g|gif|svg|pdf|docx?|pptx?|xls[xm]?|zip|swf))["\'']'
    foreach ($m in $jsAssetRegex.Matches($Content)) { $links.Add($m.Groups[1].Value) }

    $filtered = $links |
        Where-Object { $_ -and $_ -notmatch '^(?i)(?:https?:|//|mailto:|javascript:|data:|tel:|ftp:|#)' } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' -and $_ -ne '#' }

    return $filtered
}

function Resolve-LinkPath {
    param(
        [string]$RepoRoot,
        [string]$FileRelPath,
        [string]$Link
    )
    $l = $Link -replace '&amp;','&'
    if ($l.Contains('#')) { $l = $l.Substring(0, $l.IndexOf('#')) }
    if ($l.Contains('?')) { $l = $l.Substring(0, $l.IndexOf('?')) }
    $l = $l.Trim()
    if (-not $l) { return $null }

    $fileDir = Split-Path -Parent $FileRelPath
    if ([string]::IsNullOrEmpty($fileDir)) { $fileDir = '' } else { $fileDir = $fileDir.Replace('\\','/') + '/' }
    $baseUri = [uri]("http://wsart.org/" + $fileDir)

    try {
        $resolved = [uri]::new($baseUri, $l)
        return $resolved.AbsolutePath.TrimStart('/')
    } catch {
        return $null
    }
}

function Test-TargetPaths {
    param(
        [string]$RepoRoot,
        [string]$NormPath
    )
    $checked = New-Object System.Collections.Generic.List[string]
    $exists = $false

    $p = $NormPath.Trim('/').Trim()
    if (-not $p) { return @{ Exists = $false; CheckedPaths = @() } }

    $candidates = New-Object System.Collections.Generic.List[string]
    $candidates.Add($p) | Out-Null

    # Also consider decoded/encoded variants to handle space vs %20 differences
    try {
        $pDecoded = [uri]::UnescapeDataString($p)
        if ($pDecoded -and $pDecoded -ne $p) { $candidates.Add($pDecoded) | Out-Null }
        $pEncoded = [System.Uri]::EscapeUriString($pDecoded)
        if ($pEncoded -and $pEncoded -ne $p -and $pEncoded -ne $pDecoded) { $candidates.Add($pEncoded) | Out-Null }
    } catch {}

    if ($p.EndsWith('/')) { $candidates.Add($p.TrimEnd('/') + '/index.html') | Out-Null }

    if ($p -notmatch '\\.[a-zA-Z0-9]{2,5}$') {
        $candidates.Add($p + '.html') | Out-Null
        $candidates.Add($p + '.htm') | Out-Null
        $candidates.Add($p.TrimEnd('/') + '/index.html') | Out-Null
    }

    foreach ($cand in $candidates) {
        if (-not [string]::IsNullOrEmpty($cand)) {
            $checked.Add($cand) | Out-Null
            if (-not $exists) {
                $fs = Join-Path $RepoRoot ($cand -replace '/','\\')
                if (Test-Path -LiteralPath $fs) { $exists = $true }
            }
        }
    }

    return @{ Exists = $exists; CheckedPaths = $checked.ToArray() }
}

function Check-WaybackAvailability {
    param(
        [string]$Url,
        [string]$Timestamp = '20110907152140'
    )
    $api = 'https://archive.org/wayback/available?url=' + [uri]::EscapeDataString($Url) + '&timestamp=' + $Timestamp
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri $api -TimeoutSec 20
        $json = $resp.Content | ConvertFrom-Json
        $closest = $json.archived_snapshots.closest
        if ($closest -and $closest.available -eq $true) {
            return @{ Available = $true; ArchivedUrl = [string]$closest.url; Timestamp = [string]$closest.timestamp }
        }
        return @{ Available = $false; ArchivedUrl = $null; Timestamp = $null }
    } catch {
        return @{ Available = $false; ArchivedUrl = $null; Timestamp = $null; Error = $_.Exception.Message }
    }
}

Write-Host "Scanning for HTML/CSS/JS files under: $RepoRoot" -ForegroundColor Cyan

$files = Get-ChildItem -Path $RepoRoot -Recurse -File -Include *.html,*.htm,*.css,*.js | ForEach-Object { $_.FullName }

$seen = @{}
$missing = @{}

foreach ($fullPath in $files) {
    $relPath = Resolve-Path -LiteralPath $fullPath | ForEach-Object { $_.Path.Substring($RepoRoot.Length).TrimStart('\\') }
    $relWeb = $relPath.Replace('\\','/')

    $content = Get-Content -LiteralPath $fullPath -Raw
    $links = Get-InternalLinksFromContent -Content $content

    foreach ($link in $links) {
        $norm = Resolve-LinkPath -RepoRoot $RepoRoot -FileRelPath $relWeb -Link $link
        if (-not $norm) { continue }

        if (-not $seen.ContainsKey($norm)) {
            $seen[$norm] = @{ FirstSeenIn = $relWeb; OriginalLink = $link }

            $probe = Test-TargetPaths -RepoRoot $RepoRoot -NormPath $norm
            if (-not $probe.Exists) {
                $missing[$norm] = @{ FirstSeenIn = $relWeb; OriginalLink = $link; CheckedPaths = ($probe.CheckedPaths -join '; ') }
            }
        }
    }
}

Write-Host ("Total unique internal references: {0}" -f $seen.Count)
Write-Host ("Missing locally: {0}" -f $missing.Count) -ForegroundColor Yellow

$results = @()
foreach ($k in $missing.Keys) {
    $url = 'http://wsart.org/' + $k.TrimStart('/')
    $avail = Check-WaybackAvailability -Url $url -Timestamp $WaybackTimestamp
    $results += [pscustomobject]@{
        Path = $k
        FirstSeenIn = $missing[$k].FirstSeenIn
        OriginalLink = $missing[$k].OriginalLink
        CheckedPaths = $missing[$k].CheckedPaths
        WaybackAvailable = [bool]$avail.Available
        WaybackUrl = $avail.ArchivedUrl
        WaybackTimestamp = $avail.Timestamp
    }
}

if ($results.Count -gt 0) {
    $results | Sort-Object -Property Path | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $RepoRoot $OutputCsv)
    Write-Host ("Wrote report: {0}" -f (Join-Path $RepoRoot $OutputCsv)) -ForegroundColor Green
} else {
    Write-Host "No missing internal files detected." -ForegroundColor Green
}
