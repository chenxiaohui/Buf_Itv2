"Author:	zzsu (vimtexhappy@gmail.com)
"			Buffer list in statusline
"			2011-02-14 07:07:48 v4.0
"Modified:	BitRobt(sdqxcxh@gmail.com)
"			fix some bugs under windows		
"			fix some conflicts with NerdTree and Taglist plugin
"License:	Copyright (c) 2001-2009, zzsu
"			GNU General Public License version 2 for more details.

if exists('loaded_buf_it') || &cp
    finish
endif

let g:showInStatusbar = 1
if(g:iswindows==1 && has("gui_running"))
	autocmd BufRead * call CloseDefaultBuf()
endif
autocmd VimEnter,BufNew,BufEnter,BufWritePost,VimResized * call UpdateStatus()
autocmd InsertLeave * call BufEcho()

nmap  <s-h>      :call BufPrevPart()<cr>
nmap  <s-l>      :call BufNextPart()<cr>
noremap  <leader>be  :call BufEcho()<cr>
noremap  <leader>bo :call BufOnly()<cr>

let g:bufBStr = ""
let g:bufNStr= ""
let g:bufAStr= ""
let g:statusbarKeepWidth = 20

hi NowBuf term=bold ctermfg=Cyan guifg=green guibg=blue gui=bold

if exists("g:showInStatusbar")
    if !exists("g:statusbarUsrDef") || g:statusbarUsrDef == 0
		set statusline=%m\{%{&ff}:%{&fenc}:%Y}\ %{g:bufBStr}%#NowBuf#%{g:bufNStr}%#StatusLine#%{g:bufAStr}%<%=%c:%l/%L%<
    endif
endif
"buf index now
let g:bufNowIdx = 0
"buf part now (for multi line)
let s:bufNowPartIdx = 0

"buf names
let s:bufs = {}
"buf indexes
let s:bufnrs = {}

"buf Part(for multi line)
let s:bufPartStrList = []

function! CloseDefaultBuf()
    "if there is a default buf just close it
	if buflisted(1) && empty(bufname(1))
		exec 'bd1'
	endif
	call UpdateStatus()
endfun

"unmap the keys
function! BufUnMap()
    for i in keys(s:bufs)
		"less than 10 files
        if i < 10
            exec "silent! unmap <M-".i.">"
        else
            exec "silent! unmap <M-".i/10."><M-".i%10.">"
        endif
    endfor
endfun
"map keys
function! BufMap()
    for i in keys(s:bufs)
        if i < 10
            exec "silent! noremap <M-".i."> :call BufChange(".i.")<CR>"
        else
            exec "silent! noremap <M-".i/10."><M-".i%10."> :call BufChange(".i.")<CR>"
        endif
    endfor
endfunction

"close other bufs
function! BufOnly()
    let i = 1
	"bufnr('$')will return the last buf,
	"buflisted(i) judges if the ist buf exists,
	"buwinnr return the window contains the buf,
	"winnr return the default window
    while(i <= bufnr('$'))
		"the ist buffer exists and can be modified
        if buflisted(i) && getbufvar(i, "&modifiable")
                    \   && (bufwinnr(i) != winnr())
            exec 'bw'.i
        endif
        let i = i + 1
    endwhile
    call UpdateStatus()
endfun

"close the buf
function! BufClose(force)
	if(!a:force && &modified)
		echohl WarningMsg | echo "Buffer Modified!" | echohl None
		return
	endif
	let cmd=a:force?'bd!':'bd'
	let qcmd=a:force?'q!':'q'
	call UpdateStatus()
	"deal conflicts with NerdTree
	if exists("t:NERDTreeBufName") && bufname("%")==t:NERDTreeBufName
		return
	endif
	"it's not the window which is being edited
	if index(values(s:bufnrs),winbufnr(0))==-1
		exec cmd
	"the window is being edited and multi buffer openen.
	elseif len(s:bufnrs)>1
		"nerdtree opened, switch to the next buffer and close the buffer
		"before.It's just a bug.
		if exists("t:NERDTreeBufName")
			let ibufNow=bufnr("%")
			call BufNextPart() 
			exec cmd.ibufNow
		else 
			exec cmd
		endif
	"only one buf.close it for three times.One is for the current buf, another
	"for nerdtree, the last for taglist.
	else 
		exec qcmd 
		exec qcmd 
		exec qcmd 
	endif   
	call UpdateStatus()
