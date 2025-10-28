<#
.SYNOPSIS
    Android SDK Detection Tool - Windows GUI Version

.DESCRIPTION
    Graphical interface for analyzing Android APK/XAPK files to detect SDKs and libraries.
    This GUI wrapper provides an easy-to-use interface for the detect-sdk-android.ps1 script.

.NOTES
    Version: 1.0
    Requires: PowerShell 5.1 or higher, .NET Framework
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CoreScript = Join-Path $ScriptDir "detect-sdk-android.ps1"

# Verify core script exists
if (-not (Test-Path $CoreScript)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Error: detect-sdk-android.ps1 not found in the same directory!`n`nExpected location: $CoreScript",
        "Missing Core Script",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

################################################################################
# Create Main Form
################################################################################

$form = New-Object System.Windows.Forms.Form
$form.Text = "Android SDK Analyzer - Windows Edition"
$form.Size = New-Object System.Drawing.Size(700, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.BackColor = [System.Drawing.Color]::White

################################################################################
# Title Label
################################################################################

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titleLabel.Size = New-Object System.Drawing.Size(650, 35)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.Text = "🔍 Android SDK Detection & Analysis Tool"
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 102, 204)
$form.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Location = New-Object System.Drawing.Point(20, 50)
$subtitleLabel.Size = New-Object System.Drawing.Size(650, 20)
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitleLabel.Text = "Analyze APK/XAPK files to detect SDKs, libraries, and competitor products"
$subtitleLabel.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($subtitleLabel)

################################################################################
# File Selection Group
################################################################################

$fileGroupBox = New-Object System.Windows.Forms.GroupBox
$fileGroupBox.Location = New-Object System.Drawing.Point(20, 85)
$fileGroupBox.Size = New-Object System.Drawing.Size(650, 80)
$fileGroupBox.Text = "📁 Select APK/XAPK File"
$fileGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($fileGroupBox)

$filePathLabel = New-Object System.Windows.Forms.Label
$filePathLabel.Location = New-Object System.Drawing.Point(15, 25)
$filePathLabel.Size = New-Object System.Drawing.Size(80, 20)
$filePathLabel.Text = "File Path:"
$filePathLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$fileGroupBox.Controls.Add($filePathLabel)

$filePathTextBox = New-Object System.Windows.Forms.TextBox
$filePathTextBox.Location = New-Object System.Drawing.Point(100, 23)
$filePathTextBox.Size = New-Object System.Drawing.Size(420, 25)
$filePathTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$filePathTextBox.ReadOnly = $true
$fileGroupBox.Controls.Add($filePathTextBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(530, 21)
$browseButton.Size = New-Object System.Drawing.Size(100, 28)
$browseButton.Text = "Browse..."
$browseButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$browseButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$browseButton.ForeColor = [System.Drawing.Color]::White
$browseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$fileGroupBox.Controls.Add($browseButton)

# Browse button click event
$browseButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Android Files (*.apk;*.xapk)|*.apk;*.xapk|APK Files (*.apk)|*.apk|XAPK Files (*.xapk)|*.xapk|All Files (*.*)|*.*"
    $openFileDialog.Title = "Select APK or XAPK File"
    $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("UserProfile") + "\Downloads"

    if ($openFileDialog.ShowDialog() -eq "OK") {
        $filePathTextBox.Text = $openFileDialog.FileName
    }
})

################################################################################
# Analysis Options Group
################################################################################

$optionsGroupBox = New-Object System.Windows.Forms.GroupBox
$optionsGroupBox.Location = New-Object System.Drawing.Point(20, 175)
$optionsGroupBox.Size = New-Object System.Drawing.Size(650, 140)
$optionsGroupBox.Text = "⚙️ Analysis Options"
$optionsGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($optionsGroupBox)

# Analysis Mode
$modeLabel = New-Object System.Windows.Forms.Label
$modeLabel.Location = New-Object System.Drawing.Point(15, 28)
$modeLabel.Size = New-Object System.Drawing.Size(150, 20)
$modeLabel.Text = "Analysis Mode:"
$modeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$optionsGroupBox.Controls.Add($modeLabel)

