using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using SS_CAM.Models;
using SS_CAM.Services;

namespace SS_CAM.Views
{
    public partial class SettingsPage : Page
    {
        private UserProfile currentProfile;

        public SettingsPage()
        {
            InitializeComponent();
            if (TxtVersionBadge != null)
                TxtVersionBadge.Text = string.Format("SS-CAM {0}", AppVersion.DisplayVersion);
            Loaded += OnPageLoaded;
            Unloaded += OnPageUnloaded;
        }

        private void OnPageUnloaded(object sender, RoutedEventArgs e)
        {
            // Reserved for future cleanup
        }

        private bool _isPluginLoading = false;

        private void OnPageLoaded(object sender, RoutedEventArgs e)
        {
            LoadProfileData();
            LoadPluginStates();
            RefreshPortalAccountCard();
        }

        #region Web portal account

        // Password typed at sign-in, kept in memory ONLY while a forced password change is pending.
        private string _portalPendingCurrentPassword;
        private bool _portalBusy;
        private bool _portalUsernamePrefilled;

        private void RefreshPortalAccountCard()
        {
            try
            {
                bool pendingChange = PortalAuthService.IsPasswordChangePending && !string.IsNullOrEmpty(_portalPendingCurrentPassword);
                bool signedIn = !pendingChange && PortalAuthService.IsSignedIn;

                PortalChangePasswordPanel.Visibility = pendingChange ? Visibility.Visible : Visibility.Collapsed;
                PortalSignedInPanel.Visibility = signedIn ? Visibility.Visible : Visibility.Collapsed;
                PortalSignedOutPanel.Visibility = (!pendingChange && !signedIn) ? Visibility.Visible : Visibility.Collapsed;

                if (signedIn)
                {
                    string display = PortalAuthService.SignedInDisplayName;
                    string uname = PortalAuthService.SignedInUsername;
                    PortalSignedInText.Text = "Signed in as " + (string.IsNullOrWhiteSpace(display) ? uname : display);
                    PortalSignedInDetail.Text = string.IsNullOrWhiteSpace(uname) || string.Equals(uname, display, StringComparison.OrdinalIgnoreCase)
                        ? "Orders and notes sync with the web portal."
                        : "Username: " + uname + ". Orders and notes sync with the web portal.";

                    if (PortalAuthService.SavedAccountNeedsPasswordChange)
                    {
                        ShowPortalStatus("Your account needs a new password. Switch account and sign in again to choose one.", true);
                    }
                    else if (PortalAuthService.SavedCredentialsRejected)
                    {
                        ShowPortalStatus("Your saved password no longer works. Switch account and sign in again.", true);
                    }
                }
                else if (!pendingChange && !_portalUsernamePrefilled)
                {
                    // Pre-fill once per page visit (not after "Switch account", which starts blank).
                    _portalUsernamePrefilled = true;
                    if (string.IsNullOrWhiteSpace(PortalUsernameInput.Text))
                    {
                        PortalUsernameInput.Text = GetSuggestedPortalUsername();
                    }
                }
            }
            catch (Exception ex)
            {
                App.LogTrace("[SettingsPage] RefreshPortalAccountCard: " + ex.Message);
            }
        }

        private string GetSuggestedPortalUsername()
        {
            string last = PortalAuthService.LastUsername;
            if (!string.IsNullOrWhiteSpace(last)) return last;

            var selected = StaffDirectoryCombo.SelectedItem as StaffDirectoryItem;
            if (selected != null && !string.IsNullOrWhiteSpace(selected.Username)) return selected.Username.Trim();
            if (currentProfile != null && !string.IsNullOrWhiteSpace(currentProfile.StaffId)) return currentProfile.StaffId.Trim();
            return "";
        }

        private void ShowPortalStatus(string message, bool isError)
        {
            if (string.IsNullOrWhiteSpace(message))
            {
                PortalStatusText.Text = "";
                PortalStatusText.Visibility = Visibility.Collapsed;
                return;
            }
            PortalStatusText.Text = message;
            PortalStatusText.SetResourceReference(TextBlock.ForegroundProperty,
                isError ? "SystemFillColorCriticalBrush" : "SystemFillColorSuccessBrush");
            PortalStatusText.Visibility = Visibility.Visible;
        }

