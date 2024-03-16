if get(g:, 'restclient_loaded', v:false)
  finish
endif
let g:restclient_loaded = v:true

let s:cpo_save = &cpo
set cpo&vim


" let s:pattern = '{{?\zs[^}]*\ze}}'
let s:pattern = '{{\zs\$\?[^}]*\ze}}'

function! s:generate_uuid()
  let l:uuid = ''
  for i in range(1, 36)
    if i == 9 || i == 14 || i == 19 || i == 24
      let l:uuid .= '-'
    elseif i == 15
      let l:uuid .= '4'
    elseif i == 20
      let l:uuid .= printf('%x', (rand() % 4) + 8)
    else
      let l:uuid .= printf('%x', rand() % 16)
    endif
  endfor
  return l:uuid
endfunction

function! s:load_variables() abort
  if !exists('b:rest_variables')
    let b:rest_variables = {}
  endif
  for i in range(1, line('$'))
    " Get the current line content
    let l:line = getline(i)
    let l:matched = matchlist(l:line, '^\s*@\(\w\+\)\s*=\#*\([^=]\+\)$')
    if len(l:matched) > 0
      let b:rest_variables[matched[1]] = trim(matched[2])
    endif
  endfor
  let b:rest_variables['$uuid'] = s:generate_uuid()
endfunction

function! s:get_request_lines() abort
  let l:current_line = getpos('.')[1]
  let l:start_line   = 1
  let l:end_line     = line('$')

  " Search backward for ### or start of buffer
  let l:start_search = search('###', 'bWn')
  if l:start_search != 0
    " Skip blank lines after delimiter to find the start of the request
    let l:start_line = l:start_search + 1
    while l:start_line <= line('$') && getline(l:start_line) =~ '^\s*$'
      let l:start_line += 1
    endwhile
  endif

  " Move curSor back to the original position after search
  call cursor(l:current_line, 1)

  " search forward for ### or end of buffer
  let l:end_search = search('###', 'Wn')
  if l:end_search != 0
    let l:end_line = l:end_search - 1
    while l:end_line > 1 && getline(l:end_line) =~ '^\s*$'
      let l:end_line -= 1
    endwhile
  endif

  let l:lines = getline(l:start_line, l:end_line)
  return l:lines
endfunction

function! s:get_variable(key)
  let l:keys = split(a:key, '\.')
  let l:result = b:rest_variables
  for k in l:keys
    if has_key(l:result, k)
      let l:result = result[k]
    else
      return v:null
    endif
  endfor
  return l:result
endfunction

function! s:expand_variables(request_lines) abort
  let l:return_lines = []
  " loop through request_lines
  for i in range(0, len(a:request_lines) - 1)
    let l:line = a:request_lines[i]
    while match(l:line, s:pattern) != -1
      let l:matched_var = trim(matchstr(l:line, s:pattern))
      if len(l:matched_var) > 0
        let l:line = substitute(l:line, '{{\s*' . escape(l:matched_var, '\') . '\s*}}', s:get_variable(l:matched_var), 'g')
      else
        break
      endif
    endwhile
    let l:return_lines += [l:line]
  endfor

  return l:return_lines
endfunction

function! s:parse_request(request_lines) abort
  let l:request = {}
  let l:headers = {}
  let l:payload = ''
  let l:reading_payload = v:false
  let l:found_url = v:false
  let l:text = ''

  for line in a:request_lines
    " Find the name of the request in format `# @name name`
    let l:matched = matchlist(line, '^#\s*@\(\w\+\)\s*\#*\([^=]\+\)$')
    if len(l:matched) > 0
      let l:request['name'] = l:matched[2]
      continue
    endif

    if line =~ '^\s*#\s*' " Skip commented lines
      continue
    endif

    if line == '' && l:found_url
      let l:reading_payload = v:true
    endif

    if l:reading_payload
      let l:payload .= line
    endif

    if l:found_url && !l:reading_payload
      if line =~? '^content-type.*'
        let l:parts = split(line, ': ')
        let l:request['content_type'] = trim(l:parts[1])
      endif
      let l:header_parts = split(line, ':')
      let l:headers[l:header_parts[0]] = trim(l:header_parts[1])
    endif

    if line =~ '\v(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|CONNECT)'
      let l:found_url = v:true
      let l:parts = split(line, '\s\+')
      let l:request['method'] = l:parts[0]
      let l:request['url'] = l:parts[1]
      if len(l:parts) == 3
        let l:request['http_version'] = l:parts[2]
      endif
    endif

    let l:text .= line . '\n'
  endfor

  let l:request['headers'] = l:headers
  let l:request['payload'] = l:payload

  let l:request['text'] = l:text

  if has_key(l:request, 'name')
    let b:rest_variables[l:request.name] = { 'request': l:request }
  endif

  return l:request
