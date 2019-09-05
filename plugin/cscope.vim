" vim: tabstop=2 shiftwidth=2 softtabstop=2 expandtab foldmethod=marker
"    Copyright: Copyright (C) 2012-2015 Brook Hong
"    License: The MIT License
"

if !exists('g:cscope_silent')
  let g:cscope_silent = 0
endif

if !exists('g:cscope_auto_update')
  let g:cscope_auto_update = 1
endif

if !exists('g:cscope_open_location')
  let g:cscope_open_location = 1
endif

if !exists('g:cscope_split_threshold')
  let g:cscope_split_threshold = 10000
endif

function! ToggleLocationList()
  let l:own = winnr()
  lw
  let l:cwn = winnr()
  if(l:cwn == l:own)
    if &buftype == 'quickfix'
      lclose
    elseif len(getloclist(winnr())) > 0
      lclose
    else
      echohl WarningMsg | echo "No location list." | echohl None
    endif
  endif
endfunction

if !exists('g:cscope_cmd')
  if executable('cscope')
    let g:cscope_cmd = 'cscope'
  else
    call cscope#echo('cscope: command not found')
    finish
  endif
endif

if !exists('g:cscope_interested_files')
  "TODO: change to default map, allow to redefine or extend
  let files = readfile(expand("<sfile>:p:h")."/interested.txt")
  let g:cscope_interested_files = join(map(files, 'v:val."$"'), '\|')
endif

let g:cscope_vim_dir = substitute($HOME,'\\','/','g')."/.cscope.vim"
let g:index_file = g:cscope_vim_dir.'/index'

function! CscopeFind(action, word)
  let dirtyDirs = []
  for d in keys(g:dbs)
    if g:dbs[d]['dirty'] == 1
      call add(dirtyDirs, d)
    endif
  endfor
  if len(dirtyDirs) > 0
    call cscope#UpdateDBs(dirtyDirs)
  endif
  let dbl = cscope#AutoloadDB(expand('%:p:h'), v:false)
  if dbl == 0
    try
      exe ':lcs f '.a:action.' '.a:word
      if g:cscope_open_location == 1
        lw
      endif
    catch
      echohl WarningMsg | echo 'Can not find '.a:word.' with querytype as '.a:action.'.' | echohl None
    endtry
  endif
endfunction

function! CscopeFindInteractive(pat)
    call inputsave()
    let qt = input("\nChoose a querytype for '".a:pat."'(:help cscope-find)\n  c: functions calling this function\n  d: functions called by this function\n  e: this egrep pattern\n  f: this file\n  g: this definition\n  i: files #including this file\n  s: this C symbol\n  t: this text string\n\n  or\n  <querytype><pattern> to query `pattern` instead of '".a:pat."' as `querytype`, Ex. `smain` to query a C symbol named 'main'.\n> ")
    call inputrestore()
    if len(qt) > 1
        call CscopeFind(qt[0], qt[1:])
    elseif len(qt) > 0
        call CscopeFind(qt, a:pat)
    endif
    call feedkeys("\<CR>")
endfunction

if exists('g:cscope_preload_path')
  call cscope#preloadDB()
endif

if g:cscope_auto_update == 1
  au BufWritePost * call cscope#OnChange()
endif

set cscopequickfix=s-,g-,d-,c-,t-,e-,f-,i-

function! CscopeUpdateDB()
  call cscope#UpdateDBs(keys(g:dbs))
endfunction

function! cscope#ListDirs(A,L,P)
  return keys(g:dbs)
endfunction

com! -nargs=? -complete=customlist,cscope#ListDirs CscopeClear call cscope#clearDBs("<args>")

com! -nargs=0 CscopeList call cscope#listDBs()

"TODO: if there's a git project use root
com! -nargs=0 CscopeCreateDB cscope#AutoloadDB(expand('%:p:h'), v:true)

call cscope#LoadIndex()
