Rebol [
	Title:  "Test HTTPd Scheme"
	File:   %server-test.r3
	Date:    14-Dec-2023
	Author: "Oldes"
	Version: 0.9.0
	Needs:   3.11.0
	Note: {
		To test POST method from Rebol console, try this:
		```
		write http://localhost:8081 {msg=hello}
		write http://localhost:8081 [post [user-agent: "bla"] "hello"]

		```
	}
]

import %httpd.reb

system/schemes/httpd/set-verbose 4 ; for verbose output
system/options/quiet: true

make-dir %logs/  ;; make sure that there is the directory for logs

robots.txt: {User-agent: *^/Disallow: /}
humans.txt: {
       __
      (  )
       ||
       ||
   ___|""|__.._
  /____________\
  \____________/~~~> http://github.com/oldes/
}

serve-http [
	port: 8081
	;- Main server configuration                                                                 
	root: %hosts/test/
	server-name: "nginx" ;= it's possible to hide real server name
	keep-alive: [30 100] ;= [timeout max-requests] or FALSE to turn it off
	log-access: %logs/test-access.log
	log-errors: %logs/test-errors.log
	list-dir?:  true
	trust-ips: [127.0.0.1]
	;- Server's actor functions                                                                  
	actor: [
		On-Accept: func [ctx][
			; allow only connections from localhost
			; TRUE = accepted, FALSE = refuse
			find ctx/config/trust-ips ctx/remote-ip 
		]
		On-Header: func [ctx [object!] /local path key][
			path: ctx/inp/target/file

			;- detect some of common hacking attempts...
			unless parse path anti-hacking-rules [
				ctx/out/status: 418 ;= I'm a teapot
				ctx/out/header/Content-Type: "text/plain; charset=UTF-8"
				ctx/out/content: "Your silly hacking attempt was detected!"
				exit
			]
			;- serve valid content...
			switch path [
				%/form/     [
					; path rewrite...
					; http://localhost:8081/form/ is now same like http://localhost:8081/form.html
					ctx/inp/target/file: %/form.html
					; request processing will continue
				]
				%/form.htm
				%/form.html [
					ctx/out/status: 301 ;= Moved Permanently
					ctx/out/header/Location: %/form/
					; request processing will stop with redirection response
				]
				%/plain/ [
					ctx/out/status: 200
					ctx/out/header/Content-Type: "text/plain; charset=UTF-8"
					ctx/out/content: "hello"
					; request processing will stop with response 200 serving the plain text content
				]
				%/ip [
					; service to resolve the remote ip like: http://ifconfig.me/ip
					ctx/out/status: 200
					ctx/out/header/Content-Type: "text/plain"
					ctx/out/content: form ctx/remote-ip
				]
				%/header [
					ctx/out/status: 200
					ctx/out/header/Content-Type: "text/plain"
					ctx/out/content: ajoin [
						"Request input:" mold ctx/inp
					]
				]
				%/echo [
					;@@ Consider checking the ctx/out/header/Origin value
					;@@ before accepting websocket connection upgrade!   
					system/schemes/httpd/actor/WS-handshake ctx
				]
			]
		]
		On-Post: func [ctx [object!] /local data][
			if ctx/inp/target/file = %/api/v2/do [
				;- A primitive API example                                                    
				try/with [
					;?? ctx/inp
					data: ctx/inp/content
					unless map? data [data: to map! ctx/inp/content/1] ;;= url-encoded input
					;; using plain secret in this example,
					;; but it should be replaced with something better in the real life
					if data/token <> "SOME_SECRET" [
						ctx/out/status: 401 ;= Unauthorized
						exit
					]
					;; reusing the input for an output
					;; without the token...
					remove/key data 'token
					;; but with result of the input expression...
					;@@ NOTE that there is no security setting, so the code may be dangerous!
					data/result: mold/all try load data/code
					ctx/out/header/Content-Type: "application/json"
					ctx/out/content: to-json data
				][
					ctx/out/status: 400 ;= Bad request
				]
				exit
			]
			;; else just return what we received...
			ctx/out/content: ajoin [
				"<br/>Request header:<pre>" mold ctx/inp/header </pre>
				"Received <code>" ctx/inp/header/Content-Type/1 
				"</code> data:<pre>" mold ctx/inp/content </pre>
			]
		]
		On-Not-Found: func[ctx][
			;; Here may be provided custom content, when requested file is not found
			unless parse ctx/inp/target/file [
				;; we must work with an absolute path!
				ctx/config/root [
					;-- serving the content directly from the memory
					%humans.txt (ctx/out/content: humans.txt) ;@@ https://codeburst.io/all-about-humans-humans-txt-actually-f571d37f92d2
				|	%robots.txt (ctx/out/content: robots.txt) ;@@ https://developers.google.com/search/docs/crawling-indexing/robots/create-robots-txt
				|	%bot-trap/  (ctx/out/content: ajoin ["Welcome bot: " ctx/inp/header/User-Agent])
				]
			][
				ctx/out/status: 404
				;; including an optional message...
				ctx/out/content: "Content not found on this server!"
			]
		]
		;-- WebSocket related actions                                                                
		On-Read-Websocket: func[ctx final? opcode][
			print ["WS opcode:" opcode "final frame:" final?]
			either opcode = 1 [
				probe ctx/out/content: to string! ctx/inp/content
			][
				? ctx/inp/content
			]
		]
		On-Close-Websocket: func[ctx code /local reason][
			reason: any [
				select [
					1000 "the purpose for which the connection was established has been fulfilled."
					1001 "a browser navigated away from a page."
					1002 "a protocol error."
					1003 "it has received a type of data it cannot accept."
					1007 "it has received data within a message that was not consistent with the type of the message."
					1008 "it has received a message that violates its policy."
					1009 "it has received a message that is too big for it to process."
					1010 "it has expected the server to negotiate one or more extension, but the server didn't return them in the response message of the WebSocket handshake."
					1011 "it encountered an unexpected condition that prevented it from fulfilling the request."
				] code
				ajoin ["an unknown reason (" code ")"]
			]
			print ["WS connection is closing because" reason]
			unless empty? reason: ctx/inp/content [
				;; optional client's reason
				print ["Client's reason:" as-red to string! reason]
			]
		]
	] ;end of actors
]

