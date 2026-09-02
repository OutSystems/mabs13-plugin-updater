# mabs13-plugin-update

[![CI](https://github.com/OutSystems/cordova-plugin-converter/actions/workflows/ci.yml/badge.svg)](https://github.com/OutSystems/cordova-plugin-converter/actions/workflows/ci.yml)

Updates Cordova plugins to Cordova iOS 8 for MABS 13 compatibility. **No action is needed for Capacitor plugins.**

Maintained by OutSystems.

## Do you need this?

Only if you maintain a **Cordova** plugin that has an iOS platform.

MABS 13 uses Cordova iOS 8, which builds a plugin's iOS code as a Swift package rather than through CocoaPods. A plugin that declares its native iOS dependencies in a `<podspec>` needs a `Package.swift` before it will build. This tool generates that manifest and makes the matching changes to `plugin.xml`, while leaving the plugin's existing CocoaPods build path intact — so the updated plugin still builds on earlier MABS versions.

If your plugin is a **Capacitor** plugin, it is unaffected and you do not need this tool.

> **Note:** This is an independent project. It is not affiliated with, endorsed by, or sponsored by The Apache Software Foundation. See [Trademarks](#trademarks).

## Example

**Input — `plugin.xml`**
```xml
<plugin id="com.example.myplugin" version="1.0.0">
    <platform name="ios">
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
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "com.example.myplugin", targets: ["com.example.myplugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apache/cordova-ios.git", branch: "master"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.0.0"))
    ],
    targets: [
        .target(
            name: "com.example.myplugin",
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
- Injects `#if canImport(Cordova)` guards into Swift source files
- Updates `.gitignore` with SPM build artifacts

## Installation

### Build from source

```bash
git clone https://github.com/OutSystems/cordova-plugin-converter.git
cd cordova-plugin-converter
make install
```

## Usage

```bash
# Update the plugin in the current directory
mabs13-plugin-update

# Update, resolving CocoaPods dependencies to SPM automatically
mabs13-plugin-update --auto-resolve

# Preview changes without writing files
mabs13-plugin-update --dry-run --verbose

# Update a plugin elsewhere
mabs13-plugin-update path/to/plugin.xml
```

### Options

| Flag | Description |
| --- | --- |
| `--auto-resolve` | Automatically convert CocoaPods dependencies to SPM equivalents |
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

If a dependency cannot be resolved automatically, it is added as a `// TODO:` comment in `Package.swift` for manual conversion.

## Trademarks

Apache, Apache Cordova, and Cordova are trademarks or registered trademarks of The Apache Software Foundation in the United States and/or other countries.

This project is an independent work and is not affiliated with, endorsed by, or sponsored by The Apache Software Foundation. References to Apache Cordova in this repository are for identification purposes only — to describe the software this tool operates on — and do not imply any endorsement or association.

All other trademarks are the property of their respective owners.

## License

MIT — see [LICENSE](LICENSE).
