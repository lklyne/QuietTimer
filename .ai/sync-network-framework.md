# Network Framework Local Sync Implementation Specification

## Overview

Local network synchronization for QuietTimer app using iOS Network Framework and Bonjour service discovery to sync timer sessions and active timer state between devices on the same WiFi network.

## Architecture Overview

### Core Components

1. **NetworkSyncManager**: Main coordination class
2. **ServiceAdvertiser**: Advertises timer service on local network
3. **ServiceBrowser**: Discovers other timer apps on network
4. **ConnectionManager**: Manages peer-to-peer connections
5. **SyncProtocol**: Defines message format and sync logic
6. **ConflictResolver**: Handles data conflicts between devices

## Prerequisites

### iOS Requirements

- iOS 12.0+ (Network Framework availability)
- Local Network permission (iOS 14+)
- WiFi or local network connectivity

### App Capabilities

```swift
// Info.plist additions required:
<key>NSLocalNetworkUsageDescription</key>
<string>QuietTimer needs local network access to sync timers with other devices on your network.</string>

<key>NSBonjourServices</key>
<array>
    <string>_quiettimer._tcp</string>
</array>
```

## Data Model

### Sync Message Protocol

```swift
// Base message structure
struct SyncMessage: Codable {
    let messageID: UUID
    let timestamp: Date
    let deviceID: String
    let deviceName: String
    let messageType: MessageType
    let payload: Data

    enum MessageType: String, Codable {
        case handshake
        case timerSessionUpdate
        case activeTimerUpdate
        case timerSessionHistory
        case heartbeat
        case acknowledgment
        case conflictResolution
    }
}

// Specific message payloads
struct HandshakePayload: Codable {
    let appVersion: String
    let protocolVersion: String
    let deviceCapabilities: [String]
    let lastSyncTimestamp: Date?
}

struct TimerSessionPayload: Codable {
    let sessions: [NetworkTimerSession]
    let syncType: SyncType

    enum SyncType: String, Codable {
        case full        // Complete session history
        case incremental // Only changes since last sync
        case single      // Single session update
    }
}

struct ActiveTimerPayload: Codable {
    let activeTimer: NetworkActiveTimer?
    let action: TimerAction

    enum TimerAction: String, Codable {
        case start
        case pause
        case resume
        case stop
        case update
        case clear
    }
}
```

### Network Data Models

```swift
struct NetworkTimerSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let deviceID: String
    let deviceName: String
    let createdAt: Date
    let modifiedAt: Date
    let isActive: Bool

    // Convert from local TimerSession
    init(from session: TimerSession, deviceID: String, deviceName: String) {
        self.id = session.id
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.duration = session.duration
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.createdAt = session.startTime
        self.modifiedAt = Date()
        self.isActive = false
    }
}

struct NetworkActiveTimer: Codable {
    let sessionID: UUID
    let startTime: Date
    let pausedTime: Date?
    let totalPausedDuration: TimeInterval
    let isRunning: Bool
    let isPaused: Bool
    let deviceID: String
    let deviceName: String
    let lastUpdateTime: Date
    let elapsedTime: TimeInterval

    var currentElapsedTime: TimeInterval {
        if isRunning && !isPaused {
            return elapsedTime + Date().timeIntervalSince(lastUpdateTime)
        }
        return elapsedTime
    }
}
```

## Implementation Architecture

### 1. NetworkSyncManager

