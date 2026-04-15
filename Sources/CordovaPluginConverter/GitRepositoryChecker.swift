import Foundation

/// Handles checking remote Git repositories for Package.swift files
public class GitRepositoryChecker {
    private let logger: Logger

    // MARK: - Static Regex Constants
    // Compiled once at class load time; patterns are literals and never fail.

    private static let githubPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(
            pattern: #"github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?/?$"#,
            options: .caseInsensitive
        ),
        // Short "owner/repo" format
        try! NSRegularExpression(
            pattern: #"^([^/]+)/([^/]+?)(?:\.git)?/?$"#,
            options: .caseInsensitive
        )
    ]

    // Matches any host whose name contains "gitlab" (e.g. gitlab.com, gitlab.mycompany.com)
    private static let gitlabPattern = try! NSRegularExpression(
        pattern: #"([^:/]*gitlab[^:/]*)[:/](.+?)(?:\.git)?/?$"#
    )

    public init(logger: Logger) {
        self.logger = logger
    }

    // MARK: - Public Interface

    /// Check if a Package.swift file exists in a remote Git repository at a specific tag/branch
    public func hasPackageSwift(in gitUrl: String, at reference: String = "main") async -> Bool {
        logger.debug("Checking for Package.swift in \(gitUrl) at \(reference)")

        if let githubResult = await checkGitHubRepository(gitUrl: gitUrl, reference: reference) {
            return githubResult
        }
        if let gitlabResult = await checkGitLabRepository(gitUrl: gitUrl, reference: reference) {
            return gitlabResult
        }
        return await checkRepositoryWithGit(gitUrl: gitUrl, reference: reference)
    }

    /// Fetch Package.swift content from a remote Git repository
    public func fetchPackageSwiftContent(from gitUrl: String, at reference: String = "main") async -> String? {
        logger.debug("Fetching Package.swift content from \(gitUrl) at \(reference)")

        if let content = await fetchFromGitHub(gitUrl: gitUrl, reference: reference) {
            return content
        }
        if let content = await fetchFromGitLab(gitUrl: gitUrl, reference: reference) {
            return content
        }
        return await fetchWithGit(gitUrl: gitUrl, reference: reference)
    }

    // MARK: - GitHub

    /// Builds the GitHub Contents API URL for Package.swift at a given ref.
    /// Returns nil when `gitUrl` is not a recognisable GitHub URL.
    private func githubContentsUrl(gitUrl: String, reference: String) -> String? {
        guard let (owner, repo) = parseGitHubUrl(gitUrl) else { return nil }
        let ref = reference.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? reference
        return "https://api.github.com/repos/\(owner)/\(repo)/contents/Package.swift?ref=\(ref)"
    }

    private func checkGitHubRepository(gitUrl: String, reference: String) async -> Bool? {
        guard let apiUrl = githubContentsUrl(gitUrl: gitUrl, reference: reference) else { return nil }
        return await makeHttpHeadRequest(to: apiUrl)
    }

    private func fetchFromGitHub(gitUrl: String, reference: String) async -> String? {
        guard let apiUrl = githubContentsUrl(gitUrl: gitUrl, reference: reference) else { return nil }
        return await fetchFileContentFromGitHub(apiUrl: apiUrl)
    }

    private func parseGitHubUrl(_ gitUrl: String) -> (owner: String, repo: String)? {
        let range = NSRange(gitUrl.startIndex..., in: gitUrl)
        for regex in Self.githubPatterns {
            guard let match = regex.firstMatch(in: gitUrl, range: range),
                  let ownerRange = Range(match.range(at: 1), in: gitUrl),
                  let repoRange = Range(match.range(at: 2), in: gitUrl)
            else { continue }
            return (String(gitUrl[ownerRange]), String(gitUrl[repoRange]))
        }
        return nil
    }

    private func fetchFileContentFromGitHub(apiUrl: String) async -> String? {
        guard let url = URL(string: apiUrl) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentBase64 = json["content"] as? String else { return nil }

            // GitHub API returns base64-encoded content with embedded newlines
            let cleanedBase64 = contentBase64.replacingOccurrences(of: "\n", with: "")
            guard let decodedData = Data(base64Encoded: cleanedBase64),
                  let content = String(data: decodedData, encoding: .utf8) else { return nil }

            return content
        } catch {
            logger.debug("Failed to fetch from GitHub API: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - GitLab

    /// Extracts and percent-encodes the components needed to build any GitLab API URL.
    /// Returns nil when `gitUrl` is not a recognisable GitLab URL.
    private func gitlabComponents(
        gitUrl: String,
        reference: String
    ) -> (host: String, encodedPath: String, encodedRef: String)? {
        guard let (host, projectPath) = parseGitLabUrl(gitUrl) else { return nil }
        let encodedPath = projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectPath
        let encodedRef = reference.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? reference
        return (host, encodedPath, encodedRef)
    }

    private func checkGitLabRepository(gitUrl: String, reference: String) async -> Bool? {
        guard let (host, path, ref) = gitlabComponents(gitUrl: gitUrl, reference: reference) else { return nil }
        let apiUrl = "https://\(host)/api/v4/projects/\(path)/repository/files/Package.swift?ref=\(ref)"
        return await makeHttpHeadRequest(to: apiUrl)
    }

    private func fetchFromGitLab(gitUrl: String, reference: String) async -> String? {
        guard let (host, path, ref) = gitlabComponents(gitUrl: gitUrl, reference: reference) else { return nil }
        let apiUrl = "https://\(host)/api/v4/projects/\(path)/repository/files/Package.swift/raw?ref=\(ref)"
        return await fetchFileContent(from: apiUrl)
    }

    private func parseGitLabUrl(_ gitUrl: String) -> (host: String, projectPath: String)? {
        let range = NSRange(gitUrl.startIndex..., in: gitUrl)
        guard let match = Self.gitlabPattern.firstMatch(in: gitUrl, range: range),
              let hostRange = Range(match.range(at: 1), in: gitUrl),
              let pathRange = Range(match.range(at: 2), in: gitUrl)
        else { return nil }
        return (String(gitUrl[hostRange]), String(gitUrl[pathRange]))
    }

    // MARK: - Git Command Fallback

    private func checkRepositoryWithGit(gitUrl: String, reference: String) async -> Bool {
        logger.debug("Checking repository with git command: \(gitUrl) at \(reference)")

        let lsRemoteOk = await executeProcess(
            launchPath: "/usr/bin/env",
            arguments: ["git", "ls-remote", "--exit-code", gitUrl, reference]
        ) == 0

        guard lsRemoteOk else { return false }

        return await executeProcess(
            launchPath: "/usr/bin/env",
            arguments: ["git", "archive", "--remote=\(gitUrl)", reference, "Package.swift"]
        ) == 0
    }

    private func fetchWithGit(gitUrl: String, reference: String) async -> String? {
        logger.debug("Fetching Package.swift with git command from \(gitUrl) at \(reference)")

        // Pipe: git archive ... | tar -xO
        return await withCheckedContinuation { continuation in
            let archiveProcess = Process()
            archiveProcess.launchPath = "/usr/bin/env"
            archiveProcess.arguments = ["git", "archive", "--remote=\(gitUrl)", reference, "Package.swift"]

            let tarProcess = Process()
            tarProcess.launchPath = "/usr/bin/env"
            tarProcess.arguments = ["tar", "-xO"]

            let pipe = Pipe()
            let outputPipe = Pipe()
            archiveProcess.standardOutput = pipe
            tarProcess.standardInput = pipe
            tarProcess.standardOutput = outputPipe
            tarProcess.standardError = FileHandle.nullDevice

            tarProcess.terminationHandler = { _ in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                continuation.resume(returning: output?.isEmpty == false ? output : nil)
            }

            do {
                try archiveProcess.run()
                try tarProcess.run()
                // Do NOT call archiveProcess.waitUntilExit() here: if outputPipe's buffer
                // fills before the termination handler drains it, tar blocks → archive
                // blocks on its write → waitUntilExit() deadlocks.
                // tarProcess.terminationHandler fires naturally once tar reads EOF from
                // the archive process's stdout (i.e. after archive exits).
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - HTTP Helpers

    private func makeHttpHeadRequest(to urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10.0

            let (_, response) = try await URLSession.shared.data(for: request)

            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            logger.debug("HTTP HEAD request failed: \(error.localizedDescription)")
            return false
        }
    }

    private func fetchFileContent(from urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0

            let (data, response) = try await URLSession.shared.data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            return String(data: data, encoding: .utf8)
        } catch {
            logger.debug("Failed to fetch file content: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Process Helper

    private func executeProcess(launchPath: String, arguments: [String]) async -> Int32 {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = launchPath
            process.arguments = arguments
            // Redirect to /dev/null to prevent pipe-buffer blocking when output is not needed.
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { terminatedProcess in
                continuation.resume(returning: terminatedProcess.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }
    }
}
