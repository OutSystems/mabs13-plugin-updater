# cdv2spm - Cordova Plugin to Swift Package Manager Converter

[![CI](https://github.com/andredestro/cordova-plugin-converter/actions/workflows/ci.yml/badge.svg)](https://github.com/andredestro/cordova-plugin-converter/actions/workflows/ci.yml)

A Swift command-line tool that converts Cordova `plugin.xml` files to Swift Package Manager `Package.swift` format, facilitating the migration from CocoaPods to Swift Package Manager for iOS Cordova plugins.

## Features

- 📦 **Package.swift Generation**: Creates properly structured Swift Package Manager manifests
- 🤖 **Auto-Resolve Dependencies**: Automatically converts CocoaPods to Swift Package Manager equivalents
- ⚙️ **Automatic iOS Platform Updates**: Adds `package="swift"` to iOS platform
- 🙈 **Gitignore Updates**: Adds Swift Package Manager build artifacts to `.gitignore`
- 🎨 **Colorized Output**: Beautiful, colored terminal output with different log levels
- 🔧 **Interactive Mode**: Prompts for confirmation before making changes
- 🏃‍♂️ **Dry Run Mode**: Preview changes without modifying files
- 📁 **Conditional Backup Creation**: Creates backups when using `--backup` flag
- ✅ **Comprehensive Testing**: Full test coverage for all major components

## Installation

### Using Make (Recommended)

```bash
# Clone the repository
git clone https://github.com/andredestro/cordova-plugin-converter.git
cd cordova-plugin-converter

# Build and install
make install
```

This will install the `cdv2spm` binary to `/usr/local/bin`.

### Manual Installation

```bash
# Build the project
swift build -c release

# Copy binary to your PATH
cp .build/release/cdv2spm /usr/local/bin/
```

### Running from Build Directory

```bash
# Build and run directly
swift build
.build/debug/cdv2spm --help
```

## Usage

### Basic Usage

```bash
# Convert plugin.xml in current directory
cdv2spm

# Convert specific plugin.xml file
cdv2spm /path/to/plugin.xml

# Preview changes without modifying files
cdv2spm --dry-run --verbose

# Force conversion without prompts
cdv2spm --force

# Skip .gitignore updates
cdv2spm --no-gitignore
```

### Command Line Options

- `--force`: Skip all confirmation prompts
- `--dry-run`: Preview changes without writing files
- `--verbose`: Enable detailed logging output
- `--no-gitignore`: Skip .gitignore updates
- `--backup`: Create backups of modified files
- `--auto-resolve`: Automatically resolve CocoaPods to SPM dependencies
- `--help`, `-h`: Show help message

### Examples

**Convert a plugin with CocoaPods dependencies:**
```bash
cdv2spm path/to/plugin.xml --verbose
```

**Convert with backup creation:**
```bash
cdv2spm path/to/plugin.xml --backup --verbose
```

**Preview conversion for multiple plugins:**
```bash
find . -name "plugin.xml" -exec cdv2spm --dry-run {} \;
```

**Automated conversion in CI/CD:**
```bash
cdv2spm --force --no-gitignore plugin.xml
```

**Automatic dependency resolution:**
```bash
cdv2spm --auto-resolve --verbose plugin.xml
```

## What It Does

1. **Parses plugin.xml**: Extracts plugin ID and CocoaPods dependencies (iOS platform only)
2. **Auto-resolves dependencies** (with `--auto-resolve`): Automatically converts CocoaPods to SPM equivalents when possible
3. **Generates Package.swift**: Creates a properly structured Swift Package Manager manifest
4. **Updates plugin.xml**: Always adds `package="swift"` to iOS platform, optionally removes `<podspec>` sections
5. **Updates .gitignore**: Adds `.build/`, `.swiftpm/`, and `Package.resolved` entries (after plugin.xml update)
6. **Creates backups**: Conditionally backs up files when `--backup` flag is used

## Automatic CocoaPods Resolution

When using the `--auto-resolve` flag, the tool attempts to automatically convert CocoaPods dependencies to their Swift Package Manager equivalents by:

1. **Fetching pod specifications**: Uses `pod spec cat <pod_name> --version=<version>` to get pod metadata
2. **Extracting Git repository information**: Finds the source Git URL and tag/branch from the podspec
3. **Checking for Package.swift**: Verifies if the Git repository contains a `Package.swift` file
4. **Parsing Swift package information**: Extracts library name and dependency details
5. **Converting version requirements**: Translates CocoaPods version syntax to SPM equivalents

### Resolution Process

The tool follows this process for each CocoaPods dependency:

```
CocoaPods dependency → pod spec cat → Git repository → Package.swift → SPM dependency
```

**Success criteria:**
- Pod specification is accessible via CocoaPods
- Pod has a Git source repository
- Repository contains a valid `Package.swift` file
- Package.swift defines a library product (not just executable)

**Fallback behavior:**
- If automatic resolution fails, generates TODO comments for manual conversion
- Provides detailed status information for each dependency
- Continues processing other dependencies even if some fail

## Input/Output Example

### Input: plugin.xml
```xml
<plugin id="com.example.myplugin" version="1.0.0">
    <platform name="ios">
        <podspec>
            <pods>
                <pod name="AFNetworking" spec="~> 4.0"/>
                <pod name="SDWebImage" spec="~> 5.0"/>
            </pods>
        </podspec>
    </platform>
</plugin>
```

### Output: Package.swift (Traditional)
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "com.example.myplugin",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "com.example.myplugin",
            targets: ["com.example.myplugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apache/cordova-ios.git", branch: "master"),
        // TODO: Convert CocoaPods dependency: AFNetworking (~> 4.0)
        // TODO: Convert CocoaPods dependency: SDWebImage (~> 5.0)
    ],
    targets: [
        .target(
            name: "com.example.myplugin",
            dependencies: [
                .product(name: "Cordova", package: "cordova-ios"),
                // TODO: Add Swift Package equivalent for: AFNetworking (~> 4.0)
                // TODO: Add Swift Package equivalent for: SDWebImage (~> 5.0)
            ],
            path: "src/ios")
    ]
)
```

### Output: Package.swift (with `--auto-resolve`)
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "com.example.myplugin",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "com.example.myplugin",
            targets: ["com.example.myplugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apache/cordova-ios.git", branch: "master"),
        .package(url: "https://github.com/AFNetworking/AFNetworking.git", .upToNextMajor(from: "4.0")),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", .upToNextMajor(from: "5.0"))
    ],
    targets: [
        .target(
            name: "com.example.myplugin",
            dependencies: [
                .product(name: "Cordova", package: "cordova-ios"),
                .product(name: "AFNetworking", package: "AFNetworking"),
                .product(name: "SDWebImage", package: "SDWebImage")
            ],
            path: "src/ios")
    ]
)
```

