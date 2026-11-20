# remote-dev

Turns a fresh Debian 13 VPS into a hardened remote dev box: Tailscale, GitHub CLI, Claude Code,
opencode, mise (Node + Ruby), and a Neovim 0.12 IDE built on `vim.pack` + mini.nvim.
Dotfiles are managed with GNU stow.

## Usage

```bash
# from your Mac
scp -r ~/remote-dev root@<ip>:
ssh -t root@<ip> 'NEW_USER=ted ~/remote-dev/install.sh'
```

The script asks for your git name and email, then runs unattended. Without
`TS_AUTHKEY` it prints a Tailscale login URL and waits for you to approve it.
Keep the root session open until `ssh <user>@<host>` works from a new terminal.

Re-run any steps later, from the user's copy of the repo:

```bash
sudo ~/dotfiles/install.sh neovim versions
sudo ~/dotfiles/install.sh tailscale firewall
```

## Options (env vars)

| Variable | Default | Meaning |
|---|---|---|
| `NEW_USER` | `dev` | Login user to create |
| `SSH_PUBKEY` | root's keys | Public key for `NEW_USER` |
| `GIT_NAME`, `GIT_EMAIL` | prompted | Written to `~/.gitconfig.local` |
| `TS_AUTHKEY` | empty | Join Tailscale without the login URL |
| `TS_ONLY_SSH` | `yes` | Close public port 22 once Tailscale is up |
| `SWAP_SIZE` | `2G` | Swap file size |
| `TIMEZONE` | `UTC` | System timezone |
| `SUDO_NOPASSWD` | `yes` | Passwordless sudo (the user has no password) |
| `AUTO_REBOOT` | `true` | Reboot at 04:00 when updates need it |

## Steps

System (root): `packages locale swap kernel journald auto_updates user fail2ban sshd tailscale firewall repo`

User (`NEW_USER`): `dotfiles mise claude neovim versions`

## Layout

```
install.sh        entrypoint: config, step order, root/user dispatch
lib/              step functions, grouped by area
  common.sh       helpers: log, ask, render, run_installer…
  system.sh       packages, locale, swap, sysctl, journald, auto-updates
  security.sh     user, SSH keys, sshd, fail2ban
  network.sh      Tailscale, ufw
  user.sh         dotfiles, mise, Claude Code, Neovim
system/           config templates installed under /etc (@VAR@ placeholders)
bash/ git/ mise/ nvim/   stow packages linked into $HOME
```

## Notes

- Docker ignores ufw. Publish ports as `127.0.0.1:3000:3000`.
- mise installs npm packages with `--ignore-scripts`, so tools that download a
  binary at install time use `aqua:` backends instead.
- The `gitcommit` treesitter parser is left out: it can't compile in 1GB RAM.
