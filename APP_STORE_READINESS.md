# 🚀 App Store Readiness Checklist – Tepovka v3.0.0

**Status:** 🟡 **READY FOR SUBMISSION**  
**Target Date:** Q2 2026  
**Release Platforms:** iOS App Store + Google Play Store

---

## 📋 Pre-Launch Checklist

### Phase 1: Documentation ✅
- [x] Privacy Policy written (PRIVACY_POLICY.md)
- [x] Terms of Service written (TERMS_OF_SERVICE.md)
- [x] HTML privacy policy created (privacy_policy.html)
- [x] README.md completely updated
- [x] APP_STORE_LISTING.md with all metadata
- [x] RELEASE_BUILD_GUIDE.md with build instructions
- [x] CHANGES_FIXES.md documenting all updates

### Phase 2: Code Quality ✅
- [x] All print() statements wrapped in `if (kDebugMode)` guards
- [x] Summary class typo fixed (Summmary → Summary)
- [x] Backup files removed (ppg_algo_ver_2.dart, backup/)
- [x] Internal PDF removed (Stepan_Bakala_prubezne.pdf)
- [x] .gitignore updated with proper patterns
- [x] 22 unit tests passing (PPG algorithm)
- [x] flutter analyze: ✓ (only info warnings)
- [x] flutter test: ✓ (all 22 tests pass)

### Phase 3: Configuration ❓
- [ ] Android bundle ID updated: `cz.mojetepovka.tepovka` (DONE ✓)
- [ ] iOS bundle identifier verified (auto-generated from Android)
- [ ] Version bumped to 3.0.0 (pubspec.yaml)
- [ ] App description updated in pubspec.yaml
- [ ] iOS Info.plist permissions verified:
  - [ ] NSCameraUsageDescription ✓
  - [ ] NSHealthShareUsageDescription ✓
  - [ ] NSHealthUpdateUsageDescription ✓
  - [ ] NSMicrophoneUsageDescription ✓
- [ ] Android AndroidManifest.xml verified:
  - [ ] android.permission.CAMERA ✓
  - [ ] android.permission.INTERNET ✓

### Phase 4: Build Verification 🟡
- [ ] Android APK built successfully (flutter build apk --release)
  - Expected size: < 30MB ✓
  - Expected: ARM64 optimized
  - Command: `flutter build apk --release --target-platform android-arm64`
  
- [ ] Android AAB built for Play Store
  - Command: `flutter build appbundle --release`
  - Output: `build/app/outputs/bundle/release/app-release.aab`
  
- [ ] iOS build successful
  - Command: `flutter build ios --release`
  - Signature: Verified ✓
  - Version: 3.0.0
  - Build number: 1

### Phase 5: Store Assets 🟡
- [ ] App Icon (1024x1024 minimum)
  - Current file: `assets/tepovka.png` (verify resolution)
  - Alternative: `assets/vut_heart.png`
  - Required: 1024x1024 minimum, no transparency
  
