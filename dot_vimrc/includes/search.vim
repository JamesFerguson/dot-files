" Searching
set hlsearch
set incsearch
set ignorecase
set smartcase

set wildignore+=*/tmp/*,*.so,*.swp,*.zip,.git,.svn,.o,.obj,app/assets/fonts,app/assets/images,lib/legacy-plugins,spec/vcr_cassettes,public,tmp,log,*swp

" NERDTree configuration
let NERDTreeIgnore=['\.pyc$', '\.rbc$', '\~$']
map <Leader>n <plug>NERDTreeMirrorToggle<CR>

" Use ag for ack.vim
let g:ackprg = 'ag --nogroup --nocolor --column'
