# Release Build Guide – Tepovka

**For:** iOS App Store + Google Play Store Release  
**Version:** 3.0.0  
**Date:** March 2026

---

## 1. Pre-Release Verification

### 1.1 Code Quality Check
```bash
# Flutter analysis (no errors)
flutter analyze --no-fatal-infos

# Expected output:
# ✓ No critical errors
# ℹ A few info-level warnings are OK
```

### 1.2 Unit Tests
```bash
# Run all tests
flutter test 2>&1 | grep -E "^[✓✗]|passed|failed"

# Expected:
# ✅ 22 tests passed (PPG algorithms)
```

### 1.3 Performance Check
```bash
# Analyze APK size
flutter build apk --analyze-size

# Expected: < 30MB
```

### 1.4 Device Compatibility
```
✓ Built for Android ARM64 (primary)
✓ Tested on iOS 14+, Android 8.0+
✓ Dark mode supported
✓ Landscape + Portrait orientations working
```

---

## 2. Android Release Build

### 2.1 Create Signing Key (First Time Only)

```bash
cd android/app

# Generate keystore (if you don't have one)
keytool -genkey -v -keystore tepovka-release-key.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias tepovka

# This will ask for:
# - Password (USE STRONG PASSWORD!)
# - Organization name: VUT Brno
# - Organizational unit: Research
# - City: Brno
# - State: South Moravian
# - Country code: CZ
```

### 2.2 Configure key.properties

```bash
cd android

# Create key.properties file
cat > key.properties << 'EOF'
storePassword=YOUR_PASSWORD_HERE
keyPassword=YOUR_PASSWORD_HERE
keyAlias=tepovka
storeFile=app/tepovka-release-key.jks
EOF

# Important: Add to .gitignore to never commit passwords!
echo "key.properties" >> .gitignore
```

### 2.3 Build Signed APK

```bash
cd /path/to/tessovka_app

# Clean build (recommended)
flutter clean

# Build AAB for Play Store (RECOMMENDED)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### 2.4 Build APK (Alternative for Direct Distribution)

```bash
# Multi-architecture APK
flutter build apk --release --split-per-abi
# Outputs: 
#   - app-arm64-v8a-release.apk (primary, ~25MB)
#   - app-armeabi-v7a-release.apk (legacy, ~22MB)
#   - app-x86_64-release.apk (emulator, ~26MB)

# Single architecture (smaller)
flutter build apk --release --target-platform android-arm64
# Output: build/app/outputs/flutter-apk/app-release.apk (~24MB)
```

### 2.5 Verify Signatures

```bash
# Check if APK is properly signed
jarsigner -verify -verbose -certs \
    build/app/outputs/flutter-apk/app-release.apk

# Should show:
# jar verified. This jar contains entries whose certificate chain is not validated.
```

---

## 3. iOS Release Build

### 3.1 Update Build & Version Numbers

```bash
# In pubspec.yaml
version: 3.0.0+1   # This increments the iOS build number on each release

# Or manually in Xcode:
# Project > Targets > General > Version: 3.0.0, Build: 1
```

### 3.2 Build for Release

```bash
# Clean
flutter clean

# Build iOS release
flutter build ios --release

# Alternatively, open Xcode and build:
open ios/Runner.xcworkspace
# Product > Build For > Testing
# Or use Archive for App Store submission
```

### 3.3 Create Archive (for App Store)

```bash
# Using flutter
flutter build ios --release

# Or in Xcode:
# Select iOS Device as target
# Product > Archive
# This creates .xcarchive in ~/Library/Developer/Xcode/Archives/
```

### 3.4 Upload to App Store Connect

```bash
# Using Transporter (Apple's upload tool)
# Download from: https://apps.apple.com/app/transporter/id1450874784

# Or use fastlane:
fastlane deliver --ipa ./build/ios/release/Runner.ipa

# Or xcrun:
xcrun altool --upload-app \
    --type ios \
    --file ~/path/to/Runner.ipa \
    --username your-apple-id@example.com \
    --password your-app-specific-password
```

---

## 4. Google Play Store Upload

### 4.1 Create Google Play Account (First Time)

1. Go to: https://play.google.com/console/
2. Choose billing account
3. Create app: Tepovka
4. Set category: Medical

### 4.2 Upload AAB (Recommended)

```bash
# Build AAB
flutter build appbundle --release

# Upload using Google Play Console:
# 1. Go to Internal Testing > Releases
# 2. Create new release
# 3. Upload: build/app/outputs/bundle/release/app-release.aab
# 4. Set version: 3.0.0 (matches pubspec.yaml)
# 5. Set release notes
```

### 4.3 Configure Store Listing

```bash
# In Google Play Console:
1. Store Listing > Summary
   - Title: Tepovka
   - Short description: [from APP_STORE_LISTING.md]
   - Full description: [from APP_STORE_LISTING.md]

2. Graphics
   - Feature graphic (1024x500): [Hero image]
   - Icon (512x512): [App icon]
   - Screenshots: [5-8 screenshots]

3. Content Rating Questionnaire
   - Select: Medical/Health
   - Fill out questions

4. App Category
   - Primary: Medical
   - Secondary: Health & Fitness

5. Contact Details
   - Fill with your contact info
```

### 4.4 Release Strategy

```bash
# Staged rollout (recommended)
1. Create Internal Testing release first (100%)
   - Wait 24-48 hours for feedback
   
