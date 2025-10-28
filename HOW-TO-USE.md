# Android SDK Analyzer - Quick Start Guide

## What Does This Tool Do?

This tool analyzes Android APK/XAPK files to detect:
- ✅ Specific SDKs and libraries (like "pspdfkit", "nutrient", etc.)
- ✅ All libraries and frameworks used in the app
- ✅ Competitor products
- ✅ App package information and metadata

---

## 📁 Project Structure

```
app-decompile-main/
├── SDK-Analyzer-GUI.ps1      ← Main GUI application (double-click to run)
├── detect-sdk-android.ps1    ← Core analysis engine
├── cleanup.ps1               ← Clean up temporary files
├── data/                     ← SDK and competitor databases
│   ├── library-info.txt      ← SDK database (100+ SDKs)
│   └── competitors.txt       ← Competitor list
└── docs/                     ← Documentation folder
```

---

## 🚀 How to Use (3 Simple Steps)

### Step 1: Launch the Application

**Option A: Double-click the GUI (Recommended)**
1. Navigate to the project folder
2. Double-click `SDK-Analyzer-GUI.ps1`
3. If prompted by Windows, click "Run" or "Open"

**Option B: Run from PowerShell**
```powershell
cd "c:\Users\naras\Downloads\app-decompile\app-decompile-main"
.\SDK-Analyzer-GUI.ps1
```

**Screenshot: Main GUI Window**

![GUI Main Window](docs/screenshot-gui-main.png)

---

### Step 2: Select Your APK/XAPK File

1. Click the **"Browse..."** button
2. Navigate to your APK or XAPK file (usually in Downloads folder)
3. Select the file and click "Open"

**Screenshot: File Selection**

![File Selection](docs/screenshot-file-browse.png)

---

### Step 3: Choose Analysis Mode

**Option A: Search for Specific SDKs** (Recommended for quick checks)
1. Select **"Search Specific SDKs"** radio button
2. Enter SDK names in the text box (e.g., `pspdfkit, nutrient, firebase`)
3. Separate multiple names with commas
4. Click **"▶️ Start Analysis"**

**Option B: List All Libraries** (Comprehensive analysis)
1. Select **"List All Libraries (Full Report)"** radio button
2. Click **"▶️ Start Analysis"**

**Screenshot: Analysis Options**

![Analysis Options](docs/screenshot-analysis-options.png)

---

### Step 4: Wait for Analysis

- The status window will show real-time progress
- For XAPK files: extraction and merging may take 1-2 minutes
- For APK files: analysis typically takes 30 seconds to 2 minutes
- **Do not close the window during analysis**

**Screenshot: Analysis in Progress**

![Analysis Progress](docs/screenshot-analysis-running.png)

---

### Step 5: View the Report

After analysis completes:

**Method 1: Click the button**
1. Click **"📄 Open Last Report"** button
2. Report opens in Notepad

**Method 2: Find it manually**
- Reports are saved in the project folder
- File name format: `sdk-analysis-android-YYYYMMDD-HHMMSS.txt`
- Look for the most recent file

**Screenshot: Analysis Complete**

![Analysis Complete](docs/screenshot-analysis-complete.png)

---

## 📊 Understanding the Report

### Report Format

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  ✅ RESULT: KEYWORDS FOUND IN APK                                        ║
╚═══════════════════════════════════════════════════════════════════════════╝

✅ KEYWORD FOUND: 'pspdfkit'
  Found in: AndroidManifest.xml, Resource XML files, Java/smali code
  - AndroidManifest.xml: 3 occurrence(s)
  - Resource XMLs: 5 occurrence(s)
  - Java code: 12 reference(s)

========================================
APP INFORMATION
========================================
Package Name: com.example.myapp
App Version: 1.2.3
Min Android: 5.0 (API 21)
Target Android: 13 (API 33)

========================================
DETECTED SDKS & LIBRARIES
========================================
✅ pspdfkit - Document SDK
✅ Firebase Analytics - Google Analytics
✅ OkHttp - HTTP Client
... (and more)

