# Changelog

All notable changes to iOSAdsDebugKit. Versioning and release rules:
`iOS-base/docs/BASE_RELEASE_AND_UPGRADE.md`. Changes before this file was added are only in the
git history (latest tag at that time: `v2.0.1`).

## [Unreleased]

## [3.0.0] - 2026-10-14

First release under the versioned release process. Covers everything since `v2.0.1`.

### Added
- Runtime debug value overrides: `AdDebugValue`, `AdDebugValueDefinition`, `AdDebugValueOption`,
  `setDebugValueOverride(_:forKey:)`, `debugValueOverride(forKey:)`, `resolveDebugValue(_:forKey:)`
  for `Bool`/`Int`/`Double`/`String`, and `AdTelemetryConfiguration(debugValues:)` (defaults to
  none, so existing initializers still compile).
- SwiftUI debug combo unlock modifier.
- Ad ID override info dialog; cycle mode help highlight.

### Changed
- **Breaking:** `MotionShakeDetector.stop()` is no longer public; the detector manages its own
  motion updates.
- Debug panel background stays below the status area, which is dimmed behind the panel.
- Event list keeps its scroll position on reload; settings action sheet is anchored on iPad.

### Fixed
- Fullscreen show impression counts are deduplicated.
- SwiftUI combo unlock receives touches directly.
