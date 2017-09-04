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
