Rebol [
	Title:  "Test HTTPd Scheme"
	File:   %server-test.r3
	Date:    02-Jul-2020
	Author: "Oldes"
	Version: 0.6.0
	Note: {
		To test POST method from Rebol console, try this:
		```
		write http://localhost:8081 {msg=hello}
		write http://localhost:8081 [post [user-agent: "bla"] "hello"]

		```
	}
]

import %httpd.reb

system/options/log/httpd: 1 ; for verbose output
system/options/quiet: false

make-dir %logs/  ;; make sure that there is the directory for logs

humans.txt: {
       __
      (  )
       ||
       ||
   ___|""|__.._
  /____________\
  \____________/~~~> http://github.com/oldes/
}

http-server/config/actor 8081 [
	;- Main server configuration                                                                 
	
	root: %hosts/test/
	server-name: "nginx" ;= it's possible to hide real server name
	keep-alive: [30 100] ;= [timeout max-requests] or FALSE to turn it off
	log-access: %logs/test-access.log
	log-errors: %logs/test-errors.log
	list-dir?:  #[true]

] [
	;- Server's actor functions                                                                  

	On-Accept: func [info [object!]][
		; allow only connections from localhost
		; TRUE = accepted, FALSE = refuse
		find [ 127.0.0.1 ] info/remote-ip 
	]
	On-Header: func [ctx [object!] /local path key][
		path: ctx/inp/target/file
		;- detect some of common hacking attempts...
		unless parse path [
			some [
				;; common scripts, which we don't use
				  #"." [
				  	  %php
				  	| %aspx
				  	| %cgi
				][end | #"?" | #"#"] reject
				; common hacking attempts to root folders...
				| #"/" [
					  %ecp/      ; we are not an exchange server
					| %mifs/     ; either not MobileIron (https://stackoverflow.com/questions/67901776/what-does-the-line-mifs-services-logservice-mean)
					| %GponForm/ ; nor Gpon router (https://www.vpnmentor.com/blog/critical-vulnerability-gpon-router/)
					| %.env end  ; https://stackoverflow.com/questions/64109005/do-these-env-get-requests-from-localhost-indicate-an-attack
				] reject
				| 1 skip
			]
		][
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
			%/humans.txt [
				;@@ https://codeburst.io/all-about-humans-humans-txt-actually-f571d37f92d2
				;-- serving the content directly from the memory
				ctx/out/status: 200
				ctx/out/header/Content-Type: "text/plain; charset=UTF-8"
				ctx/out/content: humans.txt
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
	On-Post-Received: func [ctx [object!] /local data][
		if ctx/inp/target/file = %/api/v2/do [
			;- A primitive API example                                                    
			try/except [
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
]

