using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Media;
using SS_CAM.Services;
using Wpf.Ui.Controls;

namespace SS_CAM.Dialogs
{
    public class DiffLineViewModel
    {
        public string OldLineNumber { get; set; }
        public string NewLineNumber { get; set; }
        public string TypeSymbol { get; set; }
        public string Text { get; set; }
        public Brush AccentBrush { get; set; }
        public Brush TextBrush { get; set; }
        public DiffLineType Type { get; set; }
    }

    /// <summary>
    /// Interaction logic for MarkdownDiffDialog.xaml
    /// </summary>
    public partial class MarkdownDiffDialog : FluentWindow
    {
        private readonly string _projectPath;
        private readonly string _docType;
        private List<RevisionItem> _revisions;
        private DiffResult _currentDiff;

        public MarkdownDiffDialog(string projectPath, string docType = "copy")
        {
            InitializeComponent();
            _projectPath = projectPath;
            _docType = docType;

            ConfigureDocHeader();
            LoadRevisions();
        }

        private void ConfigureDocHeader()
        {
            if (string.Equals(_docType, "brief", StringComparison.OrdinalIgnoreCase))
            {
                TxtDocTypeBadge.Text = "README.MD";
                TxtDialogTitle.Text = "Project Brief Revision Diff";
                TxtDocSubtitle.Text = "Compare project requirements, creative deliverables, and brief modifications.";
            }
            else
            {
                TxtDocTypeBadge.Text = "COPY.MD";
                TxtDialogTitle.Text = "Copywriting Script Revision Diff";
                TxtDocSubtitle.Text = "Inspect copy alterations, hook revisions, and body modifications across drafts.";
            }
        }

        private void LoadRevisions()
        {
            try
            {
                _revisions = TextDiffService.GetRevisions(_projectPath, _docType);

                CmbBeforeRevision.ItemsSource = null;
                CmbAfterRevision.ItemsSource = null;

                if (_revisions == null || _revisions.Count == 0)
                {
                    TxtDocSubtitle.Text = "No previous snapshots or revisions found for this document.";
                    return;
                }

                CmbBeforeRevision.ItemsSource = _revisions;
                CmbBeforeRevision.DisplayMemberPath = "DisplayName";

                CmbAfterRevision.ItemsSource = _revisions;
                CmbAfterRevision.DisplayMemberPath = "DisplayName";

                // Default: After is Current (index 0), Before is Previous snapshot (index 1 if exists, else 0)
                CmbAfterRevision.SelectedIndex = 0;
                CmbBeforeRevision.SelectedIndex = _revisions.Count > 1 ? 1 : 0;

                ComputeAndRenderDiff();
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[MarkdownDiffDialog] LoadRevisions error: " + ex.Message);
            }
        }

        private void OnRevisionSelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
        {
            ComputeAndRenderDiff();
        }

