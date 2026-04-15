import ArgumentParser
import Foundation

@main
struct Cdv2spm: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cdv2spm",
        abstract: "Cordova plugin.xml to Swift Package Manager converter",
        discussion: """
        A Swift command-line tool that converts Cordova plugin.xml files to Swift Package Manager
        Package.swift format, facilitating the migration from CocoaPods to Swift Package Manager
        for iOS Cordova plugins.
        """,
        version: "1.0.0"
    )

    @Flag(name: .long, help: "Skip all confirmation prompts")
    var force = false

    @Flag(name: .long, help: "Preview changes without writing files")
    var dryRun = false

    @Flag(name: .long, help: "Enable verbose logging")
    var verbose = false

    @Flag(name: .long, help: "Skip .gitignore updates")
    var noGitignore = false

    @Flag(name: .long, help: "Create backup files before modifying")
    var backup = false

    @Flag(name: .long, help: "Automatically resolve CocoaPods to SPM dependencies")
    var autoResolve = false

    @Argument(help: "Path to plugin.xml file (defaults to ./plugin.xml)")
    var pluginXmlPath: String?

    func run() async throws {
        let options = ConversionOptions(
            force: force,
            dryRun: dryRun,
            verbose: verbose,
            noGitignore: noGitignore,
            backup: backup,
            autoResolve: autoResolve,
            inputPath: pluginXmlPath
        )

        let converter = CordovaToSPMConverter(options: options)
        let success = await converter.convert()

        if !success {
            throw ExitCode.failure
        }
    }
}
