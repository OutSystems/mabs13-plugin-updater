# cdv2spm

[![CI](https://github.com/OutSystems/cordova-plugin-converter/actions/workflows/ci.yml/badge.svg)](https://github.com/OutSystems/cordova-plugin-converter/actions/workflows/ci.yml)

`cdv2spm` converts a Cordova `plugin.xml` into a Swift Package Manager `Package.swift`, automating the migration from CocoaPods to SPM for iOS Cordova plugins.

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
# Convert plugin.xml in current directory
cdv2spm

# Convert with automatic CocoaPods → SPM resolution
cdv2spm --auto-resolve

# Preview changes without writing files
cdv2spm --dry-run --verbose

# Convert a specific file
cdv2spm path/to/plugin.xml
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
