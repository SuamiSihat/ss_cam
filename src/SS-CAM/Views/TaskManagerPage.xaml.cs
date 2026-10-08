using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using SS_CAM.Models;
using SS_CAM.Services;
using SS_CAM.Utilities;
using SS_CAM.Dialogs;
using Wpf.Ui.Controls;
using MenuItem = System.Windows.Controls.MenuItem;

namespace SS_CAM.Views
{
    public partial class TaskManagerPage : Page
    {
        private string _workspaceRoot = "";
        private List<ProjectStatusItem> _allProjects = new List<ProjectStatusItem>();
        private ProjectStatusItem _editingProject = null;
        private string _editingSubtaskId = null;

        private bool _isPopulatingFilter = false;
        private bool _isPopulatingDetail = false;
        private Point _dragStartPoint;
        private bool _isDragging = false;

        public TaskManagerPage()
        {
            InitializeComponent();
            Loaded += OnPageLoaded;
            Unloaded += OnPageUnloaded;
        }

        private void OnPageLoaded(object sender, RoutedEventArgs e)
        {
            try
            {
                var profile = UserProfileService.LoadProfile();
                _workspaceRoot = profile != null ? profile.WorkspaceRoot : "";
                PopulateDesignerFilter();
                LoadProjects();
                WorkspaceWatcherService.Instance.WorkspaceChanged += OnWorkspaceChanged;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("TaskManager PageLoad error: " + ex);
            }
        }

        private void OnPageUnloaded(object sender, RoutedEventArgs e)
        {
            try
            {
                if (_editingProject != null && !string.IsNullOrWhiteSpace(_editingProject.FullPath))
                {
                    FileCollisionGuardService.Instance.ReleaseLock(_editingProject.FullPath);
                }
                WorkspaceWatcherService.Instance.WorkspaceChanged -= OnWorkspaceChanged;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("TaskManager PageUnload error: " + ex);
            }
        }

