" File:        chapa.vim
" Description: Go to or visually select the next/previous class, method or
"              function in Python.
" Maintainer:  Alfredo Deza <alfredodeza AT gmail.com>
" License:     MIT
" Notes:       A lot of the code within was adapted/copied from python.vim 
"              and python_fn.vim authored by Jon Franklin and Mikael Berthe
"
"============================================================================

if exists("g:loaded_chapa") || &cp 
  finish
endif

"{{{ Default Mappings 
if (exists('g:chapa_default_mappings'))
    " Function Movement
    nmap fnf <Plug>ChapaNextFunction
    nmap fif <Plug>ChapaInFunction
    nmap fpf <Plug>ChapaPreviousFunction

    " Class Movement
    nmap fnc <Plug>ChapaNextClass
    nmap fic <Plug>ChapaInClass
    nmap fpc <Plug>ChapaPreviousClass

    " Method Movement
    nmap fnm <Plug>ChapaNextMethod
    nmap fim <Plug>ChapaInMethod
    nmap fpm <Plug>ChapaPreviousMethod

    " Class Visual Select 
    nmap vnc <Plug>ChapaVisualNextClass
    nmap vic <Plug>ChapaVisualThisClass 
    nmap vpc <Plug>ChapaVisualPreviousClass

    " Method Visual Select
    nmap vnm <Plug>ChapaVisualNextMethod
    nmap vim <Plug>ChapaVisualThisMethod
    nmap vpm <Plug>ChapaVisualPreviousMethod

    " Function Visual Select
    nmap vnf <Plug>ChapaVisualNextFunction
    nmap vif <Plug>ChapaVisualThisFunction
    nmap vpf <Plug>ChapaVisualPreviousFunction

    " Comment Class
    nmap cic <Plug>ChapaCommentThisClass
    nmap cnc <Plug>ChapaCommentNextClass
    nmap cpc <Plug>ChapaCommentPreviousClass

    " Comment Method 
    nmap cim <Plug>ChapaCommentThisMethod 
    nmap cnm <Plug>ChapaCommentNextMethod 
    nmap cpm <Plug>ChapaCommentPreviousMethod 

    " Comment Function 
    nmap cif <Plug>ChapaCommentThisFunction
    nmap cnf <Plug>ChapaCommentNextFunction
    nmap cpf <Plug>ChapaCommentPreviousFunction

    " Repeat Mappings
    nmap <C-h> <Plug>ChapaOppositeRepeat
    nmap <C-l> <Plug>ChapaRepeat

    " Folding Method
    nmap zim <Plug>ChapaFoldThisMethod
    nmap znm <Plug>ChapaFoldNextMethod
    nmap zpm <Plug>ChapaPreviousMethod

    " Folding Class
    nmap zic <Plug>ChapaFoldThisClass
    nmap znc <Plug>ChapaFoldNextClass
    nmap zpc <Plug>ChapaFoldPreviousClass

    " Folding Function
    nmap zif <Plug>ChapaFoldThisFunction
    nmap znf <Plug>ChapaFoldNextFunction
    nmap zpf <Plug>ChapaFoldPreviousFunction
endif

"{{{ Helpers

" In certain situations, it allows you to echo something without 
" having to hit Return again to do exec the command.
" It looks if the global message variable is set or set to 0 or set to 1
function! s:Echo(msg)
  if (! exists('g:chapa_messages') || exists('g:chapa_messages') && g:chapa_messages)
    let x=&ruler | let y=&showcmd
    set noruler noshowcmd
    redraw
    echo a:msg
    let &ruler=x | let &showcmd=y
  endif
endfun


" Set the fold title right if we have a decorator
set foldtext=ChapaFoldText()
set foldmethod=manual
function! ChapaFoldText()
    let line = getline(v:foldstart)
    if (line =~ '\v^\s*\@')
        let decorator_line = v:foldstart + 1
        while (getline(decorator_line) =~ '\v^\s*\@')
            let decorator_line = decorator_line + 1
        endwhile
        let title = getline(decorator_line)
    else
        let title = line
    endif
    let fold_title = substitute(title,"^\\s\\+\\|\\s\\+$","","g") 
    return v:folddashes . fold_title
endfunction


" Wouldn't it be nice if you could just repeat the effing Movements
" instead of typing mnemonics to keep going forward or backwards?
" Exactly.
function! s:Repeat()
    if (exists('g:chapa_last_action'))
        let cmd = "call " . g:chapa_last_action 
        exe cmd
    else 
        echo "No command to repeat"
    endif 
