---
paths:
  - "**/*.xcconfig"
  - "**/*.xcodeproj/project.pbxproj"
  - "**/*.xcscheme"
  - "**/Info.plist"
---

# iOS build versioning — platform rules

**The build number is the `CURRENT_PROJECT_VERSION` build setting, fed by an xcconfig. Never patch `CFBundleVersion` into a built product from a build phase.**

Every target's `Info.plist` carries:

```xml
<key>CFBundleShortVersionString</key>
<string>$(MARKETING_VERSION)</string>
<key>CFBundleVersion</key>
<string>${CURRENT_PROJECT_VERSION}</string>
```

`MARKETING_VERSION` is set per target; `CURRENT_PROJECT_VERSION` is regenerated from the git commit count at archive time. Driving a *build setting* rather than editing plists is what makes the app, the watch app, and every extension pick up the same number automatically — App Store validation rejects them when they disagree.

#### The anti-pattern (when you find it, point it out and offer the migration below)

Older projects carry a `Build Number` run-script phase, marked "Run script only when installing", that does:

```sh
versioncount=`git rev-list --count master`
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $versioncount" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
echo "Updated ${PRODUCT_SETTINGS_PATH} to $versioncount"
```

**This silently stopped working in Xcode 26.** Xcode now runs `ProcessInfoPlistFile` for the installed bundle *after* every run-script phase in the target, so PlistBuddy writes to a file that does not exist yet, the `Set` fails, and the archive ships whatever `${CURRENT_PROJECT_VERSION}` resolves to — normally `1`. The trailing `echo` reports success regardless (it prints `PRODUCT_SETTINGS_PATH`, the *source* plist, not what was written), so the build log looks clean. It also only ever touched the main app; extensions matched only because older Xcode propagated the host app's version into embedded bundles, which Xcode 26 no longer does.

No build phase can fix this by reordering — nothing user-scriptable runs between `ProcessInfoPlistFile` and `CodeSign`. The version has to be set before the build, not patched after.

#### Setup

1. **`Resources/Config.xcconfig`** — committed:

   ```
   CURRENT_PROJECT_VERSION = 1

   #include? "Version.xcconfig"
   ```

   The default matters. A `baseConfigurationReference` cannot be optional, so a lone gitignored file would leave a fresh clone with a missing-file warning and an empty `CFBundleVersion`. The optional include overrides the default whenever the generated file is present.

2. **`Resources/Version.xcconfig`** — gitignored, generated, one line:

   ```
   CURRENT_PROJECT_VERSION = 775
   ```

3. Set `Config.xcconfig` as the **project-level** base configuration for both Debug and Release, and **delete any `CURRENT_PROJECT_VERSION` from the project's `buildSettings`** — a value there outranks the base xcconfig and defeats the whole thing. Provided no target sets it (CocoaPods target xcconfigs don't), project level reaches every target.

4. Add a **`Set build number` pre-action on the scheme's *Build* step — not its Archive step** — with "Provide build settings from" pointed at the app target so `$SRCROOT` and `$ACTION` resolve, and let it act only for an archive:

   ```sh
   [ "$ACTION" = "install" ] || exit 0

   count=$(env -u SDKROOT /usr/bin/git -C "$SRCROOT" rev-list --count master)

   if [ -z "$count" ]; then
       echo "error: could not determine build number from git" >&2
       exit 1
   fi

   file="$SRCROOT/Resources/Version.xcconfig"
   line="CURRENT_PROJECT_VERSION = $count"
   [ "$(cat "$file" 2>/dev/null)" = "$line" ] || echo "$line" > "$file"
   ```

   **An Archive pre-action runs too late.** It runs after the build has finished, just before the archive is packaged, so the build reads whatever the *previous* archive wrote: the first archive from a tree with no `Version.xcconfig` ships **1**, and every later one ships the previous archive's count, a duplicate whenever two archives come from one `master` commit. A Build pre-action runs before the build reads its settings, and `ACTION` is `install` there for an archive; anything other than `install` skips, so ordinary builds keep `1`, and the write-only-on-change line keeps an unchanged number from touching the file. Apply any per-app offset here (e.g. adding 500 so a rewrite's builds clear the numbers its predecessor already used). **A `Set build number` pre-action on the Archive step has this bug** — move it to the Build step.

   **`env -u SDKROOT` is load-bearing.** `/usr/bin/git` is the xcrun shim, which finds git through the `SDKROOT` in its environment, and the pre-action inherits the target's build settings. A **multiplatform** target archived for *Any Mac* exports `SDKROOT=auto`, which the shim cannot resolve (`xcodebuild: error: SDK "auto" cannot be located`), so `count` comes back empty and the archive fails on the script's own error line; an iOS archive exports `SDKROOT=iphoneos` and doesn't hit it. Unsetting it lets the shim fall back to the default toolchain. **A pre-action that runs `git` without `env -u SDKROOT` has this bug** on a multiplatform target's Mac archive.

Steps 3 and 4 mean editing `project.pbxproj` and the `.xcscheme`. **Quit Xcode first** — it holds both in memory and will happily overwrite them from its own copy. Validate afterward with `plutil -lint` on the pbxproj and `xmllint --noout` on the scheme.

#### Verify

**Delete `Resources/Version.xcconfig` first**, so a value a previous archive left there cannot pass for this one's, then archive, and check *every* bundle in the `.xcarchive`, not just the app:

```bash
a="$HOME/Library/Developer/Xcode/Archives/<date>/<name>.xcarchive"
app=$(find "$a/Products/Applications" -maxdepth 1 -name "*.app" | head -1)
for p in "$app/Info.plist" "$app"/PlugIns/*.appex/Info.plist "$app"/Watch/*.app/Info.plist; do
    echo "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$p")  $p"
done
```

A `1` anywhere means the setting isn't reaching that target. When diagnosing a suspected regression, run this across the archives already on disk — a run of sensible numbers that ends in `1` dates the breakage precisely, and the corresponding build log under `DerivedData/<Project>-*/Logs/Build/*.xcactivitylog` (gzipped; `gunzip -c`) shows the task ordering and any PlistBuddy errors.
