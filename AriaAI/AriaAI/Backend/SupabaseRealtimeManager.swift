import Foundation

// Minimal Phoenix Channels WebSocket client for Supabase Realtime.
// Subscribes to INSERT events on group_messages filtered by group_id.

final class SupabaseRealtimeManager: @unchecked Sendable {
    static let shared = SupabaseRealtimeManager()

    private var webSocketTask: URLSessionWebSocketTask?
    private var handlers: [String: (SBMessage) -> Void] = [:]
    private var ref = 0
    private var heartbeatTimer: Timer?
    private let lock = NSLock()

    private init() {}

    // MARK: - Public API

    func subscribe(groupID: String, onMessage: @escaping (SBMessage) -> Void) {
        lock.lock()
        handlers[groupID] = onMessage
        let needsConnect = webSocketTask == nil
        lock.unlock()

        if needsConnect { connect() }
        joinChannel(groupID: groupID)
    }

    func unsubscribe(groupID: String) {
        lock.lock()
        handlers.removeValue(forKey: groupID)
        let empty = handlers.isEmpty
        lock.unlock()

        if empty { disconnect() }
    }

    // MARK: - Connection

    private func connect() {
        guard let url = URL(string: SupabaseConfig.realtimeURL) else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        scheduleHeartbeat()
        receiveNext()
    }

    private func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    private func reconnect() {
        disconnect()
        let groupIDs: [String]
        lock.lock()
        groupIDs = Array(handlers.keys)
        lock.unlock()
        guard !groupIDs.isEmpty else { return }

        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            self.connect()
            groupIDs.forEach { self.joinChannel(groupID: $0) }
        }
    }

    // MARK: - Phoenix Channels protocol

    private func joinChannel(groupID: String) {
        // Supabase Realtime v2 topic format
        let topic = "realtime:public:group_messages:group_id=eq.\(groupID)"
        let payload: [String: Any] = [
            "topic":   topic,
            "event":   "phx_join",
            "payload": [
                "config": [
                    "broadcast": ["self": false],
                    "presence":  ["key": ""]
                ] as [String: Any]
            ] as [String: Any],
            "ref": nextRef()
        ]
        sendJSON(payload)
    }

    private func scheduleHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    private func sendHeartbeat() {
        sendJSON(["topic": "phoenix", "event": "heartbeat", "payload": [:] as [String: Any], "ref": nextRef()])
    }

    // MARK: - Receive loop

    private func receiveNext() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                self.handle(msg)
                self.receiveNext()
            case .failure:
                self.reconnect()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        guard (json["event"] as? String) == "INSERT",
              let payload = json["payload"] as? [String: Any],
              let record  = payload["record"] as? [String: Any]
        else { return }

        guard let id       = record["id"]        as? String,
              let groupID  = record["group_id"]  as? String,
              let role     = record["role"]       as? String,
              let content  = record["content"]   as? String,
              let tsString = record["created_at"] as? String
        else { return }

        let senderID = record["sender_id"] as? String

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdAt = formatter.date(from: tsString) ?? Date()

        let msg = SBMessage(id: id, groupId: groupID, senderId: senderID,
                            role: role, content: content, createdAt: createdAt)

        lock.lock()
        let handler = handlers[groupID]
        lock.unlock()

        DispatchQueue.main.async { handler?(msg) }
    }

    // MARK: - Helpers

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8)
        else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }

    private func nextRef() -> String {
        lock.lock()
        defer { lock.unlock() }
        ref += 1
        return String(ref)
    }
}
