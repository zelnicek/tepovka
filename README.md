# 💓 Tepovka – Heart Rate & HRV Wellness App

**A professional-grade, privacy-first wellness application for measuring heart rate and heart rate variability (HRV) using smartphone camera technology.**

![Version](https://img.shields.io/badge/version-3.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)
![Status](https://img.shields.io/badge/status-🟡%20Ready%20for%20App%20Store-yellow)

---

## 📋 Table of Contents

1. [Features](#features)
2. [Quick Start](#quick-start)
3. [Technical Details](#technical-details)
4. [Installation](#installation)
5. [Building & Release](#building--release)
6. [Privacy & Security](#privacy--security)
7. [Documentation](#documentation)
8. [Contributing](#contributing)
9. [License](#license)
10. [Contact](#contact)

---

## ✨ Features

### Measurement Capabilities
- **Real-time Heart Rate (BPM)** – Beats per minute calculation
- **Heart Rate Variability (HRV)** – SDNN, RMSSD, pNN50, SD1, SD2
- **Respiratory Rate (RR)** – Breathing frequency tracking
- **Continuous Metrics** – Sliding-window processing for real-time updates
- **Data Export** – CSV format for analysis or medical review

### User Experience
- 🎨 Beautiful chart visualization with real-time FFT display
- 📊 Historical trend analysis
- 👵 **Senior-Friendly Interface** – Large text, high contrast, voice guidance
- 🌙 Dark mode support
- 🇨🇿 Czech localization
- ⚡ Haptic feedback for user feedback
- 🔇 Text-to-Speech announcements

### Privacy & Security
- 🔐 **100% Local Processing** – No cloud uploads, all computation on-device
- 🚫 **No Registration** – Use without account creation
- 📱 **No Tracking** – No analytics or advertising networks
- 🏥 **HealthKit Integration** (optional) – Sync with Apple Health / Health Connect
- 📄 **Open Source** – Transparent, auditable code

### Accessibility
- ✓ iOS 14+, Android 8.0+ support
- ✓ Portrait + Landscape orientations
- ✓ Camera permission handling
- ✓ Microphone control for LED flash

---

## 🚀 Quick Start

### For Users
1. Download from **App Store** (iOS) or **Google Play** (Android)
2. Grant camera permission
3. Place finger on camera, keep still
4. View measurements in 60 seconds

### For Developers

```bash
# Clone repository
git clone https://github.com/zelnicek/tepovka.git
cd tepovka

# Install dependencies
flutter pub get

# Connect iOS dependencies (CocoaPods)
cd ios && pod install && cd ..

# Run on emulator/simulator
flutter run

# Run specific device
flutter run -d <device-id>
```

---

## 🔧 Technical Details

### Architecture

```
lib/
├── main.dart                 # App entry point + theme
├── home.dart                 # Main measurement UI
├── ppg_algo.dart            # Core PPG algorithm ⭐⭐⭐
├── pages/                   # Feature screens
│   ├── intro_page.dart      # Home/dashboard
│   ├── settings.dart        # App settings
│   ├── summary_page.dart    # Results display
│   ├── records.dart         # Measurement history
│   └── about.dart           # App information
├── elements/                # Reusable UI components
│   ├── camera_body.dart     # Camera integration
│   └── chart_widgets.dart   # Chart components
├── services/                # Business logic
│   ├── app_settings.dart    # Settings persistence
│   ├── local_profile_service.dart
│   └── tts_service.dart     # Text-to-speech
└── theme.dart               # Design system
```

### Core Algorithm: `ppg_algo.dart`

**State-of-the-art photoplethysmography signal processing:**

```dart
// Sliding window processing
- 60-frame buffer with 30-frame intervals
- Pre-filtering: Butterworth bandpass (0.5-4 Hz)
- FFT + peak detection hybrid approach
- Local framerate estimation (fixes GC pauses)
- Continuous HRV calculation (300-IBI rolling window)
- Poincaré plot analysis (SD1 vs SD2)
```

**Key Methods:**
```dart
double getCurrentHeartRate()           // 40-200 BPM
double getCurrentRespiratoryRate()     // 6-30 breaths/min
double getSdnn()                       // Standard Deviation NN intervals
double getRmssd()                      // Root Mean Square SD
double getPnn50()                      // % of intervals > 50ms
double getSd1() / getSd2()             // Poincaré plot metrics
```

### Dependencies

**Key Libraries:**
- `camera: ^0.11.0` – Device camera access
- `fftea: ^1.5.0+1` – Fast Fourier Transform
- `iirjdart: ^0.1.0` – Butterworth filtering
- `health: ^13.1.3` – HealthKit integration (iOS/Android)
- `flutter_tts: ^4.2.5` – Text-to-speech
- `shared_preferences: ^2.2.2` – Local data persistence

---

## 💻 Installation

### Prerequisites

```bash
flutter --version                          # Should be 3.5.2+
Xcode 14.0+ (for iOS)
Android Studio / Android SDK 26+
```

### Step-by-Step

```bash
# 1. Clone
git clone https://github.com/zelnicek/tepovka.git
cd tepovka

# 2. Get dependencies
flutter pub get

# 3. iOS setup (if on Mac)
cd ios
pod install --repo-update
cd ..

# 4. Run
flutter run

# 5. Or build for release (see RELEASE_BUILD_GUIDE.md)
flutter build apk --release
flutter build ios --release
```

### IDE Setup

```
# VS Code
- Install Flutter extension
- Install Dart extension
- Install Android Studio (for Android SDK)

# OR Android Studio
- Install Flutter plugin
- Install Dart plugin
- Create emulator (API 26+)
```

---

## 📦 Building & Release

### Development Build

```bash
# Debug APK (fast, unoptimized)
flutter build apk --debug

# Debug iOS
flutter run -d iPhone
```

### Production Build

```bash
# Android AAB for Play Store (RECOMMENDED)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab

# iOS for App Store
flutter build ios --release
# Then upload via Xcode Organizer or Transporter
```

### Testing Before Release

```bash
# Code quality
flutter analyze --no-fatal-infos

# Unit tests (22 tests)
flutter test

# Build size analysis
flutter build apk --analyze-size --release
# Target: < 30MB maximum
```

**See [RELEASE_BUILD_GUIDE.md](./RELEASE_BUILD_GUIDE.md) for complete instructions.**

---

## 🔐 Privacy & Security

### Data Handling Philosophy

✅ **What We DO:**
- Process measurements locally on device
- Store data in local app storage (encrypted by OS)
- Offer optional HealthKit/Health Connect sync
- Provide data export (CSV) on user request

❌ **What We DON'T:**
- Send data to servers (no cloud sync)
- Track user location
- Collect personal identifiers
- Share with third parties
- Use advertising networks
- Build user profiles

### Compliance

- ✓ **GDPR** – European data protection standards
- ✓ **CCPA** – California privacy requirements  
- ✓ **HIPAA-like** – Health data protection principles
- ✓ **Apple HealthKit Terms** – Proper review guidelines
- ✓ **Google Play Medical Policy** – Health app requirements

### Security Best Practices

```
✓ Permissions: Only camera + optional HealthKit
✓ Data Storage: SharedPreferences (OS-protected)
✓ Transport: HTTPS for HealthKit sync
✓ Code: Open source = transparent auditing
```

**Full Privacy Policy:** [PRIVACY_POLICY.md](./PRIVACY_POLICY.md)  
**Terms of Service:** [TERMS_OF_SERVICE.md](./TERMS_OF_SERVICE.md)

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) | Health data privacy & GDPR compliance |
| [TERMS_OF_SERVICE.md](./TERMS_OF_SERVICE.md) | User agreement & liability disclaimer |
| [APP_STORE_LISTING.md](./APP_STORE_LISTING.md) | App Store metadata & screenshots |
| [RELEASE_BUILD_GUIDE.md](./RELEASE_BUILD_GUIDE.md) | Build, sign, and release instructions |
| [CHANGES_FIXES.md](./CHANGES_FIXES.md) | Algorithm improvements & bug fixes |
| [analysis_options.yaml](./analysis_options.yaml) | Dart linting configuration |

---

## 🧪 Testing

### Unit Tests
```bash
flutter test                                 # Run all tests
flutter test --verbose                       # Detailed output
flutter test test/ppg_algorithm_test.dart   # Specific test file
```

**Test Coverage:**
- ✓ PPG algorithm (calculateStandardDeviation, state management)
- ✓ HRV metrics validity (SDNN, RMSSD, pNN50, SD1, SD2)
- ✓ Heart rate calculations (range validation)
- ✓ Respiratory rate calculations
- ✓ Data export functionality

### Manual Testing Checklist

- [ ] Measurement accuracy (compare with known devices)
- [ ] Camera permissions (grant/deny scenarios)
- [ ] HealthKit sync (iOS + Android)
- [ ] Data export (CSV format)
- [ ] Senior mode (large text, voice)
- [ ] Offline functionality (works without internet)
- [ ] Battery drain (30-min continuous use)
- [ ] Landscape orientation
- [ ] App backgrounding + resume

---

## 🐛 Known Issues & Limitations

### Current Limitations

- **Accuracy:** ±5-15% vs clinical devices (PPG is approximation)
- **Environment:** Works best with good lighting
- **Movement:** User must keep finger very still
- **Phone Variations:** Different cameras may have different accuracy
- **Not Medical:** This is wellness tracking, NOT clinical diagnosis

### Supported Devices

| Device | Minimum OS | Status |
|--------|-----------|--------|
| iPhone | iOS 14.0 | ✅ Tested |
| iPad | iOS 14.0 | ✅ Tested |
| Android Phone | 8.0 (API 26) | ✅ Tested |
| Android Tablet | 8.0 (API 26) | ✅ Works |

---

## 🤝 Contributing

### Reporting Issues
```
Bug reports: contact@mojetepovka.cz
Security issues: security@mojetepovka.cz
Feature requests: feedback@mojetepovka.cz
```

### Development

```bash
# Create feature branch
git checkout -b feature/your-feature

# Commit with descriptive messages
git commit -m "feat: Add new PPG algorithm improvement"

# Push and create pull request
git push origin feature/your-feature
```

---

## 📄 License

MIT License – See [LICENSE](./LICENSE) for details.

**In summary:**
- ✓ Free for commercial use
- ✓ Can modify and distribute
- ✓ Must include license notice
- ✗ No warranty provided

---

## 👥 Contact & Support

| | Contact |
|---|---------|
| **Support** | support@mojetepovka.cz |
| **Technical** | tech@mojetepovka.cz |
| **Privacy** | privacy@mojetepovka.cz |
| **Website** | https://mojetepovka.cz |
| **GitHub** | github.com/zelnicek/tepovka |

---

## 🎯 Roadmap

### v3.0.0 (Current) ✅
- ✅ Core PPG algorithm with HRV
- ✅ HealthKit integration  
- ✅ Senior mode onboarding
- ✅ Unit tests (22 tests)
- ✅ App Store ready

### v3.1.0 (Q2 2026) 🟡
- Wearable integration (Wear OS)
- Advanced trend analysis
- Meditation mode
- Improved dark mode

### v4.0.0 (Q4 2026) 🔮
- Major UI redesign
- Machine learning improvements
- Integration with other wellness apps
- Web dashboard (optional)

---

## 📊 Statistics

```
Lines of Code:      ~2,500 (core algorithm)
Test Coverage:      22 unit tests
Package Version:    3.0.0+1
Target Users:       General wellness (65+ accessibility focus)
Privacy Grade:      A+ (no tracking, local processing)
Access Cost:        FREE
```

---

**Made with ❤️ by VUT Brno Research Team**

Last Updated: March 9, 2026  
Status: 🟡 **Ready for App Store Submission**