endfunction

function! s:BackwardRepeat()
    let act_map = {'s:NextClass(0)' : 's:PreviousClass(0)',
                \'s:PreviousClass(0)' : 's:NextClass(0)',
                \'s:NextMethod(0)' : 's:PreviousMethod(0)',
                \'s:PreviousMethod(0)' : 's:NextMethod(0)',
                \'s:NextFunction(0)' : 's:PreviousFunction(0)',
                \'s:PreviousFunction(0)' : 's:NextFunction(0)'}
    if (exists('g:chapa_last_action'))
        let fwd = g:chapa_last_action 
        let cmd = "call " . act_map[fwd]
        exe cmd
    else 
        echo "No opposite command to repeat"
    endif
endfunction
"}}}

"{{{ Main Functions 
" Range for commenting 
function! s:PythonCommentObject(obj, direction, count)
    let orig_line = line('.')
    let orig_col = col('.')

    " Go to the object declaration
    normal $
    let go_to_obj = s:FindPythonObject(a:obj, a:direction, a:count)
        
    if (! go_to_obj)
        exec orig_line
        exe "normal " orig_col . "|"
        return
    endif

    " Sometimes, when we get a decorator we are not in the line we want 
    let has_decorator = s:HasPythonDecorator(line('.'))

    if has_decorator 
        let beg = has_decorator 
    else 
        let beg = line('.')
    endif

    let until = s:NextIndent(1)

    " go to the line we need
    exec beg

    let line_moves = until - beg

    " check if we have comments or not 
    let has_comments = s:HasComments(beg, until)
    if (has_comments == 1)
        let regex = " s/^#//"
        let until = s:LastComment(beg)
    else
        let regex = " s/^/#/"
    endif
        
    if line_moves > 0
        execute beg . "," . until . regex
    else
        execute "%" . regex
    endif
    let @/ = ""

    return 1
endfunction

" Find if a Range has comments or not 
function! s:HasComments(from, until)
    let regex =  's/^#//gn'
    try 
        silent exe a:from . "," . a:until . regex
        return 1
    catch /^Vim\%((\a\+)\)\=:E/
        return 0
    endtry
endfunction

" Find the last commented line 
function! s:LastComment(from_line)
    let line = a:from_line
    exe line
    return s:NextUncommentedLine(1)
endfunction

" Select an object ("class"/"function")
function! s:PythonSelectObject(obj, direction, count)
    let orig_line = line('.')
    let orig_col = col('.')

    " Go to the object declaration
    normal $
    let go_to_obj = s:FindPythonObject(a:obj, a:direction, a:count)
        
    if (! go_to_obj)
        exec orig_line
        exe "normal " orig_col . "|"
        return
    endif

    " Sometimes, when we get a decorator we are not in the line we want 
    let has_decorator = s:HasPythonDecorator(line('.'))

    if has_decorator 
        let beg = has_decorator 
    else 
        let beg = line('.')
    endif

    let until = s:NextIndent(1)

    " go to the line we need
    exec beg
    let line_moves = until - beg

    if line_moves > 0
        execute "normal V" . line_moves . "j"
    else
        execute "normal VG" 
    endif
endfunction


function! s:NextUncommentedLine(fwd)
    let line = line('.')
    let column = col('.')
    let lastline = line('$')
    let indent = indent(line)
    let stepvalue = a:fwd ? 1 : -1

    let found = 0
    while ((line > 0) && (line <= lastline) && (found == 0)) 
        if (getline(line) =~ '^#')
            let line = line + 1
            if (line == lastline)
                return lastline
            endif

        elseif (getline(line) !~ '^#')
            let found = 1
            return line - 1
        endif
    endwhile
endfunction


function! s:NextIndent(fwd)
    let line = line('.')
    let column = col('.')
    let lastline = line('$')
    let indent = indent(line)
    let stepvalue = a:fwd ? 1 : -1

    if (getline(line) =~ '^#')
        let until = s:NextUncommentedLine(1)
        return until
    endif
    " We look for the last non whitespace 
    " line (e.g. another function at same indent level
    " and then go back until we find an indent that 
    " matches what we are looking for that is NOT whitespace
    let found = 0
    while ((line > 0) && (line <= lastline) && (found == 0))
        let line = line + 1

        if ((indent(line) <= indent) && (getline(line) !~ '^\s*$'))
            let go_back = line -1 
            while (getline(go_back) =~ '^\s*$')
                let go_back = go_back-1 
                if (getline(go_back) !~ '^\s*$')
                    break 
                    let found = 1
                endif
            endwhile
            return go_back 

        " what if we reach end of file and no dice? 
        elseif (line == lastline)
            while (getline(line) =~ '^\s*$')
                let line = line-1 
                if (getline(line) !~ '^\s*$')
                    break 
                endif
            endwhile
            return line
        endif
    endwhile
