# CloudKit Sync Implementation Specification

## Overview

CloudKit-based synchronization for QuietTimer app to sync timer sessions and active timer state across multiple devices using the same iCloud account.

## Prerequisites

### Apple Developer Account

- **Required**: Paid Apple Developer Program membership ($99/year)
- **Capabilities**: CloudKit, Sign in with Apple (optional)
- **Bundle ID**: Must be registered with CloudKit capability enabled

### App Configuration

```swift
// Required capabilities in project settings:
// - CloudKit
// - Background App Refresh (for sync)
// - Push Notifications (for real-time updates)
```

## Data Model

### CloudKit Schema

#### TimerSession Record Type

```swift
// CKRecord type: "TimerSession"
struct CloudKitTimerSession {
    // System fields
    let recordID: CKRecord.ID
    let recordType: String = "TimerSession"
    let creationDate: Date
    let modificationDate: Date

    // Custom fields
    let sessionID: String           // UUID string
    let startTime: Date
    let endTime: Date?              // nil for active timers
    let duration: Double            // TimeInterval
    let isActive: Bool
    let deviceName: String          // Device identifier
    let appVersion: String

    // Optional fields
    let notes: String?
    let tags: [String]?
}
```

#### ActiveTimer Record Type

```swift
// CKRecord type: "ActiveTimer"
// Single record per user for current active timer
struct CloudKitActiveTimer {
    let recordID: CKRecord.ID = CKRecord.ID(recordName: "activeTimer")
    let recordType: String = "ActiveTimer"

    let sessionID: String?          // Reference to TimerSession
    let startTime: Date?
    let pausedTime: Date?
    let totalPausedDuration: Double
    let isRunning: Bool
    let isPaused: Bool
    let deviceName: String
    let lastUpdateTime: Date
}
```

#### UserPreferences Record Type

```swift
// CKRecord type: "UserPreferences"
struct CloudKitUserPreferences {
    let recordID: CKRecord.ID = CKRecord.ID(recordName: "userPreferences")
    let recordType: String = "UserPreferences"

    let defaultTimerDuration: Double
    let soundEnabled: Bool
    let soundName: String
    let vibrationEnabled: Bool
    let backgroundSyncEnabled: Bool
}
```

## Implementation Architecture

### Core Components

#### 1. CloudKitManager

```swift
class CloudKitManager: ObservableObject {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isSignedIn: Bool = false

    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }

    init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        publicDatabase = container.publicCloudDatabase
    }
}
```

#### 2. Sync Operations

##### Account Status Check

```swift
func checkAccountStatus() async -> CKAccountStatus {
    return await container.accountStatus()
}

func setupCloudKitSubscriptions() async throws {
    // Subscribe to TimerSession changes
    let sessionSubscription = CKQuerySubscription(
        recordType: "TimerSession",
        predicate: NSPredicate(value: true),
        options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
    )

    // Subscribe to ActiveTimer changes
    let activeTimerSubscription = CKQuerySubscription(
        recordType: "ActiveTimer",
        predicate: NSPredicate(value: true),
        options: [.firesOnRecordUpdate]
    )

    try await privateDatabase.save(sessionSubscription)
    try await privateDatabase.save(activeTimerSubscription)
}
```

##### Upload Operations

```swift
func uploadTimerSession(_ session: TimerSession) async throws {
    let record = CKRecord(recordType: "TimerSession")
    record["sessionID"] = session.id.uuidString
    record["startTime"] = session.startTime
    record["endTime"] = session.endTime
    record["duration"] = session.duration
    record["isActive"] = false
    record["deviceName"] = UIDevice.current.name
    record["appVersion"] = Bundle.main.appVersion

    try await privateDatabase.save(record)
}

func uploadActiveTimer(_ timer: ActiveTimerState) async throws {
    let recordID = CKRecord.ID(recordName: "activeTimer")
    let record = CKRecord(recordType: "ActiveTimer", recordID: recordID)

    record["sessionID"] = timer.sessionID?.uuidString
    record["startTime"] = timer.startTime
    record["pausedTime"] = timer.pausedTime
    record["totalPausedDuration"] = timer.totalPausedDuration
    record["isRunning"] = timer.isRunning
    record["isPaused"] = timer.isPaused
    record["deviceName"] = UIDevice.current.name
    record["lastUpdateTime"] = Date()

    try await privateDatabase.save(record)
}
```

