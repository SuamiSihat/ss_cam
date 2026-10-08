using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using SS_CAM.Services;
using Wpf.Ui.Controls;
using MessageBox = System.Windows.MessageBox;
using MessageBoxButton = System.Windows.MessageBoxButton;
using MessageBoxImage = System.Windows.MessageBoxImage;
using MessageBoxResult = System.Windows.MessageBoxResult;

namespace SS_CAM.Dialogs
{
    /// <summary>
    /// Interaction logic for ProjectSnapshotsDialog.xaml.
    /// Provides visual revision history, source design asset inspection, and safe rollbacks.
    /// </summary>
    public partial class ProjectSnapshotsDialog : FluentWindow
    {
        private readonly string _projectFullPath;
        private readonly string _projectId;
        private readonly string _projectTitle;

        public bool ProjectWasModified { get; private set; }

        public ProjectSnapshotsDialog(string projectFullPath, string projectId, string projectTitle)
        {
            InitializeComponent();
            _projectFullPath = projectFullPath ?? string.Empty;
            _projectId = projectId ?? string.Empty;
            _projectTitle = projectTitle ?? string.Empty;
            ProjectWasModified = false;

            Loaded += OnWindowLoaded;
        }

        private void OnWindowLoaded(object sender, RoutedEventArgs e)
        {
            try
            {
                if (TxtProjectTitle != null)
                {
                    string display = !string.IsNullOrWhiteSpace(_projectTitle) ? _projectTitle : _projectId;
                    TxtProjectTitle.Text = display;
                }

                if (TxtSnapshotNote != null)
                {
                    TxtSnapshotNote.Text = "Manual milestone snapshot";
                }

                LoadSnapshots();
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[ProjectSnapshotsDialog] OnWindowLoaded error: " + ex.Message);
            }
        }

        private void LoadSnapshots()
        {
            try
            {
                if (string.IsNullOrWhiteSpace(_projectFullPath) || !Directory.Exists(_projectFullPath))
                {
                    ShowEmptyState(true);
                    return;
                }

                List<ProjectSnapshotItem> snapshots = SnapshotDesktopService.GetSnapshots(_projectFullPath);
                if (snapshots == null || snapshots.Count == 0)
                {
                    ShowEmptyState(true);
                    if (ListSnapshots != null) ListSnapshots.ItemsSource = null;
                }
                else
                {
                    ShowEmptyState(false);
                    if (ListSnapshots != null)
                    {
                        ListSnapshots.ItemsSource = snapshots;
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[ProjectSnapshotsDialog] LoadSnapshots error: " + ex.Message);
                ShowEmptyState(true);
            }
        }

        private void ShowEmptyState(bool isEmpty)
        {
            if (PanelEmptyState != null)
            {
                PanelEmptyState.Visibility = isEmpty ? Visibility.Visible : Visibility.Collapsed;
            }
            if (ScrollerSnapshots != null)
            {
                ScrollerSnapshots.Visibility = isEmpty ? Visibility.Collapsed : Visibility.Visible;
            }
        }

        private void OnCaptureSnapshotClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(_projectFullPath) || !Directory.Exists(_projectFullPath))
                {
                    System.Windows.MessageBox.Show("Project folder path is not accessible.", "Cannot Capture Snapshot", MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }

                string note = TxtSnapshotNote != null ? TxtSnapshotNote.Text.Trim() : string.Empty;
                if (string.IsNullOrWhiteSpace(note))
                {
                    note = "Manual studio snapshot";
                }

                bool includeSource = ChkIncludeSource != null && ChkIncludeSource.IsChecked == true;
                string actor = Environment.UserName;

                ProjectSnapshotItem item = SnapshotDesktopService.CreateSnapshot(
                    _projectFullPath,
                    "MANUAL_USER_SNAPSHOT",
                    actor,
                    note,
                    includeSource);

                if (item != null)
                {
                    System.Windows.MessageBox.Show(
                        string.Format("Snapshot '{0}' created successfully!\nRevision: Rev {1}\nSource Files: {2}", item.Id, item.Revision, item.SourceFilesSummary),
                        "Snapshot Captured",
                        MessageBoxButton.OK,
                        MessageBoxImage.Information);

                    if (TxtSnapshotNote != null)
                    {
                        TxtSnapshotNote.Text = string.Empty;
                    }

                    LoadSnapshots();
                }
                else
                {
                    System.Windows.MessageBox.Show("Failed to create snapshot. Please check project folder permissions.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[ProjectSnapshotsDialog] OnCaptureSnapshotClicked error: " + ex.Message);
                System.Windows.MessageBox.Show("Error capturing snapshot: " + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void OnRollbackClicked(object sender, RoutedEventArgs e)
        {
            FrameworkElement btn = sender as FrameworkElement;
            string snapshotId = btn != null ? btn.Tag as string : null;

            if (string.IsNullOrWhiteSpace(snapshotId)) return;

            string confirmMsg = string.Format(
                "Are you sure you want to rollback this project to snapshot '{0}'?\n\n" +
                "• A pre-rollback safety backup will be created automatically before restoring.\n" +
                "• README notes, copywriting, and design source binaries (.afdesign, .psd, .ai) will be restored.",
                snapshotId);

            MessageBoxResult confirm = System.Windows.MessageBox.Show(confirmMsg, "Confirm Project Rollback", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (confirm != MessageBoxResult.Yes) return;

            try
            {
                string actor = Environment.UserName;
                SnapshotRollbackResult res = SnapshotDesktopService.Rollback(_projectFullPath, snapshotId, actor);

                if (res != null && res.Success)
                {
                    ProjectWasModified = true;
                    string msg = string.Format(
                        "Project successfully rolled back to '{0}'!\n\n" +
                        "Restored Revision: Rev {1}\n" +
                        "Restored Source Files: {2}\n" +
                        "Safety Backup Created: {3}",
                        res.SnapshotId,
                        res.RestoredRevision,
                        res.RestoredSourceFilesCount,
                        res.PreRollbackBackupId);

                    System.Windows.MessageBox.Show(msg, "Rollback Complete", MessageBoxButton.OK, MessageBoxImage.Information);
                    LoadSnapshots();
                }
                else
                {
                    string err = res != null ? res.Message : "Unknown rollback failure.";
                    System.Windows.MessageBox.Show("Rollback failed: " + err, "Rollback Failed", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[ProjectSnapshotsDialog] OnRollbackClicked error: " + ex.Message);
                System.Windows.MessageBox.Show("Error executing rollback: " + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void OnCloseClicked(object sender, RoutedEventArgs e)
        {
            DialogResult = ProjectWasModified;
            Close();
        }
    }
}
