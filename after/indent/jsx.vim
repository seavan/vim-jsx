"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Vim indent file
"
" Language: JSX (JavaScript)
" Maintainer: Max Wang <mxawng@gmail.com>
" Depends: pangloss/vim-javascript
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Prologue; load in XML indentation.
if exists('b:did_indent')
  let s:did_indent=b:did_indent
  unlet b:did_indent
endif
exe 'runtime! indent/xml.vim'
if exists('s:did_indent')
  let b:did_indent=s:did_indent
endif

setlocal indentexpr=GetJsxIndent()

" JS indentkeys
setlocal indentkeys=0{,0},0),0],0\,,!^F,o,O,e
" XML indentkeys
setlocal indentkeys+=*<Return>,<>>,<<>,/

" Self-closing tag regex.
let s:sctag = '^\s*\/>\s*;\='

" Get all syntax types at the beginning of a given line.
fu! SynSOL(lnum)
  return map(synstack(a:lnum, 1), 'synIDattr(v:val, "name")')
endfu

" Get all syntax types at the end of a given line.
fu! SynEOL(lnum)
  let lnum = prevnonblank(a:lnum)
  let col = strlen(getline(lnum))
  return map(synstack(lnum, col), 'synIDattr(v:val, "name")')
endfu

" Check if a syntax attribute is XMLish.
fu! SynAttrXMLish(synattr)
  return a:synattr =~ "^xml" || a:synattr =~ "^jsx"
endfu

" Check if a synstack is XMLish (i.e., has an XMLish last attribute).
fu! SynXMLish(syns)
  return SynAttrXMLish(get(a:syns, -1))
endfu

" Check if a synstack has any XMLish attribute.
fu! SynXMLishAny(syns)
  for synattr in a:syns
    if SynAttrXMLish(synattr)
      return 1
    endif
  endfor
  return 0
endfu

" Check if a synstack denotes the end of a JSX block.
fu! SynJSXBlockEnd(syns)
  return get(a:syns, -1) == 'jsBraces' && SynAttrXMLish(get(a:syns, -2))
endfu

" Check if a synstack denotes the conditional thing like ternary, before JSX block.
fu! SynJSXTernary(lnum)
  return match(getline(a:lnum), "[?:]\s*$") != -1
endfu

" Find line above 'lnum' that isn't empty, in a comment, or in a string.
fu! PrevXmlBlock(lnum)
  let in_block = 0
  let long_autoclosing_block = 0
  let lnum = (a:lnum)
  while lnum > 0
    " Go in and out of blocks comments as necessary.
    " If the line isn't empty (with opt. comment) or in a string, end search.
    let line = getline(lnum)
    let closematches = len(split(line, '</.*>', 1)) - 1
    let openmatches = len(split(line, '<[^/]*>', 1)) - 1
    let openmatches = openmatches + len(split(line, '<[^/>]*$', 1)) - 1
    let in_block = in_block + openmatches - closematches
    echom line
    if line =~ '[^<]*/>\s*$'
        echom "autoclosing block start"
        let long_autoclosing_block = 1
    endif
    if line =~ '^\s*<' && (long_autoclosing_block > 0)
        echom "autoclosing block end"
        let long_autoclosing_block = 0
        let openmatches = openmatches - 1
        let in_block = in_block - 1
        let lnum = (lnum - 1)
        continue
    endif
    echom openmatches
    echom closematches
    if line =~ '^\s*<' && (openmatches > 0 || closematches > 0)
        echom "current block"
        echom in_block
        if in_block == 1
            break
        endif
    endif
    let lnum = (lnum - 1)
  endwhile
  return lnum
endfunction


