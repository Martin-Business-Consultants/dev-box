# dev-box

Turns a fresh Debian 13 VPS into a hardened remote dev box: Tailscale, Rex server, GitHub CLI, Claude Code, Podman,
opencode, mise (Node + Ruby), and a Neovim 0.12 IDE built on `vim.pack` + mini.nvim.
Dotfiles are managed with GNU stow.

## Create a box with one command

`bin/box` does the cloud-init steps below for you: it makes a single-use Tailscale key, fills in
`cloud-init.yaml` (your username, git name and email, and timezone from this machine), creates the
droplet and waits for it to join your tailnet. It needs `curl`, `jq` and two tokens in your
environment, kept in your password manager and never committed:

- `DIGITALOCEAN_ACCESS_TOKEN`: DigitalOcean > API > Generate New Token, custom scopes `droplet`
  (create, read, delete) and `tag` (create).
- `TAILSCALE_API_KEY`: Tailscale admin console > Settings > Keys > Generate access token.

```bash
bin/box new my-dev                     # 1 GB dev box, ready in about 15 minutes
bin/box list                           # boxes made with bin/box
bin/box destroy my-dev                 # deletes the droplet and removes it from the tailnet
```

Any other cloud-init file with `KEY="..."` lines works too. `new` fills each from the environment,
and lists what it filled before creating anything:

```bash
RUNWELL_TOKEN=… CLAUDE_CODE_OAUTH_TOKEN=… GH_TOKEN=… \
  bin/box new runner-1 --tag runner --size s-1vcpu-2gb --user-data ../runwell-runner-box/cloud-init.yaml
```

## Create a box with cloud-init

The box sets itself up on first boot. You never log in as root, and once it's done the only way in
is Tailscale.

1. In Tailscale's admin console (Settings > Keys), make an auth key: pre-approved, single use,
   expiring in a day.
2. Copy [`cloud-init.yaml`](cloud-init.yaml) and fill in `NEW_USER`, `GIT_NAME`, `GIT_EMAIL` and
   `TS_AUTHKEY`.
3. Create a Debian 13 droplet with that file as its user data. In the control panel it's Advanced
   Options > Add Initialization scripts; with the CLI:

   ```bash
   doctl compute droplet create my-dev --image debian-13-x64 --size s-1vcpu-1gb \
     --region nyc3 --user-data-file cloud-init.yaml --wait
   ```

4. Wait for `my-dev` to appear in your tailnet. The install takes about 15 minutes on 1 GB, then the
   box reboots. Connect with `ssh <user>@my-dev`, or add it in Rex.

The droplet's name becomes its tailnet name. If it never joins the tailnet, destroy it and make
another: with public SSH closed and no SSH key, there's no other way in. The droplet's metadata keeps
the auth key, which is why it should be single use and short-lived.

## Install by hand

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
cloud-init.yaml   user data that runs install.sh on a new droplet
bin/box           creates and destroys droplets that use it
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