endfunction

function! s:build_curl_command(request) abort
  let l:curl_command = 'curl -s -i -X ' . a:request.method . ' '
  if has_key(a:request, 'http_version')
    let l:parts = split(a:request.http_version, '/')
    let l:curl_command .= '--http' . l:parts[1] . ' '
  endif

  for header in keys(a:request.headers)
    let l:curl_command .= '-H ' . shellescape(header . ': ' . a:request.headers[header]) . ' '
  endfor

  if len(a:request.payload) > 0
    let l:content_type = get(a:request, 'content_type', '')
    if l:content_type == 'application/json' || (l:content_type == '' && a:request.payload[0] == '{')
      let l:curl_command .= '--json ' . shellescape(a:request.payload)
    else
      let l:curl_command .= '--data ' . shellescape(a:request.payload)
    endif
  endif

  let l:curl_command .= ' ' . shellescape(a:request.url)
  return l:curl_command
endfunction


function! s:parse_response(request, response_lines) abort
  let l:response = { 'status_code' : -1, 'headers': {}, 'body_text': '', 'body': v:null}

  let l:status_code = substitute(a:response_lines[0], '^HTTP/\d\+\.\d\+\s*\(\d\+\)', '\1', '')
  let l:response['status_code'] = str2nr(l:status_code)

  execute 'let @' . get(g:, 'rest_client_response_register', '_') . '=a:response_lines[0] + "\n"'
  call setreg(get(g:, 'rest_client_header_register', '_'), '')
  call setreg(get(g:, 'rest_client_body_register', '_'), '')

  let l:finished_parsing_headers = v:false
  let l:headers = {}
  for i in range(2, len(a:response_lines) - 1)
  execute 'let @' . toupper(get(g:, 'rest_client_response_register', '_')) . '=a:response_lines[i] + "\n"'
    if !l:finished_parsing_headers && a:response_lines[i] == ''
      let l:finished_parsing_headers = v:true
    endif

    if !l:finished_parsing_headers
      execute 'let @' . toupper(get(g:, 'rest_client_header_register', '_')) . '=a:response_lines[i] + "\n"'
      let l:header_parts = split(a:response_lines[i], ':')
      let l:headers[l:header_parts[0]] = trim(l:header_parts[1])
    endif

    if l:finished_parsing_headers
      execute 'let @' . toupper(get(g:, 'rest_client_body_register', '_')) . '=a:response_lines[i] + "\n"'
      let l:response['body_text'] .= a:response_lines[i] . "\n"
    endif
  endfor

  if l:headers['Content-Type'] =~? '.*json.*'
    let l:response['body'] = json_decode(l:response['body_text'])
  endif 
  let l:response['headers'] = l:headers

  if has_key(a:request, 'name')
    let b:rest_variables[a:request.name] = { 'request': a:request, 'response': l:response }
  endif

  return l:response
endfunction

function! s:show_response(response, qmods)
  let l:orig_win_id = win_getid()

  if exists('s:bufnr')
    execute 'silent! bwipe' . s:bufnr
  endif

  let l:window_cmd = len(a:qmods) == 0 ? 'vertical' : a:qmods
  execute l:window_cmd . ' new'
  setf restresult
  call setline(1, split(a:response, '\n'))
  setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nomodifiable nospell
  nnoremap <silent><buffer><nowait> q :q<CR>
  let s:bufnr = bufnr('')
  call win_gotoid(l:orig_win_id)
endfunction

function! s:send_request(qmods) abort
  call s:load_variables()
  let l:request_lines = s:get_request_lines()

  if len(l:request_lines) == 0
    echom "No request found"
    return
  endif

  let l:request_lines = s:expand_variables(l:request_lines)
  let l:request = s:parse_request(l:request_lines)
  let l:curl = s:build_curl_command(l:request)
  let l:response_text = system(l:curl)
  let l:response = s:parse_response(l:request, split(l:response_text, '\n'))
  call s:show_response(l:response_text, a:qmods)
endfunction

command! SendRequest call <SID>send_request(<q-mods>)
