" Use Node.js for JS interpreter - fix JSLint whine
let $JS_CMD='node'

" Turn off jslint errors by default
let g:JSLintHighlightErrorLine = 0

" Allow easy pretty print of json with ==
autocmd FileType json set equalprg=json_reformat
autocmd FileType javascript set equalprg=json_reformat
