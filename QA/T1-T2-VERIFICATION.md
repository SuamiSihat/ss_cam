# QA Verification: T1 (Archive Vault) & T2 (QR Code Studio)

**Date:** 2026-10-22  
**Branch:** `SS-Master`  
**Configuration:** Release (.NET Framework 4.8 / WPF)  
**Status:** **PASS**

---

## 1. Task 1: Archive Vault Hardening & Performance

### Changes Implemented
1. **Background Size Estimation & Cancellation (`ArchiveVaultPage.xaml.cs`):**
   - Transferred heavy recursive folder size calculations off the UI thread into a cancellable `Task.Run`.
   - Added `CancellationTokenSource` cancelled automatically on page reload, rescan, or page unload.
   - Initialized item size as `-1` ("Calculating...") and dispatched in-place size calculations as they complete.
2. **Smooth INotifyPropertyChanged Updates (`ArchiveVaultPage.xaml.cs`):**
   - Converted `ArchivableProjectItem` to implement `INotifyPropertyChanged` using C# 5-compatible event invocation.
   - Bound `ProjectItemsControl.ItemsSource` to `ObservableCollection<ArchivableProjectItem>` once.
   - Removed aggressive `ItemsSource = null` rebindings that caused UI flickering and scroll resets.
   - Updated `OnSelectAllClicked` to mutate selection in-place.
3. **Empty / Missing Root Handling (`ArchiveVaultPage.xaml`, `ArchiveVaultPage.xaml.cs`):**
   - Added `BtnGoToSettings` inside the empty-state panel with primary Fluent 2 styling and icon.
   - Implemented navigation to `SettingsPage` via `MainWindow.RootNavigation` if workspace path is empty or invalid.
4. **Data Safety Enforcement (`ArchiveVaultService.cs`):**
   - Strictly enforced `options.CopyOnly = true;` to guarantee source project files are never pruned or deleted during archive operations.
5. **Trace Logging Standard:**
   - Replaced all raw `Debug.WriteLine` statements with `App.LogTrace`.

### Automated Verification (`QA/scripts/test_archive.ps1`)
- **Test 1:** Archive ZIP packaging creates correct directory structure (`_Archive/yyyy/yyyyMM_Month/yyyyMMdd_<Project>_ARCHIVE.zip`). -> **PASS**
- **Test 2:** Source project files remain 100% untouched (`CopyOnly = true`). -> **PASS**
- **Test 3:** Catalog `_archive_catalog.jsonl` appends valid JSON metadata entry. -> **PASS**
- **Test 4:** Invalid/offline NAS root reports clean failure without crashing or freezing UI. -> **PASS**

---

## 2. Task 2: QR Code Studio Vector Engine & Fluent 2 Audit

### Changes Implemented
1. **Selective Rounded Rect Path Geometry (`QrCodeEncoderService.cs`):**
   - Rewrote `CreateSelectiveRoundedRectPath` using a continuous clockwise path (top -> top-right arc -> right -> bottom-right arc -> bottom -> bottom-left arc -> left -> top-left arc).
   - Eliminated discontinuous half-edge lines and rendering holes that broke camera scannability.
2. **Body Shape Parity (`QrCodeEncoderService.cs`):**
   - Implemented `QrBodyShape.Diamond` (rhombus polygon) and `QrBodyShape.Classy` (diagonal rounded petal) in both Bitmap and SVG engines.
   - Added SVG path generation for selective rounded module corners.
3. **Full SVG Vector Parity (`QrCodeEncoderService.cs`):**
   - Embedded logo image as base64 PNG (`<image href="data:image/png;base64,..."/>`) alongside circular background pad.
   - Synchronized finder eye corner radii between Bitmap and SVG (`rx = moduleSize * 2.5f`, `irx = moduleSize * 1.5f`).
   - Added `QrEyeDotShape.Diamond` vector polygon in SVG.
   - Supported dynamic `GradientAngle` rotation in `<linearGradient>` definition.
4. **Export Resolution & Sizing Math (`QrCodeEncoderService.cs`):**
   - Improved module sizing calculation to `Math.Max(1, (int)Math.Round((double)reqSize / totalModules))`.
   - Adheres within module boundaries across 300px to 2400px exports without subpixel blur.
5. **Dead Code Elimination (`QrCodeEncoderService.cs`):**
   - Removed unused manual codeword generator (`BuildDataCodewords`, `ToBits`, `QrBlockSpec`), unused GF(256) tables (`GfExp`, `GfLog`), and unused `GenerateDrawingImage` / `AppendWpfFinderEye` (~200 LOC removed).
6. **Graceful Error Handling & Non-Image Logo Handling (`QrCodePage.xaml`, `QrCodePage.xaml.cs`):**
   - Added inline `PreviewErrorOverlay` with error icon and message.
   - Replaced silent catch in `GenerateQrMatrix` with `App.LogTrace` and exception propagation.
   - Handled non-image file uploads in `OnUploadCustomLogoClicked` with user feedback and avoided file locks.
7. **Fluent 2 ComboBox Standard:**
   - Standardized `CmbWifiEnc`, `CmbEyeFrameShape`, `CmbEyeDotShape`, and `CmbErrorCorrection` to `MinHeight="36"`, `VerticalContentAlignment="Center"`, and `Padding="10,0"`.

### Automated Verification (`QA/scripts/test_qrcode.ps1`)
- **Content Formats:** URL, vCard, WiFi encoding (Bitmap & SVG) -> **PASS**
- **Body Shapes:** Square, Circle, Rounded, Dots, Diamond, Classy (Bitmap & SVG) -> **PASS**
- **Finder Eye Shapes:** 12 combinations of Eye Frame and Eye Dot shapes -> **PASS**
- **Gradient Angle Support:** Distinct coordinates for 90° vs 180° -> **PASS**
- **Logo Embedding:** Base64 image + circular pad in SVG -> **PASS**
- **Sizing Math Scaling:** 300px, 600px, 1200px, 2000px scaling -> **PASS**
- **Total Tests:** 24 passed / 0 failed.

---

## 3. Governance & Quality Checks

- **Source Guardian (`QA/verify-sscam.ps1 -Fix`):**
  - UTF-8 BOM encoding restored on all modified files.
  - 14/14 checks **PASSED**.
- **Dual-Track Governance (`QA/verify-dual-track.ps1 -Fix`):**
  - Cross-platform project format & public documentation leakage check **PASSED**.
- **Build Verification:**
  - `MSBuild.exe src\SS-CAM\SS-CAM.csproj /p:Configuration=Release /t:Rebuild` -> **0 Errors**.
