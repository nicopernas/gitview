# gitview

A native macOS git history viewer. Like gitk, without Tk.

## Install

```
make install    # builds ~/.local/share/gitview/gitview.app, links ~/.local/bin/gitview
```

Only needs the Xcode Command Line Tools.

## Use

Run it inside a repo. Any `git log` arguments work:

```
gitview
gitview --all
gitview main..feature
gitview -- src/
```

The terminal is free right away. Set `GITVIEW_FOREGROUND=1` to keep it attached (logs also print to the terminal). A dev build (`swift build`) always runs attached.

## Keys

| Key | Action |
|---|---|
| ↑ ↓ | Move between commits |
| Space / Shift+Space | Scroll diff |
| Tab | Next pane |
| Cmd+F or / | Find commit (in the file list: filter files; in the diff: find text) |
| Enter, Cmd+G / Shift+Cmd+G | Next / previous match |
| Cmd+C | Copy commit hash (or file path) |
| Cmd+R | Reload |
| Cmd+T | Choose font (default Source Code Pro 12) |
| Cmd+= / Cmd+- / Cmd+0 | Bigger / smaller / reset font |

## Logs

`~/.gitview/logs/YYYY-MM-DD.log`. Kept for 14 days.

## Develop

```
make test
make run ARGS="--all"
```
