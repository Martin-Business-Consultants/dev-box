# User environment: dotfiles (stow), mise tools, Claude Code, Neovim.
# step_repo and load_git_identity run as root; the other steps run as NEW_USER.

STOW_FLAT=(bash git mise)  # files linked individually (~/.config stays a real dir)
STOW_FOLDED=(nvim)         # dir linked whole, so vim.pack's lockfile lands in the repo

user_dotfiles() { echo "/home/$NEW_USER/dotfiles"; }

# Environment for --as-user runs.
user_env() {
  DOTFILES="$HOME/dotfiles"
  export PATH="$HOME/.local/bin:$PATH"
  export MISE_YES=1
  # sudo -u doesn't set these; `systemctl --user` (rex server install) needs them
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
}

# Use GIT_NAME/GIT_EMAIL from env, else the user's existing config, else ask.
load_git_identity() {
  local existing="/home/$NEW_USER/.gitconfig.local"
  if [[ -f $existing ]] && has git; then
    : "${GIT_NAME:=$(git config -f "$existing" user.name || true)}"
    : "${GIT_EMAIL:=$(git config -f "$existing" user.email || true)}"
  fi
  [[ -n $GIT_NAME ]]  || ask GIT_NAME  "Git name (e.g. Jane Doe)"
  [[ -n $GIT_EMAIL ]] || ask GIT_EMAIL "Git email"
  [[ $GIT_EMAIL == *@*.* ]] || die "That doesn't look like an email: $GIT_EMAIL"
}

# Copy this repo into the user's home so stow links point at a user-owned copy.
step_repo() {
  local dest
  dest=$(user_dotfiles)
  if [[ $ROOT == "$dest" ]]; then
    echo "Running from $dest already."
  elif [[ -e $dest ]]; then
    warn "$dest exists; leaving it alone."
  else
    cp -a "$ROOT" "$dest"
    chown -R "$NEW_USER:$NEW_USER" "$dest"
  fi
}

step_dotfiles() {
  mkdir -p "$HOME/.config" "$HOME/.local/bin"
  ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

  if [[ -n ${GIT_NAME:-} ]]; then
    git config -f "$HOME/.gitconfig.local" user.name "$GIT_NAME"
    git config -f "$HOME/.gitconfig.local" user.email "$GIT_EMAIL"
  fi

  backup_conflicts "${STOW_FLAT[@]}" "${STOW_FOLDED[@]}"
  stow -d "$DOTFILES" -t "$HOME" --restow --no-folding "${STOW_FLAT[@]}"
  stow -d "$DOTFILES" -t "$HOME" --restow "${STOW_FOLDED[@]}"
}

# Move real files that would block stow (e.g. Debian's default ~/.bashrc)
# to *.bak. Skips anything that already resolves into the repo.
backup_conflicts() {
  local pkg file target
  for pkg in "$@"; do
    while IFS= read -r -d '' file; do
      target="$HOME/${file#"$DOTFILES/$pkg/"}"
      [[ -e $target ]] || continue
      [[ $(realpath "$target") == "$DOTFILES"/* ]] && continue
      warn "Backing up $target -> $target.bak"
      mv "$target" "$target.bak"
    done < <(find "$DOTFILES/$pkg" -type f -print0)
  done
}

step_mise() {
  has mise || run_installer https://mise.run
  mise install node ruby  # npm: and gem: tools need these first
  mise install
  mise reshim
}

step_claude() {
  has claude || run_installer https://claude.ai/install.sh bash
}

# Install plugins (vim.pack runs on startup) and compile treesitter parsers.
# One compile at a time: parallel builds get OOM-killed on 1GB boxes.
step_neovim() {
  mise exec -- nvim --headless \
    "+lua require('nvim-treesitter').install(vim.g.ts_langs, { max_jobs = 1 }):wait(1800000)" +qa \
    || warn "Neovim bootstrap had errors; open nvim and run :TSUpdate."
}

step_versions() {
  local tool
  for tool in mise node ruby nvim gh opencode claude; do
    printf '  %-9s %s\n' "$tool" "$(mise exec -- "$tool" --version 2>/dev/null | head -1 || echo '?')"
  done
}
