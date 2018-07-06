" Searching
set tags+=gems.tags
set hlsearch
set incsearch
set ignorecase
set smartcase

set wildignore+=*/tmp/*,*.so,*.swp,*.zip,.git,.svn,.o,.obj,app/assets/fonts,app/assets/images,lib/legacy-plugins,spec/vcr_cassettes,public,tmp,log,*swp

" NERDTree configuration
let NERDTreeIgnore=['\.pyc$', '\.rbc$', '\~$']
map <Leader>n <plug>NERDTreeMirrorToggle<CR>
let NERDTreeShowHidden=1

" Use ag for ack.vim
"let g:ackprg = 'ag --nogroup --nocolor --column'

" Use ripgrep for CtrlP
" https://elliotekj.com/2016/11/22/setup-ctrlp-to-use-ripgrep-in-vim/
" http://www.wezm.net/technical/2016/09/ripgrep-with-vim/

" Use rg over grep
set grepprg=rg\ --vimgrep\ --no-heading
set grepformat=%f:%l:%c:%m,%f:%l:%m

" Use rg in ack.vim
let g:ackprg = 'rg --vimgrep --no-heading'

" Use rg in CtrlP for listing files. Lightning fast and respects .gitignore
let g:ctrlp_user_command = 'rg %s --files --color=never --glob ""'

" rg is fast enough that CtrlP doesn't need to cache
let g:ctrlp_use_caching = 0

" set ctrlp's cwd at startup to the ancestor dir of the file param that is a
" repo
let g:ctrlp_working_path_mode = 'ra'

" e - jump when <cr> is pressed, but only to windows in the current tab.
" t - jump when <c-t> is pressed, but only to windows in another tab.
let g:ctrlp_switch_buffer = 'et'
