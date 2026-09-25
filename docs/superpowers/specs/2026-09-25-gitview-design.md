# gitview design

A native macOS replacement for gitk. Read-only history viewer, nothing more.

## Goals

- Look like a proper Mac app (system fonts, dark mode).
- Fast on big repos: open quickly, scroll smoothly.
- Feel good to use: sane keys, scrolling, window handling.

## Non-goals

- No write actions (checkout, reset, cherry-pick, branch).
- No settings UI.

## Launch

- `gitview [any git log args]`, run inside a repo. Examples: `--all`, `main..feature`, `-- src/`, `--author=bob`.
- Parent process checks the repo with `git rev-parse --show-toplevel`. On failure: print git's error, exit 1.
- On success: re-spawn itself with `POSIX_SPAWN_SETSID`, stdin `/dev/null`, stdout/stderr to the log file, then exit. The terminal is free right away.
- `GITVIEW_FOREGROUND=1` skips the detach (debugging).
- If `git log` fails (bad args), the window shows git's error.
- `make install` copies the binary to `~/.local/bin`.

## Logs

- `~/.gitview/logs/YYYY-MM-DD.log`, one file per day, lines prefixed with timestamp and pid.
- Logged: every git command (args, exit code, duration, stderr), load progress and totals, diff load times, errors.
- The detached process's stdout/stderr go to the same file.
- Files older than 14 days are deleted at startup.

## Structure

One Swift package, built with SwiftPM (no Xcode needed).

- `GitViewCore` (no UI, unit tested)
  - `Git`: runs `git`, streams stdout lines, captures stderr, logs each run.
  - `Log`: file logger.
  - `LogParser`: `git log` line -> `Commit` (hash, parents, author, date, subject, refs).
  - `GraphLayout`: incremental lane assignment -> `GraphRow` per commit.
  - `LogLoader`: runs `git log` in the background, parses, lays out, delivers batches.
  - `DetailsParser` / `DetailsLoader`: runs `git show` for one commit, finds file offsets and line kinds.
  - `Search`: next/previous commit matching subject, author or hash prefix; wraps around.
- `gitview` (AppKit executable): launch/detach, window, commit table, file list, diff view, find field, menus.

## Loading

- Command: `git -c core.quotepath=false log --no-color --no-show-signature --date-order --parents --decorate=full --format=%H%x00%P%x00%an%x00%at%x00%D%x00%s <user args>`.
- User args come last so they override defaults (e.g. `--topo-order`).
- `--parents` is required so path-limited history keeps connected parents.
- Output is read on a background thread; rows are appended in batches. The UI is usable while loading. Status bar shows progress and final count.
- Cmd+R reloads and keeps the selected commit if it still exists.

## Graph

- State: a list of lanes, each waiting for a commit hash, with a color.
- For each commit: it takes the first lane waiting for it (or a free slot). Other lanes waiting for it converge into it.
- First parent continues in the same column. Other parents reuse a lane already waiting for them, or take a free slot.
- Lanes never move, so pass-through lines are straight. Freed slots are reused. Trailing empty slots are trimmed.
- Each row stores: node column, node color, and line pieces (top half / bottom half, from column, to column, color).

## Window

- Left: commit table with three columns: graph + ref labels + subject, author, date (`yyyy-MM-dd HH:mm`, local).
  - Ref labels: local branch, remote branch, tag, with different colors. HEAD's branch is bold.
- Left bottom (under the commit table): filter field and file list. First entry "Commit", then changed files. Click scrolls the diff to that file. Typing in the filter hides files that don't match (substring, ignoring case); the "Commit" entry is hidden while filtering.
- Right (full height): header (hash, parents, author, committer, dates, full message) then diff. Long lines wrap.
- One font for list, file list and diff. Default Source Code Pro 12 (falls back to the system monospaced font). Changed with the font panel (Cmd+T) or Bigger/Smaller/Reset (Cmd+= / Cmd+- / Cmd+0); saved in user defaults.
  - Added green, removed red, hunk headers blue, file headers bold. Merges show git's combined diff.
  - Diffs over 50,000 lines are cut with a note.
  - Loaded in the background; stale results are dropped when the selection changes.
- Status bar at the bottom.
- Split sizes and window frame are saved and restored.

## Keys

- Up/Down, Page Up/Down, Home/End: move in commit list.
- Space / Shift+Space: scroll diff down / up.
- Tab: next pane.
- Cmd+F or /: focus commit find field. When the file list has focus: the file filter. When the diff has focus: native find bar in the diff.
- Enter or Cmd+G / Shift+Cmd+G: next / previous match.
- Cmd+R: reload. Cmd+W / Cmd+Q: close / quit.

## Errors

- Not a repo: error printed in the terminal, exit 1, no window.
- `git log` fails: alert with git's stderr.
- `git show` fails: error text in the diff pane.
- All errors are logged.

## Testing

- Unit tests (Swift Testing) for `LogParser`, `GraphLayout`, `DetailsParser`, `Search`.
- Integration tests that build a temp repo with branches and merges and run the loaders.
- Manual check of the app on this repo and on `/opt/homebrew` (~53k commits).
- Tests need `-plugin-path` to the testing macros when only Command Line Tools are installed; the Makefile handles it.