endfunction
 

" Go to previous (-1) or next (1) class/function definition
" return a line number that matches either a class or a function
" to call this manually:
" Backwards:
"     :call FindPythonObject("class", -1)
" Forwards:
"     :call FindPythonObject("class")
" Functions Backwards:
"     :call FindPythonObject("function", -1)
" Functions Forwards:
"     :call FindPythonObject("function")
function! s:FindPythonObject(obj, direction, count)
    let orig_line = line('.')
    let orig_col = col('.')
    if (a:obj == "class")
        let objregexp  = '\v^\s*(.*class)\s+(\w+)\s*\(\s*'
    elseif (a:obj == "method")
        let objregexp = '\v^\s*(.*def)\s+(\w+)\s*\(\s*(self[^)]*)'
    else
        let objregexp = '\v^\s*(.*def)\s+(\w+)\s*\(\s*(.*self)@!'
    endif
    let flag = "W"
    if (a:direction == -1)
        let flag = flag."b"
    endif
    let _count = a:count
    let matched_search = 0
    if (_count == 0)
        let result = search(objregexp, flag)
        if result 
            let matched_search = result 
        endif
    else    
        while _count > 0
            let result = search(objregexp, flag)
            if result 
                let matched_search = result 
            endif
            let _count = _count - 1
        endwhile
    endif
    if (matched_search != 0)
        return matched_search
    endif
endfunction


function! s:HasPythonDecorator(line)
    " Get to the previous line where the decorator lives
    let line = a:line -1 
    while (getline(line) =~ '\v^(.*\@[a-zA-Z])')
        let line = line - 1
    endwhile

    " This is tricky but goes back and forth to 
    " correctly match the decorator without the 
    " possibility of selecting a blank line
    if (getline(line) =~ '\v^(.*\@[a-zA-Z])')
        return line
    elseif (getline(line+1) =~ '\v^(.*\@[a-zA-Z])')
        return line + 1
    endif
endfunction

function! s:IsInside(object)
    let beg = line('.')
    let column = col('.')
    " Verifies you are actually inside 
    " of the object you are referring to 
    exe beg 
    let class = s:PreviousObjectLine("class")
    exe beg 
    let method = s:PreviousObjectLine("method")
    exe beg 
    let function = s:PreviousObjectLine("function")
    exe beg 
    exe "normal " column . "|"

    if (a:object == "function")
        if (function == -1)
            return -1
        elseif ((class < function) && (method < function))
            return 1
        else 
            return 0 
        endif 
    elseif (a:object == "class")
        if (class == -1)
            return -1
        elseif ((function < class) && (method < class))
            return 1
        else 
            return 0 
        endif 
    elseif (a:object == "method")
        if (method == -1)
            return -1
        elseif ((function < method) && (class < method))
            return 1
        else 
            return 0
        endif 
    endif 
endfunction 

function! s:PreviousObjectLine(obj)
    let beg = line('.')
    if (a:obj == "class")
        let objregexp  = '\v^\s*(.*class)\s+(\w+)\s*\(\s*'
    elseif (a:obj == "method")
        let objregexp = '\v^\s*(.*def)\s+(\w+)\s*\(\s*(self[^)]*)'
    else
        let objregexp = '\v^\s*(.*def)\s+(\w+)\s*\(\s*(.*self)@!'
    endif

    let flag = 'Wb' 

    " are we on THE actual beginning of the object? 
    if (getline('.') =~ objregexp)
        return -1
    else
        let result = search(objregexp, flag)
        if (line('.') == beg)
            return 0
        endif
        if result
            return line('.')
        else 
            return 0
        endif
    endif

endfunction
"}}}

"{{{ Proxy Functions 
"
" Commenting Selections
"
" Comment Class Selections:
"
function! s:CommentPreviousClass()
    let inside = s:IsInside("class")
    let times = v:count1+inside
    if (! s:PythonCommentObject("class", -1, times))
        call s:Echo("Could not match previous class for commenting")
    endif 
