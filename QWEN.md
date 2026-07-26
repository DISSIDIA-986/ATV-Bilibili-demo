# Bilibili tvOS Client Demo - Project Context

## Project Overview

This is a **Bilibili tvOS Client Demo** - an unofficial iOS/tvOS application that provides a native interface for accessing Bilibili (a popular Chinese video platform) content on Apple TV devices. The application is written in Swift and targets tvOS 16.0+.

The project is open-source and serves as a demonstration of how to interact with Bilibili's APIs to provide features like video playback, live streaming, login via QR code, casting, and more. It's important to note that this is an independent project with no official affiliation to Bilibili and is not available on the App Store or TestFlight for commercial purposes.

### Key Features

The application supports:
- QR code login to Bilibili accounts
- Cloud TV casting protocol (云视听小电视投屏协议)
- Live streaming with danmaku (弹幕)
- Video recommendation feed
- Trending videos ("热门")
- Rankings system
- Search functionality
- Following lists
- Video history
- "Watch Later" functionality ("稍后再看")
- System player for video playback
- Video danmaku (comments overlay)
- Popular comments
- Danmaku anti-blocking (弹幕防挡)
- Cloud TV casting
- HDR playback
- Subtitles support

### Fork Enhanced Features
- Smart search with hot search rankings and pagination
- Area unlock for region-restricted bangumi (BiliRoaming proxy)
- SponsorBlock ad skipping
- One-command deployment to Apple TV (`scripts/deploy_to_appletv.sh`)
- Continuous playback crash prevention
- Multi-account switching
- Quality selection plugin (4K/1080P)

### Architecture

The project follows a modular architecture with the following main components:

- **AppDelegate**: Application entry point (`@main`). Handles non-UI bootstrap (logging, image cache, account, DLNA server) and owns root view controller *selection* (`makeRootViewController()`) and *switching* (`showLogin` / `showTabBar` / `resetTabBar`). It no longer creates the window.
- **SceneDelegate**: Owns the `UIWindow` and presents the initial root view controller, plus audio session setup on activation. Required since the tvOS 27 SDK, which makes the UIScene life cycle mandatory — apps still using the old `AppDelegate`-only window model trap at launch. Declared via `UIApplicationSceneManifest` in Info.plist; lives in `AppDelegate.swift`. See `docs/fixes/deploy-apple-account-and-bundle-id.md`.
- **BLTabBarViewController**: Main tab-based navigation controller with 10 tabs: Live, Feed, Hot, Ranking, History, Follows, Favorite, Upload, Search, and Personal
- **Module Directory**: Contains different functional modules:
  - Live: Live streaming features with danmaku support
  - DLNA: Casting functionality
  - Personal: User account features
  - ViewController: Main view controllers for each tab section
- **Request**: API request handling
- **Component**: Reusable UI components and custom views
- **Extensions**: Swift extensions for built-in types
- **Vendor**: Third-party library integrations

### Dependencies & Libraries

The project uses several libraries and frameworks:
- AVFoundation: For audio/video playback
- CocoaLumberjackSwift: For logging functionality
- UIKit: iOS/tvOS UI framework
- AVAudioSession: For audio session management

## Building and Running

### Prerequisites
- Xcode 15+ (Xcode 13 cannot build the tvOS 16.0 deployment target; the deploy script also relies on `xcodebuild -downloadPlatform`, added in Xcode 15). Matches `docs/TESTFLIGHT_GUIDE.md`.
- macOS with Xcode Command Line Tools
- Ruby (for fastlane)

### Build Process

The project supports multiple build methods:

1. **Using Xcode**:
   - Open `BilibiliLive.xcodeproj`
   - Select the BilibiliLive target
   - Build and run for tvOS Simulator or connected Apple TV

2. **Using Fastlane** (recommended for automated builds):
   ```bash
   # Install fastlane if not already installed
   bundle install
   
   # Build for simulator
   bundle exec fastlane build_simulator
   
   # Build unsigned IPA for distribution
   bundle exec fastlane build_unsign_ipa
   ```

3. **Using deploy script** (for direct installation on Apple TV):
   ```bash
   # One-command deploy (auto-detects device, builds, installs)
   ./scripts/deploy_to_appletv.sh

   # Clean build
   ./scripts/deploy_to_appletv.sh --clean

   # List connected Apple TVs
   ./scripts/deploy_to_appletv.sh --list
   ```

### Development Notes

- The application uses Bilibili's unofficial APIs (reverse-engineered endpoints)
- Login is handled through QR code scanning mechanism
- Video playback uses native AVPlayer with support for HDR and subtitles
- Danmaku (弹幕) functionality is implemented for both live streams and regular videos
- The app includes casting functionality for screen mirroring to other devices

### Debugging and Logging

The project uses CocoaLumberjack for logging, with the `Logger` class providing setup functionality. Logs can be useful for debugging API requests and understanding the application flow.

### Code Structure

- **Account Management**: `AccountManager.swift` handles user authentication and token management
- **API Requests**: `ApiRequest` class manages communication with Bilibili's servers
- **Web Requests**: `WebRequest` handles additional web-based operations
- **Keys**: `Keys.swift` contains API keys and other sensitive configuration values
- **DMR (UpnpDMR)**: BiliBiliUpnpDMR handles DLNA/UPnP casting functionality

### Important Security Notes

- This project has no official authorization and is not available for commercial distribution
- No testflight releases or paid versions are officially supported
- The project is distributed as-is with no warranties
- Users should be aware of potential security implications when using third-party applications that access Bilibili's services

## Development Conventions

- Swift naming conventions and Apple's iOS/tvOS development guidelines are followed
- Error handling is implemented where appropriate using Swift's error handling mechanisms
- The codebase follows a model-view-controller (MVC) pattern with some view model components
- Network requests are handled asynchronously
- Memory management follows ARC conventions with proper weak/unowned references where needed