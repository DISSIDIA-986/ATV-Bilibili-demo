# Agent Rules Imports
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/code-analysis.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/implement-task.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/bug-fix.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/commit.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/context-prime.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/clean.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/check.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/continuous-improvement.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/pr-review.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/analyze-issue.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/create-docs.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/update-docs.mdc
@import /Users/niuyp/Documents/github.com/agent-rules/project-rules/mermaid.mdc

---

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BiliBili tvOS Client Demo - A unofficial BiliBili client for Apple TV platform built with Swift and UIKit. The app provides core video streaming functionality including login, video browsing, live streaming, and casting support.

## Development Commands

### Building
- **Xcode**: Open `BilibiliLive.xcodeproj` and build using Xcode for simulator or device
- **Fastlane (iOS Simulator)**: `bundle exec fastlane build_simulator`
- **Fastlane (Unsigned IPA)**: `bundle exec fastlane build_unsign_ipa`

### Code Formatting
- **Swift Format**: Integrated as build phase - runs automatically during build
- **Manual Format**: `cd BuildTools && swift run swiftformat --disable unusedArguments,numberFormatting,redundantReturn,andOperator,anyObjectProtocol,trailingClosures,redundantFileprivate --ranges nospace --swiftversion 5 ../`

### Dependencies
- **Swift Package Manager**: Dependencies managed through Xcode project
- **Fastlane**: `bundle install` to install Ruby dependencies

## Architecture

### Core Structure
- **AppDelegate.swift**: Main app entry point, handles login state and navigation setup
- **BLTabBarViewController**: Main tab navigation controller
- **LoginViewController**: QR code login flow

### Key Modules
- **Request/**: Network layer with Alamofire-based API client
  - `WebRequest.swift`: Main HTTP client with BiliBili API endpoints
  - `ApiRequest.swift`: Authentication and user-specific requests
  - `CookieManager.swift`: Session management
- **Component/**: Reusable UI components
  - `Feed/`: Video feed views and collection controllers
  - `Player/`: Video player with plugin architecture
  - `Video/`: Video detail views and danmu (comment) system
- **Module/**: Feature modules
  - `Live/`: Live streaming functionality
  - `Personal/`: User profile and history
  - `DLNA/`: UPnP/DLNA casting support
- **Vendor/**: Third-party libraries and custom implementations
  - `DanmakuKit/`: Custom danmu (bullet comment) rendering system

### Dependencies Used
- **Alamofire**: HTTP networking
- **SwiftyJSON**: JSON parsing
- **SnapKit**: Auto Layout DSL
- **Kingfisher**: Image loading and caching
- **CocoaLumberjack**: Logging framework
- **SwiftProtobuf**: Protocol buffers for danmu data
- **PocketSVG**: SVG rendering
- **MarqueeLabel**: Scrolling text labels

### tvOS-Specific Features
- Remote control navigation optimized for Apple TV
- Focus engine integration
- System video player with custom overlay UI
- Cloud casting protocol support ("云视听小电视投屏")
- HDR video playback support

### Development Notes
- Target platform: tvOS 16.0+
- SwiftFormat runs as build phase with custom configuration
- Uses file system synchronized groups for modern Xcode project management
- Supports both simulator and device builds through Fastlane