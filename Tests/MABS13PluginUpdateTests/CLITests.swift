import XCTest
@testable import MABS13PluginUpdate

final class CLITests: XCTestCase {
    func testANSIColorize() {
        let text = "Hello World"
        let colorized = ANSIColor.red.colorize(text)

        XCTAssertTrue(colorized.hasPrefix("\u{001B}[31m"))
        XCTAssertTrue(colorized.hasSuffix("\u{001B}[0m"))
        XCTAssertTrue(colorized.contains(text))
    }

    func testLogLevelColors() {
        XCTAssertEqual(LogLevel.debug.color, .magenta)
        XCTAssertEqual(LogLevel.info.color, .cyan)
        XCTAssertEqual(LogLevel.warn.color, .yellow)
        XCTAssertEqual(LogLevel.error.color, .red)
        XCTAssertEqual(LogLevel.success.color, .green)
    }

    func testLogLevelPrefixes() {
        XCTAssertEqual(LogLevel.debug.prefix, "[DEBUG]")
        XCTAssertEqual(LogLevel.info.prefix, "[INFO]")
        XCTAssertEqual(LogLevel.warn.prefix, "[WARN]")
        XCTAssertEqual(LogLevel.error.prefix, "[ERROR]")
        XCTAssertEqual(LogLevel.success.prefix, "[SUCCESS]")
    }

    func testLoggerVerboseMode() {
        // Test that logger respects verbose mode for debug messages
        let verboseLogger = Logger(verbose: true, noColor: true)
        let nonVerboseLogger = Logger(verbose: false, noColor: true)

        // We can't easily test console output, but we can test the constructor
        XCTAssertNotNil(verboseLogger)
        XCTAssertNotNil(nonVerboseLogger)
    }

    func testUserInteractionForceMode() {
        let logger = Logger(verbose: false, noColor: true)
        let interaction = UserInteraction(force: true, logger: logger)

        // In force mode, should always return true without prompting
        let result = interaction.confirmAction("Test confirmation")
        XCTAssertTrue(result)
    }

    func testStringPathExtensions() {
        let fullPath = "/Users/test/Documents/plugin.xml"

        XCTAssertEqual(fullPath.directoryPath, "/Users/test/Documents")

        let appendedPath = "/base/path".appendingPathComponent("file.txt")
        XCTAssertEqual(appendedPath, "/base/path/file.txt")
    }

    func testLogLevelAllCases() {
        let allLevels = LogLevel.allCases
        XCTAssertEqual(allLevels.count, 5)
        XCTAssertTrue(allLevels.contains(.debug))
        XCTAssertTrue(allLevels.contains(.info))
        XCTAssertTrue(allLevels.contains(.warn))
        XCTAssertTrue(allLevels.contains(.error))
        XCTAssertTrue(allLevels.contains(.success))
    }
    
    // MARK: - Additional Logger Tests
    
    func testLoggerVerboseDebugMessages() {
        let verboseLogger = Logger(verbose: true, noColor: true)
        let nonVerboseLogger = Logger(verbose: false, noColor: true)
        
        // Test that we can create loggers with different verbose settings
        XCTAssertNotNil(verboseLogger)
        XCTAssertNotNil(nonVerboseLogger)
        
        // We can't easily test console output, but we can test the initialization
        // In real implementation, verbose logger would show debug messages
        // while non-verbose would skip them
    }
    
    func testLoggerNoColorMode() {
        let colorLogger = Logger(verbose: false, noColor: false)
        let noColorLogger = Logger(verbose: false, noColor: true)
        
        XCTAssertNotNil(colorLogger)
        XCTAssertNotNil(noColorLogger)
        
        // Both should be created successfully
        // In practice, noColor logger would skip ANSI color codes
    }
    
    func testLoggerAllLogLevels() {
        let logger = Logger(verbose: true, noColor: true)
        
        // Test that all log methods can be called without crashing
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warn("Warning message")
        logger.error("Error message")
        logger.success("Success message")
        
        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }
    
    // MARK: - Additional UserInteraction Tests
    
    func testUserInteractionNonForceMode() {
        let logger = Logger(verbose: false, noColor: true)
        let interaction = UserInteraction(force: false, logger: logger)
        
        XCTAssertNotNil(interaction)
        
        // Note: Testing actual user input is complex in unit tests
        // In real usage, non-force mode would prompt for user input
    }
    
    func testUserInteractionPrintMethods() {
        let logger = Logger(verbose: false, noColor: true)
        let interaction = UserInteraction(force: true, logger: logger)
        
        // Test that print methods don't crash
        interaction.printSeparator()
        interaction.printSeparator("*", length: 40)
        interaction.printImportantMessage("Test important message")
        
        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }
    
    // MARK: - ANSI Color Edge Cases
    
    func testANSIColorAllColors() {
        let testText = "Test"
        
        // Test all color variants
        let redText = ANSIColor.red.colorize(testText)
        let greenText = ANSIColor.green.colorize(testText)
        let yellowText = ANSIColor.yellow.colorize(testText)
        let magentaText = ANSIColor.magenta.colorize(testText)
        let cyanText = ANSIColor.cyan.colorize(testText)
        
        // All should contain the original text
        XCTAssertTrue(redText.contains(testText))
        XCTAssertTrue(greenText.contains(testText))
        XCTAssertTrue(yellowText.contains(testText))
        XCTAssertTrue(magentaText.contains(testText))
        XCTAssertTrue(cyanText.contains(testText))
        
        // All should start with ANSI code and end with reset
        let allColorized = [redText, greenText, yellowText, magentaText, cyanText]
        for colorized in allColorized {
            XCTAssertTrue(colorized.hasPrefix("\u{001B}["))
            XCTAssertTrue(colorized.hasSuffix(ANSIColor.reset.rawValue))
        }
    }
    
    func testANSIColorEmptyString() {
        let emptyColorized = ANSIColor.red.colorize("")
        
        // Should still have color codes even with empty string
        XCTAssertTrue(emptyColorized.hasPrefix(ANSIColor.red.rawValue))
        XCTAssertTrue(emptyColorized.hasSuffix(ANSIColor.reset.rawValue))
    }
}
