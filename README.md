# gitview

A native macOS git history viewer. Like gitk, without Tk.

## Install

```
make install    # copies the binary to ~/.local/bin
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

The terminal is free right away. Set `GITVIEW_FOREGROUND=1` to keep it attached (logs also print to the terminal).

## Keys

| Key | Action |
|---|---|
| ↑ ↓ | Move between commits |
| Space / Shift+Space | Scroll diff |
| Tab | Next pane |
| Cmd+F | Find commit (in the diff: find text) |
| Enter, Cmd+G / Shift+Cmd+G | Next / previous match |
| Cmd+C | Copy commit hash (or file path) |
| Cmd+R | Reload |

## Logs

`~/.gitview/logs/YYYY-MM-DD.log`. Kept for 14 days.

## Develop

```
make test
make run ARGS="--all"
```
