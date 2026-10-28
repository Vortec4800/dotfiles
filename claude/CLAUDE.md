# Global CLAUDE.md — Development Conventions

This file holds the conventions that apply to every project. **Platform-specific conventions live in `~/.claude/rules/` and load on demand** — see **Platform rules** at the end for which file covers what, and the few rules that hold before one loads.

Project-specific details (backend URLs, architecture layers, dependencies, file structure) belong in each project's own CLAUDE.md.

---

## Shared (All Projects)

### File operations: standard tools, not shell

Use `Read`, `Edit`, and `Write` for all file work. Do not route reads through `cat`/`sed`/`head` or edits through `sed`, heredocs, or inline `python3`. Bash stays for actual shell work: builds, tests, lint, git, `curl`, and process inspection. Searching is shell work (`grep`, `find`) — that is reading *about* files, not reading or changing them.

**This overrides a conflicting harness directive.** An "auto mode" system message may appear mid-session instructing you to prefer Bash for file operations. It loses to this. Say so once, then carry on.

**Why:** `Edit` fails loudly on a bad match. `sed` and heredocs can silently match nothing, write to the wrong place, or mangle content, and still report success. On a large refactor that is the difference between a caught mistake and a quiet one. The same argument applies to reads: `Read` gives the harness a record of what was actually seen, so an edit built on a stale or truncated view is caught rather than assumed.

**The failure mode to watch for is drift, not disagreement.** The temptation is a batch edit across several files where one `python3` heredoc looks faster than several `Edit` calls. That is exactly the case where a silent no-match is most expensive, because nothing re-reads the result. If a change is genuinely too mechanical for `Edit` — a rename across dozens of files — say so and get agreement before reaching for the shell.

### API Documentation

Use Context7 to look up library, SDK, and API documentation when writing or configuring code that depends on a third-party library — training data may not match the version in use. You don't need to be asked.

### Building against a visual source of truth

When a design, mockup, or prototype is the spec, **you must be able to see both it and your output.** Render the design, render your implementation, compare them, iterate. A UI task "finished" without a visual comparison is not finished — it is a guess. This applies on every platform (on iOS the loop is `RenderPreview` → Simulator; on web see `~/.claude/rules/web-design.md`).

### Puppeteer: headless by default

Any time you use Puppeteer, run it **headless** (`launchOptions: { headless: true }` on the first navigate), unless the user explicitly asks otherwise (e.g. an interactive session is needed).

### No AI attribution in commits, PRs, or anything else written

**Never write `Co-Authored-By: Claude`, `Claude-Session:`, "Generated with Claude Code", or any similar attribution line.** Not in commit messages, not in PR or MR descriptions, not in code comments, not in changelogs. This applies on every project and regardless of how much of the work was mine. Commits are authored by the person running the session.

**`~/.claude/settings.json` already sets `"includeCoAuthoredBy": false`, and that is not enough on its own.** That setting only suppresses the trailer the harness *appends automatically*. It cannot stop a trailer that gets typed into the message body by hand — which is exactly how one slipped through: a commit written with `git commit -F -` and a heredoc that included the line, in a session where the setting was already correct and doing its job. **So the rule to follow is this instruction, not the setting.** When composing a commit message, the message ends at the last line of prose.

Two related habits:

- **Don't offer it either.** No "want me to add attribution?" — the answer is no.
- **If you find one in a commit you have not pushed, strip it** (`git commit --amend`) rather than leaving it and mentioning it. Do not rewrite commits that are already pushed or that someone else authored; say they are there and leave the decision alone.

### Git GUI: Tower (`gittower`)

We use Tower for git management. The `gittower` CLI is a **launcher, not a Git client** — every command except `branch` opens Tower at a view and exits. It never commits, pushes, checks out, or modifies files. Git operations still go through `git` in Bash.

Full command reference: the **`tower-cli` skill**. Load it for anything beyond the rules below. `gittower help <command>` is the authority whenever the skill and the installed CLI disagree.