        private void OnScrollViewerPreviewMouseWheel(object sender, System.Windows.Input.MouseWheelEventArgs e)
        {
            try
            {
                var scroller = sender as ScrollViewer;
                if (scroller == null || e.Handled) return;
                int steps = Math.Max(1, Math.Min(8, Math.Abs(e.Delta) / 30));
                if (scroller.ScrollableHeight > 0)
                {
                    if (e.Delta < 0) for (int i = 0; i < steps; i++) scroller.LineDown();
                    else for (int i = 0; i < steps; i++) scroller.LineUp();
                }
                else if (scroller.ScrollableWidth > 0)
                {
                    if (e.Delta < 0) for (int i = 0; i < steps; i++) scroller.LineRight();
                    else for (int i = 0; i < steps; i++) scroller.LineLeft();
                }
                e.Handled = true;
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[TaskManagerPage] OnScrollViewerPreviewMouseWheel: " + ex.Message); }
        }

        private void OnWorkspaceChanged(object sender, WorkspaceChangedEventArgs e)
        {
            Dispatcher.Invoke(delegate
            {
                try
                {
                    if (e != null && e.ChangeType == WorkspaceChangeType.ProjectEditorLock)
                    {
                        if (_editingProject != null && string.Equals(e.ProjectPath, _editingProject.FullPath, StringComparison.OrdinalIgnoreCase))
                        {
                            UpdateCollisionStatus(_editingProject.FullPath);
                        }
                        return;
                    }

                    LoadProjects();

                    if (_editingProject != null && e != null && string.Equals(e.ProjectPath, _editingProject.FullPath, StringComparison.OrdinalIgnoreCase))
                    {
                        UpdateCollisionStatus(_editingProject.FullPath);
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[TaskManagerPage] WorkspaceChanged refresh error: " + ex.Message);
                }
            });
        }

        private List<string> GetAvailableDesignersList()
        {
            HashSet<string> designerSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            List<StaffDirectoryItem> staffList = null;
            try { staffList = UserProfileService.GetStaffDirectory(_workspaceRoot); }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[TaskManagerPage] GetStaffDirectory: " + ex.Message); }

            if (staffList != null)
            {
                foreach (var s in staffList)
                {
                    if (s != null && !string.IsNullOrWhiteSpace(s.Name))
                    {
                        if (WorkloadSlaService.IsDesignerOrAdminRole(s.Role, s.Department, s.Roles))
                            designerSet.Add(s.Name);
                    }
                }
            }

            if (!string.IsNullOrWhiteSpace(_workspaceRoot))
            {
                List<DesignerFolderChoice> designers = WorkspaceScanner.GetDesignerFolders(_workspaceRoot);
                if (designers != null)
                {
                    foreach (DesignerFolderChoice d in designers)
                    {
                        if (d != null && !string.IsNullOrWhiteSpace(d.Name))
                            designerSet.Add(d.Name);
                    }
                }
            }

            foreach (ProjectStatusItem p in _allProjects)
            {
                if (p != null && !string.IsNullOrWhiteSpace(p.Designer))
                {
                    if (!Regex.IsMatch(p.Designer, @"^\d{4}$") && !Regex.IsMatch(p.Designer, @"^\d{6}") &&
                        !p.Designer.StartsWith("#") && !p.Designer.StartsWith("_"))
                    {
                        designerSet.Add(p.Designer);
                    }
                }
            }

            List<string> list = new List<string>(designerSet);
            list.Sort(StringComparer.OrdinalIgnoreCase);
            return list;
        }

        private void PopulateDesignerFilter()
        {
            try
            {
                _isPopulatingFilter = true;
                string currentSelection = DesignerFilterTM.SelectedItem != null ? DesignerFilterTM.SelectedItem.ToString() : "All Designers";

                List<string> designers = GetAvailableDesignersList();

                DesignerFilterTM.Items.Clear();
                DesignerFilterTM.Items.Add("All Designers");
                foreach (string d in designers)
                {
                    DesignerFilterTM.Items.Add(d);
                }

                int selectedIdx = 0;
                for (int i = 0; i < DesignerFilterTM.Items.Count; i++)
                {
                    if (string.Equals(DesignerFilterTM.Items[i].ToString(), currentSelection, StringComparison.OrdinalIgnoreCase))
                    {
                        selectedIdx = i;
                        break;
                    }
                }
                DesignerFilterTM.SelectedIndex = selectedIdx;

                if (DetailDesigner != null)
                {
                    string currentDetailText = DetailDesigner.Text;
                    DetailDesigner.Items.Clear();
                    foreach (string d in designers)
                    {
                        DetailDesigner.Items.Add(d);
                    }
                    if (!string.IsNullOrEmpty(currentDetailText))
                        DetailDesigner.Text = currentDetailText;
                }

                if (CmbNewTaskAssignee != null)
                {
                    string currentNewTaskText = CmbNewTaskAssignee.Text;
                    CmbNewTaskAssignee.Items.Clear();
                    foreach (string d in designers)
                    {
                        CmbNewTaskAssignee.Items.Add(d);
                    }
                    if (!string.IsNullOrEmpty(currentNewTaskText))
                        CmbNewTaskAssignee.Text = currentNewTaskText;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("PopulateFilter error: " + ex);
            }
            finally
            {
                _isPopulatingFilter = false;
            }
        }

        private async System.Threading.Tasks.Task LoadProjectsAsync()
        {
            try
            {
                if (string.IsNullOrWhiteSpace(_workspaceRoot) ||
                    !System.IO.Directory.Exists(_workspaceRoot))
                {
                    _allProjects.Clear();
                    PopulateDesignerFilter();
                    UpdateBoard();
                    return;
                }

                string root = _workspaceRoot;
                List<ProjectStatusItem> items = await System.Threading.Tasks.Task.Run(() =>
                {
                    List<ProjectStatusItem> list = new List<ProjectStatusItem>();
                    try
                    {
                        // 1. Load lightweight Studio Tasks from .sscam/tasks/*.md
                        List<ProjectStatusItem> tasks = StudioTaskService.LoadStudioTasks(root);
                        if (tasks != null && tasks.Count > 0)
                        {
                            list.AddRange(tasks);
                        }

                        // 2. Load heavy NAS Vault Projects
                        List<DesignerFolderItem> folders = WorkspaceScanner.ListDesignerFolders(root, "", "", 500);
                        if (folders != null)
                        {
                            foreach (DesignerFolderItem folder in folders)
                            {
                                if (folder != null && !string.IsNullOrEmpty(folder.FullPath))
                                {
                                    ProjectStatusItem item = FrontmatterService.ReadStatus(folder.FullPath);
                                    if (item != null)
                                    {
                                        if (string.IsNullOrWhiteSpace(item.Designer) && !string.IsNullOrWhiteSpace(folder.Designer))
                                        {
                                            item.Designer = folder.Designer;
                                        }
                                        list.Add(item);
                                    }
                                }
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine("Background TaskManager LoadProjects error: " + ex);
                    }
                    return list;
                });

                _allProjects.Clear();
                _allProjects.AddRange(items);

                PopulateDesignerFilter();
                UpdateMetricSummaryCards();
                ApplyFiltersAndUpdateBoard();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("LoadProjects error: " + ex);
                UpdateBoard();
            }
        }

        private async void LoadProjects()
        {
            await LoadProjectsAsync();
        }
        private void UpdateMetricSummaryCards()
        {
            try
            {
                int total = _allProjects.Count;
                int inProgressCount = 0;
                int reviewCount = 0;
                int urgentCount = 0;
                int doneCount = 0;

                foreach (ProjectStatusItem p in _allProjects)
                {
                    if (p == null) continue;
                    string status = (p.Status ?? "").Trim().Trim('"', '\'').ToLowerInvariant();
                    string priority = (p.Priority ?? "").Trim().Trim('"', '\'').ToLowerInvariant();
                    string deadlineDisp = p.DeadlineDisplay ?? "";

                    if (status == "in-progress" || status == "in_progress" || status == "inprogress" || status == "in progress" || status == "revision" || status == "revision_required" || status == "revision-required") inProgressCount++;
                    else if (status == "review" || status == "in-review" || status == "in_review") reviewCount++;
                    else if (status == "done" || status == "approved" || status == "completed") doneCount++;

                    if (status != "done" && status != "approved" && status != "completed")
                    {
                        if (priority == "urgent" || status == "revision" || p.IsOverdue || deadlineDisp.StartsWith("Overdue", StringComparison.OrdinalIgnoreCase))
                        {
                            urgentCount++;
                        }
                    }
                }

                if (MetricTotalProjects != null) MetricTotalProjects.Text = total.ToString();
                if (MetricInProgress != null) MetricInProgress.Text = inProgressCount.ToString();
                if (MetricReview != null) MetricReview.Text = reviewCount.ToString();
                if (MetricUrgent != null) MetricUrgent.Text = urgentCount.ToString();
                if (MetricDone != null) MetricDone.Text = doneCount.ToString();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("UpdateMetricSummaryCards error: " + ex);
            }
        }

        private void ApplyFiltersAndUpdateBoard()
        {
            try
            {
                string scopeFilter = "all";
                if (ScopeFilter != null && ScopeFilter.SelectedItem is ComboBoxItem)
                {
                    ComboBoxItem scopeCbi = (ComboBoxItem)ScopeFilter.SelectedItem;
                    string tag = scopeCbi.Tag != null ? scopeCbi.Tag.ToString().ToLowerInvariant() : "";
                    if (!string.IsNullOrEmpty(tag)) scopeFilter = tag;
                }

                string designerFilter = DesignerFilterTM.SelectedItem != null
                    ? DesignerFilterTM.SelectedItem.ToString() : "All Designers";
                string priorityFilter = "";
                if (PriorityFilter != null && PriorityFilter.SelectedItem is ComboBoxItem)
                {
                    ComboBoxItem cbi = (ComboBoxItem)PriorityFilter.SelectedItem;
                    string tag = cbi.Tag != null ? cbi.Tag.ToString() : "";
                    if (!string.IsNullOrEmpty(tag) && tag != "all")
                    {
                        priorityFilter = tag;
                    }
                    else
                    {
                        string sel = cbi.Content != null ? cbi.Content.ToString() : "";
                        if (sel != "All Priorities" && sel != "all") priorityFilter = sel;
                    }
                }
                string statusFilter = "";
                if (StatusFilter != null && StatusFilter.SelectedItem is ComboBoxItem)
                {
                    string sel = ((ComboBoxItem)StatusFilter.SelectedItem).Content.ToString();
                    if (sel != "All Statuses") statusFilter = sel;
                }
                string searchQuery = TxtSearchQuery != null ? TxtSearchQuery.Text.Trim().ToLowerInvariant() : "";

                List<ProjectStatusItem> filtered = new List<ProjectStatusItem>();
                foreach (ProjectStatusItem p in _allProjects)
                {
                    if (p == null) continue;
                    if (scopeFilter == "tasks" && !p.IsStudioTask) continue;
                    if (scopeFilter == "projects" && p.IsStudioTask) continue;
                    if (designerFilter != "All Designers" && !string.IsNullOrWhiteSpace(designerFilter))
                    {
                        bool match = false;
                        if (!string.IsNullOrWhiteSpace(p.Designer))
                        {
                            if (string.Equals(p.Designer, designerFilter, StringComparison.OrdinalIgnoreCase) ||
                                p.Designer.IndexOf(designerFilter, StringComparison.OrdinalIgnoreCase) >= 0 ||
                                designerFilter.IndexOf(p.Designer, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                match = true;
                            }
                        }
                        if (!match && !string.IsNullOrWhiteSpace(p.FullPath))
                        {
                            if (p.FullPath.IndexOf(designerFilter, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                match = true;
                            }
                        }
                        if (!match) continue;
                    }
                    if (!string.IsNullOrEmpty(priorityFilter) &&
                        !string.Equals(p.Priority, priorityFilter, StringComparison.OrdinalIgnoreCase)) continue;
                    if (!string.IsNullOrEmpty(statusFilter) &&
                        !string.Equals(p.Status, statusFilter, StringComparison.OrdinalIgnoreCase)) continue;
                    if (!string.IsNullOrEmpty(searchQuery))
                    {
                        string projName = (p.Project ?? "").ToLowerInvariant();
                        string clientName = (p.Client ?? "").ToLowerInvariant();
                        string designerName = (p.Designer ?? "").ToLowerInvariant();
                        if (!projName.Contains(searchQuery) && !clientName.Contains(searchQuery) && !designerName.Contains(searchQuery)) continue;
                    }
                    filtered.Add(p);
                }

                SortProjects(filtered);
                UpdateBoard(filtered);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("ApplyFilters error: " + ex);
            }
        }

        private void SortProjects(List<ProjectStatusItem> list)
        {
            if (list == null || list.Count <= 1) return;

            string sortSel = "Oldest First";
            if (SortFilter != null && SortFilter.SelectedItem is ComboBoxItem)
            {
                sortSel = ((ComboBoxItem)SortFilter.SelectedItem).Content.ToString();
            }

            if (sortSel.Contains("Oldest First"))
            {
                list.Sort((a, b) => a.ParsedCreatedDate.CompareTo(b.ParsedCreatedDate));
            }
            else if (sortSel.Contains("Newest First"))
            {
                list.Sort((a, b) => b.ParsedCreatedDate.CompareTo(a.ParsedCreatedDate));
            }
            else if (sortSel.Contains("Deadline"))
            {
                list.Sort((a, b) =>
                {
                    DateTime dtA, dtB;
                    bool hasA = DateTime.TryParse(a.Deadline, out dtA);
                    bool hasB = DateTime.TryParse(b.Deadline, out dtB);
                    if (hasA && hasB) return dtA.CompareTo(dtB);
                    if (hasA) return -1;
                    if (hasB) return 1;
                    return 0;
                });
            }
            else if (sortSel.Contains("Priority"))
            {
                list.Sort((a, b) => PriorityRank(b.Priority).CompareTo(PriorityRank(a.Priority)));
            }
        }

        private static int PriorityRank(string priority)
        {
            if (string.IsNullOrWhiteSpace(priority)) return 0;
            string p = priority.ToLowerInvariant();
            if (p == "urgent") return 4;
            if (p == "high") return 3;
            if (p == "medium") return 2;
            if (p == "low") return 1;
            return 0;
        }

        private void UpdateBoard(List<ProjectStatusItem> projects = null)
        {
            try
            {
                if (projects == null) projects = _allProjects;

                List<ProjectStatusItem> backlog = new List<ProjectStatusItem>();
                List<ProjectStatusItem> inProgress = new List<ProjectStatusItem>();
                List<ProjectStatusItem> review = new List<ProjectStatusItem>();
                List<ProjectStatusItem> revision = new List<ProjectStatusItem>();
                List<ProjectStatusItem> done = new List<ProjectStatusItem>();
                List<ProjectStatusItem> other = new List<ProjectStatusItem>();

                foreach (ProjectStatusItem p in projects)
                {
                    if (p == null) continue;
                    string s = (p.Status ?? "").Trim().Trim('"', '\'').ToLowerInvariant();
                    if (s == "backlog") backlog.Add(p);
                    else if (s == "in-progress" || s == "in_progress" || s == "inprogress" || s == "in progress") inProgress.Add(p);
                    else if (s == "review" || s == "in-review" || s == "in_review") review.Add(p);
                    else if (s == "revision" || s == "revision-required" || s == "revision_required") revision.Add(p);
                    else if (s == "done" || s == "approved" || s == "completed") done.Add(p);
                    else other.Add(p);   // on-hold, untracked, empty
                }

                if (ListBacklog != null) ListBacklog.ItemsSource = backlog;
                if (ListInProgress != null) ListInProgress.ItemsSource = inProgress;
                if (ListReview != null) ListReview.ItemsSource = review;
                if (ListRevision != null) ListRevision.ItemsSource = revision;
                if (ListDone != null) ListDone.ItemsSource = done;
                if (ListOther != null) ListOther.ItemsSource = other;

                if (CountBacklog != null) CountBacklog.Text = backlog.Count.ToString();
                if (CountInProgress != null) CountInProgress.Text = inProgress.Count.ToString();
                if (CountReview != null) CountReview.Text = review.Count.ToString();
                if (CountRevision != null) CountRevision.Text = revision.Count.ToString();
                if (CountDone != null) CountDone.Text = done.Count.ToString();
                if (CountOther != null) CountOther.Text = other.Count.ToString();

                if (TxtTaskCount != null) TxtTaskCount.Text = string.Format("{0} projects", projects.Count);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("UpdateBoard error: " + ex);
            }
        }

        private void OnTMSearchQueryChanged(object sender, TextChangedEventArgs e)
        {
            if (!IsLoaded || _isPopulatingFilter) return;
            ApplyFiltersAndUpdateBoard();
        }

        private void OnTMResetFiltersClicked(object sender, RoutedEventArgs e)
        {
            if (TxtSearchQuery != null) TxtSearchQuery.Text = "";
            if (ScopeFilter != null && ScopeFilter.Items.Count > 0) ScopeFilter.SelectedIndex = 0;
            if (DesignerFilterTM != null && DesignerFilterTM.Items.Count > 0) DesignerFilterTM.SelectedIndex = 0;
            if (StatusFilter != null && StatusFilter.Items.Count > 0) StatusFilter.SelectedIndex = 0;
            if (PriorityFilter != null && PriorityFilter.Items.Count > 0) PriorityFilter.SelectedIndex = 0;
            if (SortFilter != null && SortFilter.Items.Count > 0) SortFilter.SelectedIndex = 0;
            ApplyFiltersAndUpdateBoard();
        }

        private void OnOpenInCanvaClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                var menu = sender as System.Windows.Controls.MenuItem;
                ProjectStatusItem item = (menu != null ? menu.DataContext : null) as ProjectStatusItem;
                if (item != null && !string.IsNullOrWhiteSpace(item.CanvaUrl))
                {
                    string url = item.CanvaUrl.Trim();
                    if (!url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) && !url.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                    {
                        url = "https://" + url;
                    }
                    Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[TaskManagerPage] OnOpenInCanvaClicked error: " + ex.Message);
            }
        }

        private void OnDetailOpenCanvaClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject != null && !string.IsNullOrWhiteSpace(_editingProject.CanvaUrl))
            {
                try
                {
                    string url = _editingProject.CanvaUrl.Trim();
                    if (!url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) && !url.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                    {
                        url = "https://" + url;
                    }
                    Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[TaskManagerPage] OpenCanva error: " + ex.Message);
                }
            }
        }

        private void OnQuickStatusMenuClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                System.Windows.Controls.MenuItem menu = sender as System.Windows.Controls.MenuItem;
                if (menu != null && menu.Tag != null)
                {
                    string newStatus = menu.Tag.ToString();
                    ProjectStatusItem item = menu.DataContext as ProjectStatusItem;
                    if (item != null && !string.IsNullOrEmpty(item.FullPath))
                    {
                        item.Status = newStatus;
                        FrontmatterService.WriteStatus(item);
                        LoadProjects();
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("OnQuickStatusMenuClicked error: " + ex);
            }
        }

        private void OnCardContextMenuOpened(object sender, RoutedEventArgs e)
        {
            try
            {
                ContextMenu cm = sender as ContextMenu;
                if (cm == null) return;

                ProjectStatusItem item = cm.DataContext as ProjectStatusItem;
                if (item == null) return;

                MenuItem handoverRoot = null;
                foreach (var obj in cm.Items)
                {
                    MenuItem mi = obj as MenuItem;
                    if (mi != null && object.Equals(mi.Tag, "handover_root"))
                    {
                        handoverRoot = mi;
                        break;
                    }
                }

                if (handoverRoot != null)
                {
                    handoverRoot.Items.Clear();
                    List<string> designers = GetAvailableDesignersList();
                    foreach (string d in designers)
                    {
                        MenuItem sub = new MenuItem
                        {
                            Header = d,
                            Tag = d,
                            IsChecked = string.Equals(item.Designer, d, StringComparison.OrdinalIgnoreCase)
                        };
                        sub.Click += OnQuickHandoverMenuClicked;
                        handoverRoot.Items.Add(sub);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[TaskManagerPage] OnCardContextMenuOpened error: " + ex.Message);
            }
        }

        private void OnQuickHandoverMenuClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                MenuItem menu = sender as MenuItem;
                if (menu == null || menu.Tag == null) return;

                string targetDesigner = menu.Tag.ToString();
                ProjectStatusItem item = menu.DataContext as ProjectStatusItem;
                if (item == null)
                {
                    ContextMenu cm = FindParentContextMenu(menu);
                    if (cm != null) item = cm.DataContext as ProjectStatusItem;
                }

                if (item != null && !string.IsNullOrEmpty(item.FullPath))
                {
                    string oldDesigner = !string.IsNullOrWhiteSpace(item.Designer) ? item.Designer : "Unassigned";
                    item.Designer = targetDesigner;
                    FrontmatterService.WriteStatus(item);
                    NotificationService.ShowSuccess(
                        "Task Handed Over",
                        string.Format("Project '{0}' handed over to {1}.", item.Project, targetDesigner),
                        item.FullPath);
                    LoadProjects();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[TaskManagerPage] OnQuickHandoverMenuClicked error: " + ex.Message);
            }
        }

        private ContextMenu FindParentContextMenu(MenuItem item)
        {
            DependencyObject current = item;
            while (current != null)
            {
                if (current is ContextMenu) return (ContextMenu)current;
                current = LogicalTreeHelper.GetParent(current);
            }
            return null;
        }

        private void OnTMRefreshClicked(object sender, RoutedEventArgs e)
        {
            LoadProjects();
        }

        private void OnTMFilterChanged(object sender, SelectionChangedEventArgs e)
        {
            if (!IsLoaded || _isPopulatingFilter) return;
            ApplyFiltersAndUpdateBoard();
        }

        // ─── Drag and Drop Implementation ──────────────────────────────────────

        private void OnCardPreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            _dragStartPoint = e.GetPosition(null);
            _isDragging = false;
        }

        private void OnCardMouseMove(object sender, MouseEventArgs e)
        {
            if (e.LeftButton != MouseButtonState.Pressed || _isDragging) return;

            Point mousePos = e.GetPosition(null);
            Vector diff = _dragStartPoint - mousePos;

            if (Math.Abs(diff.X) > SystemParameters.MinimumHorizontalDragDistance ||
                Math.Abs(diff.Y) > SystemParameters.MinimumVerticalDragDistance)
            {
                FrameworkElement card = sender as FrameworkElement;
                if (card == null) return;

                ProjectStatusItem item = card.DataContext as ProjectStatusItem;
                if (item == null) return;

                _isDragging = true;
                try
                {
                    DataObject dragData = new DataObject(typeof(ProjectStatusItem), item);
                    dragData.SetData("ProjectStatusItem", item);
                    DragDrop.DoDragDrop(card, dragData, DragDropEffects.Move);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("DragDrop error: " + ex.Message);
                }
                finally
                {
                    _isDragging = false;
                }
            }
        }

        private void OnColumnDragOver(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(typeof(ProjectStatusItem)) || e.Data.GetDataPresent("ProjectStatusItem"))
            {
                e.Effects = DragDropEffects.Move;
                e.Handled = true;

                Wpf.Ui.Controls.Card columnCard = sender as Wpf.Ui.Controls.Card;
                if (columnCard != null)
                {
                    columnCard.BorderThickness = new Thickness(2);
                    columnCard.BorderBrush = (System.Windows.Media.Brush)Application.Current.FindResource("FluentBrand80");
                }
            }
            else
            {
                e.Effects = DragDropEffects.None;
            }
        }

        private void OnColumnDragLeave(object sender, DragEventArgs e)
        {
            Wpf.Ui.Controls.Card columnCard = sender as Wpf.Ui.Controls.Card;
            if (columnCard != null)
            {
                columnCard.BorderThickness = new Thickness(1);
                columnCard.BorderBrush = (System.Windows.Media.Brush)Application.Current.FindResource("CardStrokeColorDefaultBrush");
            }
        }

        private void OnColumnDrop(object sender, DragEventArgs e)
        {
            Wpf.Ui.Controls.Card columnCard = sender as Wpf.Ui.Controls.Card;
            if (columnCard != null)
            {
                columnCard.BorderThickness = new Thickness(1);
                columnCard.BorderBrush = (System.Windows.Media.Brush)Application.Current.FindResource("CardStrokeColorDefaultBrush");
            }

            try
            {
                ProjectStatusItem item = null;
                if (e.Data.GetDataPresent(typeof(ProjectStatusItem)))
                    item = e.Data.GetData(typeof(ProjectStatusItem)) as ProjectStatusItem;
                else if (e.Data.GetDataPresent("ProjectStatusItem"))
                    item = e.Data.GetData("ProjectStatusItem") as ProjectStatusItem;

                FrameworkElement targetEl = sender as FrameworkElement;
                string targetStatus = targetEl != null ? targetEl.Tag as string : null;

                if (item != null && !string.IsNullOrEmpty(targetStatus))
                {
                    string cur = (item.Status ?? "").Trim().Trim('"', '\'').ToLowerInvariant();
                    string tgt = targetStatus.Trim().Trim('"', '\'').ToLowerInvariant();
                    if (!string.Equals(cur, tgt, StringComparison.OrdinalIgnoreCase))
                    {
                        item.Status = targetStatus;
                        if (item.IsStudioTask)
                        {
                            StudioTaskService.SaveStudioTask(item, null);
                        }
                        else
                        {
                            FrontmatterService.WriteStatus(item);
                        }

                        NotificationService.ShowSuccess(
                            item.IsStudioTask ? "Task Status Updated" : "Project Status Updated",
                            string.Format("'{0}' moved to {1}", item.Project, targetStatus),
                            item.FullPath);

                        UpdateMetricSummaryCards();
                        ApplyFiltersAndUpdateBoard();
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("ColumnDrop error: " + ex.Message);
                NotificationService.ShowError(
                    "Update Failed",
                    "Could not update status: " + ex.Message);
            }
        }

        // ─── Project Card Click → Open Detail Drawer ───────────────────────────

        private void OnProjectCardClicked(object sender, RoutedEventArgs e)
        {
            if (_isDragging) return;

            FrameworkElement el = sender as FrameworkElement;
            if (el == null) return;
            ProjectStatusItem item = el.DataContext as ProjectStatusItem;
            if (item == null) return;

            PopulateDetail(item);
        }

        private void PopulateDetail(ProjectStatusItem item)
        {
            if (item == null) return;

            DetailPanel.Visibility = Visibility.Visible;
            _editingProject = item;
            _isPopulatingDetail = true;

            DetailProjectName.Text = item.Project;
            if (BtnDetailOpenCanva != null)
            {
                BtnDetailOpenCanva.Visibility = item.HasCanvaUrl ? Visibility.Visible : Visibility.Collapsed;
            }

            if (BtnDetailProvision != null)
            {
                BtnDetailProvision.Visibility = (item.IsStudioTask && !item.IsConverted) ? Visibility.Visible : Visibility.Collapsed;
            }

            if (BtnDetailOpenSource != null)
            {
                BtnDetailOpenSource.Visibility = (item.IsStudioTask && !item.IsConverted) ? Visibility.Collapsed : Visibility.Visible;
            }

            if (BtnDetailHandoverZip != null)
            {
                BtnDetailHandoverZip.Visibility = (item.IsStudioTask && !item.IsConverted) ? Visibility.Collapsed : Visibility.Visible;
            }

            // Set Status combobox
            SelectComboItemByContent(DetailStatus, item.Status ?? "backlog");
            SelectComboItemByContent(DetailPriority, item.Priority ?? "medium");
            
            DateTime dtDeadline;
            if (DateTime.TryParse(item.Deadline, out dtDeadline))
                DetailDeadline.SelectedDate = dtDeadline;
            else
                DetailDeadline.SelectedDate = null;

            DateTime dtCreated;
            if (DateTime.TryParse(item.CreatedDate, out dtCreated))
                DetailCreatedDate.SelectedDate = dtCreated;
            else
                DetailCreatedDate.SelectedDate = null;

            if (DetailStartDate != null)
            {
                DateTime dtStart;
                if (DateTime.TryParse(item.StartDate, out dtStart))
                    DetailStartDate.SelectedDate = dtStart;
                else if (DetailCreatedDate.SelectedDate.HasValue)
                    DetailStartDate.SelectedDate = DetailCreatedDate.SelectedDate.Value;
                else
                    DetailStartDate.SelectedDate = null;
            }

            if (DetailDuration != null) DetailDuration.Text = item.Duration ?? "";
            DetailRevision.Text = item.Revision.ToString();
            if (DetailDesigner != null) DetailDesigner.Text = item.Designer ?? "";

            // Populate Subtasks section
            _editingSubtaskId = null;
            if (SubtaskEditorCard != null) SubtaskEditorCard.Visibility = Visibility.Collapsed;
            PopulateDetailSubtasks(item);

            // Load README body content notes
            string body = item.IsStudioTask
                ? StudioTaskService.ReadStudioTaskBody(item.FullPath)
                : FrontmatterService.ReadBody(item.FullPath);
            DetailReadmePreview.Text = body ?? "";
            DetailReadmeRendered.Document = MarkdownHelper.ToFlowDocument(body);

            // Default to Preview Mode
            SwitchToReadmePreviewMode();

            // Check collision status & acquire lease if not in conflict
            UpdateCollisionStatus(item.FullPath);
            LockCheckResult lockCheck = FileCollisionGuardService.Instance.CheckLock(item.FullPath);
            if (lockCheck == null || !lockCheck.IsConflict)
            {
                FileCollisionGuardService.Instance.AcquireLock(
                    item.FullPath,
                    item.ProjectId,
                    Environment.UserName,
                    Environment.UserName);
            }

            DetailSaveStatus.Text = "";
            _isPopulatingDetail = false;
        }

        private void UpdateCollisionStatus(string projectPath)
        {
            if (string.IsNullOrWhiteSpace(projectPath) || CollisionAlertCard == null) return;

            try
            {
                LockCheckResult check = FileCollisionGuardService.Instance.CheckLock(projectPath);
                if (check != null && check.IsConflict && check.LockInfo != null)
                {
                    CollisionAlertCard.Visibility = Visibility.Visible;
                    if (TxtCollisionHeadline != null)
                    {
                        TxtCollisionHeadline.Text = string.Format("Active Editor: {0} ({1})", check.LockInfo.EditorName, check.LockInfo.Machine);
                    }
                    if (TxtCollisionDetails != null)
                    {
                        TxtCollisionDetails.Text = string.Format("Locked {0} via {1}. Any saves may overwrite concurrent changes.", check.LockInfo.FormattedDuration, check.LockInfo.Platform);
                    }
                }
                else
                {
                    CollisionAlertCard.Visibility = Visibility.Collapsed;
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TaskManagerPage] UpdateCollisionStatus error: " + ex.Message);
            }
        }

        private void OnReloadConflictClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null || string.IsNullOrWhiteSpace(_editingProject.FullPath)) return;
            try
            {
                ProjectStatusItem refreshed = FrontmatterService.ReadStatus(_editingProject.FullPath);
                if (refreshed != null)
                {
                    _editingProject = refreshed;
                    PopulateDetail(_editingProject);
                    NotificationService.ShowInfo("Project Reloaded", "Latest project state loaded from storage.");
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TaskManagerPage] OnReloadConflictClicked error: " + ex.Message);
            }
        }

        private void OnTakeoverLockClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null || string.IsNullOrWhiteSpace(_editingProject.FullPath)) return;
            try
            {
                System.Windows.MessageBoxResult confirm = System.Windows.MessageBox.Show(
                    "Are you sure you want to take over this editing lock?\n\nThe previous designer's lock lease will be superseded for this project.",
                    "Confirm Take Over Lock",
                    System.Windows.MessageBoxButton.YesNo,
                    System.Windows.MessageBoxImage.Warning);

                if (confirm == System.Windows.MessageBoxResult.Yes)
                {
                    bool ok = FileCollisionGuardService.Instance.TakeoverLock(
                        _editingProject.FullPath,
                        _editingProject.ProjectId,
                        Environment.UserName,
                        Environment.UserName);

                    if (ok)
                    {
                        if (CollisionAlertCard != null) CollisionAlertCard.Visibility = Visibility.Collapsed;
                        NotificationService.ShowSuccess("Lock Acquired", "You now hold the active editing lease for this project.");
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TaskManagerPage] OnTakeoverLockClicked error: " + ex.Message);
            }
        }

        private void OnDateChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_isPopulatingDetail) return;
            
            DateTime? start = DetailStartDate != null && DetailStartDate.SelectedDate.HasValue
                ? DetailStartDate.SelectedDate
                : (DetailCreatedDate != null ? DetailCreatedDate.SelectedDate : null);

            if (start.HasValue && DetailDeadline != null && DetailDeadline.SelectedDate.HasValue && DetailDuration != null)
            {
                TimeSpan diff = DetailDeadline.SelectedDate.Value - start.Value;
                if (diff.TotalDays == 0)
                {
                    DetailDuration.Text = "Same day";
                }
                else if (diff.TotalDays > 0)
                {
                    int days = (int)diff.TotalDays;
                    DetailDuration.Text = days == 1 ? "1 day" : string.Format("{0} days", days);
                }
                else
                {
                    DetailDuration.Text = "Overdue";
                }
            }
        }

