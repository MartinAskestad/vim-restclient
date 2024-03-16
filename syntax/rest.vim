if exists('b:current_syntax')
  finish
endif

if !exists('main_syntax')
  let main_syntax = 'rest'
endif

syn match restVariable /@\w\+\(\s\|=\)\@=/
syn match restMustache /{{\s*\w\+\s*}}/
syn match restHttpHeader /^\w\([^:]\+\):/
syn keyword restTodo contained TODO FIXME XXX NOTE
syn keyword restKeyword contained name prompt
syn match restPreProcessor contained /@\w\+$/ contains=restKeyword
syn region restComment display oneline start=/\%\(^\|\#\)#/ end='$' contains=restTodo,@Spell,restKeyword
syn match restUrl /http[s]\?:\/\/[[:alnum:]%\/_#.-]*/

syn keyword restVerb GET POST PUT DELETE PATH OPTIONS HEAD TRACE CONNECT

highlight link restComment Comment
highlight link restVariable Identifier
highlight link restMustache Identifier
highlight link restHttpHeader Identifier
highlight link restPreProcessor Keyword
highlight link restVerb Keyword

highlight restUrl cterm=underline gui=underline
