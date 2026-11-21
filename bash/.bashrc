[[ $- == *i* ]] || return

HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend checkwinsize

. ~/.config/bash/prompt.sh

eval "$(dircolors -b ~/.dircolors 2>/dev/null || dircolors -b)"
alias ls='ls --color=auto'

[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases
if ! shopt -oq posix && [[ -f /usr/share/bash-completion/bash_completion ]]; then
  . /usr/share/bash-completion/bash_completion
fi

export PATH="$HOME/.local/bin:$PATH"
command -v mise >/dev/null && eval "$(mise activate bash)"