endfun

"switch to some buf
function! BufChange(idx)
    exec 'b! '.s:bufnrs[a:idx]
	let g:bufNowIdx=a:idx
endfunction

"split window to show some buffer
function! BufSplit(idx)
    exec 'sb! '.s:bufnrs[a:idx]
endfunction

"switch to the next buf
function! BufNextPart()
	call UpdateStatus()
	if index(values(s:bufnrs),winbufnr(0))==-1
		return
	endif
	let g:bufNowIdx += 1
	if g:bufNowIdx >len(s:bufnrs)
		let g:bufNowIdx = 1
	endif
	call BufChange(g:bufNowIdx)
	call UpdateBufPartStr()
endfunction

"switch to the pre buf
function! BufPrevPart()
	call UpdateStatus()
	if index(values(s:bufnrs),winbufnr(0))==-1
		return
	endif
    let g:bufNowIdx -= 1
    if g:bufNowIdx < 1
        let g:bufNowIdx = len(s:bufnrs)
    endif
	call BufChange(g:bufNowIdx)
    call UpdateBufPartStr()
endfunction

function! UpdateBufPartStr()
    let [g:bufBStr, g:bufNStr, g:bufAStr] = s:bufPartStrList[s:bufNowPartIdx]
	"one screen is not enough add '<<'
    if s:bufNowPartIdx > 0
        let g:bufBStr = '<<'.g:bufBStr
    endif
	"one screen is not enough add '>>'
    if s:bufNowPartIdx < len(s:bufPartStrList)-1
        let g:bufAStr = g:bufAStr.'>>'
    endif
endfunction

function! UpdateStatus()
	"unmap all keys
    call BufUnMap()
    let s:bufs = {}
    let s:bufNowPartIdx = 0
    let s:bufnrs = {}
    let s:bufPartStrList = []
    let idx = 1
    let i = 1
	
    while(i <= bufnr('$'))
		"exists and modifiable
        if buflisted(i) && getbufvar(i, "&modifiable")
            "bufName: like 1-buf_it.vim+
			let bufName  =  idx."-"
            let bufName .= fnamemodify(bufname(i), ":t")
            let bufName .= getbufvar(i, "&modified")? "+":''
            let bufName .= " "
            let s:bufs[idx] = bufName
            let s:bufnrs[idx] = i
            let idx += 1
        endif
        let i += 1
    endwhile
    if empty(s:bufs)
        return
    endif
	
	"the max width
    let widthForBufStr = winwidth(0) - g:statusbarKeepWidth
    let [POSB,POSN,POSA] = [0, 1, 2]
    let [strB,strN,strA] = ["", "", ""]
    let strPos = POSB
    let partIdx = 0
	"
    for i in keys(s:bufs)
        let bufName = s:bufs[i]
		
		"the current buffer
        if bufnr("%") == s:bufnrs[i]
            let strPos = POSN
        endif

		"buffer before
        if strPos == POSB
            let strB .= bufName
		"buffer now
        elseif strPos == POSN
            let strN .= bufName
            let strPos = POSA
			"get the buffer part which contains buffer now
            let s:bufNowPartIdx = partIdx
		"buffer past
        elseif strPos == POSA
            let strA .= bufName
        endif
		
        if len(strB.strN.strA.bufName) > widthForBufStr
            call add(s:bufPartStrList, [strB, strN, strA])
            let [strB,strN,strA] = ["", "", ""]
            let partIdx += 1
        endif
    endfor
    if strB != "" || strN != "" || strA != ""
        call add(s:bufPartStrList, [strB, strN, strA])
    endif
	let g:bufNowIdx=index(values(s:bufnrs),bufnr("%"))+1
    call UpdateBufPartStr()
    call BufMap()
	call BufEcho()
endfunction

function! BufEcho()
	redraw
	let msg = g:bufBStr.'['.g:bufNStr.']'.g:bufAStr
	echo msg
endfunction



