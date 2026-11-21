#!/usr/bin/env bash
# Remote dev VPS setup for Debian 13. Options and steps: see README.md.
#   ./install.sh                  # every step; asks for your sudo password if needed
#   ./install.sh neovim versions  # only the named steps
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for lib in "$ROOT"/lib/*.sh; do source "$lib"; done

: "${NEW_USER:=dev}"
: "${SSH_PUBKEY:=}"
: "${SWAP_SIZE:=2G}"
# Region/City from `timedatectl list-timezones`, e.g. America/New_York,
# America/Chicago, America/Denver, America/Los_Angeles, Europe/London,
# Europe/Berlin, Asia/Kolkata, Asia/Singapore, Asia/Tokyo, Australia/Sydney, UTC
: "${TIMEZONE:=UTC}"
: "${SUDO_NOPASSWD:=yes}"
: "${AUTO_REBOOT:=true}"
: "${TS_AUTHKEY:=}"
: "${TS_ONLY_SSH:=yes}"
: "${GIT_NAME:=}"
: "${GIT_EMAIL:=}"
CONFIG_VARS=(NEW_USER SSH_PUBKEY SWAP_SIZE TIMEZONE SUDO_NOPASSWD AUTO_REBOOT TS_AUTHKEY TS_ONLY_SSH GIT_NAME GIT_EMAIL)

is_root() { [[ $EUID -eq 0 ]]; }

# Without sudo, only your own account can be set up.
is_root || NEW_USER=$(id -un)
USER_HOME="/home/$NEW_USER"
DOTFILES="$USER_HOME/dotfiles"
GIT_LOCAL="$USER_HOME/.gitconfig.local"

SYSTEM_STEPS=(packages locale timezone swap memory kernel journald auto_updates user fail2ban sshd tailscale firewall rex repo)
USER_STEPS=(dotfiles mise claude rex_server neovim versions)

is_user_step() { in_list "$1" "${USER_STEPS[@]}"; }

# System steps run as root and user steps as NEW_USER, whoever started the script.
run_step() {
  local step=$1
  if is_root && is_user_step "$step"; then
    rerun_as "$NEW_USER" "$DOTFILES" "$step"
  elif ! is_root && ! is_user_step "$step"; then
    rerun_as root "$ROOT" "$step"
  else
    log "$step"
    "step_$step"
  fi
}

# rerun_as USER REPO STEP: run REPO/install.sh as USER, carrying the config across sudo.
rerun_as() {
  local user=$1 repo=$2 var env=()
  shift 2
  for var in "${CONFIG_VARS[@]}"; do env+=("$var=${!var}"); done
  sudo -u "$user" -H env "${env[@]}" bash "$repo/install.sh" "$@"
}

check_steps() {
  local step
  for step in "$@"; do
    declare -F "step_$step" >/dev/null || die "Unknown step: $step"
  done
}

needs_sudo() {
  local step
  is_root && return 1
  for step in "$@"; do is_user_step "$step" || return 0; done
  return 1
}

print_next_steps() {
  local host
  host=$(hostname)
  cat <<EOF2

Next steps:
  1. In a NEW terminal, confirm login:  ssh ${NEW_USER}@${host}
  2. Only then close this session.
  3. Reboot if the kernel was upgraded: sudo reboot
  4. Sign in: 'gh auth login', then run 'claude' and 'opencode' once.
  5. In Rex on your Mac: Settings > Remote Hosts > ssh://${NEW_USER}@${host}
EOF2
}

main() {
  local steps=("$@") step
  (( ${#steps[@]} )) || steps=("${SYSTEM_STEPS[@]}" "${USER_STEPS[@]}")
  check_steps "${steps[@]}"
  step_preflight
  is_root || user_env
  if needs_sudo "${steps[@]}"; then sudo true; fi
  if in_list dotfiles "${steps[@]}"; then load_git_identity; fi

  for step in "${steps[@]}"; do run_step "$step"; done
  if (( $# == 0 )); then print_next_steps; fi
}

main "$@"
