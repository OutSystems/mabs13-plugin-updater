# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-04-17

### Added

- Native Obj-C/C source file support: `<source-file compiler-flags="...">` entries are now parsed
  and emitted as SPM `cSettings` (`.define`, `.defineWithValue`, `.headerSearchPath`)
- System framework linking: `<framework src="Security.framework"/>` generates `linkerSettings`
  with `.linkedFramework("Security")` in the target
- Header file support: `<header-file>` paths are parsed and used to derive `publicHeadersPath`
  and additional `.headerSearchPath` cSettings entries
- Multi-directory source layout: when native sources span multiple directories (e.g. `src/ios`
  and `src/common`), the common ancestor is used as `path:` and explicit `sources:` are listed
- `CompilerFlagsParser` utility to convert raw `-D` compiler flag strings into typed
  `CCompilerSetting` values, with deduplication across multiple source files
- 47 new unit tests covering compiler flag parsing, native source layout, system framework
  parsing, header file handling, and end-to-end SQLCipher-like plugin scenarios

### Fixed

- Hybrid plugins (both CocoaPods dependencies and native source files) now display both sections
  in the conversion summary instead of only showing the CocoaPods section
- `isNativeOnly` now correctly reflects plugins with no real pod dependencies even when the
  `<podspec>` element is present but contains no `<pod>` children
- Duplicate native source files with different compiler flags no longer create duplicate entries
  in the `sources:` list; deduplication is based on file path only

## [1.0.1] - 2026-04-17

### Fixed

- Multi-product SPM packages (e.g. `firebase-ios-sdk`) now resolve to the correct product name
  matching the CocoaPod name (e.g. `FirebaseMessaging`) instead of always picking the first
  product listed in the remote `Package.swift` (e.g. `Firebase`)
- Package identifier in `.product(name:package:)` is now derived from the repository URL
  (e.g. `firebase-ios-sdk`) instead of the `name:` field declared inside `Package.swift`
  (e.g. `Firebase`), matching how SPM identifies URL-based packages
- `SPMPackageParser` failed to extract any products from `Package.swift` files that declare
  multiple library products; the section regex incorrectly consumed opening brackets of nested
  arrays (e.g. `targets: ["Foo"]`), causing product extraction to return empty

## [1.0.0] - 2026-04-15

### Added
- `Package.swift` generation from Cordova `plugin.xml`
- Automatic CocoaPods → SPM dependency resolution via `--auto-resolve` flag
- Support for pods with `git`/`tag`/`branch` attributes (bypasses CocoaPods registry)
- Support for local `.xcframework` bundles as SPM binary targets
- Automatic `package="swift"` injection into iOS platform in `plugin.xml`
- `nospm="true"` attribute added to `<pod>` elements to preserve CocoaPods compatibility
- Automatic Cordova import injection (`#if canImport(Cordova)`) into Swift source files
- Cordova variable substitution in pod specs (e.g. `$MY_VERSION` → preference default)
- CocoaPods version spec conversion to SPM requirements (`~>`, `>=`, `=`, `>`, `<`)
- HTTP source dependency resolution with Git URL inference from GitHub releases and homepage
- GitLab repository support for Package.swift detection and fetching
- Dry-run mode (`--dry-run`) to preview changes without writing files
- Interactive confirmation prompts with `--force` flag to skip them
- Optional backup creation (`--backup`) for modified files
- `.gitignore` update with SPM build artifacts (skippable via `--no-gitignore`)
- Colorized terminal output with multiple log levels
- GitHub Actions CI workflow (build, test, SwiftLint)
- GitHub Actions release workflow producing a universal macOS binary (arm64 + x86_64)
- 115 unit tests covering all major components

[Unreleased]: https://github.com/andredestro/cordova-plugin-converter/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/andredestro/cordova-plugin-converter/releases/tag/v1.0.0
