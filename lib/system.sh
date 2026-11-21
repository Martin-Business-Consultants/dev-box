PACKAGES=(
  sudo curl ca-certificates gnupg git stow tmux mosh htop unzip xz-utils
  ripgrep fd-find jq locales btop fastfetch
  earlyoom systemd-zram-generator
  podman podman-docker uidmap passt dbus-user-session
  ufw fail2ban python3-systemd
  unattended-upgrades apt-listchanges needrestart
  build-essential pkg-config libyaml-dev libvips42t64
)

step_preflight() {
  . /etc/os-release
  [[ ${ID:-} == debian && ${VERSION_ID:-} == 13 ]] \
    || die "Expected Debian 13, found ${PRETTY_NAME:-unknown}."
  [[ -f /usr/share/zoneinfo/$TIMEZONE ]] \
    || die "Unknown TIMEZONE '$TIMEZONE'. List valid ones: timedatectl list-timezones"
}

step_packages() {
  apt_get update -y
  apt_get -o Dpkg::Options::="--force-confold" full-upgrade -y
  apt_install "${PACKAGES[@]}"
  install -D -m 644 /dev/null /etc/containers/nodocker  # silence podman-docker's notice
}

# macOS ssh forwards LANG=en_US.UTF-8; generate it so logins don't warn.
step_locale() {
  sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen
  update-locale LANG=en_US.UTF-8
}

step_timezone() {
  timedatectl set-timezone "$TIMEZONE"
}

step_swap() {
  if swapon --show | grep -q .; then
    echo "Swap already configured."
    return
  fi
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
}

# zram (compressed swap in RAM) is used before the swap file. earlyoom kills the
# hungriest process, preferring language servers, before the box freezes.
step_memory() {
  render zram/zram-generator.conf /etc/systemd/zram-generator.conf
  systemctl daemon-reload
  systemctl start systemd-zram-setup@zram0

  render earlyoom/earlyoom /etc/default/earlyoom
  systemctl enable earlyoom
  systemctl restart earlyoom
}

step_kernel() {
  render sysctl/99-hardening.conf /etc/sysctl.d/99-hardening.conf
  sysctl --system >/dev/null
}

step_journald() {
  render journald/size.conf /etc/systemd/journald.conf.d/size.conf
  systemctl restart systemd-journald
}

step_auto_updates() {
  local file
  for file in 20auto-upgrades 52unattended-local; do
    render "apt/$file" "/etc/apt/apt.conf.d/$file"
  done
  systemctl enable --now unattended-upgrades
}
