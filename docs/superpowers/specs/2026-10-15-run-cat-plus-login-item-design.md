# RunCatPlus — Login Item Design

## Objective

Add a "Launch at startup" toggle in the menu-bar popover. When enabled, RunCatPlus starts automatically when the user logs in.

## Context

RunCatPlus is a personal menu-bar utility for macOS. It is not sandboxed and is distributed outside the Mac App Store. The previous UI contained a disabled placeholder button labeled "Ouvrir au démarrage (à configurer dans Réglages Système)".

## Decision

Use a `launchd` user agent plist in `~/Library/LaunchAgents` (Option B). This is the simplest approach for a non-App-Store app and does not require a helper application target.

Rejected alternative: `SMLoginItemSetEnabled` with a helper app (Option A). It is the Apple-recommended approach for App Store apps, but it adds a second binary and complicates the Xcode project and packaging for no benefit in this context.

## Architecture

### New component: `LaunchAgentManager`

Location: `RunCatPlus/Launch/LaunchAgentManager.swift`

Responsibilities:
- Know the label: `com.runCatPlus.startup`
- Build the path to `~/Library/LaunchAgents/com.runCatPlus.startup.plist`
- Expose a `@Published var isEnabled: Bool` property
- Provide `setEnabled(_:)` that writes or removes the plist and runs `launchctl load` / `unload`
- Expose a human-readable error message if something goes wrong

### Integration points

- `AppState` owns a `LaunchAgentManager` instance.
- `MenuContentView` binds a `Toggle("Lancer au démarrage", isOn: $launchAgent.isEnabled)`.

## Data flow

1. User toggles the switch.
2. `LaunchAgentManager.setEnabled(true)`:
   - Builds a plist dictionary with `Label`, `ProgramArguments` pointing to `Bundle.main.bundleURL.path`, `RunAtLoad = true`, `KeepAlive = false`.
   - Writes the plist to `~/Library/LaunchAgents/com.runCatPlus.startup.plist`.
   - Runs `Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["load", plistPath])` and waits for termination.
   - Updates `isEnabled` on success.
3. `LaunchAgentManager.setEnabled(false)`:
   - Runs `launchctl unload plistPath`.
   - Removes the plist.
   - Updates `isEnabled` on success.

## Error handling

- If writing the plist fails, keep the previous state and set `lastError`.
- If `launchctl` fails (e.g., bad path), revert the plist change and report the error.
- Errors are displayed in the menu as a small caption under the toggle.

## UI

Replace the previous disabled button in `MenuContentView` with:

```swift
Toggle("Lancer au démarrage", isOn: $launchAgent.isEnabled)
if let error = launchAgent.lastError {
    Text(error)
        .font(.caption)
        .foregroundStyle(.red)
}
```

## Files touched

- `RunCatPlus/Launch/LaunchAgentManager.swift` (new)
- `RunCatPlus/RunCatPlusApp.swift` (add `LaunchAgentManager` to `AppState`)
- `RunCatPlus/Views/MenuContentView.swift` (add toggle and pass `launchAgent`)
- `RunCatPlus/StatusBarController.swift` (pass `launchAgent` to `MenuContentView`)

## Testing

Manual verification:
1. Enable the toggle.
2. Check that `~/Library/LaunchAgents/com.runCatPlus.startup.plist` exists.
3. Run `launchctl list | grep runCatPlus` and confirm the label is present.
4. Disable the toggle.
5. Confirm the plist is removed and the label disappears from `launchctl list`.

## Notes

- The plist path uses `NSHomeDirectory()` so it works for the current user only.
- `KeepAlive` is `false` so the app can be quit normally without `launchd` restarting it.
- The feature requires that the app is moved to `/Applications` (or another stable path) before enabling, otherwise the login item will break if the app is moved later. `LaunchAgentManager` does not validate the path; the user is responsible for a stable install location.
