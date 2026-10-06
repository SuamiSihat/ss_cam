using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;
using SS_CAM.Models;
using SS_CAM.Services;

namespace SS_CAM.Views
{
    /// <summary>
    /// Code-behind for TranscoderBridgePage.
    /// Provides batch transcoding UI with FFmpeg engine integration.
    /// </summary>
    public partial class TranscoderBridgePage : Page
    {
        private static readonly ObservableCollection<TranscodeJob> _sharedJobs = new ObservableCollection<TranscodeJob>();
        public static ObservableCollection<TranscodeJob> SharedJobs { get { return _sharedJobs; } }
        private readonly ObservableCollection<TranscodeJob> _jobs = _sharedJobs;
        private bool _isConverting = false;
        private volatile bool _cancelRequested = false;
        private string _ffmpegBinaryPath = null;
        private string _ffmpegVersion = null;

        public TranscoderBridgePage()
        {
            InitializeComponent();
            QueueListView.ItemsSource = _jobs;
            Loaded += OnPageLoaded;
            Unloaded += OnPageUnloaded;
        }

        private void OnPageLoaded(object sender, RoutedEventArgs e)
        {
            try
            {
                ProbeEngine();
                UpdateQueueStateUI();
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderBridgePage] OnPageLoaded: " + ex.Message);
            }
        }

        private void OnPageUnloaded(object sender, RoutedEventArgs e)
        {
            try
            {
                if (_isConverting)
                {
                    _cancelRequested = true;
                    TranscoderService.CancelAll();
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderBridgePage] OnPageUnloaded: " + ex.Message);
            }
        }

        // ─── Engine Probing ───────────────────────────────────────────────────────

        private void OnRefreshEngineClicked(object sender, RoutedEventArgs e)
        {
            ProbeEngine();
        }

        private void ProbeEngine()
        {
            try
            {
                string detectedPath;
                string ver;
                bool available = TranscoderService.IsFFmpegAvailable(out detectedPath, out ver);

                _ffmpegBinaryPath = detectedPath;
                _ffmpegVersion = ver;

                if (available)
                {
                    EngineStatusDot.Fill = (Brush)FindResource("SystemFillColorSuccessBrush");
                    EngineStatusTitle.Text = "FFmpeg Engine Ready";
                    EngineVersionBadge.Visibility = Visibility.Visible;
                    EngineVersionText.Text = !string.IsNullOrEmpty(ver) ? "v" + ver : "Detected";
                    EnginePathText.Text = detectedPath;
                    StartBatchBtn.IsEnabled = true;
                }
                else
                {
                    EngineStatusDot.Fill = (Brush)FindResource("SystemFillColorCriticalBrush");
                    EngineStatusTitle.Text = "FFmpeg Not Found";
                    EngineVersionBadge.Visibility = Visibility.Collapsed;
                    EnginePathText.Text = "Install FFmpeg or configure custom path in Settings.";
                    StartBatchBtn.IsEnabled = false;
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderBridgePage] ProbeEngine: " + ex.Message);
            }
        }

        // ─── Preset Selection ─────────────────────────────────────────────────────

        private TranscodePreset GetSelectedPreset()
        {
            var item = PresetComboBox.SelectedItem as ComboBoxItem;
            if (item != null && item.Tag != null)
            {
                string tag = item.Tag.ToString();
                switch (tag)
                {
                    case "WebP_Image": return TranscodePreset.WebP_Image;
                    case "Avif_Image": return TranscodePreset.Avif_Image;
                    case "WebM_Video": return TranscodePreset.WebM_Video;
                    case "Social_Gif_10s": return TranscodePreset.Social_Gif_10s;
                    case "Mp4_Compress": return TranscodePreset.Mp4_Compress;
                }
            }
            return TranscodePreset.WebP_Image;
        }