$listAllRadio = New-Object System.Windows.Forms.RadioButton
$listAllRadio.Location = New-Object System.Drawing.Point(170, 26)
$listAllRadio.Size = New-Object System.Drawing.Size(200, 22)
$listAllRadio.Text = "List All Libraries (Full Report)"
$listAllRadio.Checked = $true
$listAllRadio.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$optionsGroupBox.Controls.Add($listAllRadio)

$searchSDKRadio = New-Object System.Windows.Forms.RadioButton
$searchSDKRadio.Location = New-Object System.Drawing.Point(390, 26)
$searchSDKRadio.Size = New-Object System.Drawing.Size(180, 22)
$searchSDKRadio.Text = "Search Specific SDKs"
$searchSDKRadio.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$optionsGroupBox.Controls.Add($searchSDKRadio)

# SDK Names (only enabled when search mode is selected)
$sdkLabel = New-Object System.Windows.Forms.Label
$sdkLabel.Location = New-Object System.Drawing.Point(15, 58)
$sdkLabel.Size = New-Object System.Drawing.Size(150, 20)
$sdkLabel.Text = "SDK Names:"
$sdkLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$sdkLabel.Enabled = $false
$optionsGroupBox.Controls.Add($sdkLabel)

$sdkTextBox = New-Object System.Windows.Forms.TextBox
$sdkTextBox.Location = New-Object System.Drawing.Point(170, 56)
$sdkTextBox.Size = New-Object System.Drawing.Size(460, 25)
$sdkTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$sdkTextBox.Text = "pspdfkit, nutrient"
$sdkTextBox.Enabled = $false
$optionsGroupBox.Controls.Add($sdkTextBox)

$sdkHintLabel = New-Object System.Windows.Forms.Label
$sdkHintLabel.Location = New-Object System.Drawing.Point(170, 82)
$sdkHintLabel.Size = New-Object System.Drawing.Size(460, 15)
$sdkHintLabel.Text = "Separate multiple SDK names with commas"
$sdkHintLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$sdkHintLabel.ForeColor = [System.Drawing.Color]::Gray
$sdkHintLabel.Enabled = $false
$optionsGroupBox.Controls.Add($sdkHintLabel)

# Radio button event handlers
$listAllRadio.Add_CheckedChanged({
    $sdkLabel.Enabled = -not $listAllRadio.Checked
    $sdkTextBox.Enabled = -not $listAllRadio.Checked
    $sdkHintLabel.Enabled = -not $listAllRadio.Checked
})

$searchSDKRadio.Add_CheckedChanged({
    $sdkLabel.Enabled = $searchSDKRadio.Checked
    $sdkTextBox.Enabled = $searchSDKRadio.Checked
    $sdkHintLabel.Enabled = $searchSDKRadio.Checked
})

# Additional Options
$verboseCheckBox = New-Object System.Windows.Forms.CheckBox
$verboseCheckBox.Location = New-Object System.Drawing.Point(170, 105)
$verboseCheckBox.Size = New-Object System.Drawing.Size(200, 22)
$verboseCheckBox.Text = "Verbose Output"
$verboseCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$optionsGroupBox.Controls.Add($verboseCheckBox)

$noCleanupCheckBox = New-Object System.Windows.Forms.CheckBox
$noCleanupCheckBox.Location = New-Object System.Drawing.Point(390, 105)
$noCleanupCheckBox.Size = New-Object System.Drawing.Size(200, 22)
$noCleanupCheckBox.Text = "Keep Temporary Files"
$noCleanupCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$optionsGroupBox.Controls.Add($noCleanupCheckBox)

################################################################################
# Progress and Status
################################################################################

$statusGroupBox = New-Object System.Windows.Forms.GroupBox
$statusGroupBox.Location = New-Object System.Drawing.Point(20, 325)
$statusGroupBox.Size = New-Object System.Drawing.Size(650, 220)
$statusGroupBox.Text = "📊 Analysis Status"
$statusGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($statusGroupBox)