========================================
COMPLETE LIBRARY LIST
========================================
1. com.pspdfkit.*** (24 files)
2. com.google.firebase.*** (45 files)
3. com.squareup.okhttp3.*** (18 files)
... (and more)
```

### What to Look For

**✅ Keyword Found:**
- Shows if your searched SDK is present
- Lists all locations where it was found
- Shows number of occurrences

**❌ Keyword Not Found:**
- The SDK is not used in this app
- Try alternative names or check full library list

---

## 🧹 Cleaning Up After Analysis

### Why Clean Up?

Analysis creates temporary folders that can use **100-500 MB** per analysis:
- Extracted APK files
- Merged APK files (for XAPK)
- Decompiled code

### How to Clean Up

**Method 1: Use the GUI Button**
1. Click **"🧹 Clean Up Temporary Files"** button
2. Confirm when prompted
3. Wait for cleanup to complete

**Method 2: Run Cleanup Script**
```powershell
.\cleanup.ps1
```

**Screenshot: Cleanup Button**

![Cleanup Button](docs/screenshot-cleanup-button.png)

### What Gets Deleted

- ✅ Temporary analysis folders (`sdk-analysis-android-*`)
- ✅ Merged APK files (`merged-*.apk`)
- ✅ Old reports (keeps 3 most recent)
- ❌ Your original APK/XAPK files (NEVER deleted)
- ❌ Latest 3 reports (kept for reference)
- ❌ SDK databases (kept)

**Screenshot: Cleanup Complete**

![Cleanup Complete](docs/screenshot-cleanup-complete.png)

---

## ⚙️ Advanced Options

### Keep Temporary Files (For Debugging)

If you want to inspect extracted files manually:
1. Check **"Keep Temporary Files"** checkbox before analysis
2. After analysis, temporary folders remain in project directory
3. You can browse extracted APK contents manually

### Verbose Output

For detailed technical information:
1. Check **"Verbose Output"** checkbox before analysis
2. Status window shows detailed progress
3. Report includes more technical details

---

## 🔧 Troubleshooting

### Issue: GUI doesn't open

**Solution:**
```powershell
# Run with execution policy bypass
powershell -ExecutionPolicy Bypass -File .\SDK-Analyzer-GUI.ps1
```

### Issue: "apktool not found"

**Solution:**
- Ensure Java is installed (required for apktool)
- Download apktool.jar and place it in the project folder
- Or install via package manager

### Issue: Analysis is stuck/hanging

**Solution:**
- Wait 2-5 minutes (large files take time)
- If still stuck after 10 minutes, close and restart
- Try analyzing a smaller APK first to test

### Issue: "File not found" error

**Solution:**
- Make sure the APK/XAPK file path has no special characters
- Try moving the file to a simpler path (e.g., `C:\Temp\`)
- Ensure file is not corrupted

### Issue: Cannot delete temporary files

**Solution:**
- Close all programs that might be using the files
- Restart PowerShell/Command Prompt
- If still locked, restart Windows and try cleanup again

---

## 📝 Tips & Best Practices

### For Best Results:

1. **Keep SDK database updated**
   - Edit `data\library-info.txt` to add new SDKs
   - Format: `SDKName|Description|Keywords`

2. **Search multiple names at once**
   - Example: `pspdfkit, nutrient, pdf, document`
   - Tool checks all variants automatically

3. **Clean up regularly**
   - Run cleanup after each analysis
   - Prevents disk space issues

4. **Save important reports**
   - Copy reports to another folder before cleanup
   - Cleanup keeps only 3 most recent

5. **Use descriptive XAPK filenames**
   - Rename files before analysis for easier tracking
   - Example: `MyApp_v1.2.3_downloaded_20250128.xapk`

---

## 🛡️ Security & Privacy

- ✅ All analysis is done **locally** on your computer
- ✅ No data is sent to external servers
- ✅ No internet connection required (after initial setup)
- ✅ Your APK files are never modified or uploaded

---

## 📞 Support & Feedback

If you encounter issues:
1. Check the troubleshooting section above
2. Review the status window for error messages
3. Ensure Java and PowerShell 5.1+ are installed

---

## 🎯 Quick Reference Card

| Task | Command |
|------|---------|
| Launch GUI | Double-click `SDK-Analyzer-GUI.ps1` |
| Search specific SDK | Select "Search Specific SDKs" → Enter names → Start |
| List all libraries | Select "List All Libraries" → Start |
| View report | Click "Open Last Report" button |
| Clean up files | Click "Clean Up Temporary Files" button |
| Manual cleanup | Run `.\cleanup.ps1` |

---

**Version:** 1.0
**Last Updated:** January 2025
**Platform:** Windows 11 / PowerShell 5.1+
