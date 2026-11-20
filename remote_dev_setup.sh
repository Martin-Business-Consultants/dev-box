#!/usr/bin/env bash
# Harden + provision a fresh Debian 13 (trixie) VPS for AI-assisted development.
#
#   scp remote_dev_setup.sh root@<ip>:
#   ssh -t root@<ip> 'NEW_USER=ted bash remote_dev_setup.sh'
#
# Installs: Tailscale, Claude Code, opencode, mise (Node + Ruby latest),
# Neovim 0.12+ IDE (vim.pack + mini.nvim + treesitter + LSP), git config,
# all dotfiles managed with GNU stow in ~/dotfiles.
#
# Keep your current root session open until you've confirmed you can log in
# as NEW_USER in a second terminal.

set -euo pipefail

# ---------------- config (override via env) ----------------
NEW_USER="${NEW_USER:-dev}"
SSH_PUBKEY="${SSH_PUBKEY:-}"            # if empty, copies /root/.ssh/authorized_keys
SWAP_SIZE="${SWAP_SIZE:-2G}"            # important on 1GB droplets
TIMEZONE="${TIMEZONE:-UTC}"
SUDO_NOPASSWD="${SUDO_NOPASSWD:-yes}"   # user has no password (key-only login)
AUTO_REBOOT="${AUTO_REBOOT:-true}"      # reboot at 04:00 if updates need it
TS_AUTHKEY="${TS_AUTHKEY:-}"            # optional; without it you log in via URL
TS_ONLY_SSH="${TS_ONLY_SSH:-yes}"       # if Tailscale joins, close public port 22
GIT_NAME="${GIT_NAME:-}"                # prompted if empty
GIT_EMAIL="${GIT_EMAIL:-}"              # prompted if empty
# ------------------------------------------------------------

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."
. /etc/os-release
[[ "${ID:-}" == "debian" && "${VERSION_ID:-}" == "13" ]] || die "Expected Debian 13, found ${PRETTY_NAME:-unknown}."

# ---------------- prompts (up front, so the rest runs unattended) ----------------
ask() {  # ask VAR "Prompt"
  local __var=$1 __prompt=$2 __val=""
  while [[ -z "$__val" ]]; do
    read -r -p "$__prompt: " __val </dev/tty || die "No TTY for prompt; set $__var in env."
  done
  printf -v "$__var" '%s' "$__val"
}
[[ -n "$GIT_NAME"  ]] || ask GIT_NAME  "Git name (e.g. Jane Doe)"
[[ -n "$GIT_EMAIL" ]] || ask GIT_EMAIL "Git email"
[[ "$GIT_EMAIL" == *@*.* ]] || die "That doesn't look like an email: $GIT_EMAIL"

export DEBIAN_FRONTEND=noninteractive

log "Updating system"
apt-get update -y
apt-get -o Dpkg::Options::="--force-confold" full-upgrade -y
apt-get install -y --no-install-recommends \
  sudo curl ca-certificates gnupg git stow tmux mosh htop unzip xz-utils \
  ripgrep fd-find \
  ufw fail2ban python3-systemd unattended-upgrades apt-listchanges needrestart \
  build-essential pkg-config

timedatectl set-timezone "$TIMEZONE" || true

# macOS ssh forwards LANG=en_US.UTF-8; generate it so logins don't warn
log "Generating en_US.UTF-8 locale"
apt-get install -y --no-install-recommends locales
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# ---------------- user ----------------
log "Creating user $NEW_USER"
if ! id "$NEW_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$NEW_USER"
fi
usermod -aG sudo "$NEW_USER"

install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "/home/$NEW_USER/.ssh"
AUTH_KEYS="/home/$NEW_USER/.ssh/authorized_keys"
if [[ -n "$SSH_PUBKEY" ]]; then
  echo "$SSH_PUBKEY" > "$AUTH_KEYS"
elif [[ -s /root/.ssh/authorized_keys ]]; then
  cp /root/.ssh/authorized_keys "$AUTH_KEYS"
fi
[[ -s "$AUTH_KEYS" ]] || die "No SSH key for $NEW_USER. Set SSH_PUBKEY. Aborting before locking SSH."
chown "$NEW_USER:$NEW_USER" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

if [[ "$SUDO_NOPASSWD" == "yes" ]]; then
  echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$NEW_USER"
  chmod 440 "/etc/sudoers.d/90-$NEW_USER"
  visudo -cf "/etc/sudoers.d/90-$NEW_USER"
fi

passwd -l root