```swift
import Network
import Combine

class NetworkSyncManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isEnabled: Bool = false
    @Published var connectedDevices: [ConnectedDevice] = []
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?

    // MARK: - Private Properties
    private let deviceID = UUID().uuidString
    private let deviceName = UIDevice.current.name
    private let serviceType = "_quiettimer._tcp"
    private let port: NWEndpoint.Port = 12345

    private var serviceAdvertiser: ServiceAdvertiser?
    private var serviceBrowser: ServiceBrowser?
    private var connectionManager: ConnectionManager
    private var syncProtocol: SyncProtocol

    // MARK: - Sync Status
    enum SyncStatus {
        case idle
        case discovering
        case connecting
        case syncing
        case connected(Int) // number of connected devices
        case error(String)
    }

    struct ConnectedDevice: Identifiable {
        let id: String
        let name: String
        let connection: NWConnection
        let lastSeen: Date
        let capabilities: [String]
    }

    init() {
        self.connectionManager = ConnectionManager(deviceID: deviceID, deviceName: deviceName)
        self.syncProtocol = SyncProtocol(deviceID: deviceID)

        setupBindings()
    }

    // MARK: - Public Interface
    func startNetworkSync() {
        guard !isEnabled else { return }

        isEnabled = true
        syncStatus = .discovering

        startServiceAdvertising()
        startServiceDiscovery()
    }

    func stopNetworkSync() {
        guard isEnabled else { return }

        isEnabled = false
        syncStatus = .idle

        stopServiceAdvertising()
        stopServiceDiscovery()
        connectionManager.disconnectAll()
        connectedDevices.removeAll()
    }

    func syncTimerSession(_ session: TimerSession) {
        let networkSession = NetworkTimerSession(from: session, deviceID: deviceID, deviceName: deviceName)
        let payload = TimerSessionPayload(sessions: [networkSession], syncType: .single)

        Task {
            await broadcastMessage(.timerSessionUpdate, payload: payload)
        }
    }

    func syncActiveTimer(_ timer: NetworkActiveTimer?) {
        let payload = ActiveTimerPayload(
            activeTimer: timer,
            action: timer != nil ? .update : .clear
        )

        Task {
            await broadcastMessage(.activeTimerUpdate, payload: payload)
        }
    }
}
```

### 2. Service Advertising

```swift
class ServiceAdvertiser {
    private var listener: NWListener?
    private let serviceType: String
    private let port: NWEndpoint.Port
    private let deviceID: String
    private let deviceName: String

    weak var delegate: ServiceAdvertiserDelegate?

    init(serviceType: String, port: NWEndpoint.Port, deviceID: String, deviceName: String) {
        self.serviceType = serviceType
        self.port = port
        self.deviceID = deviceID
        self.deviceName = deviceName
    }

    func startAdvertising() throws {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        listener = try NWListener(using: parameters, on: port)

        // Configure Bonjour service
        let service = NWListener.Service(
            name: deviceName,
            type: serviceType,
            txtRecord: createTXTRecord()
        )
        listener?.service = service

        listener?.stateUpdateHandler = { [weak self] state in
            self?.handleListenerStateChange(state)
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    func stopAdvertising() {
        listener?.cancel()
        listener = nil
    }

    private func createTXTRecord() -> NWTXTRecord {
        var txtRecord = NWTXTRecord()
        txtRecord["deviceID"] = deviceID
        txtRecord["appVersion"] = Bundle.main.appVersion
        txtRecord["protocolVersion"] = "1.0"
        txtRecord["capabilities"] = "timer,sync,history"
        return txtRecord
    }

    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            delegate?.serviceAdvertiserDidStart()
        case .failed(let error):
            delegate?.serviceAdvertiser(didFailWithError: error)
        case .cancelled:
            delegate?.serviceAdvertiserDidStop()
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        delegate?.serviceAdvertiser(didReceiveConnection: connection)
    }
}

protocol ServiceAdvertiserDelegate: AnyObject {
    func serviceAdvertiserDidStart()
    func serviceAdvertiserDidStop()
    func serviceAdvertiser(didFailWithError error: Error)
    func serviceAdvertiser(didReceiveConnection connection: NWConnection)
}
```

### 3. Service Discovery