- [ ] Screenshots (iOS & Android)
  - [ ] Screenshot 1: Measurement screen
  - [ ] Screenshot 2: Results dashboard
  - [ ] Screenshot 3: HRV chart
  - [ ] Screenshot 4: HealthKit sync
  - [ ] Screenshot 5: Privacy notice
  - iOS: 1242x2208 (6.1" iPhone)
  - Android: 1080x1920 (5.5" device)

- [ ] Preview Video (optional)
  - Duration: < 30 seconds
  - Format: MP4 H.264
  - Content: Demo measurement process

### Phase 6: Store Listing (From APP_STORE_LISTING.md) 🟡

**iOS App Store:**
- [ ] App Name: "Tepovka"
- [ ] Subtitle: "Heart Rate & HRV Wellness"
- [ ] Category: Health & Fitness
- [ ] Content Rating: 4+
- [ ] Description: [5000 chars from APP_STORE_LISTING.md]
- [ ] Keywords: [From APP_STORE_LISTING.md]
- [ ] Support URL: https://mojetepovka.cz/support
- [ ] Privacy Policy: https://mojetepovka.cz/privacy
- [ ] Terms of Service: https://mojetepovka.cz/terms

**Google Play:**
- [ ] App Name: "Tepovka"
- [ ] Category: Medical
- [ ] Short Description: "Heart Rate & HRV Monitor"
- [ ] Full Description: [From APP_STORE_LISTING.md]
- [ ] Promotional Text: [From APP_STORE_LISTING.md]
- [ ] Content Rating: Low Risk
- [ ] Privacy Policy: https://mojetepovka.cz/privacy
- [ ] Permissions Declaration: [From APP_STORE_LISTING.md]

---

## ⚙️ Next Steps (Before Submission)

### 1. Create Developer Accounts
```
iOS:
- [ ] Apple Developer Program ($99/year)
- [ ] Create App ID for Tepovka
- [ ] Create provisioning profiles
- [ ] Add signing certificates
- [ ] Access App Store Connect

Android:
- [ ] Google Play Developer Account ($25 one-time)
- [ ] Create app in Google Play Console
- [ ] Set up app signing
- [ ] Access Play Console Dashboard
```

### 2. Setup Web Infrastructure
```
- [ ] Domain mojetepovka.cz active
- [ ] Privacy policy accessible: /privacy
- [ ] Terms of service accessible: /terms
- [ ] Support email: support@mojetepovka.cz
- [ ] Security email: security@mojetepovka.cz
- [ ] DPO email: dpo@vut.cz
```

### 3. Create Android Signing Key (First Time Only)
```bash
cd android/app

# Generate keystore
keytool -genkey -v -keystore tepovka-release-key.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias tepovka

# Store password securely in password manager!
# Create key.properties (never commit to git)
cat > ../key.properties << EOF
storePassword=___SECURE_PASSWORD___
keyPassword=___SECURE_PASSWORD___
keyAlias=tepovka
storeFile=app/tepovka-release-key.jks
EOF

# Add to .gitignore
echo "key.properties" >> ../.gitignore
```

### 4. Prepare Screenshots and Videos
```
Screenshot Order:
1. App launch / onboarding
2. Measurement in progress
3. Results with HRV metrics
4. History / trends
5. HealthKit settings

Tools:
- Screenshots: Device screen capture
- Video: Screen recording on device, trim to 30s
- Optimization: ImageMagick, FFmpeg
```

### 5. Finalize Metadata
```
Update before submission:
- [ ] App version in pubspec.yaml
- [ ] Build number incremented
- [ ] All strings localized (Czech ✓, English ✓)
- [ ] Theme colors consistent (app brand)
```

---

## 🔐 Security Checklist Before Release

- [ ] No hardcoded passwords or API keys
- [ ] No debug/verbose logging in release build
- [ ] Permissions: Only Camera + optional HealthKit
- [ ] HTTPS enforced for network requests
- [ ] Keystore password saved in password manager
- [ ] Code signing certificate valid
- [ ] iOS provisioning profiles active
- [ ] Android app signing configured
- [ ] Git repository: No sensitive files committed

---

## 📱 Platform-Specific Checklists

### iOS App Store

```
Pre-Submission:
- [ ] TestFlight build uploaded and tested
- [ ] Wait 24-48 hours for TestFlight build processing
- [ ] Test on iPad (if app is universal)
- [ ] Verify camera permissions prompt
- [ ] Verify HealthKit access prompt
- [ ] Test HealthKit sync toggles
- [ ] Verify offline functionality
- [ ] Review all UI layouts (portrait + landscape)

Submission:
- [ ] All required fields filled in App Store Connect
- [ ] Screenshots uploaded for all device sizes
- [ ] Build selected for submission
- [ ] Content rating questionnaire completed
- [ ] Age rating confirmed (4+)
- [ ] Advertising ID usage: None ✓
- [ ] Encryption: Approved ✓
- [ ] Third-party SDKs: Declared ✓
- [ ] Click "Submit for Review"

Expected Review Time: 24-48 hours
Approval Rate: ~95% for health apps with proper disclaimers
```

### Google Play Store

```
Pre-Submission:
- [ ] Internal testing release created
- [ ] App tested on Android 8.0, 10, 12, 13
- [ ] Both portrait and landscape work
- [ ] Permission prompts function correctly
- [ ] Health Connect integration verified (Android 13+)
- [ ] Offline functionality confirmed
- [ ] APK size < 100MB ✓
- [ ] AAB size < 50MB ✓

Submission:
- [ ] App listing complete (title, description, etc.)
- [ ] Screenshots uploaded (4-8 images)
- [ ] Featured image (1024x500) uploaded
- [ ] Content rating questionnaire filled
- [ ] Alcohol/Tobacco/etc. ratings set
- [ ] Privacy policy URL provided
- [ ] Terms of service URL provided
- [ ] User data usage declared (health data)
- [ ] Permissions declared (camera, internet)
- [ ] No health claims without validation ✓
- [ ] Set to "Staged rollout" (5% initially)
- [ ] Click "Request Review"

Expected Review Time: 2-4 hours
Approval Rate: ~85% for health apps (watch for policy violations)
```

---

## 🔄 Staged Rollout Strategy

### Android Google Play (Recommended)

```
Week 1: 5% rollout
- Monitor crash reports
- Check ANRs (Application Not Responding)
- Read user feedback
- Verify HRV calculations accuracy

Week 2: 25% rollout
- Expand if no critical issues
- Monitor performance metrics
- Check for device-specific bugs

Week 3: 50% rollout
- Further expand if stable
- One more week of monitoring

Week 4: 100% rollout
- Full public availability
- Continue monitoring indefinitely
```

### iOS App Store

```
- No staged rollout available
- All or nothing release
- Can only pull app (cannot reduce % installed)
- Release to everyone at once
```

---

## 📊 Post-Launch Monitoring (First Month)

### Daily (Week 1)
- [ ] Check crash reports
- [ ] Read new user reviews
- [ ] Monitor app store ratings
- [ ] Verify HealthKit sync works
- [ ] Test new reported issues

### Weekly
- [ ] Review analytics dashboard
- [ ] Compilation: User feedback themes
- [ ] Check for security issues reported
- [ ] Prepare hotfix if needed

### Metrics to Track
```
Target Metrics:
- Crash Rate: < 0.5%
- ANR Rate (Android): < 0.5%
- Average Rating: ≥ 4.0 stars
- Negative Reviews: < 5% of total
- Daily Active Users: Track growth
- Retention: 30-day retention > 25%
```

### Common Issues & Fixes
```
If Camera Access Crashes:
- Add permission handling
- Hotfix: v3.0.1

If HRV Calculations Wrong:
- Verify algorithm logic
- Check framerate estimation
- Hotfix: v3.0.2

If HealthKit Not Syncing (iOS):
- Verify HSK capabilities
- Check permission prompt
- Hotfix: v3.0.1

If App Too Large (>100MB):
- Strip unused assets
- Enable Proguard (Android)
- Hotfix: v3.0.3
```

---

## 🎯 Success Criteria

✅ **App Store Readiness**: When ALL sections are marked complete

✅ **Launch Success**: After 1 week with:
- Zero critical crashes
- >= 3.5 star rating
- >= 50 downloads/reviews
- No policy violation emails from stores

✅ **Post-Launch Success** (1 month):
- >= 4.0 stars
- >= 500 downloads
- >= 20 positive reviews
- < 1% crash rate
- < 5% uninstall rate

---

## 📞 Support Contacts

| Issue | Contact |
|-------|---------|
| App Store review rejected | App Store Review Guidelines @ Apple |
| Google Play rejected | Google Play Policy Support |
| Technical support | support@mojetepovka.cz |
| Security issues | security@mojetepovka.cz |
| Privacy questions | privacy@mojetepovka.cz |
| Press/Media | press@mojetepovka.cz |

---

## 📝 Final Notes

### Key Reminders
1. **No Medical Claims** – This is WELLNESS, not medical device
2. **Privacy First** – Everything local, nothing sent to servers
3. **Transparency** – Open source, auditable codebase
4. **User Control** – Easy opt-out of any features
5. **Health Disclaimer** – Clear limitations in description

### Timeline
```
NOW: Final testing & documentation ✓
2 weeks: Submission to both app stores
2-4 days: iOS App Store review
2-4 hours: Google Play review
THEN: Soft launch (5-25% rollout)
4 weeks: Full public launch
```

---

**Last Updated:** March 9, 2026  
**Created by:** Tepovka Development Team  
**Current Version:** 3.0.0+1  
**Status:** 🟡 **PENDING SUBMISSION**

---

## 🚀 Ready to Launch?

Once ALL checkboxes are complete:
1. Create final git commit with version bump
2. Tag release: `git tag v3.0.0`
3. Upload to both app stores simultaneously
4. Monitor closely for first 48 hours
5. Prepare response to any rejections
6. Plan v3.1.0 improvements based on feedback

**Good luck! 🎉**
