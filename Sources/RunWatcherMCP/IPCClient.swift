import Foundation
import GhRunWatcherIPC

enum IPCClientError: Error, CustomStringConvertible {
    case appNotRunning
    case connectionFailed(String)
    case invalidResponse

    var description: String {
        switch self {
        case .appNotRunning:
            return "GhRunWatcher is not running. Launch it first."
        case .connectionFailed(let msg):
            return "Connection failed: \(msg)"
        case .invalidResponse:
            return "Invalid response from GhRunWatcher"
        }
    }
}

struct IPCClient {
    func send(_ request: IPCRequest) throws -> IPCResponse {
        let path = IPCConstants.socketPath

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw IPCClientError.appNotRunning
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 104) { buf in
                path.withCString { src in
                    strncpy(buf, src, 103)
                }
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else {
            throw IPCClientError.appNotRunning
        }

        var data = try JSONEncoder().encode(request)
        data.append(UInt8(ascii: "\n"))
        let written = data.withUnsafeBytes { ptr -> Int in
            guard let base = ptr.baseAddress else { return -1 }
            return write(fd, base, data.count)
        }
        guard written == data.count else {
            throw IPCClientError.connectionFailed("Failed to send request")
        }

        // Shutdown write side to signal we're done sending
        shutdown(fd, SHUT_WR)

        var responseData = Data()
        let bufSize = 4096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        while true {
            let n = read(fd, buf, bufSize)
            if n <= 0 { break }
            responseData.append(buf, count: n)
        }

        // Strip trailing newline
        if responseData.last == UInt8(ascii: "\n") {
            responseData.removeLast()
        }

        guard let response = try? JSONDecoder().decode(IPCResponse.self, from: responseData) else {
            throw IPCClientError.invalidResponse
        }
        return response
    }
}
