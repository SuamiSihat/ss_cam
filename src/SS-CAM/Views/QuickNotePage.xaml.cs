using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Navigation;
using System.Windows.Threading;
using Microsoft.Win32;
using SS_CAM.Services;
using SS_CAM.Utilities;

namespace SS_CAM.Views
{
    public partial class QuickNotePage : Page
    {
        private List<QuickNoteItem> _notes = new List<QuickNoteItem>();
        private QuickNoteItem _currentNote = null;
        private DispatcherTimer _autoSaveTimer;
        private bool _isLoading = false;
        private int _activeFilter = 0; // 0 = All, 1 = Pinned, 2 = High, 3 = Tasks, 4 = Ideas, 5 = Briefs
        private int _currentViewMode = 0; // 0 = Split, 1 = Edit, 2 = Preview
        private int _currentSortIndex = 0; // 0 = Recently Edited, 1 = Date Created, 2 = Title A-Z, 3 = Priority
        private bool _isZenMode = false;
        private double _previousSidebarWidth = 300;

        public QuickNotePage()
        {
            InitializeComponent();
            Loaded += OnPageLoaded;
            Unloaded += OnPageUnloaded;
        }

        private async void OnPageLoaded(object sender, RoutedEventArgs e)
        {
            try
            {
                UpdateFilterButtonStyles();
                SetupAutoSaveTimer();
                RefreshNoteList();

                await QuickNoteService.SyncWithWebPortalAsync();
                RefreshNoteList();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[QuickNotePage] OnPageLoaded error: " + ex.Message);
            }
        }

        private void OnPageUnloaded(object sender, RoutedEventArgs e)
        {
            try
            {
                if (_autoSaveTimer != null) { _autoSaveTimer.Stop(); _autoSaveTimer = null; }
                SaveCurrentNote();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[QuickNotePage] OnPageUnloaded error: " + ex.Message);
            }
        }

