# SS-CAM v5.3.x Improvement Brief (for Antigravity)

Repo: `E:\Dev\Projects\SS-CAM`, branch `SS-Master`. App: WPF, .NET Framework 4.8, WPF-UI 3.0.4, code-behind pages (no ViewModels on the pages below). Core code is in `src/SS-CAM/`.
**Read `AGENTS.md` first. It is binding.** Key points are repeated under Guardrails.

## Guardrails (non-negotiable)
- Smallest safe change. Inspect, then change, then build, then verify. Do not rewrite working features.
- **Do not launch the app against real data.** `App.OnStartup` copies the exe and fonts into the user profile and registers a URI scheme. If a launch is needed, use a throwaway Windows user or VM and a temp workspace. Never touch the real NAS (`\\SSNAS\...`, `Z:\`). Use a temp folder as the workspace.
- All `.cs` and `.xaml` files must stay **UTF-8 with BOM**. Verify after edits (`head -c3 file | xxd` gives `efbbbf`).
- No silent catches. Log with `App.LogTrace(...)` (`App.LogException` is private). No `.Result`/`.Wait()` on the UI thread.
- ComboBox: `MinHeight`/`Height` >= 36, `VerticalContentAlignment="Center"`, padding `10,0`. Scrollable containers need trailing padding >= 12. Lists get `ScrollViewer.HorizontalScrollBarVisibility="Disabled"`. Chip rows use `WrapPanel`, not a horizontal ScrollViewer.
- Reuse existing resources and tokens (`FluentBrand80`, `FluentBrandTint`, `CardStrokeColorDefaultBrush`, `TextFill*Brush`, and so on). No hardcoded tenant strings in Core. Keep terminology (Workspace, Project Creator, Settings & Profile).
- Report results only as PASS / FAIL / PARTIAL / BLOCKED. PASS means actually verified on disk or on screen. A toast saying "Success" is not proof.
- Before committing, run `.\QA\verify-dual-track.ps1 -Fix`. Commit message trailer: `Co-Authored-By: Antigravity <noreply@google.com>`. Do not push without being asked.
- Update `/QA/` docs for anything you test or fix.

## Build command
Only the Framework MSBuild exists on the dev machine, so treat this as a compile check. A Visual Studio build is authoritative.
```powershell
& "$env:windir\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe" src\SS-CAM\SS-CAM.csproj /p:Configuration=Debug /p:OutDir=<temp dir>\ /t:Build /v:minimal /nologo
```
The project is old-style (`packages.config`, hand-listed `.cs` files). **New files must be added to `SS-CAM.csproj`** (`<Compile Include>` / `<Page Include>`).

## Already done
- **Archive crash fix** (uncommitted, in `Views/ArchiveVaultPage.xaml.cs`): the filter handlers are guarded with `if (!IsLoaded) return;`. Compiles. **Not runtime-verified.**

## Task order and acceptance criteria

### T1. Archive module (finish)
Root cause: `CmbStatusFilter` (`ArchiveVaultPage.xaml:166`) `IsSelected="True"` fired `SelectionChanged` during `InitializeComponent`, so `RebindProjectList` hit a null control (58 crashes in `%LOCALAPPDATA%\SuamiSihat\crash_log.txt`).
Remaining work:
1. Move `EstimateDirectorySize` (`ArchiveVaultPage.xaml.cs` ~564-578) off the UI thread: async, cancellable, with "calculating..." UI.
2. Make `ArchivableProjectItem` implement `INotifyPropertyChanged`. Stop rebinding with `ItemsSource = null`.
3. When the workspace root is empty, show the empty state with a button that navigates to Settings.
4. Replace the `Debug.WriteLine` swallows in `Services/ArchiveVaultService.cs` with `App.LogTrace`. Keep `CopyOnly = true`. Do not enable the prune/delete path.
**Accept:** the page opens with no new `crash_log.txt` entry. Archiving a dummy project in a temp workspace creates the copy under `_Archive/yyyy/yyyyMM_Month` with matching file counts and sizes, plus a `_archive_catalog.jsonl` line. The source is untouched. Offline or invalid root shows an error state without freezing the UI.

### T2. QR Code Studio
Cause is **not confirmed**. Files: `Views/QrCodePage.xaml(.cs)`, `Services/QrCodeEncoderService.cs`. Library: QRCoder 1.4.3 (embedded by Costura).
1. Reproduce first, with a debugger, and record the real exception. Currently hidden: `QrCodeEncoderService.cs` ~936-940 returns a blank 21x21 matrix on any exception, and `QrCodePage.xaml.cs` ~51, 172, 455 only `Debug.WriteLine`.
2. Replace the silent catches with `App.LogTrace` and an inline error state in the preview.
3. Fix the confirmed cause. Also fix: `Diamond` and `Classy` body shapes fall through to square in `DrawBodyModule` (implement them or hide the buttons, `QrCodePage.xaml.cs` ~459-479); `GenerateSvgXml` must match the bitmap (logo, corner radius, `GradientAngle`); check the module pixel size logic (`max(4, req/total)`) against `SldResolution` 300-2000.
4. Dead code (`BuildDataCodewords`, `ToBits`, `GfExp`/`GfLog`, `GenerateDrawingImage`): grep for callers, then remove only if none.
**Accept:** URL, vCard and WiFi codes render in the preview and **scan correctly with a phone**. PNG and SVG exports scan and visually match. Every body shape works with and without a logo. Errors are visible to the user and in the log.

### T3. Startup and build speed
Measure first: cold start to first interactive frame, and clean and incremental build time. Record the numbers in `QA/`. Each item ships separately.
1. `App.xaml.cs` ~135-187 and `Services/PayloadInstallerService.cs` ~12-31, 135-157: payload (137 MB), exe and fonts are re-copied on **every launch**. Skip when size and mtime match (or use a version marker). Run after the main window shows.
2. `Services/UserProfileService.cs` ~54-100 and `Services/NasConfigSyncService.cs` ~357: cache the profile in memory (36 `LoadProfile()` call sites). Do NAS probing (`Directory.Exists`, `DiscoverWorkspaceRoot`, `SyncFromNasIfNewer`) async with a short timeout.
3. `Services/ThemeService.cs` ~178-211 and `MainWindow.xaml.cs` ~92: `ApplyTheme` must not write to the NAS at startup. Persist only on user change.
4. `App.LogTrace` (~105): buffer the writes.
5. `MainWindow.xaml.cs` ~45-136, ~1192: defer update check, NAS health, watcher, session tracker and intro sound to `ContextIdle` or the background. Replace `Thread.Sleep(3000)` with `Task.Delay`.
6. `Views/DashboardPage.xaml.cs` ~121-157: guard against concurrent `RefreshDashboard` runs (timer, watcher and page load can overlap). Paint cached data first.
7. Stop page timers on `Unloaded` (Wellbeing, WaktuSolat, Dashboard). Run `VisualizerService` (33 ms) only while the radio plays.
8. `MainWindow.xaml.cs` ~1083: remove the global `ServerCertificateValidationCallback = true` (security). Use a shared `HttpClient`.
9. Build: `packages.config` omits Fody 6.5.5 and Costura.Fody 5.7.0, which the csproj imports behind `Exists()`. Declare them or remove the imports, then delete stale `packages/` folders. Skip Costura in Debug. Remove unused references only after grepping usage (`System.Windows.Forms` is used by the Archive folder dialog; `System.Drawing` is used by QR). Remove the duplicate `tenant_config.json` (Content and EmbeddedResource) if the embedded copy is unused. Add a `.sln`. Use `/m` and `/t:Build` in `.agents/skills/sscam-qa/scripts/run-sscam-qa.ps1`. Add `ngen install` to `installer/Build-Installer.ps1`.
- **Do not** migrate to an SDK-style csproj in this task. Propose it separately.
**Accept:** a second launch skips the payload copy (verify by file timestamps). With the NAS unreachable, the main window appears and stays responsive. Startup time is measurably lower and the numbers are recorded.

### T4. Settings page, minimalist
Files: `Views/SettingsPage.xaml` (1105 lines) and `.cs` (939 lines, all handlers there). Currently 9 copy-pasted `ui:Card` sections in two columns.
1. Single centered column (max ~760 px) with a left category rail: Profile, Workspace, Account, Appearance, Modules, Maintenance. One category visible at a time.
2. One reusable section style or UserControl for the repeated header (32x32 icon tile, 14 Bold title, 11 subtitle).
3. Merge Workstation Payload, Category Presets and Diagnostics into one "Workstation" group of plain rows (give Diagnostics a title). Put Reset and Maintenance last under an "Advanced" expander. Keep the confirmation dialogs on destructive actions.
4. Compact Profile (avatar and name row; staff picker and fields behind "Edit"). Show the workspace path-format hint only on a validation error. Theme swatches become a compact chip row.
5. Fix the truncated module descriptions (add `TextTrimming` and a tooltip).
- Layout and style only. **Keep every handler and name** so behavior does not change.
**Accept:** every control behaves as before: save profile, workspace path and presets, sign in/out, theme swap, module toggles (sidebar updates), payload actions, and reset (confirms first). Keyboard Tab order, visible focus and accessible names are in place. Usable at narrow widths.

### T5. "Focus" theme (productivity and speed)
Neutral, low-chroma, high-contrast, flat, with a single blue-teal accent, no glow and no animations, compact density. Light and dark variants following the existing pattern. Base it on `Styles/NordTheme.xaml`.
Registration (hard-coded, edit all):
1. `Services/ThemeService.cs`: `AppTheme.Focus` enum value, `GetFocusColors()`, the `GetColors` dispatch, the dark/light choice and accent in `ApplyTheme`, the `SwapResourceDictionary` mapping and its removal-match list (~375).
2. New `Styles/FocusTheme.xaml`, plus a `<Page Include=... MSBuild:Compile>` entry in `SS-CAM.csproj` (~77-100). Include the ComboBox and ComboBoxItem standards. They are currently only in `Fluent2Styles.xaml`, so confirm each theme file carries them.
3. `MainWindow.xaml.cs`: the `OnStatusThemeToggle` cycle (~915-933), the display name (~1009), `forceWhiteNavText` (~1016).
4. `Views/SettingsPage.xaml(.cs)`: swatch and handler (~818-841).
5. Also fix `GetNordColors`, which omits `SpectrumBarColor`.
**Accept:** cycle through all six themes. No unreadable text, ComboBoxes render correctly (including the Staff ComboBox), nav and header colors correct, and the choice persists after restart.

### T6. Radio Player, Zune style
Files: `Views/RadioPage.xaml` (563 lines) and `.cs` (1279 lines); `Services/RadioStreamService.cs`, `Services/VisualizerService.cs`, `Models/RadioStation.cs`.
Design: big Segoe UI Light title, panoramic horizontal layout, a large Now Playing art tile with oversized station name and a thin visualizer line, a cover-art tile grid (name over a bottom gradient), flat accent blocks with no cards or shadows.
Constraints:
- `OnRhythmTick` (`RadioPage.xaml.cs` ~401-807) animates named elements (`AuraRing1/2`, `Spark1-6`, `HeroWavePath*`, `HeroMeshStop1-3`, `SSLogoCanvas`). Keep the names or update `OnRhythmTick` and `UpdateVisualizerModeUI` together.
- Keep `Tag="{Binding}"` on station buttons (`OnStationPlayClicked`, `...FavoriteClicked`, `...EditClicked`, `...DeleteClicked`).
- `RadioStation` already has `LocalCoverPath`, `HasLocalCover`, `Initials`, `IconEmoji`, `FavIcon`. No model change.
- Keep SpectrumBars, Waveform and PulseRing visualizers. Move the heavy ones (and the 69 floating "♂" particles) behind a setting.
- Horizontal scroll must not overlap content (bottom padding >= 12). Keyboard navigation, focus visuals and `AutomationProperties.Name` on icon-only buttons.
- The MainWindow bottom bar and flyout are out of scope.
**Accept:** play, stop, favourite, add, edit, delete, import and export all work. The visualizer reacts to audio. The bottom bar stays in sync. Stations without covers show initials.

## Delivery
Four commits on `SS-Master`: (1) T1 + T2, (2) T3, (3) T4 + T5, (4) T6. Each commit must build and have its QA notes in `/QA/`. After each task, report PASS / FAIL / PARTIAL / BLOCKED per acceptance item, with evidence (file listings, log excerpts, screenshots).
