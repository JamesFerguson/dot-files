# https://stackoverflow.com/questions/3231804/in-bash-how-to-add-are-you-sure-y-n-to-any-command-or-alias
# Adapted for zsh
#
# Pass a prompt or it defaults to "Continue?"
# example usage:
#   prompt_confirm "Overwrite File?" || exit 0
prompt_confirm() {
  while true; do
    read -k 1 "REPLY?${1:-Continue?} [y/n]: "
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input, 'y' or 'n' expected"
    esac
    REPLY='' # clear variables after use
  done
}
