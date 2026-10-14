using System;
using System.IO;
using Newtonsoft.Json;

namespace SS_CAM.Utilities
{
    public static class JsonPersistenceHelper
    {
        public static T Load<T>(string filePath, Func<T> defaultFactory = null) where T : new()
        {
            if (string.IsNullOrWhiteSpace(filePath))
                return defaultFactory != null ? defaultFactory() : new T();

            if (!File.Exists(filePath))
                return defaultFactory != null ? defaultFactory() : new T();

            try
            {
                string json = File.ReadAllText(filePath);
                T result = JsonConvert.DeserializeObject<T>(json);
                return result != null ? result : (defaultFactory != null ? defaultFactory() : new T());
            }
            catch (Exception ex)
            {
                // Fallback on serialization failure to avoid crash, but record it: the caller may
                // later Save() the default object over the unreadable file.
                App.LogTrace(string.Format("[JsonPersistenceHelper] Could not read {0}: {1}", filePath, ex.Message));
                return defaultFactory != null ? defaultFactory() : new T();
            }
        }

        public static bool Save<T>(string filePath, T data)
        {
            if (string.IsNullOrWhiteSpace(filePath) || data == null) return false;

            try
            {
                string dir = Path.GetDirectoryName(filePath);
                if (!string.IsNullOrWhiteSpace(dir) && !Directory.Exists(dir))
                {
                    Directory.CreateDirectory(dir);
                }

                string json = JsonConvert.SerializeObject(data, Formatting.Indented);
                File.WriteAllText(filePath, json);
                return true;
            }
            catch (Exception ex)
            {
                App.LogTrace(string.Format("[JsonPersistenceHelper] Could not save {0}: {1}", filePath, ex.Message));
                return false;
            }
        }
    }
}