##### Download Operations

```swift
func fetchTimerSessions() async throws -> [TimerSession] {
    let query = CKQuery(recordType: "TimerSession", predicate: NSPredicate(value: true))
    query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

    let (records, _) = try await privateDatabase.records(matching: query)

    return records.compactMap { (_, result) in
        switch result {
        case .success(let record):
            return TimerSession(from: record)
        case .failure:
            return nil
        }
    }
}

func fetchActiveTimer() async throws -> ActiveTimerState? {
    let recordID = CKRecord.ID(recordName: "activeTimer")

    do {
        let record = try await privateDatabase.record(for: recordID)
        return ActiveTimerState(from: record)
    } catch CKError.unknownItem {
        return nil // No active timer
    }
}
```

#### 3. Conflict Resolution

```swift
enum ConflictResolutionStrategy {
    case lastWriterWins
    case devicePriority(String) // Preferred device name
    case userChoice
}

func resolveActiveTimerConflict(
    local: ActiveTimerState,
    remote: ActiveTimerState,
    strategy: ConflictResolutionStrategy = .lastWriterWins
) -> ActiveTimerState {

    switch strategy {
    case .lastWriterWins:
        return local.lastUpdateTime > remote.lastUpdateTime ? local : remote

    case .devicePriority(let preferredDevice):
        if local.deviceName == preferredDevice {
            return local
        } else if remote.deviceName == preferredDevice {
            return remote
        } else {
            return local.lastUpdateTime > remote.lastUpdateTime ? local : remote
        }

    case .userChoice:
        // Present UI for user to choose
        // Return placeholder for now
        return local
    }
}
```

#### 4. Background Sync

```swift
// AppDelegate.swift
func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {

    guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
        return .failed
    }

    switch notification.notificationType {
    case .query:
        if let queryNotification = notification as? CKQueryNotification {
            await handleCloudKitNotification(queryNotification)
            return .newData
        }
    default:
        break
    }

    return .noData
}

func handleCloudKitNotification(_ notification: CKQueryNotification) async {
    switch notification.recordType {
    case "TimerSession":
        await syncTimerSessions()
    case "ActiveTimer":
        await syncActiveTimer()
    default:
        break
    }
}
```

## Integration with Existing Code

### TimerSession Extension

```swift
extension TimerSession {
    init?(from record: CKRecord) {
        guard
            let sessionIDString = record["sessionID"] as? String,
            let sessionID = UUID(uuidString: sessionIDString),
            let startTime = record["startTime"] as? Date,
            let duration = record["duration"] as? Double
        else { return nil }

        self.init(
            id: sessionID,
            startTime: startTime,
            endTime: record["endTime"] as? Date ?? startTime.addingTimeInterval(duration),
            duration: duration
        )
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "TimerSession")
        record["sessionID"] = id.uuidString
        record["startTime"] = startTime
        record["endTime"] = endTime
        record["duration"] = duration
        record["isActive"] = false
        record["deviceName"] = UIDevice.current.name
        record["appVersion"] = Bundle.main.appVersion
        return record
    }
}
```

### ViewModel Integration

```swift
class TimerViewModel: ObservableObject {
    @Published var sessions: [TimerSession] = []
    @Published var activeTimer: ActiveTimerState?

    private let cloudKitManager = CloudKitManager()
    private let localStorageManager = LocalStorageManager()

    func startTimer() {
        let newTimer = ActiveTimerState(startTime: Date())
        activeTimer = newTimer

        // Save locally first
        localStorageManager.saveActiveTimer(newTimer)

        // Upload to CloudKit
        Task {
            try await cloudKitManager.uploadActiveTimer(newTimer)
        }
    }

    func stopTimer() {
        guard let timer = activeTimer else { return }

        let session = TimerSession(
            startTime: timer.startTime,
            endTime: Date()
        )

        sessions.append(session)
        activeTimer = nil

        // Save locally
        localStorageManager.saveTimerSession(session)
        localStorageManager.clearActiveTimer()

        // Upload to CloudKit
        Task {
            try await cloudKitManager.uploadTimerSession(session)
            try await cloudKitManager.clearActiveTimer()
        }
    }

    func syncWithCloudKit() async {
        do {
            // Fetch remote data
            let remoteSessions = try await cloudKitManager.fetchTimerSessions()
            let remoteActiveTimer = try await cloudKitManager.fetchActiveTimer()

            // Merge with local data
            await MainActor.run {
                mergeSessions(remoteSessions)
                mergeActiveTimer(remoteActiveTimer)
            }

        } catch {
            print("Sync failed: \(error)")
        }
    }
}
```

