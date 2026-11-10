# Build system

No Xcode project, no `xcodebuild`, no XcodeGen. `swift build` compiles; a shell
script bundles and signs; `make` orchestrates. Xcode is only a toolchain
provider (`swift`, `codesign`, `notarytool`, `stapler`).

## The pieces

- **`Package.swift`** — library targets for the logic, two executable
  targets (`ReviewApp`, `review`), one test target per library. Swift 6
  language mode. See architecture.md for the graph.
- **`build.sh`** — `swift build` → assemble `build/Review Dev.app` or `build/Review.app` (Info.plist
  with its `__…__` placeholders substituted, `PkgInfo`, any
  dependency `*.bundle`s copied into `Contents/Resources`, the icon) → codesign.
  Falls back to ad-hoc signing (`-`) when no real identity is available, so
  `make run` always works on a bare machine.
- **`Makefile`** — the front door. `make help` lists everything.
- **`Resources/Info.plist`** — bundle metadata. Version strings are
  placeholders filled at build time.
- **No entitlements file, no App Sandbox.** The app runs git, gh, gopls,
  typescript-language-server and claude from the user's own install and reads
  arbitrary repositories; the sandbox forbids both. See architecture.md.
  `build.sh` still signs with entitlements if `Review/Review.entitlements`
  ever appears.

## Permissions & capabilities

OS capabilities work in this no-Xcode, ad-hoc-signed bundle — you just have to
add the keys by hand, because there's no Xcode "Signing & Capabilities" tab
doing it for you:

- **Usage prompts** need the matching `NS…UsageDescription` string in
  `Resources/Info.plist`. CoreLocation, for example, prompts and returns a fix
  with `NSLocationUsageDescription` (+ `NSLocationWhenInUseUsageDescription`)
  present — ad-hoc signing and the hand-assembled `.app` are not a barrier.
- **The sandbox decides the entitlement.** With the App Sandbox **off**, a
  usage-description string is enough. With it **on**, also add the matching
  `com.apple.security.*` entitlement (e.g.
  `com.apple.security.personal-information.location`).
- **Always design the denied path.** A permission the user declines should
  route to a sensible default, not a dead feature — e.g. a one-shot location
  request that yields `nil` falls back to a configured location.

## Two copies: dev and installed

The reviewer uses the app while agents build and test it, so there are two
variants, chosen by `VARIANT` (`build.sh`, `make`):

|                    | dev (default)                     | installed                       |
|--------------------|-----------------------------------|---------------------------------|
| bundle             | `build/Review Dev.app`            | `/Applications/Review.app`      |
| bundle id          | `dev.review.app.dev`              | `dev.review.app`                |
| URL scheme         | `review-dev://`                   | `review://`                     |
| data               | `Application Support/Review Dev`  | `Application Support/Review`    |
| icon               | DEV band (`make-icon.swift --dev`) | plain                           |
| built by           | any `make` / `make run`           | `make install` only             |

Separate bundle ids keep LaunchServices, Spotlight, `open` and UserDefaults
apart; the separate data folder keeps a test run off the reviewer's clones,
drafts, notes and open workspace. The app and CLI learn their variant at
compile time: `build.sh` passes `-Xswiftc -DREVIEW_INSTALLED` for the
installed one, and `AppVariant.current` reads it. So `./.build/debug/review`
is a dev CLI and reads the dev data; the `review` inside the installed bundle
reads the reviewer's. `build.sh` and `AppVariant` must agree on the names.

promote.sh also passes `SOURCE` (the checkout it was run from), stamped as
`ReviewSource`; it is empty in every other build. Both stamp `ReviewCommit` into Info.plist (`+dirty` for uncommitted changes),
and the About panel shows it as the build: "Version 0.1.0 (2f3ee44)".

**`make install` → `scripts/promote.sh`.** It fetches `origin/main` into its
own worktree at `~/Library/Caches/Review/promote` (kept between runs, so builds
are incremental), builds a release there as the installed variant, asks any
running `Review.app` to quit through AppleScript, replaces
`/Applications/Review.app`, re-registers it and opens it. The checkout it is run
from never matters. It lists older builds Spotlight can still find under the
installed id — dev builds from before the split were `build/Review.app` with
that id — for the reviewer to delete; a dev build in a checkout removes its own.

Not built yet, and why: a GitHub Actions build gains nothing without a
Developer ID — a downloaded ad-hoc-signed zip is quarantined, and its signature
differs every build. Instead the installed app updates itself through
promote.sh: it is stamped with the checkout it was built from (`ReviewSource`)
and watches `origin/main` there. See updates.md.

## Everyday targets

| Target        | What it does                                              |
|---------------|----------------------------------------------------------|
| `make check`  | `swift build` only — fast compile gate for CI/agents      |
| `make test`   | `swift test` (swift-testing)                              |
| `make cli`    | build and sign the `review` command-line tool             |
| `make run`    | build the dev `.app`, sign, `open` it                    |
| `make` / build| `build/Review Dev.app` (debug)                           |
| `make install`| build `origin/main` into `/Applications/Review.app`      |
| `make icon`   | regenerate the icon for `VARIANT`                        |
| `make clean`  | remove `build/ .build/ dist/`                            |

## Versioning

`make` resolves the version in this order: a `VERSION=` override → an exact
`vX.Y.Z` git tag at HEAD → the `VERSION` file. `make print-version` shows what
resolved and from where.

## Release pipeline (`make dist`)

Requires an exact `vX.Y.Z` tag at HEAD and a Developer ID signing identity.
The chain is deliberately ordered:

```
clean → release → sign → zip-notary → notarize → staple → zip-release → checksum → verify-release
```

The two-zip dance is intentional: Apple's notary service takes a zip; stapling
writes the ticket back into the `.app`; the zip you actually ship must be made
**after** stapling. One-time credential setup:

```sh
make notary-setup TEAM_ID=XXXXXXXXXX APPLE_ID=you@example.com
```

`make github-release` uploads the release zip + `.sha256` to a GitHub release.

## CI gate

The minimum a change must pass: `make check && make test`. The minimum a *UI*
change must pass: also `make run` and look at it — see `SWIFTUI-RULES.md` §9.