        private string GetSelectedPresetName()
        {
            var item = PresetComboBox.SelectedItem as ComboBoxItem;
            if (item != null && item.Content != null)
            {
                string full = item.Content.ToString();
                int dash = full.IndexOfAny(new char[] { '-', '—' });
                if (dash > 0) return full.Substring(0, dash).Trim();
                return full.Trim();
            }
            return "WebP Image";
        }

        private void OnPresetSelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (PresetDescriptionText == null) return;

            TranscodePreset preset = GetSelectedPreset();
            switch (preset)
            {
                case TranscodePreset.WebP_Image:
                    PresetDescriptionText.Text = "Optimized for web pages and digital portals. Delivers ~80% size savings over raw PNG.";
                    break;
                case TranscodePreset.Avif_Image:
                    PresetDescriptionText.Text = "Next-generation AV1 image compression. Extremely high quality with minimal file footprint.";
                    break;
                case TranscodePreset.WebM_Video:
                    PresetDescriptionText.Text = "HTML5 royalty-free VP9 video with Opus audio. Ideal for website video backgrounds.";
                    break;
                case TranscodePreset.Social_Gif_10s:
                    PresetDescriptionText.Text = "Extracts first 10 seconds into a 480p animated GIF for social media, Discord, and Slack.";
                    break;
                case TranscodePreset.Mp4_Compress:
                    PresetDescriptionText.Text = "Re-encodes with H.264 CRF 23 and faststart metadata for instantaneous web streaming.";
                    break;
            }

