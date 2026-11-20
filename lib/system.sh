# Base system: packages, locale, swap, kernel settings, logs, auto-updates.

PACKAGES=(
  sudo curl ca-certificates gnupg git stow tmux mosh htop unzip xz-utils
  ripgrep fd-find locales btop fastfetch
  ufw fail2ban python3-systemd
  unattended-upgrades apt-listchanges needrestart
  build-essential pkg-config
)

step_preflight() {
  [[ $EUID -eq 0 ]] || die "Run as root (sudo ./install.sh)."
  . /etc/os-release
  [[ ${ID:-} == debian && ${VERSION_ID:-} == 13 ]] \
    || die "Expected Debian 13, found ${PRETTY_NAME:-unknown}."
}

step_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get -o Dpkg::Options::="--force-confold" full-upgrade -y
  apt_install "${PACKAGES[@]}"
  timedatectl set-timezone "$TIMEZONE" || true
}

# macOS ssh forwards LANG=en_US.UTF-8; generate it so logins don't warn.
step_locale() {
  sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen
  update-locale LANG=en_US.UTF-8
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

step_kernel() {
  render sysctl/99-hardening.conf /etc/sysctl.d/99-hardening.conf
  sysctl --system >/dev/null
}

step_journald() {
  render journald/size.conf /etc/systemd/journald.conf.d/size.conf
  systemctl restart systemd-journald
}

step_auto_updates() {
  render apt/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades
  render apt/52unattended-local /etc/apt/apt.conf.d/52unattended-local
  systemctl enable --now unattended-upgrades
}
