import Foundation

public enum IPCConstants {
    public static let socketDirectory = "GhRunWatcher"
    public static let socketName = "mcp.sock"

    public static var socketPath: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.path
        return "\(appSupport)/\(socketDirectory)/\(socketName)"
    }
}

public enum IPCAction: String, Codable {
    case addWatch = "add_watch"
    case listWatches = "list_watches"
    case removeWatch = "remove_watch"
}

public struct IPCRequest: Codable {
    public let action: IPCAction
    public let runId: String?
    public let repo: String?
    public let watchId: String?

    public init(action: IPCAction, runId: String? = nil, repo: String? = nil, watchId: String? = nil) {
        self.action = action
        self.runId = runId
        self.repo = repo
        self.watchId = watchId
    }
}

public struct WatchInfo: Codable {
    public let id: String
    public let runId: String
    public let repo: String?

    public init(id: String, runId: String, repo: String? = nil) {
        self.id = id
        self.runId = runId
        self.repo = repo
    }
}

public struct IPCResponse: Codable {
    public let ok: Bool
    public let message: String?
    public let watches: [WatchInfo]?

    public init(ok: Bool, message: String? = nil, watches: [WatchInfo]? = nil) {
        self.ok = ok
        self.message = message
        self.watches = watches
    }

    public static func success(message: String) -> IPCResponse {
        IPCResponse(ok: true, message: message)
    }

    public static func success(watches: [WatchInfo]) -> IPCResponse {
        IPCResponse(ok: true, watches: watches)
    }

    public static func error(_ message: String) -> IPCResponse {
        IPCResponse(ok: false, message: message)
    }
}
