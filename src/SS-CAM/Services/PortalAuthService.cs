using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using SS_CAM.Utilities;

namespace SS_CAM.Services
{
    /// <summary>
    /// Outcome of a web portal sign-in or password change. ErrorMessage is plain language and safe to show to users.
    /// </summary>
    public class PortalAuthResult
    {
        public bool Success { get; set; }
        public bool MustChangePassword { get; set; }
        public string ErrorMessage { get; set; }
        public string DisplayName { get; set; }
        public string Username { get; set; }
    }

    /// <summary>
    /// The ONE place SS-CAM signs in to the web portal (POST api/auth/login) and hands out bearer tokens.
    /// Credentials are stored per Windows user in %LOCALAPPDATA%\&lt;AppFolderName&gt;\portal_account.dat with the
    /// password encrypted by DPAPI (CurrentUser scope). The password is never logged or written in plain text.
    /// Network failures are expected: every public method returns a result/null instead of throwing to the UI.
    /// </summary>
    public static class PortalAuthService
    {
        public const string MsgWrongCredentials = "Username or password is incorrect.";
        public const string MsgOffline = "Can't reach the web portal. Check your connection.";
        public const string MsgTooManyAttempts = "Too many attempts. Wait a minute and try again.";
        public const string MsgServerProblem = "The web portal had a problem. Try again in a few minutes.";
        public const string MsgNotConfigured = "The web portal address isn't configured.";

        private const string AccountFileName = "portal_account.dat";
        private const string FallbackPortalUrl = "https://creative.corporate.local/";

        // Server tokens last 12h; refresh a little early so a request never goes out with a token about to expire.
        private static readonly TimeSpan TokenLifetime = TimeSpan.FromMinutes(690);
        private static readonly TimeSpan RejectedBackoff = TimeSpan.FromMinutes(5);
        private static readonly TimeSpan OfflineBackoff = TimeSpan.FromSeconds(60);

        // Fixed, app-specific DPAPI entropy so other apps running as the same user can't trivially decrypt the file.
        private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("SS-CAM.PortalAccount.v1:7f3c9a1e-52d4-4b8e-9c61-0e2b7d84a5f3");

        private static readonly HttpClient _httpClient;
        private static readonly object _cacheLock = new object();
        private static readonly SemaphoreSlim _refreshGate = new SemaphoreSlim(1, 1);

        private static string _cachedToken;
        private static DateTime _tokenExpiryUtc = DateTime.MinValue;
        private static DateTime _silentRetryNotBeforeUtc = DateTime.MinValue;
        private static bool _savedCredentialsRejected;
        private static bool _savedAccountNeedsPasswordChange;

        // Pending password-change state (restricted token + the credentials just typed). Memory only.
        private static string _pendingToken;
        private static string _pendingUsername;
        private static string _pendingDisplayName;

        private static string _lastUsername;

        private class StoredAccount
        {
            [JsonProperty("username")]
            public string Username { get; set; }

            [JsonProperty("displayName")]
            public string DisplayName { get; set; }

            /// <summary>Base64 of the DPAPI-protected UTF-8 password bytes.</summary>
            [JsonProperty("password")]
            public string ProtectedPassword { get; set; }
        }

        static PortalAuthService()
        {
            try
            {
                ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] TLS 1.2 enable warning: " + ex.Message);
            }
            _httpClient = CreatePortalHttpClient(TimeSpan.FromSeconds(8));
        }

        #region Portal address and TLS

        /// <summary>
        /// Canonical web portal base URL (always ends with "/"), resolved from TenantConfig.PortalUrl.
        /// </summary>
        public static string PortalBaseUrl
        {
            get
            {
                if (TenantConfigService.Current != null && !string.IsNullOrWhiteSpace(TenantConfigService.Current.PortalUrl))
                {
                    string url = TenantConfigService.Current.PortalUrl.Trim();
                    return url.EndsWith("/") ? url : url + "/";
                }
                return FallbackPortalUrl;
            }
        }

        private static string PortalHost
        {
            get
            {
                Uri uri;
                if (Uri.TryCreate(PortalBaseUrl, UriKind.Absolute, out uri)) return uri.Host;
                return null;
            }
        }

