using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;
using SS_CAM.Models;
using SS_CAM.Services;

namespace SS_CAM.Views
{
    // ─── View Models ──────────────────────────────────────────────────────────

    /// <summary>Row view model for an archivable project in the selection list.</summary>
    internal class ArchivableProjectItem
    {
        public string Name { get; set; }
        public string FullPath { get; set; }
        public string Status { get; set; }
        public bool IsSelected { get; set; }
        public long SizeBytes { get; set; }
        public DateTime LastModified { get; set; }

        public string SizeLabel
        {
            get
            {
                if (SizeBytes < 1024) return SizeBytes + " B";
                if (SizeBytes < 1024 * 1024) return (SizeBytes / 1024) + " KB";
                return (SizeBytes / (1024 * 1024)) + " MB";
            }
        }

        public string LastModifiedLabel
        {
            get { return LastModified.ToString("dd MMM yyyy"); }
        }
    }

    /// <summary>Row view model for a catalog history entry.</summary>
    internal class CatalogEntryViewModel
    {
        private readonly ArchiveCatalogEntry _entry;

        public CatalogEntryViewModel(ArchiveCatalogEntry entry)
        {
            _entry = entry;
        }

        public string Summary
        {
            get
            {
                int count = _entry.ProjectCount > 0 ? _entry.ProjectCount : (_entry.ArchivedProjects != null ? _entry.ArchivedProjects.Count : 0);
                string label = count == 1 ? "project" : "projects";
                return string.Format("Archived {0} {1}", count, label);
            }
        }

        public string CountLabel
        {
            get
            {
                int count = _entry.ProjectCount > 0 ? _entry.ProjectCount : (_entry.ArchivedProjects != null ? _entry.ArchivedProjects.Count : 0);
                return count.ToString();
            }
        }

        public string TimestampLabel
        {
            get
            {
                DateTime dt;
                if (DateTime.TryParse(_entry.Timestamp, null, System.Globalization.DateTimeStyles.RoundtripKind, out dt))
                    return dt.ToLocalTime().ToString("dd MMM yyyy HH:mm");
                return _entry.Timestamp;
            }
        }

        public string OperatorLabel
        {
            get { return "by " + (_entry.Operator ?? "Unknown"); }
        }

        public string SizeLabel
        {
            get
            {
                long bytes = _entry.ZipSizeBytes;
                if (bytes <= 0) return "";
                if (bytes < 1024 * 1024) return (bytes / 1024) + " KB";
                return (bytes / (1024 * 1024)) + " MB";
            }
        }

        public Brush StatusColor
        {
            get
            {
                return _entry.Success
                    ? new SolidColorBrush((Color)ColorConverter.ConvertFromString("#10B981"))
                    : new SolidColorBrush((Color)ColorConverter.ConvertFromString("#EF4444"));
            }
        }
    }

    // ─── Page ─────────────────────────────────────────────────────────────────

    public partial class ArchiveVaultPage : Page
    {
        private string _archiveRoot;
        private List<ArchivableProjectItem> _allProjects = new List<ArchivableProjectItem>();
        private List<ArchivableProjectItem> _filteredProjects = new List<ArchivableProjectItem>();
        private bool _isBusy = false;

        private void OnScrollViewerPreviewMouseWheel(object sender, System.Windows.Input.MouseWheelEventArgs e)
        {
            var scroller = sender as ScrollViewer;
            if (scroller == null) return;
            int steps = Math.Max(1, Math.Min(8, Math.Abs(e.Delta) / 30));
            if (e.Delta < 0) for (int i = 0; i < steps; i++) scroller.LineDown();
            else for (int i = 0; i < steps; i++) scroller.LineUp();
            e.Handled = true;
        }

        public ArchiveVaultPage()
        {
            InitializeComponent();
            Loaded   += OnPageLoaded;
            Unloaded += OnPageUnloaded;
        }

        private void OnPageLoaded(object sender, RoutedEventArgs e)
        {
            try
            {
                // Restore archive root from user profile workspace root
                var profile = UserProfileService.LoadProfile();
                if (profile != null && !string.IsNullOrWhiteSpace(profile.WorkspaceRoot))
                {
                    _archiveRoot = ArchiveVaultService.GetArchiveRoot(profile.WorkspaceRoot);
                    TxtArchiveRoot.Text = _archiveRoot;
                }

                RefreshAll();
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] OnPageLoaded: " + ex.Message); }
        }

        private void OnPageUnloaded(object sender, RoutedEventArgs e)
        {
            // No timers to clean up
        }

        // ── Toolbar ───────────────────────────────────────────────────────────

