# (main*↑1↓2): branch, uncommitted changes, commits ahead/behind upstream
git_info() {
  local branch counts ahead behind
  branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
  [[ -n $(git status --porcelain 2>/dev/null) ]] && branch+='*'
  if counts=$(git rev-list --left-right --count @{u}...HEAD 2>/dev/null); then
    read -r behind ahead <<<"$counts"
    (( ahead ))  && branch+="↑$ahead"
    (( behind )) && branch+="↓$behind"
  fi
  printf ' (%s)' "$branch"
}

# [node 22.11.0]: tools pinned by the current project's mise config
mise_info() {
  local tools
  tools=$(mise ls --current --local 2>/dev/null | awk '{ printf "%s%s %s", sep, $1, $2; sep = ", " }')
  [[ -n $tools ]] && printf ' [%s]' "$tools"
}

PS1='\[\e[01;32m\]\u@\h\[\e[00m\]:\[\e[01;34m\]\w\[\e[33m\]$(git_info)\[\e[35m\]$(mise_info)\[\e[00m\]\$ '

case $TERM in
  xterm*|rxvt*) PS1="\[\e]0;\u@\h: \w\a\]$PS1" ;;
esac
