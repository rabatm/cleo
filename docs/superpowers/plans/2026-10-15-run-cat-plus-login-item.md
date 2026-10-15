# RunCatPlus Login Item Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Lancer au démarrage" toggle in the menu-bar popover that writes or removes a `launchd` user agent plist in `~/Library/LaunchAgents`.

**Architecture:** A single `LaunchAgentManager` observable object owns the enabled state, writes the plist, and calls `launchctl load/unload`. `AppState` exposes it, `StatusBarController` passes it to `MenuContentView`, and `MenuContentView` binds it to a SwiftUI `Toggle`.

**Tech Stack:** Swift, SwiftUI, AppKit, `Foundation.Process`, `launchd` user agents.

**Spec:** `docs/superpowers/specs/2026-10-15-run-cat-plus-login-item-design.md`

## Global Constraints

- Target: macOS (current build target is arm64-apple-macosx27.0.0).
- No `@MainActor` isolation on the AppKit entry path (see existing comments in `RunCatPlusApp.swift` and `StatusBarController.swift`).
- `ObservableObject`/`@Published` is the existing state mechanism.
- App is not sandboxed and is distributed outside the Mac App Store.
- Plist label: `com.runCatPlus.startup`.
- Plist path: `~/Library/LaunchAgents/com.runCatPlus.startup.plist`.

---

### Task 1: Create `LaunchAgentManager`

**Files:**
- Create: `RunCatPlus/Launch/LaunchAgentManager.swift`
- Modify: none
- Test: manual (see Step 6)

**Interfaces:**
- Consumes: `Bundle.main.bundleURL`, `NSHomeDirectory()`, `FileManager`.
- Produces:
  - `final class LaunchAgentManager: ObservableObject`
  - `@Published var isEnabled: Bool`
  - `@Published var lastError: String?`
  - `func setEnabled(_ enabled: Bool)`

- [ ] **Step 1: Create `RunCatPlus/Launch/LaunchAgentManager.swift`**

```swift
import Foundation

final class LaunchAgentManager: ObservableObject {
    static let label = "com.runCatPlus.startup"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var lastError: String?

    private let plistURL: URL

    init() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        plistURL = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(Self.label).plist")
        isEnabled = FileManager.default.fileExists(atPath: plistURL.path)
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        if enabled {
            enable()
        } else {
            disable()
        }
    }

    private func enable() {
        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [Bundle.main.bundleURL.path],
            "RunAtLoad": true,
            "KeepAlive": false,
        ]

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: plistURL, options: .atomic)
        } catch {
            lastError = "Impossible d'écrire le fichier de démarrage : \(error.localizedDescription)"
            return
        }

        runLaunchCtl(arguments: ["load", plistURL.path])
        isEnabled = FileManager.default.fileExists(atPath: plistURL.path)
    }

    private func disable() {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            runLaunchCtl(arguments: ["unload", plistURL.path])
        }
        do {
            try FileManager.default.removeItem(at: plistURL)
        } catch {
            lastError = "Impossible de supprimer le fichier de démarrage : \(error.localizedDescription)"
        }
        isEnabled = FileManager.default.fileExists(atPath: plistURL.path)
    }

    private func runLaunchCtl(arguments: [String]) {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            lastError = "launchctl a échoué : \(error.localizedDescription)"
            return
        }

        if task.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "code \(task.terminationStatus)"
            lastError = "launchctl : \(message)"
        }
    }
}
```

- [ ] **Step 2: Type-check the new file in isolation**

Run:
```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -typecheck RunCatPlus/Launch/LaunchAgentManager.swift
```

Expected: no errors.

- [ ] **Step 3: Commit the new manager**

```bash
git add RunCatPlus/Launch/LaunchAgentManager.swift
git commit -m "Add LaunchAgentManager for startup toggle"
```

---

### Task 2: Wire `LaunchAgentManager` into `AppState`

**Files:**
- Modify: `RunCatPlus/RunCatPlusApp.swift`

**Interfaces:**
- Consumes: `LaunchAgentManager` from Task 1.
- Produces: `AppState.launchAgent: LaunchAgentManager`.

- [ ] **Step 1: Add the property to `AppState`**