" Cleverly mix JS and XML indentation.
fu! GetJsxIndent()
  let cursyn  = SynSOL(v:lnum)
  let prevsyn = SynEOL(v:lnum - 1)
  let prev_lnum = prevnonblank(v:lnum - 1)
  let cur_line = getline(v:lnum)
  let prev_line = getline(prev_lnum)
  " Use XML indenting if the syntax at the end of the previous line was either
  " JSX or was the closing brace of a jsBlock whose parent syntax was JSX.
  " Remove <i> from inline elements in WebStorm
  if (SynXMLish(prevsyn) || SynJSXBlockEnd(prevsyn) || SynJSXTernary(prev_lnum)) && SynXMLishAny(cursyn)
    let ind = XmlIndentGet(v:lnum, 0)
    echom "xmlindent"
    echom ind
    " correct attribute indentation
    if match(prev_line, '>\s*[:?]*\s*$') == -1
        echom "attribute fixing"
        echom prev_line
        let att_shift = match(prev_line, '\s\w')
        echom att_shift
        if att_shift > 0
            let ind = att_shift + 1
        endif
    " correct bad indent (hack)
    elseif (ind % &sw) != 0
      let ind = ind - (ind % &sw)
    endif
    " Align '/>' with '<' for multiline self-closing tags.
    if getline(v:lnum) =~? s:sctag
      let ind = ind - &sw
    endif

    " Then correct the indentation of any JSX following '/>'.
    if getline(v:lnum - 1) =~? s:sctag
      let ind = ind + &sw
    endif

    " correct indentation of tag, following closed multiline tag '/>'
    if getline(v:lnum - 1) =~ '/>\s*$' && getline(v:lnum - 1) !~ '^\s*<'
      call cursor(v:lnum - 1, 1)
      let ind = indent(search('<', 'bW'))
    endif

    " correct indentation of tags immediately after js blocks
    " exclude attributes w/ JSX
    if prev_line =~ '^\s*{.*}\s*$'
      call cursor(v:lnum - 1, 1)
      " call cursor(searchpair('{', '', '}', 'bW') - 1, 1)
      let ind = indent(search('<', 'bW')) + &sw
    endif

    " correct indentation of closing tags
    if cur_line =~ '^\s*</'
      echom "correct closing tags"
      let ind = indent(PrevXmlBlock(v:lnum - 1))
    endif

    " correcting prev. colon
    if match(prev_line, "[:]\s*$") != -1
      echom "correct colon tags"
      let ind = indent(search('<', 'bW')) " + &sw
      call cursor(v:lnum - 1, 1)
    endif

    " correcting prev. question mark
    if match(prev_line, "[?]\s*$") != -1
      echom "correct question mark"
      let ind = indent(search('<', 'bW')) + &sw
      call cursor(v:lnum - 1, 1)
    endif

    " correct closing tags
    if prev_line !~ '[</]' && prev_line =~ '>\s*$'
      echom "correct closing tags"
      let ind = indent(PrevXmlBlock(v:lnum - 1)) + &sw
    endif

    " correct javascript blocks
    if match(cur_line, '^\s*{') != -1
        echom "javascript indent 2"
        if match(prev_line, '^\s*{') != -1
            call cursor(v:lnum - 1, 1)
            let ind = indent(searchpair('^\s*{', '', '}', 'bW'))
        else
            let ind = indent(PrevXmlBlock(v:lnum - 1)) + &sw
        endif
    endif
  else
    echom "javascript indent"
    let ind = GetJavascriptIndent()
    " correct indent for comma after keywords (like var)
    "if match(prev_line, 'var.*,\s*$') != -1
        "echom "comma indent fixing"
        "let comma_shift = match(prev_line, '\w\+,\s*$')
        "if comma_shift > 0
            "echom comma_shift
                        "let ind = comma_shift
        "endif
    "endif
  endif

  " fix indent for lines starting with ':'
  if (prev_line =~ '/>\s*[)]*\s*$') && (cur_line =~ '^\s*[:]')
      call cursor(v:lnum - 1, 1)
      let ind = indent(searchpair('<', '', '>', 'bW'))
  endif

  echom "final indent"
  echom ind
  return ind
endfu
