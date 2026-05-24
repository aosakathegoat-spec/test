#!/bin/sh
# Charlie Kirk OS — shell environment

# Themed prompt: red-white-blue patriot colors
export PS1='\[\033[1;31m\][TPUSA]\[\033[0m\] \[\033[1;34m\]\u\[\033[0m\]@\[\033[1;37m\]tpusa-os\[\033[0m\]:\[\033[1;33m\]\w\[\033[0m\]\$ '

# Patriot aliases
alias freedom='echo "FREEDOM ACHIEVED."'
alias capitalism='echo "Free markets: the engine of prosperity."'
alias socialism='echo "ERROR: This feature has been historically disproven."'
alias facts='kirk-facts'
alias quote='kirk-quote'
alias debate='kirk-debate'
alias news='tpusa-news'
alias ll='ls -alF'

# Welcome banner (non-login shells skip motd, so show a mini one)
if [ -z "$MOTD_SHOWN" ]; then
    export MOTD_SHOWN=1
    echo "\033[1;31m  TPUSA-OS\033[0m | \033[1;37mFreedom Shell v1.0\033[0m | type 'quote' for inspiration"
fi
