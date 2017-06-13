" allow backspacing over everything in insert mode
set backspace=indent,eol,start

" Fuzzy find files with Ctrl-P
map <Leader>t :CtrlPMixed <CR>

" Opens an edit command with the path of the currently edited file filled in
" Normal mode: <Leader>e
map <Leader>e :e <C-R>=expand("%:p:h") . "/" <CR>

" Opens a tab edit command with the path of the currently edited file filled in
" Normal mode: <Leader>t
map <Leader>te :tabe <C-R>=expand("%:p:h") . "/" <CR>

" Inserts the path of the currently edited file into a command
" Command mode: Ctrl+P
cmap <C-P> <C-R>=expand("%:p:h") . "/" <CR>

" OverCommandLine - for visual find and replace
map <Leader>r :OverCommandLine %s/<CR>

" Unimpaired configuration
" Bubble single lines
nmap <C-Up> [e
nmap <C-Down> ]e
" Bubble multiple lines
vmap <C-Up> [egv
vmap <C-Down> ]egv

" MacVIM shift+arrow-keys behavior (required in .vimrc)
let g:macvim_hig_shift_movement = 1

" % to bounce from do to end etc.
runtime! macros/matchit.vim

" Use very magic mode (start regexes with /\v...) for all regexes
"  Switch off anywhere in a regex with \V.
nnoremap / /\v
vnoremap / /\v