```swift
class ServiceBrowser {
    private var browser: NWBrowser?
    private let serviceType: String

    weak var delegate: ServiceBrowserDelegate?

    init(serviceType: String) {
        self.serviceType = serviceType
    }

    func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            self?.handleBrowserStateChange(state)
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResultsChanged(results: results, changes: changes)
        }

        browser?.start(queue: .global(qos: .userInitiated))
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    private func handleBrowserStateChange(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            delegate?.serviceBrowserDidStart()
        case .failed(let error):
            delegate?.serviceBrowser(didFailWithError: error)
        case .cancelled:
            delegate?.serviceBrowserDidStop()
        default:
            break
        }
    }

    private func handleBrowseResultsChanged(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                delegate?.serviceBrowser(didFindService: result)
            case .removed(let result):
                delegate?.serviceBrowser(didLoseService: result)
            case .changed(old: _, new: let result, flags: _):
                delegate?.serviceBrowser(didUpdateService: result)
            @unknown default:
                break
            }
        }
    }
}

protocol ServiceBrowserDelegate: AnyObject {
    func serviceBrowserDidStart()
    func serviceBrowserDidStop()
    func serviceBrowser(didFailWithError error: Error)
    func serviceBrowser(didFindService service: NWBrowser.Result)
    func serviceBrowser(didLoseService service: NWBrowser.Result)
    func serviceBrowser(didUpdateService service: NWBrowser.Result)
}
```

### 4. Connection Management

```swift
class ConnectionManager {
    private var connections: [String: NWConnection] = [:]
    private let deviceID: String
    private let deviceName: String

    weak var delegate: ConnectionManagerDelegate?

    init(deviceID: String, deviceName: String) {
        self.deviceID = deviceID
        self.deviceName = deviceName
    }

    func connectToService(_ result: NWBrowser.Result) {
        let connectionID = extractDeviceID(from: result) ?? UUID().uuidString

        // Avoid connecting to ourselves
        guard connectionID != deviceID else { return }

        // Check if already connected
        guard connections[connectionID] == nil else { return }

        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connections[connectionID] = connection

        setupConnection(connection, deviceID: connectionID)
        connection.start(queue: .global(qos: .userInitiated))
    }

    func acceptConnection(_ connection: NWConnection) {
        let connectionID = UUID().uuidString // Will be updated after handshake
        connections[connectionID] = connection

        setupConnection(connection, deviceID: connectionID)
        connection.start(queue: .global(qos: .userInitiated))
    }

    func sendMessage(_ message: SyncMessage, to deviceID: String) async throws {
        guard let connection = connections[deviceID] else {
            throw NetworkSyncError.deviceNotConnected
        }

        let data = try JSONEncoder().encode(message)
        let lengthData = withUnsafeBytes(of: UInt32(data.count).bigEndian) { Data($0) }

        try await withCheckedThrowingContinuation { continuation in
            connection.send(content: lengthData + data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func broadcastMessage(_ message: SyncMessage) async {
        await withTaskGroup(of: Void.self) { group in
            for (deviceID, _) in connections {
                group.addTask {
                    try? await self.sendMessage(message, to: deviceID)
                }
            }
        }
    }

    func disconnectAll() {
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
    }

    private func setupConnection(_ connection: NWConnection, deviceID: String) {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionStateChange(connection, deviceID: deviceID, state: state)
        }

        startReceivingMessages(connection, deviceID: deviceID)
    }

    private func startReceivingMessages(_ connection: NWConnection, deviceID: String) {
        // First, receive the message length (4 bytes)
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in

            if let error = error {
                self?.delegate?.connectionManager(didFailWithError: error, for: deviceID)
                return
            }

            guard let lengthData = data, lengthData.count == 4 else {
                self?.startReceivingMessages(connection, deviceID: deviceID)
                return
            }

            let messageLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            // Now receive the actual message
            connection.receive(minimumIncompleteLength: Int(messageLength), maximumLength: Int(messageLength)) { data, _, isComplete, error in

                if let error = error {
                    self?.delegate?.connectionManager(didFailWithError: error, for: deviceID)
                    return
                }

                if let messageData = data {
                    self?.handleReceivedMessage(messageData, from: deviceID)
                }

                // Continue receiving messages
                if !isComplete {
                    self?.startReceivingMessages(connection, deviceID: deviceID)
                }
            }
        }
    }

    private func handleReceivedMessage(_ data: Data, from deviceID: String) {
        do {
            let message = try JSONDecoder().decode(SyncMessage.self, from: data)
            delegate?.connectionManager(didReceiveMessage: message, from: deviceID)
        } catch {
            delegate?.connectionManager(didFailWithError: error, for: deviceID)
        }
    }

    private func extractDeviceID(from result: NWBrowser.Result) -> String? {
        guard case .service(let name, let type, let domain, let txtRecord) = result.metadata else {
            return nil
        }

        return txtRecord?["deviceID"]
    }
}

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(didReceiveMessage message: SyncMessage, from deviceID: String)
    func connectionManager(didFailWithError error: Error, for deviceID: String)
    func connectionManager(didConnect deviceID: String)
    func connectionManager(didDisconnect deviceID: String)
}

enum NetworkSyncError: Error {
    case deviceNotConnected
    case invalidMessage
    case syncConflict
    case networkUnavailable
}
```

