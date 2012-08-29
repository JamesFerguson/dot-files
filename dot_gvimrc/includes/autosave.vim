" Write file when a buffer is closed
set autowrite

" write files when mVim loses focus (prob gui only; some cli versions can detect this too)
au FocusLost * silent! wa
