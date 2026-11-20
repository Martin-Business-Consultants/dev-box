# Tailscale and firewall. The firewall step reads Tailscale's state, so it
# always runs after the tailscale step and is safe to re-run on its own.

tailscale_up() {
  has tailscale && tailscale status >/dev/null 2>&1
}

step_tailscale() {
  has tailscale || run_installer https://tailscale.com/install.sh
  systemctl enable --now tailscaled

  if tailscale_up; then
    echo "Already connected to the tailnet."
    return
  fi

  local args=(--ssh --hostname="$(hostname)" --timeout=10m)
  if [[ -n $TS_AUTHKEY ]]; then
    args+=(--authkey="$TS_AUTHKEY")
  else
    echo "No TS_AUTHKEY: open the login URL below to add this machine."
  fi
  tailscale up "${args[@]}" \
    || warn "Tailscale didn't connect; public SSH stays open. Retry: sudo ./install.sh tailscale firewall"
}

step_firewall() {
  ufw --force reset >/dev/null
  ufw default deny incoming
  ufw default allow outgoing

  if tailscale_up; then
    ufw allow in on tailscale0
    [[ $TS_ONLY_SSH == yes ]] || ufw allow OpenSSH
  else
    ufw allow OpenSSH
  fi

  ufw --force enable
  ufw status verbose
}
