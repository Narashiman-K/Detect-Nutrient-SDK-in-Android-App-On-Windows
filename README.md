# Android SDK Analyzer for Windows

Analyze Android APK/XAPK files to detect SDKs, libraries, and competitor products.

## 🚀 Quick Start

1. **Launch the GUI:**
   ```powershell
   .\SDK-Analyzer-GUI.ps1
   ```
   Or just double-click `SDK-Analyzer-GUI.ps1`

2. **Select an APK/XAPK file** using the Browse button

3. **Choose analysis mode:**
   - Search for specific SDKs (e.g., "pspdfkit, nutrient")
   - Or list all libraries (full report)

4. **Click "Start Analysis"** and wait for results

5. **View the report** by clicking "Open Last Report"

6. **Clean up** temporary files when done

## Demo
Detect-Nutrient-SDK-in-Andriod-App-On-Windows.mp4

## 📁 Project Structure

```
app-decompile-main/
├── SDK-Analyzer-GUI.ps1          Main GUI application
├── detect-sdk-android.ps1        Core analysis engine
├── cleanup.ps1                   Cleanup utility
├── HOW-TO-USE.md                 Detailed user guide
├── data/                         SDK databases
│   ├── library-info.txt          SDK database (100+ SDKs)
│   └── competitors.txt           Competitor list
└── docs/                         Documentation
```

## 📖 Documentation

- **[HOW-TO-USE.md](HOW-TO-USE.md)** - Complete user guide with screenshots
- **[PROJECT-CLEANUP-SUMMARY.md](PROJECT-CLEANUP-SUMMARY.md)** - Recent changes and cleanup details

## ⚙️ Requirements

- Windows 10/11
- PowerShell 5.1 or higher
- Java (required for APK decompilation)

## 🆘 Troubleshooting

**GUI won't open?**
```powershell
powershell -ExecutionPolicy Bypass -File .\SDK-Analyzer-GUI.ps1
```

**Need help?** See [HOW-TO-USE.md](HOW-TO-USE.md) troubleshooting section.

## 🎯 Features

- ✅ Search for specific SDKs by name
- ✅ List all libraries in an APK
- ✅ Extract and analyze XAPK files (multi-APK packages)
- ✅ Detect competitor products
- ✅ Generate detailed analysis reports
- ✅ Clean up temporary files with one click
- ✅ 100% local analysis (no internet required)

## 📊 What Gets Analyzed

- AndroidManifest.xml entries
- Resource XML files
- Java/smali code
- Native libraries (.so files)
- Asset files
- META-INF metadata

## 🔒 Privacy & Security

- All analysis is performed locally on your computer
- No data is sent to external servers
- Your APK files are never modified
- No internet connection required

---

**Version:** 1.0
**Platform:** Windows 11 / PowerShell 5.1+
**Last Updated:** January 2025
