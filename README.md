# SARISA

**System for Advanced Real-time Intelligent Search and Action**

Flutter starter application targeting Android and Windows. This repository is a user-interface and integration foundation, not a flight-certified system.

## Current prototype features
- Dark SARISA operator dashboard
- Mission draft screen
- Reference image upload for human-reviewed case records
- View-only network video URL player (supported formats depend on gateway)
- Telemetry display placeholders
- Disabled flight-control simulator panel
- Integration placeholders for maps, drone adapters and communications

## Safety and scope
This starter does not implement biometric identification, face matching, identity-based tracking, autonomous person following, weapon interfaces, or physical drone flight commands. Visual-analysis extensions should be limited to non-identifying scene/object classification for lawful Search & Rescue, with human review and privacy safeguards.

## Requirements
- Flutter stable (Dart 3.3+)
- Android toolchain for Android builds
- Visual Studio 2022 with Desktop development with C++ for Windows builds

## Run
```bash
flutter pub get
flutter run
```

## Build
```bash
flutter build apk --release
flutter build appbundle --release
flutter build windows --release
```

## GitHub Actions
Push to `main` or run workflows manually. Android workflow builds an APK; Windows workflow builds a ZIP containing the Windows runner output.

## Important
Before connecting any physical aircraft, obtain manufacturer documentation, use a certified/supported integration, conduct bench and simulator testing, and complete aviation/legal/safety review. Never rely on this prototype for operational flight.
