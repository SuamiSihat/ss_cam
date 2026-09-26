using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;

namespace SS_CAM.Linux.Services
{
    public class ProjectGeneratorService
    {
        public static bool ValidateRootDirectory(string rootDirectory, out string errorMessage)
        {
            errorMessage = null!;
            if (string.IsNullOrWhiteSpace(rootDirectory))
            {
                errorMessage = "Workspace root directory path is not specified. Please configure your workspace location in Settings.";
                return false;
            }

            try
            {
                if (!Directory.Exists(rootDirectory))
                {
                    errorMessage = $"Target root directory or Synology Drive vault is unreachable or does not exist:\n{rootDirectory}";
                    return false;
                }
            }
            catch (Exception ex)
            {
                errorMessage = $"Failed to access workspace path '{rootDirectory}': {ex.Message}";
                return false;
            }

            return true;
        }

        public string GenerateProjectFolder(
            string rootDirectory, 
            string projectName, 
            string subBrand, 
            string year, 
            string projectNumber, 
            string presetType, 
            List<string>? extraSubFolders = null,
            string briefMarkdown = "",
            string designer = "Designer",
            string? createdDate = null,
            string? startDate = null,
            string? deadline = null,
            string? duration = null)
        {
            if (!ValidateRootDirectory(rootDirectory, out var valError))
            {
                throw new InvalidOperationException(valError);
            }

            var cleanProjectName = string.IsNullOrWhiteSpace(projectName) 
                ? "Untitled_Project" 
                : Regex.Replace(projectName.Trim(), @"[^a-zA-Z0-9\-_]", "_");

            string cleanSubBrand;
            var brandMatch = Regex.Match(subBrand.Trim(), @"^([A-Z]{2,4})\s+-\s+");
            if (brandMatch.Success)
            {
                cleanSubBrand = brandMatch.Groups[1].Value.ToUpperInvariant();
            }
            else
            {
                var lowerBrand = subBrand.ToLowerInvariant();
                if (lowerBrand.Contains("holding")) cleanSubBrand = "SSH";
                else if (lowerBrand.Contains("healthcare")) cleanSubBrand = "SSC";
                else if (lowerBrand.Contains("wellness")) cleanSubBrand = "SSW";
                else if (lowerBrand.Contains("ecom")) cleanSubBrand = "SSE";
                else if (lowerBrand.Contains("tech")) cleanSubBrand = "SST";
                else if (subBrand == "SSH" || subBrand == "SSC" || subBrand == "SSW" || subBrand == "SSE" || subBrand == "SST")
                    cleanSubBrand = subBrand.ToUpperInvariant();
                else cleanSubBrand = "SS";
            }

            var cleanYear = Regex.IsMatch(year, @"^\d{4}$") ? year : DateTime.Now.ToString("yyyy");
            var curMonthNum = DateTime.Now.ToString("MM");
            var curMonthFull = DateTime.Now.ToString("MMMM");
            
            var yearFolder = $"SS-{cleanYear}";
            var monthFolder = $"{cleanYear}{curMonthNum}_{curMonthFull}";
            var dateCode = $"{cleanYear}{curMonthNum}";

            var cleanProjectNumber = projectNumber != null ? projectNumber.Trim() : string.Empty;
            if (Regex.IsMatch(cleanProjectNumber, @"^\d+$")) cleanProjectNumber = $"{cleanProjectNumber}D";
            if (string.IsNullOrWhiteSpace(cleanProjectNumber)) cleanProjectNumber = "0001D";

            var folderName = $"{dateCode}_{cleanProjectNumber}_{cleanSubBrand}_{cleanProjectName}";
            
            var yearPath = Path.Combine(rootDirectory, yearFolder);
            var monthlyRoot = Path.Combine(yearPath, monthFolder);
            var projectRoot = Path.Combine(monthlyRoot, folderName);

            var cleanCreated = !string.IsNullOrWhiteSpace(createdDate) ? createdDate : DateTime.Now.ToString("yyyy-MM-dd");
            var cleanStart = !string.IsNullOrWhiteSpace(startDate) ? startDate : cleanCreated;
            var cleanDeadline = !string.IsNullOrWhiteSpace(deadline) ? deadline : DateTime.Now.AddDays(3).ToString("yyyy-MM-dd");
            var cleanDuration = !string.IsNullOrWhiteSpace(duration) ? duration : Models.ProjectStatusItem.CalculateDuration(cleanStart, cleanDeadline);

            // Canonical 5-Folder hierarchy
            var subFolders = new List<string>
            {
                "01_BRIEFS",
                "02_RAW_ASSETS",
                "03_WORKING_FILES",
                "04_EXPORTS",
                "05_DELIVERABLES"
            };

            if (extraSubFolders != null && extraSubFolders.Count > 0)
            {
                foreach (var extra in extraSubFolders)
                {
                    if (!string.IsNullOrWhiteSpace(extra) && !subFolders.Contains(extra))
                    {
                        subFolders.Add(extra.Trim());
                    }
                }
            }

            foreach (var sf in subFolders)
            {
                var path = Path.Combine(projectRoot, sf);
                Directory.CreateDirectory(path);
            }

            // Write project.yaml frontmatter metadata
            var yamlPath = Path.Combine(projectRoot, "project.yaml");
            var yamlContent = 
$@"project_id: {dateCode}_{cleanProjectNumber}_{cleanSubBrand}
title: ""{projectName}""
sub_brand: {cleanSubBrand}
designer: {designer}
created_date: {cleanCreated}
start_date: {cleanStart}
deadline: {cleanDeadline}
duration: {cleanDuration}
category: {presetType}
status: in-progress
priority: medium
version: 1.0.0
";
            File.WriteAllText(yamlPath, yamlContent, System.Text.Encoding.UTF8);

            // Write README.md with Frontmatter for TaskManager / WorkspaceScanner
            var readmePath = Path.Combine(projectRoot, "README.md");
            var readmeContent = 
$@"---
status: in-progress
designer: {designer}
client: {cleanSubBrand}
created: {cleanCreated}
start_date: {cleanStart}
deadline: {cleanDeadline}
duration: {cleanDuration}
priority: medium
tags: [{cleanSubBrand}, {presetType}]
---

# {folderName}

- **Project ID**: {dateCode}_{cleanProjectNumber}_{cleanSubBrand}
- **Designer**: {designer}
- **Brand / Entity**: {cleanSubBrand}
- **Category**: {presetType}
- **Created Date**: {cleanCreated}
- **Start Date**: {cleanStart}
- **Target Deadline**: {cleanDeadline}
- **Turnaround Duration**: {cleanDuration}

## Deliverable Brief
{projectName}
";
            File.WriteAllText(readmePath, readmeContent, System.Text.Encoding.UTF8);

            // Write 01_BRIEFS/COPY.md or 03_WORKING_FILES/COPY.md
            var copyPath = Path.Combine(projectRoot, "01_BRIEFS", "COPY.md");
            var initialCopy = string.IsNullOrWhiteSpace(briefMarkdown)
                ? CopywritingDesktopService.GetDefaultTemplate(projectName)
                : briefMarkdown;
            File.WriteAllText(copyPath, initialCopy, System.Text.Encoding.UTF8);

            return projectRoot;
        }
    }
}