### 5. Sync Protocol Implementation

```swift
class SyncProtocol {
    private let deviceID: String
    private var pendingAcknowledgments: [UUID: Date] = [:]
    private let acknowledgmentTimeout: TimeInterval = 10.0

    weak var delegate: SyncProtocolDelegate?

    init(deviceID: String) {
        self.deviceID = deviceID
        startAcknowledgmentTimer()
    }

    // MARK: - Message Creation
    func createHandshakeMessage() -> SyncMessage {
        let payload = HandshakePayload(
            appVersion: Bundle.main.appVersion,
            protocolVersion: "1.0",
            deviceCapabilities: ["timer", "sync", "history"],
            lastSyncTimestamp: UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date
        )

        return createMessage(.handshake, payload: payload)
    }

    func createTimerSessionMessage(_ sessions: [NetworkTimerSession], syncType: TimerSessionPayload.SyncType) -> SyncMessage {
        let payload = TimerSessionPayload(sessions: sessions, syncType: syncType)
        return createMessage(.timerSessionUpdate, payload: payload)
    }

    func createActiveTimerMessage(_ timer: NetworkActiveTimer?, action: ActiveTimerPayload.TimerAction) -> SyncMessage {
        let payload = ActiveTimerPayload(activeTimer: timer, action: action)
        return createMessage(.activeTimerUpdate, payload: payload)
    }

    func createHeartbeatMessage() -> SyncMessage {
        return createMessage(.heartbeat, payload: Data())
    }

    func createAcknowledgmentMessage(for messageID: UUID) -> SyncMessage {
        let ackData = try! JSONEncoder().encode(messageID)
        return createMessage(.acknowledgment, payload: ackData)
    }

    private func createMessage(_ type: SyncMessage.MessageType, payload: Codable) -> SyncMessage {
        let payloadData = try! JSONEncoder().encode(payload)

        return SyncMessage(
            messageID: UUID(),
            timestamp: Date(),
            deviceID: deviceID,
            deviceName: UIDevice.current.name,
            messageType: type,
            payload: payloadData
        )
    }

    // MARK: - Message Processing
    func processReceivedMessage(_ message: SyncMessage) async {
        // Send acknowledgment for non-acknowledgment messages
        if message.messageType != .acknowledgment && message.messageType != .heartbeat {
            let ackMessage = createAcknowledgmentMessage(for: message.messageID)
            delegate?.syncProtocol(shouldSendMessage: ackMessage, to: message.deviceID)
        }

        switch message.messageType {
        case .handshake:
            await processHandshakeMessage(message)
        case .timerSessionUpdate:
            await processTimerSessionMessage(message)
        case .activeTimerUpdate:
            await processActiveTimerMessage(message)
        case .timerSessionHistory:
            await processTimerHistoryMessage(message)
        case .heartbeat:
            await processHeartbeatMessage(message)
        case .acknowledgment:
            await processAcknowledgmentMessage(message)
        case .conflictResolution:
            await processConflictResolutionMessage(message)
        }
    }

    private func processHandshakeMessage(_ message: SyncMessage) async {
        do {
            let payload = try JSONDecoder().decode(HandshakePayload.self, from: message.payload)
            delegate?.syncProtocol(didReceiveHandshake: payload, from: message.deviceID)

            // Respond with our own handshake
            let responseMessage = createHandshakeMessage()
            delegate?.syncProtocol(shouldSendMessage: responseMessage, to: message.deviceID)

        } catch {
            delegate?.syncProtocol(didFailWithError: error)
        }
    }

    private func processTimerSessionMessage(_ message: SyncMessage) async {
        do {
            let payload = try JSONDecoder().decode(TimerSessionPayload.self, from: message.payload)
            delegate?.syncProtocol(didReceiveTimerSessions: payload.sessions, syncType: payload.syncType, from: message.deviceID)
        } catch {
            delegate?.syncProtocol(didFailWithError: error)
        }
    }

    private func processActiveTimerMessage(_ message: SyncMessage) async {
        do {
            let payload = try JSONDecoder().decode(ActiveTimerPayload.self, from: message.payload)
            delegate?.syncProtocol(didReceiveActiveTimer: payload.activeTimer, action: payload.action, from: message.deviceID)
        } catch {
            delegate?.syncProtocol(didFailWithError: error)
        }
    }

    // MARK: - Acknowledgment Management
    func trackMessageForAcknowledgment(_ message: SyncMessage) {
        pendingAcknowledgments[message.messageID] = Date()
    }

    private func processAcknowledgmentMessage(_ message: SyncMessage) async {
        do {
            let messageID = try JSONDecoder().decode(UUID.self, from: message.payload)
            pendingAcknowledgments.removeValue(forKey: messageID)
        } catch {
            delegate?.syncProtocol(didFailWithError: error)
        }
    }

    private func startAcknowledgmentTimer() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkPendingAcknowledgments()
        }
    }

    private func checkPendingAcknowledgments() {
        let now = Date()
        let expiredMessages = pendingAcknowledgments.filter { _, timestamp in
            now.timeIntervalSince(timestamp) > acknowledgmentTimeout
        }

        for (messageID, _) in expiredMessages {
            pendingAcknowledgments.removeValue(forKey: messageID)
            delegate?.syncProtocol(didTimeoutMessage: messageID)
        }
    }
}

protocol SyncProtocolDelegate: AnyObject {
    func syncProtocol(shouldSendMessage message: SyncMessage, to deviceID: String)
    func syncProtocol(didReceiveHandshake payload: HandshakePayload, from deviceID: String)
    func syncProtocol(didReceiveTimerSessions sessions: [NetworkTimerSession], syncType: TimerSessionPayload.SyncType, from deviceID: String)
    func syncProtocol(didReceiveActiveTimer timer: NetworkActiveTimer?, action: ActiveTimerPayload.TimerAction, from deviceID: String)
    func syncProtocol(didTimeoutMessage messageID: UUID)
    func syncProtocol(didFailWithError error: Error)
}
```

