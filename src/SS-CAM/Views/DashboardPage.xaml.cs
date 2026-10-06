using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using System.Xml.Linq;
using SS_CAM.Models;
using SS_CAM.Services;

namespace SS_CAM.Views
{
    public partial class DashboardPage : Page
    {
        private string workspaceRoot = string.Empty;
        private DispatcherTimer _tipTimer;
        private int _tipIndex = 0;
        private DispatcherTimer _liveTasksTickerTimer;
        private List<LiveTaskEntry> _currentLiveTasks;
        private bool _liveFilterUpdating = false;

        private bool _isCustomizingLayout = false;
        private List<DashboardWidgetConfig> _currentLayout;
        private readonly List<DashboardSpotlightItem> _allSpotlightItems = new List<DashboardSpotlightItem>();
        private string _currentSpotlightFilter = "ALL";

        public class DashboardSpotlightItem
        {
            public string JobId { get; set; }
            public string Title { get; set; }
            public string StatusLabel { get; set; }
            public Brush StatusBrush { get; set; }
            public string Designer { get; set; }
            public string DeadlineDisplay { get; set; }
            public string ProjectPath { get; set; }
        }

        public class DashboardTranscodeDisplayItem
        {
            public string SourceFileName { get; set; }
            public string PresetDisplay { get; set; }
            public string StatusText { get; set; }
            public int ProgressPercent { get; set; }
            public string ProgressPercentDisplay { get; set; }
            public string OutputFilePath { get; set; }
        }

        // ────────────────────────────────────────────────
        // Design Tip data class (C#5 compatible — no tuples)
        // ────────────────────────────────────────────────
        private class DesignTip
        {
            public string Title { get; set; }
            public string Body { get; set; }
            public DesignTip(string title, string body) { Title = title; Body = body; }
        }

        private static readonly DesignTip[] _tips = new DesignTip[]
        {
            new DesignTip("Use the 60-30-10 Colour Rule", "Allocate 60% to a dominant colour, 30% to a secondary, and 10% to an accent. This creates balanced, professional palettes without guesswork."),
            new DesignTip("White Space Is Not Wasted Space", "Generous padding and margins reduce cognitive load and direct the viewer's eye to what actually matters. Crowded designs exhaust the audience."),
            new DesignTip("Limit Typefaces to Two", "One typeface for headings, one for body copy. Mixing more than two creates visual noise. Use weight and size variation instead of a third font."),
            new DesignTip("Align Everything to a Grid", "An 8-point grid (multiples of 8 px for all spacing and sizing) keeps your layouts consistent across breakpoints and artboards."),
            new DesignTip("Test Contrast for Accessibility", "WCAG AA requires a minimum contrast ratio of 4.5:1 for normal text. Run every brand colour pair through a contrast checker before finalising."),
            new DesignTip("Kerning vs Tracking", "Kerning is the space between two specific characters; tracking is uniform spacing across a word. Fine-tune kerning at display sizes; adjust tracking for headlines and all-caps."),
            new DesignTip("The Hierarchy Rule of Three", "Organise content into three visual levels: primary (largest, boldest), secondary (medium), tertiary (small, muted). Users scan in this order."),
            new DesignTip("Print at 300 DPI Minimum", "Any asset destined for offset or digital print should be at 300 DPI at final output size in CMYK. Designing at 72 DPI and scaling up always ends in regret."),
            new DesignTip("Name Your Layers", "A file with 47 layers named 'Rectangle Copy 12' is unusable. Layer and group names like 'hero-bg', 'cta-button', 'logo-primary' make handoffs seamless."),
            new DesignTip("Bleed 3 mm on All Print Sides", "Any artwork that reaches the edge of the page must extend 3 mm beyond the trim line as bleed. Missing bleed causes white edges after cutting."),
            new DesignTip("Avoid Pure Black Text (#000000)", "Pure black on white creates harsh contrast that fatigues the eyes during reading. Use near-black (#1E293B or #0F172A) for body text instead."),
            new DesignTip("Colour Psychology: Blue Signals Trust", "Blue is the single most universally trusted colour in healthcare and financial branding, which is why Corporate's brand anchor is a deep blue (#043388)."),
            new DesignTip("Use SVG for Logos, Not PNG", "SVGs are resolution-independent — they look sharp on any screen and any size. PNGs pixelate when scaled. Deliver client logos as SVG whenever possible."),
            new DesignTip("Brand Consistency Over Creativity", "For established brands, consistency builds recognition faster than creative novelty. Reserve experimentation for campaign sub-identities and event branding."),
            new DesignTip("The Gestalt Principle of Proximity", "Elements placed near each other are perceived as belonging to the same group. Use spacing deliberately to form logical visual clusters."),
            new DesignTip("Optical Centring vs Mathematical Centring", "A shape that is mathematically centred often looks slightly too low. Optical centring — nudged a hair upward — feels more balanced to the human eye."),
            new DesignTip("Limit Body Text to 65-75 Characters per Line", "Line lengths beyond 80 characters impair readability. Use column widths or max-width settings to keep body text in the comfortable reading range."),
            new DesignTip("Use Semibold Instead of Bold for Subheadings", "Bold at small display sizes can look heavy and cramp letter spacing. Semibold (600 weight) gives emphasis without sacrificing elegance."),
            new DesignTip("Save Source Files Before Export", "Always save the native editable file (.afdesign, .psd, .ai) before running your export. Exported files are not your source — they are your output."),
            new DesignTip("RGB for Screens, CMYK for Print", "Designing a digital banner in CMYK means the software is converting your colours and they may shift on screen. Work in sRGB for digital; switch to CMYK only for print."),
            new DesignTip("Colour Profiles Matter", "Embed your ICC colour profile when saving files intended for print handoff. Missing profiles cause colour shifts between design, proof, and press."),
            new DesignTip("Leading Affects Readability", "Line height (leading) should be 1.4 to 1.6 times the font size for body text. Tight leading makes text claustrophobic; loose makes it feel disconnected."),
            new DesignTip("The Rule of Odds", "Groupings of an odd number of elements (3, 5, 7) appear more natural and visually interesting than even groupings. Apply to icon rows, card grids, and image collages."),
            new DesignTip("Design for the Fastest Scan First", "Users read in an F-pattern: across the top, then down the left. Put your most critical information in the first two horizontal bands."),
            new DesignTip("Master Canvas = Creative Insurance", "A master canvas file containing every approved asset at source resolution means any future adaptation can be produced in minutes."),
            new DesignTip("Snap to Pixel Grid", "Sub-pixel rendering creates blurry edges on screen. Enable 'Snap to Pixel Grid' in Affinity or Photoshop to ensure all strokes and shapes stay crisp."),
            new DesignTip("File Naming Is Documentation", "A file called 202608_0042S_SSC_Raya-Campaign.afdesign communicates project, date, brand, and context instantly. Generic names like 'Final_v3_FINAL.psd' cost the team time."),
            new DesignTip("Mockups Sell Ideas", "Even a rough concept presented in a contextual mockup (billboard, phone screen, tote bag) lands significantly better with stakeholders than a flat artboard."),
            new DesignTip("Scale Your Text Optically", "At display sizes (above 36 pt), reduce letter-spacing and tighten line height. At small sizes (below 12 pt), do the opposite. Type behaves differently at scale."),
            new DesignTip("Always Outline Text for Final Delivery", "When sending vector files to a printer, outline all fonts. This eliminates missing-font errors regardless of what software the recipient uses."),
            new DesignTip("The Hick-Hyman Law", "Every additional choice increases the time a user takes to decide. Fewer options on a poster or UI lead to faster, more decisive responses."),
            new DesignTip("Aspect Ratio Discipline", "Define the aspect ratios allowed per platform in your brief before opening Affinity. Retrofitting square assets into stories is always inefficient."),
            new DesignTip("Dark Mode Needs Separate Colour Tokens", "A dark-mode asset is not simply an inverted version of the light-mode one. Define separate token values rather than applying CSS/filter invert."),
            new DesignTip("Consistent Radius = Cohesive Brand", "Pick one corner-radius value for cards and buttons and apply it system-wide. Mixing radii makes a UI feel unfinished."),
            new DesignTip("Export Artboards, Not the Document", "When exporting from Affinity, always export named artboards rather than the whole document page. This gives you clean individual files without clipping artefacts."),
            new DesignTip("Grid Overlap Creates Depth", "Layering elements so they cross grid cell boundaries creates visual dynamism while maintaining structural order."),
            new DesignTip("Brief Before Brief Deck", "Write the project brief in plain text first. If you cannot describe the project clearly in three sentences, the scope is not well-defined enough to start designing."),
            new DesignTip("Proof on Multiple Devices", "Colour and resolution look different on a calibrated monitor, a laptop, and a mobile phone. Always proof critical campaigns across at least two device types."),
            new DesignTip("Rest Is Part of the Creative Process", "Cognitive fatigue degrades design quality measurably. A 10-minute break after 90 minutes of focused work restores perceptual accuracy and problem-solving capacity."),
            new DesignTip("Revision Rounds Belong in the Brief", "State the number of included revision rounds in writing before the project begins. Unlimited revisions have no equivalent in any other professional service."),
        };

