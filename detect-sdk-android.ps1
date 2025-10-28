<#
.SYNOPSIS
    Android App SDK Detection Script for Windows 11

.DESCRIPTION
    Automates the process of downloading and analyzing Android apps
    to detect the presence of specific SDKs or libraries.

.PARAMETER SDKNames
    SDK names to search for (can specify multiple)

.PARAMETER ListAll
    List all libraries and SDKs (default if no SDK names specified)

.PARAMETER URL
    Google Play Store URL

.PARAMETER PackageName
    Package name (bundle identifier)

.PARAMETER APKFile
    Path to existing APK or XAPK file to analyze

.PARAMETER OutputReport
    Output report file (default: auto-generated with app name)

.PARAMETER WorkDir
    Working directory for analysis (default: auto-generated)

.PARAMETER NoCleanup
    Don't delete temporary files after analysis

.PARAMETER Verbose
    Enable verbose output

.EXAMPLE
    .\detect-sdk-android.ps1 -APKFile "C:\path\to\app.apk"

.EXAMPLE
    .\detect-sdk-android.ps1 -SDKNames "pspdfkit","nutrient" -URL "https://play.google.com/store/apps/details?id=com.example.app"

.EXAMPLE
    .\detect-sdk-android.ps1 -PackageName "com.example.app" -ListAll

.NOTES
    Version: 1.0
    Author: Created for SDK license compliance verification
    Requires: Java JDK, apktool, Internet connection (for downloads)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$SDKNames = @(),

    [Parameter(Mandatory=$false)]
    [switch]$ListAll,

    [Parameter(Mandatory=$false)]
    [string]$URL = "",

    [Parameter(Mandatory=$false)]
    [string]$PackageName = "",

    [Parameter(Mandatory=$false)]
    [string]$APKFile = "",

    [Parameter(Mandatory=$false)]
    [string]$OutputReport = "sdk-detection-report.txt",

    [Parameter(Mandatory=$false)]
    [string]$WorkDir = "",

    [Parameter(Mandatory=$false)]
    [switch]$NoCleanup,

    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput
)

# Load required assemblies
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Script configuration
$ErrorActionPreference = "Stop"
$OriginalDir = Get-Location
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrEmpty($WorkDir)) {
    $WorkDir = Join-Path $PWD "sdk-analysis-android-$Timestamp"
}

$CompetitorsFile = Join-Path $OriginalDir "data\competitors.txt"
$LibraryInfoFile = Join-Path $OriginalDir "data\library-info.txt"

# Global variables
$script:AppInfo = @{
    Package = "N/A"
    Name = "N/A"
    VersionName = "N/A"
    VersionCode = "N/A"
}
$script:AllLibraries = @()
$script:AllLibraryDetails = @()
$script:CompetitorNames = @()
$script:CompetitorProducts = @()
$script:DetectedSDKs = @()
$script:LibraryVersions = @()
$script:PlayServicesVersions = @()
$script:AndroidXLibraries = @()
$script:AppPermissions = @()
$script:AppFeatures = @()
$script:BuildInfo = @()
$script:KotlinInfo = @()
$script:AssetsInfo = @()
$script:APKExtractedPath = ""
$script:APKRawPath = ""
$script:FinalReportPath = ""

################################################################################
# Helper Functions - Console Output
################################################################################

function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "❌ ERROR: $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  WARNING: $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Write-Found {
    param([string]$Message)
    Write-Host "🔍 FOUND: $Message" -ForegroundColor Magenta
}

function Write-VerboseLog {
    param([string]$Message)
    if ($VerboseOutput) {
        Write-Host "[DEBUG] $Message" -ForegroundColor Cyan
    }
}

################################################################################
# Usage and Help
################################################################################

function Show-Usage {
    @"

ANDROID APP SDK DETECTION SCRIPT FOR WINDOWS 11

USAGE:
    .\detect-sdk-android.ps1 [OPTIONS]

OPTIONS:
    -SDKNames <names>         SDK names to search for (comma-separated or array)
                              Example: -SDKNames "pspdfkit","nutrient"
                              Note: If not specified, all libraries will be listed

    -ListAll                  List all libraries and SDKs (default if no SDKNames)

    -URL <url>                Google Play Store URL
                              Example: -URL "https://play.google.com/store/apps/details?id=com.example.app"

    -PackageName <id>         Package name (bundle identifier)
                              Example: -PackageName "com.example.app"

    -APKFile <path>           Path to existing APK or XAPK file to analyze
                              Example: -APKFile "C:\path\to\app.apk"

    -OutputReport <file>      Output report file (default: auto-generated)

    -WorkDir <dir>            Working directory (default: auto-generated)

    -NoCleanup                Don't delete temporary files after analysis

    -VerboseOutput            Enable verbose output

    -Help                     Show this help message

EXAMPLES:
    # List all libraries in an APK
    .\detect-sdk-android.ps1 -APKFile "C:\Downloads\app.apk"

    # Analyze for specific SDKs
    .\detect-sdk-android.ps1 -SDKNames "pspdfkit","nutrient" -URL "https://play.google.com/store/apps/details?id=com.example.app"

    # List all libraries using package name
    .\detect-sdk-android.ps1 -PackageName "com.example.app"

    # Analyze with verbose output and keep files
    .\detect-sdk-android.ps1 -ListAll -PackageName "com.example.app" -VerboseOutput -NoCleanup

REQUIREMENTS:
    - Windows 11
    - Java JDK (for apktool)
    - apktool (will be auto-downloaded if missing)
    - Internet connection (for downloads)
    - Optional: ADB (Android SDK) for device extraction

"@
}

################################################################################
# Validation Functions
################################################################################

