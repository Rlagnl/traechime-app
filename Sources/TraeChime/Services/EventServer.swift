import Foundation
import Network

/// 本机事件服务：监听 127.0.0.1 的 HTTP 端口，接收 Trae 侧 hooks 推送
final class EventServer {
    private let registry: AgentRegistry
    private let settings: SettingsStore
    private let queue = DispatchQueue(label: "com.traechime.eventserver")
    private var listener: NWListener?

    /// 错误/就绪回调（在后台队列触发，需在主线程更新 UI）
    var onError: ((String) -> Void)?
    var onReady: (() -> Void)?

    init(registry: AgentRegistry, settings: SettingsStore) {
        self.registry = registry
        self.settings = settings
    }

    func start(port: UInt16) {
        stop()
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            onError?("端口 \(port) 无效")
            return
        }

        let parameters = NWParameters.tcp
        // 仅监听回环地址，不接受外部连接
        parameters.requiredInterfaceType = .loopback

        do {
            let listener = try NWListener(using: parameters, on: nwPort)
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    DispatchQueue.main.async { self?.onReady?() }
                case .failed(let error):
                    DispatchQueue.main.async { self?.onError?("端口 \(port) 监听失败：\(error.localizedDescription)") }
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            onError?("端口 \(port) 监听失败：\(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - 连接与请求处理

    private func handle(_ connection: NWConnection) {
        let context = ConnectionContext(connection: connection)
        connection.start(queue: queue)
        receive(context)
    }

    private func receive(_ context: ConnectionContext) {
        context.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                context.buffer.append(data)
            }
            if self.isCompleteRequest(context.buffer) || isComplete || error != nil {
                let response = self.process(context.buffer)
                self.send(response, on: context.connection)
            } else {
                self.receive(context)
            }
        }
    }

    /// 依据 Content-Length 判断请求体是否收完整
    private func isCompleteRequest(_ data: Data) -> Bool {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)) else { return false }
        let headerData = data[data.startIndex..<sep.lowerBound]
        let headerString = String(decoding: headerData, as: UTF8.self)
        var contentLength = 0
        for line in headerString.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                let value = line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "0"
                contentLength = Int(value) ?? 0
            }
        }
        let bodyLength = data.count - sep.upperBound
        return bodyLength >= contentLength
    }

    private func process(_ data: Data) -> Data {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)) else {
            return httpResponse(400, "Bad Request", body: "")
        }
        let headerData = data[data.startIndex..<sep.lowerBound]
        let headerString = String(decoding: headerData, as: UTF8.self)
        let lines = headerString.components(separatedBy: "\r\n")

        guard let requestLine = lines.first else {
            return httpResponse(400, "Bad Request", body: "")
        }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return httpResponse(400, "Bad Request", body: "")
        }
        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(kv[1]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        let body = data[sep.upperBound...]

        guard method == "POST", path == "/v1/events" else {
            return httpResponse(404, "Not Found", body: "")
        }

        // 令牌校验（未配置令牌则跳过）
        if !settings.token.isEmpty, headers["x-traechime-token"] != settings.token {
            return httpResponse(401, "Unauthorized", body: "")
        }

        guard let event = try? JSONDecoder().decode(AgentEvent.self, from: body), event.isValid else {
            return httpResponse(400, "Bad Request", body: "")
        }

        // 状态变更须在主线程执行（ObservableObject 驱动 SwiftUI）
        DispatchQueue.main.async { [weak self] in
            self?.registry.apply(event)
        }
        return httpResponse(200, "OK", body: "")
    }

    private func httpResponse(_ code: Int, _ reason: String, body: String) -> Data {
        let bodyData = body.data(using: .utf8) ?? Data()
        let head = "HTTP/1.1 \(code) \(reason)\r\nContent-Type: text/plain\r\nContent-Length: \(bodyData.count)\r\nConnection: close\r\n\r\n"
        var response = Data(head.utf8)
        response.append(bodyData)
        return response
    }

    private func send(_ data: Data, on connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

/// 每个连接的缓冲区
private final class ConnectionContext {
    let connection: NWConnection
    var buffer = Data()

    init(connection: NWConnection) {
        self.connection = connection
    }
}
