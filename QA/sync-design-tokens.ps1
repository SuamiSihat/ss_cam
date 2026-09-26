param([switch]$Apply)

$jsonPath = "D:\HaNa_Innovation\ssDesignSystem\assets\tokens\design-tokens.json"
$xamlPath = "D:\HaNa_Innovation\ss_cam\src\SS-CAM\Styles\SSDefaultTheme.xaml"

$json = Get-Content $jsonPath -Raw | ConvertFrom-Json

# Flatten JSON to path-value map
$tokenMap = @{}
function Flatten-Json($node, $prefix) {
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $node.psobject.properties) {
            $key = $prop.Name
            $val = $prop.Value
            if ($key -eq "`$value") {
                $tokenMap[$prefix.TrimEnd('.')] = $val
            } elseif ($key -ne "`$type" -and $key -ne "`$description") {
                Flatten-Json $val "$prefix$key."
            }
        }
    }
}
Flatten-Json $json.color "color."

$xamlMapping = [ordered]@{
    "FluentBrand80" = "color.brand.azure"
    "SSPrussianBlue" = "color.brand.prussian-blue"
    "SSBlue" = "color.brand.blue"
    "SSAzure" = "color.brand.azure"
    "SSMalibu" = "color.brand.malibu"
    "SSNeutralBlack" = "color.neutral.neutral-black"
    "SSLion" = "color.brand.lion"
    "SSFawn" = "color.brand.fawn"
    "SSArylide" = "color.brand.arylide"
    "SSBanana" = "color.brand.banana"
    
    "FluentLightCanvasBg" = "color.semantic.light.bg-canvas"
    "FluentLightCardBg" = "color.semantic.light.bg-surface"
    "FluentLightCardSubBg" = "color.semantic.light.bg-subtle"
    "FluentLightTextPrimary" = "color.semantic.light.fg-primary"
    "FluentLightTextSecondary" = "color.semantic.light.fg-secondary"
    
    "SidebarBackgroundBrush" = "color.brand.prussian-blue"
    "SidebarSearchBackgroundBrush" = "color.brand.blue"
    "SidebarTextPrimaryBrush" = "color.neutral.0"
    
    "FluentDarkCanvasBg" = "color.semantic.dark.bg-canvas"
    "FluentDarkCardBg" = "color.semantic.dark.bg-surface"
    "FluentDarkCardSubBg" = "color.semantic.dark.bg-subtle"
    "FluentDarkTextPrimary" = "color.semantic.dark.fg-primary"
    "FluentDarkTextSecondary" = "color.semantic.dark.fg-secondary"
    
    "FluentSuccess" = "color.status.success-fg"
    "FluentWarning" = "color.status.warning-fg"
    "FluentDanger" = "color.status.error-fg"
    
    "FluentBrand70" = "color.brand.blue"
    "FluentBrandLight" = "color.semantic.light.brand-subtle"
    "FluentBrandTint" = "color.semantic.light.brand-subtle"
    "FluentLightStroke" = "color.semantic.light.stroke-1"
    "SidebarTextSecondaryBrush" = "color.brand.malibu"
    "SidebarUserCardBackgroundBrush" = "color.brand.prussian-blue"
    "SidebarDividerBrush" = "color.brand.blue"
    "FluentDarkStroke" = "color.semantic.dark.stroke-1"
}

$xamlLines = Get-Content $xamlPath -Encoding UTF8
$newXaml = @()

$unmapped = @()

foreach ($line in $xamlLines) {
    if ($line -match '<SolidColorBrush\s+x:Key="([^"]+)"\s+Color="([^"]+)"\s*/>') {
        $key = $matches[1]
        $oldColor = $matches[2]
        
        if ($xamlMapping.Contains($key)) {
            $tokenPath = $xamlMapping[$key]
            $newTokenVal = $tokenMap[$tokenPath]
            
            if ($null -ne $newTokenVal) {
                # Convert rgba to hex if necessary
                if ($newTokenVal -match 'rgba\((\d+),(\d+),(\d+),([\d.]+)\)') {
                    $a = [int]([double]$matches[4] * 255)
                    $r = [int]$matches[1]
                    $g = [int]$matches[2]
                    $b = [int]$matches[3]
                    $newTokenVal = "#{0:X2}{1:X2}{2:X2}{3:X2}" -f $a, $r, $g, $b
                }
                
                # Format to upper case
                $newTokenVal = $newTokenVal.ToUpper()
                
                # Check if comment already exists on previous line
                $lastLine = if ($newXaml.Count -gt 0) { $newXaml[-1] } else { "" }
                if ($lastLine -notmatch "<!-- Token: $tokenPath -->") {
                    $indent = $line.Substring(0, $line.IndexOf("<"))
                    $newXaml += "$indent<!-- Token: $tokenPath -->"
                }
                
                $newLine = $line -replace 'Color="[^"]+"', "Color=`"$newTokenVal`""
                $newXaml += $newLine
            } else {
                $unmapped += $key
                $newXaml += $line
            }
        } else {
            $unmapped += $key
            $newXaml += $line
        }
    } else {
        $newXaml += $line
    }
}

$tempFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllLines($tempFile, $newXaml, [System.Text.Encoding]::UTF8)

# Run diff
git diff --no-index $xamlPath $tempFile

if ($unmapped.Count -gt 0) {
    Write-Host "`nWARNING: The following tokens in XAML lacked a clear 1:1 mapping and were left unchanged:" -ForegroundColor Yellow
    $unmapped | ForEach-Object { Write-Host " - $_" }
}

if ($Apply) {
    Write-Host "`nApplying changes to $xamlPath..." -ForegroundColor Green
    # Use UTF8Encoding with BOM
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllLines($xamlPath, $newXaml, $utf8Bom)
} else {
    Write-Host "`nRun with -Apply to save changes." -ForegroundColor Cyan
}

Remove-Item $tempFile
