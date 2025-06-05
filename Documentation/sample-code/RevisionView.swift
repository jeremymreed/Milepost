//
//  RevisionView.swift
//  Milepost
//
//  Created by Jeremy M. Reed on 6/5/25.
//

import Milepost
import SwiftUI

struct RevisionView: View {
    var revision: Revision?

    func getAppVersion() -> String {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return appVersion
        }
        return "Unknown"
    }

    func getBuildNumber() -> String {
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return buildNumber
        }
        return "Unknown"
    }

    var workspaceStatus: String {
        if let revision {
            if revision.isWorkspaceClean {
                return "clean."
            } else {
                return "dirty."
            }
        } else {
            return "unknown."
        }
    }

    var body: some View {
        Form {
            Section("Version") {
                Text("Version: \(getAppVersion())")
                Text("Build Number: \(getBuildNumber())")
            }
            if let revision {
                Section("Git Info") {
                    Text("Author: \(revision.lastCommit.author.description)")
                    Text("Committer: \(revision.lastCommit.committer.description)")
                    Text("Short Hash: \(revision.shortHash)")
                    Text("Hash: \(revision.hash)")
                    Text("Git Workspace was \(workspaceStatus)")
                }
            }
        }
    }
}

#Preview {
    let revision =
            Revision(
                lastCommit: Revision.Commit(
                    author: Revision.Commit.User(
                        name: "Jeremy M. Reed",
                        email: "reeje76@gmail.com"
                    ),
                    committer: Revision.Commit.User(
                        name: "Jeremy M. Reed",
                        email: "reeje76@gmail.com"
                    ),
                    subject: "Foo",
                    authorDate: .now,
                    commitDate: .now,
                    shortHash: "deafbeef",
                    hash: "gloriousdeadbeef"
                ),
                branch: "main",
                isWorkspaceClean: false
            )
    RevisionView(revision: revision)
}