        /// <summary>
        /// Certificate policy for portal traffic: accept a valid certificate for any host, and accept a
        /// certificate with errors ONLY for the configured portal host (the NAS portal may use a self-signed
        /// certificate). Every other host keeps normal certificate validation.
        /// </summary>
        public static bool IsCertificateAcceptable(Uri requestUri, SslPolicyErrors sslPolicyErrors)
        {
            if (sslPolicyErrors == SslPolicyErrors.None) return true;
            if (requestUri == null) return false;
            string portalHost = PortalHost;
            return !string.IsNullOrEmpty(portalHost) &&
                   string.Equals(requestUri.Host, portalHost, StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// Callback suitable for ServicePointManager.ServerCertificateValidationCallback (scoped to the portal host).
        /// </summary>
        public static bool ServicePointCertificateCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors)
        {
            if (sslPolicyErrors == SslPolicyErrors.None) return true;
            HttpWebRequest webRequest = sender as HttpWebRequest;
            return webRequest != null && IsCertificateAcceptable(webRequest.RequestUri, sslPolicyErrors);
        }

        /// <summary>
        /// Creates an HttpClient for portal calls whose handler applies the portal-scoped certificate policy.
        /// Callers must keep the instance in a static readonly field (one client per service).
        /// </summary>
        public static HttpClient CreatePortalHttpClient(TimeSpan timeout)
        {
            HttpClientHandler handler = new HttpClientHandler();
            handler.ServerCertificateCustomValidationCallback = delegate(HttpRequestMessage request, X509Certificate2 cert, X509Chain chain, SslPolicyErrors errors)
            {
                return IsCertificateAcceptable(request != null ? request.RequestUri : null, errors);
            };
            HttpClient client = new HttpClient(handler);
            client.Timeout = timeout;
            return client;
        }

        #endregion

        #region State

        public static bool IsSignedIn
        {
            get
            {
                StoredAccount account = LoadAccount();
                return account != null && !string.IsNullOrWhiteSpace(account.Username) && !string.IsNullOrWhiteSpace(account.ProtectedPassword);
            }
        }

        public static string SignedInUsername
        {
            get
            {
                StoredAccount account = LoadAccount();
                return account != null ? account.Username : null;
            }
        }

        public static string SignedInDisplayName
        {
            get
            {
                StoredAccount account = LoadAccount();
                if (account == null) return null;
                return !string.IsNullOrWhiteSpace(account.DisplayName) ? account.DisplayName : account.Username;
            }
        }

        /// <summary>Last username used in this session (survives sign-out) for pre-filling the sign-in form.</summary>
        public static string LastUsername
        {
            get
            {
                lock (_cacheLock)
                {
                    if (!string.IsNullOrWhiteSpace(_lastUsername)) return _lastUsername;
                }
                return SignedInUsername;
            }
        }

        /// <summary>True when the saved password was refused by the portal during a background sign-in.</summary>
        public static bool SavedCredentialsRejected
        {
            get { lock (_cacheLock) { return _savedCredentialsRejected; } }
        }

        /// <summary>True when the saved account must change its password before the portal will accept it.</summary>
        public static bool SavedAccountNeedsPasswordChange
        {
            get { lock (_cacheLock) { return _savedAccountNeedsPasswordChange; } }
        }

        /// <summary>True while a sign-in is waiting for the user to choose a new password.</summary>
        public static bool IsPasswordChangePending
        {
            get { lock (_cacheLock) { return !string.IsNullOrEmpty(_pendingToken); } }
        }

        /// <summary>Drops the cached token (e.g. after the portal answered 401/403) so the next call signs in again.</summary>
        public static void InvalidateToken()
        {
            lock (_cacheLock)
            {
                _cachedToken = null;
                _tokenExpiryUtc = DateTime.MinValue;
            }
        }

        #endregion

        #region Sign in / change password / sign out

        /// <summary>
        /// Signs in with a username, name, staff ID or email and password. On success (and no forced password
        /// change) the credentials are saved for silent background sign-in.
        /// </summary>
        public static async Task<PortalAuthResult> SignInAsync(string username, string password)
        {
            PortalAuthResult result = new PortalAuthResult();
            string uname = username != null ? username.Trim() : "";
            if (uname.Length == 0 || string.IsNullOrEmpty(password))
            {
                result.ErrorMessage = "Enter your username and password.";
                return result;
            }

            lock (_cacheLock) { _lastUsername = uname; }

            LoginOutcome outcome = await PostLoginAsync(uname, password).ConfigureAwait(false);
            result.Username = uname;
            result.ErrorMessage = outcome.ErrorMessage;
            result.DisplayName = outcome.DisplayName;
            if (!outcome.Success) return result;

            result.Success = true;
            if (outcome.MustChangePassword)
            {
                result.MustChangePassword = true;
                lock (_cacheLock)
                {
                    _pendingToken = outcome.Token;
                    _pendingUsername = uname;
                    _pendingDisplayName = outcome.DisplayName;
                }
                App.LogTrace("[PortalAuthService] Sign-in succeeded but the portal requires a password change.");
                return result;
            }

            bool saved = SaveAccount(uname, outcome.DisplayName, password);
            lock (_cacheLock)
            {
                _cachedToken = outcome.Token;
                _tokenExpiryUtc = DateTime.UtcNow.Add(TokenLifetime);
                _silentRetryNotBeforeUtc = DateTime.MinValue;
                _savedCredentialsRejected = false;
                _savedAccountNeedsPasswordChange = false;
                _pendingToken = null;
                _pendingUsername = null;
                _pendingDisplayName = null;
            }
            if (!saved)
            {
                App.LogTrace("[PortalAuthService] Signed in, but the account could not be saved; sign-in will not persist after restart.");
            }
            App.LogTrace("[PortalAuthService] Signed in to the web portal as '" + uname + "'.");
            return result;
        }

        /// <summary>
        /// Changes the portal password. Works for the forced change after sign-in (pending restricted token)
        /// and for a normal change while signed in. On success stores the new password and token.
        /// </summary>
        public static async Task<PortalAuthResult> ChangePasswordAsync(string currentPassword, string newPassword)
        {
            PortalAuthResult result = new PortalAuthResult();
            if (string.IsNullOrEmpty(currentPassword))
            {
                result.ErrorMessage = "Enter your current password.";
                return result;
            }
            if (string.IsNullOrEmpty(newPassword) || newPassword.Length < 10)
            {
                result.ErrorMessage = "Your new password must be at least 10 characters.";
                return result;
            }
            if (string.Equals(currentPassword, newPassword, StringComparison.Ordinal))
            {
                result.ErrorMessage = "Your new password must be different from your current password.";
                return result;
            }

            string token;
            string uname;
            string displayName;
            lock (_cacheLock)
            {
                token = _pendingToken;
                uname = _pendingUsername;
                displayName = _pendingDisplayName;
            }
            if (string.IsNullOrEmpty(token))
            {
                StoredAccount account = LoadAccount();
                if (account != null)
                {
                    uname = account.Username;
                    displayName = account.DisplayName;
                }
                token = await GetTokenAsync().ConfigureAwait(false);
            }
            if (string.IsNullOrEmpty(token) || string.IsNullOrWhiteSpace(uname))
            {
                result.ErrorMessage = "Sign in again, then change your password.";
                return result;
            }

            try
            {
                string json = JsonConvert.SerializeObject(new { currentPassword = currentPassword, newPassword = newPassword });
                using (HttpRequestMessage req = new HttpRequestMessage(HttpMethod.Post, PortalBaseUrl + "api/auth/change-password"))
                {
                    req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
                    req.Content = new StringContent(json, Encoding.UTF8, "application/json");
                    using (HttpResponseMessage res = await _httpClient.SendAsync(req).ConfigureAwait(false))
                    {
                        string body = await ReadBodySafeAsync(res).ConfigureAwait(false);
                        JObject root = TryParseObject(body);
                        int status = (int)res.StatusCode;

                        if (res.IsSuccessStatusCode)
                        {
                            string newToken = GetString(root, "token");
                            string newDisplay = ReadDisplayName(root, displayName ?? uname);
                            if (!SaveAccount(uname, newDisplay, newPassword))
                            {
                                App.LogTrace("[PortalAuthService] Password changed, but the account could not be saved locally.");
                            }
                            lock (_cacheLock)
                            {
                                _cachedToken = string.IsNullOrEmpty(newToken) ? null : newToken;
                                _tokenExpiryUtc = string.IsNullOrEmpty(newToken) ? DateTime.MinValue : DateTime.UtcNow.Add(TokenLifetime);
                                _pendingToken = null;
                                _pendingUsername = null;
                                _pendingDisplayName = null;
                                _savedCredentialsRejected = false;
                                _savedAccountNeedsPasswordChange = false;
                                _silentRetryNotBeforeUtc = DateTime.MinValue;
                            }
                            App.LogTrace("[PortalAuthService] Portal password changed for '" + uname + "'.");
                            result.Success = true;
                            result.Username = uname;
                            result.DisplayName = newDisplay;
                            return result;
                        }

                        App.LogTrace("[PortalAuthService] Change password failed with HTTP " + status + ".");
                        if (status == 400)
                        {
                            string serverError = GetString(root, "error");
                            result.ErrorMessage = IsShowableServerMessage(serverError)
                                ? serverError
                                : "Your password couldn't be changed. Check your current password and try again.";
                        }
                        else if (status == 401 || status == 403)
                        {
                            InvalidateToken();
                            result.ErrorMessage = "Your session has expired. Sign in again, then change your password.";
                        }
                        else if (status == 429)
                        {
                            result.ErrorMessage = MsgTooManyAttempts;
                        }
                        else
                        {
                            result.ErrorMessage = MsgServerProblem;
                        }
                        return result;
                    }
                }
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] Change password request failed: " + ex.GetType().Name + ": " + ex.Message);
                result.ErrorMessage = MsgOffline;
                return result;
            }
        }