# ---------------- swap ----------------
if ! swapon --show | grep -q .; then
  log "Creating ${SWAP_SIZE} swap"
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# ---------------- sysctl ----------------
log "Applying sysctl hardening"
cat > /etc/sysctl.d/99-hardening.conf <<'EOF'
vm.swappiness = 10
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.log_martians = 1
EOF
sysctl --system >/dev/null

# ---------------- journald (small disks) ----------------
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/size.conf <<'EOF'
[Journal]
SystemMaxUse=200M
EOF
systemctl restart systemd-journald

# ---------------- unattended upgrades ----------------
log "Enabling unattended upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
cat > /etc/apt/apt.conf.d/52unattended-local <<EOF
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "${AUTO_REBOOT}";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
EOF
systemctl enable --now unattended-upgrades

# ---------------- fail2ban ----------------
log "Configuring fail2ban"
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
backend  = systemd
bantime  = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1 100.64.0.0/10

[sshd]
enabled = true
EOF
systemctl enable fail2ban
systemctl restart fail2ban

# ---------------- sshd ----------------
log "Hardening sshd"
# 00- prefix: sshd uses first match, so this beats 50-cloud-init.conf
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
AllowUsers ${NEW_USER}
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowAgentForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
sshd -t || die "sshd config invalid; not restarting."
systemctl restart ssh

# ---------------- firewall ----------------
log "Configuring ufw"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw --force enable

# ---------------- tailscale ----------------
log "Installing Tailscale"
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable --now tailscaled

TS_ARGS=(--ssh --hostname="$(hostname)" --timeout=10m)
if [[ -n "$TS_AUTHKEY" ]]; then
  TS_ARGS+=(--authkey="$TS_AUTHKEY")
else
  echo "No TS_AUTHKEY set: open the login URL printed below to add this machine to your tailnet."
fi

if tailscale up "${TS_ARGS[@]}" && tailscale status &>/dev/null; then
  ufw allow in on tailscale0
  if [[ "$TS_ONLY_SSH" == "yes" ]]; then
    log "Closing public SSH (Tailscale only)"
    ufw delete allow OpenSSH
  fi
else
  echo "Tailscale did not come up; leaving public SSH open. Run 'sudo tailscale up --ssh' later."
fi

# ---------------- user environment (dotfiles, mise, tools) ----------------
log "Setting up dotfiles + dev tools for $NEW_USER"
sudo -u "$NEW_USER" -H env GIT_NAME="$GIT_NAME" GIT_EMAIL="$GIT_EMAIL" bash -s <<'USERSETUP'
set -euo pipefail
cd "$HOME"
DOT="$HOME/dotfiles"
export PATH="$HOME/.local/bin:$PATH"
export MISE_YES=1

mkdir -p "$DOT"/{git,bash,mise/.config/mise,nvim/.config/nvim} "$HOME/.config" "$HOME/.local/bin"
ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

# --- git ---
cat > "$DOT/git/.gitconfig" <<EOF
[user]
	name = ${GIT_NAME}
	email = ${GIT_EMAIL}
[init]
	defaultBranch = main
[pull]
	rebase = true
[push]
	autoSetupRemote = true
[fetch]
	prune = true
[rebase]
	autoStash = true
[diff]
	algorithm = histogram
[merge]
	conflictstyle = zdiff3
[core]
	editor = vi
EOF

# --- bash: adopt Debian's default .bashrc into the repo, then extend it ---
if [[ ! -L "$HOME/.bashrc" && -f "$HOME/.bashrc" && ! -f "$DOT/bash/.bashrc" ]]; then
  mv "$HOME/.bashrc" "$DOT/bash/.bashrc"
fi
touch "$DOT/bash/.bashrc"
if ! grep -q 'mise activate' "$DOT/bash/.bashrc"; then
  cat >> "$DOT/bash/.bashrc" <<'EOF'

# --- dev tools ---
export PATH="$HOME/.local/bin:$PATH"
command -v mise >/dev/null && eval "$(mise activate bash)"
EOF
fi

# --- mise global tools ---
cat > "$DOT/mise/.config/mise/config.toml" <<'EOF'
[tools]
node = "latest"
ruby = "latest"
neovim = "latest"
# aqua = prebuilt binaries (mise runs npm with --ignore-scripts, which breaks
# npm packages that download a binary in postinstall)
"aqua:anomalyco/opencode" = "latest"
"aqua:tree-sitter/tree-sitter" = "latest"
# language servers for Neovim
lua-language-server = "latest"
"npm:typescript" = "latest"
"npm:typescript-language-server" = "latest"
"npm:vscode-langservers-extracted" = "latest"
"npm:bash-language-server" = "latest"
"gem:ruby-lsp" = "latest"