function Test-JavaInstalled {
    try {
        $javaVersion = java -version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-VerboseLog "Java: found"
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

function Install-Java {
    Write-Warning "Java not found. apktool requires Java."
    Write-Info "Please install Java JDK manually:"
    Write-Host "  1. Download from: https://www.oracle.com/java/technologies/downloads/" -ForegroundColor Yellow
    Write-Host "  2. Or install via winget: winget install Oracle.JDK.21" -ForegroundColor Yellow
    Write-Host "  3. Or install via Chocolatey: choco install openjdk" -ForegroundColor Yellow
    throw "Java is required but not installed. Please install and retry."
}

function Get-ApkTool {
    $apktoolDir = Join-Path $env:LOCALAPPDATA "apktool"
    $apktoolJar = Join-Path $apktoolDir "apktool.jar"
    $apktoolBat = Join-Path $apktoolDir "apktool.bat"

    if (Test-Path $apktoolJar) {
        Write-VerboseLog "apktool: found at $apktoolJar"
        return $apktoolDir
    }

    Write-Info "apktool not found. Downloading apktool..."

    New-Item -ItemType Directory -Force -Path $apktoolDir | Out-Null

    try {
        # Download apktool.jar
        $apktoolUrl = "https://github.com/iBotPeaches/Apktool/releases/download/v2.9.3/apktool_2.9.3.jar"
        Write-Info "Downloading apktool.jar..."
        Invoke-WebRequest -Uri $apktoolUrl -OutFile $apktoolJar -UseBasicParsing

        # Create wrapper batch file
        $batContent = @"
@echo off
if "%1"=="" goto help
java -jar "$apktoolJar" %*
goto end
:help
java -jar "$apktoolJar"
:end
"@
        Set-Content -Path $apktoolBat -Value $batContent

        # Add to PATH for current session
        $env:Path += ";$apktoolDir"

        Write-Success "apktool installed successfully at $apktoolDir"
        Write-Info "apktool has been added to PATH for this session"

        return $apktoolDir
    }
    catch {
        Write-ErrorMsg "Failed to download apktool: $_"
        Write-Host "Please download manually from: https://ibotpeaches.github.io/Apktool/" -ForegroundColor Yellow
        throw
    }
}

function Test-Requirements {
    Write-Header "Checking Requirements"

    # Check Java
    if (-not (Test-JavaInstalled)) {
        Install-Java
    }
    else {
        Write-Success "Java is installed"
    }

    # Check/Install apktool
    $apktoolPath = Get-ApkTool
    Write-Success "apktool is available"

    Write-Success "All required tools found"
}

function Test-Inputs {
    # If no SDK names provided, enable list all mode
    if ($SDKNames.Count -eq 0) {
        $script:ListAll = $true
        Write-VerboseLog "No specific SDKs specified - will list all libraries"
    }

    # Check that at least one app identifier is provided
    if ([string]::IsNullOrEmpty($URL) -and [string]::IsNullOrEmpty($PackageName) -and [string]::IsNullOrEmpty($APKFile)) {
        Write-ErrorMsg "Must provide one of: -URL, -PackageName, or -APKFile"
        Show-Usage
        throw "Invalid input parameters"
    }
}

################################################################################
# APK Acquisition Functions
################################################################################

function Get-PackageFromURL {
    param([string]$Url)

    if ($Url -match 'id=([^&]+)') {
        return $matches[1]
    }

    Write-ErrorMsg "Could not extract package name from URL: $Url"
    Write-Host "Please provide a valid Play Store URL." -ForegroundColor Yellow
    Write-Host "Example: https://play.google.com/store/apps/details?id=com.example.app" -ForegroundColor Yellow
    throw "Invalid URL format"
}

function Get-APKFromAPKPure {
    param(
        [string]$Package,
        [string]$OutputFile
    )

    Write-Info "Attempting to download APK from APKPure..."

    try {
        $apkpureUrl = "https://d.apkpure.com/b/APK/$Package`?version=latest"
        Invoke-WebRequest -Uri $apkpureUrl -OutFile $OutputFile -UseBasicParsing -ErrorAction Stop

        # Verify it's a valid ZIP/APK file
        $fileHeader = Get-Content $OutputFile -Encoding Byte -TotalCount 4
        if ($fileHeader[0] -eq 0x50 -and $fileHeader[1] -eq 0x4B) {  # PK header
            Write-Success "Downloaded APK from APKPure"
            return $true
        }
    }
    catch {
        Write-VerboseLog "APKPure download failed: $_"
    }

    return $false
}

function Get-APKFromDevice {
    param(
        [string]$Package,
        [string]$OutputFile
    )

    # Check if ADB is available
    $adbPath = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adbPath) {
        return $false
    }

    Write-Info "Attempting to extract APK from connected Android device..."

    try {
        # Check if device is connected
        $devices = & adb devices
        if (-not ($devices -match "device$")) {
            Write-Warning "No Android device connected via ADB"
            return $false
        }

        # Get APK path on device
        $apkPath = (& adb shell pm path $Package 2>$null) -replace 'package:', '' -replace '\r', ''

        if ([string]::IsNullOrEmpty($apkPath)) {
            Write-Warning "Package $Package not found on connected device"
            return $false
        }

        # Pull APK from device
        & adb pull $apkPath $OutputFile 2>&1 | Out-Null

        if (Test-Path $OutputFile) {
            Write-Success "Extracted APK from Android device"
            return $true
        }
    }
    catch {
        Write-VerboseLog "Device extraction failed: $_"
    }

    return $false
}

function Expand-XAPK {
    param(
        [string]$XAPKFile,
        [string]$OutputAPK
    )

    Write-VerboseLog "Processing XAPK file: $XAPKFile"

    # Create temporary directory for XAPK extraction
    $xapkTemp = Join-Path $WorkDir "xapk-temp"
    New-Item -ItemType Directory -Force -Path $xapkTemp | Out-Null

    # Extract XAPK (it's just a ZIP file)
    Write-VerboseLog "Extracting XAPK..."
    try {
        Expand-Archive -Path $XAPKFile -DestinationPath $xapkTemp -Force
    }
    catch {
        Write-ErrorMsg "Failed to extract XAPK file"
        Remove-Item -Recurse -Force $xapkTemp -ErrorAction SilentlyContinue
        return $false
    }

    # Find the base APK
    $baseApk = Get-ChildItem -Path $xapkTemp -Filter "*.apk" -Recurse |
               Where-Object { $_.Name -notlike "config.*" } |
               Select-Object -First 1

    if (-not $baseApk) {
        Write-ErrorMsg "No base APK found in XAPK"
        Remove-Item -Recurse -Force $xapkTemp -ErrorAction SilentlyContinue
        return $false
    }

    Write-VerboseLog "Found base APK: $($baseApk.Name)"

    # Create merge directory
    $mergeDir = Join-Path $WorkDir "merged-apk"
    if (Test-Path $mergeDir) {
        Remove-Item -Recurse -Force $mergeDir
    }
    New-Item -ItemType Directory -Force -Path $mergeDir | Out-Null

    # Extract base APK
    Write-VerboseLog "Extracting base APK..."
    try {
        Expand-Archive -Path $baseApk.FullName -DestinationPath $mergeDir -Force
    }
    catch {
        Write-ErrorMsg "Failed to extract base APK"
        Remove-Item -Recurse -Force $xapkTemp, $mergeDir -ErrorAction SilentlyContinue
        return $false
    }

    # Find and merge architecture-specific APKs
    $archApks = @()
    $archApks += @(Get-ChildItem -Path $xapkTemp -Filter "config.arm*.apk" -Recurse -ErrorAction SilentlyContinue)
    $archApks += @(Get-ChildItem -Path $xapkTemp -Filter "config.x86*.apk" -Recurse -ErrorAction SilentlyContinue)

    if ($archApks.Count -gt 0) {
        Write-Info "Merging architecture-specific libraries..."
        foreach ($archApk in $archApks) {
            if ($archApk) {
                Write-VerboseLog "Merging: $($archApk.Name)"
                try {
                    Expand-Archive -Path $archApk.FullName -DestinationPath $mergeDir -Force
                }
                catch {
                    Write-VerboseLog "Warning: Could not merge $($archApk.Name)"
                }
            }
        }
        Write-Success "Architecture libraries merged"
    }

    # Find and merge other config APKs
    $configApks = @(Get-ChildItem -Path $xapkTemp -Filter "config.*.apk" -Recurse -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -notlike "config.arm*" -and $_.Name -notlike "config.x86*" })

    if ($configApks.Count -gt 0) {
        Write-VerboseLog "Merging additional config APKs..."
        foreach ($configApk in $configApks) {
            if ($configApk) {
                try {
                    Expand-Archive -Path $configApk.FullName -DestinationPath $mergeDir -Force
                }
                catch {
                    Write-VerboseLog "Warning: Could not merge $($configApk.Name)"
                }
            }
        }
    }

    # Repackage as APK
    Write-VerboseLog "Repackaging merged APK..."

    # Compress-Archive always creates .zip, so we create as .zip first then rename
    $tempZipPath = Join-Path $WorkDir "temp-merged.zip"
    $finalApkPath = Join-Path $WorkDir $OutputAPK

    try {
        # Create ZIP file
        Compress-Archive -Path "$mergeDir\*" -DestinationPath $tempZipPath -Force

        # Rename .zip to .apk
        if (Test-Path $finalApkPath) {
            Remove-Item $finalApkPath -Force
        }
        Move-Item $tempZipPath $finalApkPath -Force

        Write-VerboseLog "Successfully created merged APK"
    }
    catch {
        Write-ErrorMsg "Failed to repackage APK: $_"
        Remove-Item -Recurse -Force $xapkTemp, $mergeDir -ErrorAction SilentlyContinue
        Remove-Item $tempZipPath -Force -ErrorAction SilentlyContinue
        return $false
    }

    # Cleanup temp directories
    Remove-Item -Recurse -Force $xapkTemp, $mergeDir -ErrorAction SilentlyContinue

    # Verify the merged APK was created
    if (-not (Test-Path $finalApkPath)) {
        Write-ErrorMsg "Failed to create merged APK at: $finalApkPath"
        return $false
    }

    $mergedSize = (Get-Item $finalApkPath).Length / 1MB
    Write-VerboseLog "Merged APK size: $([math]::Round($mergedSize, 2)) MB"

    return $true
}

