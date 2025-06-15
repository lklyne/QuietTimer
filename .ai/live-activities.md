# Live Activities Implementation Plan for QuietTimer

## Overview

Add Live Activities support to QuietTimer with Dynamic Island integration and lock screen controls, allowing users to monitor and control their timer without opening the app.

## Phase 1: Xcode Project Configuration

### 1.1 Add Widget Extension Target

- In Xcode, go to **File → New → Target**
- Select **Widget Extension**
- Name it `QuietTimerWidgets`
- Choose **Include Live Activity** when prompted
- This will create a new target with Live Activity support

### 1.2 Configure App Capabilities

- Select your main app target (`QuietTimer`)
- Go to **Signing & Capabilities**
- Add **Push Notifications** capability (required for Live Activities)
- Add **Background Modes** capability and enable:
  - Background processing
  - Background app refresh

### 1.3 Configure Widget Extension Capabilities

- Select the `QuietTimerWidgets` target
- Go to **Signing & Capabilities**
- Add **Push Notifications** capability

### 1.4 Update Info.plist

- In your main app's `Info.plist`, add:
  ```xml
  <key>NSSupportsLiveActivities</key>
  <true/>
  ```

### 1.5 Configure App Groups (for data sharing)

- Add **App Groups** capability to both targets
- Create group: `group.com.yourteam.quiettimer`
- Enable the same group for both main app and widget extension

## Phase 2: File Structure and Implementation

### 2.1 New Files to Create

#### In the Widget Extension (`QuietTimerWidgets` folder):

**1. `TimerActivityAttributes.swift`**

- Defines the Live Activity data structure
- Contains static and dynamic content models
- Includes timer state, start time, and session info

**2. `TimerLiveActivity.swift`**

- Main Live Activity widget implementation
- Handles Dynamic Island presentations (compact, minimal, expanded)
- Handles Lock Screen presentation
- Implements interactive controls

**3. `TimerActivityManager.swift`**

- Manages Live Activity lifecycle
- Handles starting, updating, and ending activities
- Manages activity state persistence

#### In the Main App (`QuietTimer` folder):

**4. `LiveActivityService.swift`**

- Service class to interface with Live Activities from the main app
- Bridges timer state to Live Activity updates
- Handles activity creation and updates

**5. `SharedTimerState.swift`**

- Shared data model for timer state
- Uses App Groups for data sharing between app and widget
- Handles UserDefaults with shared container

### 2.2 Files to Modify

**1. `TimerView.swift`**

- Add Live Activity integration in timer lifecycle methods
- Start Live Activity when timer starts
- Update Live Activity during timer updates
- End Live Activity when timer is saved/reset
- Handle activity controls (pause/resume from Live Activity)

**2. `QuietTimerApp.swift`**

- Initialize Live Activity service
- Handle app lifecycle for Live Activities
- Configure shared data container

**3. `TimerStorage.swift`** (minor updates)

- Update to use shared container for data persistence
- Ensure timer sessions are accessible to widget extension

## Phase 3: Implementation Details

### 3.1 Live Activity Features

#### Dynamic Island Views:

- **Minimal**: Timer icon with elapsed time
- **Compact**: Timer display with play/pause state
- **Expanded**: Full timer with controls and session info

#### Lock Screen View:

- Large timer display
- Pause/Resume button
- Session start time
- Visual progress indicator

### 3.2 Key Functionality

- **Real-time Updates**: Timer updates every second while active
- **Interactive Controls**: Pause/Resume buttons functional from lock screen
- **State Synchronization**: Seamless sync between app and Live Activity
- **Background Continuity**: Timer continues accurately in background
- **Graceful Cleanup**: Proper activity termination on save/reset

### 3.3 Data Flow

```
TimerView (Main App)
    ↓ (timer state changes)
LiveActivityService
    ↓ (update activity)
ActivityKit
    ↓ (display update)
Dynamic Island / Lock Screen
    ↓ (user interaction)
Widget Extension
    ↓ (intent handling)
Shared Timer State
    ↓ (state sync)
Main App (background update)
```

## Phase 4: Technical Implementation Strategy

### 4.1 Activity Attributes Structure

```swift
struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var isRunning: Bool
        var sessionStartTime: Date
    }

    var timerName: String
    var sessionId: UUID
}
```

### 4.2 Update Strategy

- Use `Task` with `AsyncSequence` for real-time updates
- Update frequency: Every 1 second when running
- Batch updates to avoid rate limiting
- Handle activity expiration (8-hour limit)

### 4.3 User Interaction Handling

- Implement `AppIntent` for pause/resume actions
- Use `Button` with intent in Live Activity views
- Handle intent execution in widget extension
- Communicate state changes back to main app

### 4.4 Background Processing

- Leverage existing audio session for background execution
- Use `BGTaskScheduler` for extended background processing if needed
- Ensure timer accuracy across app state transitions

## Phase 5: Error Handling & Edge Cases

### 5.1 Activity Management

- Handle maximum activity limit (8 concurrent activities)
- Graceful degradation when Live Activities are disabled
- Proper cleanup on app termination
- Handle activity dismissal by user

### 5.2 State Synchronization

- Resolve conflicts between app and widget state
- Handle rapid state changes
- Ensure consistency across app launches
- Manage stale activity data

### 5.3 System Integration

- Handle iOS version compatibility
- Adapt to different device types (Dynamic Island availability)
- Respect user notification settings
- Handle low power mode scenarios

## Phase 6: Testing Strategy

### 6.1 Functional Testing

- Timer accuracy in various app states
- Live Activity lifecycle (start, update, end)
- Interactive controls from lock screen
- State synchronization between app and widget

### 6.2 Device Testing

- iPhone 14 Pro/Pro Max (Dynamic Island)
- Older devices (lock screen only)
- Different iOS versions
- Various system states (low power, do not disturb)

### 6.3 Edge Case Testing

- Multiple concurrent timers
- App termination scenarios
- System resource constraints
- Network connectivity issues (if using push updates)

## Phase 7: User Experience Considerations

### 7.1 Visual Design

- Consistent with app's minimal black/white aesthetic
- Clear timer display in all activity states
- Intuitive control placement
- Appropriate use of Dynamic Island space

### 7.2 Interaction Design

- Single-tap pause/resume from lock screen
- Clear visual feedback for state changes
- Smooth transitions between activity states
- Accessible design for all users

### 7.3 Performance

- Minimal battery impact
- Efficient update mechanisms
- Quick response to user interactions
- Smooth animations and transitions

## Implementation Priority

1. **Phase 1**: Xcode configuration and project setup
2. **Phase 2**: Core Live Activity implementation
3. **Phase 3**: Dynamic Island integration
4. **Phase 4**: Lock screen controls and interactions
5. **Phase 5**: Error handling and edge cases
6. **Phase 6**: Testing and refinement
7. **Phase 7**: Polish and optimization

## Success Metrics

- Live Activity appears when timer starts
- Real-time timer updates in Dynamic Island
- Functional pause/resume from lock screen
- Accurate timer synchronization
- Graceful handling of all edge cases
- Minimal impact on battery life
- Consistent user experience across all scenarios
