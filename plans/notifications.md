# Notifications

While the app is open it checks GitHub every few minutes and raises a macOS
notification for:

| Kind | When | Default |
|---|---|---|
| Asked to review by name | Your review is requested directly | on |
| Asked to review through a team | A team you're on is requested | **off** |
| Assigned to you | You're made an assignee | on |
| Replies to you | Someone writes after you in a review thread, or in a PR's conversation | on |
| Comments on your pull requests | Anything else someone writes on a PR you opened | on |

Settings › Notifications (⌘, then the bell) has a switch for each and the
interval (1, 2, 5 or 15 minutes). They are `UserDefaults` keys
(`NotificationPreferences.Key`) bound with `@AppStorage`; the defaults are
registered at launch so the view and `NotificationPreferences(defaults:)` agree.
The tab also says when macOS will not show them (never asked, or turned off in
System Settings) and offers Allow… or Open System Settings….

Clicking a notification opens the PR. A reply or comment in a review thread
also opens the inspector on that thread, refetching threads if the PR is
already loaded so the new comment is there.

## The notifications panel

The bell in the sidebar's toolbar (⌥⌘N) opens a popover listing every
notification raised, newest first, with an unread dot on the bell. Every
notification is a `NotificationRecord` (ReviewCore): activity notices through
`NotificationRecord(notice:)` and Claude's answers through `.answer(…)`, worded
exactly as the banner is. `AppModel.deliver` adds records to the
`NotificationLog` (ReviewKit, newest first, capped at 200), saves it to
`notifications.json` (`NotificationLogStore`), then hands them to
`SystemNotifier` for macOS. A record is kept even when macOS will not show it,
so turning banners off loses nothing.

The bell is the plain gray toolbar symbol until something is unread, then
`bell.badge.fill` with a red badge. (A monochrome symbol given two styles
takes the first, which is how the empty bell came out red.)

**Surviving a relaunch.** The log is saved on every change and loaded at
startup. At startup the app also reads its notifications still in macOS
Notification Center and adds back any the log lacks
(`NotificationRecord(delivered:)`): ones raised before the panel existed, or
lost to a failed save. Each banner's `userInfo` carries the record's ID, PR,
thread and draft, and older builds' `pullRequest`/`thread`/`draft` keys are
read too; the kind is inferred from the wording. Deleting or clearing in the
panel removes the banners from Notification Center as well, so they do not
come back. A failed save is logged with `NSLog`, not swallowed.

A row opens what it is about, as its banner does, and marks it read. A banner
carries its record's ID, so clicking one marks the row read too. Claude's
answers are recorded only when they would notify: an answer the reviewer is
already watching is not a notification. `--notifications on` opens the panel
in a scripted launch (snapshot `-popover.png`); scripted launches load the log
but never add to or save it.

## By name versus through a team

GitHub's `review-requested:@me` includes requests to your teams;
`user-review-requested:@me` is only requests by name, and `gh search prs` has
no flag for it, so it goes in the query words. The inbox now runs both
(`InboxItem.Reason.reviewRequested` and `.teamReviewRequested`); a PR asked of
you and your team has both reasons and counts as by name. Assignees are always
people — teams cannot be assigned — so there is no team form of assignment.

## Requests and assignments: what is new

Built on the inbox refresh (launch, ⌘R, and every poll). `ActivityDetector
.requestKeys` turns the inbox into keys like `owner/repo#12 assigned`; a key
not in the last look's set is news. The set is replaced each time, not added
to, so being asked again after reviewing is news again. One notice per PR,
assigned before by name before team, skipping kinds that are switched off.

The first look ever, and the first after the tracked repositories change, only
record — otherwise every PR in a newly tracked repository would notify.

## Replies and comments: what is new

`GitHubClient.activity` is one GraphQL request:
`is:pr involves:@me updated:>=<since> repo:… sort:updated-desc`, first 25, with
each PR's last 30 conversation comments, last 30 reviews (summaries; empty ones
dropped, their line comments are in the threads), and last 50 threads with
their first 50 comments, plus `viewer { login }`. `involves:` covers your PRs
and every PR you've commented on. A quiet check matches nothing and costs one
search.

A comment counts when it is in the window, not seen before, not yours, and not
from an app (`author.__typename == "Bot"` — CI, Claude, Copilot never notify).
In a thread or conversation where you wrote earlier it is a **reply**;
otherwise, on your own PR, a **comment**; otherwise nothing. Per PR, at most one
reply notice and one comment notice per check, about the newest, with a count
("7 comments, latest from ana") — one review's five line comments are one
banner, not five.

**The window.** GitHub's search can lag a fresh comment by a minute or two, so a
check looks back to 30 minutes before the last one (at most a day, after the
app has been closed) and skips comment IDs (their URLs) it saw last time. The
state — request keys, when comments were last checked, and the IDs — is
`activity.json` beside the other stores (`ActivityStore`). Turning both comment
switches off clears it, so turning one back on starts fresh rather than
reporting everything since.

## Not done

- Nothing is checked while the app is closed; what happened meanwhile is
  reported on the next launch's first check (up to a day of comments).
- The scope is the tracked repositories, like the inbox. With none tracked, all
  of GitHub.
- Mentions on PRs you're otherwise not part of are not looked for.
- A scripted launch (`REVIEW_SNAPSHOT`) neither polls, notifies nor records.

## Headless

`review activity [--hours 24]` prints what would notify, by the same rules, as
if nothing had been seen, with team requests included. It reads only.
`--settings notifications` opens the tab in a scripted launch.