endfunction

function! s:CommentNextClass()
    if (! s:PythonCommentObject("class", 1, v:count1))
        call s:Echo("Could not match next class for commenting")
    endif 
endfunction

function! s:CommentThisClass()
    if (! s:PythonCommentObject("class", -1, 1))
        call s:Echo("Could not match inside of class for commenting")
    endif 
endfunction

"
" Comment Method Selections:
"
function! s:CommentPreviousMethod()
    let inside = s:IsInside("method")
    let times = v:count1+inside
    if (! s:PythonCommentObject("method", -1, times))
        call s:Echo("Could not match previous method for commenting")
    endif 
endfunction

function! s:CommentNextMethod()
    if (! s:PythonCommentObject("method", 1, v:count1))
        call s:Echo("Could not match next method for commenting")
    endif 
endfunction

function! s:CommentThisMethod()
    if (! s:PythonCommentObject("method", -1, 1))
        call s:Echo("Could not match inside of method for commenting")
    endif 
endfunction

"
" Comment Function Selections:
"
function! s:CommentPreviousFunction()
    let inside = s:IsInside("function")
    let times = v:count1+inside
    if (! s:PythonCommentObject("function", -1, times))
        call s:Echo("Could not match previous function for commenting")
    endif 
endfunction

function! s:CommentNextFunction()
    if (! s:PythonCommentObject("function", 1, v:count1))
        call s:Echo("Could not match next function for commenting")
    endif 
endfunction

function! s:CommentThisFunction()
    if (! s:PythonCommentObject("function", -1, 1))
        call s:Echo("Could not match inside of function for commenting")
    endif 
endfunction

"
" Visual Selections:
"
" Visual Class Selections:
function! s:VisualNextClass()
    if (! s:PythonSelectObject("class", 1, v:count1))
        call s:Echo("Could not match next class for visual selection")
    endif
endfunction

function! s:VisualPreviousClass()
    let inside = s:IsInside("class")
    let times = v:count1+inside
    if (! s:PythonSelectObject("class", -1, times))
        call s:Echo("Could not match previous class for visual selection")
    endif 
endfunction

function! s:VisualThisClass()
    if (! s:PythonSelectObject("class", -1, 1))
        call s:Echo("Could not match inside of class for visual selection")
    endif 
endfunction


" Visual Function Selections:
function! s:VisualNextFunction()
    if (! s:PythonSelectObject("function", 1, v:count1))
        call s:Echo("Could not match next function for visual selection")
    endif
endfunction

function! s:VisualPreviousFunction()
    let inside = s:IsInside("function")
    let times = v:count1+inside
    if (! s:PythonSelectObject("function", -1, times))
        call s:Echo("Could not match previous function for visual selection")
    endif 
endfunction

function! s:VisualThisFunction()
    if (! s:PythonSelectObject("function", -1, 1))
        call s:Echo("Could not match inside of function for visual selection")
    endif 
endfunction

" Visual Method Selections:
function! s:VisualNextMethod()
    if (! s:PythonSelectObject("method", 1, v:count1))
        call s:Echo("Could not match next method for visual selection")
    endif
endfunction

function! s:VisualPreviousMethod()
    let inside = s:IsInside("method")
    let times = v:count1+inside
    if (! s:PythonSelectObject("method", -1, times))
        call s:Echo("Could not match previous method for visual selection")
    endif 
endfunction

function! s:VisualThisMethod()
    if (! s:PythonSelectObject("method", -1, 1))
        call s:Echo("Could not match inside of method for visual selection")
    endif 
endfunction

" 
" Movements:
" 
" Class:
function! s:PreviousClass(record)
    if (a:record == 1)
        let g:chapa_last_action = "s:PreviousClass(0)"
    endif
    let inside = s:IsInside("class")
    let times = v:count1+inside
    if (! s:FindPythonObject("class", -1, times))
        call s:Echo("Could not match previous class")
    endif 
endfunction 

function! s:InClass()
    if (! s:FindPythonObject("class", -1, 1))
        call s:Echo("Could not match insode of class")
    endif 
endfunction 

function! s:NextClass(record)
    if (a:record == 1)
        let g:chapa_last_action = "s:NextClass(0)"
    endif
    if (! s:FindPythonObject("class", 1, v:count1))
        call s:Echo("Could not match next class")
    endif 