        private void OnRefreshClicked(object sender, RoutedEventArgs e)
        {
            RefreshAll();
        }

        private void OnBrowseArchiveRootClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                var dlg = new System.Windows.Forms.FolderBrowserDialog
                {
                    Description = "Select Archive Root (_Archive) directory on NAS",
                    ShowNewFolderButton = true
                };
                if (!string.IsNullOrWhiteSpace(TxtArchiveRoot.Text) && Directory.Exists(TxtArchiveRoot.Text))
                    dlg.SelectedPath = TxtArchiveRoot.Text;

                if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    TxtArchiveRoot.Text = dlg.SelectedPath;
                    _archiveRoot = dlg.SelectedPath;
                    RefreshAll();
                }
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] Browse: " + ex.Message); }
        }

        private void OnApplyArchiveRootClicked(object sender, RoutedEventArgs e)
        {
            _archiveRoot = (TxtArchiveRoot.Text ?? "").Trim();
            RefreshAll();
        }

        // ── Filter & Selection ────────────────────────────────────────────────

        private void OnProjectFilterChanged(object sender, TextChangedEventArgs e)
        {
            ApplyProjectFilter();
        }

        private void OnStatusFilterChanged(object sender, SelectionChangedEventArgs e)
        {
            ApplyProjectFilter();
        }

        private void OnSelectAllClicked(object sender, RoutedEventArgs e)
        {
            bool val = ChkSelectAll.IsChecked == true;
            foreach (var item in _filteredProjects)
                item.IsSelected = val;
            RebindProjectList();
            UpdateSelectionState();
        }

        private void OnProjectCheckClicked(object sender, RoutedEventArgs e)
        {
            UpdateSelectionState();
        }

        private void OnOpenProjectFolderClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                var element = sender as FrameworkElement;
                var item = (element != null) ? element.Tag as ArchivableProjectItem : null;
                if (item != null && Directory.Exists(item.FullPath))
                    System.Diagnostics.Process.Start("explorer.exe", item.FullPath);
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] OpenFolder: " + ex.Message); }
        }

        // ── Batch Archive ─────────────────────────────────────────────────────

        private void OnArchiveBatchClicked(object sender, RoutedEventArgs e)
        {
            if (_isBusy) return;

            var selected = _filteredProjects.Where(p => p.IsSelected).ToList();
            if (selected.Count == 0)
            {
                ShowResult(false, "No projects selected", "Select at least one project to archive.");
                return;
            }

            if (string.IsNullOrWhiteSpace(_archiveRoot))
            {
                ShowResult(false, "Archive Root not set", "Enter a valid archive root path before archiving.");
                return;
            }

            var confirm = MessageBox.Show(
                string.Format("Archive {0} project(s) to:\n{1}\n\nThis operation is non-destructive — source folders will be preserved.", selected.Count, _archiveRoot),
                "Confirm Batch Archive",
                MessageBoxButton.OKCancel,
                MessageBoxImage.Question);

            if (confirm != MessageBoxResult.OK) return;

            StartArchiveBatch(selected);
        }

        private async void StartArchiveBatch(List<ArchivableProjectItem> selected)
        {
            _isBusy = true;
            SetBusyState(true, selected.Count);

            var paths = selected.Select(p => p.FullPath).ToList();
            var options = new ArchiveBatchOptions
            {
                ArchiveRoot    = _archiveRoot,
                CopyOnly       = true,
                OperatorName   = TryGetOperatorName(),
                ProgressCallback = (processed, total, currentName) =>
                {
                    Dispatcher.BeginInvoke(new Action(() =>
                    {
                        try
                        {
                            ArchiveProgressBar.Value = total > 0 ? (double)processed / total * 100 : 0;
                            ProgressCountLabel.Text = processed + " / " + total;
                            ProgressCurrentProject.Text = currentName;
                        }
                        catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] ProgressCallback: " + ex.Message); }
                    }));
                }
            };

            try
            {
                var result = await ArchiveVaultService.ArchiveBatchAsync(paths, options);
                _isBusy = false;
                SetBusyState(false, 0);

                if (result.Success)
                {
                    string details = string.Format(
                        "{0} project(s) archived  -  {1:N0} KB total  -  Catalog: {2}",
                        result.ArchivedCount,
                        result.TotalZipBytes / 1024,
                        result.CatalogPath);

                    if (result.FailedCount > 0)
                        details += string.Format("\n{0} project(s) failed: {1}", result.FailedCount, string.Join(", ", result.FailedProjects));

                    ShowResult(true, "Archive Complete", details);
                }
                else
                {
                    ShowResult(false, "Archive Failed",
                        result.ErrorMessage ?? ("All " + result.FailedCount + " project(s) failed."));
                }

                RefreshAll();
            }
            catch (Exception ex)
            {
                _isBusy = false;
                SetBusyState(false, 0);
                System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] ArchiveBatch: " + ex.Message);
                ShowResult(false, "Archive Failed", ex.Message);
            }
        }

        // ── Catalog ───────────────────────────────────────────────────────────

        private void OnOpenCatalogFileClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(_archiveRoot)) return;
                string catalogPath = Path.Combine(_archiveRoot, "_archive_catalog.jsonl");
                if (File.Exists(catalogPath))
                    System.Diagnostics.Process.Start(catalogPath);
                else
                    MessageBox.Show("Catalog file not found. Run an archive operation first.", "Archive Vault", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] OpenCatalog: " + ex.Message); }
        }

        // ── Data Loading & Binding ────────────────────────────────────────────

        private void RefreshAll()
        {
            ScanProjects();
            LoadCatalog();
        }

        private void ScanProjects()
        {
            _allProjects.Clear();
            _filteredProjects.Clear();

            try
            {
                var profile = UserProfileService.LoadProfile();
                string workspaceRoot = (profile != null) ? profile.WorkspaceRoot : null;
                if (string.IsNullOrWhiteSpace(workspaceRoot) || !Directory.Exists(workspaceRoot))
                {
                    EmptyStateText.Text = "Workspace root not configured. Check Settings.";
                    ShowProjectListEmpty();
                    UpdateStats();
                    return;
                }

                // Scan immediate child directories - each is a potential project
                string[] projectDirs;
                try { projectDirs = Directory.GetDirectories(workspaceRoot); }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] GetDirectories: " + ex.Message); projectDirs = new string[0]; }

                string archiveRootNorm = string.IsNullOrWhiteSpace(_archiveRoot) ? null : Path.GetFullPath(_archiveRoot);

                foreach (string dir in projectDirs)
                {
                    // Skip the _Archive root itself
                    if (archiveRootNorm != null)
                    {
                        try
                        {
                            if (string.Equals(Path.GetFullPath(dir), archiveRootNorm, StringComparison.OrdinalIgnoreCase))
                                continue;
                        }
                        catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] GetFullPath: " + ex.Message); }
                    }

                    string name = new DirectoryInfo(dir).Name;
                    if (name.StartsWith(".") || name.StartsWith("_")) continue;

                    // Read project status from frontmatter
                    ProjectStatusItem status = null;
                    try { status = FrontmatterService.ReadStatus(dir); }
                    catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] ReadStatus: " + ex.Message); }

                    string statusLabel = (status != null && !string.IsNullOrWhiteSpace(status.Status))
                        ? status.Status : "Unknown";

                    // Estimate folder size (top-level only for performance)
                    long sizeBytes = EstimateDirectorySize(dir);

                    DateTime lastModified = Directory.GetLastWriteTime(dir);

                    _allProjects.Add(new ArchivableProjectItem
                    {
                        Name         = name,
                        FullPath     = dir,
                        Status       = statusLabel,
                        IsSelected   = false,
                        SizeBytes    = sizeBytes,
                        LastModified = lastModified
                    });
                }

                // Sort: most recently modified first
                _allProjects.Sort((a, b) => b.LastModified.CompareTo(a.LastModified));
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] ScanProjects: " + ex.Message);
            }

            ApplyProjectFilter();
            UpdateStats();
        }

        private void ApplyProjectFilter()
        {
            string nameFilter = (TxtProjectFilter.Text ?? "").Trim().ToLowerInvariant();
            string statusFilter = "";
            var selectedStatus = CmbStatusFilter.SelectedItem as ComboBoxItem;
            if (selectedStatus != null && !selectedStatus.Content.ToString().StartsWith("All"))
                statusFilter = selectedStatus.Content.ToString();

            _filteredProjects = _allProjects
                .Where(p => (string.IsNullOrEmpty(nameFilter) || p.Name.ToLowerInvariant().Contains(nameFilter))
                         && (string.IsNullOrEmpty(statusFilter) || p.Status.Contains(statusFilter)))
                .ToList();

            RebindProjectList();
            UpdateSelectionState();
        }

        private void RebindProjectList()
        {
            ProjectItemsControl.ItemsSource = null;
            ProjectItemsControl.ItemsSource = _filteredProjects;

            ProjectListCountLabel.Text = _filteredProjects.Count + " project" + (_filteredProjects.Count == 1 ? "" : "s");

            if (_filteredProjects.Count > 0)
                ShowProjectListFull();
            else
                ShowProjectListEmpty();
        }

        private void LoadCatalog()
        {
            try
            {
                if (string.IsNullOrWhiteSpace(_archiveRoot) || !Directory.Exists(_archiveRoot))
                {
                    CatalogItemsControl.ItemsSource = null;
                    CatalogEmptyPanel.Visibility = Visibility.Visible;
                    CatalogScroller.Visibility = Visibility.Collapsed;
                    StatArchiveOps.Text = "—";
                    return;
                }

                var entries = ArchiveVaultService.LoadCatalog(_archiveRoot);

                // Newest first
                entries.Sort((a, b) => string.Compare(b.Timestamp, a.Timestamp, StringComparison.Ordinal));

                var vms = entries.Select(e => new CatalogEntryViewModel(e)).ToList();

                CatalogItemsControl.ItemsSource = vms;

                if (vms.Count > 0)
                {
                    CatalogEmptyPanel.Visibility = Visibility.Collapsed;
                    CatalogScroller.Visibility = Visibility.Visible;
                }
                else
                {
                    CatalogEmptyPanel.Visibility = Visibility.Visible;
                    CatalogScroller.Visibility = Visibility.Collapsed;
                }

                StatArchiveOps.Text = vms.Count.ToString();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] LoadCatalog: " + ex.Message);
            }
        }

        // ── State Helpers ─────────────────────────────────────────────────────

        private void UpdateSelectionState()
        {
            int count = _filteredProjects.Count(p => p.IsSelected);
            BtnArchiveLabel.Text = "Archive Selected (" + count + ")";
            BtnArchive.IsEnabled = count > 0 && !_isBusy && !string.IsNullOrWhiteSpace(_archiveRoot);

            // Sync select-all checkbox tri-state
            if (count == 0) ChkSelectAll.IsChecked = false;
            else if (count == _filteredProjects.Count) ChkSelectAll.IsChecked = true;
            else ChkSelectAll.IsChecked = null; // indeterminate
        }

        private void UpdateStats()
        {
            StatProjectCount.Text = _allProjects.Count.ToString();
            long totalMb = _allProjects.Sum(p => p.SizeBytes) / (1024 * 1024);
            StatSizeMb.Text = totalMb > 0 ? totalMb.ToString("N0") : "—";
        }

        private void SetBusyState(bool busy, int total)
        {
            ProgressCard.Visibility = busy ? Visibility.Visible : Visibility.Collapsed;
            if (busy)
            {
                ArchiveProgressBar.Value = 0;
                ProgressCountLabel.Text = "0 / " + total;
                ProgressCurrentProject.Text = "";
                ResultBanner.Visibility = Visibility.Collapsed;
            }
            BtnArchive.IsEnabled = !busy;
        }

        private void ShowResult(bool success, string title, string details)
        {
            ResultBanner.Visibility = Visibility.Visible;

            if (success)
            {
                ResultBanner.Background  = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#0D1F15"));
                ResultBanner.BorderBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#10B981"));
                ResultIcon.Symbol        = Wpf.Ui.Controls.SymbolRegular.Checkmark24;
                ResultIcon.Foreground    = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#10B981"));
            }
            else
            {
                ResultBanner.Background  = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#1F0D0D"));
                ResultBanner.BorderBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#EF4444"));
                ResultIcon.Symbol        = Wpf.Ui.Controls.SymbolRegular.ErrorCircle24;
                ResultIcon.Foreground    = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#EF4444"));
            }

            ResultTitle.Text   = title;
            ResultDetails.Text = details;
        }

        private void ShowProjectListEmpty()
        {
            EmptyStatePanel.Visibility    = Visibility.Visible;
            ProjectListScroller.Visibility = Visibility.Collapsed;
        }

        private void ShowProjectListFull()
        {
            EmptyStatePanel.Visibility    = Visibility.Collapsed;
            ProjectListScroller.Visibility = Visibility.Visible;
        }

        private static long EstimateDirectorySize(string path)
        {
            try
            {
                long total = 0;
                // Only count files 2 levels deep for performance
                foreach (string f in Directory.GetFiles(path, "*", SearchOption.AllDirectories))
                {
                    try { total += new FileInfo(f).Length; }
                    catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] FileInfo: " + ex.Message); }
                }
                return total;
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] EstimateDirectorySize: " + ex.Message); return 0; }
        }

        private static string TryGetOperatorName()
        {
            try
            {
                var profile = UserProfileService.LoadProfile();
                if (profile != null && !string.IsNullOrWhiteSpace(profile.DesignerName))
                    return profile.DesignerName;
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[ArchiveVaultPage] TryGetOperatorName: " + ex.Message); }
            return Environment.UserName;
        }
    }
}
