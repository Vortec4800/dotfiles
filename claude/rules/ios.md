---
paths:
  - "**/*.swift"
  - "**/*.{m,mm}"
  - "**/*.xcodeproj/**"
  - "**/*.xcworkspace/**"
  - "**/*.xcconfig"
  - "**/*.xcscheme"
  - "**/*.xcstrings"
  - "**/*.entitlements"
  - "**/*.xcassets/**"
  - "**/*.{storyboard,xib}"
  - "**/Info.plist"
  - "**/Podfile"
  - "**/.swiftlint.yml"
---

# iOS / Swift platform rules

**Scope: iOS/Swift projects only.** Everything in this section applies exclusively to iOS app development using Swift and SwiftUI.

### Xcode MCP (REQUIRED)

**All Xcode operations MUST go through the Xcode MCP server** (tools named `mcp__xcode__*`). Never use `xcodebuild` shell commands.

**One carve-out:** the built-in simulator tooling's `build` action may produce the `.app` for a Simulator drive-it session (see **Simulator & Device Interaction**). Xcode MCP stays the builder of record for compilation, diagnostics, and tests — this exception is about getting a launchable bundle, not about where you check for build errors.

This section describes the **Xcode 27** MCP server. If a tool named here is absent at runtime, enumerate what the session actually exposes and work from that rather than guessing at a near-miss name.

#### Targeting a workspace

`workspaceIdentifier` is **optional** on every tool that takes it — omit it and the server acts on the workspace Xcode already has open. Pass it (an identifier like `workspace1`, or an absolute path) when more than one workspace is open, or when driving headless.

- `XcodeListWorkspaces` — what's currently open, with each identifier and path.
- `XcodeOpenWorkspace` — takes an absolute path to a `.xcworkspace` or `.xcodeproj` and returns its identifier. **If nothing is open, open it yourself** instead of asking the user to.
- `XcodeCloseWorkspace` — only for workspaces you opened.

#### Active scheme, run destination, test plan

Building, running, previewing, and testing all act on whatever is **active**. Verify it rather than assuming — a wrong active destination is a common cause of confusing build or preview failures.

| Purpose | Tools |
|---|---|
| **Schemes** | `XcodeListSchemes` → `XcodeSwitchScheme` |
| **Run destinations** | `XcodeListRunDestinations` → `XcodeSwitchRunDestination` (pass the `displayTitle`) |
| **Test plans** | `XcodeListTestPlans` → `XcodeSwitchTestPlan` |
| **Targets** | `XcodeListTargets` (filter with `productTypeFilter`) |

`XcodeSwitchScheme` may auto-adjust the run destination, including to a different *variant* of a similar-looking name — read the `activeDestinationDisplayTitle` it returns instead of assuming the destination held. Each list tool caps inline results and writes the full, grep-friendly list to a `full*ListPath`.

#### Tool usage

**For existing files, always use standard filesystem tools** (`Read`, `Edit`, `Write`) — NOT Xcode MCP equivalents. Use Xcode MCP file tools only for operations that modify project structure.

| Operation | Tool |
|---|---|
| **Read existing file** | `Read` (standard) |
| **Edit existing file** | `Edit` (standard) |
| **Overwrite existing file** | `Write` (standard) |
| **Create new file** | `XcodeWrite` (adds to Xcode project automatically) |
| **Delete file** | `XcodeRM` (removes from project; also trashes the file unless `deleteFiles: false`) |
| **Move/rename file** | `XcodeMV` (also does `operation: "copy"`) |
| **Create directory** | `XcodeMakeDir` |
| **Search by pattern** | `Glob` (standard) preferred, or `XcodeGlob` |
| **Search by content** | `Grep` (standard) preferred, or `XcodeGrep` |
| **Browse project structure** | `XcodeLS` |

`XcodeRead` and `XcodeUpdate` also exist (project-path read and string-replace edit). **Don't reach for them** — they JSON-escape their content in both directions and cap reads at 600 lines, so `Read`/`Edit` on the absolute path is both safer and easier to reason about. They are for the rare case where only the project-organization path is known.

Xcode MCP paths are **project-relative** (e.g., `MyApp/Classes/AppDelegate.swift`), not absolute filesystem paths.

#### Building & diagnostics

