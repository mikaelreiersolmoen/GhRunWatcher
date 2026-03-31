import Foundation

let server = MCPServer()

// Prevent stdout buffering
setbuf(stdout, nil)

while let line = readLine(strippingNewline: true) {
    guard !line.isEmpty else { continue }

    guard let data = line.data(using: .utf8),
          let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: data) else {
        let error = JSONRPCResponse.error(id: nil, code: -32700, message: "Parse error")
        writeLine(error)
        continue
    }

    guard let response = server.handle(request) else {
        continue // notifications don't get responses
    }

    writeLine(response)
}

func writeLine(_ response: JSONRPCResponse) {
    guard let data = try? JSONEncoder().encode(response),
          var json = String(data: data, encoding: .utf8) else { return }
    json.append("\n")
    FileHandle.standardOutput.write(json.data(using: .utf8)!)
}
