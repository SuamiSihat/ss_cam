using System;
using System.IO;
using SS_CAM.Services;

namespace SS_CAM.Utilities
{
    public static class AppPaths
    {
        public static string AppDataFolder
        {
            get
            {
                string folderName = (TenantConfigService.Current != null && !string.IsNullOrWhiteSpace(TenantConfigService.Current.AppFolderName)) ? TenantConfigService.Current.AppFolderName : "Corporate";
                string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), folderName);
                if (!Directory.Exists(path))
                {
                    Directory.CreateDirectory(path);
                }
                return path;
            }
        }
    }
}
