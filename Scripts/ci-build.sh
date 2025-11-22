#!/usr/bin/env bash

# CI Build Script for BilibiliLive
# Runs a headless build for tvOS

set -euo pipefail

# Try to build for generic tvOS platform (may require a connected device or simulator)
xcodebuild -scheme BilibiliLive -destination 'generic/platform=tvOS' clean build || \
xcodebuild -scheme BilibiliLive -destination 'platform=tvOS Simulator,OS=latest,name=Apple TV' clean build || \
xcodebuild -scheme BilibiliLive clean build