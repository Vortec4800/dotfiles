---
paths:
  - "**/.swiftlint.yml"
  - "**/*.xcodeproj/project.pbxproj"
  - "**/Package.resolved"
---

# iOS SwiftLint — platform rules

**SwiftLint runs as the `SwiftLintBuildToolPlugin` from the SwiftLintPlugins package, not as a Run Script that finds a Homebrew `swiftlint` on `PATH`.** A missing binary is then a build *error*; the Run Script version skips lint silently.

#### The anti-pattern (when you find it, point it out and offer the migration below)

Older projects have a "Run SwiftLint" Run Script phase like:

```sh
export PATH="$PATH:/opt/homebrew/bin"
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

**On machines with endpoint-security software this can quietly stop linting.** The security agent can quarantine the Homebrew binary (`/opt/homebrew/Cellar/swiftlint/<ver>/bin/swiftlint` → "permission denied" / "operation not permitted"), and a `brew reinstall` can be re-quarantined within about an hour. The script then takes its `else` branch — one warning line nobody reads — so builds look clean and commits go out unlinted. **Do not strip the quarantine attribute or build around it**; that is a security-control decision for the user and IT.

Symptoms: `swiftlint` in a terminal fails with a permission error, and a build shows no SwiftLint warnings at all, even ones you know exist.

#### Migration

No Xcode MCP tool adds a package or a build tool plugin, so **the user does steps 1–4 in Xcode** (about a minute); hand-editing `project.pbxproj` for this needs their explicit approval and Xcode closed.

1. **File ▸ Add Package Dependencies…** → `https://github.com/SimplyDanny/SwiftLintPlugins` (the README's recommended source; same releases as `realm/SwiftLint`). Dependency rule **Up to Next Major Version** — deliberate: lint updates arrive automatically, as `brew upgrade` used to deliver them. Add to Target: **None** for every product; plugins aren't linked.
2. For **each** target with Swift sources — app, unit tests, UI tests, extensions — **Build Phases ▸ Run Build Tool Plug-ins ▸ + ▸ SwiftLintBuildToolPlugin**. The plugin lints only the targets it is attached to; the old Run Script linted the whole repo in one pass.
3. **Delete the old Run Script phase.**
4. **⌘B → Trust & Enable** when Xcode asks (see *Plugin trust* if it doesn't).

Then, before committing:

5. **Read the whole `project.pbxproj` diff.** Xcode's UI edit can write unrelated changes. In one project it copied xcconfig `INFOPLIST_KEY_*` values (display name, Face ID usage string) into *target-level* settings for every configuration; target settings override the xcconfig, so one regional edition would have shipped another region's Face ID prompt. Remove such copies with `UpdateTargetBuildSetting` (omit the value to delete). A `.xcscheme` that changed only in XML escaping (`'` → `&apos;`) is harmless re-serialisation.
6. **Check the active scheme and run destination.** Re-resolving packages can switch Xcode to a dependency's scheme (one project landed on a package's scheme with destination *My Mac*), and builds then succeed while building the wrong thing.
7. Commit `project.pbxproj` and `Package.resolved` together.

#### Which config it uses

The plugin passes **no `--config`**. For each Swift file it walks from the directory containing the `.xcodeproj` *down* toward the file and uses the **topmost** directory holding a `.swiftlint.yml` as SwiftLint's working directory. Consequences:

- A `.swiftlint.yml` **above** the `.xcodeproj`'s directory is never found; SwiftLint then runs with its defaults, silently. Put a `.swiftlint.yml` beside the project (it can be a one-line `parent_config: ../.swiftlint.yml`).
- A nested `.swiftlint.yml` deeper in the tree is ignored in favour of the topmost one.
- Swift files outside the project directory make the plugin fail the build.

**Verify, don't assume.** Lint once with an empty config and compare against the build's warnings — e.g. a config that sets `identifier_name.min_length: 2` makes the build say "between **2** and 40 characters", where defaults say 3 (as an *error*), and the defaults' hundreds of `line_length` / `trailing_whitespace` warnings are absent.

#### Plugin trust

- Xcode stores **one trusted fingerprint per plugin per machine** (`~/Library/org.swift.swiftpm/security/plugins.json`, keyed by package identity + target). Another project that trusted a different SwiftLintPlugins version makes Xcode disable this one — `Plugin "SwiftLintBuildToolPlugin" … was disabled because it has changed (previous fingerprint was …)` — reported against `Path+Helpers.swift` inside the package checkout, **with no Trust prompt and nothing in the Issue Navigator**. Fix: the user empties the stale entry (`printf '[\n]\n' > ~/Library/org.swift.swiftpm/security/plugins.json` when it is the only one), **quits and reopens Xcode** (trust is cached in memory), then ⌘B → Trust & Enable.
- With *Up to Next Major*, every SwiftLintPlugins update changes the fingerprint, so expect the Trust prompt after updating packages — and projects on different versions will keep invalidating each other. Keep the projects on one machine on the same version.
- **Never set `IDESkipPackagePluginFingerprintValidatation` / `IDESkipMacroFingerprintValidation`**: they trust every plugin and macro on the machine. `-skipPackagePluginValidation` is for unattended CI `xcodebuild` only.
- Xcode MCP may hold **two handles on one project** — a headless `workspace-…` you opened earlier and the user's `windowtab-…` — and they cache trust separately. If the user's ⌘B succeeds but `BuildProject` still fails, re-run `XcodeListWorkspaces`, build with the window's handle, and close headless handles you opened.

#### Linting from the terminal

There is no `swiftlint` on `PATH` any more. Lint before every commit with the plugin's own binary, from the directory holding `.swiftlint.yml`:

```bash
~/Library/Developer/Xcode/DerivedData/<Project>-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint lint --quiet
```

It exists once Xcode has resolved packages. Use the literal path rather than `$(ls …)` — a colourising `ls` alias breaks the substitution. **Never gate a commit on `swiftlint | tail -1 && git commit`**: the pipeline returns `tail`'s status, so a broken linter lets the commit through.

The plugin's binary is the official release artifact (checksum-verified by SwiftPM) — a different file from Homebrew's build, but **endpoint-security software could quarantine it too**. If it does, builds fail loudly rather than skipping lint; the fix is still an IT safelist entry, not a workaround.
