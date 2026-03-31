import Foundation
import GhRunWatcherIPC

struct MCPServer {
    private let ipcClient = IPCClient()

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "add_watch",
            description: "Add a GitHub Actions workflow run to watch. You will be notified when it completes.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "run_id": .object([
                        "type": .string("string"),
                        "description": .string("The numeric GitHub Actions workflow run ID")
                    ]),
                    "repo": .object([
                        "type": .string("string"),
                        "description": .string("The GitHub repository in OWNER/REPO format (e.g. 'octocat/Hello-World'). Required unless a default repository is configured in the app.")
                    ])
                ]),
                "required": .array([.string("run_id")])
            ])
        ),
        MCPToolDefinition(
            name: "list_watches",
            description: "List all currently active GitHub Actions run watches.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:])
            ])
        ),
        MCPToolDefinition(
            name: "remove_watch",
            description: "Remove an active run watch.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "watch_id": .object([
                        "type": .string("string"),
                        "description": .string("The UUID of the watch to remove (from list_watches)")
                    ])
                ]),
                "required": .array([.string("watch_id")])
            ])
        )
    ]

    func handle(_ request: JSONRPCRequest) -> JSONRPCResponse? {
        switch request.method {
        case "initialize":
            return handleInitialize(id: request.id)
        case "notifications/initialized":
            return nil // notification, no response
        case "ping":
            return .success(id: request.id, result: .object([:]))
        case "tools/list":
            return handleToolsList(id: request.id)
        case "tools/call":
            return handleToolsCall(id: request.id, params: request.params)
        default:
            return .error(id: request.id, code: -32601, message: "Method not found: \(request.method)")
        }
    }

    private func handleInitialize(id: JSONRPCId?) -> JSONRPCResponse {
        .success(id: id, result: .object([
            "protocolVersion": .string("2024-11-05"),
            "capabilities": .object([
                "tools": .object([:])
            ]),
            "serverInfo": .object([
                "name": .string("ghrunwatcher"),
                "version": .string("1.0.0")
            ])
        ]))
    }

    private func handleToolsList(id: JSONRPCId?) -> JSONRPCResponse {
        let toolValues: [JSONValue] = tools.map { tool in
            let schemaData = try! JSONEncoder().encode(tool.inputSchema)
            let schema = try! JSONDecoder().decode(JSONValue.self, from: schemaData)
            return JSONValue.object([
                "name": .string(tool.name),
                "description": .string(tool.description),
                "inputSchema": schema
            ])
        }
        return .success(id: id, result: .object(["tools": .array(toolValues)]))
    }

    private func handleToolsCall(id: JSONRPCId?, params: JSONValue?) -> JSONRPCResponse {
        guard let name = params?["name"]?.stringValue else {
            return .error(id: id, code: -32602, message: "Missing tool name")
        }

        let arguments = params?["arguments"]

        switch name {
        case "add_watch":
            return callAddWatch(id: id, arguments: arguments)
        case "list_watches":
            return callListWatches(id: id)
        case "remove_watch":
            return callRemoveWatch(id: id, arguments: arguments)
        default:
            return .error(id: id, code: -32602, message: "Unknown tool: \(name)")
        }
    }

    private func callAddWatch(id: JSONRPCId?, arguments: JSONValue?) -> JSONRPCResponse {
        guard let runId = arguments?["run_id"]?.stringValue, !runId.isEmpty else {
            return toolError(id: id, message: "Missing required argument: run_id")
        }
        guard runId.allSatisfy(\.isNumber) else {
            return toolError(id: id, message: "run_id must contain only numbers")
        }
        let repo = arguments?["repo"]?.stringValue

        do {
            let response = try ipcClient.send(IPCRequest(action: .addWatch, runId: runId, repo: repo))
            if response.ok {
                return toolResult(id: id, text: response.message ?? "Watch added for run #\(runId)")
            } else {
                return toolError(id: id, message: response.message ?? "Failed to add watch")
            }
        } catch {
            return toolError(id: id, message: "\(error)")
        }
    }

    private func callListWatches(id: JSONRPCId?) -> JSONRPCResponse {
        do {
            let response = try ipcClient.send(IPCRequest(action: .listWatches))
            if response.ok {
                if let watches = response.watches, !watches.isEmpty {
                    let lines = watches.map { w in
                        let repoSuffix = w.repo.map { " in \($0)" } ?? ""
                        return "- Run #\(w.runId)\(repoSuffix) (id: \(w.id))"
                    }
                    return toolResult(id: id, text: "Active watches:\n\(lines.joined(separator: "\n"))")
                } else {
                    return toolResult(id: id, text: "No active watches.")
                }
            } else {
                return toolError(id: id, message: response.message ?? "Failed to list watches")
            }
        } catch {
            return toolError(id: id, message: "\(error)")
        }
    }

    private func callRemoveWatch(id: JSONRPCId?, arguments: JSONValue?) -> JSONRPCResponse {
        guard let watchId = arguments?["watch_id"]?.stringValue, !watchId.isEmpty else {
            return toolError(id: id, message: "Missing required argument: watch_id")
        }

        do {
            let response = try ipcClient.send(IPCRequest(action: .removeWatch, watchId: watchId))
            if response.ok {
                return toolResult(id: id, text: response.message ?? "Watch removed")
            } else {
                return toolError(id: id, message: response.message ?? "Failed to remove watch")
            }
        } catch {
            return toolError(id: id, message: "\(error)")
        }
    }

    private func toolResult(id: JSONRPCId?, text: String) -> JSONRPCResponse {
        .success(id: id, result: .object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(text)
                ])
            ])
        ]))
    }

    private func toolError(id: JSONRPCId?, message: String) -> JSONRPCResponse {
        .success(id: id, result: .object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(message)
                ])
            ]),
            "isError": .bool(true)
        ]))
    }
}