        private void OnReadmeModePreviewClicked(object sender, RoutedEventArgs e)
        {
            SwitchToReadmePreviewMode();
        }

        private void OnReadmeModeEditClicked(object sender, RoutedEventArgs e)
        {
            SwitchToReadmeEditMode();
        }

        private void SwitchToReadmePreviewMode()
        {
            if (ReadmeEditToolbar != null) ReadmeEditToolbar.Visibility = Visibility.Collapsed;
            if (DetailReadmePreview != null && DetailReadmeRendered != null)
            {
                DetailReadmeRendered.Document = MarkdownHelper.ToFlowDocument(DetailReadmePreview.Text);
                DetailReadmeRendered.Visibility = Visibility.Visible;
                DetailReadmePreview.Visibility = Visibility.Collapsed;
            }
            if (BtnModePreview != null) BtnModePreview.Appearance = ControlAppearance.Primary;
            if (BtnModeEdit != null) BtnModeEdit.Appearance = ControlAppearance.Secondary;
        }

        private void SwitchToReadmeEditMode()
        {
            if (ReadmeEditToolbar != null) ReadmeEditToolbar.Visibility = Visibility.Visible;
            if (DetailReadmePreview != null && DetailReadmeRendered != null)
            {
                DetailReadmeRendered.Visibility = Visibility.Collapsed;
                DetailReadmePreview.Visibility = Visibility.Visible;
            }
            if (BtnModePreview != null) BtnModePreview.Appearance = ControlAppearance.Secondary;
            if (BtnModeEdit != null) BtnModeEdit.Appearance = ControlAppearance.Primary;
        }

