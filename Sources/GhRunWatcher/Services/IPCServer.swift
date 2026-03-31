import Foundation
import GhRunWatcherIPC

final class IPCServer {
    private let watchManager: WatchManager
    private var serverFd: Int32 = -1
    private var running = false
    private let queue = DispatchQueue(label: "ipc-server", qos: .utility, attributes: .concurrent)

    init(watchManager: WatchManager) {
        self.watchManager = watchManager
    }

    func start() {
        let path = IPCConstants.socketPath
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // Remove stale socket
        unlink(path)

        serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let bound = ptr.withMemoryRebound(to: CChar.self, capacity: 104) { buf in
                path.withCString { src in
                    strncpy(buf, src, 103)
                }
            }
            _ = bound
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverFd, sockPtr, addrLen)
            }
        }
        guard bindResult == 0 else {
            close(serverFd)
            serverFd = -1
            return
        }

        guard listen(serverFd, 5) == 0 else {
            close(serverFd)
            serverFd = -1
            return
        }

        running = true
        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        running = false
        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }
        unlink(IPCConstants.socketPath)
    }

    private func acceptLoop() {
        while running {
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(serverFd, sockPtr, &clientLen)
                }
            }
            guard clientFd >= 0 else { continue }

            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.handleConnection(clientFd)
            }
        }
    }

    private func handleConnection(_ fd: Int32) {
        defer { close(fd) }

        var buffer = Data()
        let chunkSize = 4096
        let chunk = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { chunk.deallocate() }

        while true {
            let bytesRead = read(fd, chunk, chunkSize)
            guard bytesRead > 0 else { break }
            buffer.append(chunk, count: bytesRead)

            while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = buffer[buffer.startIndex..<newlineIndex]
                buffer = Data(buffer[buffer.index(after: newlineIndex)...])
                processMessage(lineData, fd: fd)
            }
        }
    }

    private func processMessage(_ data: Data, fd: Int32) {
        guard let request = try? JSONDecoder().decode(IPCRequest.self, from: data) else {
            sendResponse(.error("Invalid request"), fd: fd)
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        var response: IPCResponse = .error("Internal error")

        let manager = self.watchManager
        Task { @MainActor in
            response = Self.handleRequest(request, watchManager: manager)
            semaphore.signal()
        }

        semaphore.wait()
        sendResponse(response, fd: fd)
    }

    @MainActor
    private static func handleRequest(_ request: IPCRequest, watchManager: WatchManager) -> IPCResponse {
        switch request.action {
        case .addWatch:
            guard let runId = request.runId, !runId.isEmpty else {
                return .error("Missing run_id")
            }
            do {
                let watch = try watchManager.addWatch(runId: runId, repo: request.repo)
                return .success(message: "Watching run #\(runId) (id: \(watch.id.uuidString))")
            } catch {
                return .error(error.localizedDescription)
            }

        case .listWatches:
            let watches = watchManager.getWatches()
            return .success(watches: watches)

        case .removeWatch:
            guard let idString = request.watchId, let uuid = UUID(uuidString: idString) else {
                return .error("Missing or invalid watch_id")
            }
            if watchManager.removeWatchById(uuid) {
                return .success(message: "Watch removed")
            } else {
                return .error("Watch not found")
            }
        }
    }

    private func sendResponse(_ response: IPCResponse, fd: Int32) {
        guard var data = try? JSONEncoder().encode(response) else { return }
        data.append(UInt8(ascii: "\n"))
        data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            _ = write(fd, base, data.count)
        }
    }
}
