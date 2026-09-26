param([switch]$Apply)

$jsonPath = "D:\HaNa_Innovation\ssDesignSystem\assets\tokens\status-enum.json"
if (-not (Test-Path $jsonPath)) {
    Write-Host "status-enum.json not found." -ForegroundColor Red
    exit 1
}

$json = Get-Content $jsonPath -Raw | ConvertFrom-Json

$webStatuses = @()
$wpfConstants = @()
$androidConstants = @()

foreach ($prop in $json.psobject.properties) {
    $key = $prop.Name
    $web = $prop.Value.web
    $wpf = $prop.Value.wpf
    $android = $prop.Value.android
    
    $webStatuses += "'$web'"
    
    $camelCaseKey = (Get-Culture).TextInfo.ToTitleCase($key.Replace('_', ' ')).Replace(' ', '')
    $wpfConstants += "        public const string $camelCaseKey = `"$wpf`";"
    
    $upperKey = $key.ToUpper()
    $androidConstants += "    const val $upperKey = `"$android`""
}

$webTypeString = "export type ProjectStatus = " + ($webStatuses -join " | ") + ";"

# 1. Update Web
$webPath = "D:\HaNa_Innovation\ss_cam\src\SS-CAM.Web\client\src\lib\types\index.ts"
if (Test-Path $webPath) {
    $webContent = Get-Content $webPath -Raw -Encoding UTF8
    $newWebContent = $webContent -replace 'export type ProjectStatus = [^;]+;', $webTypeString
    if ($Apply) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($webPath, $newWebContent, $utf8NoBom)
        Write-Host "Updated Web types." -ForegroundColor Green
    } else {
        Write-Host "Web type would be: $webTypeString"
    }
}

# 2. Update WPF
$wpfPath = "D:\HaNa_Innovation\ss_cam\src\SS-CAM\Models\ProjectStatus.cs"
if (Test-Path $wpfPath) {
    $wpfContent = Get-Content $wpfPath -Raw -Encoding UTF8
    
    $wpfBlock = "    public static class ProjectStatusConstants`r`n    {`r`n" + ($wpfConstants -join "`r`n") + "`r`n    }"
    
    if ($wpfContent -match 'public static class ProjectStatusConstants\s*\{[^}]+\}') {
        $newWpfContent = $wpfContent -replace 'public static class ProjectStatusConstants\s*\{[^}]+\}', $wpfBlock
    } else {
        $newWpfContent = $wpfContent -replace '    public class ProjectStatusItem', "$wpfBlock`r`n`r`n    public class ProjectStatusItem"
    }
    
    if ($Apply) {
        $utf8Bom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($wpfPath, $newWpfContent, $utf8Bom)
        Write-Host "Updated WPF constants." -ForegroundColor Green
    } else {
        Write-Host "WPF Constants generated."
    }
}

# 3. Update Android
$androidPath = "D:\HaNa_Innovation\ss_cam\src\SS-CAM.Android\app\src\main\java\com\suamisihat\sscam\data\models\Models.kt"
if (Test-Path $androidPath) {
    $androidContent = Get-Content $androidPath -Raw -Encoding UTF8
    
    $androidBlock = "object ProjectStatusConstants {`n" + ($androidConstants -join "`n") + "`n}"
    
    if ($androidContent -match 'object ProjectStatusConstants\s*\{[^}]+\}') {
        $newAndroidContent = $androidContent -replace 'object ProjectStatusConstants\s*\{[^}]+\}', $androidBlock
    } else {
        # Insert after imports
        $newAndroidContent = $androidContent -replace 'import com\.google\.gson\.annotations\.SerializedName', "`$0`n`n$androidBlock"
    }
    
    if ($Apply) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($androidPath, $newAndroidContent, $utf8NoBom)
        Write-Host "Updated Android constants." -ForegroundColor Green
    } else {
        Write-Host "Android Constants generated."
    }
}
