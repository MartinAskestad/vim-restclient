set commentstring=#\ %s

function s:jump_to_next_request() abort
  let current_line = line('.')
  let next_section_line = search('^\w*\shttp', 'W')
  if next_section_line
    call cursor(next_section_line, 1)
  endif
endfunction

function! s:jump_to_previous_request() abort
  let current_line = line('.')
  let prev_section_line = search('^\w*\shttp', 'bW')
  if prev_section_line > 0
    call cursor(prev_section_line, 1)
  endif
endfunction

nnoremap <silent><buffer> ]] :call <SID>jump_to_next_request()<CR>
nnoremap <silent><buffer> [[ :call <SID>jump_to_previous_request()<CR>
