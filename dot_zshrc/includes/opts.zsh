# see `man zshoptions`
# use `setopt` to see current options
#
setopt AUTO_CD # if cmd unknown try to cd to it
setopt AUTO_PUSHD # cd pushes old dir to stack
setopt PUSHD_MINUS # reverse meaning of +/- w number when using dir stack
setopt PUSHD_SILENT # don't print dir stack after push/pop
setopt PUSHD_TO_HOME # pushd ~= pushd $HOME
setopt CDABLE_VARS # if cd param not dir & doesn't begin w '/' expand it

setopt ALWAYS_TO_END # move to end after completion
unsetopt AUTO_LIST # always list choices on completion (default: on)
# setopt AUTO_MENU # show completion menu after second tab (default: on)
unsetopt AUTO_PARAM_SLASH # add slash when completing dirs (default: on)
# setopt AUTO_REMOVE_SLASH # after complete ending in '/' space removes '/' (default: on)
setopt MENU_COMPLETE # cycle through completion menu (overrides AUTO_MENU)
setopt REC_EXACT # In completion, recognize exact matches even if they are ambiguous

setopt EXTENDED_GLOB # '#~^' part of patterns in globs
setopt GLOB_DOTS # don't require a leading `.' in a filename to match

unsetopt APPEND_HISTORY # (see SHARE_HISTORY) append rather than replace history file on exit (default: on)
unsetopt BANG_HIST # params starting '!' expanded from history (default: on)
setopt EXTENDED_HISTORY		# puts timestamps/durations in the history
setopt HIST_ALLOW_CLOBBER # allow history references to clobber files (overrides NO_CLOBBER)
setopt HIST_IGNORE_ALL_DUPS # when adding cmd to history remove all previous dupes
setopt HIST_REDUCE_BLANKS # remove superfluous blanks from lines added to history
# setopt INC_APPEND_HISTORY # incrementally append each line to history, not on exit
setopt SHARE_HISTORY # commands are appended to and imported from history file (b/w shells)

unsetopt CLOBBER # '>' and '>>' can destroy files, if unset must use '>!', '>|', '>>!' or '>>|'
unsetopt CORRECT # correct the spelling of commands
unsetopt CORRECT_ALL # correct spelling of all arguments (implies CORRECT)
# unsetopt FLOW_CONTROL # allow output flow control via start/stop characters (usually assigned to ^S/^Q) (default: on)
setopt IGNORE_EOF # don't exit on EOF (Ctrl-D), require 'exit', 'logout' or 10xEOF
setopt INTERACTIVE_COMMENTS # allow comments in interactive/terminal sessions
# setopt HASH_CMDS # cache cmd paths (default: on)
# setopt HASH_DIRS # cache dirs containing cmds (default: on)
setopt MAIL_WARNING # warn re new mail
setopt RC_QUOTES # '' within single quoted strings becomes a literal single quote

setopt AUTO_RESUME # tries to resume command of same name when simple word cmd
unsetopt BG_NICE # do NOT nice bg commands
# unsetopt CHECK_JOBS # warn about bg/suspended jobs before exit
# unsetopt HUP # send the HUP signal to running jobs when the shell exits
setopt LONG_LIST_JOBS # list jobs in long format
setopt NOTIFY # report bg job status immediately, not when next printing a prompt (default: on)