function Get-APKFile {
    Write-Header "Obtaining APK"

    # Option 1: User provided APK file
    if (-not [string]::IsNullOrEmpty($APKFile)) {
        # Convert to absolute path BEFORE changing directory
        $sourceAPKPath = $APKFile
        if (-not [System.IO.Path]::IsPathRooted($sourceAPKPath)) {
            $sourceAPKPath = Join-Path $OriginalDir $sourceAPKPath
        }

        if (-not (Test-Path $sourceAPKPath)) {
            Write-ErrorMsg "APK file not found: $sourceAPKPath"
            throw "File not found"
        }

        New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
        Set-Location $WorkDir

        $targetAPKFile = "app.apk"

        # Check if it's an XAPK file
        if ($sourceAPKPath -like "*.xapk") {
            Write-Info "📦 Detected XAPK file: $(Split-Path -Leaf $sourceAPKPath)"
            Write-Info "Extracting XAPK and merging split APKs..."

            if (-not (Expand-XAPK -XAPKFile $sourceAPKPath -OutputAPK $targetAPKFile)) {
                Write-ErrorMsg "Failed to process XAPK file"
                throw "XAPK processing failed"
            }

            Write-Success "XAPK processed and merged into: $targetAPKFile"

            # Verify the merged APK exists
            if (-not (Test-Path $targetAPKFile)) {
                Write-ErrorMsg "Merged APK not found after XAPK processing"
                throw "XAPK merge failed"
            }

            $mergedSize = (Get-Item $targetAPKFile).Length / 1MB
            Write-Info "Merged APK size: $([math]::Round($mergedSize, 2)) MB"
            return
        }

        # Regular APK file - just copy it
        Write-Info "📱 Using APK file: $(Split-Path -Leaf $sourceAPKPath)"
        Copy-Item $sourceAPKPath $targetAPKFile
        Write-Success "APK file copied"
        return
    }

    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    Set-Location $WorkDir

    $apkFile = "app.apk"

    # Extract package name from URL if provided
    if (-not [string]::IsNullOrEmpty($URL)) {
        $script:PackageName = Get-PackageFromURL -Url $URL
        Write-Success "Extracted package name: $PackageName"
    }

    Write-Info "Package name: $PackageName"
    Write-Info "Trying multiple download methods...`n"

    # Try method 1: APKPure
    if (Get-APKFromAPKPure -Package $PackageName -OutputFile $apkFile) {
        return
    }

    # Try method 2: Connected Android device
    if (Get-APKFromDevice -Package $PackageName -OutputFile $apkFile) {
        return
    }

    # All methods failed - provide guidance
    Write-ErrorMsg "Could not obtain APK automatically"
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Write-Warning "Don't worry! Here's how to get the APK manually:"
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Yellow

    Write-Host "OPTION 1: Download from APKPure (Easiest)`n" -ForegroundColor White
    Write-Host "  1. Open this URL in your browser:" -ForegroundColor White
    Write-Host "     https://apkpure.com/search?q=$PackageName`n" -ForegroundColor Cyan
    Write-Host "  2. Click on the first result (the correct app)" -ForegroundColor White
    Write-Host "  3. Click the green 'Download APK' button" -ForegroundColor White
    Write-Host "  4. Save the file`n" -ForegroundColor White
    Write-Host "  5. Then run:" -ForegroundColor White
    Write-Host "     .\detect-sdk-android.ps1 -APKFile `"C:\Path\To\Downloaded.apk`"`n" -ForegroundColor Green

    # Offer to open browser
    $openBrowser = Read-Host "Would you like to open APKPure in your browser now? (y/n)"
    if ($openBrowser -eq 'y' -or $openBrowser -eq 'Y') {
        Start-Process "https://apkpure.com/search?q=$PackageName"
        Write-Success "Browser opened! Download the APK and run the command shown above."
    }

    throw "Manual APK download required"
}

################################################################################
# Library Information Functions
################################################################################

function Get-LibraryDescription {
    param([string]$LibName)

    if (-not (Test-Path $LibraryInfoFile)) {
        return ""
    }

    $result = Select-String -Path $LibraryInfoFile -Pattern "^$LibName\|" -CaseSensitive:$false | Select-Object -First 1

    if ($result) {
        $fields = $result.Line -split '\|'
        if ($fields.Count -ge 2) {
            return $fields[1]
        }
    }

    return ""
}

function Get-LibraryVendor {
    param([string]$LibName)

    if (-not (Test-Path $LibraryInfoFile)) {
        return ""
    }

    $result = Select-String -Path $LibraryInfoFile -Pattern "^$LibName\|" -CaseSensitive:$false | Select-Object -First 1

    if ($result) {
        $fields = $result.Line -split '\|'
        if ($fields.Count -ge 3) {
            return $fields[2]
        }
    }

    return ""
}

function Get-LibraryVersion {
    param([string]$SearchName)

    foreach ($versionEntry in $script:LibraryVersions) {
        $parts = $versionEntry -split '\|'
        if ($parts.Count -eq 2) {
            $libName = $parts[0]
            $version = $parts[1]

            if ($libName -like "*$SearchName*") {
                return $version
            }
        }
    }

    return ""
}

function Get-LibraryVersions {
    $metaInfDir = Join-Path $script:APKRawPath "META-INF"

    if (-not (Test-Path $metaInfDir)) {
        Write-VerboseLog "META-INF directory not found"
        return
    }

    Write-VerboseLog "Extracting library versions from META-INF..."

    $versionFiles = Get-ChildItem -Path $metaInfDir -Filter "*.version" -Recurse -ErrorAction SilentlyContinue

    foreach ($versionFile in $versionFiles) {
        $libName = [System.IO.Path]::GetFileNameWithoutExtension($versionFile.Name)
        $version = (Get-Content $versionFile.FullName -Raw).Trim()

        if (-not [string]::IsNullOrEmpty($version)) {
            $script:LibraryVersions += "$libName|$version"
        }
    }

    Write-VerboseLog "Found $($script:LibraryVersions.Count) library versions"
}

################################################################################
# Metadata Extraction Functions
################################################################################

function Get-PlayServicesVersions {
    Write-VerboseLog "Extracting Google Play Services versions..."

    $propFiles = Get-ChildItem -Path $script:APKRawPath -Filter "*play-services-*.properties" -Recurse -ErrorAction SilentlyContinue
    $propFiles += Get-ChildItem -Path $script:APKRawPath -Filter "*firebase-*.properties" -Recurse -ErrorAction SilentlyContinue

    foreach ($propFile in $propFiles) {
        $content = Get-Content $propFile.FullName -ErrorAction SilentlyContinue
        $version = ($content | Select-String "^version=").ToString() -replace 'version=', ''
        $client = ($content | Select-String "^client=").ToString() -replace 'client=', ''

        if ($client -and $version) {
            $script:PlayServicesVersions += "$client|$version"
        }
    }

    Write-VerboseLog "Found $($script:PlayServicesVersions.Count) Play Services/Firebase libraries"
}

function Get-AndroidXLibraries {
    Write-VerboseLog "Extracting AndroidX library list..."

    $metaInfDir = Join-Path $script:APKRawPath "META-INF"

    if (-not (Test-Path $metaInfDir)) {
        return
    }

    $versionFiles = Get-ChildItem -Path $metaInfDir -Filter "androidx.*.version" -Recurse -ErrorAction SilentlyContinue

    foreach ($versionFile in $versionFiles) {
        $libName = [System.IO.Path]::GetFileNameWithoutExtension($versionFile.Name)
        $version = (Get-Content $versionFile.FullName -Raw).Trim()

        if ($version -and $libName -like "androidx.*") {
            $script:AndroidXLibraries += "$libName|$version"
        }
    }

    Write-VerboseLog "Found $($script:AndroidXLibraries.Count) AndroidX libraries"
}

function Get-Permissions {
    Write-VerboseLog "Extracting permissions and features..."

    $manifest = Join-Path $script:APKExtractedPath "AndroidManifest.xml"

    if (-not (Test-Path $manifest)) {
        return
    }

    $content = Get-Content $manifest -Raw

    # Extract permissions
    $permMatches = [regex]::Matches($content, 'uses-permission[^>]*android:name="([^"]*)"')
    foreach ($match in $permMatches) {
        if ($match.Groups.Count -ge 2) {
            $script:AppPermissions += $match.Groups[1].Value
        }
    }

    # Extract features
    $featMatches = [regex]::Matches($content, 'uses-feature[^>]*android:name="([^"]*)"[^>]*(?:android:required="([^"]*)")?')
    foreach ($match in $featMatches) {
        if ($match.Groups.Count -ge 2) {
            $featName = $match.Groups[1].Value
            $required = if ($match.Groups.Count -ge 3 -and $match.Groups[2].Value -eq "false") { "optional" } else { "required" }
            $script:AppFeatures += "$featName|$required"
        }
    }

    Write-VerboseLog "Found $($script:AppPermissions.Count) permissions and $($script:AppFeatures.Count) features"
}

function Get-BuildInfo {
    Write-VerboseLog "Extracting build information..."

    $metadataFile = Join-Path $script:APKRawPath "META-INF\com\android\build\gradle\app-metadata.properties"

    if (Test-Path $metadataFile) {
        $content = Get-Content $metadataFile
        foreach ($line in $content) {
            if ($line -match '^([^=]+)=(.+)$') {
                $script:BuildInfo += "$($matches[1])|$($matches[2])"
            }
        }
    }

    Write-VerboseLog "Found $($script:BuildInfo.Count) build metadata entries"
}

