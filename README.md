# dev-box

Turns a fresh Debian 13 VPS into a hardened remote dev box: Tailscale, Rex server, GitHub CLI, Claude Code, Podman,
opencode, mise (Node + Ruby), and a Neovim 0.12 IDE built on `vim.pack` + mini.nvim.
Dotfiles are managed with GNU stow.

## Usage

```bash
# from your Mac
gh repo clone Martin-Business-Consultants/dev-box && scp -r dev-box root@<ip>:
ssh -t root@<ip> 'NEW_USER=ted ~/dev-box/install.sh'
```

The script asks for your git name and email, then runs unattended. Without
`TS_AUTHKEY` it prints a Tailscale login URL and waits for you to approve it.
Keep the root session open until `ssh <user>@<host>` works from a new terminal.

Re-run any steps later, from the user's copy of the repo:

```bash
~/dotfiles/install.sh                    # every step
~/dotfiles/install.sh tailscale firewall # just these
```

System steps run through `sudo`, which asks for your password once if needed.

## Options (env vars)

| Variable | Default | Meaning |
|---|---|---|
| `NEW_USER` | `dev` | Login user to create |
| `SSH_PUBKEY` | root's keys | Public key for `NEW_USER` |
| `GIT_NAME`, `GIT_EMAIL` | prompted | Written to `~/.gitconfig.local` |
| `TS_AUTHKEY` | empty | Join Tailscale without the login URL |
| `TS_ONLY_SSH` | `yes` | Close public port 22 once Tailscale is up |
| `SWAP_SIZE` | `2G` | Swap file size |
| `TIMEZONE` | `UTC` | Region/City, e.g. `America/New_York`, `Europe/London`, `Asia/Kolkata` (`timedatectl list-timezones`) |
| `SUDO_NOPASSWD` | `yes` | Passwordless sudo (the user has no password) |
| `AUTO_REBOOT` | `true` | Reboot at 04:00 when updates need it |

## Steps

System (root): `packages locale timezone swap memory kernel journald auto_updates user fail2ban sshd tailscale firewall rex repo`

User (`NEW_USER`): `dotfiles mise claude rex_server neovim versions`

## Layout

```
install.sh        entrypoint: config, step order, root/user dispatch
lib/              step functions, grouped by area
  common.sh       helpers: log, ask, render, run_installer…
  system.sh       packages, locale, timezone, swap, zram, earlyoom, sysctl, journald, auto-updates
  security.sh     user, SSH keys, sshd, fail2ban
  network.sh      Tailscale, ufw
  rex.sh          Rex server (persistent sessions for the Rex app)
  user.sh         dotfiles, mise, Claude Code, Neovim
system/           config templates installed under /etc (@VAR@ placeholders)
bash/ git/ mise/ nvim/   stow packages linked into $HOME
nvim/.config/nvim/lua/config/   one module per area (ui, editing, git, lsp…) + util.lua
```

## Notes

- Containers run on rootless Podman: no daemon, no root. `docker` is an alias
  for `podman`, and published ports respect ufw.
- mise installs npm packages with `--ignore-scripts`, so tools that download a
  binary at install time use `aqua:` backends instead.
- mise only installs precompiled Ruby (`ruby.compile = false`); it never falls back to ruby-build.
- The `gitcommit` treesitter parser is left out: it can't compile in 1GB RAM.
