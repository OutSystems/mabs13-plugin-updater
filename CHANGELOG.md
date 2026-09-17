# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `--verify`: loads the generated manifest with `swift package dump-package` and builds the
  package for iOS with `xcodebuild`, so an unsatisfiable platform, an invalid module name or a
  source file that does not compile outside the app target is caught here instead of in a MABS 13
  build. A failing step exits non-zero; where Xcode is unavailable the build step is skipped with
  a warning.
- `--min-ios <version>`: sets the minimum iOS version of the generated `Package.swift` explicitly.
  A version lower than what the plugin or its dependencies require is raised, with a warning.
- The iOS deployment target is now derived rather than fixed. The floor is the highest of: the
  MABS 13 minimum, a `deployment-target` / `IPHONEOS_DEPLOYMENT_TARGET` preference in `plugin.xml`,
  the `platforms:` block of each resolved dependency's own `Package.swift`, and `platforms.ios`
  from each podspec. The chosen version is logged with the reasons for it.

### Fixed

- The generated manifest declared `platforms: [.iOS(.v14)]`, below what MABS 13 accepts — Xcode 26
  and later reject anything under iOS 15 during project validation. The default is now iOS 15.
- The SPM target took its name from the plugin id, which is dotted and so not a valid Swift module
  name. The package and product keep the id, which is how Cordova iOS 8 references the plugin, and
  the target is now named after the plugin's iOS class (`<param name="ios-package">`, falling back
  to the `<feature>` name and then to the id).
- The conditional Cordova import was only injected into `src/ios`, silently doing nothing for a
  plugin that keeps its iOS sources elsewhere. The directories now come from the plugin's own
  `<source-file>` declarations, with `src/ios` as the fallback.
- Swift files that use Foundation types without importing Foundation now get the import. A
  CocoaPods build inherits it from the app target's bridging header; a Swift package has none, so
  the same file failed with `cannot find 'Data' in scope` under MABS 13.

### Changed

- Renamed the tool from `cdv2spm` to `mabs13-plugin-update`. The new name uses OutSystems'
  own product vocabulary and scopes the tool to the MABS version that requires the change,
  rather than leading with a third-party trademark. The binary, Swift package, product,
  target, module, and source directory names all change; the Swift module is
  `MABS13PluginUpdate`.
- Release artifacts are now named `mabs13-plugin-update-<tag>-macos.zip`.
- The README and `--help` output now state the tool's scope: it updates Cordova plugins to
  Cordova iOS 8 for MABS 13 compatibility, and no action is needed for Capacitor plugins.

If you installed a previous version with `make install`, remove the old binary with
`sudo rm /usr/local/bin/cdv2spm` before running `make install` again.

## [1.3.0] - 2026-05-27

### Added

- `<resource-file>` support: resource files are now parsed and emitted as SPM `resources`,
  using `.copy` for `.bundle` directories and `.process` for other files
- System library linking: `<framework src="libsqlite3.dylib"/>` and `<framework src="libxml2.tbd"/>`
  now correctly map to `.linkedLibrary("sqlite3")` / `.linkedLibrary("xml2")` instead of being
  emitted as `.linkedFramework` with the full filename

## [1.2.0] - 2026-04-22

### Added

- Cordova plugin dependency support: top-level `<dependency>` elements in `plugin.xml` are now
  parsed and can be resolved to SPM packages when `--auto-resolve` is used
- Both `url=` and `path=` attributes are accepted on `<dependency>` elements
- URL fragments (`#branch` or `#tag`) are automatically classified: fragments starting with a digit
  or 'v' followed by a digit are treated as tags (e.g. `#1.0.2`, `#v2.0.0`); anything else is
  treated as a branch name (e.g. `#spm`, `#main`)
- Without `--auto-resolve`, plugin dependencies are emitted as `// TODO:` comments with a hint to
  run `--auto-resolve`
- 27 new unit tests covering `<dependency>` parsing, branch/tag classification, the full
  SecureSQLiteBundle scenario, `CordovaPluginDependency` model behavior, and Package.swift
  generation with resolved/unresolved plugin dependencies

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

[Unreleased]: https://github.com/OutSystems/mabs13-plugin-updater/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/OutSystems/mabs13-plugin-updater/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/OutSystems/mabs13-plugin-updater/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/OutSystems/mabs13-plugin-updater/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/OutSystems/mabs13-plugin-updater/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/OutSystems/mabs13-plugin-updater/releases/tag/v1.0.0
