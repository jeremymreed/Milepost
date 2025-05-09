import Foundation
import Milepost

struct Fetcher {
    init(repositoryPath: URL, gitExecutablePath: URL) {
        self.repositoryPath = repositoryPath
        self.gitExecutablePath = gitExecutablePath
    }
    private let repositoryPath: URL
    private let gitExecutablePath: URL
    private let fileManager: FileManager = .default
    
    enum Error: Swift.Error {
        case executableNotFound
        case repositoryNotFound
        case unexpectedOutput
        case noCommit
    }
    
    func parse() throws -> Revision {
        guard fileManager.fileExists(atPath: gitExecutablePath.path) else {
            throw Error.executableNotFound
        }
        
        let lastCommit = try parseLastCommit()
        let branchName = parseBranchName()
        let workspaceStatus = parseWorkspaceStatus()
        return .init(lastCommit: lastCommit,
                     branch: branchName,
                     isWorkspaceClean: workspaceStatus)
    }
    
    private func parseBranchName() -> String? {
        try? runGit("rev-parse", "--abbrev-ref", "HEAD")
    }
    
    private func parseLastCommit() throws -> Revision.Commit {
        let format: String = [
            "%H", // Hash
            "%h", // Short hash
            "%an", // Author name
            "%ae", // Author email
            "%at", // Author timestamp
            "%cn", // Commit name
            "%ce", // Commit email
            "%ct", // Commit timestamp
        ]
            .joined(separator: "%n")
        guard let outputString = try? runGit("show", "-s", "--format=\(format)") else {
            throw Error.unexpectedOutput
        }
        let bits = outputString.split(separator: "\n").map(String.init)
        
        guard bits.count == 8 else {
            throw Error.unexpectedOutput
        }
        let hash = bits[0]
        let shortHash = bits[1]
        let authorName = bits[2]
        let authorEmail = bits[3]
        guard let authorDate = TimeInterval(bits[4]).map(Date.init(timeIntervalSince1970:)) else {
            throw Error.unexpectedOutput
        }
        let commitName = bits[5]
        let commitEmail = bits[6]
        guard let commitDate = TimeInterval(bits[7]).map(Date.init(timeIntervalSince1970:)) else {
            throw Error.unexpectedOutput
        }
        
        let subject = parseCommitSubject()
        
        return .init(author: .init(name: authorName, email: authorEmail),
                     committer: .init(name: commitName, email: commitEmail),
                     subject: subject,
                     authorDate: authorDate,
                     commitDate: commitDate,
                     shortHash: shortHash,
                     hash: hash)
    }
    
    private func parseCommitSubject() -> String? {
        try? runGit("show", "-s", "--format=%s")
    }

    private func parseWorkspaceStatus() -> Bool {
        do {
            let result = try runGit("status", "--porcelain")
            if result.isEmpty {
                print("Workspace was clean.")
            } else {
                print("Workspace was dirty.")
            }
            return result.isEmpty
        } catch {
            fatalError("Failed to get workspace status: \(error.localizedDescription)")
        }
    }

    private func gitProcess(for arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = gitExecutablePath
        process.arguments = arguments
        return process
    }

    // Errors thrown from this function may be getting swallowed by the try? calls in the various parse* methods.
    // Check the assumptions made here about what outputs are errors and what isn't.
    private func runGit(_ subCommand: String, _ options: String...) throws -> String {
        fileManager.changeCurrentDirectoryPath(repositoryPath.path)
        let standardOutput = Pipe()
        let standardError = Pipe()
        
        let arguments = [subCommand] + options
        let git = gitProcess(for: arguments)
        git.standardOutput = standardOutput
        git.standardError = standardError
        
        try git.run()
        git.waitUntilExit()
        
        if git.terminationStatus > 0, let errorData = try standardError.fileHandleForReading.readToEnd(),
            let errorString = String(data: errorData, encoding: .utf8) {
            if errorString.contains("does not have any commits yet") {
                throw Error.noCommit
            } else if errorString.contains("not a git repository") {
                throw Error.repositoryNotFound
            } else {
                throw Error.unexpectedOutput
            }
        }
        
        let outputData = try standardOutput.fileHandleForReading.readToEnd() ?? Data()

        guard let string = String(data: outputData, encoding: .utf8) else {
            throw Error.unexpectedOutput
        }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