        private void SetPortalBusy(bool busy)
        {
            _portalBusy = busy;
            BtnPortalSignIn.IsEnabled = !busy;
            BtnPortalChangePassword.IsEnabled = !busy;
            BtnPortalCancelChange.IsEnabled = !busy;
            BtnPortalSignOut.IsEnabled = !busy;
            BtnPortalSwitchAccount.IsEnabled = !busy;
            PortalUsernameInput.IsEnabled = !busy;
            PortalPasswordInput.IsEnabled = !busy;
            PortalNewPasswordInput.IsEnabled = !busy;
            PortalConfirmPasswordInput.IsEnabled = !busy;
            BtnPortalSignInText.Text = busy ? "Signing in..." : "Sign in";
            BtnPortalChangePasswordText.Text = busy ? "Changing password..." : "Change password";
        }

        private void OnPortalSignInKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
        {
            if (e.Key == System.Windows.Input.Key.Enter)
            {
                e.Handled = true;
                OnPortalSignInClicked(sender, new RoutedEventArgs());
            }
        }

        private void OnPortalChangePasswordKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
        {
            if (e.Key == System.Windows.Input.Key.Enter)
            {
                e.Handled = true;
                OnPortalChangePasswordClicked(sender, new RoutedEventArgs());
            }
        }

        private async void OnPortalSignInClicked(object sender, RoutedEventArgs e)
        {
            if (_portalBusy) return;
            string username = PortalUsernameInput.Text != null ? PortalUsernameInput.Text.Trim() : "";
            string password = PortalPasswordInput.Password ?? "";

            if (username.Length == 0)
            {
                ShowPortalStatus("Enter your username.", true);
                PortalUsernameInput.Focus();
                return;
            }
            if (password.Length == 0)
            {
                ShowPortalStatus("Enter your password.", true);
                PortalPasswordInput.Focus();
                return;
            }

            ShowPortalStatus(null, false);
            SetPortalBusy(true);
            try
            {
                PortalAuthResult result = await PortalAuthService.SignInAsync(username, password);
                if (!result.Success)
                {
                    ShowPortalStatus(result.ErrorMessage ?? PortalAuthService.MsgOffline, true);
                    PortalPasswordInput.Password = "";
                    PortalPasswordInput.Focus();
                    return;
                }

                PortalPasswordInput.Password = "";
                if (result.MustChangePassword)
                {
                    _portalPendingCurrentPassword = password;
                    PortalNewPasswordInput.Password = "";
                    PortalConfirmPasswordInput.Password = "";
                    RefreshPortalAccountCard();
                    ShowPortalStatus(null, false);
                    PortalNewPasswordInput.Focus();
                    return;
                }

                RefreshPortalAccountCard();
                ShowPortalStatus("Signed in. Orders and notes will now sync with the web portal.", false);
                BtnPortalSignOut.Focus();
            }
            catch (Exception ex)
            {
                App.LogTrace("[SettingsPage] Portal sign-in failed: " + ex.Message);
                ShowPortalStatus(PortalAuthService.MsgOffline, true);
            }
            finally
            {
                SetPortalBusy(false);
            }
        }