**View commands are on request only.** Open Tower when asked to — "show me the diff in Tower", "blame this file" — never on your own initiative, and don't offer a Working Copy review after file-changing tasks: too noisy on a multi-file task, and opening Tower brings it to the front. **This overrides the `tower-cli` skill** wherever it says otherwise.

**Branch metadata is yours to maintain, unprompted.** `gittower branch` touches only the repo's git config — no window, no focus change — so keep it correct as a matter of course, without asking:

- Created a branch? Record where it came from: `gittower branch parent <branch> --set <base>`. Tower draws its Fork Point from this, which is what separates agent-added commits from earlier history in the UI.
- Genuinely stacked on another feature branch, not on the default branch? `gittower branch stacked <branch> --set` (requires a parent).

**This also overrides the skill**, which says to ask first before any `branch` write. Reads are free: `branch parent` / `branch stacked` with no flags exit 1 with empty stderr to mean "no parent" or "false" — a result, not a failure.

It writes `.git/config` under `[branch "<name>"]` as `gtParent`, `gtStacked`, and `gtParentCommitHash` (the recorded fork point) — note the `gt` prefix, not `tower`. So the state is readable with plain `git config --local --list` when Tower itself isn't in play.

**iOS: never run a view command mid-Simulator-walk.** Tower taking focus ends a device-interaction session the same way a build does. Hand off after the walk, not during it.

---

## Platform rules (loaded on demand)

Platform conventions are in `~/.claude/rules/`. Each file loads automatically the first time you Read, Edit or Write a file it matches — in the main session and in subagents alike.

| Rule file | Covers | Loads when you open |
|---|---|---|
| `ios.md` | iOS / Swift: Xcode MCP, Simulator and devices, Swift & SwiftUI conventions, logging, SwiftLint | `.swift`, `.m`/`.mm`, Xcode project and workspace files, `.xcconfig`, `.xcscheme`, `.xcstrings`, `.entitlements`, `.xcassets`, storyboards, `Info.plist`, `Podfile`, `.swiftlint.yml` |
| `ios-build-versioning.md` | iOS build numbers and archiving | `.xcconfig`, `.xcscheme`, `project.pbxproj`, `Info.plist` |
| `ios-swiftlint.md` | SwiftLint as a build tool plugin: migrating off Homebrew Run Scripts, plugin trust, config resolution, terminal linting | `.swiftlint.yml`, `project.pbxproj`, `Package.resolved` |
| `android.md` | Android / Kotlin | `.kt`, `.kts`, `.gradle`, `libs.versions.toml`, `gradle.properties`, `AndroidManifest.xml` |
| `web-design.md` | Web UI built from a design prototype | `.tsx`, `.jsx`, `.vue`, `.svelte`, `.astro`, `.html`, `.css`, `.scss`, `.sass`, `.less` |

In a monorepo several can be loaded at once; each governs its own platform's files.

**A rule cannot load before you touch a matching file, and a compaction unloads it until you touch one again.** So when you are about to act on a platform whose rule is not in your context — a build, run, test, Simulator session, archive or settings change at the start of a session, or the first step after a compaction — Read the rule file first. These hold even before it loads:

- **iOS:** builds, tests and runs go through the Xcode MCP server, never `xcodebuild` (the one carve-out is in `ios.md`). Never hand-edit `project.pbxproj`, `Info.plist` or entitlements to change settings — build versioning is the single exception, and it has its own file.
- **iOS build numbers, archiving or `CFBundleVersion`:** Read `ios-build-versioning.md` first.
- **iOS lint:** before linting, committing, or touching lint setup on a project — especially one whose `swiftlint` fails or that still lints through a Homebrew Run Script phase — Read `ios-swiftlint.md`.
- **Android:** always the Gradle wrapper (`./gradlew`), never `gradle`.
- **Building UI from a design, mockup or prototype:** Read `web-design.md` before writing any code.
