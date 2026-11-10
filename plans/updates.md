# Updates

The installed copy checks whether `origin/main` has commits it was not built
from, says so, and on request rebuilds and relaunches itself. A new version
*is* a new commit on main: there are no releases or version numbers to compare.

## Where the app looks

`make install` runs `scripts/promote.sh`, which builds in its own worktree but
passes `SOURCE=<the checkout it was run from>` through `make` to `build.sh`.
That path is stamped into Info.plist as `ReviewSource`, next to `ReviewCommit`.
`BuildInfo` (ReviewCore) reads both; an empty, `unknown` or unsubstituted
(`__…__`) value means "cannot update". Only promote.sh sets `SOURCE`, so dev
builds never check, and neither does an installed copy from before this
existed — the first `make install` after it lands is still by hand.

## Checking

`UpdateChecker` (ReviewKit), in the stamped checkout:

1. `git fetch --quiet origin main` — the same fetch promote.sh does, so
   `origin/main` there moves; nothing is checked out.
2. `git rev-parse origin/main`. Starting with the installed short commit means up to date.
3. `git log --format=%h%x09%s <installed>..origin/main` for the list. A
   commit main no longer has (a force-push) gives an update with no list.

`Updater` (ReviewApp) checks at launch and then hourly, while the app runs.
The macOS banner is posted once per new head of main
(`UserDefaults` `UpdateNotifiedHead`), so the hourly check does not repeat it.
The banner is not a `NotificationRecord`: those are about a pull request, and
the panel and the recovery from Notification Center both assume one. Its
`userInfo` carries `update`, and a click opens the update sheet.

What the sheet may do next is decided by `UpdateStatus` (ReviewKit), a value
type so it is tested without the app:

- After a failed check the button retries the check; after a failed install
  it retries the install. An earlier update still waiting does not turn a
  failed check's Try Again into an install.
- Until a check has answered, the sheet says "Checking for updates…", never
  "up to date". Check for Updates… chosen before startup has the login-shell
  environment waits for the launch check. A missing `git` is a failed check.
- The hourly check does not run over a failed install, so its log stays in
  the sheet. Asking for a check does.
- A scripted launch (`--update-source`) has `canInstall` false: the button is
  disabled, so a dev build cannot replace /Applications/Review.app.

While an update is waiting, a row at the foot of the sidebar says so ("Update
available: 3 new commits"), so a dismissed banner is not the only notice.
**Review › Check for Updates…** checks now and opens the sheet either way.

## Installing

**Update and Relaunch** runs `UpdateInstaller` (ReviewKit):
`/bin/bash <source>/scripts/promote.sh` in the source checkout, with the
login-shell environment plus:

- `PROMOTE_WAIT_PID` — the app's pid. promote.sh then does not AppleScript
  `quit` the app; a child of the app sending it Apple events would need
  Automation permission.
- `PROMOTE_READY_FILE` — touched once the build is done.

The installer returns when the ready file appears, and the app calls
`NSApp.terminate`. promote.sh waits up to five minutes for the pid to exit, then
replaces `/Applications/Review.app` and opens it. If the build fails first, the
script exits non-zero and the sheet shows the end of the log, with Try Again.

The script outlives the app, so its output goes to
`~/Library/Logs/Review/update.log` (Show Log), never a pipe. A pipe with no
reader left would kill the script with SIGPIPE on its next `echo`, before it
installs anything.

The promote.sh that runs is the checkout's copy, so it comes from whichever
branch that checkout has out, the same as running `make install` by hand.

## Checking it

- `UpdateCheckerTests` use a real origin and a clone. `UpdateInstallerTests`
  use a stand-in promote.sh, because the real one builds for minutes and
  replaces /Applications/Review.app.
- `open -n --env REVIEW_SNAPSHOT=… "build/Review Dev.app" --args
  --update-source "$PWD" --update-commit <older sha>` checks this checkout as
  if it were built from that commit and shows the sheet (`-sheet.png`). It
  never notifies, and Update and Relaunch is disabled.
- `UpdateStatusTests` cover which action the sheet offers and when a check
  may run.
- The sidebar draws blank in snapshots on macOS 26, so the footer row was not
  seen that way.