        public DashboardPage()
        {
            InitializeComponent();

            var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
            if (TxtVersionBadge != null)
            {
                TxtVersionBadge.Text = string.Format("v{0}", version.ToString(3));
            }

            Loaded += OnPageLoaded;
            Unloaded += OnPageUnloaded;
        }

        private async void OnPageLoaded(object sender, RoutedEventArgs e)
        {
            UserProfile profile = UserProfileService.LoadProfile();
            if (!string.IsNullOrWhiteSpace(profile.WorkspaceRoot))
            {
                workspaceRoot = profile.WorkspaceRoot;
            }

            TxtWorkspacePath.Text = workspaceRoot;
            await RefreshDashboard();

            // Initialise customizable layout
            _currentLayout = DashboardLayoutService.LoadLayout();
            ApplyDashboardLayout();

            // Initialise Spotlight and Active Transcodes
            LoadSpotlightProjects();
            LoadActiveTranscodes();

            // Initialise tip widget with a random starting tip
            _tipIndex = new Random().Next(0, _tips.Length);
            ShowCurrentTip();

            // Initialise Team Board with 30-second polling
            InitTeamBoard();

            // Initialise Live Studio Tasks stream & ticker
            InitLiveTasks();

            // Initialise periodic 60-second background auto-scan for live NAS updates
            InitAutoScanTimer();

            WorkspaceWatcherService.Instance.WorkspaceChanged += OnWorkspaceChanged;
        }

        private void OnWorkspaceChanged(object sender, WorkspaceChangedEventArgs e)
        {
            Dispatcher.Invoke(async delegate
            {
                try
                {
                    await RefreshDashboard(force: true);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[DashboardPage] WorkspaceChanged refresh error: " + ex.Message);
                }
            });
        }

        private void OnScrollViewerPreviewMouseWheel(object sender, System.Windows.Input.MouseWheelEventArgs e)
        {
            var scroller = sender as ScrollViewer;
            if (scroller != null)
            {
                int steps = Math.Abs(e.Delta) / 30;
                if (steps < 1) steps = 1;
                if (steps > 8) steps = 8;

                if (e.Delta < 0)
                {
                    for (int i = 0; i < steps; i++) scroller.LineDown();
                }
                else if (e.Delta > 0)
                {
                    for (int i = 0; i < steps; i++) scroller.LineUp();
                }
                e.Handled = true;
            }
        }

