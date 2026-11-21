# Rex's installer adds its apt repo. Linger keeps the user's Rex sessions alive after logout.
step_rex() {
  run_installer https://pkgs.superlogical.com/rex/install.sh
  loginctl enable-linger "$NEW_USER"
}

step_rex_server() {
  rex server install
}
