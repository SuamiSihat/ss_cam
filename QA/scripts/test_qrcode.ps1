$exePath = (Resolve-Path "src\SS-CAM\bin\Release\SS-CAM.exe").Path
[Reflection.Assembly]::LoadFrom($exePath) | Out-Null
$service = [SS_CAM.Services.QrCodeEncoderService]::Instance

$passCount = 0
$failCount = 0

function Assert-Test($condition, $name) {
    if ($condition) {
        Write-Host "  [PASS] $name" -ForegroundColor Green
        $global:passCount++
    } else {
        Write-Host "  [FAIL] $name" -ForegroundColor Red
        $global:failCount++
    }
}

Write-Host "=========================================="
Write-Host "  T2 QR CODE STUDIO AUTOMATED QA TESTS"
Write-Host "=========================================="

# Test 1: Content formats (URL, vCard, WiFi)
Write-Host "`n1. Content formats:"
$optsUrl = New-Object SS_CAM.Services.QrCodeOptions
$optsUrl.Content = "https://suamisihat.clinic"
$bmpUrl = $service.GenerateQrCodeBitmap($optsUrl)
$svgUrl = $service.GenerateSvgXml($optsUrl)
Assert-Test ($bmpUrl -ne $null -and $bmpUrl.Width -gt 200 -and $svgUrl.Contains("<svg")) "URL encoding (Bitmap & SVG)"

$optsVCard = New-Object SS_CAM.Services.QrCodeOptions
$optsVCard.Content = "BEGIN:VCARD`nVERSION:3.0`nN:Harussani`nFN:Harussani`nORG:SuamiSihat`nTEL:+60123456789`nEMAIL:test@suamisihat.clinic`nEND:VCARD"
$bmpVCard = $service.GenerateQrCodeBitmap($optsVCard)
$svgVCard = $service.GenerateSvgXml($optsVCard)
Assert-Test ($bmpVCard -ne $null -and $svgVCard.Contains("<svg")) "vCard encoding (Bitmap & SVG)"

$optsWifi = New-Object SS_CAM.Services.QrCodeOptions
$optsWifi.Content = "WIFI:S:SS_Wifi;T:WPA;P:Secret123;;"
$bmpWifi = $service.GenerateQrCodeBitmap($optsWifi)
$svgWifi = $service.GenerateSvgXml($optsWifi)
Assert-Test ($bmpWifi -ne $null -and $svgWifi.Contains("<svg")) "WiFi encoding (Bitmap & SVG)"

# Test 2: Body shapes (Square, Circle, Rounded, Dots, Diamond, Classy)
Write-Host "`n2. Body shapes:"
$shapes = [Enum]::GetNames([SS_CAM.Services.QrBodyShape])
foreach ($shape in $shapes) {
    $sOpts = New-Object SS_CAM.Services.QrCodeOptions
    $sOpts.Content = "https://suamisihat.clinic"
    $sOpts.BodyShape = [Enum]::Parse([SS_CAM.Services.QrBodyShape], $shape)
    $bmp = $service.GenerateQrCodeBitmap($sOpts)
    $svg = $service.GenerateSvgXml($sOpts)
    
    $validSvg = $false
    if ($shape -eq "Diamond") {
        $validSvg = $svg.Contains("<polygon")
    } elseif ($shape -eq "Classy") {
        $validSvg = $svg.Contains("<path")
    } elseif ($shape -eq "Circle" -or $shape -eq "Dots") {
        $validSvg = $svg.Contains("<circle")
    } else {
        $validSvg = $svg.Contains("<rect") -or $svg.Contains("<path")
    }
    Assert-Test ($bmp -ne $null -and $bmp.Width -gt 200 -and $validSvg) "BodyShape '$shape' produces valid Bitmap and SVG"
}

# Test 3: Eye frames & Eye dots
Write-Host "`n3. Eye Frame and Eye Dot shapes:"
$eyeFrames = [Enum]::GetNames([SS_CAM.Services.QrEyeFrameShape])
$eyeDots = [Enum]::GetNames([SS_CAM.Services.QrEyeDotShape])
foreach ($ef in $eyeFrames) {
    foreach ($ed in $eyeDots) {
        $eOpts = New-Object SS_CAM.Services.QrCodeOptions
        $eOpts.Content = "https://suamisihat.clinic"
        $eOpts.EyeFrameShape = [Enum]::Parse([SS_CAM.Services.QrEyeFrameShape], $ef)
        $eOpts.EyeDotShape = [Enum]::Parse([SS_CAM.Services.QrEyeDotShape], $ed)
        $bmp = $service.GenerateQrCodeBitmap($eOpts)
        $svg = $service.GenerateSvgXml($eOpts)
        
        $dotValid = $true
        if ($ed -eq "Diamond") {
            $dotValid = $svg.Contains("<polygon")
        }
        Assert-Test ($bmp -ne $null -and $dotValid) "EyeFrame '$ef' + EyeDot '$ed'"
    }
}

# Test 4: Gradient Angle
Write-Host "`n4. Gradient Angle support in SVG:"
$gOpts = New-Object SS_CAM.Services.QrCodeOptions
$gOpts.Content = "https://suamisihat.clinic"
$gOpts.UseGradient = $true
$gOpts.GradientAngle = 90
$svg90 = $service.GenerateSvgXml($gOpts)
$gOpts.GradientAngle = 180
$svg180 = $service.GenerateSvgXml($gOpts)
Assert-Test ($svg90.Contains("linearGradient") -and $svg90 -ne $svg180) "Gradient angles generate distinct vector coords"

# Test 5: Logo embedding
Write-Host "`n5. Logo embedding in Bitmap and SVG:"
$logoBmp = New-Object System.Drawing.Bitmap 64, 64
$logoOpts = New-Object SS_CAM.Services.QrCodeOptions
$logoOpts.Content = "https://suamisihat.clinic"
$logoOpts.LogoImage = $logoBmp
$logoOpts.DrawLogoBackground = $true
$bmpWithLogo = $service.GenerateQrCodeBitmap($logoOpts)
$svgWithLogo = $service.GenerateSvgXml($logoOpts)
Assert-Test ($bmpWithLogo -ne $null -and $svgWithLogo.Contains("<image href=`"data:image/png;base64,") -and $svgWithLogo.Contains("<circle")) "Logo embedded in SVG with background circle pad"
$logoBmp.Dispose()

# Test 6: Sizing math scaling
Write-Host "`n6. Sizing math scaling:"
$sizes = @(300, 600, 1200, 2000)
$sizeOk = $true
foreach ($sz in $sizes) {
    $szOpts = New-Object SS_CAM.Services.QrCodeOptions
    $szOpts.Content = "https://suamisihat.clinic"
    $szOpts.PixelSize = $sz
    $resBmp = $service.GenerateQrCodeBitmap($szOpts)
    # Check that actual size is within 15% of requested size (clean module multiple)
    $ratio = [Math]::Abs($resBmp.Width - $sz) / $sz
    if ($ratio -gt 0.15) {
        $sizeOk = $false
        Write-Host "  Requested $sz, got $($resBmp.Width) (ratio: $ratio)"
    }
}
Assert-Test $sizeOk "PixelSize scaling across 300px to 2000px adheres to requested bounds"

Write-Host "=========================================="
Write-Host "  RESULTS: $passCount PASSED, $failCount FAILED"
Write-Host "=========================================="
if ($failCount -gt 0) { exit 1 } else { exit 0 }
