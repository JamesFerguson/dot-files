" Strip trailing whitespace on open (e flag suppresses errors like 'not found')
au BufReadPost * %s/\s\+$//e

" Kill hashrockets with fire
au BufReadPost *.rb %s/\([^:]\):\(\w\+\) =>/\1\2:/ge
