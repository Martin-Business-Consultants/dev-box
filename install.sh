#!/usr/bin/env bash
# Remote dev VPS setup for Debian 13 (trixie). See README.md.
#
#   sudo ./install.sh                  # run every step
#   sudo ./install.sh neovim versions  # run only the named steps
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for lib in "$ROOT"/lib/*.sh; do source "$lib"; done

# ---------------- config (override via env) ----------------
: "${NEW_USER:=dev}"
: "${SSH_PUBKEY:=}"          # if empty, copies /root/.ssh/authorized_keys
: "${SWAP_SIZE:=2G}"         # important on 1GB droplets
: "${TIMEZONE:=UTC}"
: "${SUDO_NOPASSWD:=yes}"    # user has no password (key-only login)
: "${AUTO_REBOOT:=true}"     # reboot at 04:00 if updates need it
: "${TS_AUTHKEY:=}"          # optional; without it you log in via URL
: "${TS_ONLY_SSH:=yes}"      # once Tailscale is up, close public port 22
: "${GIT_NAME:=}"            # prompted if empty
: "${GIT_EMAIL:=}"           # prompted if empty
# ------------------------------------------------------------

SYSTEM_STEPS=(packages locale swap kernel journald auto_updates user fail2ban sshd tailscale firewall repo)
USER_STEPS=(dotfiles mise claude neovim versions)

run_step() {
  local step=$1
  declare -F "step_$step" >/dev/null || die "Unknown step: $step"
  if in_list "$step" "${USER_STEPS[@]}" && [[ $EUID -eq 0 ]]; then
    as_user "$step"
  else
    log "$step"
    "step_$step"
  fi
}

# Re-run this script as NEW_USER from their dotfiles copy for user-level steps.
as_user() {
  sudo -u "$NEW_USER" -H env GIT_NAME="$GIT_NAME" GIT_EMAIL="$GIT_EMAIL" \
    bash "$(user_dotfiles)/install.sh" --as-user "$@"
}

print_next_steps() {
  cat <<EOF

Next steps:
  1. In a NEW terminal, confirm login:  ssh ${NEW_USER}@$(hostname)
  2. Only then close this root session.
  3. Reboot if the kernel was upgraded: sudo reboot
  4. Run 'claude' and 'opencode' once to sign in.
EOF
}

main() {
  if [[ ${1:-} == --as-user ]]; then
    shift
    user_env
    for step in "$@"; do run_step "$step"; done
    return
  fi

  step_preflight
  local steps=("$@")
  (( ${#steps[@]} )) || steps=("${SYSTEM_STEPS[@]}" "${USER_STEPS[@]}")
  if in_list dotfiles "${steps[@]}"; then load_git_identity; fi

  for step in "${steps[@]}"; do run_step "$step"; done
  (( $# )) || print_next_steps
}

main "$@"