endfunction 

" Method:
function! s:PreviousMethod(record)
    if (a:record == 1)
        let g:chapa_last_action = "s:PreviousMethod(0)"
    endif
    let inside = s:IsInside("method")
    let times = v:count1+inside
    if (! s:FindPythonObject("method", -1, times))
        call s:Echo("Could not match previous method")
    endif 
endfunction 

function! s:InMethod()
    if (! s:FindPythonObject("method", -1, 1))
        call s:Echo("Could not match inside of method")
    endif 
endfunction 

function! s:NextMethod(record)
    if (a:record == 1)
        let g:chapa_last_action = "s:NextMethod(0)"
    endif
    if (! s:FindPythonObject("method", 1, v:count1))
        call s:Echo("Could not match next method")
    endif 
endfunction 

" Function:
function! s:PreviousFunction(record)
    if (a:record == 1)
        let g:chapa_last_action = "s:PreviousFunction(0)"
    endif
    let inside = s:IsInside("function")
    let times = v:count1+inside
    if (! s:FindPythonObject("function", -1, times))
        call s:Echo("Could not match previous function")
    endif 
endfunction

function! s:InFunction()
    if (! s:FindPythonObject("function", -1, 1))
        call s:Echo("Could not match inside of function")
    endif 
endfunction

function! s:NextFunction(record)
    if (a:record == 1)
        let g:chapa_last_action = "s:NextFunction(0)"
    endif
    if (! s:FindPythonObject("function", 1, v:count1))
        call s:Echo("Could not match next function")
    endif 
endfunction

"
" Folding:
" 

" Method:
function! s:FoldThisMethod()
    call s:PythonSelectObject("method", -1, 1)
    exe "normal zf"
endfunction

function! s:FoldPreviousMethod()
    let inside = s:IsInside("method")
    let times = v:count1+inside
    if (! s:FindPythonObject("method", -1, times))
        call s:Echo("Could not match previous method for folding")
    endif 
    exe "normal zf"
endfunction

function! s:FoldNextMethod()
    if (! s:PythonSelectObject("method", 1, v:count1))
        call s:Echo("Could not match next method for folding")
    endif 
    exe "normal zf"
endfunction


" Class:
function! s:FoldThisClass()
    call s:PythonSelectObject("class", -1, 1)
    exe "normal zf"
endfunction

function! s:FoldPreviousClass()
    let inside = s:IsInside("class")
    let times = v:count1+inside
    if (! s:FindPythonObject("class", -1, times))
        call s:Echo("Could not match previous class for folding")
    endif 
    exe "normal zf"
endfunction

function! s:FoldNextClass()
    if (! s:PythonSelectObject("class", 1, v:count1))
        call s:Echo("Could not match next class for folding")
    endif 
    exe "normal zf"
endfunction


" Function:
function! s:FoldThisFunction()
    if (! s:PythonSelectObject("function", -1, 1))
        call s:Echo("Could not match inside of function for folding")
    endif 
    exe "normal zf"
endfunction

function! s:FoldPreviousFunction()
    let inside = s:IsInside("function")
    let times = v:count1+inside
    if (! s:FindPythonObject("function", -1, times))
        call s:Echo("Could not match previous function for folding")
    endif 
    exe "normal zf"
endfunction

function! s:FoldNextFunction()
    if (! s:PythonSelectObject("function", 1, v:count1))
        call s:Echo("Could not match next function for folding")
    endif 
    exe "normal zf"
endfunction
"}}}

"{{{ Misc 
" Comment Class: 
nnoremap <silent> <Plug>ChapaCommentPreviousClass   :<C-U>call <SID>CommentPreviousClass() <CR>
nnoremap <silent> <Plug>ChapaCommentNextClass       :<C-U>call <SID>CommentNextClass()     <CR>
nnoremap <silent> <Plug>ChapaCommentThisClass       :<C-U>call <SID>CommentThisClass()     <CR>

" Comment Method: 
nnoremap <silent> <Plug>ChapaCommentPreviousMethod   :<C-U>call <SID>CommentPreviousMethod()<CR>
nnoremap <silent> <Plug>ChapaCommentNextMethod       :<C-U>call <SID>CommentNextMethod()    <CR>
nnoremap <silent> <Plug>ChapaCommentThisMethod       :<C-U>call <SID>CommentThisMethod()    <CR>