### 6. Conflict Resolution

```swift
class ConflictResolver {
    enum ResolutionStrategy {
        case lastWriterWins
        case devicePriority([String]) // Ordered list of preferred devices
        case userChoice
        case merge
    }

    func resolveActiveTimerConflict(
        local: NetworkActiveTimer?,
        remote: NetworkActiveTimer,
        strategy: ResolutionStrategy = .lastWriterWins
    ) -> NetworkActiveTimer? {

        guard let local = local else {
            return remote // No local timer, accept remote
        }

        switch strategy {
        case .lastWriterWins:
            return local.lastUpdateTime > remote.lastUpdateTime ? local : remote

        case .devicePriority(let preferredDevices):
            for deviceID in preferredDevices {
                if local.deviceID == deviceID {
                    return local
                } else if remote.deviceID == deviceID {
                    return remote
                }
            }
            // Fall back to last writer wins
            return local.lastUpdateTime > remote.lastUpdateTime ? local : remote

        case .merge:
            // For active timers, merging doesn't make sense
            // Fall back to last writer wins
            return local.lastUpdateTime > remote.lastUpdateTime ? local : remote

        case .userChoice:
            // This would require UI interaction
            // For now, return local and let UI handle it
            return local
        }
    }

    func resolveTimerSessionConflicts(
        local: [NetworkTimerSession],
        remote: [NetworkTimerSession]
    ) -> [NetworkTimerSession] {

        var mergedSessions: [UUID: NetworkTimerSession] = [:]

        // Add all local sessions
        for session in local {
            mergedSessions[session.id] = session
        }

        // Merge remote sessions
        for remoteSession in remote {
            if let localSession = mergedSessions[remoteSession.id] {
                // Conflict: same session ID exists locally
                // Use the one with the latest modification date
                if remoteSession.modifiedAt > localSession.modifiedAt {
                    mergedSessions[remoteSession.id] = remoteSession
                }
            } else {
                // No conflict: add remote session
                mergedSessions[remoteSession.id] = remoteSession
            }
        }

        return Array(mergedSessions.values).sorted { $0.startTime > $1.startTime }
    }
}
```

