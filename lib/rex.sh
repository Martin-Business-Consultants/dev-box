# Rex server: sessions live on this box; Rex on your Macs attaches to them via
# Settings > Remote Hosts (ssh://<user>@<host>).

# As root: Rex's installer adds its apt repo (+ a pin over Debian's unrelated
# `rex` package), so updates arrive with apt. Linger keeps the user's systemd
# manager, and so their Rex sessions, alive after they log out.
step_rex() {
  run_installer https://pkgs.superlogical.com/rex/install.sh
  loginctl enable-linger "$NEW_USER"
}

# As NEW_USER: run a personal Rex server at boot.
step_rex_server() {
  rex server install
}
