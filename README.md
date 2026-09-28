# mabs13-plugin-update

[![CI](https://github.com/OutSystems/mabs13-plugin-updater/actions/workflows/ci.yml/badge.svg)](https://github.com/OutSystems/mabs13-plugin-updater/actions/workflows/ci.yml)

Updates Cordova plugins to Cordova iOS 8 for MABS 13 compatibility. **No action is needed for Capacitor plugins.**

Maintained by OutSystems.

## Do you need this?

Only if you maintain a **Cordova** plugin that has an iOS platform.

MABS 13 uses Cordova iOS 8, which builds a plugin's iOS code as a Swift package rather than through CocoaPods. A plugin that declares its native iOS dependencies in a `<podspec>` needs a `Package.swift` before it will build. This tool generates that manifest and makes the matching changes to `plugin.xml`, while leaving the plugin's existing CocoaPods build path intact — so the updated plugin still builds on earlier MABS versions.

If your plugin is a **Capacitor** plugin, it is unaffected and you do not need this tool.

> **Note:** This is an independent project. It is not affiliated with, endorsed by, or sponsored by The Apache Software Foundation. See [Trademarks](#trademarks).

## Scope

This tool automates one mechanical part of a MABS 13 upgrade: making the plugin's iOS code buildable as a Swift package.

**In scope**

- Generating `Package.swift` from the dependencies declared in `<podspec>`
- Choosing the manifest's minimum iOS version from what the plugin and its dependencies require
- The corresponding `plugin.xml` changes (`package="swift"`, `nospm="true"`)
- Adding `#if canImport(Cordova)` guards so sources still compile on older MABS versions
- Adding `import Foundation` to sources that relied on the app target's bridging header for it
- `.gitignore` entries for SPM build artifacts
- With `--verify`, checking that the generated package loads and compiles for iOS

**Out of scope**

- **Breaking changes in your native source.** Cordova iOS 8 changes and removes platform APIs. The tool does not read your Objective-C or Swift for uses of them, and will not tell you about them.
- **Proving the plugin works.** `--verify` compiles the generated package; it does not run the plugin. You still need to build it into an app on MABS 13 and exercise it.
- **Dependencies with no SPM equivalent.** `--auto-resolve` leaves these as `// TODO:` comments for you to resolve by hand.
- **Android.** The tool touches the iOS platform only. A plugin whose `plugin.xml` declares no `<platform name="ios">` is refused before anything is written, since it needs no change for MABS 13.

Treat a successful run as the starting point for the upgrade, not the end of it.

## Example

**Input — `plugin.xml`**
```xml
<plugin id="com.example.myplugin" version="1.0.0">
    <platform name="ios">
        <config-file parent="/*" target="config.xml">
            <feature name="MyPlugin">
                <param name="ios-package" value="MyPlugin"/>
            </feature>
        </config-file>
        <podspec>
            <pods>
                <pod name="Alamofire" spec="~> 5.0"/>
            </pods>
        </podspec>
    </platform>
</plugin>
```

**Output — `Package.swift`** (with `--auto-resolve`)
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "com.example.myplugin",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "com.example.myplugin", targets: ["MyPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apache/cordova-ios.git", branch: "master"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.0.0"))
    ],
    targets: [
        .target(
            name: "MyPlugin",
            dependencies: [
                .product(name: "Cordova", package: "cordova-ios"),
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "src/ios")
    ]
)
```

The tool also:

- Adds `package="swift"` to the iOS platform in `plugin.xml`
- Adds `nospm="true"` to `<pod>` elements to preserve CocoaPods compatibility
- Injects `#if canImport(Cordova)` guards into the Swift files of the plugin's declared iOS
  source directories
- Adds `import Foundation` to Swift files that need it — a Swift package has no bridging header
  to provide it implicitly, unlike a CocoaPods build
- Names the target after the plugin's iOS class, keeping the plugin id as the product name
- Raises the minimum iOS version when the plugin or a dependency requires more than the MABS 13
  floor of iOS 15
- Updates `.gitignore` with SPM build artifacts

## Installation

### Build from source

```bash
git clone https://github.com/OutSystems/mabs13-plugin-updater.git
cd mabs13-plugin-updater
make install
```

## Usage

```bash
# Update the plugin in the current directory
mabs13-plugin-update

# Update, resolving CocoaPods dependencies to SPM automatically
mabs13-plugin-update --auto-resolve

# Update, then check the generated package actually builds for iOS
mabs13-plugin-update --auto-resolve --verify

# Preview changes without writing files
mabs13-plugin-update --dry-run --verbose

# Update a plugin elsewhere
mabs13-plugin-update path/to/plugin.xml
```

### Options

| Flag | Description |
| --- | --- |
| `--auto-resolve` | Automatically convert CocoaPods dependencies to SPM equivalents |
| `--min-ios <version>` | Minimum iOS version for the generated `Package.swift` (defaults to `15.0`) |
| `--verify` | Load the generated manifest and build the package for iOS (needs Xcode) |
| `--dry-run` | Preview changes without modifying files |
| `--force` | Skip all confirmation prompts |
| `--verbose` | Enable detailed logging output |
| `--no-gitignore` | Skip `.gitignore` updates |
| `--backup` | Create backups of modified files |

## How auto-resolve works

When `--auto-resolve` is used, the tool looks up each CocoaPods dependency and:

1. Fetches the podspec via `pod spec cat`
2. Finds the Git source URL and version tag
3. Checks if the repository contains a `Package.swift`
4. Converts the CocoaPods version spec to the SPM equivalent
5. Reads the dependency's own minimum iOS version, from its `Package.swift` and its podspec, and
   raises the generated manifest's platform to match

If a dependency cannot be resolved automatically, it is added as a `// TODO:` comment in `Package.swift` for manual conversion.

## How the minimum iOS version is chosen

The generated `platforms:` entry is the highest of:

- iOS 15, the lowest a Swift package can declare. Xcode 27, the toolchain MABS 13 builds with,
  rejects anything below it during validation. (Xcode 26 applies the same rule to applications but
  not to packages, which is why this did not affect MABS 12.)
- a `deployment-target` or `IPHONEOS_DEPLOYMENT_TARGET` preference in the plugin's iOS platform
- the minimum declared by each resolved dependency (with `--auto-resolve`)
- `--min-ios`, when given

Run with `--verbose` to see which of these set the version. A `--min-ios` lower than what is
required is raised, with a warning.

Nothing here lowers the result, including `--min-ios`. A dependency that requires more than a
MABS 13 application's own deployment target (iOS 16) still sets the manifest's floor, and the tool
warns instead of capping: capping would emit a manifest that cannot resolve, and the application's
target can itself be raised from a Cordova hook. If you see that warning and no hook raises the
target, the dependency version is the thing to change.

## Trademarks

Apache, Apache Cordova, and Cordova are trademarks or registered trademarks of The Apache Software Foundation in the United States and/or other countries.

This project is an independent work and is not affiliated with, endorsed by, or sponsored by The Apache Software Foundation. References to Apache Cordova in this repository are for identification purposes only — to describe the software this tool operates on — and do not imply any endorsement or association.

All other trademarks are the property of their respective owners.

## License

MIT — see [LICENSE](LICENSE).