        private void ApplyMarkdownWrap(string prefix, string suffix = null, bool lineStart = false)
        {
            if (DetailReadmePreview == null) return;
            suffix = suffix ?? prefix;
            string sel = DetailReadmePreview.SelectedText;
            int start = DetailReadmePreview.SelectionStart;
            int length = DetailReadmePreview.SelectionLength;

            string replacement;
            int newCaret;

            if (lineStart)
            {
                replacement = prefix + (string.IsNullOrEmpty(sel) ? "Item" : sel);
                newCaret = start + replacement.Length;
            }
            else if (!string.IsNullOrEmpty(sel))
            {
                replacement = prefix + sel + suffix;
                newCaret = start + replacement.Length;
            }
            else
            {
                replacement = prefix + "text" + suffix;
                newCaret = start + prefix.Length;
            }

            DetailReadmePreview.SelectedText = replacement;
            if (length == 0)
            {
                DetailReadmePreview.Select(start + prefix.Length, 4);
            }
            else
            {
                DetailReadmePreview.SelectionStart = newCaret;
            }
            DetailReadmePreview.Focus();
        }

        private void OnMdBold(object sender, RoutedEventArgs e)
        {
            ApplyMarkdownWrap("**");
        }

        private void OnMdItalic(object sender, RoutedEventArgs e)
        {
            ApplyMarkdownWrap("*");
        }