## Error Handling

### Common CloudKit Errors

```swift
func handleCloudKitError(_ error: Error) {
    if let ckError = error as? CKError {
        switch ckError.code {
        case .notAuthenticated:
            // User not signed into iCloud
            showSignInPrompt()

        case .quotaExceeded:
            // Storage quota exceeded
            showQuotaExceededAlert()

        case .networkUnavailable:
            // No internet connection
            enableOfflineMode()

        case .serviceUnavailable:
            // CloudKit temporarily unavailable
            scheduleRetry()

        case .requestRateLimited:
            // Too many requests
            backoffAndRetry()

        default:
            showGenericError(ckError.localizedDescription)
        }
    }
}
```

## Testing Strategy

### Unit Tests

```swift
class CloudKitManagerTests: XCTestCase {
    var cloudKitManager: CloudKitManager!

    override func setUp() {
        cloudKitManager = CloudKitManager()
    }

    func testTimerSessionSerialization() {
        let session = TimerSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        let record = session.toCKRecord()
        let deserializedSession = TimerSession(from: record)

        XCTAssertEqual(session.id, deserializedSession?.id)
        XCTAssertEqual(session.duration, deserializedSession?.duration, accuracy: 0.1)
    }

    func testConflictResolution() {
        let localTimer = ActiveTimerState(startTime: Date(), lastUpdate: Date())
        let remoteTimer = ActiveTimerState(startTime: Date().addingTimeInterval(-60), lastUpdate: Date().addingTimeInterval(30))

        let resolved = cloudKitManager.resolveActiveTimerConflict(local: localTimer, remote: remoteTimer)
        XCTAssertEqual(resolved.lastUpdateTime, localTimer.lastUpdateTime)
    }
}
```

### Integration Tests

- Test sync with multiple devices
- Test offline/online scenarios
- Test conflict resolution
- Test background sync

## Performance Considerations

### Optimization Strategies

1. **Batch Operations**: Upload/download multiple records together
2. **Incremental Sync**: Only sync changed records using modification dates
3. **Caching**: Cache frequently accessed data locally
4. **Background Processing**: Perform sync operations in background queues

### Monitoring

```swift
struct SyncMetrics {
    let syncDuration: TimeInterval
    let recordsUploaded: Int
    let recordsDownloaded: Int
    let errors: [Error]
    let timestamp: Date
}

func trackSyncMetrics(_ metrics: SyncMetrics) {
    // Log to analytics service
    // Monitor performance over time
}
```

## Security & Privacy

### Data Protection

- All data stored in user's private CloudKit database
- Encrypted in transit and at rest by Apple
- No access to other users' data

### Privacy Considerations

- Minimal data collection (only timer sessions)
- No personal information beyond iCloud account
- User controls sync via iCloud settings

## Deployment Checklist

### Pre-Release

- [ ] CloudKit schema deployed to production
- [ ] Push notification certificates configured
- [ ] Background app refresh capability enabled
- [ ] Privacy policy updated
- [ ] TestFlight testing completed

### Post-Release

- [ ] Monitor CloudKit usage metrics
- [ ] Track sync success/failure rates
- [ ] Monitor user feedback
- [ ] Plan for schema migrations if needed

## Future Enhancements

### Potential Features

1. **Family Sharing**: Share timers within family group
2. **Selective Sync**: Choose which data to sync
3. **Export/Import**: Backup data outside CloudKit
4. **Analytics**: Track usage patterns (privacy-compliant)
5. **Collaboration**: Real-time shared timers

### Migration Strategy

- Version CloudKit schema for future changes
- Maintain backward compatibility
- Provide data migration tools if needed
