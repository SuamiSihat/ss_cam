using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows;
using System.Windows.Media;
using Newtonsoft.Json;
using SS_CAM.Models;
using SS_CAM.Utilities;

namespace SS_CAM.Services
{
    public class RadioConfigData
    {
        public string LastStationId { get; set; }
        public double Volume { get; set; }
        public bool IsMuted { get; set; }
        public List<RadioStation> SavedStations { get; set; }
        public List<string> FavoriteStationIds { get; set; }

        public RadioConfigData()
        {
            Volume = 0.8;
            IsMuted = false;
            SavedStations = new List<RadioStation>();
            FavoriteStationIds = new List<string>();
        }
    }

    public enum RadioPlaybackState
    {
        Stopped,
        Buffering,
        Playing,
        Paused,
        Error
    }

    public static class PlaylistHelper
    {
        public static string ResolveStreamUrl(string url, int maxDepth = 2)
        {
            if (string.IsNullOrWhiteSpace(url)) return url;
            url = url.Trim();

            if (!url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) &&
                !url.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            {
                return url;
            }

            bool isPlaylistExt = url.IndexOf(".m3u", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                 url.IndexOf(".m3u8", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                 url.IndexOf(".pls", StringComparison.OrdinalIgnoreCase) >= 0;

            if (!isPlaylistExt)
            {
                return url;
            }

            try
            {
                ServicePointManager.ServerCertificateValidationCallback = (s, cert, chain, sslPolicyErrors) => true;
                HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
                req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) SS-CAM/4.6.3";
                req.Timeout = 5000;
                req.AllowAutoRedirect = true;

                using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
                {
                    Uri baseUri = resp.ResponseUri ?? new Uri(url);
                    using (Stream s = resp.GetResponseStream())
                    using (StreamReader reader = new StreamReader(s, System.Text.Encoding.UTF8))
                    {
                        string body = reader.ReadToEnd();
                        string stream = ParseFirstStreamUrl(body, baseUri);
                        if (!string.IsNullOrWhiteSpace(stream) && !stream.Equals(url, StringComparison.OrdinalIgnoreCase))
                        {
                            if (maxDepth > 0 && (stream.IndexOf(".m3u", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                                 stream.IndexOf(".pls", StringComparison.OrdinalIgnoreCase) >= 0))
                            {
                                return ResolveStreamUrl(stream, maxDepth - 1);
                            }
                            return stream;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[PlaylistHelper] ResolveStreamUrl error: " + ex.Message);
            }

            return url;
        }

        public static string ParseFirstStreamUrl(string content, Uri baseUri = null)
        {
            if (string.IsNullOrWhiteSpace(content)) return null;

            string[] lines = content.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.RemoveEmptyEntries);

            if (content.Contains("[playlist]"))
            {
                foreach (string l in lines)
                {
                    string line = l.Trim();
                    if (line.StartsWith("File", StringComparison.OrdinalIgnoreCase))
                    {
                        var match = Regex.Match(line, @"File\d+=(.*)", RegexOptions.IgnoreCase);
                        if (match.Success)
                        {
                            string target = match.Groups[1].Value.Trim();
                            return ResolveAbsoluteUri(target, baseUri);
                        }
                    }
                }
            }

            foreach (string l in lines)
            {
                string line = l.Trim();
                if (string.IsNullOrWhiteSpace(line) || line.StartsWith("#")) continue;

                return ResolveAbsoluteUri(line, baseUri);
            }

            return null;
        }

        public static string ResolveAbsoluteUri(string rawUri, Uri baseUri)
        {
            if (string.IsNullOrWhiteSpace(rawUri)) return rawUri;
            rawUri = rawUri.Trim();

            if (Uri.IsWellFormedUriString(rawUri, UriKind.Absolute))
            {
                return rawUri;
            }

            if (baseUri != null)
            {
                try
                {
                    Uri resolved = new Uri(baseUri, rawUri);
                    return resolved.AbsoluteUri;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[PlaylistHelper] ResolveAbsoluteUri: " + ex.Message);
                }
            }

            return rawUri;
        }

        public static List<RadioStation> ParseM3U(string content, string sourceName, Uri baseUri = null)
        {
            List<RadioStation> stations = new List<RadioStation>();
            if (string.IsNullOrWhiteSpace(content)) return stations;

            string[] lines = content.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.RemoveEmptyEntries);
            string currentTitle = "";
            string currentGenre = "Imported";
            string currentLogo = "";

            foreach (string l in lines)
            {
                string line = l.Trim();
                if (line.StartsWith("#EXTINF:", StringComparison.OrdinalIgnoreCase))
                {
                    var groupMatch = Regex.Match(line, @"group-title=""([^""]+)""", RegexOptions.IgnoreCase);
                    if (groupMatch.Success)
                    {
                        currentGenre = groupMatch.Groups[1].Value.Trim();
                    }

                    var logoMatch = Regex.Match(line, @"(?:tvg-logo|logo)=""([^""]+)""", RegexOptions.IgnoreCase);
                    if (logoMatch.Success)
                    {
                        currentLogo = logoMatch.Groups[1].Value.Trim();
                    }

                    int commaIdx = line.IndexOf(',');
                    if (commaIdx >= 0)
                    {
                        currentTitle = line.Substring(commaIdx + 1).Trim();
                    }
                    else
                    {
                        var nameMatch = Regex.Match(line, @"tvg-name=""([^""]+)""", RegexOptions.IgnoreCase);
                        if (nameMatch.Success)
                        {
                            currentTitle = nameMatch.Groups[1].Value.Trim();
                        }
                    }
                }
                else if (!string.IsNullOrWhiteSpace(line) && !line.StartsWith("#"))
                {
                    string streamUrl = ResolveAbsoluteUri(line, baseUri);
                    string title = !string.IsNullOrWhiteSpace(currentTitle) ? currentTitle : sourceName;

                    RadioStation station = new RadioStation
                    {
                        Name = title,
                        StreamUrl = streamUrl,
                        Genre = !string.IsNullOrWhiteSpace(currentGenre) ? currentGenre : "Imported",
                        IconEmoji = "📻",
                        CoverImageUrl = !string.IsNullOrWhiteSpace(currentLogo) ? currentLogo : null,
                        Description = "Imported from M3U playlist (" + sourceName + ")"
                    };

                    stations.Add(station);

                    currentTitle = "";
                    currentGenre = "Imported";
                    currentLogo = "";
                }
            }

            return stations;
        }

        public static List<RadioStation> ParsePLS(string content, string sourceName, Uri baseUri = null)
        {
            List<RadioStation> stations = new List<RadioStation>();
            if (string.IsNullOrWhiteSpace(content)) return stations;

            Dictionary<int, string> files = new Dictionary<int, string>();
            Dictionary<int, string> titles = new Dictionary<int, string>();

            string[] lines = content.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string l in lines)
            {
                string line = l.Trim();
                if (line.StartsWith("File", StringComparison.OrdinalIgnoreCase))
                {
                    var match = Regex.Match(line, @"File(\d+)=(.*)", RegexOptions.IgnoreCase);
                    if (match.Success)
                    {
                        int idx = int.Parse(match.Groups[1].Value);
                        files[idx] = match.Groups[2].Value.Trim();
                    }
                }
                else if (line.StartsWith("Title", StringComparison.OrdinalIgnoreCase))
                {
                    var match = Regex.Match(line, @"Title(\d+)=(.*)", RegexOptions.IgnoreCase);
                    if (match.Success)
                    {
                        int idx = int.Parse(match.Groups[1].Value);
                        titles[idx] = match.Groups[2].Value.Trim();
                    }
                }
            }

            foreach (var kvp in files)
            {
                int idx = kvp.Key;
                string streamUrl = ResolveAbsoluteUri(kvp.Value, baseUri);
                string title = titles.ContainsKey(idx) ? titles[idx] : sourceName;

                if (!string.IsNullOrWhiteSpace(streamUrl))
                {
                    RadioStation station = new RadioStation
                    {
                        Name = title,
                        StreamUrl = streamUrl,
                        Genre = "Imported",
                        IconEmoji = "🎵",
                        Description = "Imported from PLS playlist (" + sourceName + ")"
                    };
                    stations.Add(station);
                }
            }

            return stations;
        }

        public static string GenerateM3U(IEnumerable<RadioStation> stations)
        {
            var sb = new System.Text.StringBuilder();
            sb.AppendLine("#EXTM3U");
            if (stations != null)
            {
                foreach (var station in stations)
                {
                    if (string.IsNullOrWhiteSpace(station.StreamUrl)) continue;

                    string name = !string.IsNullOrWhiteSpace(station.Name) ? station.Name.Replace(",", " ") : "Radio Stream";
                    string genre = !string.IsNullOrWhiteSpace(station.Genre) ? station.Genre : "Radio";
                    string logoAttr = !string.IsNullOrWhiteSpace(station.CoverImageUrl) ? string.Format(" tvg-logo=\"{0}\"", station.CoverImageUrl) : "";

                    sb.AppendLine(string.Format("#EXTINF:-1 tvg-name=\"{0}\" group-title=\"{1}\"{2},{0}", name, genre, logoAttr));
                    sb.AppendLine(station.StreamUrl.Trim());
                }
            }
            return sb.ToString();
        }
    }

    public class LocalAudioProxy
    {
        private HttpListener _listener;
        private Thread _listenerThread;
        private string _targetStreamUrl;
        private bool _isRunning;
        private const int ProxyPort = 28193;

        public double[] CurrentSpectrumData { get; private set; }
        public double CurrentPeakAmplitude { get; private set; }

        public event Action<string> StreamTitleChanged;
        public string CurrentStreamTitle { get; private set; }

        public LocalAudioProxy()
        {
            CurrentSpectrumData = new double[48];
            CurrentPeakAmplitude = 0.0;
        }

        public string LocalProxyUrl
        {
            get { return string.Format("http://127.0.0.1:{0}/live.mp3", ProxyPort); }
        }

        public void Start(string targetStreamUrl)
        {
            Stop();
            CurrentStreamTitle = null;
            if (StreamTitleChanged != null) StreamTitleChanged(null);

            _targetStreamUrl = targetStreamUrl;
            _isRunning = true;

            try
            {
                _listener = new HttpListener();
                _listener.Prefixes.Add(string.Format("http://127.0.0.1:{0}/", ProxyPort));
                _listener.Start();

                _listenerThread = new Thread(ListenLoop);
                _listenerThread.IsBackground = true;
                _listenerThread.Start();
            }
            catch
            {
                _isRunning = false;
            }
        }

        public void Stop()
        {
            _isRunning = false;
            CurrentPeakAmplitude = 0.0;
            Array.Clear(CurrentSpectrumData, 0, CurrentSpectrumData.Length);

            try
            {
                if (_listener != null)
                {
                    _listener.Stop();
                    _listener.Close();
                    _listener = null;
                }
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }

            if (_listenerThread != null && _listenerThread.IsAlive)
            {
                try { _listenerThread.Abort(); } catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
                _listenerThread = null;
            }
        }

        private void ListenLoop()
        {
            while (_isRunning && _listener != null && _listener.IsListening)
            {
                try
                {
                    HttpListenerContext context = _listener.GetContext();
                    ThreadPool.QueueUserWorkItem(state => ProcessRequest(context));
                }
                catch
                {
                    break;
                }
            }
        }

        private void ProcessRequest(HttpListenerContext context)
        {
            HttpListenerResponse response = context.Response;
            HttpWebRequest remoteReq = null;
            HttpWebResponse remoteResp = null;
            Stream remoteStream = null;

            try
            {
                response.ContentType = "audio/mpeg";
                response.Headers.Add("Access-Control-Allow-Origin", "*");
                response.Headers.Add("Cache-Control", "no-cache, no-store");

                ServicePointManager.ServerCertificateValidationCallback = (s, cert, chain, sslPolicyErrors) => true;

                string activeUrl = PlaylistHelper.ResolveStreamUrl(_targetStreamUrl);

                remoteReq = (HttpWebRequest)WebRequest.Create(activeUrl);
                remoteReq.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
                remoteReq.Timeout = 8000;
                remoteReq.ReadWriteTimeout = 8000;
                remoteReq.AllowAutoRedirect = true;
                remoteReq.Headers.Add("Icy-MetaData", "1"); // Request ICY Metadata

                remoteResp = (HttpWebResponse)remoteReq.GetResponse();

                string cType = remoteResp.ContentType != null ? remoteResp.ContentType.ToLower() : "";
                if (cType.Contains("mpegurl") || cType.Contains("x-scpls") || cType.Contains("playlist"))
                {
                    using (Stream s = remoteResp.GetResponseStream())
                    using (StreamReader reader = new StreamReader(s, System.Text.Encoding.UTF8))
                    {
                        string body = reader.ReadToEnd();
                        Uri baseUri = remoteResp.ResponseUri ?? new Uri(activeUrl);
                        string nestedUrl = PlaylistHelper.ParseFirstStreamUrl(body, baseUri);
                        if (!string.IsNullOrWhiteSpace(nestedUrl) && !nestedUrl.Equals(activeUrl, StringComparison.OrdinalIgnoreCase))
                        {
                            remoteResp.Close();
                            activeUrl = nestedUrl;
                            remoteReq = (HttpWebRequest)WebRequest.Create(activeUrl);
                            remoteReq.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
                            remoteReq.Timeout = 8000;
                            remoteReq.ReadWriteTimeout = 8000;
                            remoteReq.AllowAutoRedirect = true;
                            remoteReq.Headers.Add("Icy-MetaData", "1");
                            remoteResp = (HttpWebResponse)remoteReq.GetResponse();
                        }
                    }
                }
                
                int metaInt = 0;
                string metaIntStr = remoteResp.Headers.Get("icy-metaint");
                if (!string.IsNullOrEmpty(metaIntStr))
                {
                    int.TryParse(metaIntStr, out metaInt);
                }

                remoteStream = remoteResp.GetResponseStream();

                byte[] buffer = new byte[8192];
                Stream outStream = response.OutputStream;
                int bytesUntilMeta = metaInt;

                while (_isRunning && remoteStream != null)
                {
                    if (metaInt > 0)
                    {
                        if (bytesUntilMeta > 0)
                        {
                            int toRead = Math.Min(buffer.Length, bytesUntilMeta);
                            int bytesRead = remoteStream.Read(buffer, 0, toRead);
                            if (bytesRead <= 0) break;

                            outStream.Write(buffer, 0, bytesRead);
                            outStream.Flush();

                            AnalyzeAudioBuffer(buffer, bytesRead);
                            bytesUntilMeta -= bytesRead;
                        }
                        else
                        {
                            // Metadata block
                            int lengthByte = remoteStream.ReadByte();
                            if (lengthByte < 0) break;

                            int metaLen = lengthByte * 16;
                            if (metaLen > 0)
                            {
                                byte[] metaBuffer = new byte[metaLen];
                                int totalRead = 0;
                                while (totalRead < metaLen)
                                {
                                    int r = remoteStream.Read(metaBuffer, totalRead, metaLen - totalRead);
                                    if (r <= 0) break;
                                    totalRead += r;
                                }
                                
                                string metaString = System.Text.Encoding.UTF8.GetString(metaBuffer).TrimEnd('\0');
                                ParseMetadata(metaString);
                            }
                            
                            bytesUntilMeta = metaInt;
                        }
                    }
                    else
                    {
                        int bytesRead = remoteStream.Read(buffer, 0, buffer.Length);
                        if (bytesRead <= 0) break;

                        outStream.Write(buffer, 0, bytesRead);
                        outStream.Flush();

                        // Real-Time Audio Energy & 48 Frequency Band Spectrum Sampling
                        AnalyzeAudioBuffer(buffer, bytesRead);
                    }
                }
            }
            catch
            {
                try { response.StatusCode = 500; } catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
            }
            finally
            {
                try { if (remoteStream != null) remoteStream.Close(); } catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
                try { if (remoteResp != null) remoteResp.Close(); } catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
                try { response.Close(); } catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
            }
        }

        private void ParseMetadata(string metaString)
        {
            try
            {
                var match = Regex.Match(metaString, @"StreamTitle='([^']*)';");
                if (match.Success)
                {
                    string title = match.Groups[1].Value.Trim();
                    if (string.IsNullOrEmpty(title) || title.ToLower() == "unknown")
                    {
                        title = null;
                    }

                    if (title != CurrentStreamTitle)
                    {
                        CurrentStreamTitle = title;
                        if (Application.Current != null)
                        {
                            Application.Current.Dispatcher.BeginInvoke(new Action(() =>
                            {
                                if (StreamTitleChanged != null) StreamTitleChanged(title);
                            }));
                        }
                    }
                }
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
        }

        private void AnalyzeAudioBuffer(byte[] buffer, int length)
        {
            try
            {
                int samples = length / 2;
                if (samples <= 0) return;

                double sumSq = 0;
                double[] bands = new double[48];
                int bandSize = Math.Max(1, samples / 48);

                for (int i = 0; i < length - 1; i += 2)
                {
                    short sample = (short)(buffer[i] | (buffer[i + 1] << 8));
                    double norm = Math.Abs(sample / 32768.0);
                    sumSq += norm * norm;

                    int bandIdx = (i / 2) / bandSize;
                    if (bandIdx >= 48) bandIdx = 47;
                    bands[bandIdx] += norm;
                }

                double rms = Math.Sqrt(sumSq / samples);
                CurrentPeakAmplitude = Math.Min(1.0, rms * 4.5);

                for (int b = 0; b < 48; b++)
                {
                    bands[b] = Math.Min(1.0, (bands[b] / bandSize) * 3.5);
                }

                CurrentSpectrumData = bands;
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
        }
    }

    public class RadioStreamService
    {
        private static RadioStreamService _instance;
        public static RadioStreamService Instance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = new RadioStreamService();
                }
                return _instance;
            }
        }

        static RadioStreamService()
        {
            EnableUnsafeHeaderParsing();
        }

        private static void EnableUnsafeHeaderParsing()
        {
            try
            {
                Type settingsType = Type.GetType("System.Net.Configuration.SettingsSectionInternal, System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089");
                if (settingsType != null)
                {
                    object instance = settingsType.InvokeMember("Section",
                        BindingFlags.Static | BindingFlags.GetProperty | BindingFlags.NonPublic,
                        null, null, new object[] { });

                    if (instance != null)
                    {
                        FieldInfo useUnsafeHeaderParsingField = settingsType.GetField("useUnsafeHeaderParsing",
                            BindingFlags.Instance | BindingFlags.NonPublic);

                        if (useUnsafeHeaderParsingField != null)
                        {
                            useUnsafeHeaderParsingField.SetValue(instance, true);
                        }
                    }
                }
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
        }

        private MediaPlayer _mediaPlayer;
        private LocalAudioProxy _localProxy;
        private readonly string _configFilePath;
        private RadioConfigData _config;

        public LocalAudioProxy LocalProxy
        {
            get { return _localProxy; }
        }

        public event Action<RadioPlaybackState> PlaybackStateChanged;
        public event Action<RadioStation> StationChanged;
        public event Action<double, bool> VolumeChanged;
        public event Action<string> ErrorOccurred;
        public event Action<string> StreamTitleChanged;

        public RadioPlaybackState State { get; private set; }
        public RadioStation CurrentStation { get; private set; }
        public List<RadioStation> AllStations { get; private set; }

        public double Volume
        {
            get
            {
                return _config != null ? _config.Volume : 0.8;
            }
            set
            {
                if (_config != null)
                {
                    _config.Volume = Math.Max(0.0, Math.Min(1.0, value));
                    EnsureUI(() =>
                    {
                        if (_mediaPlayer != null && !_config.IsMuted)
                        {
                            _mediaPlayer.Volume = _config.Volume;
                        }
                    });
                    SaveConfig();
                    if (VolumeChanged != null)
                    {
                        VolumeChanged(_config.Volume, _config.IsMuted);
                    }
                }
            }
        }

        public bool IsMuted
        {
            get
            {
                return _config != null && _config.IsMuted;
            }
            set
            {
                if (_config != null)
                {
                    _config.IsMuted = value;
                    EnsureUI(() =>
                    {
                        if (_mediaPlayer != null)
                        {
                            _mediaPlayer.Volume = _config.IsMuted ? 0.0 : _config.Volume;
                        }
                    });
                    SaveConfig();
                    if (VolumeChanged != null)
                    {
                        VolumeChanged(_config.Volume, _config.IsMuted);
                    }
                }
            }
        }

        public RadioStreamService()
        {
            State = RadioPlaybackState.Stopped;
            AllStations = new List<RadioStation>();
            _localProxy = new LocalAudioProxy();
            _localProxy.StreamTitleChanged += (title) => { if (StreamTitleChanged != null) StreamTitleChanged(title); };

            string ssDir = AppPaths.AppDataFolder;
            _configFilePath = Path.Combine(ssDir, "radio_config.json");

            LoadStations();
        }

        private void EnsureUI(Action action)
        {
            if (Application.Current == null) return;

            if (Application.Current.Dispatcher.CheckAccess())
            {
                action();
            }
            else
            {
                Application.Current.Dispatcher.Invoke(action);
            }
        }

        private void EnsureMediaPlayerCreated()
        {
            EnsureUI(() =>
            {
                if (_mediaPlayer == null)
                {
                    _mediaPlayer = new MediaPlayer();

                    _mediaPlayer.MediaOpened += (s, e) =>
                    {
                        SetState(RadioPlaybackState.Playing);
                    };

                    _mediaPlayer.MediaEnded += (s, e) =>
                    {
                        SetState(RadioPlaybackState.Stopped);
                    };

                    _mediaPlayer.MediaFailed += (s, e) =>
                    {
                        SetState(RadioPlaybackState.Error);
                        string errMsg = "Stream connection failed";
                        if (e.ErrorException != null && !string.IsNullOrWhiteSpace(e.ErrorException.Message))
                        {
                            errMsg = e.ErrorException.Message;
                        }
                        if (ErrorOccurred != null)
                        {
                            ErrorOccurred(errMsg);
                        }
                    };
                }
            });
        }

        private void LoadStations()
        {
            _config = LoadConfig();

            if (_config.SavedStations != null && _config.SavedStations.Count > 0)
            {
                AllStations = new List<RadioStation>(_config.SavedStations);

                // Purge removed station presets
                AllStations.RemoveAll(s => s.Id == "preset_fm988" || s.Id == "preset_aifm" || s.Id == "preset_cityplus" || s.Name.Contains("988 FM") || s.Name.Contains("Ai FM") || s.Name.Contains("CITYPlus"));

                // Ensure Nightwave Plaza is present
                if (!AllStations.Any(s => s.Id == "preset_nightwave" || s.Name.Contains("Nightwave")))
                {
                    AllStations.Add(new RadioStation
                    {
                        Id = "preset_nightwave",
                        Name = "Nightwave Plaza",
                        Genre = "Synthwave / Vaporwave",
                        StreamUrl = "https://radio.plaza.one/mp3",
                        CoverImageUrl = "https://plaza.one/favicon.ico",
                        IconEmoji = "🌃",
                        IsPreset = true,
                        Description = "24/7 Aesthetic Vaporwave & Synthwave soundtrack for late-night designing & deep focus."
                    });
                }

                // Ensure Groove Salad is present
                if (!AllStations.Any(s => s.Id == "preset_groovesalad" || s.Name.Contains("Groove Salad")))
                {
                    AllStations.Add(new RadioStation
                    {
                        Id = "preset_groovesalad",
                        Name = "SomaFM: Groove Salad",
                        Genre = "Downtempo / Ambient",
                        StreamUrl = "https://ice6.somafm.com/groovesalad-256-mp3",
                        CoverImageUrl = "https://somafm.com/img3/groovesalad-400.jpg",
                        IconEmoji = "🥗",
                        IsPreset = true,
                        Description = "A nicely chilled plate of ambient/downtempo beats and grooves for creative flow."
                    });
                }

                // Update BABYMETAL station if it used old jango URL
                var bm = AllStations.FirstOrDefault(s => s.Id == "preset_babymetal" || s.Name.Contains("BABYMETAL"));
                if (bm != null)
                {
                    bm.StreamUrl = "https://animefm.stream.laut.fm/animefm";
                    bm.Name = "BABYMETAL & J-Rock Radio";
                    bm.Description = "24/7 BABYMETAL, J-Rock, Anime & High-Energy Japanese Metal Station.";
                }
                else
                {
                    AllStations.Insert(1, GetBabymetalStation());
                }

                // Ensure Initial D is present
                if (!AllStations.Any(s => s.StreamUrl.Contains("165.227.19.100") || s.Name.Contains("Initial D")))
                {
                    AllStations.Insert(0, GetInitialDStation());
                }

                // Ensure SuamiSihat Radio is present as the pinned first station
                var existingSs = AllStations.FirstOrDefault(s => s.Id == "preset_suamisihat" || s.StreamUrl.Contains("radio.suamisihat.myds.me") || s.StreamUrl.Contains("dj.suamisihat.myds.me"));
                if (existingSs == null)
                {
                    AllStations.Insert(0, GetSuamiSihatRadioStation());
                }
                else
                {
                    existingSs.StreamUrl = "https://radio.suamisihat.myds.me/listen";
                    existingSs.Name = "SuamiSihat Radio";
                    existingSs.Genre = "Health / Lifestyle (Official)";
                }

                SyncConfigStations();
                SaveConfig();
            }
            else
            {
                AllStations = GetDefaultPresetStations();
                _config.SavedStations = new List<RadioStation>(AllStations);
                SaveConfig();
            }

            if (_config.FavoriteStationIds != null)
            {
                foreach (var station in AllStations)
                {
                    station.IsFavorite = _config.FavoriteStationIds.Contains(station.Id);
                }
            }

            if (!string.IsNullOrEmpty(_config.LastStationId))
            {
                CurrentStation = AllStations.FirstOrDefault(s => s.Id == _config.LastStationId);
            }

            if (CurrentStation == null && AllStations.Count > 0)
            {
                CurrentStation = AllStations[0];
            }
        }

        public static RadioStation GetSuamiSihatRadioStation()
        {
            return new RadioStation
            {
                Id = "preset_suamisihat",
                Name = "SuamiSihat Radio",
                Genre = "Health / Lifestyle (Official)",
                StreamUrl = "https://radio.suamisihat.myds.me/listen",
                IconEmoji = "📻",
                IsPreset = true,
                Language = "Malay",
                Country = "Malaysia",
                Description = "Official SuamiSihat Radio — health, wellness & lifestyle broadcasting 24/7."
            };
        }

        public static RadioStation GetInitialDStation()
        {
            return new RadioStation
            {
                Id = "preset_initiald",
                Name = "Initial D World Radio Broadcast",
                Genre = "Eurobeat / High Energy",
                StreamUrl = "http://165.227.19.100:9001/listen.aac",
                IconEmoji = "🏎️",
                IsPreset = true,
                Description = "24/7 Initial D & Eurobeat high-energy workstation radio."
            };
        }

        public static RadioStation GetBabymetalStation()
        {
            return new RadioStation
            {
                Id = "preset_babymetal",
                Name = "BABYMETAL & J-Rock Radio",
                Genre = "J-Rock / Kawaii Metal",
                StreamUrl = "https://animefm.stream.laut.fm/animefm",
                IconEmoji = "🦊",
                IsPreset = true,
                Description = "24/7 BABYMETAL, J-Rock, Anime & High-Energy Japanese Metal Station."
            };
        }

        public static List<RadioStation> GetDefaultPresetStations()
        {
            return new List<RadioStation>
            {
                GetSuamiSihatRadioStation(),
                GetInitialDStation(),
                GetBabymetalStation(),
                new RadioStation
                {
                    Id = "preset_bfm899",
                    Name = "BFM 89.9",
                    Genre = "Talk / News",
                    StreamUrl = "https://stream.rcs.revma.com/s91qy9p0zs3vv",
                    CoverImageUrl = "https://media.bfm.my/images/bfm-logo-square.jpg",
                    IconEmoji = "🎙️",
                    IsPreset = true,
                    Description = "The Business Station — News, interviews, and intellectual discussion."
                },
                new RadioStation
                {
                    Id = "preset_lofifocus",
                    Name = "Lo-Fi Focus Beats",
                    Genre = "Focus / Lo-Fi",
                    StreamUrl = "https://stream.bigfm.de/lofifocus/mp3-128/radiobrowser",
                    CoverImageUrl = "https://i.scdn.co/image/ab67706f00000002e4eadd417a05b2546e866aa8",
                    IconEmoji = "🎧",
                    IsPreset = true,
                    Description = "Chillhop lo-fi beats to relax and code/design to."
                },
                new RadioStation
                {
                    Id = "preset_chillhop",
                    Name = "Chillhop Lounge",
                    Genre = "Focus / Lo-Fi",
                    StreamUrl = "https://stream.laut.fm/lofi",
                    CoverImageUrl = "https://i.scdn.co/image/ab67706f000000025f9e3d83c3ec9c8a95e41b48",
                    IconEmoji = "☕",
                    IsPreset = true,
                    Description = "Smooth lo-fi chillhop background tracks."
                },
                new RadioStation
                {
                    Id = "preset_nightwave",
                    Name = "Nightwave Plaza",
                    Genre = "Synthwave / Vaporwave",
                    StreamUrl = "https://radio.plaza.one/mp3",
                    CoverImageUrl = "https://plaza.one/favicon.ico",
                    IconEmoji = "🌃",
                    IsPreset = true,
                    Description = "24/7 Aesthetic Vaporwave & Synthwave soundtrack for late-night designing & deep focus."
                },
                new RadioStation
                {
                    Id = "preset_groovesalad",
                    Name = "SomaFM: Groove Salad",
                    Genre = "Downtempo / Ambient",
                    StreamUrl = "https://ice6.somafm.com/groovesalad-256-mp3",
                    CoverImageUrl = "https://somafm.com/img3/groovesalad-400.jpg",
                    IconEmoji = "🥗",
                    IsPreset = true,
                    Description = "A nicely chilled plate of ambient/downtempo beats and grooves for creative flow."
                },
                new RadioStation
                {
                    Id = "preset_smoothjazz",
                    Name = "Smooth Jazz Workstation",
                    Genre = "Jazz / Chill",
                    StreamUrl = "https://0nlineradio.radioho.st/0r-jazz?ref=radio-browser",
                    CoverImageUrl = "https://i.scdn.co/image/ab67706f000000025a9f8f8e5e5e5e5e5e5e5e5e",
                    IconEmoji = "🎷",
                    IsPreset = true,
                    Description = "Smooth instrumental jazz for deep concentration."
                }
            };
        }

        public void PlayStation(RadioStation station)
        {
            if (station == null || string.IsNullOrWhiteSpace(station.StreamUrl)) return;

            CurrentStation = station;
            _config.LastStationId = station.Id;
            SaveConfig();

            if (StationChanged != null)
            {
                StationChanged(CurrentStation);
            }

            string url = station.StreamUrl.Trim();
            SetState(RadioPlaybackState.Buffering);
            _localProxy.Start(url);

            EnsureUI(() =>
            {
                try
                {
                    EnsureMediaPlayerCreated();
                    _mediaPlayer.Stop();
                    _mediaPlayer.Close();

                    Uri streamUri = new Uri(_localProxy.LocalProxyUrl, UriKind.Absolute);
                    _mediaPlayer.Open(streamUri);
                    _mediaPlayer.Volume = _config.IsMuted ? 0.0 : _config.Volume;
                    _mediaPlayer.Play();
                }
                catch (Exception ex)
                {
                    SetState(RadioPlaybackState.Error);
                    if (ErrorOccurred != null)
                    {
                        ErrorOccurred("Failed to play station: " + ex.Message);
                    }
                }
            });
        }

        public void TogglePlayPause()
        {
            if (State == RadioPlaybackState.Playing || State == RadioPlaybackState.Buffering)
            {
                Pause();
            }
            else
            {
                if (CurrentStation != null)
                {
                    PlayStation(CurrentStation);
                }
                else if (AllStations.Count > 0)
                {
                    PlayStation(AllStations[0]);
                }
            }
        }

        public void Pause()
        {
            EnsureUI(() =>
            {
                try
                {
                    if (_mediaPlayer != null)
                    {
                        _mediaPlayer.Pause();
                    }
                    SetState(RadioPlaybackState.Paused);
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
            });
        }

        public void Stop()
        {
            if (_localProxy != null)
            {
                _localProxy.Stop();
            }

            EnsureUI(() =>
            {
                try
                {
                    if (_mediaPlayer != null)
                    {
                        _mediaPlayer.Stop();
                        _mediaPlayer.Close();
                    }
                    SetState(RadioPlaybackState.Stopped);
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
            });
        }

        public void ToggleFavorite(RadioStation station)
        {
            if (station == null) return;

            station.IsFavorite = !station.IsFavorite;

            if (_config.FavoriteStationIds == null)
            {
                _config.FavoriteStationIds = new List<string>();
            }

            if (station.IsFavorite)
            {
                if (!_config.FavoriteStationIds.Contains(station.Id))
                {
                    _config.FavoriteStationIds.Add(station.Id);
                }
            }
            else
            {
                _config.FavoriteStationIds.Remove(station.Id);
            }

            SyncConfigStations();
            SaveConfig();
        }

        public void AddStation(RadioStation station)
        {
            if (station == null) return;

            AllStations.Add(station);
            SyncConfigStations();
            SaveConfig();
        }

        public void UpdateStation(RadioStation updatedStation)
        {
            if (updatedStation == null) return;

            RadioStation existing = AllStations.FirstOrDefault(s => s.Id == updatedStation.Id);
            if (existing != null)
            {
                existing.Name = updatedStation.Name;
                existing.StreamUrl = updatedStation.StreamUrl;
                existing.Genre = updatedStation.Genre;
                existing.IconEmoji = updatedStation.IconEmoji;
                existing.Description = updatedStation.Description;

                if (CurrentStation != null && CurrentStation.Id == existing.Id)
                {
                    CurrentStation = existing;
                    if (StationChanged != null)
                    {
                        StationChanged(CurrentStation);
                    }
                    if (State == RadioPlaybackState.Playing)
                    {
                        PlayStation(CurrentStation);
                    }
                }

                SyncConfigStations();
                SaveConfig();
            }
        }

        public void DeleteStation(RadioStation station)
        {
            if (station == null) return;

            if (CurrentStation != null && CurrentStation.Id == station.Id)
            {
                Stop();
                CurrentStation = null;
            }

            AllStations.RemoveAll(s => s.Id == station.Id);
            if (_config.FavoriteStationIds != null)
            {
                _config.FavoriteStationIds.Remove(station.Id);
            }

            SyncConfigStations();
            SaveConfig();
        }

        public void ResetToDefaultPresets()
        {
            Stop();
            AllStations = GetDefaultPresetStations();
            CurrentStation = AllStations.Count > 0 ? AllStations[0] : null;
            SyncConfigStations();
            SaveConfig();

            if (StationChanged != null && CurrentStation != null)
            {
                StationChanged(CurrentStation);
            }
        }

        public List<RadioStation> ImportPlaylistFile(string filePath)
        {
            List<RadioStation> imported = new List<RadioStation>();
            if (string.IsNullOrWhiteSpace(filePath) || !File.Exists(filePath)) return imported;

            try
            {
                string text = File.ReadAllText(filePath);
                string ext = Path.GetExtension(filePath).ToLower();
                string fileName = Path.GetFileName(filePath);
                Uri baseUri = new Uri(Path.GetFullPath(filePath));

                if (ext == ".pls" || text.Contains("[playlist]"))
                {
                    imported = PlaylistHelper.ParsePLS(text, fileName, baseUri);
                }
                else
                {
                    imported = PlaylistHelper.ParseM3U(text, fileName, baseUri);
                }

                foreach (var st in imported)
                {
                    AddStation(st);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[RadioStreamService] ImportPlaylistFile: " + ex.Message);
            }

            return imported;
        }

        public List<RadioStation> ImportPlaylistUrl(string url)
        {
            List<RadioStation> imported = new List<RadioStation>();
            if (string.IsNullOrWhiteSpace(url)) return imported;

            try
            {
                ServicePointManager.ServerCertificateValidationCallback = (s, cert, chain, sslPolicyErrors) => true;
                HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url.Trim());
                req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) SS-CAM/4.6.3";
                req.Timeout = 8000;
                req.AllowAutoRedirect = true;

                using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
                using (Stream s = resp.GetResponseStream())
                using (StreamReader reader = new StreamReader(s, System.Text.Encoding.UTF8))
                {
                    string text = reader.ReadToEnd();
                    Uri baseUri = resp.ResponseUri ?? new Uri(url);
                    string name = Path.GetFileName(baseUri.LocalPath);
                    if (string.IsNullOrWhiteSpace(name)) name = "Online Playlist";

                    if (text.Contains("[playlist]"))
                    {
                        imported = PlaylistHelper.ParsePLS(text, name, baseUri);
                    }
                    else
                    {
                        imported = PlaylistHelper.ParseM3U(text, name, baseUri);
                    }

                    foreach (var st in imported)
                    {
                        AddStation(st);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[RadioStreamService] ImportPlaylistUrl: " + ex.Message);
            }

            return imported;
        }

        public void ExportPlaylistFile(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath)) return;

            try
            {
                string m3uContent = PlaylistHelper.GenerateM3U(AllStations);
                File.WriteAllText(filePath, m3uContent, System.Text.Encoding.UTF8);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[RadioStreamService] ExportPlaylistFile: " + ex.Message);
                throw;
            }
        }

        private void SyncConfigStations()
        {
            if (_config != null)
            {
                _config.SavedStations = new List<RadioStation>(AllStations);
            }
        }

        private void SetState(RadioPlaybackState state)
        {
            State = state;
            EnsureUI(() =>
            {
                if (PlaybackStateChanged != null)
                {
                    PlaybackStateChanged(State);
                }
            });
        }

        public static bool TestStreamUrl(string url, out string statusMessage)
        {
            statusMessage = "";
            if (string.IsNullOrWhiteSpace(url))
            {
                statusMessage = "URL cannot be empty.";
                return false;
            }

            try
            {
                ServicePointManager.ServerCertificateValidationCallback = (sender, cert, chain, sslPolicyErrors) => true;

                string resolvedUrl = PlaylistHelper.ResolveStreamUrl(url.Trim());
                bool wasM3u = !resolvedUrl.Equals(url.Trim(), StringComparison.OrdinalIgnoreCase);

                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(resolvedUrl);
                request.Timeout = 5000;
                request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
                request.Method = "GET";

                using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                {
                    string ctype = response.ContentType != null ? response.ContentType.ToLower() : "";
                    if (response.StatusCode == HttpStatusCode.OK ||
                        ctype.Contains("audio") || ctype.Contains("mpeg") || ctype.Contains("aac") || ctype.Contains("ogg") || ctype.Contains("stream") || ctype.Contains("html"))
                    {
                        if (wasM3u)
                        {
                            statusMessage = "M3U stream verified! (" + (response.ContentType ?? "Audio Stream") + ")";
                        }
                        else
                        {
                            statusMessage = "Stream connection successful (" + (response.ContentType ?? "Audio Stream") + ")!";
                        }
                        return true;
                    }
                    else
                    {
                        statusMessage = "Server returned status: " + response.StatusCode;
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                statusMessage = "Stream test failed: " + ex.Message;
                return false;
            }
        }

        private RadioConfigData LoadConfig()
        {
            return JsonPersistenceHelper.Load<RadioConfigData>(_configFilePath);
        }

        private void SaveConfig()
        {
            JsonPersistenceHelper.Save(_configFilePath, _config);
        }

        // ── Cover Art ─────────────────────────────────────────────────────
        //
        // Downloads a station cover image on a background thread and caches
        // it to %APPDATA%\SS-CAM\covers\<stationId>.jpg.
        // Fires CoverDownloaded on the WPF Dispatcher when complete.

        public event Action<RadioStation> CoverDownloaded;

        private static readonly string _coversDir =
            Path.Combine(AppPaths.AppDataFolder, "covers");

        /// <summary>
        /// Downloads the cover image for the given station (if a URL is set and
        /// no valid local copy exists yet). The download is fire-and-forget on a
        /// background thread. On completion, station.LocalCoverPath is set and the
        /// CoverDownloaded event is raised on the UI thread.
        /// </summary>
        public void DownloadCoverAsync(RadioStation station)
        {
            if (station == null) return;
            if (string.IsNullOrWhiteSpace(station.CoverImageUrl)) return;
            if (station.HasLocalCover) return;   // already cached

            ThreadPool.QueueUserWorkItem(delegate(object state)
            {
                try
                {
                    if (!Directory.Exists(_coversDir))
                        Directory.CreateDirectory(_coversDir);

                    // Sanitise filename: use station id (alphanumeric only)
                    string safeId = System.Text.RegularExpressions.Regex.Replace(station.Id, "[^a-zA-Z0-9_-]", "");
                    string localPath = Path.Combine(_coversDir, safeId + ".jpg");

                    if (!File.Exists(localPath))
                    {
                        using (var wc = new WebClient())
                        {
                            wc.Headers["User-Agent"] = "SS-CAM/2.5.1";
                            byte[] data = wc.DownloadData(station.CoverImageUrl);
                            File.WriteAllBytes(localPath, data);
                        }
                    }

                    station.LocalCoverPath = localPath;

                    // Update the JSON config so the path persists across restarts
                    SaveConfig();

                    // Notify UI on the Dispatcher
                    Application.Current.Dispatcher.BeginInvoke(
                        new Action(delegate()
                        {
                            if (CoverDownloaded != null)
                                CoverDownloaded(station);
                        }));
                }
                catch
                {
                    // Silent fail — UI falls back to the glyph icon
                }
            });
        }
    }
}