        private void OnMdCode(object sender, RoutedEventArgs e)
        {
            ApplyMarkdownWrap("`");
        }

        private void OnMdH2(object sender, RoutedEventArgs e)
        {
            ApplyMarkdownWrap("## ", "", true);
        }

        private void OnMdList(object sender, RoutedEventArgs e)
        {
            ApplyMarkdownWrap("- ", "", true);
        }

        private void OnMdTable(object sender, RoutedEventArgs e)
        {
            if (DetailReadmePreview == null) return;
            string table = "\n| Item / Angle | Script / Copy | Status |\n| :--- | :--- | :--- |\n| **Hook 1** | Stop scrolling if you want... | `Draft` |\n| **Body Offer** | Exclusive bundle promo | `Ready` |\n| **CTA** | Click the link below | `Ready` |\n";
            int pos = DetailReadmePreview.SelectionStart;
            DetailReadmePreview.Text = DetailReadmePreview.Text.Insert(pos, table);
            DetailReadmePreview.SelectionStart = pos + table.Length;
            DetailReadmePreview.Focus();
        }

        private void OnMdLink(object sender, RoutedEventArgs e)
        {
            ApplyMarkdownWrap("[", "](https://)");
        }

        private void OnMdImage(object sender, RoutedEventArgs e)
        {
            ApplyMarkdownWrap("![", "](image_path)");
        }

        private void OnMdAttachment(object sender, RoutedEventArgs e)
        {
            ApplyMarkdownWrap("[📎 ", "](attachment_path)");
        }

        private void OnOpenRawReadmeClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null || string.IsNullOrWhiteSpace(_editingProject.FullPath)) return;
            string readmePath = System.IO.Path.Combine(_editingProject.FullPath, "README.md");