            // Update queued items that haven't converted yet
            string customDir = OutputDirTextBox != null ? OutputDirTextBox.Text.Trim() : "";
            for (int i = 0; i < _jobs.Count; i++)
            {
                var job = _jobs[i];
                if (job.Status == TranscodeStatus.Queued)
                {
                    job.Preset = preset;
                    job.PresetName = GetSelectedPresetName();
                    job.OutputFilePath = TranscoderService.GetDefaultOutputPath(job.SourceFilePath, preset, customDir);
                }
            }
        }

        // ─── Destination Folder ───────────────────────────────────────────────────

        private void OnBrowseOutputDirClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var dlg = new System.Windows.Forms.FolderBrowserDialog())
                {
                    dlg.Description = "Select Destination Folder for Transcoded Assets";
                    if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                    {
                        OutputDirTextBox.Text = dlg.SelectedPath;
                        OutputDirHintText.Text = "Files will be saved into: " + dlg.SelectedPath;
                        RefreshQueuedOutputPaths();
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderBridgePage] OnBrowseOutputDirClicked: " + ex.Message);
            }
        }

        private void OnSameAsSourceClicked(object sender, RoutedEventArgs e)
        {
            OutputDirTextBox.Text = "";
            OutputDirHintText.Text = "Saving alongside source file by default (e.g. image_web.webp).";
            RefreshQueuedOutputPaths();
        }

        private void RefreshQueuedOutputPaths()
        {
            string customDir = OutputDirTextBox.Text.Trim();
            TranscodePreset preset = GetSelectedPreset();
            for (int i = 0; i < _jobs.Count; i++)
            {
                var job = _jobs[i];
                if (job.Status == TranscodeStatus.Queued)
                {
                    job.OutputFilePath = TranscoderService.GetDefaultOutputPath(job.SourceFilePath, preset, customDir);
                }
            }
        }

        // ─── Ingestion & Drag and Drop ────────────────────────────────────────────

        private void OnFileDragOver(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                e.Effects = DragDropEffects.Copy;
            }
            else
            {
                e.Effects = DragDropEffects.None;
            }
            e.Handled = true;
        }

        private void OnFileDrop(object sender, DragEventArgs e)
        {
            try
            {
                if (e.Data.GetDataPresent(DataFormats.FileDrop))
                {
                    string[] files = (string[])e.Data.GetData(DataFormats.FileDrop);
                    if (files != null && files.Length > 0)
                    {
                        AddPathsToQueue(files);
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderBridgePage] OnFileDrop: " + ex.Message);
            }
        }

        private void OnAddFilesClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                var dlg = new OpenFileDialog();
                dlg.Multiselect = true;
                dlg.Filter = "Media Files|*.mp4;*.mov;*.avi;*.mkv;*.webm;*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.tiff|Video Files (*.mp4;*.mov;*.webm)|*.mp4;*.mov;*.webm;*.mkv;*.avi|Image Files (*.png;*.jpg;*.webp)|*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.tiff|All Files (*.*)|*.*";
                dlg.Title = "Select Media Assets for Transcoding";

                if (dlg.ShowDialog() == true && dlg.FileNames != null)
                {
                    AddPathsToQueue(dlg.FileNames);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderBridgePage] OnAddFilesClicked: " + ex.Message);
            }
        }

        private void OnAddFolderClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var dlg = new System.Windows.Forms.FolderBrowserDialog())
                {
                    dlg.Description = "Select Folder Containing Media Assets";
                    if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                    {
                        string folder = dlg.SelectedPath;
                        if (Directory.Exists(folder))
                        {
                            string[] files = Directory.GetFiles(folder, "*.*", SearchOption.TopDirectoryOnly);
                            AddPathsToQueue(files);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderBridgePage] OnAddFolderClicked: " + ex.Message);
            }
        }

        private void AddPathsToQueue(IEnumerable<string> paths)
        {
            TranscodePreset preset = GetSelectedPreset();
            string presetName = GetSelectedPresetName();
            string customDir = OutputDirTextBox.Text.Trim();

            var supportedExts = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                ".mp4", ".mov", ".avi", ".mkv", ".webm", ".flv", ".wmv",
                ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif"
            };

            int addedCount = 0;
            foreach (string p in paths)
            {
                if (File.Exists(p))
                {
                    string ext = Path.GetExtension(p);
                    if (supportedExts.Contains(ext))
                    {
                        // Check if already in queue
                        bool exists = false;
                        for (int i = 0; i < _jobs.Count; i++)
                        {
                            if (string.Equals(_jobs[i].SourceFilePath, p, StringComparison.OrdinalIgnoreCase) &&
                                _jobs[i].Status != TranscodeStatus.Completed)
                            {
                                exists = true;
                                break;
                            }
                        }

                        if (!exists)
                        {
                            var job = new TranscodeJob
                            {
                                SourceFilePath = p,
                                Preset = preset,
                                PresetName = presetName,
                                OutputFilePath = TranscoderService.GetDefaultOutputPath(p, preset, customDir),
                                Status = TranscodeStatus.Queued,
                                StatusMessage = "Waiting in queue"
                            };

                            try
                            {
                                var fi = new FileInfo(p);
                                job.SourceSizeBytes = fi.Length;
                            }
                            catch (Exception exFi)
                            {
                                Debug.WriteLine("[TranscoderBridgePage] FileInfo: " + exFi.Message);
                            }

                            _jobs.Add(job);
                            addedCount++;
                        }
                    }
                }
                else if (Directory.Exists(p))
                {
                    try
                    {
                        string[] subFiles = Directory.GetFiles(p, "*.*", SearchOption.TopDirectoryOnly);
                        AddPathsToQueue(subFiles);
                    }
                    catch (Exception exDir)
                    {
                        Debug.WriteLine("[TranscoderBridgePage] SubFiles read: " + exDir.Message);
                    }
                }
            }

            UpdateQueueStateUI();
        }

        private void OnClearAllQueueClicked(object sender, RoutedEventArgs e)
        {
            if (_isConverting)
            {
                MessageBox.Show("Conversion is in progress. Please cancel first.", "Transcoder Bridge", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            _jobs.Clear();
            UpdateQueueStateUI();
        }

        private void OnClearFinishedClicked(object sender, RoutedEventArgs e)
        {
            for (int i = _jobs.Count - 1; i >= 0; i--)
            {
                if (_jobs[i].Status == TranscodeStatus.Completed || _jobs[i].Status == TranscodeStatus.Cancelled)
                {
                    _jobs.RemoveAt(i);
                }
            }
            UpdateQueueStateUI();
        }

        private void OnItemRemoveClicked(object sender, RoutedEventArgs e)
        {
            var btn = sender as FrameworkElement;
            if (btn == null) return;
            var job = btn.Tag as TranscodeJob;
            if (job != null)
            {
                if (job.Status == TranscodeStatus.Processing)
                {
                    TranscoderService.CancelJob(job.Id);
                }
                _jobs.Remove(job);
                UpdateQueueStateUI();
            }
        }

        private void OnItemRevealClicked(object sender, RoutedEventArgs e)
        {
            var btn = sender as FrameworkElement;
            if (btn == null) return;
            var job = btn.Tag as TranscodeJob;
            if (job != null)
            {
                string targetPath = File.Exists(job.OutputFilePath) ? job.OutputFilePath : job.SourceFilePath;
                if (File.Exists(targetPath))
                {
                    try
                    {
                        Process.Start("explorer.exe", "/select,\"" + targetPath + "\"");
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("[TranscoderBridgePage] Reveal: " + ex.Message);
                    }
                }
            }
        }

        private void OnOpenOutputDirClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                string dir = OutputDirTextBox.Text.Trim();
                if (!string.IsNullOrEmpty(dir) && Directory.Exists(dir))
                {
                    Process.Start("explorer.exe", dir);
                    return;
                }

                // If no custom dir, check the first completed or queued job's output folder
                for (int i = 0; i < _jobs.Count; i++)
                {
                    string outDir = Path.GetDirectoryName(_jobs[i].OutputFilePath);
                    if (!string.IsNullOrEmpty(outDir) && Directory.Exists(outDir))
                    {
                        Process.Start("explorer.exe", outDir);
                        return;
                    }
                }

                // Default to workspace root
                var profile = UserProfileService.LoadProfile();
                if (profile != null && !string.IsNullOrEmpty(profile.WorkspaceRoot) && Directory.Exists(profile.WorkspaceRoot))
                {
                    Process.Start("explorer.exe", profile.WorkspaceRoot);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderBridgePage] OpenOutputDir: " + ex.Message);
            }
        }

        // ─── Batch Execution ──────────────────────────────────────────────────────

        private void OnStartBatchClicked(object sender, RoutedEventArgs e)
        {
            if (_isConverting) return;

            if (_jobs.Count == 0)
            {
                MessageBox.Show("Please add media files to the queue before starting conversion.", "Queue Empty", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            if (string.IsNullOrEmpty(_ffmpegBinaryPath) || !File.Exists(_ffmpegBinaryPath))
            {
                MessageBox.Show("FFmpeg engine is not available. Please install FFmpeg or set its path in Settings.", "Engine Error", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            _isConverting = true;
            _cancelRequested = false;
            StartBatchBtn.IsEnabled = false;
            CancelBatchBtn.IsEnabled = true;
            BatchProgressBar.Visibility = Visibility.Visible;
            BatchProgressBar.Value = 0;

            Task.Factory.StartNew(ExecuteBatchWorker);
        }

        private void OnCancelBatchClicked(object sender, RoutedEventArgs e)
        {
            _cancelRequested = true;
            CancelBatchBtn.IsEnabled = false;
            TranscoderService.CancelAll();
        }

        private void ExecuteBatchWorker()
        {
            try
            {
                int totalQueued = 0;
                for (int i = 0; i < _jobs.Count; i++)
                {
                    if (_jobs[i].Status == TranscodeStatus.Queued || _jobs[i].Status == TranscodeStatus.Failed)
                    {
                        totalQueued++;
                    }
                }

                int processed = 0;

                for (int i = 0; i < _jobs.Count; i++)
                {
                    if (_cancelRequested) break;

                    var job = _jobs[i];
                    if (job.Status != TranscodeStatus.Queued && job.Status != TranscodeStatus.Failed)
                    {
                        continue;
                    }

                    // Update UI: job starting
                    Dispatcher.Invoke(DispatcherPriority.Normal, new Action(delegate
                    {
                        job.Status = TranscodeStatus.Processing;
                        job.StatusMessage = "Initializing engine...";
                        job.ProgressPercent = 5;
                    }));

                    // Execute single transcode job
                    var result = TranscoderService.ExecuteJob(job, delegate(int pct, string msg)
                    {
                        Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(delegate
                        {
                            job.ProgressPercent = pct;
                            job.StatusMessage = msg;
                        }));
                    });

                    // Update UI: job finished
                    Dispatcher.Invoke(DispatcherPriority.Normal, new Action(delegate
                    {
                        if (_cancelRequested)
                        {
                            job.Status = TranscodeStatus.Cancelled;
                            job.StatusMessage = "Cancelled by user";
                            job.ProgressPercent = 0;
                        }
                        else if (result.Success)
                        {
                            job.Status = TranscodeStatus.Completed;
                            job.OutputSizeBytes = result.OutputSizeBytes;
                            job.Duration = result.Duration;
                            job.StatusMessage = string.Format("Ready ({0})", job.DurationFormatted);
                            job.ProgressPercent = 100;
                            job.CompletedAt = DateTime.UtcNow;
                        }
                        else
                        {
                            job.Status = TranscodeStatus.Failed;
                            job.ErrorMessage = result.ErrorMessage;
                            job.StatusMessage = "Failed: " + result.ErrorMessage;
                            job.ProgressPercent = 0;
                        }

                        processed++;
                        if (totalQueued > 0)
                        {
                            BatchProgressBar.Value = (processed * 100.0) / totalQueued;
                        }
                        UpdateQueueStateUI();
                    }));
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderBridgePage] ExecuteBatchWorker: " + ex.Message);
            }
            finally
            {
                Dispatcher.Invoke(DispatcherPriority.Normal, new Action(delegate
                {
                    _isConverting = false;
                    StartBatchBtn.IsEnabled = true;
                    CancelBatchBtn.IsEnabled = false;
                    BatchProgressBar.Visibility = Visibility.Collapsed;
                    UpdateQueueStateUI();
                }));
            }
        }

        // ─── UI Helpers ───────────────────────────────────────────────────────────

        private void UpdateQueueStateUI()
        {
            int queued = 0;
            int completed = 0;
            int failed = 0;

            for (int i = 0; i < _jobs.Count; i++)
            {
                switch (_jobs[i].Status)
                {
                    case TranscodeStatus.Queued:
                    case TranscodeStatus.Processing:
                        queued++;
                        break;
                    case TranscodeStatus.Completed:
                        completed++;
                        break;
                    case TranscodeStatus.Failed:
                    case TranscodeStatus.Cancelled:
                        failed++;
                        break;
                }
            }

            StatQueuedCount.Text = queued.ToString();
            StatCompletedCount.Text = completed.ToString();
            StatFailedCount.Text = failed.ToString();

            if (_jobs.Count == 0)
            {
                QueueEmptyState.Visibility = Visibility.Visible;
                QueueListView.Visibility = Visibility.Collapsed;
            }
            else
            {
                QueueEmptyState.Visibility = Visibility.Collapsed;
                QueueListView.Visibility = Visibility.Visible;
            }
        }

        private void OnScrollViewerPreviewMouseWheel(object sender, MouseWheelEventArgs e)
        {
            var sv = sender as ScrollViewer;
            if (sv != null)
            {
                sv.ScrollToVerticalOffset(sv.VerticalOffset - e.Delta);
                e.Handled = true;
            }
        }
    }
}
