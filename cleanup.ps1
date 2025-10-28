# Cleanup script - Remove temporary analysis files and unnecessary project files

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
Write-Host ""

$removedCount = 0
$removedSize = 0

# Remove temporary analysis folders
Write-Host "Removing temporary analysis folders..." -ForegroundColor Yellow
Get-ChildItem -Path $ScriptDir -Directory -Filter 'sdk-analysis-android-*' -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $size = (Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        Write-Host "  Removing: $($_.Name) [$([math]::Round($size/1MB, 2)) MB]" -ForegroundColor Gray
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        $removedCount++
        $removedSize += $size
    }
    catch {
        Write-Host "  Warning: Could not remove $($_.Name): $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# Remove merged APK files
Get-ChildItem -Path $ScriptDir -Filter 'merged-*.apk' -ErrorAction SilentlyContinue | ForEach-Object {
    $size = $_.Length
    Write-Host "  Removing: $($_.Name) [$([math]::Round($size/1MB, 2)) MB]" -ForegroundColor Gray
    Remove-Item $_.FullName -Force
    $removedCount++
    $removedSize += $size
}

# Remove old report files (keep the most recent 3)
Write-Host "`nCleaning up old analysis reports (keeping 3 most recent)..." -ForegroundColor Yellow
$reportFiles = Get-ChildItem -Path $ScriptDir -Filter '*android-*.txt' -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Select-Object -Skip 3

if ($reportFiles) {
    $reportFiles | ForEach-Object {
        Write-Host "  Removing old report: $($_.Name)" -ForegroundColor Gray
        Remove-Item $_.FullName -Force
        $removedCount++
    }
}

# Remove macOS specific files
Write-Host "`nRemoving macOS/iOS specific files..." -ForegroundColor Yellow
$macFiles = @('detect-sdk-ios.sh', 'download-apk-helper.sh', 'SDK-Analyzer.applescript', 'SDK-Analyzer-v1.0.zip')
foreach ($file in $macFiles) {
    $fullPath = Join-Path $ScriptDir $file
    if (Test-Path $fullPath) {
        Write-Host "  Removing: $file" -ForegroundColor Gray
        Remove-Item $fullPath -Force
        $removedCount++
    }
}

# Remove backup files
Get-ChildItem -Path $ScriptDir -Filter '*_backup_*' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  Removing backup: $($_.Name)" -ForegroundColor Gray
    Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
    $removedCount++
}

# Remove old markdown documentation (optional - uncomment if needed)
# Get-ChildItem -Path $ScriptDir -Filter '*.md' -ErrorAction SilentlyContinue |
#     Where-Object { $_.Name -ne 'README.md' } | ForEach-Object {
#     Write-Host "  Removing: $($_.Name)" -ForegroundColor Gray
#     Remove-Item $_.FullName -Force
#     $removedCount++
# }

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Cleanup complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor White
Write-Host "  Files/folders removed: $removedCount" -ForegroundColor Yellow
if ($removedSize -gt 0) {
    Write-Host "  Space freed: $([math]::Round($removedSize/1MB, 2)) MB" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Kept files:" -ForegroundColor White
Write-Host "  - detect-sdk-android.ps1 (Core script)" -ForegroundColor Green
Write-Host "  - SDK-Analyzer-GUI.ps1 (GUI interface)" -ForegroundColor Green
Write-Host "  - data\library-info.txt (SDK database)" -ForegroundColor Green
Write-Host "  - data\competitors.txt (Competitor list)" -ForegroundColor Green
Write-Host "  - Latest 3 analysis reports" -ForegroundColor Green
Write-Host "  - Documentation files" -ForegroundColor Green