            try
            {
                if (!System.IO.File.Exists(readmePath))
                {
                    FrontmatterService.WriteStatus(_editingProject);
                }

                if (System.IO.File.Exists(readmePath))
                {
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = readmePath,
                        UseShellExecute = true
                    });
                }
            }
            catch (Exception ex)
            {
                DetailSaveStatus.Text = "Cannot open README: " + ex.Message;
            }
        }

        private void OnDetailClose(object sender, RoutedEventArgs e)
        {
            if (_editingProject != null && !string.IsNullOrWhiteSpace(_editingProject.FullPath))
            {
                FileCollisionGuardService.Instance.ReleaseLock(_editingProject.FullPath);
            }
            if (CollisionAlertCard != null)
            {
                CollisionAlertCard.Visibility = Visibility.Collapsed;
            }
            DetailPanel.Visibility = Visibility.Collapsed;
            _editingProject = null;
        }

        private void OnRevisionDecrementClicked(object sender, RoutedEventArgs e)
        {
            int val;
            if (int.TryParse(DetailRevision.Text, out val))
            {
                val = Math.Max(0, val - 1);
                DetailRevision.Text = val.ToString();
            }
            else
            {
                DetailRevision.Text = "0";
            }
        }

        private void OnRevisionIncrementClicked(object sender, RoutedEventArgs e)
        {
            int val;
            if (!int.TryParse(DetailRevision.Text, out val))
            {
                val = 0;
            }
            val++;
            DetailRevision.Text = val.ToString();
        }

        private void OnDetailSave(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null) return;

            // Check collision guard before saving
            LockCheckResult lockCheck = FileCollisionGuardService.Instance.CheckLock(_editingProject.FullPath);
            if (lockCheck != null && lockCheck.IsConflict && lockCheck.LockInfo != null)
            {
                string warn = string.Format(
                    "CONCURRENT COLLISION WARNING:\n\n" +
                    "{0} on machine '{1}' is actively editing this project ({2})!\n\n" +
                    "Saving now may overwrite their concurrent modifications.\n\n" +
                    "Do you still want to force save and overwrite?",
                    lockCheck.LockInfo.EditorName,
                    lockCheck.LockInfo.Machine,
                    lockCheck.LockInfo.FormattedDuration);

                System.Windows.MessageBoxResult res = System.Windows.MessageBox.Show(warn, "Concurrent Collision Warning", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning);
                if (res != System.Windows.MessageBoxResult.Yes)
                {
                    DetailSaveStatus.Text = "Save canceled (Collision avoided)";
                    return;
                }
            }

            if (DetailStatus.SelectedItem is ComboBoxItem)
                _editingProject.Status = ((ComboBoxItem)DetailStatus.SelectedItem).Content.ToString();
            if (DetailPriority.SelectedItem is ComboBoxItem)
                _editingProject.Priority = ((ComboBoxItem)DetailPriority.SelectedItem).Content.ToString();
            
            _editingProject.Deadline = DetailDeadline.SelectedDate.HasValue 
                ? DetailDeadline.SelectedDate.Value.ToString("yyyy-MM-dd") 
                : "";
            
            if (DetailCreatedDate != null) 
            {
                _editingProject.CreatedDate = DetailCreatedDate.SelectedDate.HasValue 
                    ? DetailCreatedDate.SelectedDate.Value.ToString("yyyy-MM-dd") 
                    : "";
            }

            if (DetailStartDate != null)
            {
                _editingProject.StartDate = DetailStartDate.SelectedDate.HasValue 
                    ? DetailStartDate.SelectedDate.Value.ToString("yyyy-MM-dd") 
                    : "";
            }

            if (DetailDuration != null)
                _editingProject.Duration = DetailDuration.Text.Trim();

            if (DetailDesigner != null)
                _editingProject.Designer = DetailDesigner.Text.Trim();

            int revVal;
            if (int.TryParse(DetailRevision.Text, out revVal))
            {
                _editingProject.Revision = revVal;
            }

            string newBody = DetailReadmePreview.Text;

            try
            {
                if (_editingProject.IsStudioTask)
                {
                    StudioTaskService.SaveStudioTask(_editingProject, newBody);
                    DetailSaveStatus.Text = "Saved to task markdown \u2713";
                }
                else
                {
                    FrontmatterService.WriteStatusAndBody(_editingProject, newBody);
                    DetailSaveStatus.Text = "Saved to README.md \u2713";
                }

                // Update rendered markdown preview document
                DetailReadmeRendered.Document = MarkdownHelper.ToFlowDocument(newBody);

                // Refresh metrics & board
                PopulateDesignerFilter();
                UpdateMetricSummaryCards();
                ApplyFiltersAndUpdateBoard();
            }
            catch (Exception ex)
            {
                DetailSaveStatus.Text = string.Format("Error: {0}", ex.Message);
            }
        }

        private void OnDetailHandoverClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null) return;
            string newOwner = DetailDesigner != null ? DetailDesigner.Text.Trim() : "";
            if (string.IsNullOrWhiteSpace(newOwner))
            {
                DetailSaveStatus.Text = "Please specify a designer name.";
                return;
            }

            string oldOwner = !string.IsNullOrWhiteSpace(_editingProject.Designer) ? _editingProject.Designer : "Unassigned";
            _editingProject.Designer = newOwner;

            if (DetailStatus.SelectedItem is ComboBoxItem)
                _editingProject.Status = ((ComboBoxItem)DetailStatus.SelectedItem).Content.ToString();
            if (DetailPriority.SelectedItem is ComboBoxItem)
                _editingProject.Priority = ((ComboBoxItem)DetailPriority.SelectedItem).Content.ToString();

            _editingProject.Deadline = DetailDeadline.SelectedDate.HasValue 
                ? DetailDeadline.SelectedDate.Value.ToString("yyyy-MM-dd") 
                : "";

            if (DetailCreatedDate != null) 
            {
                _editingProject.CreatedDate = DetailCreatedDate.SelectedDate.HasValue 
                    ? DetailCreatedDate.SelectedDate.Value.ToString("yyyy-MM-dd") 
                    : "";
            }

            if (DetailStartDate != null)
            {
                _editingProject.StartDate = DetailStartDate.SelectedDate.HasValue 
                    ? DetailStartDate.SelectedDate.Value.ToString("yyyy-MM-dd") 
                    : "";
            }

            if (DetailDuration != null)
                _editingProject.Duration = DetailDuration.Text.Trim();

            int revVal;
            if (int.TryParse(DetailRevision.Text, out revVal))
                _editingProject.Revision = revVal;

            string newBody = DetailReadmePreview.Text;

            try
            {
                if (_editingProject.IsStudioTask)
                {
                    StudioTaskService.SaveStudioTask(_editingProject, newBody);
                }
                else
                {
                    FrontmatterService.WriteStatusAndBody(_editingProject, newBody);
                }
                DetailSaveStatus.Text = string.Format("Handed over to {0} \u2713", newOwner);
                DetailReadmeRendered.Document = MarkdownHelper.ToFlowDocument(newBody);

                NotificationService.ShowSuccess(
                    "Task Handed Over",
                    string.Format("Project '{0}' handed over from {1} to {2}.", _editingProject.Project, oldOwner, newOwner),
                    _editingProject.FullPath);

                PopulateDesignerFilter();
                UpdateMetricSummaryCards();
                ApplyFiltersAndUpdateBoard();
            }
            catch (Exception ex)
            {
                DetailSaveStatus.Text = string.Format("Error: {0}", ex.Message);
            }
        }

        private void PopulateDetailSubtasks(ProjectStatusItem item)
        {
            if (item == null) return;
            try
            {
                if (ListDetailSubtasks != null)
                {
                    ListDetailSubtasks.ItemsSource = null;
                    ListDetailSubtasks.ItemsSource = item.Subtasks;
                }
                if (DetailSubtasksProgressBar != null)
                {
                    DetailSubtasksProgressBar.Value = item.SubtaskProgressPercent;
                }
                if (TxtDetailSubtasksProgress != null)
                {
                    TxtDetailSubtasksProgress.Text = string.Format("({0}/{1} Done • {2:0.#} pts)", item.CompletedSubtasksCount, item.TotalSubtasksCount, item.TotalWeight);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[TaskManagerPage] PopulateDetailSubtasks error: " + ex.Message);
            }
        }

        private void OnSubtaskStatusToggleClicked(object sender, RoutedEventArgs e)
        {
            FrameworkElement btn = sender as FrameworkElement;
            string subtaskId = btn != null ? btn.Tag as string : null;
            if (string.IsNullOrWhiteSpace(subtaskId) || _editingProject == null || _editingProject.Subtasks == null) return;

            var st = _editingProject.Subtasks.Find(s => string.Equals(s.Id, subtaskId, StringComparison.OrdinalIgnoreCase));
            if (st == null) return;

            // Cycle: Draft -> In Progress -> Done -> Draft
            string currentStatus = (st.Status ?? "draft").ToLowerInvariant().Trim();
            if (currentStatus == "draft") st.Status = "in-progress";
            else if (currentStatus == "in-progress" || currentStatus == "progress" || currentStatus == "review" || currentStatus == "revision") st.Status = "done";
            else st.Status = "draft";

            // Save immediately
            if (_editingProject.IsStudioTask)
                StudioTaskService.SaveStudioTask(_editingProject, null);
            else
                FrontmatterService.WriteStatus(_editingProject);
            PopulateDetailSubtasks(_editingProject);
            ApplyFiltersAndUpdateBoard();
            UpdateMetricSummaryCards();
        }

        private void OnAddSubtaskClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null) return;
            if (_editingProject.Subtasks == null) _editingProject.Subtasks = new List<ProjectSubtaskItem>();

            int nextNum = _editingProject.Subtasks.Count + 1;
            bool isVideo = (!string.IsNullOrEmpty(_editingProject.Project) && _editingProject.Project.IndexOf("V_", StringComparison.OrdinalIgnoreCase) >= 0);
            string id = string.Format("{0}{1:D2}", isVideo ? "V" : "KV", nextNum);
            string name = isVideo ? (nextNum == 1 ? "Master Story Cut 60s" : string.Format("Hook Variation {0} 15s", (char)('A' + nextNum - 2))) : string.Format("Key Visual {0}", nextNum);
            double weight = isVideo ? (nextNum == 1 ? 2.0 : 0.4) : (nextNum == 1 ? 1.0 : 0.2);

            _editingSubtaskId = null; // New item mode
            if (TxtSubtaskEditorTitle != null) TxtSubtaskEditorTitle.Text = "Add Deliverable / Subtask";
            if (EditSubtaskId != null) EditSubtaskId.Text = id;
            if (EditSubtaskName != null) EditSubtaskName.Text = name;
            if (EditSubtaskSpecs != null) SelectOrSetComboBoxItem(EditSubtaskSpecs, isVideo ? "9:16, 1080x1920" : "1:1, 1080x1080");
            if (EditSubtaskType != null) SelectOrSetComboBoxItem(EditSubtaskType, isVideo ? (nextNum == 1 ? "master_video" : "hook_variation") : (nextNum == 1 ? "key_visual" : "resize"));
            if (EditSubtaskWeight != null) SelectOrSetComboBoxWeight(EditSubtaskWeight, weight);
            if (EditSubtaskStatus != null) EditSubtaskStatus.SelectedIndex = 0; // Default: Draft

            if (SubtaskEditorCard != null)
            {
                SubtaskEditorCard.Visibility = Visibility.Visible;
                if (EditSubtaskName != null) EditSubtaskName.Focus();
            }
        }

        private static void SelectOrSetComboBoxItem(ComboBox combo, string text)
        {
            if (combo == null) return;
            if (string.IsNullOrWhiteSpace(text)) { combo.Text = string.Empty; return; }

            foreach (var item in combo.Items)
            {
                ComboBoxItem cbi = item as ComboBoxItem;
                string content = cbi != null ? cbi.Content as string : item as string;
                if (!string.IsNullOrEmpty(content) && (content.Equals(text, StringComparison.OrdinalIgnoreCase) || content.StartsWith(text, StringComparison.OrdinalIgnoreCase)))
                {
                    combo.SelectedItem = item;
                    return;
                }
            }
            combo.Text = text;
        }

        private static void SelectOrSetComboBoxWeight(ComboBox combo, double weight)
        {
            if (combo == null) return;
            string weightStr = weight.ToString("0.#", System.Globalization.CultureInfo.InvariantCulture);

            foreach (var item in combo.Items)
            {
                ComboBoxItem cbi = item as ComboBoxItem;
                string content = cbi != null ? cbi.Content as string : item as string;
                if (!string.IsNullOrEmpty(content) && content.StartsWith(weightStr, StringComparison.OrdinalIgnoreCase))
                {
                    combo.SelectedItem = item;
                    return;
                }
            }
            combo.Text = string.Format("{0:0.#} pts", weight);
        }

        private void OnEditSubtaskClicked(object sender, RoutedEventArgs e)
        {
            FrameworkElement btn = sender as FrameworkElement;
            string subtaskId = btn != null ? btn.Tag as string : null;
            if (string.IsNullOrWhiteSpace(subtaskId) || _editingProject == null || _editingProject.Subtasks == null) return;

            var st = _editingProject.Subtasks.Find(s => string.Equals(s.Id, subtaskId, StringComparison.OrdinalIgnoreCase));
            if (st == null) return;

            _editingSubtaskId = st.Id;
            if (TxtSubtaskEditorTitle != null) TxtSubtaskEditorTitle.Text = string.Format("Edit Deliverable: {0}", st.Id);
            if (EditSubtaskId != null) EditSubtaskId.Text = st.Id ?? "";
            if (EditSubtaskName != null) EditSubtaskName.Text = st.Name ?? "";
            if (EditSubtaskSpecs != null) SelectOrSetComboBoxItem(EditSubtaskSpecs, st.Specs ?? "");
            if (EditSubtaskType != null) SelectOrSetComboBoxItem(EditSubtaskType, st.Type ?? "");
            if (EditSubtaskWeight != null) SelectOrSetComboBoxWeight(EditSubtaskWeight, st.Weight);

            if (EditSubtaskStatus != null)
            {
                string norm = (st.Status ?? "draft").ToLowerInvariant().Trim();
                if (norm == "done" || norm == "approved") EditSubtaskStatus.SelectedIndex = 2;
                else if (norm == "in-progress" || norm == "progress" || norm == "review" || norm == "revision") EditSubtaskStatus.SelectedIndex = 1;
                else EditSubtaskStatus.SelectedIndex = 0; // Draft
            }

            if (SubtaskEditorCard != null)
            {
                SubtaskEditorCard.Visibility = Visibility.Visible;
                if (EditSubtaskName != null) EditSubtaskName.Focus();
            }
        }

        private void OnCancelSubtaskEditClicked(object sender, RoutedEventArgs e)
        {
            _editingSubtaskId = null;
            if (SubtaskEditorCard != null)
            {
                SubtaskEditorCard.Visibility = Visibility.Collapsed;
            }
        }

        private void OnSaveSubtaskEditClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null) return;
            if (_editingProject.Subtasks == null) _editingProject.Subtasks = new List<ProjectSubtaskItem>();

            string id = EditSubtaskId != null ? EditSubtaskId.Text.Trim() : "";
            string name = EditSubtaskName != null ? EditSubtaskName.Text.Trim() : "";
            string specs = EditSubtaskSpecs != null ? EditSubtaskSpecs.Text.Trim() : "";
            string type = EditSubtaskType != null ? EditSubtaskType.Text.Trim() : "";
            string weightRaw = EditSubtaskWeight != null ? EditSubtaskWeight.Text.Trim() : "";

            if (string.IsNullOrWhiteSpace(id)) id = string.Format("ST{0:D2}", _editingProject.Subtasks.Count + 1);
            if (string.IsNullOrWhiteSpace(name)) name = "Untitled Deliverable";
            if (string.IsNullOrWhiteSpace(specs)) specs = "1080x1080";
            if (string.IsNullOrWhiteSpace(type)) type = "artwork";

            // Clean specs if selected from verbose combo item like "9:16, 1080x1920 (Reels...)"
            if (specs.Contains("(") && specs.IndexOf("(") > 3)
            {
                specs = specs.Substring(0, specs.IndexOf("(")).Trim();
            }

            // Parse weight safely
            double weight = 1.0;
            if (!string.IsNullOrWhiteSpace(weightRaw))
            {
                string match = System.Text.RegularExpressions.Regex.Match(weightRaw, @"\d+(\.\d+)?").Value;
                if (!double.TryParse(match, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out weight))
                {
                    weight = 1.0;
                }
            }

            // Map status
            string status = "draft";
            if (EditSubtaskStatus != null)
            {
                if (EditSubtaskStatus.SelectedIndex == 1) status = "in-progress";
                else if (EditSubtaskStatus.SelectedIndex == 2) status = "done";
                else status = "draft";
            }

            if (!string.IsNullOrWhiteSpace(_editingSubtaskId))
            {
                var existing = _editingProject.Subtasks.Find(s => string.Equals(s.Id, _editingSubtaskId, StringComparison.OrdinalIgnoreCase));
                if (existing != null)
                {
                    existing.Id = id;
                    existing.Name = name;
                    existing.Specs = specs;
                    existing.Type = type;
                    existing.Weight = weight;
                    existing.Status = status;
                }
                NotificationService.ShowSuccess("Deliverable Updated", string.Format("Updated '{0}' ({1:0.#} pts)", name, weight), _editingProject.FullPath);
            }
            else
            {
                var newItem = new ProjectSubtaskItem
                {
                    Id = id,
                    Name = name,
                    Specs = specs,
                    Type = type,
                    Weight = weight,
                    Status = status,
                    AssignedDesigner = _editingProject.Designer ?? ""
                };
                _editingProject.Subtasks.Add(newItem);
                NotificationService.ShowSuccess("Deliverable Added", string.Format("Added '{0}' ({1:0.#} pts)", name, weight), _editingProject.FullPath);
            }

            _editingSubtaskId = null;
            if (SubtaskEditorCard != null) SubtaskEditorCard.Visibility = Visibility.Collapsed;

            if (_editingProject.IsStudioTask)
                StudioTaskService.SaveStudioTask(_editingProject, null);
            else
                FrontmatterService.WriteStatus(_editingProject);
            PopulateDetailSubtasks(_editingProject);
            ApplyFiltersAndUpdateBoard();
            UpdateMetricSummaryCards();
        }

        private void OnRemoveSubtaskClicked(object sender, RoutedEventArgs e)
        {
            FrameworkElement btn = sender as FrameworkElement;
            string subtaskId = btn != null ? btn.Tag as string : null;
            if (string.IsNullOrWhiteSpace(subtaskId) || _editingProject == null || _editingProject.Subtasks == null) return;

            var st = _editingProject.Subtasks.Find(s => string.Equals(s.Id, subtaskId, StringComparison.OrdinalIgnoreCase));
            if (st != null)
            {
                if (string.Equals(_editingSubtaskId, st.Id, StringComparison.OrdinalIgnoreCase))
                {
                    _editingSubtaskId = null;
                    if (SubtaskEditorCard != null) SubtaskEditorCard.Visibility = Visibility.Collapsed;
                }
                _editingProject.Subtasks.Remove(st);
                if (_editingProject.IsStudioTask)
                    StudioTaskService.SaveStudioTask(_editingProject, null);
                else
                    FrontmatterService.WriteStatus(_editingProject);
                PopulateDetailSubtasks(_editingProject);
                ApplyFiltersAndUpdateBoard();
                UpdateMetricSummaryCards();
            }
        }

        private void OnDetailCopyProjectIdClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null) return;

            string projectId = null;
            if (_editingProject.IsStudioTask)
            {
                if (!string.IsNullOrWhiteSpace(_editingProject.ConvertedJobId))
                    projectId = _editingProject.ConvertedJobId;
                else if (!string.IsNullOrWhiteSpace(_editingProject.ConvertedProjectId))
                    projectId = _editingProject.ConvertedProjectId;
                else
                    projectId = _editingProject.TaskId;
            }
            else
            {
                projectId = !string.IsNullOrWhiteSpace(_editingProject.ProjectId)
                    ? _editingProject.ProjectId
                    : ProjectStatusItem.ExtractProjectId(_editingProject.Project);

                if (string.IsNullOrWhiteSpace(projectId) && DetailReadmePreview != null && !string.IsNullOrWhiteSpace(DetailReadmePreview.Text))
                {
                    Match m = Regex.Match(DetailReadmePreview.Text, @"(?:^|\n)\s*-\s*\*{0,2}Project ID\*{0,2}\s*:\s*([A-Za-z0-9_-]+)", RegexOptions.IgnoreCase);
                    if (m.Success)
                    {
                        projectId = m.Groups[1].Value.Trim();
                    }
                }

                if (string.IsNullOrWhiteSpace(projectId))
                {
                    projectId = _editingProject.Project ?? string.Empty;
                }
            }

            if (!string.IsNullOrWhiteSpace(projectId))
            {
                try
                {
                    ClipboardService.SetText(projectId);
                    if (DetailSaveStatus != null)
                    {
                        DetailSaveStatus.Text = string.Format("Copied ID '{0}' \u2713", projectId);
                    }
                    NotificationService.ShowSuccess("Copied ID", string.Format("ID '{0}' copied to clipboard.", projectId), _editingProject.FullPath);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[TaskManagerPage] CopyProjectId error: " + ex.Message);
                    if (DetailSaveStatus != null)
                    {
                        DetailSaveStatus.Text = "Failed to copy ID";
                    }
                }
            }
            else
            {
                if (DetailSaveStatus != null)
                {
                    DetailSaveStatus.Text = "ID not found";
                }
            }
        }

        private void OnDetailOpenFolderClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null) return;

            string targetFolder = null;
            if (Directory.Exists(_editingProject.FullPath))
            {
                targetFolder = _editingProject.FullPath;
            }
            else if (File.Exists(_editingProject.FullPath))
            {
                targetFolder = Path.GetDirectoryName(_editingProject.FullPath);
            }

            if (!string.IsNullOrEmpty(targetFolder) && Directory.Exists(targetFolder))
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = targetFolder,
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[TaskManagerPage] OpenFolder error: " + ex.Message);
                }
            }
        }

        private void OnDetailOpenSourceClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject != null && Directory.Exists(_editingProject.FullPath))
            {
                string srcDir = Path.Combine(_editingProject.FullPath, "02_SOURCE_FILES");
                string targetFile = null;
                if (Directory.Exists(srcDir))
                {
                    string[] files = Directory.GetFiles(srcDir);
                    foreach (string f in files)
                    {
                        string ext = Path.GetExtension(f).ToLowerInvariant();
                        if (ext == ".afdesign" || ext == ".psd" || ext == ".ai" || ext == ".afphoto" || ext == ".afpub")
                        {
                            targetFile = f;
                            break;
                        }
                    }
                }

                if (targetFile != null && File.Exists(targetFile))
                {
                    try
                    {
                        Process.Start(new ProcessStartInfo
                        {
                            FileName = targetFile,
                            UseShellExecute = true
                        });
                        NotificationService.ShowInfo("Launching Source File", Path.GetFileName(targetFile));
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("[TaskManagerPage] OpenSource error: " + ex.Message);
                    }
                }
                else
                {
                    System.Windows.MessageBox.Show("No working source file (.afdesign, .psd, .ai) found in 02_SOURCE_FILES.", "Source File Not Found", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Information);
                }
            }
        }

        private void OnDetailSnapshotsClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null || !Directory.Exists(_editingProject.FullPath)) return;
            try
            {
                ProjectSnapshotsDialog dlg = new ProjectSnapshotsDialog(_editingProject.FullPath, _editingProject.ProjectId, _editingProject.Project);
                dlg.Owner = Window.GetWindow(this);
                bool? result = dlg.ShowDialog();
                if (result == true)
                {
                    PopulateDetail(_editingProject);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TaskManagerPage] OnDetailSnapshotsClicked error: " + ex.Message);
            }
        }

        private async void OnDetailHandoverZipClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null || !Directory.Exists(_editingProject.FullPath)) return;

            SaveFileDialog sfd = new SaveFileDialog
            {
                Title = "Export Creative Handover Package (ZIP)",
                Filter = "ZIP Archive (*.zip)|*.zip",
                FileName = string.Format("{0}_Handover.zip", _editingProject.Project),
                InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Desktop)
            };

            if (sfd.ShowDialog() == true)
            {
                ExportPackageOptions options = new ExportPackageOptions
                {
                    IncludeDeliverables = true,
                    IncludeCopywriting = true,
                    IncludeBriefMarkdown = true,
                    IncludeHtmlSummary = true,
                    IncludeWipMockups = false
                };

                ExportPackageResult res = await ExportPackagingService.CreateHandoverPackageAsync(_editingProject.FullPath, sfd.FileName, options);
                if (res != null && res.Success)
                {
                    NotificationService.ShowSuccess("Handover Exported", string.Format("Packaged {0} files into {1}", res.FileCount, Path.GetFileName(res.ZipFilePath)));
                    if (System.Windows.MessageBox.Show(string.Format("Creative Handover Package created with {0} files.\n\nOpen destination folder?", res.FileCount), "Export Complete", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Information) == System.Windows.MessageBoxResult.Yes)
                    {
                        try
                        {
                            Process.Start(new ProcessStartInfo
                            {
                                FileName = Path.GetDirectoryName(sfd.FileName),
                                UseShellExecute = true
                            });
                        }
                        catch (Exception ex)
                        {
                            Debug.WriteLine("[TaskManagerPage] Open exported folder error: " + ex.Message);
                        }
                    }
                }
                else
                {
                    System.Windows.MessageBox.Show(res != null ? res.ErrorMessage : "Packaging failed", "Export Error", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
                }
            }
        }

        private void OnAssetDropzoneOver(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                e.Effects = DragDropEffects.Copy;
                e.Handled = true;
                if (CardAssetDropzone != null)
                {
                    CardAssetDropzone.BorderBrush = (System.Windows.Media.Brush)Application.Current.FindResource("FluentBrand80");
                    CardAssetDropzone.BorderThickness = new Thickness(2);
                }
            }
        }

        private void OnAssetDropzoneLeave(object sender, DragEventArgs e)
        {
            if (CardAssetDropzone != null)
            {
                CardAssetDropzone.BorderBrush = (System.Windows.Media.Brush)Application.Current.FindResource("CardStrokeColorDefaultBrush");
                CardAssetDropzone.BorderThickness = new Thickness(1);
            }
        }

        private void OnAssetDropzoneDrop(object sender, DragEventArgs e)
        {
            if (CardAssetDropzone != null)
            {
                CardAssetDropzone.BorderBrush = (System.Windows.Media.Brush)Application.Current.FindResource("CardStrokeColorDefaultBrush");
                CardAssetDropzone.BorderThickness = new Thickness(1);
            }

            if (_editingProject == null || !Directory.Exists(_editingProject.FullPath)) return;

            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                string[] files = (string[])e.Data.GetData(DataFormats.FileDrop);
                if (files != null && files.Length > 0)
                {
                    SmartIngestResult result = SmartIngesterService.Ingest(_editingProject.FullPath, files);

                    if (result.Success && result.TotalIngested > 0)
                    {
                        if (TxtAssetDropHint != null)
                        {
                            TxtAssetDropHint.Text = string.Format("\u2713 Ingested {0} asset(s) successfully!", result.TotalIngested);
                        }
                        NotificationService.ShowSuccess("Assets Ingested", string.Format("Ingested {0} asset(s) into project vault.", result.TotalIngested), _editingProject.FullPath);
                    }
                    else if (!result.Success)
                    {
                        NotificationService.ShowError("Ingestion Failed", result.ErrorMessage ?? "Could not ingest dropped files.");
                    }
                }
            }
        }

        // ─── Studio Task & NAS Workspace Provisioning Bridge ──────────────────

        private async void OnDetailProvisionClicked(object sender, RoutedEventArgs e)
        {
            if (_editingProject == null || !_editingProject.IsStudioTask) return;

            string designer = !string.IsNullOrWhiteSpace(_editingProject.Designer) ? _editingProject.Designer : "Unassigned";
            string brand = !string.IsNullOrWhiteSpace(_editingProject.TaskBrand) ? _editingProject.TaskBrand : "SS";

            var confirmResult = System.Windows.MessageBox.Show(
                string.Format("Provision heavy NAS project workspace for '{0}'?\n\nDesigner: {1}\nBrand: {2}\n\nThis will assign a Job ID and scaffold the 5 production folders on the NAS.",
                    _editingProject.Project, designer, brand),
                "Provision NAS Workspace",
                System.Windows.MessageBoxButton.YesNo,
                System.Windows.MessageBoxImage.Question);

            if (confirmResult != System.Windows.MessageBoxResult.Yes) return;

            if (BtnDetailProvision != null) BtnDetailProvision.IsEnabled = false;
            if (DetailSaveStatus != null) DetailSaveStatus.Text = "Provisioning NAS workspace...";

            try
            {
                var result = await StudioTaskService.ProvisionTaskToProjectAsync(_workspaceRoot, _editingProject);
                if (result.Success)
                {
                    NotificationService.ShowSuccess(
                        "Workspace Provisioned",
                        string.Format("Task upgraded to Project '{0}' ({1})", result.JobId, result.ProjectName),
                        result.ProjectFolder);

                    if (DetailSaveStatus != null) DetailSaveStatus.Text = string.Format("Provisioned as {0} \u2713", result.JobId);

                    // Reload board
                    await LoadProjectsAsync();

                    // Close detail panel
                    DetailPanel.Visibility = Visibility.Collapsed;
                    _editingProject = null;
                }
                else
                {
                    NotificationService.ShowError("Provisioning Failed", result.ErrorMessage ?? "Unknown error occurred.");
                    if (DetailSaveStatus != null) DetailSaveStatus.Text = string.Format("Error: {0}", result.ErrorMessage);
                }
            }
            catch (Exception ex)
            {
                NotificationService.ShowError("Provisioning Error", ex.Message);
                if (DetailSaveStatus != null) DetailSaveStatus.Text = string.Format("Error: {0}", ex.Message);
            }
            finally
            {
                if (BtnDetailProvision != null) BtnDetailProvision.IsEnabled = true;
            }
        }

        private void OnNewStudioTaskClicked(object sender, RoutedEventArgs e)
        {
            if (NewTaskOverlay == null) return;
            if (TxtNewTaskTitle != null) TxtNewTaskTitle.Text = "";
            if (TxtNewTaskBrief != null) TxtNewTaskBrief.Text = "";
            if (DpNewTaskDueDate != null) DpNewTaskDueDate.SelectedDate = DateTime.Today.AddDays(3);
            if (CmbNewTaskBrand != null && CmbNewTaskBrand.Items.Count > 0) CmbNewTaskBrand.SelectedIndex = 0;
            if (CmbNewTaskPriority != null && CmbNewTaskPriority.Items.Count > 2) CmbNewTaskPriority.SelectedIndex = 2; // medium
            
            // Set assignee if designer filter is currently selected
            if (CmbNewTaskAssignee != null)
            {
                string curDesigner = DesignerFilterTM != null && DesignerFilterTM.SelectedItem != null ? DesignerFilterTM.SelectedItem.ToString() : "";
                if (!string.IsNullOrWhiteSpace(curDesigner) && curDesigner != "All Designers")
                {
                    CmbNewTaskAssignee.Text = curDesigner;
                }
                else
                {
                    CmbNewTaskAssignee.Text = "";
                }
            }

            NewTaskOverlay.Visibility = Visibility.Visible;
            if (TxtNewTaskTitle != null) TxtNewTaskTitle.Focus();
        }

        private void OnCancelNewTaskClicked(object sender, RoutedEventArgs e)
        {
            if (NewTaskOverlay != null)
            {
                NewTaskOverlay.Visibility = Visibility.Collapsed;
            }
        }

        private async void OnSubmitNewTaskClicked(object sender, RoutedEventArgs e)
        {
            string title = TxtNewTaskTitle != null ? TxtNewTaskTitle.Text.Trim() : "";
            if (string.IsNullOrWhiteSpace(title))
            {
                System.Windows.MessageBox.Show("Please enter a task title.", "Title Required", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning);
                return;
            }

            string brand = "SS";
            if (CmbNewTaskBrand != null && CmbNewTaskBrand.SelectedItem is ComboBoxItem)
            {
                ComboBoxItem cbi = (ComboBoxItem)CmbNewTaskBrand.SelectedItem;
                if (cbi.Tag != null) brand = cbi.Tag.ToString();
            }

            string priority = "medium";
            if (CmbNewTaskPriority != null && CmbNewTaskPriority.SelectedItem is ComboBoxItem)
            {
                ComboBoxItem priCbi = (ComboBoxItem)CmbNewTaskPriority.SelectedItem;
                if (priCbi.Content != null) priority = priCbi.Content.ToString();
            }

            string assignee = CmbNewTaskAssignee != null ? CmbNewTaskAssignee.Text.Trim() : "";
            string dueDate = DpNewTaskDueDate != null && DpNewTaskDueDate.SelectedDate.HasValue
                ? DpNewTaskDueDate.SelectedDate.Value.ToString("yyyy-MM-dd")
                : "";

            string brief = TxtNewTaskBrief != null ? TxtNewTaskBrief.Text.Trim() : "";

            try
            {
                var taskItem = StudioTaskService.CreateStudioTask(_workspaceRoot, title, brand, priority, assignee, dueDate, brief);
                if (taskItem != null)
                {
                    NotificationService.ShowSuccess("Studio Task Created", string.Format("Task '{0}' created in .sscam/tasks", title), taskItem.FullPath);
                    if (NewTaskOverlay != null) NewTaskOverlay.Visibility = Visibility.Collapsed;

                    await LoadProjectsAsync();
                }
                else
                {
                    NotificationService.ShowError("Creation Failed", "Could not create studio task file.");
                }
            }
            catch (Exception ex)
            {
                NotificationService.ShowError("Error Creating Task", ex.Message);
            }
        }

        private static void SelectComboItemByContent(ComboBox cmb, string value)
        {
            foreach (ComboBoxItem item in cmb.Items)
            {
                if (string.Equals(item.Content.ToString(), value, StringComparison.OrdinalIgnoreCase))
                {
                    cmb.SelectedItem = item;
                    return;
                }
            }
            if (cmb.Items.Count > 0) cmb.SelectedIndex = 0;
        }
    }
}