[settings]
ruby.compile = false   # precompiled Ruby only; never fall back to ruby-build
EOF

# --- neovim (0.12+: vim.pack + mini.nvim) ---
cat > "$DOT/nvim/.config/nvim/init.lua" <<'NVIM'
-- Neovim 0.12+ IDE: vim.pack + mini.nvim + treesitter + LSP
-- Update plugins: :lua vim.pack.update()    Update parsers: :TSUpdate
-- Press <Space> and wait to see all leader mappings (mini.clue).

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Rebuild treesitter parsers whenever nvim-treesitter itself updates
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    if ev.data.spec.name == 'nvim-treesitter' and ev.data.kind == 'update' then
      if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
      vim.cmd('TSUpdate')
    end
  end,
})

vim.pack.add({
  'https://github.com/nvim-mini/mini.nvim',
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/rafamadriz/friendly-snippets',
}, { confirm = false })

local map = function(lhs, rhs, desc, mode)
  vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc })
end

-- ============================ Options ============================
require('mini.basics').setup({
  options = { extra_ui = true },
  mappings = { windows = true },
  autocommands = { relnum_in_visual_mode = true },
})
local o = vim.o
o.relativenumber = true
o.scrolloff = 8
o.sidescrolloff = 8
o.tabstop = 2
o.shiftwidth = 2
o.expandtab = true
o.updatetime = 250
o.confirm = true
o.winborder = 'rounded'
o.clipboard = 'unnamedplus'

-- Over SSH: yank to your local clipboard via OSC 52; paste from nvim's register
if vim.env.SSH_TTY then
  local osc52 = require('vim.ui.clipboard.osc52')
  local paste = function() return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') } end
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
    paste = { ['+'] = paste, ['*'] = paste },
  }
end

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, source = 'if_many' },
  float = { source = 'if_many' },
  signs = true,
  underline = true,
})

-- ============================ UI ============================
require('mini.icons').setup()
MiniIcons.mock_nvim_web_devicons()
if not pcall(vim.cmd.colorscheme, 'miniwinter') then vim.cmd.colorscheme('default') end

require('mini.notify').setup()
vim.notify = MiniNotify.make_notify()
require('mini.statusline').setup()
require('mini.tabline').setup()
require('mini.sessions').setup({ autowrite = true })
require('mini.starter').setup()
require('mini.cursorword').setup()
require('mini.trailspace').setup()
require('mini.indentscope').setup({
  draw = { animation = require('mini.indentscope').gen_animation.none() },
})

local hipatterns = require('mini.hipatterns')
hipatterns.setup({
  highlighters = {
    fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
    hack  = { pattern = '%f[%w]()HACK()%f[%W]',  group = 'MiniHipatternsHack' },
    todo  = { pattern = '%f[%w]()TODO()%f[%W]',  group = 'MiniHipatternsTodo' },
    note  = { pattern = '%f[%w]()NOTE()%f[%W]',  group = 'MiniHipatternsNote' },
    hex_color = hipatterns.gen_highlighter.hex_color(),
  },
})

