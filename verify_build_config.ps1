# Verify Build Configuration Script
# Run this before building AAB to ensure everything is configured correctly

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Tenzi za Rohoni - Build Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allGood = $true

# Check 1: Keystore file
Write-Host "1. Checking keystore file..." -ForegroundColor Yellow
$keystorePath = "C:\Users\Salvatory Jr\upload-keystore.jks"
if (Test-Path $keystorePath) {
    Write-Host "   ✓ Keystore found: $keystorePath" -ForegroundColor Green
} else {
    Write-Host "   ✗ Keystore NOT found: $keystorePath" -ForegroundColor Red
    $allGood = $false
}

# Check 2: key.properties
Write-Host "2. Checking key.properties..." -ForegroundColor Yellow
$keyPropsPath = "android\key.properties"
if (Test-Path $keyPropsPath) {
    Write-Host "   ✓ key.properties found" -ForegroundColor Green
    $content = Get-Content $keyPropsPath
    if ($content -match "storePassword" -and $content -match "keyPassword" -and $content -match "keyAlias" -and $content -match "storeFile") {
        Write-Host "   ✓ All required properties present" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Missing required properties" -ForegroundColor Red
        $allGood = $false
    }
} else {
    Write-Host "   ✗ key.properties NOT found" -ForegroundColor Red
    $allGood = $false
}

# Check 3: App icons
Write-Host "3. Checking app icons..." -ForegroundColor Yellow
$iconDensities = @("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")
$iconsMissing = 0
foreach ($density in $iconDensities) {
    $iconPath = "android\app\src\main\res\mipmap-$density\ic_launcher.png"
    if (Test-Path $iconPath) {
        Write-Host "   ✓ mipmap-$density icon found" -ForegroundColor Green
    } else {
        Write-Host "   ✗ mipmap-$density icon MISSING" -ForegroundColor Red
        $iconsMissing++
        $allGood = $false
    }
}

# Check 4: AndroidManifest.xml
Write-Host "4. Checking AndroidManifest.xml..." -ForegroundColor Yellow
$manifestPath = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw
    if ($manifest -match 'android:icon="@mipmap/ic_launcher"') {
        Write-Host "   ✓ Icon reference found in manifest" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Icon reference NOT found in manifest" -ForegroundColor Red
        $allGood = $false
    }
    
    if ($manifest -match "ca-app-pub-3940256099942544") {
        Write-Host "   ⚠ WARNING: Using test AdMob ID" -ForegroundColor Yellow
    } else {
        Write-Host "   ✓ Production AdMob ID configured" -ForegroundColor Green
    }
} else {
    Write-Host "   ✗ AndroidManifest.xml NOT found" -ForegroundColor Red
    $allGood = $false
}

# Check 5: build.gradle.kts
Write-Host "5. Checking build.gradle.kts..." -ForegroundColor Yellow
$gradlePath = "android\app\build.gradle.kts"
if (Test-Path $gradlePath) {
    $gradle = Get-Content $gradlePath -Raw
    if ($gradle -match "signingConfigs") {
        Write-Host "   ✓ Signing config found" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Signing config NOT found" -ForegroundColor Red
        $allGood = $false
    }
    
    if ($gradle -match "minifyEnabled = true") {
        Write-Host "   ✓ Code minification enabled" -ForegroundColor Green
    } else {
        Write-Host "   ⚠ Code minification disabled" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ✗ build.gradle.kts NOT found" -ForegroundColor Red
    $allGood = $false
}

# Check 6: Flutter version
Write-Host "6. Checking Flutter..." -ForegroundColor Yellow
$flutterCheck = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCheck) {
    Write-Host "   ✓ Flutter installed" -ForegroundColor Green
} else {
    Write-Host "   ✗ Flutter NOT found in PATH" -ForegroundColor Red
    $allGood = $false
}

# Check 7: pubspec.yaml version
Write-Host "7. Checking app version..." -ForegroundColor Yellow
$pubspecPath = "pubspec.yaml"
if (Test-Path $pubspecPath) {
    $version = Get-Content $pubspecPath | Select-String "^version:" | Select-Object -First 1
    Write-Host "   ✓ $version" -ForegroundColor Green
} else {
    Write-Host "   ✗ pubspec.yaml NOT found" -ForegroundColor Red
    $allGood = $false
}

# Final summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($allGood) {
    Write-Host "  ✓ ALL CHECKS PASSED!" -ForegroundColor Green
    Write-Host "  Ready to build AAB" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run: flutter build appbundle --release" -ForegroundColor Cyan
} else {
    Write-Host "  ✗ SOME CHECKS FAILED" -ForegroundColor Red
    Write-Host "  Please fix the issues above" -ForegroundColor Red
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
