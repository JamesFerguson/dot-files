set number
set ruler

" set list listchars=tab:▶,eol:¶

" Status bar
set laststatus=2

" Remember last location in file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal g'\"" | endif
endif

" Use modeline overrides
set modeline
set modelines=10

" Show (partial) command in the status line
set showcmd