        private void OnPageUnloaded(object sender, RoutedEventArgs e)
        {
            WorkspaceWatcherService.Instance.WorkspaceChanged -= OnWorkspaceChanged;
            if (_tipTimer != null)
            {
                _tipTimer.Stop();
                _tipTimer = null;
            }
            StopAutoScanTimer();
            StopTeamBoard();
            StopLiveTasks();
        }

        private void OnQuickNewProjectClicked(object sender, RoutedEventArgs e)
        {
            MainWindow mainWin = Application.Current != null ? Application.Current.MainWindow as MainWindow : null;
            if (mainWin != null) mainWin.NavigateTo(typeof(ProjectCreatorPage));
        }

        private void OnQuickCatalogClicked(object sender, RoutedEventArgs e)
        {
            MainWindow mainWin = Application.Current != null ? Application.Current.MainWindow as MainWindow : null;
            if (mainWin != null) mainWin.NavigateTo(typeof(SearchCopyPage));
        }

        private async void OnRefreshClicked(object sender, RoutedEventArgs e)
        {
            await RefreshDashboard(force: true);
        }

        private void OnVersionBadgeClicked(object sender, MouseButtonEventArgs e)
        {
            try
            {
                var aboutWin = new AboutWindow();
                aboutWin.Owner = Window.GetWindow(this);
                aboutWin.ShowDialog();
                e.Handled = true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] OnVersionBadgeClicked: " + ex.Message);
            }
        }

        private async System.Threading.Tasks.Task RefreshDashboard(bool force = false)
        {
            TxtStatus.Text = force ? "Rescanning workspace folders..." : "Scanning workspace folders...";

            DashboardSnapshot snapshot = await WorkspaceScanner.ScanAsync(workspaceRoot, force);

            MetricTotalProjects.Text = snapshot.TotalProjects.ToString();
            
            if (snapshot.RecentProjects != null && snapshot.RecentProjects.Count > 0)
            {
                var latest = snapshot.RecentProjects[0];
                TimeSpan diff = DateTime.Now - new DateTime(latest.ModifiedTicks);
                if (diff.TotalDays < 1) MetricLatestProject.Text = "Today";
                else if (diff.TotalDays < 2) MetricLatestProject.Text = "Yesterday";
                else MetricLatestProject.Text = string.Format("{0} days ago", (int)diff.TotalDays);
                
                MetricLatestProjectSubtext.Text = string.IsNullOrWhiteSpace(latest.Project) ? "Unknown" : latest.Project;
            }
            else
            {
                MetricLatestProject.Text = "-";
                MetricLatestProjectSubtext.Text = "None";
            }
            MetricFileSize.Text = snapshot.FormattedTotalSize;
            MetricThisMonth.Text = snapshot.ThisMonth.ToString();
            MetricMonthComparison.Text = snapshot.MonthComparisonText;
            MetricMonthComparison.Foreground = new System.Windows.Media.SolidColorBrush(
                (System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(snapshot.MonthComparisonColor));

            MetricLargestProjectName.Text = snapshot.LargestProjectName;
            MetricLargestProjectSize.Text = snapshot.LargestProjectSize;
            MetricStaleProjects.Text = snapshot.StaleProjects.ToString();

            Recent6ProjectsControl.ItemsSource = snapshot.RecentProjects;
            MetricActiveWIP.Text = snapshot.ActiveWipProjects.ToString();

            // Charts
            TypeChartControl.ItemsSource = snapshot.TypeChart;
            BrandChartControl.ItemsSource = snapshot.BrandChart;
            StorageChartControl.ItemsSource = snapshot.StorageChart;
            ActivityChartControl.ItemsSource = snapshot.ActivityChart;

            // Flow
            FlowDesignerCount.Text = string.Format("{0} Designers, {1} Projects", snapshot.DesignerCount, snapshot.TotalProjects);
            FlowFileCount.Text = string.Format("{0} files indexed", snapshot.TotalFiles);

            // Designer Workload & Capacity Radar
            if (DesignerWorkloadControl != null)
            {
                DesignerWorkloadControl.ItemsSource = snapshot.DesignerWorkloads;
            }

            // Creative SLA Analytics
            if (snapshot.SlaMetrics != null)
            {
                if (TxtSlaFirstTimeRight != null)
                    TxtSlaFirstTimeRight.Text = string.Format("{0:0.0}%", snapshot.SlaMetrics.FirstTimeRightPercent);
                if (TxtSlaAvgTurnaround != null)
                    TxtSlaAvgTurnaround.Text = string.Format("{0:0.0} Days", snapshot.SlaMetrics.AvgTurnaroundDays);
                if (TxtSlaAvgRevs != null)
                    TxtSlaAvgRevs.Text = string.Format("{0:0.0} Revs", snapshot.SlaMetrics.AvgRevisionsPerProject);
            }
 
            LoadSpotlightProjects();
            LoadActiveTranscodes();

            TxtStatus.Text = string.Format("Scan complete at {0:HH:mm:ss}. Connected to Synology Workspace.", DateTime.Now);
        }

        // ─────────────────────────────────────────────────────────────────────
        // Designer Inspiration Widget
        // ─────────────────────────────────────────────────────────────────────

        private void ShowCurrentTip()
        {
            DesignTip tip = _tips[_tipIndex];
            TxtTipTitle.Text = tip.Title;
            TxtTipBody.Text = tip.Body;
            TxtTipCounter.Text = string.Format("{0} / {1}", _tipIndex + 1, _tips.Length);
        }

        private void AdvanceTip()
        {
            _tipIndex = (_tipIndex + 1) % _tips.Length;
            ShowCurrentTip();
        }

        private void OnNextTipClicked(object sender, RoutedEventArgs e)
        {
            AdvanceTip();
        }

        // ─── Team Board ───────────────────────────────────────────────────────

        private DispatcherTimer _teamPollTimer;

        private void InitTeamBoard()
        {
            LoadTeamBoard();
            _teamPollTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(30) };
            _teamPollTimer.Tick += delegate { LoadTeamBoard(); };
            _teamPollTimer.Start();
        }

