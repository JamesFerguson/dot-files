" Searching
set hlsearch
set incsearch
set ignorecase
set smartcase

" Without setting this, ZoomWin restores windows in a way that causes
" equalalways behavior to be triggered the next time CommandT is used.
" This is likely a bludgeon to solve some other issue, but it works
set noequalalways

" Command-T configuration
let g:CommandTMaxHeight=20
let g:CommandTMaxFiles=25000
set wildignore+=.git,.svn,.o,.obj,app/assets/fonts,app/assets/images,public,tmp,log,*swp

" ZoomWin configuration
map <Leader><Leader> :ZoomWin<CR>

" NERDTree configuration
let NERDTreeIgnore=['\.pyc$', '\.rbc$', '\~$']
map <Leader>n :NERDTreeToggle<CR>

" Use ag for ack.vim
let g:ackprg = 'ag --nogroup --nocolor --column'