## Integration with Existing Code

### TimerViewModel Integration

```swift
extension TimerViewModel {
    private let networkSyncManager = NetworkSyncManager()

    func enableNetworkSync() {
        networkSyncManager.delegate = self
        networkSyncManager.startNetworkSync()
    }

    func disableNetworkSync() {
        networkSyncManager.stopNetworkSync()
    }

    override func startTimer() {
        super.startTimer()

        // Sync active timer to network
        if let activeTimer = self.activeTimer {
            let networkTimer = NetworkActiveTimer(from: activeTimer)
            networkSyncManager.syncActiveTimer(networkTimer)
        }
    }

    override func stopTimer() {
        super.stopTimer()

        // Clear active timer on network
        networkSyncManager.syncActiveTimer(nil)

        // Sync completed session
        if let lastSession = sessions.last {
            networkSyncManager.syncTimerSession(lastSession)
        }
    }
}

extension TimerViewModel: NetworkSyncManagerDelegate {
    func networkSyncManager(didReceiveActiveTimer timer: NetworkActiveTimer?, from deviceID: String) {
        DispatchQueue.main.async {
            if let timer = timer {
                // Handle incoming active timer
                self.handleRemoteActiveTimer(timer, from: deviceID)
            } else {
                // Remote device cleared their timer
                self.handleRemoteTimerCleared(from: deviceID)
            }
        }
    }

    func networkSyncManager(didReceiveTimerSessions sessions: [NetworkTimerSession], from deviceID: String) {
        DispatchQueue.main.async {
            self.mergeRemoteTimerSessions(sessions)
        }
    }

    private func handleRemoteActiveTimer(_ remoteTimer: NetworkActiveTimer, from deviceID: String) {
        if let localTimer = activeTimer {
            // Conflict resolution needed
            let resolver = ConflictResolver()
            let localNetworkTimer = NetworkActiveTimer(from: localTimer)

            if let resolvedTimer = resolver.resolveActiveTimerConflict(
                local: localNetworkTimer,
                remote: remoteTimer
            ) {
                if resolvedTimer.deviceID != networkSyncManager.deviceID {
                    // Remote timer wins, update local state
                    activeTimer = ActiveTimerState(from: resolvedTimer)
                }
            }
        } else {
            // No local timer, adopt remote timer
            activeTimer = ActiveTimerState(from: remoteTimer)
        }
    }
}
```

## Error Handling & Edge Cases

### Network Error Handling

```swift
enum NetworkSyncError: Error, LocalizedError {
    case networkUnavailable
    case serviceDiscoveryFailed
    case connectionFailed(String)
    case messageDecodingFailed
    case syncConflict
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is not available"
        case .serviceDiscoveryFailed:
            return "Failed to discover other devices"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .messageDecodingFailed:
            return "Failed to decode sync message"
        case .syncConflict:
            return "Sync conflict detected"
        case .permissionDenied:
            return "Local network permission denied"
        }
    }
}

extension NetworkSyncManager {
    private func handleNetworkError(_ error: Error) {
        DispatchQueue.main.async {
            if let nwError = error as? NWError {
                switch nwError {
                case .posix(.ECONNREFUSED):
                    self.syncStatus = .error("Connection refused")
                case .posix(.ENETUNREACH):
                    self.syncStatus = .error("Network unreachable")
                default:
                    self.syncStatus = .error("Network error: \(nwError.localizedDescription)")
                }
            } else {
                self.syncStatus = .error(error.localizedDescription)
            }
        }
    }
}
```

