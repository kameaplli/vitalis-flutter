#!/bin/bash
# Build release APK and output size in bytes
cd "$(dirname "$0")/.." || exit 1
flutter build apk --release 2>&1 | tail -1 >&2
stat --printf="%s" build/app/outputs/flutter-apk/app-release.apk