local miniclue = require('mini.clue')
miniclue.setup({
  triggers = {
    { mode = 'n', keys = '<Leader>' }, { mode = 'x', keys = '<Leader>' },
    { mode = 'n', keys = 'g' },        { mode = 'x', keys = 'g' },
    { mode = 'n', keys = "'" },        { mode = 'n', keys = '`' },
    { mode = 'x', keys = "'" },        { mode = 'x', keys = '`' },
    { mode = 'n', keys = '"' },        { mode = 'x', keys = '"' },
    { mode = 'i', keys = '<C-r>' },    { mode = 'c', keys = '<C-r>' },
    { mode = 'i', keys = '<C-x>' },
    { mode = 'n', keys = '<C-w>' },
    { mode = 'n', keys = 'z' },        { mode = 'x', keys = 'z' },
    { mode = 'n', keys = '[' },        { mode = 'n', keys = ']' },
  },
  clues = {
    { mode = 'n', keys = '<Leader>a', desc = '+AI' },
    { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
    { mode = 'n', keys = '<Leader>f', desc = '+Find' },
    { mode = 'n', keys = '<Leader>g', desc = '+Git' },
    { mode = 'n', keys = '<Leader>l', desc = '+LSP' },
    { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
    miniclue.gen_clues.builtin_completion(),
    miniclue.gen_clues.g(),
    miniclue.gen_clues.marks(),
    miniclue.gen_clues.registers(),
    miniclue.gen_clues.windows(),
    miniclue.gen_clues.z(),
  },
  window = { delay = 300 },
})

-- ============================ Editing ============================
require('mini.ai').setup()
require('mini.align').setup()
require('mini.bracketed').setup()
require('mini.bufremove').setup()
require('mini.jump').setup()
require('mini.move').setup()       -- Alt-h/j/k/l moves lines/selections
require('mini.pairs').setup()
require('mini.splitjoin').setup()  -- gS
require('mini.surround').setup()   -- sa / sd / sr
require('mini.misc').setup()
MiniMisc.setup_restore_cursor()
MiniMisc.setup_auto_root()

local snippets = require('mini.snippets')
snippets.setup({ snippets = { snippets.gen_loader.from_lang() } })  -- expand: <C-j>

require('mini.completion').setup()
vim.keymap.set('i', '<Tab>',   [[pumvisible() ? "\<C-n>" : "\<Tab>"]],   { expr = true })
vim.keymap.set('i', '<S-Tab>', [[pumvisible() ? "\<C-p>" : "\<S-Tab>"]], { expr = true })
_G.cr_action = function()
  if vim.fn.complete_info()['selected'] ~= -1 then return '\25' end -- <C-y>
  return MiniPairs.cr()
end
vim.keymap.set('i', '<CR>', 'v:lua.cr_action()', { expr = true })

-- ============================ Navigation ============================
require('mini.files').setup({ windows = { preview = true, width_preview = 60 } })
require('mini.pick').setup()
require('mini.extra').setup()
require('mini.visits').setup()
vim.ui.select = MiniPick.ui_select

map('<Leader>e', function() MiniFiles.open(vim.api.nvim_buf_get_name(0)) end, 'Explorer (file)')
map('<Leader>E', function() MiniFiles.open() end, 'Explorer (cwd)')
map('<Leader><Space>', '<Cmd>Pick files<CR>', 'Find files')
map('<Leader>/', '<Cmd>Pick grep_live<CR>', 'Grep')
map('<Leader>ff', '<Cmd>Pick files<CR>', 'Files')
map('<Leader>fg', '<Cmd>Pick grep_live<CR>', 'Grep live')
map('<Leader>fw', '<Cmd>Pick grep pattern="<cword>"<CR>', 'Grep word')
map('<Leader>fb', '<Cmd>Pick buffers<CR>', 'Buffers')
map('<Leader>fh', '<Cmd>Pick help<CR>', 'Help')
map('<Leader>fr', '<Cmd>Pick resume<CR>', 'Resume')
map('<Leader>fo', '<Cmd>Pick oldfiles<CR>', 'Recent files')
map('<Leader>fv', '<Cmd>Pick visit_paths<CR>', 'Visited paths')
map('<Leader>fd', '<Cmd>Pick diagnostic<CR>', 'Diagnostics')
map('<Leader>fk', '<Cmd>Pick keymaps<CR>', 'Keymaps')
map('<Leader>fc', '<Cmd>Pick commands<CR>', 'Commands')
map('<Leader>fs', '<Cmd>Pick lsp scope="document_symbol"<CR>', 'Symbols (buffer)')
map('<Leader>fS', '<Cmd>Pick lsp scope="workspace_symbol"<CR>', 'Symbols (workspace)')

map('<Leader>bd', function() MiniBufremove.delete() end, 'Delete buffer')
map('<Leader>bo', '<Cmd>%bd|e#|bd#<CR>', 'Delete other buffers')
map('<Leader>w', '<Cmd>write<CR>', 'Write')
map('<Leader>q', '<Cmd>quit<CR>', 'Quit')
map('<Esc>', '<Cmd>nohlsearch<CR>', 'Clear search')

-- ============================ Git ============================
require('mini.git').setup()
require('mini.diff').setup({ view = { style = 'sign' } })
map('<Leader>gs', function() MiniGit.show_at_cursor() end, 'Show at cursor')
map('<Leader>gd', function() MiniDiff.toggle_overlay() end, 'Diff overlay')
map('<Leader>gb', '<Cmd>vertical Git blame -- %<CR>', 'Blame')
map('<Leader>gl', '<Cmd>Pick git_commits<CR>', 'Log')
map('<Leader>gh', '<Cmd>Pick git_hunks<CR>', 'Hunks')

-- ============================ Terminal / AI ============================
map('<Leader>tt', '<Cmd>botright 15split | terminal<CR>', 'Terminal')
map('<Leader>ac', '<Cmd>botright vsplit | terminal claude<CR>', 'Claude Code')
map('<Leader>ao', '<Cmd>botright vsplit | terminal opencode<CR>', 'opencode')
vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], { desc = 'Exit terminal mode' })
vim.api.nvim_create_autocmd('TermOpen', { command = 'setlocal nonumber norelativenumber | startinsert' })

