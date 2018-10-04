# Blake sub tool, bx
eval "$($HOME/Blake/bx/bin/bx init -)"

# Blake deploy tool, bd
eval "$($HOME/Blake/bd/bin/bd init -)"

# Blake secrets tool, bs
unalias bs
eval "$($HOME/Blake/bs/bin/bs init -)"
