#!/usr/bin/env bash
#
# promote.sh — build origin/main as the installed Review and put it in
# /Applications. `make install` runs this.
#
# It never builds the checkout it is run from: main is fetched into a worktree
# of its own (kept between runs so builds are incremental), so your branch and
# uncommitted edits make no difference. The running Review is asked to quit,
# replaced, and opened again.
#
# For the reviewer to run. Agents build and test the dev variant only.
#
# Environment:
#   PROMOTE_WORKTREE  where main is built (default ~/Library/Caches/Review/promote)
#   PROMOTE_REF       what to build (default origin/main)
#   PROMOTE_WAIT_PID  set by the app's Update button: instead of asking Review
#                     to quit, touch PROMOTE_READY_FILE once built and wait for
#                     this process to exit. The app quits itself on that cue.
#
set -euo pipefail

REPO="$(git rev-parse --show-toplevel)"
WORKTREE="${PROMOTE_WORKTREE:-$HOME/Library/Caches/Review/promote}"
REF="${PROMOTE_REF:-origin/main}"
DEST="/Applications/Review.app"
BUNDLE_ID="dev.review.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

echo "→ fetching $REF"
git -C "$REPO" fetch --quiet origin main

if [ -e "$WORKTREE/.git" ]; then
	git -C "$WORKTREE" checkout --quiet --force --detach "$REF"
	# Untracked files go; ignored ones (.build, build) stay, so the build is
	# incremental.
	git -C "$WORKTREE" clean -fdq
else
	git -C "$REPO" worktree prune
	mkdir -p "$(dirname "$WORKTREE")"
	git -C "$REPO" worktree add --quiet --detach "$WORKTREE" "$REF"
fi
COMMIT="$(git -C "$WORKTREE" rev-parse --short HEAD)"
echo "→ building $COMMIT ($(git -C "$WORKTREE" log -1 --format=%s))"

make -C "$WORKTREE" release VARIANT=installed COMMIT="$COMMIT" SOURCE="$REPO"
BUILT="$WORKTREE/build/Review.app"
[ -d "$BUILT" ] || { echo "✗ $BUILT missing — build failed?" >&2; exit 1; }

# Quit the installed copy through AppKit, so it saves what it keeps on quit.
# Any Review.app counts: dev builds from before the dev variant existed share
# its name and bundle id, and are what you would be switching away from.
# Review Dev.app is left running.
running() { pgrep -qf "/Review\.app/Contents/MacOS/ReviewApp"; }
if [ -n "${PROMOTE_WAIT_PID:-}" ]; then
	echo "→ waiting for Review to quit"
	touch "$PROMOTE_READY_FILE"
	for _ in $(seq 600); do
		kill -0 "$PROMOTE_WAIT_PID" 2>/dev/null || break
		sleep 0.5
	done
	if kill -0 "$PROMOTE_WAIT_PID" 2>/dev/null; then
		echo "✗ Review did not quit within five minutes; the update was not installed." >&2
		exit 1
	fi
elif running; then
	echo "→ quitting the running Review"
	osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
	for _ in $(seq 50); do
		running || break
		sleep 0.2
	done
	if running; then
		echo "✗ Review is still running — it may be asking something. Quit it and run make install again." >&2
		exit 1
	fi
fi

rm -rf "$DEST"
ditto "$BUILT" "$DEST"
"$LSREGISTER" -f "$DEST"
echo "✓ installed $COMMIT at $DEST"

# Dev builds from before the dev variant existed are named Review.app and
# carry this bundle id, so Spotlight can offer them instead. Point them out;
# they are build products in other checkouts, left for you to remove.
stale="$(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null | grep -vx "$DEST" | grep -v "^$WORKTREE/" || true)"
if [ -n "$stale" ]; then
	echo "  older builds that Spotlight may still offer as Review:"
	while IFS= read -r path; do echo "    $path"; done <<<"$stale"
	echo "  remove each with: rm -rf <path>"
fi

open "$DEST"
