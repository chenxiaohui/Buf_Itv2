"Author:  zzsu (vimtexhappy@gmail.com)
"         Buffer list in statusline
"         2011-02-14 07:07:48 v4.0
"License: Copyright (c) 2001-2009, zzsu
"         GNU General Public License version 2 for more details.

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
		"自定义
		set statusline=%m\{%{&ff}:%{&fenc}:%Y}\ %{g:bufBStr}%#NowBuf#%{g:bufNStr}%#StatusLine#%{g:bufAStr}%<%=%c:%l/%L%<
		"原来
		"set statusline=%m\{%{&ff}:%{&fenc}:%Y}\ %{g:bufBStr}%#NowBuf#%{g:bufNStr}%#StatusLine#%{g:bufAStr}%<%=%c:%l/%L%<
		"系统
		"set statusline=\ %<%F[%1*%M%*%n%R%H]%=\ %y\ %0(%{&fileformat}\ [%{(&fenc==\"\"?&enc:&fenc).(&bomb?\",BOM\":\"\")}]\ %c:%l/%L%)
    endif
endif
"当前buf的index
let g:bufNowIdx = 0
"多屏显示里当前的part
let s:bufNowPartIdx = 0

"buf显示名称列表
let s:bufs = {}
"buf对应内部序号表
let s:bufnrs = {}

"多屏显示part列表
let s:bufPartStrList = []

function! CloseDefaultBuf()
    "存在默认buffer就关掉
	if buflisted(1) && empty(bufname(1))
		exec 'bd1'
	endif
	call UpdateStatus()
endfun

"取消键映射
function! BufUnMap()
    for i in keys(s:bufs)
		"小于10个文件,bufs按序排队
        if i < 10
            exec "silent! unmap <M-".i.">"
        else
            exec "silent! unmap <M-".i/10."><M-".i%10.">"
        endif
    endfor
endfun
"映射键位
function! BufMap()
    for i in keys(s:bufs)
        if i < 10
            exec "silent! noremap <M-".i."> :call BufChange(".i.")<CR>"
        else
            exec "silent! noremap <M-".i/10."><M-".i%10."> :call BufChange(".i.")<CR>"
        endif
    endfor
endfunction

"关闭其他所有的buf
function! BufOnly()
    let i = 1
	"bufnr('$')返回最后一个缓冲区,buflisted(i)判断i号缓冲区是否存在,buwinnr包含缓冲区i的窗口，winnr返回当前窗口
    while(i <= bufnr('$'))
		"第i个缓冲区存在且可编辑且不在当前窗口，关闭之
        if buflisted(i) && getbufvar(i, "&modifiable")
                    \   && (bufwinnr(i) != winnr())
            exec 'bw'.i
        endif
        let i = i + 1
    endwhile
    call UpdateStatus()
endfun

"关闭函数
function! BufClose(force)
	if(!a:force && &modified)
		echohl WarningMsg | echo "Buffer Modified!" | echohl None
		return
	endif
	let cmd=a:force?'bd!':'bd'
	let qcmd=a:force?'q!':'q'
	call UpdateStatus()
	if exists("t:NERDTreeBufName") && bufname("%")==t:NERDTreeBufName
		return
	endif
	"非编辑窗口，直接bd
	if index(values(s:bufnrs),winbufnr(0))==-1
		exec cmd
	"编辑窗口，如果只有一个，退出，如果多个，有nerdtree切换，关闭,否则直接关闭
	elseif len(s:bufnrs)>1
		if exists("t:NERDTreeBufName")
			let ibufNow=bufnr("%")
			call BufNextPart() 
			exec cmd.ibufNow
		else 
			exec cmd
		endif
	else 
		exec qcmd 
		exec qcmd 
		exec qcmd 
	endif   
	call UpdateStatus()
endfun

"切换到某个buf
function! BufChange(idx)
	"bufnrs按序存放
    exec 'b! '.s:bufnrs[a:idx]
	let g:bufNowIdx=a:idx
endfunction
"分割显示某个buf
"function! BufSplit(idx)
    "exec 'sb! '.s:bufnrs[a:idx]
"endfunction
"下一个buf
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
"上一个buf
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
	"超过一屏,之前有显示'<<'
    if s:bufNowPartIdx > 0
        let g:bufBStr = '<<'.g:bufBStr
    endif
	"超过一屏,之后有显示'>>'
    if s:bufNowPartIdx < len(s:bufPartStrList)-1
        let g:bufAStr = g:bufAStr.'>>'
    endif
endfunction

function! UpdateStatus()
	"取消所有的键位,全部清空数组
    call BufUnMap()
    let s:bufs = {}
    let s:bufNowPartIdx = 0
    let s:bufnrs = {}
    let s:bufPartStrList = []
    let idx = 1
    let i = 1
	
	"从第一个到当前buf
    while(i <= bufnr('$'))
		"存在且可编辑
        if buflisted(i) && getbufvar(i, "&modifiable")
            "bufName类似 1-buf_it.vim+,bufs按序存放buf名，bufnrs按序存放内部id
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
	
	"最大容许宽度
    let widthForBufStr = winwidth(0) - g:statusbarKeepWidth
    let [POSB,POSN,POSA] = [0, 1, 2]
    let [strB,strN,strA] = ["", "", ""]
    let strPos = POSB
    let partIdx = 0
	"遍历所有缓冲区并显示
    for i in keys(s:bufs)
        let bufName = s:bufs[i]
		
		"遍历到当前缓冲区
        if bufnr("%") == s:bufnrs[i]
			"置当前缓冲区
            let strPos = POSN
        endif

		"没到当前缓冲区
        if strPos == POSB
            let strB .= bufName
		"当前缓冲区
        elseif strPos == POSN
            let strN .= bufName
            let strPos = POSA
			"当前缓冲区所在的bufpart
            let s:bufNowPartIdx = partIdx
		"过了当前缓冲区
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

"function! NERDTree_Exit_Only_Window()
	"echo 'test'
	"if count(bufnrs)==1
		"exec 'q'
"endfunction