        private void StopTeamBoard()
        {
            if (_teamPollTimer != null) { _teamPollTimer.Stop(); _teamPollTimer = null; }
        }

        private void LoadTeamBoard()
        {
            try
            {
                System.Collections.Generic.List<TeamNote> notes = TeamBoardService.LoadNotes(workspaceRoot);
                // Show max 10
                if (notes.Count > 10) notes = notes.GetRange(0, 10);
                TeamNoteFeed.ItemsSource = notes;
                TxtTeamBoardStatus.Text = string.Format("Last updated {0}", DateTime.Now.ToString("HH:mm"));
            }
            catch
            {
                TxtTeamBoardStatus.Text = "Could not load team notes";
            }
        }

        private void OnPostTeamNoteClicked(object sender, RoutedEventArgs e)
        {
            string content = NewTeamNoteInput.Text.Trim();
            if (string.IsNullOrWhiteSpace(content)) return;

            UserProfile profile = UserProfileService.LoadProfile();
            string staffId = !string.IsNullOrWhiteSpace(profile.StaffId) ? profile.StaffId : "----";
            string name = !string.IsNullOrWhiteSpace(profile.DesignerName) ? profile.DesignerName : "Designer";

            bool ok = TeamBoardService.PostNote(workspaceRoot, staffId, name, content);
            if (ok)
            {
                NewTeamNoteInput.Text = "";
                LoadTeamBoard();
            }
            else
            {
                TxtTeamBoardStatus.Text = "Could not post note. Check NAS connection.";
            }
        }

        private void OnPinNoteClicked(object sender, RoutedEventArgs e)
        {
            Button btn = sender as Button;
            if (btn == null) return;
            string id = btn.Tag as string;
            if (string.IsNullOrWhiteSpace(id)) return;
            TeamBoardService.TogglePin(workspaceRoot, id);
            LoadTeamBoard();
        }

        private void OnDeleteTeamNoteClicked(object sender, RoutedEventArgs e)
        {
            Button btn = sender as Button;
            if (btn == null) return;
            string id = btn.Tag as string;
            if (string.IsNullOrWhiteSpace(id)) return;
            TeamBoardService.DeleteNote(workspaceRoot, id);
            LoadTeamBoard();
        }

        // ─── Live Tasks Stream (Real-Time Work Telemetry) ────────────────────

        private void InitLiveTasks()
        {
            LiveTaskSyncService.Instance.LiveTasksChanged += OnLiveTasksSyncChanged;
            LoadLiveTasks();

            if (_liveTasksTickerTimer == null)
            {
                _liveTasksTickerTimer = new DispatcherTimer();
                _liveTasksTickerTimer.Interval = TimeSpan.FromSeconds(1);
                _liveTasksTickerTimer.Tick += OnLiveTasksTickerTick;
                _liveTasksTickerTimer.Start();
            }
        }

        private void StopLiveTasks()
        {
            LiveTaskSyncService.Instance.LiveTasksChanged -= OnLiveTasksSyncChanged;
            if (_liveTasksTickerTimer != null)
            {
                _liveTasksTickerTimer.Stop();
                _liveTasksTickerTimer = null;
            }
        }

        private void OnLiveTasksSyncChanged(object sender, EventArgs e)
        {
            Dispatcher.Invoke(new Action(delegate { LoadLiveTasks(); }));
        }

        private void OnLiveTasksTickerTick(object sender, EventArgs e)
        {
            if (_currentLiveTasks != null && _currentLiveTasks.Count > 0)
            {
                bool hasRunning = false;
                for (int i = 0; i < _currentLiveTasks.Count; i++)
                {
                    LiveTaskEntry task = _currentLiveTasks[i];
                    if (task.IsRunning)
                    {
                        task.ElapsedSeconds++;
                        hasRunning = true;
                    }
                }
                if (hasRunning && LiveTasksControl != null && LiveTasksControl.Items != null)
                {
                    LiveTasksControl.Items.Refresh();
                }
            }
        }

        private void OnLiveDesignerFilterChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_liveFilterUpdating) return;
            LoadLiveTasks();
        }

        private void LoadLiveTasks()
        {
            try
            {
                List<LiveTaskEntry> rawTasks = LiveTaskSyncService.Instance.GetLiveTasks();
                _currentLiveTasks = rawTasks != null ? new List<LiveTaskEntry>(rawTasks) : new List<LiveTaskEntry>();

                // Populate / update designer filter dropdown
                if (CmbLiveDesignerFilter != null && !_liveFilterUpdating)
                {
                    try
                    {
                        _liveFilterUpdating = true;
                        string previous = CmbLiveDesignerFilter.SelectedItem != null 
                            ? CmbLiveDesignerFilter.SelectedItem.ToString() 
                            : "All Designers";

                        CmbLiveDesignerFilter.Items.Clear();
                        CmbLiveDesignerFilter.Items.Add("All Designers");

                        HashSet<string> designerSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                        // 1. Designers from staff directory
                        if (!string.IsNullOrWhiteSpace(workspaceRoot))
                        {
                            var staff = WorkspaceScanner.GetDesignerFolders(workspaceRoot);
                            if (staff != null)
                            {
                                foreach (var s in staff)
                                {
                                    if (s != null && !string.IsNullOrWhiteSpace(s.Name) && designerSet.Add(s.Name.Trim()))
                                    {
                                        CmbLiveDesignerFilter.Items.Add(s.Name.Trim());
                                    }
                                }
                            }
                        }

                        // 2. Designers from active live tasks
                        if (_currentLiveTasks != null)
                        {
                            foreach (var t in _currentLiveTasks)
                            {
                                if (!string.IsNullOrWhiteSpace(t.DesignerName) && designerSet.Add(t.DesignerName.Trim()))
                                {
                                    CmbLiveDesignerFilter.Items.Add(t.DesignerName.Trim());
                                }
                            }
                        }

                        // Restore previous selection
                        int selIdx = 0;
                        for (int i = 0; i < CmbLiveDesignerFilter.Items.Count; i++)
                        {
                            if (string.Equals(CmbLiveDesignerFilter.Items[i].ToString(), previous, StringComparison.OrdinalIgnoreCase))
                            {
                                selIdx = i;
                                break;
                            }
                        }
                        CmbLiveDesignerFilter.SelectedIndex = selIdx;
                    }
                    finally
                    {
                        _liveFilterUpdating = false;
                    }
                }

                // Filter tasks by selected designer
                string selectedDesigner = "All Designers";
                if (CmbLiveDesignerFilter != null && CmbLiveDesignerFilter.SelectedItem != null)
                {
                    selectedDesigner = CmbLiveDesignerFilter.SelectedItem.ToString();
                }

                List<LiveTaskEntry> displayTasks = new List<LiveTaskEntry>();
                if (_currentLiveTasks != null)
                {
                    foreach (var t in _currentLiveTasks)
                    {
                        if (t == null) continue;
                        if (selectedDesigner != "All Designers" && !string.IsNullOrWhiteSpace(selectedDesigner))
                        {
                            bool match = false;
                            if (!string.IsNullOrWhiteSpace(t.DesignerName))
                            {
                                if (string.Equals(t.DesignerName, selectedDesigner, StringComparison.OrdinalIgnoreCase) ||
                                    t.DesignerName.IndexOf(selectedDesigner, StringComparison.OrdinalIgnoreCase) >= 0 ||
                                    selectedDesigner.IndexOf(t.DesignerName, StringComparison.OrdinalIgnoreCase) >= 0)
                                {
                                    match = true;
                                }
                            }
                            if (!match && !string.IsNullOrWhiteSpace(t.StaffId))
                            {
                                if (string.Equals(t.StaffId, selectedDesigner, StringComparison.OrdinalIgnoreCase))
                                {
                                    match = true;
                                }
                            }
                            if (!match) continue;
                        }
                        displayTasks.Add(t);
                    }
                }

                if (LiveTasksControl != null)
                {
                    LiveTasksControl.ItemsSource = displayTasks;
                }

                int activeCount = 0;
                for (int i = 0; i < displayTasks.Count; i++)
                {
                    if (displayTasks[i].IsRunning)
                    {
                        activeCount++;
                    }
                }

                if (TxtLiveActiveCount != null)
                {
                    TxtLiveActiveCount.Text = string.Format("{0} Active", activeCount);
                }

                if (PanelNoLiveTasks != null && LiveTasksControl != null)
                {
                    if (displayTasks.Count == 0)
                    {
                        PanelNoLiveTasks.Visibility = Visibility.Visible;
                        LiveTasksControl.Visibility = Visibility.Collapsed;
                    }
                    else
                    {
                        PanelNoLiveTasks.Visibility = Visibility.Collapsed;
                        LiveTasksControl.Visibility = Visibility.Visible;
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] LoadLiveTasks: " + ex.Message);
            }
        }

        private void OnRefreshLiveTasksClicked(object sender, RoutedEventArgs e)
        {
            LiveTaskSyncService.Instance.RefreshLiveTasks();
            LoadLiveTasks();
        }

        private void OnLiveTaskOpenProjectClicked(object sender, RoutedEventArgs e)
        {
            FrameworkElement btn = sender as FrameworkElement;
            if (btn == null) return;
            string projectId = btn.Tag as string;
            if (string.IsNullOrWhiteSpace(projectId)) return;

            try
            {
                MainWindow mainWin = Application.Current != null ? Application.Current.MainWindow as MainWindow : null;
                if (mainWin != null)
                {
                    mainWin.NavigateTo(typeof(SearchCopyPage));
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] OnLiveTaskOpenProjectClicked: " + ex.Message);
            }
        }

        private DispatcherTimer _autoScanTimer;

        private void InitAutoScanTimer()
        {
            if (_autoScanTimer == null)
            {
                _autoScanTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(60) };
                _autoScanTimer.Tick += async delegate
                {
                    try
                    {
                        await RefreshDashboard(force: true);
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine("[DashboardPage] Auto-scan refresh warning: " + ex.Message);
                    }
                };
                _autoScanTimer.Start();
            }
        }

        private void StopAutoScanTimer()
        {
            if (_autoScanTimer != null)
            {
                _autoScanTimer.Stop();
                _autoScanTimer = null;
            }
        }

        private void OnRecentProjectCardClicked(object sender, MouseButtonEventArgs e)
        {
            try
            {
                FrameworkElement card = sender as FrameworkElement;
                DesignerFolderItem item = card != null ? card.DataContext as DesignerFolderItem : null;
                if (item != null && !string.IsNullOrWhiteSpace(item.FullPath))
                {
                    if (Directory.Exists(item.FullPath))
                    {
                        System.Diagnostics.Process.Start("explorer.exe", item.FullPath);
                    }
                    else
                    {
                        NotificationService.Show("Folder Missing", "Project folder cannot be found on the workspace.", NotificationType.Warning, 3000);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] OnRecentProjectCardClicked: " + ex.Message);
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Customizable Dashboard Layout Engine
        // ─────────────────────────────────────────────────────────────────────

        private Dictionary<string, FrameworkElement> GetWidgetCardsMap()
        {
            return new Dictionary<string, FrameworkElement>(StringComparer.OrdinalIgnoreCase)
            {
                { "kpis", CardWidget_Kpis },
                { "spotlight", CardWidget_Spotlight },
                { "transcodes", CardWidget_Transcodes },
                { "live_tasks", CardWidget_LiveTasks },
                { "recent_projects", CardWidget_RecentProjects },
                { "workload_radar", CardWidget_WorkloadRadar },
                { "sla_analytics", CardWidget_SlaAnalytics },
                { "designer_tip", CardWidget_DesignerTip },
                { "team_board", CardWidget_TeamBoard }
            };
        }

        private Dictionary<string, FrameworkElement> GetWidgetHeaderControlsMap()
        {
            return new Dictionary<string, FrameworkElement>(StringComparer.OrdinalIgnoreCase)
            {
                { "kpis", HeaderControls_Kpis },
                { "spotlight", HeaderControls_Spotlight },
                { "transcodes", HeaderControls_Transcodes },
                { "live_tasks", HeaderControls_LiveTasks },
                { "recent_projects", HeaderControls_RecentProjects },
                { "workload_radar", HeaderControls_WorkloadRadar },
                { "sla_analytics", HeaderControls_SlaAnalytics },
                { "designer_tip", HeaderControls_DesignerTip },
                { "team_board", HeaderControls_TeamBoard }
            };
        }

        private Dictionary<string, Wpf.Ui.Controls.SymbolIcon> GetWidgetPinIconsMap()
        {
            return new Dictionary<string, Wpf.Ui.Controls.SymbolIcon>(StringComparer.OrdinalIgnoreCase)
            {
                { "kpis", PinIcon_Kpis },
                { "spotlight", PinIcon_Spotlight },
                { "transcodes", PinIcon_Transcodes },
                { "live_tasks", PinIcon_LiveTasks },
                { "recent_projects", PinIcon_RecentProjects },
                { "workload_radar", PinIcon_WorkloadRadar },
                { "sla_analytics", PinIcon_SlaAnalytics },
                { "designer_tip", PinIcon_DesignerTip },
                { "team_board", PinIcon_TeamBoard }
            };
        }

        private void ApplyDashboardLayout()
        {
            if (_currentLayout == null || WidgetsContainer == null) return;

            try
            {
                var cardMap = GetWidgetCardsMap();
                var headerMap = GetWidgetHeaderControlsMap();
                var pinMap = GetWidgetPinIconsMap();

                // Sort configs: pinned widgets at the top, then by Order ascending
                var sorted = _currentLayout
                    .OrderByDescending(x => x.IsPinned)
                    .ThenBy(x => x.Order)
                    .ToList();

                // Update visual header customize controls & pin states
                foreach (var cfg in _currentLayout)
                {
                    FrameworkElement headerControls;
                    if (headerMap.TryGetValue(cfg.Id, out headerControls) && headerControls != null)
                    {
                        headerControls.Visibility = _isCustomizingLayout ? Visibility.Visible : Visibility.Collapsed;
                    }

                    Wpf.Ui.Controls.SymbolIcon pinIcon;
                    if (pinMap.TryGetValue(cfg.Id, out pinIcon) && pinIcon != null)
                    {
                        if (cfg.IsPinned)
                        {
                            pinIcon.Foreground = (Brush)FindResource("FluentBrand80");
                        }
                        else
                        {
                            pinIcon.ClearValue(Wpf.Ui.Controls.SymbolIcon.ForegroundProperty);
                        }
                    }

                    FrameworkElement card;
                    if (cardMap.TryGetValue(cfg.Id, out card) && card != null)
                    {
                        card.Visibility = cfg.IsVisible ? Visibility.Visible : Visibility.Collapsed;
                    }
                }

                // Reorder children in WidgetsContainer
                WidgetsContainer.Children.Clear();
                foreach (var cfg in sorted)
                {
                    FrameworkElement card;
                    if (cardMap.TryGetValue(cfg.Id, out card) && card != null)
                    {
                        WidgetsContainer.Children.Add(card);
                    }
                }

                // Update customization mode banner
                if (BannerCustomizeLayout != null)
                {
                    BannerCustomizeLayout.Visibility = _isCustomizingLayout ? Visibility.Visible : Visibility.Collapsed;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] ApplyDashboardLayout error: " + ex.Message);
            }
        }

        private void OnCustomizeLayoutClicked(object sender, RoutedEventArgs e)
        {
            _isCustomizingLayout = !_isCustomizingLayout;
            ApplyDashboardLayout();
        }

        private void OnDoneCustomizingClicked(object sender, RoutedEventArgs e)
        {
            _isCustomizingLayout = false;
            ApplyDashboardLayout();
        }

        private void OnResetLayoutClicked(object sender, RoutedEventArgs e)
        {
            _currentLayout = DashboardLayoutService.ResetToDefault();
            ApplyDashboardLayout();
            NotificationService.Show("Layout Reset", "Dashboard widgets restored to standard order.", NotificationType.Info, 2500);
        }

        private void OnPinWidgetClicked(object sender, RoutedEventArgs e)
        {
            FrameworkElement btn = sender as FrameworkElement;
            string widgetId = btn != null ? btn.Tag as string : null;
            if (string.IsNullOrEmpty(widgetId) || _currentLayout == null) return;

            var target = _currentLayout.FirstOrDefault(x => string.Equals(x.Id, widgetId, StringComparison.OrdinalIgnoreCase));
            if (target != null)
            {
                target.IsPinned = !target.IsPinned;
                var sorted = _currentLayout.OrderByDescending(x => x.IsPinned).ThenBy(x => x.Order).ToList();
                NormalizeWidgetOrders(sorted);
                DashboardLayoutService.SaveLayout(_currentLayout);
                ApplyDashboardLayout();

                string status = target.IsPinned ? "Pinned to top" : "Unpinned";
                NotificationService.Show(target.Title, status, NotificationType.Info, 1800);
            }
        }

        private void OnMoveWidgetUpClicked(object sender, RoutedEventArgs e)
        {
            FrameworkElement btn = sender as FrameworkElement;
            string widgetId = btn != null ? btn.Tag as string : null;
            if (string.IsNullOrEmpty(widgetId) || _currentLayout == null) return;

            var sorted = _currentLayout.OrderByDescending(x => x.IsPinned).ThenBy(x => x.Order).ToList();
            int idx = sorted.FindIndex(x => string.Equals(x.Id, widgetId, StringComparison.OrdinalIgnoreCase));
            if (idx > 0)
            {
                var current = sorted[idx];
                var previous = sorted[idx - 1];

                if (current.IsPinned != previous.IsPinned)
                {
                    current.IsPinned = previous.IsPinned;
                }

                int temp = current.Order;
                current.Order = previous.Order;
                previous.Order = temp;

                NormalizeWidgetOrders(sorted);
                DashboardLayoutService.SaveLayout(_currentLayout);
                ApplyDashboardLayout();
            }
        }

        private void OnMoveWidgetDownClicked(object sender, RoutedEventArgs e)
        {
            FrameworkElement btn = sender as FrameworkElement;
            string widgetId = btn != null ? btn.Tag as string : null;
            if (string.IsNullOrEmpty(widgetId) || _currentLayout == null) return;

            var sorted = _currentLayout.OrderByDescending(x => x.IsPinned).ThenBy(x => x.Order).ToList();
            int idx = sorted.FindIndex(x => string.Equals(x.Id, widgetId, StringComparison.OrdinalIgnoreCase));
            if (idx >= 0 && idx < sorted.Count - 1)
            {
                var current = sorted[idx];
                var next = sorted[idx + 1];

                if (current.IsPinned != next.IsPinned)
                {
                    current.IsPinned = next.IsPinned;
                }

                int temp = current.Order;
                current.Order = next.Order;
                next.Order = temp;

                NormalizeWidgetOrders(sorted);
                DashboardLayoutService.SaveLayout(_currentLayout);
                ApplyDashboardLayout();
            }
        }

        private void NormalizeWidgetOrders(List<DashboardWidgetConfig> list)
        {
            for (int i = 0; i < list.Count; i++)
            {
                list[i].Order = i + 1;
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // In-Flight Production Spotlight Widget
        // ─────────────────────────────────────────────────────────────────────

        private void LoadSpotlightProjects()
        {
            try
            {
                _allSpotlightItems.Clear();

                // 1. Check CreativeOrderService orders
                List<CreativeOrderItem> orders = null;
                try
                {
                    orders = CreativeOrderService.LoadOrders(workspaceRoot);
                }
                catch (Exception exOrders)
                {
                    System.Diagnostics.Debug.WriteLine("[DashboardPage] LoadSpotlightProjects orders: " + exOrders.Message);
                }

                if (orders != null && orders.Count > 0)
                {
                    foreach (var o in orders)
                    {
                        string st = (o.Status ?? "").ToLowerInvariant();
                        if (st == "in_progress" || st == "in_review" || st == "review" || st == "pending")
                        {
                            bool isReview = st.Contains("review");
                            _allSpotlightItems.Add(new DashboardSpotlightItem
                            {
                                JobId = string.IsNullOrWhiteSpace(o.Id) ? "ORD" : o.Id,
                                Title = string.IsNullOrWhiteSpace(o.Title) ? "Creative Deliverable" : o.Title,
                                StatusLabel = isReview ? "IN REVIEW" : "IN PRODUCTION",
                                StatusBrush = isReview 
                                    ? (Brush)FindResource("SystemFillColorCautionBrush") 
                                    : (Brush)FindResource("FluentBrand80"),
                                Designer = string.IsNullOrWhiteSpace(o.RequesterName) ? "Studio Designer" : o.RequesterName,
                                DeadlineDisplay = !string.IsNullOrWhiteSpace(o.Deadline) ? "Due " + o.Deadline : "Active",
                                ProjectPath = o.ProjectId
                            });
                        }
                    }
                }

                // 2. If fewer than 4 items, supplement from workspace folders
                if (_allSpotlightItems.Count < 4)
                {
                    try
                    {
                        var recent = WorkspaceScanner.ListDesignerFolders(workspaceRoot, "", "", 8);
                        if (recent != null)
                        {
                            foreach (var f in recent)
                            {
                                if (_allSpotlightItems.Count >= 6) break;
                                if (_allSpotlightItems.Any(x => string.Equals(x.JobId, f.Project, StringComparison.OrdinalIgnoreCase))) continue;

                                _allSpotlightItems.Add(new DashboardSpotlightItem
                                {
                                    JobId = f.Project,
                                    Title = f.Project,
                                    StatusLabel = "IN FLIGHT",
                                    StatusBrush = (Brush)FindResource("FluentBrand80"),
                                    Designer = string.IsNullOrWhiteSpace(f.Designer) ? "Team Member" : f.Designer,
                                    DeadlineDisplay = "Updated " + f.Modified,
                                    ProjectPath = f.FullPath
                                });
                            }
                        }
                    }
                    catch (Exception exScan)
                    {
                        System.Diagnostics.Debug.WriteLine("[DashboardPage] LoadSpotlightProjects folder scan: " + exScan.Message);
                    }
                }

                ApplySpotlightFilter();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] LoadSpotlightProjects error: " + ex.Message);
            }
        }

        private void ApplySpotlightFilter()
        {
            if (SpotlightProjectsControl == null) return;

            IEnumerable<DashboardSpotlightItem> filtered = _allSpotlightItems;

            if (string.Equals(_currentSpotlightFilter, "IN_PROD", StringComparison.OrdinalIgnoreCase))
            {
                filtered = _allSpotlightItems.Where(x => x.StatusLabel == "IN PRODUCTION" || x.StatusLabel == "IN FLIGHT");
            }
            else if (string.Equals(_currentSpotlightFilter, "REVIEW", StringComparison.OrdinalIgnoreCase))
            {
                filtered = _allSpotlightItems.Where(x => x.StatusLabel == "IN REVIEW");
            }

            var list = filtered.ToList();
            SpotlightProjectsControl.ItemsSource = list;

            if (TxtSpotlightActiveCount != null)
            {
                TxtSpotlightActiveCount.Text = string.Format("{0} In-Flight", list.Count);
            }

            if (PanelNoSpotlightProjects != null)
            {
                PanelNoSpotlightProjects.Visibility = list.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
            }

            UpdateSpotlightFilterButtonStyles();
        }

        private void UpdateSpotlightFilterButtonStyles()
        {
            if (BtnSpotlightFilterAll == null || BtnSpotlightFilterInProd == null || BtnSpotlightFilterReview == null) return;

            BtnSpotlightFilterAll.Appearance = _currentSpotlightFilter == "ALL" ? Wpf.Ui.Controls.ControlAppearance.Primary : Wpf.Ui.Controls.ControlAppearance.Secondary;
            BtnSpotlightFilterInProd.Appearance = _currentSpotlightFilter == "IN_PROD" ? Wpf.Ui.Controls.ControlAppearance.Primary : Wpf.Ui.Controls.ControlAppearance.Secondary;
            BtnSpotlightFilterReview.Appearance = _currentSpotlightFilter == "REVIEW" ? Wpf.Ui.Controls.ControlAppearance.Primary : Wpf.Ui.Controls.ControlAppearance.Secondary;
        }

        private void OnSpotlightFilterAllClicked(object sender, RoutedEventArgs e)
        {
            _currentSpotlightFilter = "ALL";
            ApplySpotlightFilter();
        }

        private void OnSpotlightFilterInProdClicked(object sender, RoutedEventArgs e)
        {
            _currentSpotlightFilter = "IN_PROD";
            ApplySpotlightFilter();
        }

        private void OnSpotlightFilterReviewClicked(object sender, RoutedEventArgs e)
        {
            _currentSpotlightFilter = "REVIEW";
            ApplySpotlightFilter();
        }

        private void OnSpotlightOpenProjectClicked(object sender, RoutedEventArgs e)
        {
            FrameworkElement btn = sender as FrameworkElement;
            string pathOrId = btn != null ? btn.Tag as string : null;
            if (string.IsNullOrWhiteSpace(pathOrId)) return;

            try
            {
                if (Directory.Exists(pathOrId))
                {
                    System.Diagnostics.Process.Start("explorer.exe", pathOrId);
                }
                else
                {
                    MainWindow mainWin = Application.Current != null ? Application.Current.MainWindow as MainWindow : null;
                    if (mainWin != null) mainWin.NavigateTo(typeof(SearchCopyPage));
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] OnSpotlightOpenProjectClicked error: " + ex.Message);
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Active Transcodes Widget
        // ─────────────────────────────────────────────────────────────────────

        private void LoadActiveTranscodes()
        {
            if (ActiveTranscodesControl == null) return;

            try
            {
                var sharedJobs = TranscoderBridgePage.SharedJobs;
                var displayList = new List<DashboardTranscodeDisplayItem>();

                if (sharedJobs != null && sharedJobs.Count > 0)
                {
                    foreach (var j in sharedJobs)
                    {
                        displayList.Add(new DashboardTranscodeDisplayItem
                        {
                            SourceFileName = string.IsNullOrWhiteSpace(j.FileName) ? "Asset Transcode" : j.FileName,
                            PresetDisplay = string.IsNullOrWhiteSpace(j.PresetName) ? "Web Preset" : j.PresetName,
                            StatusText = !string.IsNullOrWhiteSpace(j.StatusMessage) ? j.StatusMessage : j.Status.ToString(),
                            ProgressPercent = j.ProgressPercent,
                            ProgressPercentDisplay = string.Format("{0}%", j.ProgressPercent),
                            OutputFilePath = j.OutputFilePath
                        });
                    }
                }

                ActiveTranscodesControl.ItemsSource = displayList;

                if (PanelNoTranscodeJobs != null)
                {
                    PanelNoTranscodeJobs.Visibility = displayList.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] LoadActiveTranscodes error: " + ex.Message);
            }
        }

        private void OnOpenTranscoderBridgeClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                MainWindow mainWin = Application.Current != null ? Application.Current.MainWindow as MainWindow : null;
                if (mainWin != null)
                {
                    mainWin.NavigateTo(typeof(TranscoderBridgePage));
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] OnOpenTranscoderBridgeClicked: " + ex.Message);
            }
        }

        private void OnOpenTranscodeOutputClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                FrameworkElement btn = sender as FrameworkElement;
                string outputPath = btn != null ? btn.Tag as string : null;
                if (!string.IsNullOrEmpty(outputPath) && File.Exists(outputPath))
                {
                    System.Diagnostics.Process.Start("explorer.exe", string.Format("/select,\"{0}\"", outputPath));
                }
                else if (!string.IsNullOrEmpty(outputPath) && Directory.Exists(Path.GetDirectoryName(outputPath)))
                {
                    System.Diagnostics.Process.Start("explorer.exe", Path.GetDirectoryName(outputPath));
                }
                else
                {
                    NotificationService.Show("Output Pending", "Transcoded file is currently in processing queue.", NotificationType.Info, 2500);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[DashboardPage] OnOpenTranscodeOutputClicked error: " + ex.Message);
            }
        }
    }
}