## Architecture

The tool is built with a modular, well-tested architecture:

### Core Components

- **Models**: Data structures for plugin metadata and configuration
- **XMLParser**: Robust XML parsing using SWXMLHash
- **PackageGenerator**: Swift Package Manager manifest generation
- **CLI**: Command-line interface with colorized logging
- **FileSystemManager**: Safe file operations with dry-run support
- **Converter**: Main orchestration class

### Key Features

- **Error Handling**: Comprehensive error types with descriptive messages
- **Logging**: Multi-level logging with ANSI colors
- **Testing**: Full unit test coverage for all components
- **Safety**: Backup creation and dry-run mode prevent data loss

## Development

### Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later (for iOS development)

### Building

```bash
# Build the project
make build

# Run tests
make test

# Run tests with verbose Swift output
swift test --verbose
```

### Code Quality

```bash
# Lint code (requires swiftlint)
make lint

# Format code (requires swiftformat)
make format

# Generate Xcode project
make xcode
```

### Development Dependencies

Optional tools for development:

```bash
# Install SwiftLint for code linting
brew install swiftlint

# Install SwiftFormat for code formatting
brew install swiftformat
```

### Testing

The project includes comprehensive unit tests (**115 tests** covering all major components):

```bash
# Run all tests
swift test

# Run specific test file
swift test --filter XMLParserBasicTests

# Run with verbose output
swift test --verbose
```

### Available Make Targets

Run `make help` to see all available targets:

- `build` - Build in release mode
- `test` - Run all tests
- `install` - Install to system PATH
- `uninstall` - Remove installed binary
- `clean` - Clean build artifacts
- `lint` - Run SwiftLint
- `format` - Format code with SwiftFormat
- `xcode` - Open project in Xcode
- `resolve` - Resolve package dependencies
- `update` - Update package dependencies

## Dependencies

- [ArgumentParser](https://github.com/apple/swift-argument-parser) - Command-line argument parsing
- [SWXMLHash](https://github.com/drmohundro/SWXMLHash) - XML parsing library

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