In `RunCatPlus/RunCatPlusApp.swift`, add after the existing providers:

```swift
let launchAgent = LaunchAgentManager()
```

The `AppState` class should now look like:

```swift
final class AppState: ObservableObject {
    let cpu = CPUProvider()
    let memory = MemoryProvider()
    let claude = ClaudeProvider()
    let kimi = KimiProvider()
    let launchAgent = LaunchAgentManager()
    // ... timers and init/deinit unchanged
}
```

- [ ] **Step 2: Type-check**

Run the full project type-check command:
```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -typecheck RunCatPlus/main.swift RunCatPlus/RunCatPlusApp.swift RunCatPlus/StatusBarController.swift RunCatPlus/Providers/*.swift RunCatPlus/Views/*.swift RunCatPlus/Launch/*.swift
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add RunCatPlus/RunCatPlusApp.swift
git commit -m "Expose LaunchAgentManager in AppState"
```

---

### Task 3: Pass `launchAgent` through `StatusBarController` to `MenuContentView`

**Files:**
- Modify: `RunCatPlus/StatusBarController.swift`
- Modify: `RunCatPlus/Views/MenuContentView.swift`

**Interfaces:**
- Consumes: `AppState.launchAgent`.
- Produces: `MenuContentView` initializer accepts `launchAgent: LaunchAgentManager`.

- [ ] **Step 1: Update `StatusBarController.togglePopover`**

In `RunCatPlus/StatusBarController.swift`, change the `MenuContentView` construction to include `launchAgent`:

```swift
let content = MenuContentView(cpu: appState.cpu,
                              memory: appState.memory,
                              claude: appState.claude,
                              kimi: appState.kimi,
                              launchAgent: appState.launchAgent)
```

- [ ] **Step 2: Update `MenuContentView`**

In `RunCatPlus/Views/MenuContentView.swift`:

1. Add the property:
```swift
@ObservedObject var launchAgent: LaunchAgentManager
```

2. Replace the divider/quit button section with the toggle + error display + divider + quit button:

```swift
            Divider()

            Toggle("Lancer au démarrage", isOn: Binding(
                get: { launchAgent.isEnabled },
                set: { launchAgent.setEnabled($0) }
            ))
            if let error = launchAgent.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            Button("Quitter RunCatPlus") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
```

- [ ] **Step 3: Type-check**

Run the full project type-check command from Task 2.

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add RunCatPlus/StatusBarController.swift RunCatPlus/Views/MenuContentView.swift
git commit -m "Add startup toggle to menu popover"
```

---

### Task 4: Manual verification

**Files:** none

- [ ] **Step 1: Build the app in Xcode**

Open `RunCatPlus.xcodeproj` in Xcode and press `Cmd+B`. Expected: build succeeds.

- [ ] **Step 2: Enable the toggle**

Run the app, open the menu, enable "Lancer au démarrage".

- [ ] **Step 3: Verify plist exists**

Run:
```bash
ls ~/Library/LaunchAgents/com.runCatPlus.startup.plist
launchctl list | grep runCatPlus
```

Expected: plist file exists and the label appears in `launchctl list`.

- [ ] **Step 4: Disable the toggle**

Toggle off in the menu.

- [ ] **Step 5: Verify plist is removed**

Run:
```bash
ls ~/Library/LaunchAgents/com.runCatPlus.startup.plist
launchctl list | grep runCatPlus
```

Expected: plist is gone and the label no longer appears.

- [ ] **Step 6: Document result**

If any step fails, file a bug with the exact error message. If all pass, the feature is complete.

---

## Spec Coverage

- "Add a Launch at startup toggle in the menu-bar popover" → Task 3.
- "Use a launchd user agent plist in `~/Library/LaunchAgents`" → Task 1.
- "Expose a `@Published var isEnabled`" → Task 1.
- "Expose a human-readable error message" → Task 1 and Task 3.
- "AppState owns a LaunchAgentManager instance" → Task 2.
- "MenuContentView binds a Toggle" → Task 3.
- "Manual verification steps" → Task 4.

## Placeholder Scan

No TBD/TODO/fill-in-details found. Every task includes concrete code, concrete commands, and concrete expected output.
