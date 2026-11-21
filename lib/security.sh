step_user() {
  id "$NEW_USER" &>/dev/null || adduser --disabled-password --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  install_ssh_keys

  if [[ $SUDO_NOPASSWD == yes ]]; then
    local sudoers="/etc/sudoers.d/90-$NEW_USER"
    render sudoers/nopasswd "$sudoers" 440
    visudo -cf "$sudoers"
  fi

  passwd -l root
}

# Public SSH takes keys only, so it needs one. With TS_ONLY_SSH=yes, Tailscale SSH is the way in
# and a key is optional.
install_ssh_keys() {
  local ssh_dir="$USER_HOME/.ssh"
  local keys="$ssh_dir/authorized_keys"

  install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$ssh_dir"
  if [[ -n $SSH_PUBKEY ]]; then
    echo "$SSH_PUBKEY" > "$keys"
  elif [[ ! -s $keys && -s /root/.ssh/authorized_keys ]]; then
    cp /root/.ssh/authorized_keys "$keys"
  fi
  if [[ ! -s $keys ]]; then
    [[ $TS_ONLY_SSH == yes ]] || die "No SSH key for $NEW_USER. Set SSH_PUBKEY."
    warn "No SSH key for $NEW_USER: only Tailscale SSH will reach this box."
    return
  fi

  chown "$NEW_USER:$NEW_USER" "$keys"
  chmod 600 "$keys"
}

step_fail2ban() {
  render fail2ban/jail.local /etc/fail2ban/jail.local
  systemctl enable fail2ban
  systemctl restart fail2ban
}

step_sshd() {
  render ssh/00-hardening.conf /etc/ssh/sshd_config.d/00-hardening.conf
  sshd -t || die "sshd config invalid; not restarting."
  systemctl restart ssh
}