$statusTextBox = New-Object System.Windows.Forms.TextBox
$statusTextBox.Location = New-Object System.Drawing.Point(15, 25)
$statusTextBox.Size = New-Object System.Drawing.Size(620, 180)
$statusTextBox.Multiline = $true
$statusTextBox.ScrollBars = "Vertical"
$statusTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$statusTextBox.ReadOnly = $true
$statusTextBox.BackColor = [System.Drawing.Color]::Black
$statusTextBox.ForeColor = [System.Drawing.Color]::LimeGreen
$statusTextBox.Text = "Ready to analyze APK/XAPK files...`n`nPlease select a file and click 'Start Analysis'"
$statusGroupBox.Controls.Add($statusTextBox)

################################################################################
# Action Buttons
################################################################################

$analyzeButton = New-Object System.Windows.Forms.Button
$analyzeButton.Location = New-Object System.Drawing.Point(20, 560)
$analyzeButton.Size = New-Object System.Drawing.Size(200, 40)
$analyzeButton.Text = "▶️ Start Analysis"
$analyzeButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$analyzeButton.BackColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
$analyzeButton.ForeColor = [System.Drawing.Color]::White
$analyzeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($analyzeButton)

$openReportButton = New-Object System.Windows.Forms.Button
$openReportButton.Location = New-Object System.Drawing.Point(240, 560)
$openReportButton.Size = New-Object System.Drawing.Size(200, 40)
$openReportButton.Text = "📄 Open Last Report"
$openReportButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$openReportButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$openReportButton.ForeColor = [System.Drawing.Color]::White
$openReportButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$openReportButton.Enabled = $false
$form.Controls.Add($openReportButton)