function Get-KotlinInfo {
    Write-VerboseLog "Extracting Kotlin metadata..."

    $kotlinJson = Join-Path $script:APKRawPath "kotlin-tooling-metadata.json"
    if (Test-Path $kotlinJson) {
        $script:KotlinInfo += "metadata_found|yes"
    }

    $metaInfDir = Join-Path $script:APKRawPath "META-INF"
    if (Test-Path $metaInfDir) {
        $versionFiles = Get-ChildItem -Path $metaInfDir -Filter "kotlin*.version" -Recurse -ErrorAction SilentlyContinue

        foreach ($versionFile in $versionFiles) {
            $libName = [System.IO.Path]::GetFileNameWithoutExtension($versionFile.Name)
            $version = (Get-Content $versionFile.FullName -Raw).Trim()

            if ($version -and ($libName -like "kotlin*" -or $libName -like "kotlinx*")) {
                $script:KotlinInfo += "$libName|$version"
            }
        }
    }

    Write-VerboseLog "Found $($script:KotlinInfo.Count) Kotlin metadata entries"
}

function Get-AssetsSummary {
    Write-VerboseLog "Extracting assets and resources summary..."

    # Count assets
    $assetCount = 0
    $assetSize = "0"
    $assetsDir = Join-Path $script:APKRawPath "assets"
    if (Test-Path $assetsDir) {
        $assetCount = (Get-ChildItem -Path $assetsDir -Recurse -File -ErrorAction SilentlyContinue).Count
        $assetSizeBytes = (Get-ChildItem -Path $assetsDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($assetSizeBytes) {
            $assetSize = "{0:N2} MB" -f ($assetSizeBytes / 1MB)
        }
    }
    $script:AssetsInfo += "asset_count|$assetCount"
    $script:AssetsInfo += "asset_size|$assetSize"

    # Count resources
    $resCount = 0
    $resSize = "0"
    $resDir = Join-Path $script:APKRawPath "res"
    if (Test-Path $resDir) {
        $resCount = (Get-ChildItem -Path $resDir -Recurse -File -ErrorAction SilentlyContinue).Count
        $resSizeBytes = (Get-ChildItem -Path $resDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($resSizeBytes) {
            $resSize = "{0:N2} MB" -f ($resSizeBytes / 1MB)
        }
    }
    $script:AssetsInfo += "res_count|$resCount"
    $script:AssetsInfo += "res_size|$resSize"

    # Detect supported languages
    if (Test-Path $resDir) {
        $languages = Get-ChildItem -Path $resDir -Directory -Filter "values-*" -ErrorAction SilentlyContinue |
                     ForEach-Object { ($_.Name -replace '^values-', '') -replace '-.*$', '' } |
                     Select-Object -Unique |
                     Sort-Object

        if ($languages) {
            $languageList = $languages -join ','
            $script:AssetsInfo += "languages|$languageList"
        }
    }

    Write-VerboseLog "Assets: $assetCount files, Resources: $resCount files"
}

################################################################################
# APK Extraction
################################################################################

function Expand-APK {
    Write-Header "Extracting APK"

    Set-Location $WorkDir

    if (-not (Test-Path "app.apk")) {
        Write-ErrorMsg "APK file not found"
        throw "APK file missing"
    }

    # Verify it's a valid APK/ZIP file
    try {
        $testExtract = New-Object System.IO.Compression.ZipArchive([System.IO.File]::OpenRead((Resolve-Path "app.apk").Path))
        $testExtract.Dispose()
        Write-VerboseLog "APK file is valid ZIP archive"
    }
    catch {
        Write-ErrorMsg "app.apk is not a valid ZIP/APK file: $_"
        throw "Invalid APK file"
    }

    Write-Info "Decompiling APK with apktool..."

    # Run apktool
    $apktoolDir = Join-Path $env:LOCALAPPDATA "apktool"
    $apktoolBat = Join-Path $apktoolDir "apktool.bat"

    try {
        $apktoolOutput = & cmd /c "`"$apktoolBat`" d app.apk -o extracted -f" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "apktool failed with exit code $LASTEXITCODE"
            Write-VerboseLog "apktool output: $apktoolOutput"
            throw "apktool decompilation failed"
        }
    }
    catch {
        Write-ErrorMsg "Failed to decompile APK: $_"
        throw
    }

    # Verify extraction succeeded
    if (-not (Test-Path "extracted\AndroidManifest.xml")) {
        Write-ErrorMsg "APK decompilation incomplete - AndroidManifest.xml not found"
        Write-Info "This may be a corrupted APK or apktool compatibility issue"
        throw "Decompilation verification failed"
    }

    Write-Success "APK decompiled"

    # Also extract as zip for direct file access
    Write-Info "Extracting APK contents..."
    $rawDir = "extracted-raw"
    New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

    try {
        Expand-Archive -Path "app.apk" -DestinationPath $rawDir -Force
    }
    catch {
        Write-Warning "Could not extract APK as ZIP (may not be fatal)"
    }

    Write-Success "APK extracted"

    $script:APKExtractedPath = Join-Path $WorkDir "extracted"
    $script:APKRawPath = Join-Path $WorkDir "extracted-raw"
}

################################################################################
# App Information
################################################################################

function Get-AppInformation {
    Write-Header "App Information"

    Set-Location $script:APKExtractedPath

    $manifest = "AndroidManifest.xml"

    if (-not (Test-Path $manifest)) {
        Write-Warning "AndroidManifest.xml not found"
        return
    }

    $content = Get-Content $manifest -Raw

    # Extract app info from manifest
    if ($content -match 'package="([^"]*)"') {
        $script:AppInfo.Package = $matches[1]
    }

    if ($content -match 'versionName="([^"]*)"') {
        $script:AppInfo.VersionName = $matches[1]
    }

    if ($content -match 'versionCode="([^"]*)"') {
        $script:AppInfo.VersionCode = $matches[1]
    }

    # Try to get app name from strings
    $stringsFile = "res\values\strings.xml"
    if (Test-Path $stringsFile) {
        $stringsContent = Get-Content $stringsFile -Raw
        if ($stringsContent -match 'name="app_name"[^>]*>([^<]*)') {
            $script:AppInfo.Name = $matches[1]
        }
        else {
            $script:AppInfo.Name = $script:AppInfo.Package
        }
    }
    else {
        $script:AppInfo.Name = $script:AppInfo.Package
    }

    $apkSize = (Get-Item (Join-Path $WorkDir "app.apk")).Length / 1MB

    Write-Host "Package:      $($script:AppInfo.Package)"
    Write-Host "Name:         $($script:AppInfo.Name)"
    Write-Host "Version:      $($script:AppInfo.VersionName)"
    Write-Host "Version Code: $($script:AppInfo.VersionCode)"
    Write-Host "APK Size:     $([math]::Round($apkSize, 2)) MB"
}

################################################################################
# Competitor Detection
################################################################################

function Get-Competitors {
    if (-not (Test-Path $CompetitorsFile)) {
        Write-VerboseLog "Competitors file not found: $CompetitorsFile"
        return
    }

    Write-VerboseLog "Loading competitors from: $CompetitorsFile"

    $lines = Get-Content $CompetitorsFile

    foreach ($line in $lines) {
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith('#')) {
            continue
        }

        # Extract company/product name, removing bracketed text
        $competitor = ($line -replace '\[.*?\]', '').Trim()

        if (-not [string]::IsNullOrEmpty($competitor)) {
            $script:CompetitorNames += $competitor
        }
    }

    Write-VerboseLog "Loaded $($script:CompetitorNames.Count) competitors"
}

function Test-Competitors {
    if ($script:CompetitorNames.Count -eq 0) {
        return
    }

    Write-VerboseLog "Checking for competitor products..."

    foreach ($details in $script:AllLibraryDetails) {
        $parts = $details -split '\|'
        if ($parts.Count -ge 6) {
            $libName = $parts[0]
            $libPath = $parts[1]
            $libSize = $parts[2]

            foreach ($competitor in $script:CompetitorNames) {
                # Create pattern for matching
                $pattern = $competitor -replace ' ', '.*'

                if ($libName -match $pattern -or $libPath -match $pattern) {
                    $matchInfo = "$libName|$libPath|$libSize|$competitor"
                    $script:CompetitorProducts += $matchInfo
                    Write-VerboseLog "Found competitor match: $competitor in $libName"
                    break
                }
            }
        }
    }

    if ($script:CompetitorProducts.Count -gt 0) {
        Write-Warning "Detected $($script:CompetitorProducts.Count) competitor product(s)"
    }
}

################################################################################
# Library & SDK Detection
################################################################################

function Get-AllLibraries {
    Write-Header "Library & SDK Analysis"

    # Load competitors list and library info
    Get-Competitors

    # Extract all metadata
    Get-LibraryVersions
    Get-PlayServicesVersions
    Get-AndroidXLibraries
    Get-Permissions
    Get-BuildInfo
    Get-KotlinInfo
    Get-AssetsSummary

    # List all native libraries
    $libDir = Join-Path $script:APKRawPath "lib"

    if (Test-Path $libDir) {
        Write-Host "📦 Native Libraries:`n" -ForegroundColor White

        $libFiles = Get-ChildItem -Path $libDir -Filter "*.so" -Recurse -ErrorAction SilentlyContinue

        if ($libFiles.Count -eq 0) {
            Write-Host "   (No native libraries found)`n"
        }
        else {
            $libCount = 0
            foreach ($libFile in $libFiles) {
                $libCount++
                $libName = $libFile.Name
                $libArch = $libFile.Directory.Name
                $libSize = "{0:N2} KB" -f ($libFile.Length / 1KB)

                $script:AllLibraries += $libName

                # Get library metadata
                $description = Get-LibraryDescription -LibName $libName
                $vendor = Get-LibraryVendor -LibName $libName
                $version = Get-LibraryVersion -SearchName $libName

                Write-Host "$libCount. $libName" -ForegroundColor Cyan

                if ($description) {
                    Write-Host "   Description:  $description"
                }

                if ($vendor) {
                    Write-Host "   Vendor:       $vendor"
                }

                if ($version) {
                    Write-Host "   Version:      $version"
                }

                Write-Host "   Architecture: $libArch"
                Write-Host "   Size:         $libSize"

                $libDetails = "$libName|$($libFile.FullName)|$libSize|$description|$vendor|$version"
                $script:AllLibraryDetails += $libDetails
                Write-Host ""
            }

            Write-Success "Found $libCount native library/libraries"
        }
    }
    else {
        Write-Host "📦 Native Libraries:`n" -ForegroundColor White
        Write-Host "   (No lib directory found)`n"
    }

    # Check for competitors
    Test-Competitors

    # Display competitor products if found
    if ($script:CompetitorProducts.Count -gt 0) {
        Write-Host "`n⚠️  POTENTIAL COMPETITOR PRODUCTS DETECTED:`n" -ForegroundColor Red

        $idx = 1
        foreach ($matchInfo in $script:CompetitorProducts) {
            $parts = $matchInfo -split '\|'
            if ($parts.Count -ge 4) {
                $libName = $parts[0]
                $libPath = $parts[1]
                $libSize = $parts[2]
                $competitor = $parts[3]

                Write-Host "$idx. $libName" -ForegroundColor Red
                Write-Host "   Competitor:  $competitor"
                Write-Host "   Path:        $libPath"
                Write-Host "   Size:        $libSize"
                Write-Host ""
                $idx++
            }
        }
    }

    # List major Java packages
    Write-Host "`n📚 Java Packages (Top Level):`n" -ForegroundColor White

    $smaliDir = Join-Path $script:APKExtractedPath "smali"
    if (Test-Path $smaliDir) {
        $packages = Get-ChildItem -Path $smaliDir -Directory -ErrorAction SilentlyContinue | Select-Object -First 20

        if ($packages.Count -gt 0) {
            foreach ($pkg in $packages) {
                $pkgName = $pkg.FullName.Replace("$smaliDir\", "").Replace('\', '.')
                $fileCount = (Get-ChildItem -Path $pkg.FullName -Filter "*.smali" -Recurse -ErrorAction SilentlyContinue).Count
                Write-Host "   • $pkgName ($fileCount classes)"
            }
            Write-Host ""
        }
        else {
            Write-Host "   (No packages found)`n"
        }
    }
    else {
        Write-Host "   (No smali directory found)`n"
    }

    # Summary
    if ($script:CompetitorProducts.Count -gt 0) {
        Write-Host "⚠️  WARNING: Found $($script:CompetitorProducts.Count) competitor product(s)" -ForegroundColor Red
    }
    Write-Host "✅ Analysis complete" -ForegroundColor Green
}

function Find-SDKs {
    if ($ListAll) {
        Get-AllLibraries
        return
    }

    Write-Header "SDK Detection"

    # Extract metadata even for SDK-specific search (for comprehensive report)
    Get-Competitors
    Get-LibraryVersions
    Get-PlayServicesVersions
    Get-AndroidXLibraries
    Get-Permissions
    Get-BuildInfo
    Get-KotlinInfo
    Get-AssetsSummary

    # Collect all libraries for the report
    $libDir = Join-Path $script:APKRawPath "lib"
    if (Test-Path $libDir) {
        $allLibFiles = Get-ChildItem -Path $libDir -Filter "*.so" -Recurse -ErrorAction SilentlyContinue
        foreach ($libFile in $allLibFiles) {
            $libName = $libFile.Name
            $script:AllLibraries += $libName

            $libSize = "{0:N2} KB" -f ($libFile.Length / 1KB)
            $description = Get-LibraryDescription -LibName $libName
            $vendor = Get-LibraryVendor -LibName $libName
            $version = Get-LibraryVersion -SearchName $libName

            $libDetails = "$libName|$($libFile.FullName)|$libSize|$description|$vendor|$version"
            $script:AllLibraryDetails += $libDetails
        }
    }

    foreach ($sdkName in $SDKNames) {
        Write-Host "`nSearching for keyword: '$sdkName'" -ForegroundColor White

        $found = $false
        $details = ""
        $foundLocations = @()

        # Method 1: Search in AndroidManifest.xml (PRIORITY - most common place)
        Write-VerboseLog "Searching AndroidManifest.xml for keyword '$sdkName'..."
        $manifest = Join-Path $script:APKExtractedPath "AndroidManifest.xml"
        if (Test-Path $manifest) {
            $manifestMatches = Select-String -Path $manifest -Pattern $sdkName -CaseSensitive:$false -ErrorAction SilentlyContinue
            if ($manifestMatches) {
                $found = $true
                Write-Found "Keyword found in AndroidManifest.xml ($($manifestMatches.Count) occurrence(s))"
                $foundLocations += "AndroidManifest.xml ($($manifestMatches.Count) references)"
                $details += "`n  - AndroidManifest.xml: $($manifestMatches.Count) occurrence(s)"

                if ($VerboseOutput) {
                    $manifestMatches | Select-Object -First 3 | ForEach-Object {
                        Write-Host "    Line $($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Gray
                    }
                }
            }
        }

        # Method 2: Search in strings.xml and other resource XML files
        Write-VerboseLog "Searching resource XML files for keyword '$sdkName'..."
        $resDir = Join-Path $script:APKExtractedPath "res"
        if (Test-Path $resDir) {
            $xmlFiles = Get-ChildItem -Path $resDir -Filter "*.xml" -Recurse -ErrorAction SilentlyContinue
            $xmlMatches = 0
            $xmlFileList = @()

            foreach ($xmlFile in $xmlFiles) {
                $matches = Select-String -Path $xmlFile.FullName -Pattern $sdkName -CaseSensitive:$false -ErrorAction SilentlyContinue
                if ($matches) {
                    $xmlMatches += $matches.Count
                    $xmlFileList += $xmlFile.Name
                }
            }

            if ($xmlMatches -gt 0) {
                $found = $true
                Write-Found "Keyword found in resource XML files ($xmlMatches occurrence(s) in $($xmlFileList.Count) file(s))"
                $foundLocations += "Resource XML files ($xmlMatches references in $($xmlFileList.Count) files)"
                $details += "`n  - Resource XMLs: $xmlMatches occurrence(s)"

                if ($VerboseOutput) {
                    $xmlFileList | Select-Object -First 5 | ForEach-Object {
                        Write-Host "    Found in: $_" -ForegroundColor Gray
                    }
                }
            }
        }

        # Method 3: Search in smali code (decompiled Java) - OPTIMIZED
        Write-VerboseLog "Searching Java/smali code for keyword '$sdkName'..."
        $smaliDir = Join-Path $script:APKExtractedPath "smali"
        if (Test-Path $smaliDir) {
            # First check for files with the keyword in filename (fast)
            $smaliFiles = Get-ChildItem -Path $smaliDir -Filter "*$sdkName*" -Recurse -ErrorAction SilentlyContinue

            # Only do content search if keyword already found elsewhere or if no results yet
            # This makes it much faster by skipping deep content search when not needed
            $smaliContentMatches = 0

            # Quick check: search only class files that likely contain the SDK
            # Look for files with names containing common SDK patterns
            $likelyFiles = Get-ChildItem -Path $smaliDir -Filter "*.smali" -Recurse -ErrorAction SilentlyContinue |
                           Where-Object { $_.FullName -match "($sdkName|vendor|library|sdk)" } |
                           Select-Object -First 50  # Limit to 50 files max for performance

            if ($likelyFiles) {
                Write-VerboseLog "  Searching $($likelyFiles.Count) likely class files..."
                $contentMatches = $likelyFiles | Select-String -Pattern $sdkName -CaseSensitive:$false -ErrorAction SilentlyContinue
                $smaliContentMatches = $contentMatches.Count

                if ($VerboseOutput -and $contentMatches) {
                    $contentMatches | Select-Object -First 3 | ForEach-Object {
                        Write-Host "    Match in: $(Split-Path -Leaf $_.Path):$($_.LineNumber)" -ForegroundColor Gray
                    }
                }
            }

            $totalSmaliRefs = ($smaliFiles.Count + $smaliContentMatches)
            if ($totalSmaliRefs -gt 0) {
                $found = $true
                Write-Found "Keyword found in Java code ($totalSmaliRefs reference(s))"
                $foundLocations += "Java/smali code ($totalSmaliRefs references)"
                $details += "`n  - Java code: $totalSmaliRefs reference(s)"

                if ($VerboseOutput -and $smaliFiles.Count -gt 0) {
                    $smaliFiles | Select-Object -First 3 | ForEach-Object {
                        Write-Host "    Class file: $($_.Name)" -ForegroundColor Gray
                    }
                }
            }
        }

        # Method 4: Search in native libraries (.so files)
        Write-VerboseLog "Checking native library names for keyword '$sdkName'..."
        $libDir = Join-Path $script:APKRawPath "lib"
        if (Test-Path $libDir) {
            $nativeLibs = Get-ChildItem -Path $libDir -Filter "*$sdkName*" -Recurse -ErrorAction SilentlyContinue

            if ($nativeLibs.Count -gt 0) {
                $found = $true
                Write-Found "Keyword found in native library names ($($nativeLibs.Count) file(s))"
                $foundLocations += "Native libraries ($($nativeLibs.Count) files)"
                $details += "`n  - Native libraries: $($nativeLibs.Count) file(s)"

                if ($VerboseOutput) {
                    $nativeLibs | ForEach-Object {
                        $libSize = "{0:N2} KB" -f ($_.Length / 1KB)
                        Write-Host "    📦 $($_.Name) ($libSize)" -ForegroundColor Gray
                    }
                }
            }
        }

        # Method 5: Search in assets folder
        Write-VerboseLog "Searching assets for keyword '$sdkName'..."
        $assetsDir = Join-Path $script:APKRawPath "assets"
        if (Test-Path $assetsDir) {
            $assetFiles = Get-ChildItem -Path $assetsDir -Filter "*$sdkName*" -Recurse -ErrorAction SilentlyContinue

            if ($assetFiles.Count -gt 0) {
                $found = $true
                Write-Found "Keyword found in assets ($($assetFiles.Count) file(s))"
                $foundLocations += "Assets ($($assetFiles.Count) files)"
                $details += "`n  - Assets: $($assetFiles.Count) file(s)"
            }
        }

        # Method 6: Search in META-INF (library metadata)
        Write-VerboseLog "Searching META-INF for keyword '$sdkName'..."
        $metaInfDir = Join-Path $script:APKRawPath "META-INF"
        if (Test-Path $metaInfDir) {
            $metaFiles = Get-ChildItem -Path $metaInfDir -Filter "*$sdkName*" -Recurse -ErrorAction SilentlyContinue

            if ($metaFiles.Count -gt 0) {
                $found = $true
                Write-Found "Keyword found in META-INF ($($metaFiles.Count) file(s))"
                $foundLocations += "META-INF ($($metaFiles.Count) files)"
                $details += "`n  - META-INF: $($metaFiles.Count) file(s)"
            }
        }

        # Summary with locations
        if ($found) {
            $script:DetectedSDKs += $sdkName
            Write-Host "`n✅ RESULT: Keyword '$sdkName' WAS FOUND" -ForegroundColor Green
            Write-Host "   Locations: $($foundLocations -join ', ')" -ForegroundColor Cyan

            # Store detailed locations for report
            if (-not $script:SDKDetails) {
                $script:SDKDetails = @{}
            }
            $script:SDKDetails[$sdkName] = $details + "`n`n  Found in: $($foundLocations -join ', ')"
        }
        else {
            Write-Host "`n❌ RESULT: $sdkName SDK NOT DETECTED" -ForegroundColor Red
        }

        # Store details (using hashtable instead of dynamic variables)
        if (-not $script:SDKDetails) {
            $script:SDKDetails = @{}
        }
        $script:SDKDetails[$sdkName] = $details
    }
}

################################################################################
# Report Generation
################################################################################

function New-Report {
    Write-Header "Generating Report"

    # Create filename
    $reportFilename = $OutputReport

    if ($OutputReport -eq "sdk-detection-report.txt") {
        $identifier = $script:AppInfo.Package
        if ([string]::IsNullOrEmpty($identifier) -or $identifier -eq "N/A") {
            $identifier = $script:AppInfo.Name
        }

        $identifier = $identifier -replace '[^a-z0-9-]', '-' -replace '-+', '-'
        $identifier = $identifier.ToLower().Trim('-')

        if ($ListAll) {
            $reportFilename = "library-analysis-android-$identifier-$Timestamp.txt"
        }
        else {
            $reportFilename = "sdk-detection-android-$identifier-$Timestamp.txt"
        }
    }

    $reportFile = Join-Path $OriginalDir $reportFilename
    $script:FinalReportPath = $reportFile

    # Generate report based on mode
    if ($ListAll) {
        New-AllLibrariesReport -ReportFile $reportFile
    }
    else {
        New-SDKDetectionReport -ReportFile $reportFile
    }

    Write-Success "Report saved to: $reportFile"

    Write-Host ""
    Get-Content $reportFile
}

function New-AllLibrariesReport {
    param([string]$ReportFile)

    $apkSize = (Get-Item (Join-Path $WorkDir "app.apk")).Length / 1MB

    $report = @"
================================================================================
                   ANDROID APP LIBRARY & SDK ANALYSIS REPORT
================================================================================

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Analysis Tool: Android SDK Detection Script v1.0 (Windows Edition)

================================================================================
📱 APP INFORMATION
================================================================================

Package Name:   $($script:AppInfo.Package)
App Name:       $($script:AppInfo.Name)
Version:        $($script:AppInfo.VersionName) (Code: $($script:AppInfo.VersionCode))
APK Size:       $([math]::Round($apkSize, 2)) MB
Analysis Date:  $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

================================================================================
📊 EXECUTIVE SUMMARY
================================================================================

Total Native Libraries:         $($script:AllLibraries.Count)
Total Google Play Services:     $($script:PlayServicesVersions.Count)
Total AndroidX Libraries:       $($script:AndroidXLibraries.Count)
Total Permissions Requested:    $($script:AppPermissions.Count)
Competitor Products Detected:   $($script:CompetitorProducts.Count)

"@

    # Add ALL SDKs DETECTED section (comprehensive list)
    $allDetectedSDKs = @()

    # Collect from Play Services
    foreach ($entry in $script:PlayServicesVersions) {
        $parts = $entry -split '\|'
        if ($parts.Count -eq 2) {
            $allDetectedSDKs += "  • $($parts[0]) v$($parts[1]) (Google Play Services)"
        }
    }

    # Collect from AndroidX
    foreach ($entry in $script:AndroidXLibraries) {
        $parts = $entry -split '\|'
        if ($parts.Count -eq 2) {
            $allDetectedSDKs += "  • $($parts[0]) v$($parts[1]) (AndroidX)"
        }
    }

    # Collect from Kotlin
    foreach ($entry in $script:KotlinInfo) {
        $parts = $entry -split '\|'
        if ($parts.Count -eq 2 -and $parts[0] -ne "metadata_found") {
            $allDetectedSDKs += "  • $($parts[0]) v$($parts[1]) (Kotlin)"
        }
    }

    # Collect from Native Libraries with known vendors
    foreach ($details in $script:AllLibraryDetails) {
        $parts = $details -split '\|'
        if ($parts.Count -ge 6) {
            $libName = $parts[0]
            $vendor = $parts[4]
            $version = $parts[5]

            if ($vendor -and $vendor -ne "") {
                $versionStr = if ($version) { "v$version" } else { "(version unknown)" }
                $allDetectedSDKs += "  • $libName $versionStr ($vendor)"
            }
        }
    }

    if ($allDetectedSDKs.Count -gt 0) {
        $report += @"
================================================================================
🔍 ALL DETECTED SDKs & LIBRARIES (COMPREHENSIVE LIST)
================================================================================

This app contains $($allDetectedSDKs.Count) identified SDKs and libraries:

"@
        $sorted = $allDetectedSDKs | Sort-Object
        foreach ($sdk in $sorted) {
            $report += "$sdk`n"
        }
        $report += "`n"
    }

    # Add competitor detection section
    if ($script:CompetitorProducts.Count -gt 0) {
        $report += @"

================================================================================
⚠️  POTENTIAL COMPETITOR PRODUCTS DETECTED
================================================================================

WARNING: This app contains $($script:CompetitorProducts.Count) potential competitor product(s):

"@
        $idx = 1
        foreach ($matchInfo in $script:CompetitorProducts) {
            $parts = $matchInfo -split '\|'
            if ($parts.Count -ge 4) {
                $report += @"
$idx. $($parts[0])
   Competitor:  $($parts[3])
   Path:        $($parts[1])
   Size:        $($parts[2])

"@
                $idx++
            }
        }
    }

    $report += @"

--------------------------------------------------------------------------------
NATIVE LIBRARIES
--------------------------------------------------------------------------------

"@

    if ($script:AllLibraries.Count -eq 0) {
        $report += "No native libraries found in the APK.`n`n"
    }
    else {
        $report += "Found $($script:AllLibraries.Count) native library/libraries:`n`n"

        $idx = 1
        foreach ($details in $script:AllLibraryDetails) {
            $parts = $details -split '\|'
            if ($parts.Count -ge 6) {
                $libName = $parts[0]
                $libPath = $parts[1]
                $libSize = $parts[2]
                $description = $parts[3]
                $vendor = $parts[4]
                $version = $parts[5]

                $libFile = Get-Item $libPath -ErrorAction SilentlyContinue
                $libArch = if ($libFile) { $libFile.Directory.Name } else { "unknown" }

                $report += "$idx. $libName`n"
                $report += "   Architecture: $libArch`n"
                $report += "   Size:         $libSize`n"

                if ($description) {
                    $report += "   Description:  $description`n"
                }
                if ($vendor) {
                    $report += "   Vendor:       $vendor`n"
                }
                if ($version) {
                    $report += "   Version:      $version`n"
                }

                $report += "`n"
                $idx++
            }
        }
    }

    # Add remaining sections...
    $report += @"
--------------------------------------------------------------------------------
JAVA PACKAGES
--------------------------------------------------------------------------------

"@

    $smaliDir = Join-Path $script:APKExtractedPath "smali"
    if (Test-Path $smaliDir) {
        $packages = Get-ChildItem -Path $smaliDir -Directory -ErrorAction SilentlyContinue | Select-Object -First 20
        if ($packages.Count -gt 0) {
            foreach ($pkg in $packages) {
                $pkgName = $pkg.FullName.Replace("$smaliDir\", "").Replace('\', '.')
                $fileCount = (Get-ChildItem -Path $pkg.FullName -Filter "*.smali" -Recurse -ErrorAction SilentlyContinue).Count
                $report += "  • $pkgName ($fileCount classes)`n"
            }
        }
        else {
            $report += "  (No packages found)`n"
        }
    }
    else {
        $report += "  (No smali directory found)`n"
    }

    $report += "`n"

    # Add Play Services section
    if ($script:PlayServicesVersions.Count -gt 0) {
        $report += @"
--------------------------------------------------------------------------------
GOOGLE PLAY SERVICES & FIREBASE
--------------------------------------------------------------------------------

Found $($script:PlayServicesVersions.Count) Google Play Services/Firebase libraries:

"@
        $sorted = $script:PlayServicesVersions | Sort-Object
        foreach ($entry in $sorted) {
            $parts = $entry -split '\|'
            if ($parts.Count -eq 2) {
                $report += "  • $($parts[0]) ($($parts[1]))`n"
            }
        }
        $report += "`n"
    }

    # Add AndroidX section
    if ($script:AndroidXLibraries.Count -gt 0) {
        $report += @"
--------------------------------------------------------------------------------
ANDROIDX LIBRARIES
--------------------------------------------------------------------------------

Found $($script:AndroidXLibraries.Count) AndroidX/Jetpack libraries:

"@
        $sorted = $script:AndroidXLibraries | Sort-Object
        foreach ($entry in $sorted) {
            $parts = $entry -split '\|'
            if ($parts.Count -eq 2) {
                $report += "  • $($parts[0]) ($($parts[1]))`n"
            }
        }
        $report += "`n"
    }

    # Add Kotlin section
    if ($script:KotlinInfo.Count -gt 0) {
        $report += @"
--------------------------------------------------------------------------------
KOTLIN LIBRARIES
--------------------------------------------------------------------------------

"@
        $sorted = $script:KotlinInfo | Where-Object { $_ -notlike "metadata_found|*" } | Sort-Object
        foreach ($entry in $sorted) {
            $parts = $entry -split '\|'
            if ($parts.Count -eq 2) {
                $report += "  • $($parts[0]) ($($parts[1]))`n"
            }
        }
        $report += "`n"
    }

    # Add permissions section
    if ($script:AppPermissions.Count -gt 0) {
        $report += @"
--------------------------------------------------------------------------------
PERMISSIONS
--------------------------------------------------------------------------------

This app requests $($script:AppPermissions.Count) permissions:

"@
        $sorted = $script:AppPermissions | Sort-Object
        foreach ($perm in $sorted) {
            $report += "  • $perm`n"
        }
        $report += "`n"
    }

    # Add features section
    if ($script:AppFeatures.Count -gt 0) {
        $report += @"
--------------------------------------------------------------------------------
HARDWARE FEATURES
--------------------------------------------------------------------------------

This app declares $($script:AppFeatures.Count) hardware features:

"@
        $sorted = $script:AppFeatures | Sort-Object
        foreach ($entry in $sorted) {
            $parts = $entry -split '\|'
            if ($parts.Count -eq 2) {
                $report += "  • $($parts[0]) [$($parts[1])]`n"
            }
        }
        $report += "`n"
    }

    # Add build info section
    if ($script:BuildInfo.Count -gt 0) {
        $report += @"
--------------------------------------------------------------------------------
BUILD INFORMATION
--------------------------------------------------------------------------------

"@
        $sorted = $script:BuildInfo | Sort-Object
        foreach ($entry in $sorted) {
            $parts = $entry -split '\|'
            if ($parts.Count -eq 2) {
                $report += "  $($parts[0]): $($parts[1])`n"
            }
        }
        $report += "`n"
    }

    # Add assets summary
    if ($script:AssetsInfo.Count -gt 0) {
        $assetCount = ""
        $assetSize = ""
        $resCount = ""
        $resSize = ""
        $languages = ""

        foreach ($entry in $script:AssetsInfo) {
            $parts = $entry -split '\|'
            if ($parts.Count -eq 2) {
                switch ($parts[0]) {
                    "asset_count" { $assetCount = $parts[1] }
                    "asset_size" { $assetSize = $parts[1] }
                    "res_count" { $resCount = $parts[1] }
                    "res_size" { $resSize = $parts[1] }
                    "languages" { $languages = $parts[1] }
                }
            }
        }

        $report += @"
--------------------------------------------------------------------------------
ASSETS & RESOURCES SUMMARY
--------------------------------------------------------------------------------

Assets:    $assetCount files ($assetSize)
Resources: $resCount files ($resSize)
"@
        if ($languages) {
            $report += "Languages: $languages`n"
        }
        $report += "`n"
    }

    $report += @"
--------------------------------------------------------------------------------
TECHNICAL DETAILS
--------------------------------------------------------------------------------

Analysis Directory: $WorkDir
APK Path:           $(Join-Path $WorkDir "app.apk")
Extracted Path:     $script:APKExtractedPath
Library Database:   $LibraryInfoFile
Competitors File:   $CompetitorsFile

--------------------------------------------------------------------------------
END OF REPORT
--------------------------------------------------------------------------------
"@

    Set-Content -Path $ReportFile -Value $report -Encoding UTF8
}

function New-SDKDetectionReport {
    param([string]$ReportFile)

    $apkSize = (Get-Item (Join-Path $WorkDir "app.apk")).Length / 1MB

    $report = @"
================================================================================
                   ANDROID APP SDK DETECTION REPORT
================================================================================

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Analysis Tool: Android SDK Detection Script v1.0 (Windows Edition)

================================================================================
📱 APP INFORMATION
================================================================================

Package Name:   $($script:AppInfo.Package)
App Name:       $($script:AppInfo.Name)
Version:        $($script:AppInfo.VersionName) (Code: $($script:AppInfo.VersionCode))
APK Size:       $([math]::Round($apkSize, 2)) MB
Analysis Date:  $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

================================================================================
🎯 TARGETED SDK SEARCH RESULTS
================================================================================

Searched for SDKs: $($SDKNames -join ', ')

"@

    # Show clear keyword search results at the top
    if ($script:DetectedSDKs.Count -eq 0) {
        $report += @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║  ❌ RESULT: NONE OF THE SEARCHED KEYWORDS WERE FOUND                     ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝

The following keywords were NOT found anywhere in the APK:

"@
        foreach ($sdk in $SDKNames) {
            $report += "  ❌ '$sdk' - No references found`n"
        }
    }
    else {
        $report += @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║  ✅ RESULT: KEYWORDS FOUND IN APK                                        ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝

"@

        foreach ($sdk in $script:DetectedSDKs) {
            $report += "✅ KEYWORD FOUND: '$sdk'`n"

            if ($script:SDKDetails -and $script:SDKDetails.ContainsKey($sdk)) {
                $details = $script:SDKDetails[$sdk]
                if ($details) {
                    $report += $details + "`n"
                }
            }
            $report += "`n"
        }

        # Show keywords NOT found (if any)
        $notFound = @()
        foreach ($sdk in $SDKNames) {
            if ($script:DetectedSDKs -notcontains $sdk) {
                $notFound += $sdk
            }
        }

        if ($notFound.Count -gt 0) {
            $report += "`nKeywords NOT found:`n"
            foreach ($sdk in $notFound) {
                $report += "  ❌ '$sdk' - No references found`n"
            }
        }
    }

    $report += "`n"

    # Add comprehensive library information section
    $report += @"

================================================================================
📊 ALL LIBRARIES & SDKs IN THIS APP
================================================================================

"@

    # Collect all detected SDKs (same logic as in New-AllLibrariesReport)
    $allDetectedSDKs = @()

    # Collect from Play Services
    foreach ($entry in $script:PlayServicesVersions) {
        $parts = $entry -split '\|'
        if ($parts.Count -eq 2) {
            $allDetectedSDKs += "  • $($parts[0]) v$($parts[1]) (Google Play Services)"
        }
    }

    # Collect from AndroidX
    foreach ($entry in $script:AndroidXLibraries) {
        $parts = $entry -split '\|'
        if ($parts.Count -eq 2) {
            $allDetectedSDKs += "  • $($parts[0]) v$($parts[1]) (AndroidX)"
        }
    }

    # Collect from Kotlin
    foreach ($entry in $script:KotlinInfo) {
        $parts = $entry -split '\|'
        if ($parts.Count -eq 2 -and $parts[0] -ne "metadata_found") {
            $allDetectedSDKs += "  • $($parts[0]) v$($parts[1]) (Kotlin)"
        }
    }

    # Collect from Native Libraries with known vendors
    foreach ($details in $script:AllLibraryDetails) {
        $parts = $details -split '\|'
        if ($parts.Count -ge 6) {
            $libName = $parts[0]
            $vendor = $parts[4]
            $version = $parts[5]

            if ($vendor -and $vendor -ne "") {
                $versionStr = if ($version) { "v$version" } else { "(version unknown)" }
                $allDetectedSDKs += "  • $libName $versionStr ($vendor)"
            }
        }
    }

    if ($allDetectedSDKs.Count -gt 0) {
        $report += "Total identified SDKs and libraries: $($allDetectedSDKs.Count)`n`n"
        $sorted = $allDetectedSDKs | Sort-Object
        foreach ($sdk in $sorted) {
            $report += "$sdk`n"
        }
    }
    else {
        $report += "No identified SDKs found (or library database not loaded).`n"
    }

    $report += @"

================================================================================
📦 NATIVE LIBRARIES SUMMARY
================================================================================

"@

    if ($script:AllLibraries.Count -gt 0) {
        $report += "Found $($script:AllLibraries.Count) native library/libraries:`n`n"
        foreach ($lib in ($script:AllLibraries | Sort-Object)) {
            $report += "  • $lib`n"
        }
    }
    else {
        $report += "No native libraries found.`n"
    }

    $report += @"

================================================================================
🔍 DETECTION METHODS USED
================================================================================

1. Native Library Inspection
   - Searched lib/ directories for .so files
   - Checked all CPU architectures (arm, arm64, x86, etc.)

2. Java Class Analysis
   - Searched decompiled smali code for SDK classes
   - Checked package names and class hierarchies

3. Asset and Resource Search
   - Searched assets/ directory for SDK files
   - Checked res/ directory for SDK resources

4. Manifest Analysis
   - Checked AndroidManifest.xml for SDK references
   - Verified permissions and SDK declarations

--------------------------------------------------------------------------------
CONCLUSION
--------------------------------------------------------------------------------

"@

    if ($script:DetectedSDKs.Count -eq 0) {
        $report += @"
The analyzed Android app does NOT contain any of the specified SDKs.

If you expected to find these SDKs, consider:
- The SDK may be obfuscated or renamed (ProGuard/R8)
- The SDK may have been removed in this version
- The search terms may need adjustment
- Try analyzing with ProGuard mapping file if available

"@
    }
    else {
        $report += @"
The analyzed Android app CONTAINS the following SDK(s): $($script:DetectedSDKs -join ', ')

This indicates active integration of the SDK in the current version.

For license compliance:
- Verify if this usage is authorized
- Check if the SDK version matches license terms
- Document the findings appropriately
- Contact the app developer if unauthorized use is suspected

"@
    }

    $report += @"
--------------------------------------------------------------------------------
TECHNICAL DETAILS
--------------------------------------------------------------------------------

Analysis Directory: $WorkDir
Package Name:       $($script:AppInfo.Package)
APK Path:           $(Join-Path $WorkDir "app.apk")

--------------------------------------------------------------------------------
END OF REPORT
--------------------------------------------------------------------------------
"@

    Set-Content -Path $ReportFile -Value $report -Encoding UTF8
}

################################################################################
# Cleanup
################################################################################

function Remove-TemporaryFiles {
    Set-Location $OriginalDir

    if (-not $NoCleanup) {
        Write-Header "Cleanup"
        Write-Info "Removing temporary files from: $WorkDir"
        Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
        Write-Success "Cleanup complete"
        Write-Info "Report saved to: $script:FinalReportPath"
    }
    else {
        Write-Info "Analysis files kept at: $WorkDir"
        Write-Info "Report saved to: $script:FinalReportPath"
    }
}

################################################################################
# Main Script
################################################################################

function Main {
    # Print banner
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      Android App SDK Detection Script v1.0                     ║" -ForegroundColor Cyan
    Write-Host "║      License Compliance & Security Analysis                    ║" -ForegroundColor Cyan
    Write-Host "║      Windows 11 PowerShell Edition                             ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Validate inputs
        Test-Inputs

        # Check requirements
        Test-Requirements

        # Get APK
        Get-APKFile

        # Extract APK
        Expand-APK

        # Get app info
        Get-AppInformation

        # Detect SDKs
        Find-SDKs

        # Generate report
        New-Report

        # Cleanup
        Remove-TemporaryFiles

        # Final summary
        Write-Header "Analysis Complete"

        if ($ListAll) {
            if ($script:AllLibraries.Count -eq 0) {
                Write-Host "No native libraries found" -ForegroundColor Yellow
            }
            else {
                Write-Host "Found $($script:AllLibraries.Count) native library/libraries" -ForegroundColor Green
            }
            if ($script:CompetitorProducts.Count -gt 0) {
                Write-Host "⚠️  WARNING: Found $($script:CompetitorProducts.Count) competitor product(s)" -ForegroundColor Red
            }
        }
        else {
            if ($script:DetectedSDKs.Count -eq 0) {
                Write-Host "No SDKs detected" -ForegroundColor Red
            }
            else {
                Write-Host "Detected SDKs: $($script:DetectedSDKs -join ', ')" -ForegroundColor Green
            }
        }

        Write-Host ""
        Write-Host "📄 Full report: $script:FinalReportPath" -ForegroundColor Blue

        exit 0
    }
    catch {
        Write-Host ""
        Write-ErrorMsg $_.Exception.Message
        Write-Host ""
        Write-Host "Stack trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Yellow

        # Cleanup on error
        Set-Location $OriginalDir
        if (-not $NoCleanup -and (Test-Path $WorkDir)) {
            Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
        }

        exit 1
    }
}

# Entry point
Main
