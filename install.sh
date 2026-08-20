#!/bin/bash
# Installs KeepMyMacAwake: builds the app, sets it to launch at login,
# and checks the passwordless sudo rule it needs.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.xoxo.nosleep"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "==> Building the app"
"$REPO/app/build.sh"

echo "==> Installing the login item"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-a</string>
    <string>$HOME/Applications/NoSleep.app</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>LimitLoadToSessionType</key><array><string>Aqua</string></array>
</dict>
</plist>
PLIST_EOF

launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"

echo "==> Checking the sudo rule"
if sudo -n pmset -g >/dev/null 2>&1 || sudo -n /usr/bin/pmset disablesleep \
     "$(pmset -g | awk '/SleepDisabled/{print $2}')" >/dev/null 2>&1; then
  echo "    OK — passwordless 'pmset disablesleep' works."
else
  cat <<'MSG'
    MISSING. The toggle needs to run `pmset disablesleep` without a password,
    otherwise a GUI app would hang on an invisible prompt. Install the rule:

      sudo install -m 0440 -o root -g wheel sudoers.d/nosleep /etc/sudoers.d/nosleep

    Review that file first — it grants passwordless access to exactly one
    command and nothing else.
MSG
fi

echo "==> Optional shell helper: source shell/nosleep.zsh from your ~/.zshrc"
echo "==> Done. Look for the coffee cup in the menu bar."