### Permission Handling

```swift
extension NetworkSyncManager {
    func checkLocalNetworkPermission() async -> Bool {
        // iOS 14+ requires explicit permission for local network access
        if #available(iOS 14.0, *) {
            return await withCheckedContinuation { continuation in
                // Create a temporary listener to trigger permission prompt
                let parameters = NWParameters.tcp
                parameters.includePeerToPeer = true

                do {
                    let testListener = try NWListener(using: parameters, on: .any)
                    testListener.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            testListener.cancel()
                            continuation.resume(returning: true)
                        case .failed(let error):
                            testListener.cancel()
                            if case .posix(.EPERM) = error {
                                continuation.resume(returning: false)
                            } else {
                                continuation.resume(returning: true)
                            }
                        default:
                            break
                        }
                    }
                    testListener.start(queue: .global())
                } catch {
                    continuation.resume(returning: false)
                }
            }
        } else {
            return true
        }
    }
}
```

## Performance Optimization

### Message Batching

```swift
class MessageBatcher {
    private var pendingMessages: [SyncMessage] = []
    private var batchTimer: Timer?
    private let batchInterval: TimeInterval = 0.5
    private let maxBatchSize = 10

    weak var delegate: MessageBatcherDelegate?

    func addMessage(_ message: SyncMessage) {
        pendingMessages.append(message)

        if pendingMessages.count >= maxBatchSize {
            flushBatch()
        } else if batchTimer == nil {
            startBatchTimer()
        }
    }

    private func startBatchTimer() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: false) { [weak self] _ in
            self?.flushBatch()
        }
    }

    private func flushBatch() {
        guard !pendingMessages.isEmpty else { return }

        let batch = pendingMessages
        pendingMessages.removeAll()
        batchTimer?.invalidate()
        batchTimer = nil

        delegate?.messageBatcher(shouldSendBatch: batch)
    }
}
```

### Connection Pooling

```swift
class ConnectionPool {
    private var availableConnections: [String: NWConnection] = [:]
    private var activeConnections: [String: NWConnection] = [:]
    private let maxConnections = 5

    func getConnection(for deviceID: String) -> NWConnection? {
        if let connection = activeConnections[deviceID] {
            return connection
        }

        if let connection = availableConnections.removeValue(forKey: deviceID) {
            activeConnections[deviceID] = connection
            return connection
        }

        return nil
    }

    func releaseConnection(for deviceID: String) {
        if let connection = activeConnections.removeValue(forKey: deviceID) {
            if availableConnections.count < maxConnections {
                availableConnections[deviceID] = connection
            } else {
                connection.cancel()
            }
        }
    }
}
```

## Testing Strategy

### Unit Tests

```swift
class NetworkSyncManagerTests: XCTestCase {
    var syncManager: NetworkSyncManager!
    var mockConnectionManager: MockConnectionManager!

    override func setUp() {
        syncManager = NetworkSyncManager()
        mockConnectionManager = MockConnectionManager()
        syncManager.connectionManager = mockConnectionManager
    }

    func testActiveTimerSync() {
        let timer = NetworkActiveTimer(
            sessionID: UUID(),
            startTime: Date(),
            pausedTime: nil,
            totalPausedDuration: 0,
            isRunning: true,
            isPaused: false,
            deviceID: "test-device",
            deviceName: "Test Device",
            lastUpdateTime: Date(),
            elapsedTime: 0
        )

        syncManager.syncActiveTimer(timer)

        XCTAssertTrue(mockConnectionManager.didSendMessage)
        XCTAssertEqual(mockConnectionManager.lastMessageType, .activeTimerUpdate)
    }

    func testConflictResolution() {
        let resolver = ConflictResolver()

        let localTimer = NetworkActiveTimer(/* ... */)
        let remoteTimer = NetworkActiveTimer(/* ... */)

        let resolved = resolver.resolveActiveTimerConflict(local: localTimer, remote: remoteTimer)

        XCTAssertNotNil(resolved)
        // Add specific assertions based on conflict resolution logic
    }
}
```

