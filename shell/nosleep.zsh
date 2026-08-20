# nosleep: toggle system sleep or wrap a command with sleep+caffeinate disabled
# Usage:
#   nosleep              → toggle sleep on/off
#   nosleep <command>    → disable sleep, run command (with caffeinate), re-enable on exit
_NOSLEEP_STATE=/tmp/.nosleep_active

nosleep() {
  if [[ $# -eq 0 ]]; then
    if [[ -f "$_NOSLEEP_STATE" ]]; then
      sudo pmset disablesleep 0 && rm -f "$_NOSLEEP_STATE" && echo "nosleep: OFF — sleep re-enabled"
    else
      sudo pmset disablesleep 1 && touch "$_NOSLEEP_STATE" && echo "nosleep: ON — sleep disabled"
    fi
  else
    sudo pmset disablesleep 1 && touch "$_NOSLEEP_STATE" || return 1
    echo "nosleep: ON — running: $*"
    caffeinate "$@"
    local exit_code=$?
    sudo pmset disablesleep 0 && rm -f "$_NOSLEEP_STATE"
    echo "nosleep: OFF — sleep re-enabled"
    return $exit_code
  fi
}
