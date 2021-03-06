syntax on

set encoding=utf-8
scriptencoding utf-8

function s:setupWrapping()
  set wrap
  set wrapmargin=2
  set textwidth=72
endfunction

function s:setupMarkup()
  call s:setupWrapping()
  map <buffer> <Leader>p :Hammer<CR>
endfunction

" make uses real tabs
au FileType make set noexpandtab

" Thorfile, Rakefile, Vagrantfile and Gemfile are Ruby
au BufRead,BufNewFile {Gemfile,Rakefile,Vagrantfile,Thorfile,config.ru}    set ft=ruby

" md, markdown, and mk are markdown and define buffer-local preview
au BufRead,BufNewFile *.{md,markdown,mdown,mkd,mkdn} call s:setupMarkup()

" add json syntax highlighting
au BufNewFile,BufRead *.json set ft=javascript

au BufRead,BufNewFile *.txt call s:setupWrapping()

" make Python follow PEP8 ( http://www.python.org/dev/peps/pep-0008/ )
au FileType python set softtabstop=4 tabstop=4 shiftwidth=4 textwidth=79

" add an actionscript syntax highlighter
au BufNewFile,BufRead *.as set filetype=actionscript

" emblem syntax
au BufNewFile,BufRead *.emblem set filetype=emblem

" ALE syntax checking
let g:ale_sign_column_always = 1
let g:ale_sign_error = '✗'
let g:ale_sign_warning = '⚠'
let g:airline#extensions#ale#enabled = 1
let g:ale_linters = {
\   'ruby': ['brakeman', 'rails_best_practices', 'reek', 'rubocop'],
\   'text': ['proselint', 'vale'],
\}
call ale#Set('ruby_reek_show_context', 1)
call ale#Set('ruby_reek_show_wiki_link', 1)

" Enable syntastic syntax checking
"let g:syntastic_enable_signs = 1
"let g:syntastic_error_symbol = '✗'
"let g:syntastic_warning_symbol = '⚠'
"let g:syntastic_ruby_checkers = ['mri', 'rubocop', 'ruby-lint']
""let g:syntastic_quiet_messages = {'level': 'warnings'}
"let g:syntastic_enable_elixir_checker = 1
"let g:syntastic_elixir_checkers = ['elixir']
"let g:syntastic_vim_checkers = ['vimlint']
