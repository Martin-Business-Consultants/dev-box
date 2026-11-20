# Login user, SSH, fail2ban.

step_user() {
  id "$NEW_USER" &>/dev/null || adduser --disabled-password --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  install_ssh_keys

  if [[ $SUDO_NOPASSWD == yes ]]; then
    render sudoers/nopasswd "/etc/sudoers.d/90-$NEW_USER" 440
    visudo -cf "/etc/sudoers.d/90-$NEW_USER"
  fi

  passwd -l root
}

# Give NEW_USER an authorized key; refuse to continue without one, since the
# sshd step disables passwords and root login.
install_ssh_keys() {
  local ssh_dir="/home/$NEW_USER/.ssh"
  local keys="$ssh_dir/authorized_keys"

  install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$ssh_dir"
  if [[ -n $SSH_PUBKEY ]]; then
    echo "$SSH_PUBKEY" > "$keys"
  elif [[ ! -s $keys && -s /root/.ssh/authorized_keys ]]; then
    cp /root/.ssh/authorized_keys "$keys"
  fi
  [[ -s $keys ]] || die "No SSH key for $NEW_USER. Set SSH_PUBKEY."

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
