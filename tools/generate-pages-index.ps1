param(
    [string] $SiteUrl = "https://sunchangsong.github.io/lockbox"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$excludedRootDirs = @(".git", "assets", "tools")

function HtmlEncode([string] $value) {
    return [System.Net.WebUtility]::HtmlEncode($value)
}

function RelativeCss([int] $depth) {
    if ($depth -eq 0) {
        return "assets/site.css"
    }

    return (("../" * $depth) + "assets/site.css")
}

function Write-Utf8File([string] $path, [string] $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function PageShell([string] $title, [string] $body, [int] $depth) {
    $css = RelativeCss $depth
    $encodedTitle = HtmlEncode $title
    return @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$encodedTitle</title>
  <link rel="stylesheet" href="$css">
</head>
<body>
  <main class="page">
$body
  </main>
</body>
</html>
"@
}

function FormatDocTitle([System.IO.FileInfo] $file) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    if ($stem -match "^(\d{4})(\d{2})(\d{2})$") {
        return "$($Matches[1])-$($Matches[2])-$($Matches[3])"
    }

    return $stem -replace "_", " "
}

function SiteUrlFor([string[]] $segments) {
    $base = $SiteUrl.TrimEnd("/")
    if ($segments.Count -eq 0) {
        return "$base/"
    }

    $encodedSegments = foreach ($segment in $segments) {
        [System.Uri]::EscapeDataString($segment)
    }

    return "$base/$($encodedSegments -join "/")"
}

$languageDirs = @(Get-ChildItem -LiteralPath $repoRoot -Directory |
    Where-Object { $excludedRootDirs -notcontains $_.Name } |
    Sort-Object Name)

$sitemapUrls = New-Object System.Collections.Generic.List[string]
$sitemapUrls.Add((SiteUrlFor @()))

$languageItems = foreach ($language in $languageDirs) {
    $docCount = (Get-ChildItem -LiteralPath $language.FullName -File -Filter "*.md" | Measure-Object).Count
    @"
      <a class="tile" href="$([System.Uri]::EscapeDataString($language.Name))/">
        <strong>$(HtmlEncode $language.Name)</strong>
        <span>$docCount documents</span>
      </a>
"@
}

$rootBody = @"
    <nav class="breadcrumbs" aria-label="Breadcrumbs">
      <span>LockBox</span>
    </nav>
    <header class="hero">
      <div>
        <p class="eyebrow">Encrypted content protection documentation</p>
        <h1>Choose a LockBox document language</h1>
        <p class="lead">Browse LockBox introductions in a crawlable GitHub Pages structure organized by language and document date.</p>
      </div>
      <div class="downloads">
        <a class="button primary" href="https://lockbox.movingshop.cn/en/">Official Website</a>
      </div>
    </header>
    <section class="section">
      <div class="section-title">
        <h2>Languages</h2>
        <span>$($languageDirs.Count) languages</span>
      </div>
      <div class="grid">
$($languageItems -join "`n")
      </div>
    </section>
"@

Write-Utf8File (Join-Path $repoRoot "index.html") (PageShell "LockBox Documentation" $rootBody 0)

foreach ($language in $languageDirs) {
    $docs = @(Get-ChildItem -LiteralPath $language.FullName -File -Filter "*.md" | Sort-Object Name)
    $docItems = foreach ($doc in $docs) {
        $docTitle = HtmlEncode (FormatDocTitle $doc)
        $href = [System.Uri]::EscapeDataString(([System.IO.Path]::GetFileNameWithoutExtension($doc.Name) + ".html"))
        @"
        <a class="tile" href="$href">
          <strong>$docTitle</strong>
          <span>LockBox introduction</span>
        </a>
"@
    }

    $languageLabel = HtmlEncode $language.Name
    $languageBody = @"
    <nav class="breadcrumbs" aria-label="Breadcrumbs">
      <a href="../">LockBox</a>
      <span>$languageLabel</span>
    </nav>
    <header class="hero compact">
      <div>
        <p class="eyebrow">Document language</p>
        <h1>$languageLabel</h1>
        <p class="lead">Available LockBox introduction documents in $languageLabel.</p>
      </div>
    </header>
    <section class="section">
      <div class="section-title">
        <h2>Documents</h2>
        <span>$($docs.Count) documents</span>
      </div>
      <div class="grid">
$($docItems -join "`n")
      </div>
    </section>
"@

    Write-Utf8File (Join-Path $language.FullName "index.html") (PageShell "$languageLabel - LockBox" $languageBody 1)
    $sitemapUrls.Add((SiteUrlFor @($language.Name, "")))

    foreach ($doc in $docs) {
        $docHref = [System.IO.Path]::GetFileNameWithoutExtension($doc.Name) + ".html"
        $sitemapUrls.Add((SiteUrlFor @($language.Name, $docHref)))
    }
}

$sitemapItems = foreach ($url in $sitemapUrls) {
    "  <url><loc>$(HtmlEncode $url)</loc></url>"
}

$sitemap = @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$($sitemapItems -join "`n")
</urlset>
"@

$robots = @"
User-agent: *
Allow: /

Sitemap: $($SiteUrl.TrimEnd("/"))/sitemap.xml
"@

Write-Utf8File (Join-Path $repoRoot "sitemap.xml") $sitemap
Write-Utf8File (Join-Path $repoRoot "robots.txt") $robots

Write-Host "Generated LockBox GitHub Pages indexes."