        private void ComputeAndRenderDiff()
        {
            RevisionItem beforeItem = CmbBeforeRevision.SelectedItem as RevisionItem;
            RevisionItem afterItem = CmbAfterRevision.SelectedItem as RevisionItem;

            if (beforeItem == null || afterItem == null) return;

            string beforeContent = string.Empty;
            string afterContent = string.Empty;

            try
            {
                if (File.Exists(beforeItem.FilePath))
                {
                    beforeContent = File.ReadAllText(beforeItem.FilePath, Encoding.UTF8);
                }
                if (File.Exists(afterItem.FilePath))
                {
                    afterContent = File.ReadAllText(afterItem.FilePath, Encoding.UTF8);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[MarkdownDiffDialog] Read text error: " + ex.Message);
            }

            TxtBeforeSideBySide.Text = beforeContent;
            TxtAfterSideBySide.Text = afterContent;

            _currentDiff = TextDiffService.Compare(beforeContent, afterContent);

            // Update Metrics Banner
            TxtMetricsAdded.Text = string.Format("+{0} Lines Added", _currentDiff.AddedCount);
            TxtMetricsDeleted.Text = string.Format("-{0} Lines Removed", _currentDiff.DeletedCount);
            TxtMetricsUnchanged.Text = string.Format("{0} unchanged", _currentDiff.UnchangedCount);
            TxtSimilarityPercentage.Text = string.Format("{0:0.0}%", _currentDiff.SimilarityPercentage);

            // Render Unified Diff Items
            Brush successBrush = (Brush)Application.Current.FindResource("SystemFillColorSuccessBrush");
            Brush criticalBrush = (Brush)Application.Current.FindResource("SystemFillColorCriticalBrush");
            Brush defaultTextBrush = (Brush)Application.Current.FindResource("TextFillColorPrimaryBrush");
            Brush tertiaryBrush = (Brush)Application.Current.FindResource("TextFillColorTertiaryBrush");

            List<DiffLineViewModel> viewModels = new List<DiffLineViewModel>();

            foreach (DiffLine line in _currentDiff.Lines)
            {
                DiffLineViewModel vm = new DiffLineViewModel
                {
                    OldLineNumber = line.OldLineNumber.HasValue ? line.OldLineNumber.Value.ToString() : string.Empty,
                    NewLineNumber = line.NewLineNumber.HasValue ? line.NewLineNumber.Value.ToString() : string.Empty,
                    Text = line.Text,
                    Type = line.Type
                };

                switch (line.Type)
                {
                    case DiffLineType.Added:
                        vm.TypeSymbol = "+";
                        vm.AccentBrush = successBrush;
                        vm.TextBrush = successBrush;
                        break;
                    case DiffLineType.Deleted:
                        vm.TypeSymbol = "-";
                        vm.AccentBrush = criticalBrush;
                        vm.TextBrush = criticalBrush;
                        break;
                    default:
                        vm.TypeSymbol = " ";
                        vm.AccentBrush = tertiaryBrush;
                        vm.TextBrush = defaultTextBrush;
                        break;
                }

                viewModels.Add(vm);
            }

            ItemsUnifiedDiff.ItemsSource = viewModels;
        }

        private void OnModeUnifiedClicked(object sender, RoutedEventArgs e)
        {
            BtnModeUnified.Appearance = ControlAppearance.Primary;
            BtnModeSideBySide.Appearance = ControlAppearance.Secondary;

            ScrollUnified.Visibility = Visibility.Visible;
            GridSideBySide.Visibility = Visibility.Collapsed;
        }

        private void OnModeSideBySideClicked(object sender, RoutedEventArgs e)
        {
            BtnModeUnified.Appearance = ControlAppearance.Secondary;
            BtnModeSideBySide.Appearance = ControlAppearance.Primary;

            ScrollUnified.Visibility = Visibility.Collapsed;
            GridSideBySide.Visibility = Visibility.Visible;
        }

        private void OnCopyAddedLinesClicked(object sender, RoutedEventArgs e)
        {
            if (_currentDiff == null) return;

            StringBuilder sb = new StringBuilder();
            foreach (DiffLine line in _currentDiff.Lines.Where(l => l.Type == DiffLineType.Added))
            {
                sb.AppendLine(line.Text);
            }

            string addedText = sb.ToString();
            if (!string.IsNullOrEmpty(addedText))
            {
                ClipboardService.SetText(addedText);
                NotificationService.ShowSuccess("Copied Added Lines", string.Format("Copied {0} added line(s) to clipboard.", _currentDiff.AddedCount));
            }
        }

        private void OnCopyUnifiedDiffClicked(object sender, RoutedEventArgs e)
        {
            if (_currentDiff == null) return;

            StringBuilder sb = new StringBuilder();
            sb.AppendLine(string.Format("--- Before: {0}", CmbBeforeRevision.Text));
            sb.AppendLine(string.Format("+++ After:  {0}", CmbAfterRevision.Text));
            sb.AppendLine();

            foreach (DiffLine line in _currentDiff.Lines)
            {
                sb.AppendLine(line.ToString());
            }

            ClipboardService.SetText(sb.ToString());
            NotificationService.ShowSuccess("Copied Diff Patch", "Full unified diff copied to clipboard.");
        }

        private void OnCloseClicked(object sender, RoutedEventArgs e)
        {
            Close();
        }
    }
}
