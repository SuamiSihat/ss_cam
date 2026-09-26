[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$exePath = Join-Path $repoRoot "src\SS-CAM\bin\Release\SS-CAM.exe"

if (-not (Test-Path $exePath)) {
    Write-Error "SS-CAM.exe not found at $exePath. Please build Release first."
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SS-CAM END-TO-END ORDER -> PROJECT HANDSHAKE VERIFICATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Load Assembly
[Reflection.Assembly]::LoadFrom($exePath) | Out-Null
Write-Host "Loaded assembly: $exePath" -ForegroundColor Green

# Setup disposable test workspace
$testWs = Join-Path $PSScriptRoot "TestWorkspace\HandshakeTest_$(Get-Random)"
if (Test-Path $testWs) { Remove-Item -Path $testWs -Recurse -Force }
New-Item -ItemType Directory -Path $testWs -Force | Out-Null

$passCount = 0
$failCount = 0

function Assert-Condition($name, $condition, $detail = "") {
    if ($condition) {
        Write-Host "  [PASS] $name" -ForegroundColor Green
        $script:passCount++
    } else {
        Write-Host "  [FAIL] $name - $detail" -ForegroundColor Red
        $script:failCount++
    }
}

try {
    # ─── TEST 1: Setup Mock Order in _Orders Vault ───────────────────────
    Write-Host "`n--- STEP 1: Creating Mock Order in _Orders Vault ---" -ForegroundColor Yellow
    $ordersDir = Join-Path $testWs "_Orders\ORD-2026-001"
    New-Item -ItemType Directory -Path $ordersDir -Force | Out-Null

    # Create dummy attachment files in _Orders\ORD-2026-001
    $mockImg = Join-Path $ordersDir "product_hero.jpg"
    $mockDoc = Join-Path $ordersDir "brief_guidelines.pdf"
    [System.IO.File]::WriteAllText($mockImg, "FAKEDATA_JPG_HERO_IMAGE")
    [System.IO.File]::WriteAllText($mockDoc, "FAKEDATA_PDF_GUIDELINE_DOCUMENT")

    $expectedDuration = [SS_CAM.Models.CreativeOrder]::CalculateDuration("2026-09-28", "2026-10-05")
    Write-Host "  [INFO] Expected Canonical Duration: $expectedDuration" -ForegroundColor Gray

    $orderJson = @"
{"id":"ORD-2026-001","title":"Serum Packaging Redesign","entity":"SSH","priority":"tier_2","format":"pkg_box_sleeve","copy":"Elevate men's wellness with refined aesthetics. Premium gold foil.","targetDate":"2026-10-05","attachmentNote":"Refer to guidelines.pdf and product_hero.jpg","requester":"Marketing Team","requesterRole":"brand_manager","status":"pending","submittedAt":"2026-09-26T08:00:00Z","createdDate":"2026-09-26","startDate":"2026-09-28","deadline":"2026-10-05","duration":"$expectedDuration"}
"@
    # Write to creative-orders.jsonl
    $jsonlPath = Join-Path $testWs "_Orders\creative-orders.jsonl"
    [System.IO.File]::WriteAllText($jsonlPath, $orderJson + "`n", [System.Text.Encoding]::UTF8)

    # Ingest using CreativeOrderService.LoadOrdersFromDiskAsync
    $loadTask = [SS_CAM.Services.CreativeOrderService]::LoadOrdersFromDiskAsync($testWs)
    $orders = $loadTask.GetAwaiter().GetResult()
    Assert-Condition "CreativeOrderService discovered order from disk" ($orders.Count -eq 1) "Found $($orders.Count) orders"
    
    $ord = $orders[0]
    Assert-Condition "Order ID matches" ($ord.Id -eq "ORD-2026-001") "ID=$($ord.Id)"
    Assert-Condition "Order createdDate matches" ($ord.CreatedDate -eq "2026-09-26") "CreatedDate=$($ord.CreatedDate)"
    Assert-Condition "Order startDate matches" ($ord.StartDate -eq "2026-09-28") "StartDate=$($ord.StartDate)"
    Assert-Condition "Order deadline matches" ($ord.Deadline -eq "2026-10-05") "Deadline=$($ord.Deadline)"
    Assert-Condition "Order duration matches" ($ord.Duration -eq $expectedDuration) "Duration=$($ord.Duration)"
    Assert-Condition "Order attachments automatically enriched" ($ord.Attachments.Count -eq 2) "Attachment count=$($ord.Attachments.Count)"

    # ─── TEST 2: Convert Order to Canonical Project Structure ───────────
    Write-Host "`n--- STEP 2: Converting Order via ConvertOrderToProjectAsync ---" -ForegroundColor Yellow
    $convertTask = [SS_CAM.Services.CreativeOrderService]::ConvertOrderToProjectAsync($ord, $testWs, "HARUSSANI", "Harussani", ".af")
    $projectPath = $convertTask.GetAwaiter().GetResult()

    Assert-Condition "Project directory generated" (Test-Path $projectPath) "Path: $projectPath"

    # Verify attachment handover into 01_Brief_and_Copy/Brief_Assets
    $briefAssetsDir = Join-Path $projectPath "01_Brief_and_Copy\Brief_Assets"
    Assert-Condition "Brief_Assets directory created" (Test-Path $briefAssetsDir)
    Assert-Condition "Attachment 1 copied (product_hero.jpg)" (Test-Path (Join-Path $briefAssetsDir "product_hero.jpg"))
    Assert-Condition "Attachment 2 copied (brief_guidelines.pdf)" (Test-Path (Join-Path $briefAssetsDir "brief_guidelines.pdf"))

    # Verify COPY.md containing 4 dates & attachment markdown links
    $copyFile = Join-Path $projectPath "01_Brief_and_Copy\COPY.md"
    Assert-Condition "COPY.md exists" (Test-Path $copyFile)
    $copyText = [System.IO.File]::ReadAllText($copyFile)
    Assert-Condition "COPY.md contains Created Date" ($copyText -match 'Created Date\*\*:\s*2026-09-26')
    Assert-Condition "COPY.md contains Start Date" ($copyText -match 'Start Date\*\*:\s*2026-09-28')
    Assert-Condition "COPY.md contains Deadline" ($copyText -match 'Deadline\*\*:\s*2026-10-05')
    Assert-Condition "COPY.md contains Duration" ($copyText.Contains($expectedDuration))
    Assert-Condition "COPY.md contains attached asset markdown link" ($copyText -match 'Brief_Assets/product_hero\.jpg')

    # ─── TEST 3: Validate README.md Frontmatter ──────────────────────────
    Write-Host "`n--- STEP 3: Verifying README.md Frontmatter ---" -ForegroundColor Yellow
    $readmePath = Join-Path $projectPath "README.md"
    Assert-Condition "README.md exists" (Test-Path $readmePath)
    
    $readmeText = [System.IO.File]::ReadAllText($readmePath)
    Assert-Condition "README contains created date" ($readmeText -match 'created:\s*2026-09-26')
    Assert-Condition "README contains start_date" ($readmeText -match 'start_date:\s*2026-09-28')
    Assert-Condition "README contains deadline" ($readmeText -match 'deadline:\s*2026-10-05')
    Assert-Condition "README contains duration" ($readmeText.Contains("duration: $expectedDuration"))

    # ─── TEST 4: FrontmatterService ReadStatus Parity Check ───────────────
    Write-Host "`n--- STEP 4: Scanning Frontmatter with FrontmatterService ---" -ForegroundColor Yellow
    $projStatus = [SS_CAM.Services.FrontmatterService]::ReadStatus($projectPath)
    Assert-Condition "Frontmatter parsed successfully" $projStatus.HasFrontmatter
    Assert-Condition "Project Status is in_progress" ($projStatus.Status -eq "in_progress") "Status=$($projStatus.Status)"
    Assert-Condition "Project CreatedDate is 2026-09-26" ($projStatus.CreatedDate -eq "2026-09-26") "CreatedDate=$($projStatus.CreatedDate)"
    Assert-Condition "Project StartDate is 2026-09-28" ($projStatus.StartDate -eq "2026-09-28") "StartDate=$($projStatus.StartDate)"
    Assert-Condition "Project Deadline is 2026-10-05" ($projStatus.Deadline -eq "2026-10-05") "Deadline=$($projStatus.Deadline)"
    Assert-Condition "Project Duration is $expectedDuration" ($projStatus.Duration -eq $expectedDuration) "Duration=$($projStatus.Duration)"

    # ─── TEST 5: Verify Order Status Updated in Ledger ───────────────────
    Write-Host "`n--- STEP 5: Verifying Order Status In Ledger ---" -ForegroundColor Yellow
    $reloadTask = [SS_CAM.Services.CreativeOrderService]::LoadOrdersFromDiskAsync($testWs)
    $reloadedOrders = $reloadTask.GetAwaiter().GetResult()
    Assert-Condition "Reloaded order status is in_progress" ($reloadedOrders[0].Status -eq "in_progress")
    Assert-Condition "Reloaded order linked to new project" ($reloadedOrders[0].ProjectId -ne $null) "ProjectId=$($reloadedOrders[0].ProjectId)"

} finally {
    # Clean up test workspace
    if (Test-Path $testWs) {
        Remove-Item -Path $testWs -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " RESULTS: PASS = $passCount, FAIL = $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "============================================================" -ForegroundColor Cyan

if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}