        private async void OnPortalChangePasswordClicked(object sender, RoutedEventArgs e)
        {
            if (_portalBusy) return;
            string newPassword = PortalNewPasswordInput.Password ?? "";
            string confirm = PortalConfirmPasswordInput.Password ?? "";

            if (newPassword.Length < 10)
            {
                ShowPortalStatus("Your new password must be at least 10 characters.", true);
                PortalNewPasswordInput.Focus();
                return;
            }
            if (!string.Equals(newPassword, confirm, StringComparison.Ordinal))
            {
                ShowPortalStatus("The passwords don't match.", true);
                PortalConfirmPasswordInput.Focus();
                return;
            }
            if (string.IsNullOrEmpty(_portalPendingCurrentPassword))
            {
                ShowPortalStatus("Sign in again, then change your password.", true);
                PortalAuthService.CancelPendingPasswordChange();
                RefreshPortalAccountCard();
                return;
            }
            if (string.Equals(newPassword, _portalPendingCurrentPassword, StringComparison.Ordinal))
            {
                ShowPortalStatus("Your new password must be different from your current password.", true);
                PortalNewPasswordInput.Focus();
                return;
            }

            ShowPortalStatus(null, false);
            SetPortalBusy(true);
            try
            {
                PortalAuthResult result = await PortalAuthService.ChangePasswordAsync(_portalPendingCurrentPassword, newPassword);
                if (!result.Success)
                {
                    ShowPortalStatus(result.ErrorMessage ?? PortalAuthService.MsgOffline, true);
                    if (!PortalAuthService.IsPasswordChangePending)
                    {
                        // Restricted session expired: start again from the sign-in form.
                        _portalPendingCurrentPassword = null;
                        RefreshPortalAccountCard();
                    }
                    return;
                }

                _portalPendingCurrentPassword = null;
                PortalNewPasswordInput.Password = "";
                PortalConfirmPasswordInput.Password = "";
                RefreshPortalAccountCard();
                ShowPortalStatus("Password changed. You're signed in.", false);
                BtnPortalSignOut.Focus();
            }
            catch (Exception ex)
            {
                App.LogTrace("[SettingsPage] Portal password change failed: " + ex.Message);
                ShowPortalStatus(PortalAuthService.MsgOffline, true);
            }
            finally
            {
                SetPortalBusy(false);
            }
        }

        private void OnPortalCancelChangeClicked(object sender, RoutedEventArgs e)
        {
            _portalPendingCurrentPassword = null;
            PortalNewPasswordInput.Password = "";
            PortalConfirmPasswordInput.Password = "";
            PortalAuthService.CancelPendingPasswordChange();
            ShowPortalStatus(null, false);
            RefreshPortalAccountCard();
            PortalPasswordInput.Focus();
        }

        private void OnPortalSignOutClicked(object sender, RoutedEventArgs e)
        {
            if (_portalBusy) return;
            PortalAuthService.SignOut();
            _portalUsernamePrefilled = true;
            PortalUsernameInput.Text = GetSuggestedPortalUsername();
            PortalPasswordInput.Password = "";
            RefreshPortalAccountCard();
            ShowPortalStatus("Signed out. Orders and notes now use the NAS copy only.", false);
            PortalUsernameInput.Focus();
        }

        private void OnPortalSwitchAccountClicked(object sender, RoutedEventArgs e)
        {
            if (_portalBusy) return;
            PortalAuthService.SignOut();
            _portalUsernamePrefilled = true;
            PortalUsernameInput.Text = "";
            PortalPasswordInput.Password = "";
            RefreshPortalAccountCard();
            ShowPortalStatus(null, false);
            PortalUsernameInput.Focus();
        }

        #endregion

        private void LoadPluginStates()
        {
            try
            {
                _isPluginLoading = true;
                if (TogglePluginWaktuSolat != null)
                    TogglePluginWaktuSolat.IsChecked = TenantConfigService.IsPluginEnabled("waktu-solat");
                if (TogglePluginWellbeing != null)
                    TogglePluginWellbeing.IsChecked = TenantConfigService.IsPluginEnabled("creative-wellbeing");
                if (TogglePluginQrCode != null)
                    TogglePluginQrCode.IsChecked = TenantConfigService.IsPluginEnabled("qr-code-studio");
                if (TogglePluginRadio != null)
                    TogglePluginRadio.IsChecked = TenantConfigService.IsPluginEnabled("radio-player");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[SettingsPage] LoadPluginStates: " + ex.Message);
            }
            finally
            {
                _isPluginLoading = false;
            }
        }

        private void OnPluginToggleClicked(object sender, RoutedEventArgs e)
        {
            if (_isPluginLoading) return;

            var toggle = sender as Wpf.Ui.Controls.ToggleSwitch;
            if (toggle == null) return;

            string pluginId = null;
            string pluginName = null;
            bool isEnabled = toggle.IsChecked == true;

            if (toggle == TogglePluginWaktuSolat)
            {
                pluginId = "waktu-solat";
                pluginName = "Waktu Solat";
            }
            else if (toggle == TogglePluginWellbeing)
            {
                pluginId = "creative-wellbeing";
                pluginName = "Creative Wellbeing";
            }
            else if (toggle == TogglePluginQrCode)
            {
                pluginId = "qr-code-studio";
                pluginName = "QR Code Studio";
            }
            else if (toggle == TogglePluginRadio)
            {
                pluginId = "radio-player";
                pluginName = "Radio Player";
            }

            if (pluginId != null)
            {
                TenantConfigService.SetPluginEnabled(pluginId, isEnabled);

                // Dynamically update MainWindow navigation
                var mainWindow = Application.Current.MainWindow as MainWindow;
                if (mainWindow != null)
                {
                    mainWindow.RefreshPluginNavigation();
                }

                string status = isEnabled ? "enabled" : "disabled";
                NotificationService.ShowInfo("Plugin Updated", string.Format("{0} module is now {1}.", pluginName, status));
            }
        }

