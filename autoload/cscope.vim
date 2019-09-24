
function! cscope#echo(msg)
  if g:cscope_silent == 0
    echo a:msg
  endif
endfunction

function! cscope#LoadIndex()
  let g:dbs = {}
  if ! isdirectory(g:cscope_vim_dir)
    call mkdir(g:cscope_vim_dir)
  elseif filereadable(g:index_file)
    let idx = readfile(g:index_file)
    for i in idx
      let e = split(i, '|')
      if len(e) == 0
        call delete(g:index_file)
        call cscope#RmDBfiles()
      else
        let db_file = g:cscope_vim_dir.'/'.e[1].'.db'
        if filereadable(db_file)
          if isdirectory(e[0])
            let g:dbs[e[0]] = {}
            let g:dbs[e[0]]['id'] = e[1]
            let g:dbs[e[0]]['loadtimes'] = e[2]
            let g:dbs[e[0]]['dirty'] = (len(e) > 3) ? e[3] :0
          else
            call delete(db_file)
          endif
        endif
      endif
    endfor
  else
    call cscope#RmDBfiles()
  endif
endfunction

function! cscope#RmDBfiles()
  let odbs = split(globpath(g:cscope_vim_dir, "*"), "\n")
  for f in odbs
    call delete(f)
  endfor
endfunction

function! cscope#GetBestPath(dir)
  let f = substitute(a:dir,'\\','/','g')
  let bestDir = ""
  for d in keys(g:dbs)
    if stridx(f, d) == 0 && len(d) > len(bestDir)
      let bestDir = d
    endif
  endfor
  return bestDir
endfunction

function! cscope#ListFiles(dir)
  let d = []
  let f = []
  let cwd = a:dir
  let sl = &l:stl
  try
    while cwd != ''
      let a = split(globpath(cwd, "*"), "\n")
      for fn in a
        if getftype(fn) == 'dir'
          if !exists('g:cscope_ignored_dir') || fn !~? g:cscope_ignored_dir
            call add(d, fn)
          endif
        elseif getftype(fn) != 'file'
          continue
        elseif fn !~? g:cscope_interested_files
          continue
        else
          if stridx(fn, ' ') != -1
            let fn = '"'.fn.'"'
          endif
          call add(f, fn)
        endif
      endfor
      let cwd = len(d) ? remove(d, 0) : ''
      sleep 1m | let &l:stl = 'Found '.len(f).' files, finding in '.cwd | redrawstatus
    endwhile
  catch /^Vim:Interrupt$/
  catch
    echo "caught" v:exception
  endtry
  sleep 1m | let &l:stl = sl | redrawstatus
  return f
endfunction

function! cscope#FlushIndex()
  let lines = []
  for d in keys(g:dbs)
    call add(lines, d.'|'.g:dbs[d]['id'].'|'.g:dbs[d]['loadtimes'].'|'.g:dbs[d]['dirty'])
  endfor
  call writefile(lines, g:index_file)
  exec 'redraw!'
endfunction

function! cscope#CheckNewFile(dir, newfile)
  let id = g:dbs[a:dir]['id']
  let cscope_files = g:cscope_vim_dir."/".id.".files"
  let files = readfile(cscope_files)
  if len(files) > g:cscope_split_threshold
    let cscope_files = g:cscope_vim_dir."/".id."_inc.files"
    if filereadable(cscope_files)
      let files = readfile(cscope_files)
    else
      let files = []
    endif
  endif
  if count(files, a:newfile) == 0
    call add(files, a:newfile)
    call writefile(files, cscope_files)
  endif
endfunction

function! cscope#_CreateDB(dir, init)
  let id = g:dbs[a:dir]['id']
  let cscope_files = g:cscope_vim_dir."/".id."_inc.files"
  let cscope_db = g:cscope_vim_dir.'/'.id.'_inc.db'
  if ! filereadable(cscope_files) || a:init
    let cscope_files = g:cscope_vim_dir."/".id.".files"
    let cscope_db = g:cscope_vim_dir.'/'.id.'.db'
    if ! filereadable(cscope_files)
      let files = cscope#ListFiles(a:dir)
      call writefile(files, cscope_files)
    endif
  endif
  exec 'cs kill '.cscope_db
  redir @x
  exec 'silent !'.g:cscope_cmd.' -b -i '.cscope_files.' -f'.cscope_db
  redi END
  if @x =~ "\nCommand terminated\n"
    echohl WarningMsg | echo "Failed to create cscope database for ".a:dir.", please check if " | echohl None
  else
    let g:dbs[a:dir]['dirty'] = 0
    exec 'cs add '.cscope_db
  endif
endfunction

