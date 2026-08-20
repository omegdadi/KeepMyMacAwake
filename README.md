# KeepMyMacAwake

A menu bar coffee cup that keeps a Mac awake with the lid closed, plus the shell
helper it grew out of. Click the cup to toggle; there is nothing else to it.

<p align="center"><em>filled cup = awake · outline cup = normal sleep</em></p>

## What "awake" actually means here

Keeping a Mac awake with the lid shut takes two unrelated mechanisms, and it is
easy to think you have it when you only have one:

| | Mechanism | What it stops | Shows up in |
|---|---|---|---|
| 1 | `sudo pmset disablesleep 1` | sleep on lid close | `pmset -g` as `SleepDisabled 1` — a **system setting** |
| 2 | a `caffeinate` child process | idle system sleep | `pmset -g assertions` under **caffeinate's** pid |

The toggle sets both together and clears both together. Worth knowing when you
go looking for it: the app itself never holds a power assertion under its own
name — mechanism 1 is a setting, not an assertion, and mechanism 2 is owned by
the child process. Searching `pmset -g assertions` for the app finds nothing
whether it is on or off. Use `bin/nosleep-status` instead:

```
$ bin/nosleep-status
pmset disablesleep : ON
caffeinate         : ON (pid 23326, owned by NoSleep 22991)
shell state file   : present
```

Display sleep is deliberately left alone — the screen still dims and sleeps on
its own schedule. Bare `caffeinate` only asserts `PreventUserIdleSystemSleep`.
If you want the display kept on too, that is `caffeinate -d`.

## Install

```sh
./install.sh
```

That builds `~/Applications/NoSleep.app`, registers a LaunchAgent so it comes
back at login, and checks the one sudo rule it needs. No dependencies beyond the
Swift toolchain that ships with the Xcode command line tools.

### The sudo rule

`pmset disablesleep` is root-only, and a GUI app cannot prompt for a password
without hanging invisibly — so the app calls `sudo -n` (non-interactive) and
needs a narrow NOPASSWD rule. See [`sudoers.d/nosleep`](sudoers.d/nosleep); it
grants exactly `pmset disablesleep 0` and `pmset disablesleep 1`, nothing else.

```sh
sudo install -m 0440 -o root -g wheel sudoers.d/nosleep /etc/sudoers.d/nosleep
```

Without it the app still runs and shows you an error instead of silently
pretending the toggle worked.

## Usage

- **Left click** the cup — toggles both mechanisms.
- **Right click** (or ctrl-click) — shows current state and Quit.

Quitting turns keep-awake **off**. That is on purpose: quitting kills the
`caffeinate` child no matter what, and leaving `pmset disablesleep 1` set would
mean sleep stays disabled with no icon left to undo it.

On launch the app adopts whatever state the machine is already in, so it will not
surprise you by re-enabling sleep during something long-running. If it finds
sleep already disabled, it starts its own `caffeinate` so that one process always
owns the assertion — no leaning on some other program's `caffeinate` that may
disappear later.

## The shell helper

[`shell/nosleep.zsh`](shell/nosleep.zsh) is the original. Source it from
`~/.zshrc`:

```sh
nosleep              # toggle
nosleep make release # disable sleep, run the command, restore sleep on exit
```

The command form is the better tool when you know how long you need — it cannot
leave sleep disabled by accident. The app and the helper share the
`/tmp/.nosleep_active` state file, so toggling in one keeps the other honest.

## Gotcha: the notch can eat the icon

On a notched MacBook, if the menu bar is full, a new status item can be placed in
the dead zone behind the camera housing — where it is invisible **and**
unclickable. The app sets an `autosaveName` so macOS remembers its slot, but if
the cup goes missing, that is where it went. Check:

```sh
osascript -e 'tell application "System Events" to tell process "NoSleep" \
  to get {size, position} of every menu bar item of menu bar 1'
```

On a 1512-point-wide display the notch covers roughly x 668–843. To move it,
write a preferred x and relaunch:

```sh
defaults write com.xoxo.nosleep \
  "NSStatusItem Preferred Position NoSleepStatusItem" -float 1050
```

Cmd-dragging works too, once it is somewhere you can grab.

## Uninstall

```sh
launchctl bootout gui/$UID/com.xoxo.nosleep
rm ~/Library/LaunchAgents/com.xoxo.nosleep.plist
rm -rf ~/Applications/NoSleep.app
sudo rm /etc/sudoers.d/nosleep     # only if you also want the sudo rule gone
```

Quit the app first so it restores your sleep setting on the way out.

## License

MIT
