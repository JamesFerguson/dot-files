eval "$(fasd --init auto)"

# Emulate 'v', show files matching argument from viminfo db, choose one, then open it in mvim
alias v='f -i -e mvim -b viminfo'