2. Move to Closed Testing (5-10% of audience)
   - Wait 1 week for stability
   
3. Expand to full Open Testing (25%)
   - Wait 2 weeks
   
4. Production release (100%)
   - Full public availability
```

---

## 5. App Store Connect (iOS)

### 5.1 Create App Record

1. Go to https://appstoreconnect.apple.com
2. Apps > Tepovka > App Information
3. Primary Category: Health & Fitness
4. Content Rating: 4+

### 5.2 Version Information

```
Version Number: 3.0.0
Build Number: 1
```

### 5.3 Store Listing

```
Title: Tepovka
Subtitle: Heart Rate & HRV Wellness
Keywords: [from APP_STORE_LISTING.md]
Description: [from APP_STORE_LISTING.md]
Support URL: https://mojetepovka.cz/support
Privacy Policy URL: https://mojetepovka.cz/privacy
```

### 5.4 Build & Submit

1. Upload IPA via Transporter
2. Wait for build processing (10-15 minutes)
3. Enable for App Store
4. Click "Submit for Review"
5. Apple review: 24-48 hours typically

---

## 6. Version Management

### 6.1 Semantic Versioning

```
3.0.0+1
│   │ │  │
│   │ │  └─ iOS Build Number (increment each iOS build)
│   │ └──── Patch (bug fixes: 3.0.1, 3.0.2)
│   └────── Minor (features: 3.1.0)
└────────── Major (breaking changes: 4.0.0)
```

### 6.2 Build Numbers

```bash
# Android: Increment with each Play Store release
# iOS: Increment with each App Store submission

# For new iOS builds:
version: 3.0.0+2  # +2 on second submission
version: 3.0.0+3  # +3 on third submission

# Use only digits: 1, 2, 3... (not 1.0, 1.1)
```

---

## 7. Release Checklist

- [ ] All code reviewed
- [ ] Unit tests pass (22/22)
- [ ] flutter analyze completed
- [ ] App tested on real iOS device
- [ ] App tested on real Android device
- [ ] Screenshots captured (5+ each store)
- [ ] Privacy Policy published
- [ ] Terms of Service published
- [ ] Android keystore configured + password saved
- [ ] iOS provisioning profile valid
- [ ] AAB/IPA built successfully
- [ ] Version numbers updated (3.0.0)
- [ ] Build numbers incremented
- [ ] Signed APK verified
- [ ] Uploaded to Google Play Console
- [ ] Uploaded to App Store Connect
- [ ] Filled all store listing fields
- [ ] Content rating completed
- [ ] Permissions declared
- [ ] Released to internal testing first
- [ ] Waited 48 hours for feedback
- [ ] Moved to staged rollout (5%)
- [ ] Expanded to 25% after 1 week
- [ ] Final release to 100%
- [ ] Monitored crash reports
- [ ] Responded to user feedback

---

## 8. Troubleshooting

### Build Issues

**Issue:** "Signed with an unknown certificate"
```bash
# Solution: Rebuild with correct keystore
flutter build apk --release
```

**Issue:** "Build version too low"
```bash
# Solution: Increment build number in pubspec.yaml
version: 3.0.0+2
flutter build appbundle --release
```

**Issue:** APK too large (>100MB)
```bash
# Solution: Use split-per-abi or analyze size
flutter build apk --release --split-per-abi
flutter build apk --analyze-size
```

### Submission Issues

**Testflight Rejection:** "Missing HealthKit permissions"
```
Check iOS Info.plist for:
- NSHealthShareUsageDescription  
- NSHealthUpdateUsageDescription 
- NSMicrophoneUsageDescription
- NSCameraUsageDescription
```

**Play Store Rejection:** "Medical claims without validation"
```
Review app description for:
- ❌ "Diagnoses" → ❌
- ❌ "Cures" → ❌
- ✅ "Monitors" → ✅
- ✅ "Tracks" → ✅
- ✅ Includes disclaimer → ✅
```

---

## 9. Post-Release Monitoring

### Monitor (First Week)
```bash
# App Store Connect Metrics
- Crashes: Should be < 0.5%
- Ratings: Target 4.0+ stars
- Reviews: Read for feedback

# Google Play Console
- Crashes: < 1%
- ANRs (Application Not Responding): < 0.5%
- Ratings: Target 4.0+ stars
```

### Common Issues to Fix
```
1. Measurement accuracy issues
2. Camera access problems
3. HealthKit sync failures
4. UI crashes on specific devices
```

### Update Schedule
```
- Critical bugs: Hotfix within 48 hours (v3.0.1)
- Feature improvements: 2-week sprint (v3.1.0)
- Major updates: Quarterly (v4.0.0)
```

---

## 10. Security & Credentials

### 🔐 Store Securely

```bash
# Android keystore password (IMPORTANT!)
# Store in password manager:
- Provider: Android Keystore
- Path: android/app/tepovka-release-key.jks
- Password: [IN LASTPASS/1PASSWORD]

# Apple ID credentials
- Username: [your-apple-id]
- App-Specific Password: [16-char password from https://appleid.apple.com]

# Google Play Service Account
- JSON key: [Store in secure location]
```

### ⚠️ Never Commit

```bash
# Add to .gitignore
key.properties
*.jks
app-release.aab
app-release.apk
*.ipa
.env
secrets/
```

---

**Last Updated:** March 9, 2026  
**Next Review:** Before v3.1.0 release
