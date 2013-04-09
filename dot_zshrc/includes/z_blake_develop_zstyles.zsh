function dv() {
  for gem in $*; do; $(develop $gem); done
  bundle | grep from | column -t
}
function dr() {
  for gem in $*; do; $(develop --reset $gem); done
  bundle | grep from | column -t
}

BLAKE_GEMS='blake-common blake-shared blake-corpus blake-data-source blake-data-models caper-activities Caper kafka-rb lograge'

_blake_gems() {
  _arguments -s : \
    '--reset' \
    ":develop:($BLAKE_GEMS)"
}

compdef _blake_gems develop
compdef _blake_gems dv
compdef _blake_gems dr

