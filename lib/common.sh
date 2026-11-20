# Shared helpers. Sourced by install.sh; expects $ROOT.

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

# in_list NEEDLE ITEM...
in_list() {
  local needle=$1 item; shift
  for item in "$@"; do [[ $item == "$needle" ]] && return 0; done
  return 1
}

# ask VAR "Prompt": read a non-empty value from the terminal into VAR.
ask() {
  local var=$1 prompt=$2 value=""
  while [[ -z $value ]]; do
    read -r -p "$prompt: " value </dev/tty || die "No TTY for prompt; set $var in env."
  done
  printf -v "$var" '%s' "$value"
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

# run_installer URL [SHELL]: pipe a vendor install script into a shell.
run_installer() {
  curl -fsSL "$1" | "${2:-sh}"
}

# render TEMPLATE DEST [MODE]: install system/TEMPLATE to DEST,
# replacing every @VAR@ placeholder with the value of $VAR.
render() {
  local src="$ROOT/system/$1" dest=$2 mode=${3:-644} content var
  content=$(<"$src")
  for var in $(grep -o '@[A-Z_]*@' "$src" | sort -u | tr -d @); do
    content=${content//@$var@/${!var}}
  done
  install -D -m "$mode" /dev/stdin "$dest" <<<"$content"
}