### Integration Tests

```swift
class NetworkSyncIntegrationTests: XCTestCase {
    func testTwoDeviceSync() async {
        let device1 = NetworkSyncManager()
        let device2 = NetworkSyncManager()

        // Start both devices
        device1.startNetworkSync()
        device2.startNetworkSync()

        // Wait for discovery
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Start timer on device1
        let timer = NetworkActiveTimer(/* ... */)
        device1.syncActiveTimer(timer)

        // Wait for sync
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Verify device2 received the timer
        XCTAssertNotNil(device2.currentActiveTimer)
        XCTAssertEqual(device2.currentActiveTimer?.sessionID, timer.sessionID)
    }
}
```

## Security Considerations

### Message Authentication

```swift
class MessageAuthenticator {
    private let sharedSecret: String

    init(sharedSecret: String = "QuietTimer-LocalSync") {
        self.sharedSecret = sharedSecret
    }

    func signMessage(_ message: SyncMessage) -> String {
        let messageData = try! JSONEncoder().encode(message)
        let combinedData = messageData + sharedSecret.data(using: .utf8)!
        return SHA256.hash(data: combinedData).compactMap { String(format: "%02x", $0) }.joined()
    }

    func verifyMessage(_ message: SyncMessage, signature: String) -> Bool {
        let expectedSignature = signMessage(message)
        return expectedSignature == signature
    }
}
```

### Network Isolation

```swift
extension NetworkSyncManager {
    private func validatePeerDevice(_ result: NWBrowser.Result) -> Bool {
        guard case .service(let name, let type, let domain, let txtRecord) = result.metadata else {
            return false
        }

        // Verify it's our app
        guard type == serviceType else { return false }

        // Check app version compatibility
        if let appVersion = txtRecord?["appVersion"],
           !isCompatibleVersion(appVersion) {
            return false
        }

        // Additional validation can be added here
        return true
    }

    private func isCompatibleVersion(_ version: String) -> Bool {
        // Implement version compatibility logic
        return true
    }
}
```

## Deployment Considerations

### Feature Flags

```swift
struct NetworkSyncFeatureFlags {
    static let isEnabled = Bundle.main.object(forInfoDictionaryKey: "NetworkSyncEnabled") as? Bool ?? false
    static let maxConnections = Bundle.main.object(forInfoDictionaryKey: "NetworkSyncMaxConnections") as? Int ?? 5
    static let heartbeatInterval = Bundle.main.object(forInfoDictionaryKey: "NetworkSyncHeartbeatInterval") as? TimeInterval ?? 30.0
}
```

### Logging & Analytics

```swift
class NetworkSyncLogger {
    static func logSyncEvent(_ event: SyncEvent) {
        let logData: [String: Any] = [
            "event": event.type,
            "timestamp": Date(),
            "deviceCount": event.deviceCount,
            "success": event.success
        ]

        // Log to analytics service
        Analytics.track("network_sync_event", properties: logData)
    }
}

struct SyncEvent {
    let type: String
    let deviceCount: Int
    let success: Bool
}
```

## Future Enhancements

### Potential Features

1. **Mesh Networking**: Support for multi-hop connections
2. **Offline Queue**: Queue messages when devices are disconnected
3. **Bandwidth Optimization**: Compress messages for slower networks
4. **Device Prioritization**: Prefer certain devices for sync
5. **Selective Sync**: Choose what data to sync per device

### Migration Path

- Start with basic timer sync
- Add session history sync
- Implement advanced conflict resolution
- Add mesh networking capabilities
- Optimize for performance and battery life
  </rewritten_file>
