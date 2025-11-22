# Repository Guidelines

## Project Structure & Modules
- `BilibiliLive/`: main tvOS client code. Key folders: `Module/` (feature flows such as Live, DLNA, Personal), `Component/` (reusable views and cells), `Request/` (API/WBI signing, cookies, protobuf models), `Extensions/` and `Vendor/` (helpers and bundled libs). Localizations and assets live in `Supporting Files/` (`Assets.xcassets`, `Base.lproj`, `zh-Hans.lproj`).
- `BuildTools/`: SwiftPM package that pins SwiftFormat; run formatting from here.
- `fastlane/`: lanes for simulator builds and unsigned IPA packaging.
- `imgs/`: demo screenshots used by the README.

## Build, Test, and Development Commands
- Open `BilibiliLive.xcodeproj` and run the `BilibiliLive` target on Apple TV hardware or simulator for interactive development.
- CI-style check: `bash Scripts/ci-build.sh` to run a headless build validation.
- Alternative CI command: `xcodebuild -scheme BilibiliLive -destination 'platform=tvOS Simulator,name=Apple TV' clean build` to ensure the target still builds headlessly.
- Simulator build via Fastlane: `bundle exec fastlane tvos build_simulator` (skips archiving/IPA).
- Unsigned release IPA: `bundle exec fastlane tvos build_unsign_ipa` (archives, zips `Payload/`, skips codesign; outputs `BilbiliAtvDemo.ipa` in repo root).
- Format Swift: `cd BuildTools && swift run -c release swiftformat ../BilibiliLive`.

## Coding Style & Naming Conventions
- Swift 5.x, 4-space indentation, trailing commas where SwiftFormat allows. Prefer `final` when applicable.
- Types use PascalCase; methods/properties/locals use lowerCamelCase; constants follow `static let` patterns (`Keys.userAgent`, etc.).
- Keep view logic lean; move networking and decoding into `Request/`, reusable UI into `Component/`, and feature-specific code under `Module/`.

## Testing Guidelines
- No unit test target is present; rely on simulator/hardware verification.
- Before opening a PR, run a simulator build and sanity-test core flows: QR login, feed playback with danmaku, search, and DLNA/cast where relevant.
- Note any device-specific findings (tvOS version, hardware vs. simulator) in the PR.

## Commit & Pull Request Guidelines
- Follow existing history: `feat: …`, `fix: …`, `build(deps): …` with concise verbs; include issue/PR number in parentheses when applicable (e.g., `fix: adjust playback overlay (#165)`).
- PRs should include: a short summary, screenshots or screen captures for UI changes, repro steps for bug fixes, and what was tested (command + environment).
- Avoid committing credentials, cookies, or personal playback history; scrub any captured logs or config before pushing.