        private void SetupAutoSaveTimer()
        {
            _autoSaveTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2.5) };
            _autoSaveTimer.Tick += delegate { DoAutoSave(); };
        }

        private void RefreshNoteList()
        {
            _notes = QuickNoteService.ListNotes();
            ApplyNoteFilter();
        }

        private void OnNewNoteClicked(object sender, RoutedEventArgs e)
        {
            SaveCurrentNote();
            string path = QuickNoteService.CreateNote();
            _notes = QuickNoteService.ListNotes();
            ApplyNoteFilter();

            // Select the new note (first in list)
            if (_notes.Count > 0)
            {
                NotesList.SelectedIndex = 0;
            }
        }

        private void CreateNoteWithTemplate(string defaultTitle, string templateContent, string icon, string category)
        {
            SaveCurrentNote();
            string path = QuickNoteService.CreateNote(defaultTitle, templateContent, icon, category);
            RefreshNoteListAndKeepSelection(path);
        }

        private void OnQuickCardBriefClicked(object sender, MouseButtonEventArgs e)
        {
            CreateNoteWithTemplate("Creative Brief", QuickNoteService.GetTemplateCreativeBrief(), "📋", "Brief");
        }

        private void OnQuickCardMeetingClicked(object sender, MouseButtonEventArgs e)
        {
            CreateNoteWithTemplate("Meeting Sync", QuickNoteService.GetTemplateMeetingMinutes(), "💬", "Meeting");
        }

        private void OnQuickCardAdHookClicked(object sender, MouseButtonEventArgs e)
        {
            CreateNoteWithTemplate("3-Hook Ad Matrix", QuickNoteService.GetTemplateAdCopyHookMatrix(), "⚡", "Copywriting");
        }

        private void OnQuickCardMindDropClicked(object sender, MouseButtonEventArgs e)
        {
            CreateNoteWithTemplate("Mind Drop", QuickNoteService.GetTemplateMindDrop(), "💡", "Idea");
        }

        private void OnNoteSelected(object sender, SelectionChangedEventArgs e)
        {
            if (_isLoading) return;
            SaveCurrentNote();

            QuickNoteItem selected = NotesList.SelectedItem as QuickNoteItem;
            if (selected == null)
            {
                _currentNote = null;
                PanelEmptyState.Visibility = Visibility.Visible;
                PanelActiveWorkspace.Visibility = Visibility.Collapsed;
                PanelPageHeader.Visibility = Visibility.Collapsed;
                PanelMarkdownToolbar.Visibility = Visibility.Collapsed;
                TxtWordCount.Text = "0 words";
                TxtCharCount.Text = "0 characters";
                TxtTaskStats.Visibility = Visibility.Collapsed;
                return;
            }

            _currentNote = selected;
            _isLoading = true;

            // Load icon & title into Notion Page Header
            TxtPageIcon.Text = !string.IsNullOrEmpty(selected.Icon) ? selected.Icon : "📝";
            TxtNoteTitle.Text = selected.Title ?? "Untitled Note";

            // Load clean text WITHOUT raw YAML frontmatter
            NoteEditor.Text = QuickNoteService.StripFrontmatter(selected.Content);

            // Setup Pin Button
            BtnTogglePin.ToolTip = selected.IsPinned ? "Unpin note from top" : "Pin note to top";
            BtnTogglePin.Appearance = selected.IsPinned ? Wpf.Ui.Controls.ControlAppearance.Primary : Wpf.Ui.Controls.ControlAppearance.Secondary;

            // Select Priority Combobox
            CmbPriority.SelectedIndex = (int)selected.Priority;

            // Select Category Combobox
            SelectCategoryInComboBox(selected.Category);

            // Metrics & Timestamps
            TxtLastEditedInfo.Text = "Edited " + (!string.IsNullOrEmpty(selected.ModifiedDisplay) ? selected.ModifiedDisplay : "recently");
            TxtReadingTime.Text = selected.ReadingTimeDisplay;
            TxtSavedStatus.Text = "Saved ✓";

            _isLoading = false;

            PanelEmptyState.Visibility = Visibility.Collapsed;
            PanelActiveWorkspace.Visibility = Visibility.Visible;
            PanelPageHeader.Visibility = Visibility.Visible;
            PanelMarkdownToolbar.Visibility = Visibility.Visible;

            UpdateTelemetry();
            ApplyViewMode(_currentViewMode);
        }

        private void SelectCategoryInComboBox(string category)
        {
            if (CmbCategory == null) return;
            if (string.IsNullOrWhiteSpace(category)) category = "General";

            for (int i = 0; i < CmbCategory.Items.Count; i++)
            {
                ComboBoxItem item = CmbCategory.Items[i] as ComboBoxItem;
                if (item != null && string.Equals(item.Content as string, category, StringComparison.OrdinalIgnoreCase))
                {
                    CmbCategory.SelectedIndex = i;
                    return;
                }
            }
            CmbCategory.SelectedIndex = 0;
        }

        private void OnTogglePinClicked(object sender, RoutedEventArgs e)
        {
            if (_currentNote == null) return;
            _currentNote.IsPinned = !_currentNote.IsPinned;
            BtnTogglePin.ToolTip = _currentNote.IsPinned ? "Unpin note from top" : "Pin note to top";
            BtnTogglePin.Appearance = _currentNote.IsPinned ? Wpf.Ui.Controls.ControlAppearance.Primary : Wpf.Ui.Controls.ControlAppearance.Secondary;
            SaveCurrentNote();
            RefreshNoteListAndKeepSelection(_currentNote.FilePath);
        }

        private void OnToggleZenClicked(object sender, RoutedEventArgs e)
        {
            _isZenMode = !_isZenMode;
            if (_isZenMode)
            {
                if (ColSidebar.Width.Value > 0) _previousSidebarWidth = ColSidebar.Width.Value;
                ColSidebar.Width = new GridLength(0);
                ColMainSplitter.Width = new GridLength(0);
                MainPaneSplitter.Visibility = Visibility.Collapsed;
                BtnToggleZen.Appearance = Wpf.Ui.Controls.ControlAppearance.Primary;
                BtnToggleZen.ToolTip = "Exit Focus Mode (Show Sidebar)";
            }
            else
            {
                ColSidebar.Width = new GridLength(_previousSidebarWidth > 0 ? _previousSidebarWidth : 300);
                ColMainSplitter.Width = new GridLength(14);
                MainPaneSplitter.Visibility = Visibility.Visible;
                BtnToggleZen.Appearance = Wpf.Ui.Controls.ControlAppearance.Secondary;
                BtnToggleZen.ToolTip = "Toggle Distraction-Free Focus Mode";
            }
        }

        private void OnPageIconClicked(object sender, RoutedEventArgs e)
        {
            if (MenuIconPicker != null)
            {
                MenuIconPicker.PlacementTarget = BtnPageIcon;
                MenuIconPicker.IsOpen = true;
            }
        }

        private void OnSelectIconOption(object sender, RoutedEventArgs e)
        {
            if (_currentNote == null) return;
            MenuItem item = sender as MenuItem;
            if (item != null && item.Tag != null)
            {
                string icon = item.Tag.ToString();
                _currentNote.Icon = icon;
                TxtPageIcon.Text = icon;
                DoAutoSave();
            }
        }

        private void OnNoteTitleChanged(object sender, TextChangedEventArgs e)
        {
            if (_isLoading || _currentNote == null) return;
            _currentNote.Title = TxtNoteTitle.Text;
            TxtSavedStatus.Text = "Unsaved...";
            if (_autoSaveTimer != null) { _autoSaveTimer.Stop(); _autoSaveTimer.Start(); }
        }

        private void OnCategoryChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_isLoading || _currentNote == null) return;
            ComboBoxItem item = CmbCategory.SelectedItem as ComboBoxItem;
            if (item != null)
            {
                string newCategory = item.Content as string;
                if (!string.Equals(_currentNote.Category, newCategory, StringComparison.OrdinalIgnoreCase))
                {
                    _currentNote.Category = newCategory;

                    // Automatically assign a thematic emoji if note has standard document icon
                    if (string.IsNullOrEmpty(_currentNote.Icon) || _currentNote.Icon == "📝")
                    {
                        if (newCategory == "Brief") _currentNote.Icon = "📋";
                        else if (newCategory == "Idea") _currentNote.Icon = "💡";
                        else if (newCategory == "Meeting") _currentNote.Icon = "💬";
                        else if (newCategory == "Tasks") _currentNote.Icon = "🎯";
                        else if (newCategory == "Copywriting") _currentNote.Icon = "⚡";
                        else if (newCategory == "Feedback") _currentNote.Icon = "📋";

                        TxtPageIcon.Text = _currentNote.Icon;
                    }

                    SaveCurrentNote();
                    RefreshNoteListAndKeepSelection(_currentNote.FilePath);
                }
            }
        }

        private void OnPriorityChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_isLoading || _currentNote == null) return;
            int idx = CmbPriority.SelectedIndex;
            if (idx < 0) return;
            NotePriority newPriority = (NotePriority)idx;
            if (_currentNote.Priority == newPriority) return;
            _currentNote.Priority = newPriority;
            SaveCurrentNote();
            RefreshNoteListAndKeepSelection(_currentNote.FilePath);
        }

        private void RefreshNoteListAndKeepSelection(string targetFilePath)
        {
            _isLoading = true;
            _notes = QuickNoteService.ListNotes();
            ApplyNoteFilter();

            if (!string.IsNullOrEmpty(targetFilePath))
            {
                QuickNoteItem found = _notes.Find(delegate(QuickNoteItem n) { return n.FilePath == targetFilePath; });
                if (found != null)
                {
                    NotesList.SelectedItem = found;
                    _currentNote = found;
                    BtnTogglePin.ToolTip = found.IsPinned ? "Unpin note from top" : "Pin note to top";
                    BtnTogglePin.Appearance = found.IsPinned ? Wpf.Ui.Controls.ControlAppearance.Primary : Wpf.Ui.Controls.ControlAppearance.Secondary;
                    CmbPriority.SelectedIndex = (int)found.Priority;
                    SelectCategoryInComboBox(found.Category);
                    TxtPageIcon.Text = !string.IsNullOrEmpty(found.Icon) ? found.Icon : "📝";
                }
            }
            _isLoading = false;
        }

        private void OnNoteEditorChanged(object sender, TextChangedEventArgs e)
        {
            if (_isLoading || _currentNote == null) return;
            TxtSavedStatus.Text = "Unsaved...";
            UpdateTelemetry();
            if (_currentViewMode == 0 || _currentViewMode == 2)
            {
                UpdateLivePreview();
            }
            if (_autoSaveTimer != null) { _autoSaveTimer.Stop(); _autoSaveTimer.Start(); }
        }

        private void DoAutoSave()
        {
            if (_autoSaveTimer != null) _autoSaveTimer.Stop();
            SaveCurrentNote();
            TxtSavedStatus.Text = "Saved ✓";

            if (_currentNote != null)
            {
                // Synchronize inline title if empty
                if (string.IsNullOrWhiteSpace(TxtNoteTitle.Text) || TxtNoteTitle.Text == "Untitled Note")
                {
                    string extracted = QuickNoteService.ExtractTitle(NoteEditor.Text, _currentNote.Title);
                    if (!string.IsNullOrWhiteSpace(extracted))
                    {
                        _currentNote.Title = extracted;
                        _isLoading = true;
                        TxtNoteTitle.Text = extracted;
                        _isLoading = false;
                    }
                }
                else
                {
                    _currentNote.Title = TxtNoteTitle.Text;
                }

                _currentNote.ModifiedDisplay = "Today, " + DateTime.Now.ToString("HH:mm");
                TxtLastEditedInfo.Text = "Edited " + _currentNote.ModifiedDisplay;
                TxtReadingTime.Text = _currentNote.ReadingTimeDisplay;
                ApplyNoteFilter();
            }
        }

        private void SaveCurrentNote()
        {
            if (_currentNote == null) return;

            string title = !string.IsNullOrWhiteSpace(TxtNoteTitle.Text) ? TxtNoteTitle.Text : _currentNote.Title;
            _currentNote.Title = title;
            _currentNote.Content = NoteEditor.Text;

            QuickNoteService.SaveNote(
                _currentNote.FilePath,
                NoteEditor.Text,
                _currentNote.IsPinned,
                _currentNote.Priority,
                _currentNote.Icon,
                _currentNote.Category);

            _currentNote.Snippet = QuickNoteService.ExtractSnippet(NoteEditor.Text, _currentNote.Title);
            int comp, tot;
            QuickNoteService.ExtractTaskStats(NoteEditor.Text, out comp, out tot);
            _currentNote.CompletedTasks = comp;
            _currentNote.TotalTasks = tot;
        }

        private void OnDeleteNoteClicked(object sender, RoutedEventArgs e)
        {
            if (_currentNote == null) return;
            MessageBoxResult result = MessageBox.Show(
                string.Format("Delete \"{0}\"? This cannot be undone.", _currentNote.Title),
                "Delete Note", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (result != MessageBoxResult.Yes) return;

            QuickNoteService.DeleteNote(_currentNote.FilePath);
            _currentNote = null;
            RefreshNoteList();

            PanelEmptyState.Visibility = Visibility.Visible;
            PanelActiveWorkspace.Visibility = Visibility.Collapsed;
            PanelPageHeader.Visibility = Visibility.Collapsed;
            PanelMarkdownToolbar.Visibility = Visibility.Collapsed;
        }

        // ─── Search & Sidebar Filtering ──────────────────────────────────────

        private void OnSearchNotesChanged(object sender, TextChangedEventArgs e)
        {
            if (BtnClearSearch != null)
            {
                BtnClearSearch.Visibility = (TxtSearchNotes != null && !string.IsNullOrEmpty(TxtSearchNotes.Text))
                    ? Visibility.Visible
                    : Visibility.Collapsed;
            }
            ApplyNoteFilter();
        }

        private void OnClearSearchClicked(object sender, RoutedEventArgs e)
        {
            if (TxtSearchNotes != null)
            {
                TxtSearchNotes.Text = string.Empty;
            }
            if (BtnClearSearch != null)
            {
                BtnClearSearch.Visibility = Visibility.Collapsed;
            }
            ApplyNoteFilter();
        }

        private void OnFilterAllClicked(object sender, RoutedEventArgs e)
        {
            SetFilter(0);
        }

        private void OnFilterPinnedClicked(object sender, RoutedEventArgs e)
        {
            SetFilter(1);
        }

        private void OnFilterHighClicked(object sender, RoutedEventArgs e)
        {
            SetFilter(2);
        }

        private void OnFilterTasksClicked(object sender, RoutedEventArgs e)
        {
            SetFilter(3);
        }

        private void OnFilterIdeasClicked(object sender, RoutedEventArgs e)
        {
            SetFilter(4);
        }

        private void OnFilterBriefsClicked(object sender, RoutedEventArgs e)
        {
            SetFilter(5);
        }

        private void SetFilter(int filterIndex)
        {
            _activeFilter = filterIndex;
            UpdateFilterButtonStyles();
            ApplyNoteFilter();
        }

        private void OnSortChanged(object sender, SelectionChangedEventArgs e)
        {
            if (CmbSort != null)
            {
                _currentSortIndex = CmbSort.SelectedIndex;
                ApplyNoteFilter();
            }
        }

        private void UpdateFilterButtonStyles()
        {
            Brush brandBrush = null;
            try { brandBrush = FindResource("FluentBrand80") as Brush; }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNotePage] brandBrush: " + ex.Message); }
            if (brandBrush == null) brandBrush = new SolidColorBrush(Color.FromRgb(2, 132, 199)); // #0284C7 brand blue

            Brush inactiveBg = null;
            try { inactiveBg = FindResource("ControlFillColorSecondaryBrush") as Brush; }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNotePage] inactiveBg: " + ex.Message); }
            if (inactiveBg == null) inactiveBg = Brushes.Transparent;

            Brush inactiveFg = null;
            try { inactiveFg = FindResource("TextFillColorPrimaryBrush") as Brush; }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNotePage] inactiveFg: " + ex.Message); }
            if (inactiveFg == null) inactiveFg = Brushes.Black;

            Brush strokeBrush = null;
            try { strokeBrush = FindResource("CardStrokeColorDefaultBrush") as Brush; }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNotePage] strokeBrush: " + ex.Message); }
            if (strokeBrush == null) strokeBrush = new SolidColorBrush(Color.FromArgb(40, 0, 0, 0));

            ApplyChipStyle(BtnFilterAll, TxtFilterAll, null, _activeFilter == 0, brandBrush, Brushes.White, inactiveBg, inactiveFg, strokeBrush);
            ApplyChipStyle(BtnFilterPinned, TxtFilterPinned, IconFilterPinned, _activeFilter == 1, brandBrush, Brushes.White, inactiveBg, inactiveFg, strokeBrush);
            ApplyChipStyle(BtnFilterHigh, TxtFilterHigh, IconFilterHigh, _activeFilter == 2, brandBrush, Brushes.White, inactiveBg, inactiveFg, strokeBrush);
            ApplyChipStyle(BtnFilterTasks, TxtFilterTasks, IconFilterTasks, _activeFilter == 3, brandBrush, Brushes.White, inactiveBg, inactiveFg, strokeBrush);
            ApplyChipStyle(BtnFilterIdeas, TxtFilterIdeas, null, _activeFilter == 4, brandBrush, Brushes.White, inactiveBg, inactiveFg, strokeBrush);
            ApplyChipStyle(BtnFilterBriefs, TxtFilterBriefs, null, _activeFilter == 5, brandBrush, Brushes.White, inactiveBg, inactiveFg, strokeBrush);
        }

        private void ApplyChipStyle(Wpf.Ui.Controls.Button btn, Wpf.Ui.Controls.TextBlock label, Wpf.Ui.Controls.TextBlock icon, bool isActive,
            Brush activeBg, Brush activeFg, Brush inactiveBg, Brush inactiveFg, Brush border)
        {
            if (btn == null) return;
            btn.Background = isActive ? activeBg : inactiveBg;
            btn.BorderBrush = isActive ? activeBg : border;
            btn.BorderThickness = new Thickness(1);
            if (label != null)
            {
                label.Foreground = isActive ? activeFg : inactiveFg;
                label.FontWeight = isActive ? FontWeights.SemiBold : FontWeights.Normal;
            }
            if (icon != null)
            {
                icon.Foreground = isActive ? activeFg : inactiveFg;
            }
        }

        private void ApplyNoteFilter()
        {
            if (_notes == null) return;

            // Apply Sorting first
            _notes.Sort(delegate(QuickNoteItem a, QuickNoteItem b)
            {
                // Pinned notes always anchor to top unless user sorts by title specifically
                if (a.IsPinned != b.IsPinned)
                    return b.IsPinned.CompareTo(a.IsPinned);

                switch (_currentSortIndex)
                {
                    case 1: // Date Created (Creation ticks / filename)
                        return b.CreatedTicks.CompareTo(a.CreatedTicks);
                    case 2: // Title A-Z
                        return string.Compare(a.Title, b.Title, StringComparison.OrdinalIgnoreCase);
                    case 3: // Priority
                        int prioDiff = ((int)b.Priority).CompareTo((int)a.Priority);
                        if (prioDiff != 0) return prioDiff;
                        return b.ModifiedTicks.CompareTo(a.ModifiedTicks);
                    case 0: // Recently Edited (Default)
                    default:
                        return b.ModifiedTicks.CompareTo(a.ModifiedTicks);
                }
            });

            string query = (TxtSearchNotes != null && !string.IsNullOrWhiteSpace(TxtSearchNotes.Text))
                ? TxtSearchNotes.Text.Trim().ToLowerInvariant()
                : null;

            List<QuickNoteItem> filtered = _notes.FindAll(delegate(QuickNoteItem n)
            {
                // Filter chips check
                if (_activeFilter == 1 && !n.IsPinned) return false;
                if (_activeFilter == 2 && n.Priority != NotePriority.High) return false;
                if (_activeFilter == 3 && n.TotalTasks == 0) return false;
                if (_activeFilter == 4 && !(string.Equals(n.Category, "Idea", StringComparison.OrdinalIgnoreCase) || n.Icon == "💡")) return false;
                if (_activeFilter == 5 && !(string.Equals(n.Category, "Brief", StringComparison.OrdinalIgnoreCase) || n.Icon == "📋")) return false;

                // Search query check
                if (!string.IsNullOrEmpty(query))
                {
                    bool matchTitle = n.Title != null && n.Title.ToLowerInvariant().Contains(query);
                    bool matchBody = n.Content != null && n.Content.ToLowerInvariant().Contains(query);
                    bool matchCat = n.Category != null && n.Category.ToLowerInvariant().Contains(query);
                    if (!matchTitle && !matchBody && !matchCat) return false;
                }

                return true;
            });

            _isLoading = true;
            QuickNoteItem currentlySelected = _currentNote;
            NotesList.ItemsSource = null;
            NotesList.ItemsSource = filtered;

            if (currentlySelected != null)
            {
                QuickNoteItem found = filtered.Find(delegate(QuickNoteItem n) { return n.FilePath == currentlySelected.FilePath; });
                if (found != null) NotesList.SelectedItem = found;
            }

            TxtNoteCount.Text = string.Format("{0} note{1}", filtered.Count, filtered.Count == 1 ? "" : "s");
            _isLoading = false;
        }

        // ─── 3-Way Mode Switcher & Live Split View ────────────────────────────

        private void OnModeSplit(object sender, RoutedEventArgs e)
        {
            ApplyViewMode(0);
        }

        private void OnModeEdit(object sender, RoutedEventArgs e)
        {
            ApplyViewMode(1);
        }

        private void OnModePreview(object sender, RoutedEventArgs e)
        {
            ApplyViewMode(2);
        }

        private void ApplyViewMode(int mode)
        {
            _currentViewMode = mode;
            Brush brandBrush = FindResource("FluentBrand80") as Brush;
            Brush textBrush = FindResource("TextFillColorPrimaryBrush") as Brush;

            BtnModeSplit.Background = Brushes.Transparent;
            BtnModeSplit.Foreground = textBrush ?? Brushes.Black;
            BtnModeSplit.FontWeight = FontWeights.Normal;

            BtnModeEdit.Background = Brushes.Transparent;
            BtnModeEdit.Foreground = textBrush ?? Brushes.Black;
            BtnModeEdit.FontWeight = FontWeights.Normal;

            BtnModePreview.Background = Brushes.Transparent;
            BtnModePreview.Foreground = textBrush ?? Brushes.Black;
            BtnModePreview.FontWeight = FontWeights.Normal;

            if (mode == 0) // Split View (Side-by-Side)
            {
                BtnModeSplit.Background = brandBrush ?? Brushes.DodgerBlue;
                BtnModeSplit.Foreground = Brushes.White;
                BtnModeSplit.FontWeight = FontWeights.SemiBold;

                ColNoteEditor.Width = new GridLength(1, GridUnitType.Star);
                ColNoteSplitter.Width = new GridLength(6, GridUnitType.Pixel);
                ColNotePreview.Width = new GridLength(1, GridUnitType.Star);

                NoteEditor.Visibility = Visibility.Visible;
                NoteGridSplitter.Visibility = Visibility.Visible;
                NotePreviewViewer.Visibility = Visibility.Visible;

                UpdateLivePreview();
            }
            else if (mode == 1) // Edit Only
            {
                BtnModeEdit.Background = brandBrush ?? Brushes.DodgerBlue;
                BtnModeEdit.Foreground = Brushes.White;
                BtnModeEdit.FontWeight = FontWeights.SemiBold;

                ColNoteEditor.Width = new GridLength(1, GridUnitType.Star);
                ColNoteSplitter.Width = new GridLength(0, GridUnitType.Pixel);
                ColNotePreview.Width = new GridLength(0, GridUnitType.Pixel);

                NoteEditor.Visibility = Visibility.Visible;
                NoteGridSplitter.Visibility = Visibility.Collapsed;
                NotePreviewViewer.Visibility = Visibility.Collapsed;
            }
            else if (mode == 2) // Preview Only
            {
                BtnModePreview.Background = brandBrush ?? Brushes.DodgerBlue;
                BtnModePreview.Foreground = Brushes.White;
                BtnModePreview.FontWeight = FontWeights.SemiBold;

                ColNoteEditor.Width = new GridLength(0, GridUnitType.Pixel);
                ColNoteSplitter.Width = new GridLength(0, GridUnitType.Pixel);
                ColNotePreview.Width = new GridLength(1, GridUnitType.Star);

                NoteEditor.Visibility = Visibility.Collapsed;
                NoteGridSplitter.Visibility = Visibility.Collapsed;
                NotePreviewViewer.Visibility = Visibility.Visible;

                UpdateLivePreview();
            }
        }

        private void UpdateLivePreview()
        {
            if (_currentNote == null) return;
            string markdown = NoteEditor.Text ?? "";
            try
            {
                NotePreviewViewer.Document = MarkdownHelper.ToFlowDocument(markdown);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[QuickNotePage] Live preview render error: " + ex.Message);
            }
        }

        private void UpdateTelemetry()
        {
            string text = NoteEditor.Text ?? "";
            int chars = text.Length;

            int words = 0;
            string[] tokens = text.Split(new char[] { ' ', '\r', '\n', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            words = tokens.Length;

            int completed, total;
            QuickNoteService.ExtractTaskStats(text, out completed, out total);

            TxtWordCount.Text = string.Format("{0} word{1}", words, words == 1 ? "" : "s");
            TxtCharCount.Text = string.Format("{0} char{1}", chars, chars == 1 ? "" : "s");

            int minutes = Math.Max(1, (int)Math.Ceiling(words / 200.0));
            TxtReadingTime.Text = string.Format("{0} min read", minutes);

            if (total > 0)
            {
                TxtTaskStats.Text = string.Format("{0}/{1} tasks done", completed, total);
                TxtTaskStats.Visibility = Visibility.Visible;
            }
            else
            {
                TxtTaskStats.Visibility = Visibility.Collapsed;
            }
        }

        // ─── Starter Templates ───────────────────────────────────────────────

        private void OnTemplatesButtonClicked(object sender, RoutedEventArgs e)
        {
            if (BtnTemplates != null && BtnTemplates.ContextMenu != null)
            {
                BtnTemplates.ContextMenu.PlacementTarget = BtnTemplates;
                BtnTemplates.ContextMenu.IsOpen = true;
            }
        }

        private void OnTemplateBriefClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText(QuickNoteService.GetTemplateCreativeBrief());
        }

        private void OnTemplateMeetingClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText(QuickNoteService.GetTemplateMeetingMinutes());
        }

        private void OnTemplateTikTokClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText(QuickNoteService.GetTemplateAdCopyHookMatrix());
        }

        private void OnTemplateMindDropClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText(QuickNoteService.GetTemplateMindDrop());
        }

        private void OnTemplateTaskSprintClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText(QuickNoteService.GetTemplateTaskSprint());
        }

        private void OnTemplateFeedbackClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText(QuickNoteService.GetTemplateClientFeedback());
        }

        private void InsertTemplateText(string template)
        {
            if (_currentNote == null) return;
            if (string.IsNullOrWhiteSpace(NoteEditor.Text) || NoteEditor.Text.Trim() == "# New Note")
            {
                NoteEditor.Text = template;
                NoteEditor.CaretIndex = NoteEditor.Text.Length;
            }
            else
            {
                int caret = NoteEditor.CaretIndex;
                NoteEditor.Text = NoteEditor.Text.Insert(caret, "\n\n" + template);
                NoteEditor.CaretIndex = caret + template.Length + 2;
            }
            NoteEditor.Focus();
        }

        // ─── Export & Copy Functions ─────────────────────────────────────────

        private void OnExportButtonClicked(object sender, RoutedEventArgs e)
        {
            if (BtnExport != null && BtnExport.ContextMenu != null)
            {
                BtnExport.ContextMenu.PlacementTarget = BtnExport;
                BtnExport.ContextMenu.IsOpen = true;
            }
        }

        private void OnCopyCleanTextClicked(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(NoteEditor.Text)) return;
            try
            {
                string clean = StripMarkdownFormatting(NoteEditor.Text);
                Clipboard.SetText(clean);
                ShowToastSavedStatus("Copied clean text to clipboard!");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[QuickNotePage] Copy clean text error: " + ex.Message);
            }
        }

        private void OnCopyMarkdownClicked(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(NoteEditor.Text)) return;
            try
            {
                Clipboard.SetText(NoteEditor.Text);
                ShowToastSavedStatus("Copied raw Markdown to clipboard!");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[QuickNotePage] Copy raw markdown error: " + ex.Message);
            }
        }

        private void OnExportMdFileClicked(object sender, RoutedEventArgs e)
        {
            if (_currentNote == null || string.IsNullOrWhiteSpace(NoteEditor.Text)) return;
            try
            {
                SaveFileDialog dlg = new SaveFileDialog();
                dlg.Filter = "Markdown Document (*.md)|*.md|Text File (*.txt)|*.txt|All Files (*.*)|*.*";
                dlg.DefaultExt = ".md";
                string safeTitle = !string.IsNullOrWhiteSpace(_currentNote.Title)
                    ? SanitizeFileName(_currentNote.Title)
                    : "quick-note";
                dlg.FileName = safeTitle + ".md";

                if (dlg.ShowDialog() == true)
                {
                    string fullContent = QuickNoteService.BuildContentWithFrontmatter(
                        NoteEditor.Text,
                        _currentNote.IsPinned,
                        _currentNote.Priority,
                        _currentNote.Icon,
                        _currentNote.Category);

                    File.WriteAllText(dlg.FileName, fullContent, Encoding.UTF8);
                    ShowToastSavedStatus("Exported to " + Path.GetFileName(dlg.FileName) + "!");
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[QuickNotePage] Export md file error: " + ex.Message);
                MessageBox.Show("Failed to export Markdown file: " + ex.Message, "Export Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private static string SanitizeFileName(string name)
        {
            if (string.IsNullOrWhiteSpace(name)) return "quick-note";
            foreach (char c in Path.GetInvalidFileNameChars())
            {
                name = name.Replace(c, '_');
            }
            return name.Trim();
        }

        private void ShowToastSavedStatus(string message)
        {
            TxtSavedStatus.Text = message;
            DispatcherTimer t = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2.5) };
            t.Tick += delegate
            {
                TxtSavedStatus.Text = "Saved ✓";
                t.Stop();
            };
            t.Start();
        }

        private string StripMarkdownFormatting(string md)
        {
            if (string.IsNullOrWhiteSpace(md)) return "";
            string text = QuickNoteService.StripFrontmatter(md);
            string[] lines = text.Split(new char[] { '\r', '\n' });
            StringBuilder sb = new StringBuilder();
            foreach (string l in lines)
            {
                string line = l.Trim();
                if (line.StartsWith("#")) line = line.TrimStart('#', ' ');
                if (line.StartsWith("- [ ] ")) line = "☐ " + line.Substring(6);
                else if (line.StartsWith("- [x] ") || line.StartsWith("- [X] ")) line = "☑ " + line.Substring(6);
                else if (line.StartsWith("- ") || line.StartsWith("* ")) line = "• " + line.Substring(2);
                else if (line.StartsWith("> ")) line = "\"" + line.Substring(2) + "\"";

                line = line.Replace("**", "").Replace("*", "").Replace("~~", "").Replace("`", "");
                sb.AppendLine(line);
            }
            return sb.ToString().Trim();
        }

        // ─── Keyboard Shortcuts ──────────────────────────────────────────────

        private void OnPageKeyDown(object sender, KeyEventArgs e)
        {
            if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
            {
                if (e.Key == Key.N)
                {
                    e.Handled = true;
                    OnNewNoteClicked(this, null);
                }
                else if (e.Key == Key.S)
                {
                    e.Handled = true;
                    DoAutoSave();
                }
            }
        }

        // ─── Markdown & Block Formatting Toolbar ──────────────────────────────

        private void ApplyMarkdownWrap(string prefix, string suffix, bool linePrefix)
        {
            if (suffix == null) suffix = prefix;
            int start = NoteEditor.SelectionStart;
            int length = NoteEditor.SelectionLength;

            if (linePrefix)
            {
                int lineStart = NoteEditor.Text.LastIndexOf('\n', start > 0 ? start - 1 : 0);
                lineStart = lineStart < 0 ? 0 : lineStart + 1;
                NoteEditor.Select(lineStart, 0);
                NoteEditor.SelectedText = prefix;
                NoteEditor.SelectionStart = lineStart + prefix.Length + (length > 0 ? length : 0);
                NoteEditor.Focus();
                return;
            }

            string replacement;
            if (length > 0)
            {
                replacement = prefix + NoteEditor.SelectedText + suffix;
                NoteEditor.SelectedText = replacement;
                NoteEditor.SelectionStart = start + replacement.Length;
            }
            else
            {
                replacement = prefix + "text" + suffix;
                NoteEditor.SelectedText = replacement;
                NoteEditor.Select(start + prefix.Length, 4);
            }
            NoteEditor.Focus();
        }

        private void OnNMdBold(object sender, RoutedEventArgs e)      { ApplyMarkdownWrap("**", "**", false); }
        private void OnNMdItalic(object sender, RoutedEventArgs e)    { ApplyMarkdownWrap("*", "*", false); }
        private void OnNMdStrike(object sender, RoutedEventArgs e)    { ApplyMarkdownWrap("~~", "~~", false); }
        private void OnNMdCode(object sender, RoutedEventArgs e)      { ApplyMarkdownWrap("`", "`", false); }
        private void OnNMdH1(object sender, RoutedEventArgs e)        { ApplyMarkdownWrap("# ", "", true); }
        private void OnNMdH2(object sender, RoutedEventArgs e)        { ApplyMarkdownWrap("## ", "", true); }
        private void OnNMdH3(object sender, RoutedEventArgs e)        { ApplyMarkdownWrap("### ", "", true); }
        private void OnNMdList(object sender, RoutedEventArgs e)      { ApplyMarkdownWrap("- ", "", true); }
        private void OnNMdNumList(object sender, RoutedEventArgs e)   { ApplyMarkdownWrap("1. ", "", true); }
        private void OnNMdCheck(object sender, RoutedEventArgs e)     { ApplyMarkdownWrap("- [ ] ", "", true); }
        private void OnNMdQuote(object sender, RoutedEventArgs e)     { ApplyMarkdownWrap("> ", "", true); }

        private void OnInsertCalloutClicked(object sender, RoutedEventArgs e)
        {
            if (BtnInsertCallout != null && BtnInsertCallout.ContextMenu != null)
            {
                BtnInsertCallout.ContextMenu.PlacementTarget = BtnInsertCallout;
                BtnInsertCallout.ContextMenu.IsOpen = true;
            }
        }

        private void OnCalloutNoteClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText("> [!NOTE] Note\n> Add relevant context, brief background, or operational instructions here.\n");
        }

        private void OnCalloutTipClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText("> [!TIP] Pro-Tip\n> High-performing design hook, creative shortcut, or optimization advice.\n");
        }

        private void OnCalloutWarningClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText("> [!WARNING] Caution & Compliance\n> Review KKM and advertising claim boundaries. Avoid unapproved absolute statements.\n");
        }

        private void OnCalloutDangerClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText("> [!DANGER] Urgent Critical Alert\n> Do not release or submit for print without Art Director and Client sign-off.\n");
        }

        private void OnInsertTableClicked(object sender, RoutedEventArgs e)
        {
            InsertTemplateText(
                "| Deliverable | Specs / Ratio | Status | Assigned |\n" +
                "| :--- | :--- | :--- | :--- |\n" +
                "| TikTok Video Ad #1 | 1080x1920 MP4 (9:16) | In Progress | Motion Editor |\n" +
                "| Meta Feed Carousel | 1080x1080 PNG (1:1) | Review | Graphic Designer |\n" +
                "| Story Teaser Hook | 1080x1920 JPG (9:16) | Approved | Creative Director |\n");
        }

        private void OnNMdCodeBlock(object sender, RoutedEventArgs e)
        {
            int pos = NoteEditor.SelectionStart;
            string insert = "\n```\ncode\n```\n";
            NoteEditor.Text = NoteEditor.Text.Insert(pos, insert);
            NoteEditor.Select(pos + 5, 4);
            NoteEditor.Focus();
        }

        private void OnNMdHR(object sender, RoutedEventArgs e)
        {
            int pos = NoteEditor.SelectionStart;
            string insert = "\n---\n";
            NoteEditor.Text = NoteEditor.Text.Insert(pos, insert);
            NoteEditor.SelectionStart = pos + insert.Length;
            NoteEditor.Focus();
        }

        private void OnNMdLink(object sender, RoutedEventArgs e)
        {
            int start = NoteEditor.SelectionStart;
            string selected = NoteEditor.SelectedText;
            string replacement = string.IsNullOrWhiteSpace(selected)
                ? "[link text](url)"
                : string.Format("[{0}](url)", selected);
            NoteEditor.SelectedText = replacement;
            NoteEditor.SelectionStart = start + replacement.Length;
            NoteEditor.Focus();
        }

        private void OnNMdImage(object sender, RoutedEventArgs e)
        {
            int start = NoteEditor.SelectionStart;
            string selected = NoteEditor.SelectedText;
            string replacement = string.IsNullOrWhiteSpace(selected)
                ? "![alt text](url)"
                : string.Format("![{0}](url)", selected);
            NoteEditor.SelectedText = replacement;
            NoteEditor.SelectionStart = start + replacement.Length;
            NoteEditor.Focus();
        }

        // ─── Markdown Guide Drawer ───────────────────────────────────────────

        private void OnToggleMarkdownHelp(object sender, RoutedEventArgs e)
        {
            if (PanelMarkdownHelp == null) return;
            PanelMarkdownHelp.Visibility = PanelMarkdownHelp.Visibility == Visibility.Visible
                ? Visibility.Collapsed
                : Visibility.Visible;
        }

        private void OnCloseMarkdownHelp(object sender, RoutedEventArgs e)
        {
            if (PanelMarkdownHelp != null)
                PanelMarkdownHelp.Visibility = Visibility.Collapsed;
        }
    }
}