" Comment Function: 
nnoremap <silent> <Plug>ChapaCommentPreviousFunction   :<C-U>call <SID>CommentPreviousFunction()  <CR>
nnoremap <silent> <Plug>ChapaCommentNextFunction       :<C-U>call <SID>CommentNextFunction()      <CR>
nnoremap <silent> <Plug>ChapaCommentThisFunction       :<C-U>call <SID>CommentThisFunction()      <CR>

" Visual Select Class:
nnoremap <silent> <Plug>ChapaVisualNextClass        :<C-U>call <SID>VisualNextClass()       <CR>
nnoremap <silent> <Plug>ChapaVisualPreviousClass    :<C-U>call <SID>VisualPreviousClass()   <CR>
nnoremap <silent> <Plug>ChapaVisualThisClass        :<C-U>call <SID>VisualThisClass()       <CR>

" Visual Select Method:
nnoremap <silent> <Plug>ChapaVisualNextMethod       :<C-U>call <SID>VisualNextMethod()      <CR>
nnoremap <silent> <Plug>ChapaVisualPreviousMethod   :<C-U>call <SID>VisualPreviousMethod()  <CR>
nnoremap <silent> <PLug>ChapaVisualThisMethod       :<C-U>call <SID>VisualThisMethod()      <CR>

" Visual Select Function:
nnoremap <silent> <Plug>ChapaVisualNextFunction     :<C-U>call <SID>VisualNextFunction()    <CR>
nnoremap <silent> <Plug>ChapaVisualPreviousFunction :<C-U>call <SID>VisualPreviousFunction()<CR>
nnoremap <silent> <Plug>ChapaVisualThisFunction     :<C-U>call <SID>VisualThisFunction()    <CR>

" Class Movement:
nnoremap <silent> <Plug>ChapaPreviousClass          :<C-U>call <SID>PreviousClass(1)        <CR>
nnoremap <silent> <Plug>ChapaInClass                :<C-U>call <SID>InClass()               <CR>
nnoremap <silent> <Plug>ChapaNextClass              :<C-U>call <SID>NextClass(1)            <CR>

" Method Movement:
nnoremap <silent> <Plug>ChapaPreviousMethod         :<C-U>call <SID>PreviousMethod(1)       <CR>
nnoremap <silent> <Plug>ChapaInMethod               :<C-U>call <SID>InMethod()              <CR>
nnoremap <silent> <Plug>ChapaNextMethod             :<C-U>call <SID>NextMethod(1)           <CR>

" Function Movement:
nnoremap <silent> <Plug>ChapaPreviousFunction       :<C-U>call <SID>PreviousFunction(1)     <CR>
nnoremap <silent> <Plug>ChapaInFunction             :<C-U>call <SID>InFunction()            <CR>
nnoremap <silent> <Plug>ChapaNextFunction           :<C-U>call <SID>NextFunction(1)         <CR>

" Repeating Movements:
nnoremap <silent> <Plug>ChapaOppositeRepeat         :<C-U>call <SID>BackwardRepeat()        <CR>
nnoremap <silent> <Plug>ChapaRepeat                 :<C-U>call <SID>Repeat()                <CR>

" Folding Method:
nnoremap <silent> <Plug>ChapaFoldThisMethod         :<C-U>call <SID>FoldThisMethod()        <CR>
nnoremap <silent> <Plug>ChapaFoldNextMethod         :<C-U>call <SID>FoldNextMethod()        <CR>
nnoremap <silent> <Plug>ChapaFoldPreviousMethod     :<C-U>call <SID>FoldPreviousMethod()    <CR>

" Folding Class:
nnoremap <silent> <Plug>ChapaFoldThisClass          :<C-U>call <SID>FoldThisClass()         <CR>
nnoremap <silent> <Plug>ChapaFoldNextClass          :<C-U>call <SID>FoldNextClass()         <CR>
nnoremap <silent> <Plug>ChapaFoldPreviousClass      :<C-U>call <SID>FoldPreviousClass()     <CR>

" Fold Function:
nnoremap <silent> <Plug>ChapaFoldThisFunction       :<C-U>call <SID>FoldThisFunction()      <CR>
nnoremap <silent> <Plug>ChapaFoldNextFunction       :<C-U>call <SID>FoldNextFunction()      <CR>
nnoremap <silent> <Plug>ChapaFoldPreviousFunction   :<C-U>call <SID>FoldPreviousFunction()  <CR>

"}}}
