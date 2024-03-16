# vim-restclient

Rest client allows you to send HTTP requests and view the response directly
in vim.

## Getting started
To get started, create a buffer with the `filetype` 'rest'
```vim
	:set ft=rest
```
Enter a http-verb and an url for example:
```
	GET https://httpbin.org/get?hello=world
```
Then run the command `:SendRequest` and you'll get the response in a new split.
You can also choose to add headers and a body to your request.
```
	POST https://httpbin.org/post
	Content-Type: application/json

	{
		"message": "Hello, from vim"
	}
```
A *rest* buffer can have multiple requests in one file separating them by
using three '#' symbols. The `:SendRequest` command will run whichever request
the cursor is closest to.
```
	GET https://httpbin.org/get

	###

	GET https://httpbin.org/get?again=true

	###

	POST https://httpbin.org/post
	Content-Type: application/json

	{
		"message": "Third times the charm"
	}
```

Variables can be used to easily reuse values between requests.
```
	@user_agent = vim-restclient

	GET https://httpbin.org/get
	User-Agent: {{ user_agent }}

	###

	POST https://httpbin.org/post
	User-Agent: {{ user_agent }}
	Content-Type: application/x-www-form-urlencoded

	message=Hello+from+vim
```

A request can med named allowing to share data between requests and responses.
```vim
	# @name get_req
	GET https://httpbin.org/get?name=vim

	###

	POST https://httpbin.org/post
	Content-Type: application/json

	{
		"name": "{{ get_req.response.body.args.name }}"
	}
```

## Options

Restclient has some options to automatically put the response, the response
headers and the response body into registers to easily paste in other buffers.


g:rest_client_header_register	A register where all the response headers 
				will be stored.
```
let g:rest_client_header_register = 'h'
```

g:rest_client_body_register	A register where the body of the response
				will be stored.
```
let g:rest_client_body_register = 'b'
```

g:rest_client_response_register	A register where the whole combined response
				will be stored.
```
let g:rest_client_response_register = 'r'
```