function! cscope#CheckAbsolutePath(dir, defaultPath)
  let d = a:dir
  while 1
    if !isdirectory(d)
      echohl WarningMsg
        echo "Please input a valid path."
      echohl None
      call inputsave()
      let d = input("", a:defaultPath, 'dir')
      call inputrestore()
    elseif (len(d) < 2 || (d[0] != '/' && d[1] != ':'))
      echohl WarningMsg
        echo "Please input an absolute path."
      echohl None
      call inputsave()
      let d = input("", a:defaultPath, 'dir')
      call inputrestore()
    else
      break
    endif
  endwhile
  let d = substitute(d,'\\','/','g')
  let d = substitute(d,'/\+$','','')
  return d
endfunction

function! cscope#InitDB(dir)
  let id = localtime()
  let g:dbs[a:dir] = {}
  let g:dbs[a:dir]['id'] = id
  let g:dbs[a:dir]['loadtimes'] = 0
  let g:dbs[a:dir]['dirty'] = 0
  call cscope#_CreateDB(a:dir, 1)
  call cscope#FlushIndex()
endfunction

function! cscope#LoadDB(dir)
  cs kill -1
  exe 'cs add '.g:cscope_vim_dir.'/'.g:dbs[a:dir]['id'].'.db'
  if filereadable(g:cscope_vim_dir.'/'.g:dbs[a:dir]['id'].'_inc.db')
    exe 'cs add '.g:cscope_vim_dir.'/'.g:dbs[a:dir]['id'].'_inc.db'
  endif
  let g:dbs[a:dir]['loadtimes'] = g:dbs[a:dir]['loadtimes']+1
  call cscope#FlushIndex()
endfunction

" 0 -- loaded
" 1 -- cancelled
function! cscope#AutoloadDB(dir, auto)
  let ret = 0
  let m_dir = cscope#GetBestPath(a:dir)
  if m_dir == ""
    if ! a:auto
      echohl WarningMsg 
        echo
        echo "Can not find proper cscope db, please input a path to generate cscope db for."
      echohl None
      call inputsave()
      let m_dir = input("", a:dir, 'dir')
      call inputrestore()
    else
      let m_dir = a:dir
    endif
    if m_dir != ''
      let m_dir = cscope#CheckAbsolutePath(m_dir, a:dir)
      call cscope#InitDB(m_dir)
      call cscope#LoadDB(m_dir)
    else
      let ret = 1
    endif
  else
    let id = g:dbs[m_dir]['id']
    if cscope_connection(2, g:cscope_vim_dir.'/'.id.'.db') == 0
      call cscope#LoadDB(m_dir)
    endif
  endif
  return ret
endfunction

function! cscope#UpdateDBs(dirs)
  for d in a:dirs
    call cscope#_CreateDB(d, 0)
  endfor
  call cscope#FlushIndex()
endfunction

function! cscope#clearDBs(dir)
  cs kill -1
  if a:dir == ""
    let g:dbs = {}
    call cscope#RmDBfiles()
  else
    let id = g:dbs[a:dir]['id']
    call delete(g:cscope_vim_dir."/".id.".files")
    call delete(g:cscope_vim_dir.'/'.id.'.db')
    call delete(g:cscope_vim_dir."/".id."_inc.files")
    call delete(g:cscope_vim_dir.'/'.id.'_inc.db')
    unlet g:dbs[a:dir]
  endif
  call cscope#FlushIndex()
endfunction

function! cscope#listDBs()
  let dirs = keys(g:dbs)
  if len(dirs) == 0
    echo "You have no cscope dbs now."
  else
    let s = [' ID                   LOADTIMES    PATH']
    for d in dirs
      let id = g:dbs[d]['id']
      if cscope_connection(2, g:cscope_vim_dir.'/'.id.'.db') == 1
        let l = printf("*%d  %10d            %s", id, g:dbs[d]['loadtimes'], d)
      else
        let l = printf(" %d  %10d            %s", id, g:dbs[d]['loadtimes'], d)
      endif
      call add(s, l)
    endfor
    echo join(s, "\n")
  endif
endfunction

function! cscope#preloadDB()
  let dirs = split(g:cscope_preload_path, ';')
  for m_dir in dirs
    let m_dir = cscope#CheckAbsolutePath(m_dir, m_dir)
    if ! has_key(g:dbs, m_dir)
      call cscope#InitDB(m_dir)
    endif
    call cscope#LoadDB(m_dir)
  endfor
endfunction

function! cscope#OnChange()
  if expand('%:t') =~? g:cscope_interested_files
    let m_dir = cscope#GetBestPath(expand('%:p:h'))
    if m_dir != ""
      let g:dbs[m_dir]['dirty'] = 1
      call cscope#FlushIndex()
      call cscope#CheckNewFile(m_dir, expand('%:p'))
      redraw
      call cscope#echo('Your cscope db will be updated automatically, you can turn off this message by setting g:cscope_silent 1.')
    endif
  endif
endfunction