- **Build**: `BuildProject`. Pass `buildForTesting: true` to include test targets a plain build would skip.
- **Build results**: `GetBuildLog` — `severity` (`error` / `warning` / `remark`, **defaults to `error`**), `pattern` to regex the message, `glob` to scope to a file. Its response also says whether a build is still running.
- **File diagnostics**: `XcodeRefreshCodeIssuesInFile` for compiler errors/warnings/notes on a single file, without a full build.

For a whole-project picture, build and then widen `GetBuildLog` to `severity: "warning"`.

#### Testing

- **Discover tests**: `GetTestList` — 100 inline, with the complete list written to `fullTestListPath` in grep-friendly form (`TEST_TARGET`, `TEST_IDENTIFIER`, `TEST_FILE_PATH`). Grep that file rather than paging the tool.
- **Run all tests**: `RunAllTests`
- **Run specific tests**: `RunSomeTests` (takes `[{ targetName, testIdentifier }]` — build these from `GetTestList`'s `targetName` and `identifier` fields)

All three run the **active scheme's active test plan** — switch it with `XcodeSwitchTestPlan` first if that isn't the plan you mean.

#### Running, console, and the debugger

- **Run**: `RunProject` (Cmd+R; returns once launched). `attachDebugger: true` is required if you intend to debug.
- **Stop**: `StopProject` (Cmd+.).
- **Logs**: `GetConsoleOutput` — stdout/stderr and OSLog, with `pattern`, `contextLines`, `oslogSeverity`, and `tailLimit` (default: last 500 lines).
- **Debug**: `InvokeDebuggerCommand` sends raw lldb into Xcode's active session, sharing state with the Xcode UI. **Call `process status` first** to learn whether the process is stopped before issuing anything that requires it (expressions, `frame variable`). Raise `timeout` for commands that resume execution.

`RunProject` builds before it runs, which makes it the **preferred way to get the app running** — see **Simulator & Device Interaction** for how that interacts with driving the UI.

#### SwiftUI Previews

`RenderPreview` builds and snapshots a `#Preview` macro or `PreviewProvider`.

- `previewDefinitionIndexInFile` (0-indexed) for files with multiple previews.
- `previewVariantOverrides` (e.g. colour scheme, dynamic type) and `previewLocalizationOverride` (a locale like `"fr"`) render the variants without editing the preview. Each call reports the legal keys and values in `supportedPreviewVariantOverrides` / `supportedLocalizations` — **read those from a first call rather than guessing**.
- `previewCanvasControlOverrides` drives canvas controls that only some preview kinds have: `timelineIndex` (widgets, Live Activities), `groupItemIndex` (previews with an `arguments:` parameter), `toggleState`. Legal values likewise come back in `supportedCanvasControlOverrides`.
- `timeout` defaults to 120s.

#### UI development workflow

When making SwiftUI changes, follow this edit-render-review loop:

1. **Edit** the view using `Edit` (existing files) or `XcodeWrite` (new files).
2. **Render** the preview using `RenderPreview` to get a visual snapshot.
3. **Review** the rendered preview to verify the change looks correct.
4. **Iterate** — if the preview doesn't match expectations, go back to step 1 and adjust.
5. **Validate end-to-end** — once the change looks correct in previews, get the app running in the Simulator and exercise the feature there (real navigation, state, and data flows) before considering the work done. See **Simulator & Device Interaction** below for which toolset to use.

#### Project & target configuration

**Never read or hand-edit `project.pbxproj`, `Info.plist`, or the entitlements file to change settings.** Use the tools — they keep the project consistent and survive Xcode rewriting the file underneath you.

| Change | Tool |
|---|---|
| **Read build settings** | `GetTargetBuildSettings` (per target) |
| **Set/append/delete a build setting** | `UpdateTargetBuildSetting` (omit `buildSettingValue` to delete; don't turn `"NO"` into `"false"`) |
| **Info.plist key** | `AddInfoPlist` — privacy usage strings, orientations, URL schemes, background modes, ATS. Use it **even when `GENERATE_INFOPLIST_FILE` is on** |
| **Entitlement** | `AddEntitlement` — only for capabilities actually gated by code signing (App Groups, push, iCloud, privileged IPC). Most frameworks need nothing; privacy strings are Info.plist, not entitlements |
| **Per-file compiler flags** | `GetFileCompilerFlags` / `UpdateFileCompilerFlags` — rare, and largely inert on Swift files since the compilation unit is the module. Prefer `OTHER_SWIFT_FLAGS` at target level |

Every target-scoped tool above takes an optional `projectPath` — needed only when the same target name exists in more than one project in the workspace.

**The one place hand-editing is still correct** is the build-versioning setup in `~/.claude/rules/ios-build-versioning.md` (it loads by itself when you open an `.xcconfig`, `.xcscheme`, `project.pbxproj` or `Info.plist`; Read it first if you get there another way): a project-level `baseConfigurationReference`, a project-level `buildSettings` entry, and a scheme pre-action are all out of reach of `UpdateTargetBuildSetting` (which is target-scoped). That procedure remains a deliberate `project.pbxproj` / `.xcscheme` edit with Xcode quit.

#### Creating projects & targets

`XcodeListTemplates` first, to get the `templateIdentifier` and the option schema — **always pass a filter** (`platformFilter: ["ios"]`, `categoryFilter`, `nameFilter`, or a known `templateIdentifier`); the unfiltered listing is ~200 templates and returns empty option schemas. Then `XcodeNewProject` (writes to disk; follow with `XcodeOpenWorkspace`) or `XcodeNewTarget` (`embedInAppNamed` for extensions and widgets, which inherits the host's bundle-id prefix).

Some templates derive a target name from `productName` (Widget Extension appends `Extension`) — use the `targetName` in the response for later calls, not what you passed in.

#### Localization

`StringCatalogRead`, `StringCatalogContext`, `StringCatalogEdit`, and `LocalizationPlanner` **require the `xcode-integration:translation` / `xcode-integration:translation-coordinator` skill to be activated first** — their own descriptions mandate it. If that skill isn't available in the session, say so and stop rather than calling them blind.

#### Field diagnostics (shipped app)

Xcode MCP reaches Apple's crash and performance reporting for the real user base. Bundle id and platform resolve from the active scheme and run destination when omitted; `is_beta` selects TestFlight vs App Store.

- **Crashes**: `GetTopCrashIssues` (by device count, last 14 days) → `GetCrashIssueLogs` for a `signature_name`, which returns logs plus Apple's triage guidance.
- **Performance**: `GetTopFieldPerformanceIssues` → `GetFieldPerformanceIssueLogs`, with `diagnostic_type` one of `launches`, `hangs`, `diskwrites`, `energy`.

#### Code execution & documentation

- **Execute in context**: `RunCodeSnippet` — builds and runs a snippet with access to a source file's scope, `fileprivate` included; output is whatever the snippet `print`s. Requires a `purpose` string, and that string must not contain the word "test" (it misleads the user into thinking this is test infrastructure).
- **Search Apple docs**: `DocumentationSearch` — semantic search, optionally scoped with `frameworks`.

#### Device interaction tools

Xcode MCP carries its own device and simulator driving path — `DeviceInteractionStartSession`, `DeviceInteractionStartWorkspaceSession`, `DeviceInteractionInstallAndRun`, `DeviceInteractionSynthesize`, `DeviceInteractionEndSession`. It is the only path that reaches physical hardware. See **Simulator & Device Interaction** below for when to choose it and how to use it.

### Simulator & Device Interaction

Three toolsets can drive a running app, and which ones exist depends on the client. **Check what this session actually has before reaching for any of them.**

| Toolset | Available when | Role |
|---|---|---|
| `mcp__Claude_Code_iOS_Simulator__*` | present in the client (the usual case) | **Default for Simulator work** — live panel the user can watch, screenshots, coordinate input |
| Xcode MCP `DeviceInteraction*` | Xcode MCP is connected (required on these projects, so effectively always) | **Physical devices**, and any time you need dependable tap targets or build→install→run in one call |
| `rocketsim` skill | the skill is present | **Last resort**, when neither of the above is available |

The `rocketsim` skill's own description tells you to use it for *any* Simulator interaction. **This section overrides that.** The skill is the last resort, not the default.

**Physical hardware is reachable.** `DeviceInteractionStartSession` takes a device UUID/ECID/name and drives real iPhones and iPads; `DeviceInteractionInstallAndRun` builds and installs to them. The built-in panel and RocketSim remain Simulator-only — when the target is real hardware, that is the Xcode MCP path, and say plainly that the live panel won't show it.

#### Getting the app running

Two Xcode MCP tools **build before they run**, so neither can execute a stale bundle:

- `RunProject` — the Cmd+R equivalent, with `GetConsoleOutput` and `InvokeDebuggerCommand` available against it.
- `DeviceInteractionInstallAndRun` — builds, installs, and launches on the session's device. Re-run it after **every** project change, or you are interacting with the previous build.

**Launch the app yourself with one of these. Ask the user to build and run only when both are unavailable or have failed.** Building first is what makes this safe: the hazard to avoid is exercising a bundle you didn't build, because that silently verifies stale code.

#### Built-in simulator tooling (default for the Simulator)

`mcp__Claude_Code_iOS_Simulator__control` covers the whole loop: `attach`, `launch`, `screenshot`, `tap`, `swipe`, `touch_path`, `touch2_path`, `text`, `button`, `open_url`, `detach`.

- **`attach` first, before building.** It is cheap, opens instantly on a booted simulator, and surfaces the one-time device-access prompt while the user is still at the keyboard. If nothing is booted it errors harmlessly — boot or build, then retry. Don't lean on `launch`'s implicit re-attach; the panel should be open *while* the build runs.
- **The panel is the user's view, not yours.** `screenshot` and the input actions are headless and work without it. Verify your own work — never ask the user to look and report back. Skip the panel entirely when the ask is build-only or unit-tests-only.
- **You may `launch` an app you built in this session — never a pre-existing `.app` on disk.** The stale-build hazard is real; it is defused by controlling *which* bundle you launch. If you didn't produce the `.app` this session, use `RunProject` rather than launching what's already there.
- Coordinates are **device points, origin top-left**; `launch` reports the device's point dimensions. A `swipe`/`touch_path` starting within 4pt of a screen edge fires the OS edge gesture (back / notification shade / home / Control Center) instead of dragging — start further in to scroll content near the bezel.
- If `attach` fails, act on the error's remediation instead of retrying in a loop. Xcode setup failures (wrong `xcode-select`, missing iOS platform) generally need the user's password — surface the exact fix and stop.

#### Xcode MCP device interaction

`DeviceInteractionStartSession` (cannot build) or `DeviceInteractionStartWorkspaceSession` (can build and install) → `DeviceInteractionSynthesize` → `DeviceInteractionEndSession`. Start the session **early**, since it finds and boots the device while other work proceeds, and **always end it** — sessions are expensive and affect the user-facing UI.

`Synthesize` returns **filesystem paths, not content**: `screenshotPath`, `hierarchyPath`, `logsPath`, `thumbnailScreenshotPath`. `Read` the ones you need. Called with no `interactionCommand`, it just captures current state.

**The hierarchy dump is the reason to prefer this path.** Every element carries its type, frame, `identifier`, `label`, and a precomputed **`hitPoint`**. Tap the `hitPoint` — never eyeball a coordinate off a screenshot or compute a frame's centre yourself.

Two live caveats, both verified against Xcode 27.0 (27A266):

- `StartSession` instructs you to load a `device-interaction` skill and perform all interactions in a subagent. **That skill is not available in Claude Code**, and the tools work correctly when called directly. Treat the subagent instruction as being about keeping bulky hierarchy dumps out of the main context — use a subagent when the interaction will be long, not merely because the tool said so.
- Because that skill is missing, the `interactionCommand` grammar is mostly undocumented here. `t <x> <y>` taps. An invalid command is rejected with a pointer to the absent skill and **no list of valid commands**. If you need swipes, typing, or hardware buttons and cannot establish the syntax, drive the Simulator with the built-in tooling instead of guessing at commands.

#### RocketSim (last resort)

When neither of the above is available, the **`rocketsim` skill** drives the Simulator: reading visible accessibility elements, tapping, typing, swiping, scrolling, hardware buttons, Face ID prompts. Prefer it over ad-hoc simulator automation.

RocketSim does **not** build, install, or launch apps — get the app running with `RunProject` first, then drive it with RocketSim.

**Escape hatch for a tap target you can't pin down:** `DeviceInteractionSynthesize`'s `hitPoint` is the first answer. Failing that, a RocketSim snapshot names the element and you tap through the built-in tooling. Element discovery only — don't drift back into driving the whole session with it.

**It is okay to ask the user for help.** Simulator automation is finicky — landing a tap on a specific button, getting the right app loaded, stopping the app. Rather than burning many cycles getting a hit point just right, **just ask**. They can tap a button in a couple of seconds, and they're fine with being asked.

### Swift & SwiftUI Conventions

#### Language & framework

- **SwiftUI exclusively** — no UIKit unless absolutely necessary
- **Swift 6 concurrency**: New projects use `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY`, so all types are implicitly `@MainActor` unless opted out with `nonisolated`. Older projects may still be on Swift 5 without either setting — check the target's `SWIFT_VERSION` and isolation settings (`GetTargetBuildSettings`) before relying on them
- **Async/await** for all asynchronous operations — no Combine, no completion handlers
- Use `Task` for fire-and-forget async work; track and cancel tasks explicitly when needed

#### State management

- Use Swift's `@Observable` macro (Observation framework) — no third-party state management
- Use `@Bindable` in views for two-way bindings to `@Observable` objects
- App-wide state lives in singleton `@Observable` classes (e.g., `AppState`)

#### Models

- `Codable` structs with `CodingKeys` for snake_case-to-camelCase mapping
- Conform to `Identifiable` and `Hashable` for SwiftUI list rendering
- Use enums for discrete types (status, category, etc.) with `Codable` conformance
- Provide `#if DEBUG` preview sample data for SwiftUI previews

#### Services

- Services are **enums with static methods** (no instances, no protocols)
- Services handle networking, business logic, and error classification
- Views call services; services call the backend — views never call the backend directly

#### Navigation

- `NavigationStack` with `NavigationPath` for type-safe programmatic navigation
- Destination enum pattern: `enum Destination: Hashable { case detail(Item) }`
- Sheets/modals via `.sheet(isPresented:)` or `.sheet(item:)`

#### Error handling

- Custom `Error` enums conforming to `LocalizedError` for user-facing errors
- Error classification methods to map raw errors to typed app errors
- UI shows error states with retry options
- Non-critical failures are fire-and-forget with logging

#### SwiftUI views

- Every new SwiftUI view **must** include a `#Preview` at the bottom of the file
- Use modern `#Preview` macro syntax (not legacy `PreviewProvider`)
- For multiple configurations, create separate named previews: `#Preview("Name") { ... }`
- For sheets, wrap in a parent: `#Preview { Text("BG").sheet(isPresented: .constant(true)) { MyView() } }`
- Prefer reusing existing components before creating new ones
- Only create a new reusable component if it is truly unique and will be used in multiple places

### Logging (iOS)

**Never use `print()` or `NSLog()`.** Use `PLLog()` from `Platform_Swift` instead. SwiftLint enforces this in non-test files.

```swift
import Platform_Swift

PLLog("Message", level: .info)     // .error, .warning, .info, .verbose
```

### SwiftLint

SwiftLint is configured via `.swiftlint.yml` in each project. **It runs as the SwiftLintPlugins build tool plugin, not a Homebrew-dependent Run Script** — Read `~/.claude/rules/ios-swiftlint.md` before setting up or repairing lint on a project, or when `swiftlint` isn't on `PATH`. Common configuration:

- **Disabled rules**: `line_length`, `force_cast`, `force_try`, `function_body_length`, `cyclomatic_complexity` — intentionally relaxed
- **Enabled opt-in**: `indentation_width` and various performance/style rules
- **Custom rules**: `print()` and `NSLog()` forbidden (use `PLLog`); `WARNING:` comments flagged as compiler warnings

```bash
<plugin-binary> lint --quiet   # Lint — the binary path is in ios-swiftlint.md
<plugin-binary> --fix          # Autocorrect
```

### Common Dependencies (iOS)

These are frequently used across projects (check each project's Package.swift/Podfile for specifics):

- **Platform_Swift**: Internal utility framework (logging via `PLLog`, etc.)
- **Firebase**: Analytics, Remote Config, Push Notifications
- **Kingfisher**: Image loading and caching (configure disk cache with appropriate limits)

### Project Structure Convention (iOS)

Projects use **file system synchronized groups** — files added to the source directory are automatically picked up by Xcode without manual project file edits.

Typical structure:
```
AppName/
  Classes/
    App/           # AppState, config, constants
    Models/        # Codable domain models
    Services/      # Service enums with static methods
    Views/         # SwiftUI views, organized by feature
    Additions/     # Extensions
  Resources/
    Assets.xcassets
```
