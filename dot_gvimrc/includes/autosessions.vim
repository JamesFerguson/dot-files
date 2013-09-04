" save sessions in root folder with .vis extension
map <leader>s :mksession! session.vis<CR>

" automatically source vim sessions so I can open them with the finder
" or alt+space then open .vis
au BufRead *.vis so %

" work around nerdtree/sessions bug by closing nerdtree before VimLeave
au VimLeavePre * silent! :NERDTreeTabsClose

" write session when mVim loses focus and when it closes
au FocusLost * silent! :mksession! session.vis
au VimLeave * silent! :mksession! session.vis