-- ============================ Treesitter ============================
vim.g.ts_langs = {
  'bash', 'css', 'diff', 'dockerfile', 'embedded_template', 'git_config',
  'html', 'javascript', 'jsdoc', 'json', 'lua', 'luadoc', 'markdown', 'markdown_inline',
  'query', 'regex', 'ruby', 'sql', 'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml',
}
if #vim.api.nvim_list_uis() > 0 then
  require('nvim-treesitter').install(vim.g.ts_langs, { max_jobs = 1 }) -- async; no-op when installed
end
vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev)
    if pcall(vim.treesitter.start, ev.buf) then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- ============================ LSP ============================
-- Servers are installed by mise (see ~/.config/mise/config.toml)
vim.lsp.config('*', { capabilities = MiniCompletion.get_lsp_capabilities() })
vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
    },
  },
})
vim.lsp.enable({ 'lua_ls', 'ts_ls', 'ruby_lsp', 'bashls', 'jsonls', 'cssls', 'html' })

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local buf = function(lhs, rhs, desc, mode)
      vim.keymap.set(mode or 'n', lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    buf('gd', vim.lsp.buf.definition, 'Definition')
    buf('gD', vim.lsp.buf.declaration, 'Declaration')
    buf('<Leader>la', vim.lsp.buf.code_action, 'Code action', { 'n', 'x' })
    buf('<Leader>lr', vim.lsp.buf.rename, 'Rename')
    buf('<Leader>lf', function() vim.lsp.buf.format({ async = true }) end, 'Format', { 'n', 'x' })
    buf('<Leader>lR', '<Cmd>Pick lsp scope="references"<CR>', 'References')
    buf('<Leader>ld', vim.diagnostic.open_float, 'Line diagnostics')
    buf('<Leader>li', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
    end, 'Toggle inlay hints')
  end,
})
NVIM

# --- stow everything (no-folding so ~/.config itself stays a real dir) ---
cd "$DOT"
stow --no-folding --restow --target="$HOME" git bash mise
# nvim folds to a symlinked dir so vim.pack's lockfile lands in the repo
stow --restow --target="$HOME" nvim
cd "$HOME"

# --- mise ---
if ! command -v mise >/dev/null; then
  curl -fsSL https://mise.run | sh
fi
mise install node
mise install          # ruby (precompiled) + opencode
mise reshim

# --- Claude Code (native installer, no Node needed) ---
if ! command -v claude >/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# --- Neovim: install plugins + treesitter parsers headlessly ---
mise exec -- nvim --headless \
  "+lua require('nvim-treesitter').install(vim.g.ts_langs, { max_jobs = 1 }):wait(1800000)" +qa \
  || echo "Neovim bootstrap had errors; open nvim and run :TSUpdate."

# --- version the dotfiles ---
git -C "$DOT" init -q
git -C "$DOT" add -A
git -C "$DOT" diff --cached --quiet || git -C "$DOT" commit -qm "Update dotfiles"

echo
echo "Installed:"
echo "  mise     $(mise --version 2>/dev/null | head -1)"
echo "  node     $(mise exec -- node --version 2>/dev/null)"
echo "  ruby     $(mise exec -- ruby --version 2>/dev/null)"
echo "  nvim     $(mise exec -- nvim --version 2>/dev/null | head -1)"
echo "  opencode $(mise exec -- opencode --version 2>/dev/null || echo '?')"
echo "  claude   $(claude --version 2>/dev/null || echo '?')"
USERSETUP

log "Done"
cat <<EOF
Next steps:
  1. In a NEW terminal, confirm login works:
       ssh ${NEW_USER}@<ip>        (or: ssh ${NEW_USER}@$(hostname) via Tailscale)
  2. Only then close this root session.
  3. Reboot if the kernel was upgraded:  sudo reboot
  4. Run 'claude' and 'opencode' to sign in.
  5. Optional: push ~/dotfiles to a private repo.
Firewall:
$(ufw status verbose)
EOF