$cleanupButton = New-Object System.Windows.Forms.Button
$cleanupButton.Location = New-Object System.Drawing.Point(20, 610)
$cleanupButton.Size = New-Object System.Drawing.Size(420, 40)
$cleanupButton.Text = "🧹 Clean Up Temporary Files"
$cleanupButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$cleanupButton.BackColor = [System.Drawing.Color]::FromArgb(255, 140, 0)
$cleanupButton.ForeColor = [System.Drawing.Color]::White
$cleanupButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($cleanupButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(470, 560)
$exitButton.Size = New-Object System.Drawing.Size(200, 90)
$exitButton.Text = "❌ Exit"
$exitButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$exitButton.BackColor = [System.Drawing.Color]::FromArgb(196, 43, 28)
$exitButton.ForeColor = [System.Drawing.Color]::White
$exitButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($exitButton)

# Global variable for last report path
$script:LastReportPath = ""

################################################################################
# Button Event Handlers
################################################################################

$analyzeButton.Add_Click({
    # Validate file selection
    if ([string]::IsNullOrWhiteSpace($filePathTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select an APK or XAPK file first!",
            "No File Selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }

    if (-not (Test-Path $filePathTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show(
            "The selected file does not exist!`n`nPath: $($filePathTextBox.Text)",
            "File Not Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }

    # Disable controls during analysis
    $analyzeButton.Enabled = $false
    $browseButton.Enabled = $false
    $listAllRadio.Enabled = $false
    $searchSDKRadio.Enabled = $false
    $sdkTextBox.Enabled = $false
    $verboseCheckBox.Enabled = $false
    $noCleanupCheckBox.Enabled = $false

    # Clear status
    $statusTextBox.Clear()
    $statusTextBox.AppendText("Starting analysis...`n")
    $statusTextBox.AppendText("═══════════════════════════════════════════════════`n`n")
    $form.Refresh()

    # Build command arguments as hashtable for proper parameter passing
    $scriptParams = @{
        APKFile = $filePathTextBox.Text
    }

    if ($searchSDKRadio.Checked -and -not [string]::IsNullOrWhiteSpace($sdkTextBox.Text)) {
        $sdkNames = $sdkTextBox.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $scriptParams['SDKNames'] = $sdkNames
    }
    else {
        $scriptParams['ListAll'] = $true
    }

    if ($verboseCheckBox.Checked) {
        $scriptParams['VerboseOutput'] = $true
    }

    if ($noCleanupCheckBox.Checked) {
        $scriptParams['NoCleanup'] = $true
    }

    # Execute the analysis script
    try {
        $statusTextBox.AppendText("Executing: detect-sdk-android.ps1`n")
        $statusTextBox.AppendText("APK File: $($filePathTextBox.Text)`n")
        if ($scriptParams.ContainsKey('SDKNames')) {
            $statusTextBox.AppendText("SDK Names: $($scriptParams['SDKNames'] -join ', ')`n")
        }
        $statusTextBox.AppendText("`n")
        $form.Refresh()

        # Run the script and capture output using splatting
        $scriptOutput = & $CoreScript @scriptParams 2>&1 | Out-String

        # Display output
        $statusTextBox.AppendText($scriptOutput)
        $statusTextBox.AppendText("`n`n═══════════════════════════════════════════════════`n")
        $statusTextBox.AppendText("Analysis complete!`n")

        # Try to find the generated report
        $reportFiles = Get-ChildItem -Path $ScriptDir -Filter "*android-*.txt" -ErrorAction SilentlyContinue |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -First 1

        if ($reportFiles) {
            $script:LastReportPath = $reportFiles.FullName
            $statusTextBox.AppendText("`nReport saved: $($reportFiles.Name)`n")
            $openReportButton.Enabled = $true
        }

        [System.Windows.Forms.MessageBox]::Show(
            "Analysis completed successfully!`n`nCheck the status window for details.",
            "Analysis Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        $statusTextBox.AppendText("`n`nERROR: $($_.Exception.Message)`n")
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred during analysis:`n`n$($_.Exception.Message)",
            "Analysis Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    finally {
        # Re-enable controls
        $analyzeButton.Enabled = $true
        $browseButton.Enabled = $true
        $listAllRadio.Enabled = $true
        $searchSDKRadio.Enabled = $true
        if ($searchSDKRadio.Checked) {
            $sdkTextBox.Enabled = $true
        }
        $verboseCheckBox.Enabled = $true
        $noCleanupCheckBox.Enabled = $true
    }
})

$openReportButton.Add_Click({
    if (-not [string]::IsNullOrEmpty($script:LastReportPath) -and (Test-Path $script:LastReportPath)) {
        Start-Process notepad.exe $script:LastReportPath
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "No report file found!",
            "Report Not Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
})

$cleanupButton.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "This will remove all temporary files including:`n`n" +
        "- Extracted APK folders`n" +
        "- Merged APK files`n" +
        "- XAPK temporary files`n" +
        "- Old scripts and documentation`n`n" +
        "Analysis reports will be kept.`n`n" +
        "Do you want to continue?",
        "Confirm Cleanup",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            $statusTextBox.Clear()
            $statusTextBox.AppendText("Starting cleanup...`n`n")
            $form.Refresh()

            # Execute cleanup.ps1
            $cleanupScript = Join-Path $ScriptDir "cleanup.ps1"
            if (Test-Path $cleanupScript) {
                $cleanupOutput = & $cleanupScript 2>&1 | Out-String
                $statusTextBox.AppendText($cleanupOutput)
                $statusTextBox.AppendText("`n`nCleanup completed!`n")

                [System.Windows.Forms.MessageBox]::Show(
                    "Cleanup completed successfully!`n`nTemporary files have been removed.",
                    "Cleanup Complete",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
            else {
                [System.Windows.Forms.MessageBox]::Show(
                    "cleanup.ps1 script not found in the same directory!",
                    "Script Not Found",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
        catch {
            $statusTextBox.AppendText("`n`nERROR: $($_.Exception.Message)`n")
            [System.Windows.Forms.MessageBox]::Show(
                "An error occurred during cleanup:`n`n$($_.Exception.Message)",
                "Cleanup Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
})

$exitButton.Add_Click({
    $form.Close()
})

################################################################################
# Show Form
################################################################################

[void]$form.ShowDialog()
