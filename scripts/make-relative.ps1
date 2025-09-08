<#
  make-relative.ps1
  Rewrites root-absolute URLs (starting with "/") in HTML and CSS files to relative paths
  so files work when opened directly from a local folder (file://).

  - Attributes handled in HTML: href, src, action, poster, srcset
  - Rewrites href="/" and href="/#..." to point to index.html at the correct relative depth
  - CSS: rewrites url(/...) and @import "/..."

  Usage:
    pwsh scripts/make-relative.ps1

  Notes:
  - External URLs (http/https) are untouched.
  - Only forward-slash-rooted paths are rewritten; protocol-relative (//host) are left untouched.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RelativePrefix([string]$filePath, [string]$root) {
  $dir = Split-Path -Path $filePath -Parent
  $rel = $dir.Substring($root.Length)
  $rel = $rel.TrimStart([char]92, [char]47)
  if ([string]::IsNullOrEmpty($rel)) { return '' }
  $depth = ($rel -split '[\\/]').Count
  return ('../' * $depth)
}

function Rewrite-HtmlContent([string]$text, [string]$prefix) {
  # href="/" -> index.html
  $text = [regex]::Replace($text, 'href="/"', { param($m) 'href="' + $prefix + 'index.html"' })

  # href="/#hash" -> index.html#hash
  $text = [regex]::Replace($text, 'href="/(#.*?)"', { param($m) 'href="' + $prefix + 'index.html' + $m.Groups[1].Value + '"' })

  # Generic attributes href|src|action|poster="/path"
  $attrPattern = '(?<attr>(?:href|src|action|poster))="/(?<path>[^" >]+)"'
  $text = [regex]::Replace($text, $attrPattern, {
    param($m)
    $attr = $m.Groups['attr'].Value
    $path = $m.Groups['path'].Value
    if ($path.StartsWith('//')) { return $m.Value } # protocol-relative, skip
    $new = if ($path.StartsWith('#')) { 'index.html' + $path } else { $path }
    return ($attr + '="' + $prefix + $new + '"')
  })

  # srcset="/img/a.jpg 1x, /img/a@2x.jpg 2x"
  $text = [regex]::Replace($text, '(?<attr>srcset)="(?<val>[^"]+)"', {
    param($m)
    $attr = $m.Groups['attr'].Value
    $val = $m.Groups['val'].Value
    $newVal = [regex]::Replace($val, '(^|,\s*)(/[^\s,]+)', {
      param($m2)
      $lead = $m2.Groups[1].Value
      $url  = $m2.Groups[2].Value
      if ($url.StartsWith('//')) { return $m2.Value } # leave protocol-relative
      return $lead + $prefix + $url.Substring(1)
    })
    return ($attr + '="' + $newVal + '"')
  })

  return $text
}

function Rewrite-CssContent([string]$text, [string]$prefix) {
  # url(/path) and url('/path') and url("/path")
  $text = [regex]::Replace($text, 'url\((?<q>\"|'')?/(?<path>[^\)\"'']+)(\k<q>)?\)', {
    param($m)
    $q = $m.Groups['q'].Value
    $p = $m.Groups['path'].Value
    if ($p.StartsWith('/')) { return $m.Value } # protocol-relative //, skip
    return 'url(' + $q + $prefix + $p + $q + ')'
  })

  # @import "/path.css" or @import url("/path.css")
  $text = [regex]::Replace($text, '@import\s+(url\()?([\"''])/(?<path>[^\"'']+)([\"''])(\))?', {
    param($m)
    $hasUrl = $m.Groups[1].Success
    $quoteOpen = $m.Groups[2].Value
    $path = $m.Groups['path'].Value
    $quoteClose = $m.Groups[4].Value
    $urlClose = if ($m.Groups[5].Success) { ')' } else { '' }
    return '@import ' + ($(if ($hasUrl) { 'url(' } else { '' })) + $quoteOpen + $prefix + $path + $quoteClose + $urlClose
  })

  return $text
}

$root = (Get-Location).Path
$files = @()
$files += Get-ChildItem -Recurse -File -Include *.html
$files += Get-ChildItem -Recurse -File -Include *.css

$changed = @()
foreach ($file in $files) {
  $prefix = Get-RelativePrefix -filePath $file.FullName -root $root
  $original = Get-Content -Raw -LiteralPath $file.FullName
  $updated = $original
  if ($file.Extension -ieq '.html') {
    $updated = Rewrite-HtmlContent -text $updated -prefix $prefix
  } elseif ($file.Extension -ieq '.css') {
    $updated = Rewrite-CssContent -text $updated -prefix $prefix
  }
  if ($updated -ne $original) {
    Set-Content -LiteralPath $file.FullName -Value $updated -NoNewline
    $filesRel = $file.FullName.Substring($root.Length).TrimStart([char]92, [char]47)
    $changed += $filesRel
  }
}

if ($changed.Count -gt 0) {
  Write-Host ("Rewrote to relative in {0} file(s):" -f $changed.Count)
  $changed | ForEach-Object { Write-Host " - $_" }
} else {
  Write-Host 'No changes were necessary.'
}
