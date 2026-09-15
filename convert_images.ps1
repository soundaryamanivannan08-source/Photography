$htmlFiles = Get-ChildItem -Path . -Filter *.html -Recurse
$imgDir = "assets/images"
if (-not (Test-Path $imgDir)) { New-Item -ItemType Directory -Path $imgDir -Force | Out-Null }

$pattern = 'https://images.unsplash.com/[a-zA-Z0-9\-]+\?[a-zA-Z0-9=&.\-]+'
$urls = @()
foreach ($file in $htmlFiles) {
    $content = Get-Content $file.FullName -Raw
    $matches = [regex]::Matches($content, $pattern)
    foreach ($m in $matches) {
        $urls += $m.Value
    }
}
$urls = $urls | Sort-Object -Unique

$urlMap = @{}
$counter = 1
foreach ($url in $urls) {
    Write-Host "Processing $url"
    $baseUri = $url -replace "\?.*", ""
    
    $w = 800
    if ($url -match "w=(\d+)") { $w = [int]$matches[1] }
    
    if ($w -gt 1000) { $w = 1000 }
    
    $q = 60
    
    $localFile = "$imgDir/img_$counter.webp"
    $success = $false
    
    while (-not $success) {
        $dlUrl = "$baseUri`?w=$w&q=$q&fm=webp"
        
        try {
            Invoke-WebRequest -Uri $dlUrl -OutFile $localFile
            $fileInfo = Get-Item $localFile
            if ($fileInfo.Length -le 92160) { # 90KB
                $success = $true
            } else {
                if ($q -gt 20) {
                    $q -= 20
                } else {
                    $w = [math]::Floor($w * 0.8)
                }
                Write-Host "Too large ($($fileInfo.Length) bytes). Retrying with w=$w, q=$q"
            }
        } catch {
            Write-Host "Error downloading $dlUrl"
            $success = $true
        }
    }
    
    $urlMap[$url] = $localFile
    $counter++
}

foreach ($file in $htmlFiles) {
    $content = Get-Content $file.FullName -Raw
    $changed = $false
    foreach ($key in $urlMap.Keys) {
        if ($content.Contains($key)) {
            $content = $content.Replace($key, $urlMap[$key])
            $changed = $true
        }
    }
    if ($changed) {
        Set-Content -Path $file.FullName -Value $content
        Write-Host "Updated $($file.Name)"
    }
}