        /// <summary>Abandons a pending forced password change (nothing is saved).</summary>
        public static void CancelPendingPasswordChange()
        {
            lock (_cacheLock)
            {
                _pendingToken = null;
                _pendingUsername = null;
                _pendingDisplayName = null;
            }
        }

        /// <summary>Deletes the stored account and every cached token.</summary>
        public static void SignOut()
        {
            string previous = SignedInUsername;
            lock (_cacheLock)
            {
                if (!string.IsNullOrWhiteSpace(previous)) _lastUsername = previous;
                _cachedToken = null;
                _tokenExpiryUtc = DateTime.MinValue;
                _pendingToken = null;
                _pendingUsername = null;
                _pendingDisplayName = null;
                _savedCredentialsRejected = false;
                _savedAccountNeedsPasswordChange = false;
                _silentRetryNotBeforeUtc = DateTime.MinValue;
            }
            try
            {
                string path = AccountFilePath;
                if (File.Exists(path)) File.Delete(path);
                App.LogTrace("[PortalAuthService] Signed out of the web portal.");
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] Could not delete the saved portal account: " + ex.Message);
            }
        }

        #endregion

        #region Token

        /// <summary>
        /// Returns a valid portal bearer token: the cached one if still fresh, otherwise signs in again silently
        /// with the saved account. Returns null when not signed in, offline, or the saved account was refused.
        /// Never throws.
        /// </summary>
        public static async Task<string> GetTokenAsync()
        {
            string cached = TryGetCachedToken();
            if (cached != null) return cached;

            try
            {
                await _refreshGate.WaitAsync().ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] Token refresh gate failed: " + ex.Message);
                return null;
            }

            try
            {
                // Another caller may have refreshed while we waited.
                cached = TryGetCachedToken();
                if (cached != null) return cached;

                lock (_cacheLock)
                {
                    if (DateTime.UtcNow < _silentRetryNotBeforeUtc) return null;
                }

                StoredAccount account = LoadAccount();
                if (account == null || string.IsNullOrWhiteSpace(account.Username) || string.IsNullOrWhiteSpace(account.ProtectedPassword))
                {
                    return null;
                }

                string password = UnprotectPassword(account.ProtectedPassword);
                if (string.IsNullOrEmpty(password))
                {
                    App.LogTrace("[PortalAuthService] Saved portal password could not be decrypted for this Windows user; sign in again in Settings.");
                    lock (_cacheLock) { _savedCredentialsRejected = true; }
                    return null;
                }

                LoginOutcome outcome = await PostLoginAsync(account.Username, password).ConfigureAwait(false);
                password = null;

                if (outcome.Success && !outcome.MustChangePassword && !string.IsNullOrEmpty(outcome.Token))
                {
                    lock (_cacheLock)
                    {
                        _cachedToken = outcome.Token;
                        _tokenExpiryUtc = DateTime.UtcNow.Add(TokenLifetime);
                        _savedCredentialsRejected = false;
                        _savedAccountNeedsPasswordChange = false;
                        _silentRetryNotBeforeUtc = DateTime.MinValue;
                        return _cachedToken;
                    }
                }

                lock (_cacheLock)
                {
                    if (outcome.Success && outcome.MustChangePassword)
                    {
                        _savedAccountNeedsPasswordChange = true;
                        _silentRetryNotBeforeUtc = DateTime.UtcNow.Add(RejectedBackoff);
                        App.LogTrace("[PortalAuthService] Background sign-in: the portal requires a password change; open Settings to continue.");
                    }
                    else if (outcome.CredentialsRejected)
                    {
                        _savedCredentialsRejected = true;
                        _silentRetryNotBeforeUtc = DateTime.UtcNow.Add(RejectedBackoff);
                        App.LogTrace("[PortalAuthService] Background sign-in: saved portal credentials were refused.");
                    }
                    else
                    {
                        _silentRetryNotBeforeUtc = DateTime.UtcNow.Add(OfflineBackoff);
                        App.LogTrace("[PortalAuthService] Background sign-in failed: " + (outcome.LogDetail ?? "unknown"));
                    }
                }
                return null;
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] GetTokenAsync failed: " + ex.GetType().Name + ": " + ex.Message);
                return null;
            }
            finally
            {
                _refreshGate.Release();
            }
        }

        private static string TryGetCachedToken()
        {
            lock (_cacheLock)
            {
                if (!string.IsNullOrEmpty(_cachedToken) && DateTime.UtcNow < _tokenExpiryUtc) return _cachedToken;
            }
            return null;
        }

        #endregion

        #region HTTP helpers

        private class LoginOutcome
        {
            public bool Success { get; set; }
            public bool MustChangePassword { get; set; }
            public bool CredentialsRejected { get; set; }
            public string Token { get; set; }
            public string DisplayName { get; set; }
            public string ErrorMessage { get; set; }
            public string LogDetail { get; set; }
        }

        private static async Task<LoginOutcome> PostLoginAsync(string username, string password)
        {
            LoginOutcome outcome = new LoginOutcome();
            Uri baseUri;
            if (!Uri.TryCreate(PortalBaseUrl, UriKind.Absolute, out baseUri))
            {
                outcome.ErrorMessage = MsgNotConfigured;
                outcome.LogDetail = "invalid portal URL";
                return outcome;
            }

            try
            {
                string json = JsonConvert.SerializeObject(new { username = username, password = password });
                using (HttpRequestMessage req = new HttpRequestMessage(HttpMethod.Post, PortalBaseUrl + "api/auth/login"))
                {
                    req.Content = new StringContent(json, Encoding.UTF8, "application/json");
                    using (HttpResponseMessage res = await _httpClient.SendAsync(req).ConfigureAwait(false))
                    {
                        string body = await ReadBodySafeAsync(res).ConfigureAwait(false);
                        JObject root = TryParseObject(body);
                        int status = (int)res.StatusCode;

                        if (res.IsSuccessStatusCode)
                        {
                            string token = GetString(root, "token");
                            if (string.IsNullOrEmpty(token))
                            {
                                outcome.ErrorMessage = MsgServerProblem;
                                outcome.LogDetail = "login response had no token";
                                return outcome;
                            }
                            outcome.Success = true;
                            outcome.Token = token;
                            outcome.MustChangePassword = GetBool(root, "mustChangePassword");
                            outcome.DisplayName = ReadDisplayName(root, username);
                            return outcome;
                        }

                        outcome.LogDetail = "HTTP " + status;
                        if (status == 401)
                        {
                            outcome.CredentialsRejected = true;
                            outcome.ErrorMessage = MsgWrongCredentials;
                        }
                        else if (status == 429)
                        {
                            outcome.ErrorMessage = MsgTooManyAttempts;
                        }
                        else if (status == 400 || status == 403)
                        {
                            // e.g. disabled account; show the server's plain message when it is reasonable.
                            outcome.CredentialsRejected = status == 403;
                            string serverError = GetString(root, "error");
                            outcome.ErrorMessage = IsShowableServerMessage(serverError) ? serverError : MsgWrongCredentials;
                        }
                        else if (status == 404)
                        {
                            outcome.ErrorMessage = MsgOffline;
                        }
                        else
                        {
                            outcome.ErrorMessage = MsgServerProblem;
                        }
                        App.LogTrace("[PortalAuthService] Portal sign-in refused: " + outcome.LogDetail + ".");
                        return outcome;
                    }
                }
            }
            catch (Exception ex)
            {
                // Timeouts surface as TaskCanceledException; offline/DNS/TLS as HttpRequestException.
                outcome.ErrorMessage = MsgOffline;
                outcome.LogDetail = ex.GetType().Name + ": " + ex.Message;
                App.LogTrace("[PortalAuthService] Portal sign-in request failed: " + outcome.LogDetail);
                return outcome;
            }
        }

        private static async Task<string> ReadBodySafeAsync(HttpResponseMessage res)
        {
            try
            {
                if (res == null || res.Content == null) return null;
                return await res.Content.ReadAsStringAsync().ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] Could not read portal response body: " + ex.Message);
                return null;
            }
        }

        private static JObject TryParseObject(string body)
        {
            if (string.IsNullOrWhiteSpace(body)) return null;
            try
            {
                return JObject.Parse(body);
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] Portal response was not JSON: " + ex.Message);
                return null;
            }
        }

        private static string GetString(JObject root, string key)
        {
            if (root == null) return null;
            JToken token = root[key];
            if (token == null || token.Type == JTokenType.Null) return null;
            return token.ToString();
        }

        private static bool GetBool(JObject root, string key)
        {
            if (root == null) return false;
            JToken token = root[key];
            if (token == null) return false;
            if (token.Type == JTokenType.Boolean) return (bool)token;
            return string.Equals(token.ToString(), "true", StringComparison.OrdinalIgnoreCase);
        }

        private static string ReadDisplayName(JObject root, string fallback)
        {
            if (root != null)
            {
                JObject user = root["user"] as JObject;
                if (user != null)
                {
                    string name = GetString(user, "name");
                    if (!string.IsNullOrWhiteSpace(name)) return name.Trim();
                    string uname = GetString(user, "username");
                    if (!string.IsNullOrWhiteSpace(uname)) return uname.Trim();
                }
            }
            return fallback;
        }

        private static bool IsShowableServerMessage(string message)
        {
            return !string.IsNullOrWhiteSpace(message) && message.Length <= 160 &&
                   message.IndexOf("Exception", StringComparison.OrdinalIgnoreCase) < 0 &&
                   message.IndexOf(" at ", StringComparison.Ordinal) < 0;
        }

        #endregion

        #region Credential storage (DPAPI)

        private static string AccountFilePath
        {
            get { return Path.Combine(AppPaths.AppDataFolder, AccountFileName); }
        }

        private static StoredAccount LoadAccount()
        {
            try
            {
                string path = AccountFilePath;
                if (!File.Exists(path)) return null;
                string json = File.ReadAllText(path, Encoding.UTF8);
                if (string.IsNullOrWhiteSpace(json)) return null;
                return JsonConvert.DeserializeObject<StoredAccount>(json);
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] Could not read the saved portal account: " + ex.Message);
                return null;
            }
        }

        private static bool SaveAccount(string username, string displayName, string password)
        {
            string tempPath = null;
            try
            {
                StoredAccount account = new StoredAccount();
                account.Username = username;
                account.DisplayName = displayName;
                account.ProtectedPassword = ProtectPassword(password);

                string path = AccountFilePath;
                tempPath = path + ".tmp";
                File.WriteAllText(tempPath, JsonConvert.SerializeObject(account), new UTF8Encoding(false));
                if (File.Exists(path))
                {
                    File.Replace(tempPath, path, null);
                }
                else
                {
                    File.Move(tempPath, path);
                }
                return true;
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] Could not save the portal account: " + ex.GetType().Name);
                try
                {
                    if (tempPath != null && File.Exists(tempPath)) File.Delete(tempPath);
                }
                catch (Exception cleanupEx)
                {
                    App.LogTrace("[PortalAuthService] Could not remove temporary account file: " + cleanupEx.Message);
                }
                return false;
            }
        }

        private static string ProtectPassword(string password)
        {
            byte[] plain = Encoding.UTF8.GetBytes(password ?? "");
            try
            {
                byte[] encrypted = ProtectedData.Protect(plain, Entropy, DataProtectionScope.CurrentUser);
                return Convert.ToBase64String(encrypted);
            }
            finally
            {
                Array.Clear(plain, 0, plain.Length);
            }
        }

        private static string UnprotectPassword(string protectedBase64)
        {
            if (string.IsNullOrEmpty(protectedBase64)) return null;
            try
            {
                byte[] encrypted = Convert.FromBase64String(protectedBase64);
                byte[] plain = ProtectedData.Unprotect(encrypted, Entropy, DataProtectionScope.CurrentUser);
                string password = Encoding.UTF8.GetString(plain);
                Array.Clear(plain, 0, plain.Length);
                return password;
            }
            catch (Exception ex)
            {
                App.LogTrace("[PortalAuthService] Saved password could not be decrypted: " + ex.GetType().Name);
                return null;
            }
        }

        #endregion
    }
}