        private void LoadProfileData()
        {
            currentProfile = UserProfileService.LoadProfile();

            DesignerNameInput.Text = currentProfile.DesignerName;
            StaffIdInput.Text = currentProfile.StaffId;
            DepartmentInput.Text = currentProfile.Department;
            EmailInput.Text = currentProfile.Email;
            WorkspaceRootInput.Text = currentProfile.WorkspaceRoot;

            ProfileHeaderName.Text = string.IsNullOrWhiteSpace(currentProfile.DesignerName) ? "Brand" : currentProfile.DesignerName;
            ProfileHeaderDept.Text = string.IsNullOrWhiteSpace(currentProfile.Department) ? "Creative & Brand" : currentProfile.Department;
            ProfileHeaderStaffId.Text = string.Format("Staff ID: {0}", string.IsNullOrWhiteSpace(currentProfile.StaffId) ? "0001D" : currentProfile.StaffId);

            UpdateAvatarPreview(currentProfile.AvatarPath);
            PopulateStaffDirectory();
        }

        private void PopulateStaffDirectory()
        {
            try
            {
                var directory = UserProfileService.GetStaffDirectory(currentProfile != null ? currentProfile.WorkspaceRoot : null);
                StaffDirectoryCombo.ItemsSource = directory;

                if (currentProfile != null && !string.IsNullOrWhiteSpace(currentProfile.StaffId))
                {
                    foreach (var item in directory)
                    {
                        if (string.Equals(item.StaffId, currentProfile.StaffId, StringComparison.OrdinalIgnoreCase))
                        {
                            StaffDirectoryCombo.SelectedItem = item;
                            break;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[SettingsPage] PopulateStaffDirectory error: " + ex.Message);
            }
        }

        private void OnStaffDirectoryComboSelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            var selected = StaffDirectoryCombo.SelectedItem as StaffDirectoryItem;
            if (selected != null)
            {
                DesignerNameInput.Text = selected.Name;
                StaffIdInput.Text = selected.StaffId;
                DepartmentInput.Text = selected.Department;
                EmailInput.Text = string.IsNullOrWhiteSpace(selected.Email) ? "" : selected.Email;

                ProfileHeaderName.Text = selected.Name;
                ProfileHeaderDept.Text = selected.Department;
                ProfileHeaderStaffId.Text = string.Format("Staff ID: {0}", selected.StaffId);

                // Update avatar if the staff directory entry carries an avatar or photo path
                if (!string.IsNullOrWhiteSpace(selected.Avatar))
                {
                    string cached = UserProfileService.CacheAvatarFromData(selected.Avatar, selected.StaffId);
                    if (!string.IsNullOrWhiteSpace(cached) && File.Exists(cached))
                    {
                        UpdateAvatarPreview(cached);
                        if (currentProfile != null)
                            currentProfile.AvatarPath = cached;
                    }
                }
                else if (!string.IsNullOrWhiteSpace(selected.AvatarPath))
                {
                    UpdateAvatarPreview(selected.AvatarPath);
                    if (currentProfile != null)
                        currentProfile.AvatarPath = selected.AvatarPath;
                }
            }
        }

        private void UpdateAvatarPreview(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                AvatarPreviewImg.Visibility = Visibility.Collapsed;
                AvatarEmojiText.Visibility = Visibility.Visible;
                return;
            }

            try
            {
                BitmapImage bmp = new BitmapImage();
                if (path.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
                {
                    int comma = path.IndexOf(',');
                    if (comma >= 0)
                    {
                        byte[] bytes = Convert.FromBase64String(path.Substring(comma + 1));
                        using (var ms = new System.IO.MemoryStream(bytes))
                        {
                            bmp.BeginInit();
                            bmp.CacheOption = BitmapCacheOption.OnLoad;
                            bmp.StreamSource = ms;
                            bmp.EndInit();
                            bmp.Freeze();
                        }
                        AvatarPreviewImg.Source = bmp;
                        AvatarPreviewImg.Visibility = Visibility.Visible;
                        AvatarEmojiText.Visibility = Visibility.Collapsed;
                        return;
                    }
                }
                else if (File.Exists(path))
                {
                    bmp.BeginInit();
                    bmp.UriSource = new Uri(path, UriKind.Absolute);
                    bmp.CacheOption = BitmapCacheOption.OnLoad;
                    bmp.EndInit();

                    AvatarPreviewImg.Source = bmp;
                    AvatarPreviewImg.Visibility = Visibility.Visible;
                    AvatarEmojiText.Visibility = Visibility.Collapsed;
                    return;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[SettingsPage] LoadAvatar error: " + ex.Message);
            }

            AvatarPreviewImg.Visibility = Visibility.Collapsed;
            AvatarEmojiText.Visibility = Visibility.Visible;
        }

        private void OnChangeAvatarClicked(object sender, RoutedEventArgs e)
        {
            OpenFileDialog dlg = new OpenFileDialog();
            dlg.Filter = "Image Files (*.png;*.jpg;*.jpeg;*.webp;*.bmp)|*.png;*.jpg;*.jpeg;*.webp;*.bmp|All Files (*.*)|*.*";
            dlg.Title = "Select Avatar Profile Picture";

            if (dlg.ShowDialog() == true)
            {
                try
                {
                    string folderName = (TenantConfigService.Current != null && !string.IsNullOrWhiteSpace(TenantConfigService.Current.AppFolderName)) ? TenantConfigService.Current.AppFolderName : "CreativeAssetsApp";
                    string targetFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), folderName);
                    if (!Directory.Exists(targetFolder)) Directory.CreateDirectory(targetFolder);

                    string staffPrefix = string.IsNullOrWhiteSpace(currentProfile.StaffId) ? "user" : currentProfile.StaffId.Trim();
                    string targetPath = Path.Combine(targetFolder, string.Format("avatar_{0}.jpg", staffPrefix));

                    File.Copy(dlg.FileName, targetPath, true);
                    currentProfile.AvatarPath = targetPath;

                    UpdateAvatarPreview(targetPath);

                    // Sync avatar to NAS user folder and staff_directory.json for Web Portal & Android
                    if (!string.IsNullOrWhiteSpace(currentProfile.StaffId))
                    {
                        UserProfileService.SyncAvatarToNas(currentProfile.StaffId, targetPath, currentProfile.WorkspaceRoot);
                    }
                }
                catch (Exception ex)
                {
                    MessageBox.Show(string.Format("Could not update avatar: {0}", ex.Message), "Avatar Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void OnSaveProfileClicked(object sender, RoutedEventArgs e)
        {
            currentProfile.DesignerName = DesignerNameInput.Text;
            currentProfile.StaffId = StaffIdInput.Text;
            currentProfile.Department = DepartmentInput.Text;
            currentProfile.Email = EmailInput.Text;
            currentProfile.WorkspaceRoot = WorkspaceRootInput.Text;

            UserProfileService.SaveProfile(currentProfile);

            ProfileHeaderName.Text = currentProfile.DesignerName;
            ProfileHeaderDept.Text = string.IsNullOrWhiteSpace(currentProfile.Department) ? "Creative & Brand" : currentProfile.Department;
            ProfileHeaderStaffId.Text = string.Format("Staff ID: {0}", currentProfile.StaffId);

            ProfileSaveStatus.Text = "Profile saved!";

            // Notify MainWindow to refresh header / sidebar avatar badge
            if (Application.Current != null)
            {
                MainWindow mainWin = Application.Current.MainWindow as MainWindow;
                if (mainWin != null)
                {
                    mainWin.RefreshProfileUI();
                }
            }

            MessageBox.Show("Profile identity and workstation settings saved successfully.", "Profile Saved", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void OnBrowseWorkspace(object sender, RoutedEventArgs e)
        {
            using (var dialog = new System.Windows.Forms.FolderBrowserDialog())
            {
                dialog.SelectedPath = WorkspaceRootInput.Text;
                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    WorkspaceRootInput.Text = dialog.SelectedPath;
                }
            }
        }

        private void OnSwitchBusinessUnit(object sender, RoutedEventArgs e)
        {
            var btn = sender as FrameworkElement;
            if (btn == null || btn.Tag == null) return;
            string unit = btn.Tag.ToString();
            string current = WorkspaceRootInput != null ? WorkspaceRootInput.Text : "";
            string newPath = NasConfigSyncService.SwitchBusinessUnitPath(current, unit);
            if (!string.IsNullOrEmpty(newPath))
            {
                WorkspaceRootInput.Text = newPath;
            }
        }

        private void OnCreateDesktopShortcut(object sender, RoutedEventArgs e)
        {
            string result = PayloadInstallerService.CreateAppDesktopShortcut();
            MessageBox.Show(result, "Desktop Shortcut", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void OnRepairFonts(object sender, RoutedEventArgs e)
        {
            string result = PayloadInstallerService.InstallBrandFonts();
            MessageBox.Show(result, "Font Deployment", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void OnDeployAssets(object sender, RoutedEventArgs e)
        {
            string result = PayloadInstallerService.DeployBrandAssets(WorkspaceRootInput.Text);
            MessageBox.Show(result, "Brand Assets Deployment", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void OnCheckUpdates(object sender, RoutedEventArgs e)
        {
            // Disable button while checking to prevent double-clicks
            var btn = sender as System.Windows.Controls.Button;
            if (btn != null) btn.IsEnabled = false;

            System.Threading.ThreadPool.QueueUserWorkItem(_ =>
            {
                string latestVersion = "";
                string downloadUrl = "";
                string releaseNotes = "";
                bool networkError = false;

                try
                {
                    // Primary: GitHub Releases API of the tenant's update repository
                    string updateRepo = TenantConfigService.Current != null ? TenantConfigService.Current.UpdateRepository : null;
                    if (string.IsNullOrWhiteSpace(updateRepo))
                        throw new InvalidOperationException("No update repository configured; using portal feed.");
                    updateRepo = updateRepo.Trim().Trim('/');
                    string GithubApiUrl = "https://api.github.com/repos/" + updateRepo + "/releases/latest";
                    // Add TLS 1.2 without removing protocols other code in the app relies on.
                    System.Net.ServicePointManager.SecurityProtocol |= System.Net.SecurityProtocolType.Tls12;

                    System.Net.HttpWebRequest req = (System.Net.HttpWebRequest)System.Net.WebRequest.Create(GithubApiUrl);
                    req.Timeout = 8000;
                    req.Method = "GET";
                    req.Accept = "application/vnd.github+json";
                    req.UserAgent = "SS-CAM/" + AppVersion.VersionString;

                    using (System.Net.HttpWebResponse resp = (System.Net.HttpWebResponse)req.GetResponse())
                    using (System.IO.StreamReader reader = new System.IO.StreamReader(resp.GetResponseStream()))
                    {
                        string json = reader.ReadToEnd();

                        // Parse "tag_name": "v4.0.0"  → strip leading 'v'
                        string tag = ExtractJsonValue(json, "tag_name");
                        if (!string.IsNullOrEmpty(tag))
                            latestVersion = tag.TrimStart('v', 'V');

                        // "body": "Release notes..."
                        releaseNotes = ExtractJsonValue(json, "body");
                        if (!string.IsNullOrEmpty(releaseNotes) && releaseNotes.Length > 120)
                            releaseNotes = releaseNotes.Substring(0, 120) + "…";

                        // Build the exe download URL from known naming convention
                        downloadUrl = string.Format(
                            "https://github.com/{1}/releases/download/v{0}/SS-CAM-v{0}.exe",
                            latestVersion, updateRepo);
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[SettingsPage] OnCheckUpdates (GitHub): " + ex.Message);

                    // Fallback: NAS version.json
                    try
                    {
                        string fallbackUrl = (TenantConfigService.Current != null && !string.IsNullOrWhiteSpace(TenantConfigService.Current.PortalUrl)) ? TenantConfigService.Current.PortalUrl.TrimEnd('/') + "/ss-cam/version.json" : "https://corporate.myds.me/ss-cam/version.json";
                        System.Net.ServicePointManager.ServerCertificateValidationCallback = (s, c, ch, er) => true;
                        System.Net.HttpWebRequest req2 = (System.Net.HttpWebRequest)System.Net.WebRequest.Create(fallbackUrl);
                        req2.Timeout = 5000;
                        req2.Method = "GET";
                        req2.Accept = "application/json";
                        using (System.Net.HttpWebResponse resp2 = (System.Net.HttpWebResponse)req2.GetResponse())
                        using (System.IO.StreamReader reader2 = new System.IO.StreamReader(resp2.GetResponseStream()))
                        {
                            string json2 = reader2.ReadToEnd();
                            latestVersion = ExtractJsonValue(json2, "version");
                            releaseNotes  = ExtractJsonValue(json2, "releaseNotes");
                            downloadUrl   = ExtractJsonValue(json2, "downloadUrl");
                        }
                    }
                    catch (Exception ex2)
                    {
                        System.Diagnostics.Debug.WriteLine("[SettingsPage] OnCheckUpdates (NAS fallback): " + ex2.Message);
                        networkError = true;
                    }
                }

                // Back on UI thread
                if (Application.Current != null)
                {
                    Application.Current.Dispatcher.Invoke(() =>
                    {
                        if (btn != null) btn.IsEnabled = true;

                        if (networkError || string.IsNullOrEmpty(latestVersion))
                        {
                            MessageBox.Show(
                                "Could not reach the update server.\nPlease check your internet or NAS connection and try again.",
                                "Update Check Failed",
                                MessageBoxButton.OK,
                                MessageBoxImage.Warning);
                            return;
                        }

                        bool isNewer = false;
                        try
                        {
                            isNewer = new Version(latestVersion).CompareTo(new Version(AppVersion.VersionString)) > 0;
                        }
                        catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[SettingsPage] VersionCompare: " + ex.Message); }

                        if (isNewer)
                        {
                            string notes = string.IsNullOrWhiteSpace(releaseNotes)
                                ? ""
                                : "\n\nWhat's new:\n" + releaseNotes;
                            string msg = string.Format(
                                "SS-CAM v{0} is available.{1}\n\nYou are running {2}.\n\nWould you like to download the update now?",
                                latestVersion, notes, AppVersion.DisplayVersion);

                            MessageBoxResult result = MessageBox.Show(
                                msg,
                                "Update Available",
                                MessageBoxButton.YesNo,
                                MessageBoxImage.Information);

                            if (result == MessageBoxResult.Yes && !string.IsNullOrEmpty(downloadUrl))
                            {
                                try
                                {
                                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                                    {
                                        FileName = downloadUrl,
                                        UseShellExecute = true
                                    });
                                }
                                catch (Exception ex3) { System.Diagnostics.Debug.WriteLine("[SettingsPage] OpenDownloadUrl: " + ex3.Message); }
                            }
                        }
                        else
                        {
                            MessageBox.Show(
                                string.Format("You are running SS-CAM {0}.\nThis is the latest version.", AppVersion.DisplayVersion),
                                "Up to Date",
                                MessageBoxButton.OK,
                                MessageBoxImage.Information);
                        }
                    });
                }
            });
        }

        /// <summary>
        /// Lightweight JSON string value extractor — no external dependencies.
        /// </summary>
        private static string ExtractJsonValue(string json, string key)
        {
            try
            {
                string search = string.Format("\"{0}\"", key);
                int keyIdx = json.IndexOf(search, StringComparison.OrdinalIgnoreCase);
                if (keyIdx < 0) return "";
                int colon = json.IndexOf(':', keyIdx + search.Length);
                if (colon < 0) return "";
                // Trim whitespace after colon
                int open = colon + 1;
                while (open < json.Length && (json[open] == ' ' || json[open] == '\t')) open++;
                if (open >= json.Length) return "";
                if (json[open] == '"')
                {
                    // String value
                    open++; // skip opening quote
                    int close = open;
                    while (close < json.Length)
                    {
                        if (json[close] == '\\') { close += 2; continue; } // skip escaped chars
                        if (json[close] == '"') break;
                        close++;
                    }
                    return json.Substring(open, close - open);
                }
                else
                {
                    // Non-string value (number, bool) — read until delimiter
                    int end = open;
                    while (end < json.Length && json[end] != ',' && json[end] != '}' && json[end] != '\n') end++;
                    return json.Substring(open, end - open).Trim();
                }
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[SettingsPage] ExtractJsonValue: " + ex.Message); return ""; }
        }

        private void OnManageCategoryPresetsClicked(object sender, RoutedEventArgs e)
        {
            if (Application.Current != null && Application.Current.MainWindow is MainWindow)
            {
                MainWindow mainWin = Application.Current.MainWindow as MainWindow;
                mainWin.NavigateTo(typeof(ProjectCreatorPage));
            }
        }

        private void OnSelectFalconiaTheme(object sender, RoutedEventArgs e)
        {
            ThemeService.ApplyTheme(AppTheme.Falconia);
        }

        private void OnSelectMetamorphosisTheme(object sender, RoutedEventArgs e)
        {
            ThemeService.ApplyTheme(AppTheme.Metamorphosis);
        }

        private void OnSelectCatppuccinTheme(object sender, RoutedEventArgs e)
        {
            ThemeService.ApplyTheme(AppTheme.Catppuccin);
        }

        private void OnSelectRosePineTheme(object sender, RoutedEventArgs e)
        {
            ThemeService.ApplyTheme(AppTheme.RosePine);
        }

        private void OnSelectNordTheme(object sender, RoutedEventArgs e)
        {
            ThemeService.ApplyTheme(AppTheme.Nord);
        }

        private void OnScrollViewerPreviewMouseWheel(object sender, System.Windows.Input.MouseWheelEventArgs e)
        {
            try
            {
                var sv = sender as ScrollViewer;
                if (sv == null) return;
                sv.ScrollToVerticalOffset(sv.VerticalOffset - e.Delta * 0.5);
                e.Handled = true;
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[SettingsPage] OnScrollViewerPreviewMouseWheel: " + ex.Message); }
        }


        public void OnDownloadSoftwareClicked(object sender, RoutedEventArgs e)
        {
            Button btn = sender as Button;
            if (btn != null && btn.Tag != null)
            {
                string url = btn.Tag.ToString();
                if (!string.IsNullOrEmpty(url))
                {
                    try
                    {
                        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                        {
                            FileName = url,
                            UseShellExecute = true
                        });
                    }
                    catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
                }
            }
        }

        private void OnResetProfileDefaults(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show("Are you sure you want to reset profile credentials to default Corporate Branding details?\n\n• Name: Corporate Branding\n• Department: Creative Department\n• Email: branding@company.com\n• Staff ID: CORP000X", "Reset Profile Defaults", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
            {
                currentProfile = UserProfileService.ResetToDefaults();
                LoadProfileData();

                if (Application.Current != null)
                {
                    MainWindow mainWin = Application.Current.MainWindow as MainWindow;
                    if (mainWin != null)
                    {
                        mainWin.RefreshProfileUI();
                    }
                }

                ProfileSaveStatus.Text = "Profile reset to default Corporate Branding credentials!";
                MessageBox.Show("Profile identity successfully reset:\n• Name: Corporate Branding\n• Department: Creative Department\n• Email: branding@company.com\n• Staff ID: CORP000X", "Reset Complete", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void OnClearAllData(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show("Are you sure you want to clear all local cache, session history, and reset profile to defaults?", "Clear Data & Cache", MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes)
            {
                UserProfileService.ClearAllDataAndCache();
                LoadProfileData();

                if (Application.Current != null)
                {
                    MainWindow mainWin = Application.Current.MainWindow as MainWindow;
                    if (mainWin != null)
                    {
                        mainWin.RefreshProfileUI();
                    }
                }

                ProfileSaveStatus.Text = "All local data cleared and profile reset!";
                MessageBox.Show("All local data & cache have been cleared, and profile has been reset to default SS Branding credentials.", "Data Cleared", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void OnOpenWorkstationHealthClicked(object sender, RoutedEventArgs e)
        {
            try
            {
                if (Application.Current != null && Application.Current.MainWindow is MainWindow)
                {
                    MainWindow mainWin = Application.Current.MainWindow as MainWindow;
                    mainWin.NavigateTo(typeof(WorkstationHealthPage));
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[SettingsPage] OnOpenWorkstationHealthClicked: " + ex.Message);
            }
        }
    }
}




