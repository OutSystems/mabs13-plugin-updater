import ArgumentParser
import Foundation

@main
struct PluginUpdateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mabs13-plugin-update",
        abstract: "Updates Cordova plugins to Cordova iOS 8 for MABS 13 compatibility",
        discussion: """
        MABS 13 uses Cordova iOS 8, which builds a plugin's iOS code as a Swift package \
        rather than through CocoaPods. This tool generates the Package.swift a Cordova \
        plugin needs and makes the matching changes to plugin.xml, leaving the plugin's \
        existing CocoaPods build path intact so it still builds on earlier MABS versions.

        No action is needed for Capacitor plugins.
        """,
        version: "1.3.0"
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
