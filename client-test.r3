Rebol [
	Title:  "Test HTTPd Scheme (client)"
	File:   %client-test.r3
	Date:    21-Oct-2026
	Version: 0.11.2
	Note: {
		To test POST method from Rebol console, try this:
		```
		write http://localhost:8081 {msg=hello}
		write http://localhost:8081 [post [user-agent: "bla"] "hello"]

		```
	}
	Needs: 3.16.0
]

assert-http: func[
	code [integer!]
	url  [url!]
	/post data
	/local result
][
	all [
		block? result: try [
			either post [
				write/all url data
			][	read/all url ]
		]
		result/1 = code
		result
	]
]

assert-head: func[
	"HEAD must return same status and Content-Length as GET, but no body"
	url [url!]
	/local g h
][
	all [
		block? g: try [read/all url]
		block? h: try [write/all url [HEAD [] ""]]
		g/1 = h/1
		block? h/3
		any [none? h/3/3 empty? h/3/3]
		(to integer! h/2/Content-Length) = length? to binary! g/3
		h
	]
]

ws-echo-test: function [
	"Sends one complete and one split WebSocket frame in a single write; expects both echoed"
][
	request: to binary! ajoin [
		"GET /echo HTTP/1.1^M^/Host: localhost^M^/"
		"Upgrade: websocket^M^/Connection: Upgrade^M^/"
		"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==^M^/"
		"Sec-WebSocket-Version: 13^M^/^M^/"
	]
	;; masked text frames with a zero mask key: "a" and "b"
	frame-a: #{81810000000061}
	frame-b: #{81810000000062}
	result: copy []
	stage: 'handshake
	conn: open tcp://127.0.0.1:8081
	conn/awake: func [event /local port data][
		port: event/port
		switch event/type [
			lookup  [open port]
			connect [write port request]
			wrote   [read port]
			read [
				data: port/data
				case [
					stage = 'handshake [
						either find data #{0D0A0D0A} [
							unless find data "101 " [return true] ;; handshake failed
							stage: 'first
							;; full frame "a" + first 3 bytes of frame "b" in one write
							write port join frame-a copy/part frame-b 3
						][	read port ]
					]
					3 > length? data [read port]
					'else [
						append result copy data
						either stage = 'first [
							stage: 'second
							write port skip frame-b 3 ;; rest of frame "b"
						][	return true ] ;; done
					]
				]
			]
			close [return true]
		]
		false
	]
	wait [conn 5]
	close conn
	result = [#{810161} #{810162}]
]

ws-request: function [
	"Opens a WebSocket to /echo, sends frames in one write; returns reply bytes"
	frames [binary!]
	size   [integer!] "Expected reply size"
][
	request: to binary! ajoin [
		"GET /echo HTTP/1.1^M^/Host: localhost^M^/"
		"Upgrade: websocket^M^/Connection: Upgrade^M^/"
		"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==^M^/"
		"Sec-WebSocket-Version: 13^M^/^M^/"
	]
	result: none
	stage: 'handshake
	conn: open tcp://127.0.0.1:8081
	conn/awake: func [event /local port data][
		port: event/port
		switch event/type [
			lookup  [open port]
			connect [write port request]
			wrote   [read port]
			read [
				data: port/data
				either stage = 'handshake [
					either find data #{0D0A0D0A} [
						unless find data "101 " [return true] ;; handshake failed
						stage: 'frames
						write port frames
					][	read port ]
				][
					either size > length? data [read port][
						result: copy data
						return true
					]
				]
			]
			close [return true]
		]
		false
	]
	wait [conn 5]
	close conn
	result
]

raw-request: function [
	"Sends raw request data; returns all received data once the server closes the connection"
	request [binary! string!]
][
	result: none
	conn: open tcp://127.0.0.1:8081
	conn/awake: func [event /local port][
		port: event/port
		switch event/type [
			lookup  [open port]
			connect [write port request]
			wrote   [read port]
			read    [result: copy port/data read port]
			close   [return true]
		]
		false
	]
	wait [conn 5]
	close conn
	result
]

expect-continue-test: function [
	"Sends POST header with `Expect: 100-continue`, the body only after `100 Continue`"
][
	header: to binary! ajoin [
		"POST / HTTP/1.1^M^/Host: x^M^/Content-Type: text/plain^M^/"
		"Content-Length: 5^M^/Expect: 100-continue^M^/^M^/"
	]
	stage: 'header
	result: none
	conn: open tcp://127.0.0.1:8081
	conn/awake: func [event /local port data][
		port: event/port
		switch event/type [
			lookup  [open port]
			connect [write port header]
			wrote   [read port]
			read [
				data: port/data
				case [
					all [stage = 'header find data "HTTP/1.1 100 "][
						stage: 'body
						write port "hello"
					]
					find data "HTTP/1.1 200 " [
						result: all [stage = 'body copy data]
						return true
					]
					'else [read port]
				]
			]
			close [return true]
		]
		false
	]
	wait [conn 5]
	close conn
	result
]




log-start: any [size? %logs/test-errors.log 0]

;; directory with a file name needing escaping (for listing tests)
make-dir/deep %hosts/test/listing/
write as file! "hosts/test/listing/a&b #1.txt" "x"
make-dir/deep %hosts/test/upload/

print-hline
print as-green "Launching the server..."
pid: launch %server-test.r3
wait 0:0:1

print-hline
print as-green "Doing the tests..."

fails: 0

foreach test [
	[ assert-http      200 http://localhost:8081/            ]
	[ assert-http      200 http://localhost:8081/ip          ]
	[ assert-http      418 http://localhost:8081/ip.php      ]
	[ assert-http      404 http://localhost:8081/xxx         ]
	[ assert-http      200 http://localhost:8081/form.htm    ]
	[ assert-http      200 http://localhost:8081/humans.txt  ]
	[ assert-http      200 http://localhost:8081/plain/      ]
	[ assert-http/post 200 http://localhost:8081 {msg=hello} ]
	[ assert-http/post 200 http://localhost:8081 [post [user-agent: "UA"] "hello"] ]
	[ assert-http/post 200 http://localhost:8081/api/v2/do #[token: "SOME_SECRET" code: "[1 + 1]"] ]
	[ assert-http/post 401 http://localhost:8081/api/v2/do #[token: "ELSE_SECRET" code: "[1 + 1]"] ]
	[ assert-http/post 200 http://localhost:8081/api/v2/do {token=SOME_SECRET&code=1%20%2B%202} ]

	[ assert-head http://localhost:8081/           ] ;; file (index) path
	[ assert-head http://localhost:8081/humans.txt ] ;; actor-generated content

	[ ws-echo-test ]

	;; ping + two text frames in one write: pong first, then both echoes
	[ #{8A0170810161810162} == ws-request #{898100000000708181000000006181810000000062} 9 ]
	;; frame declaring a too large payload (2^40 bytes) -> close frame with 1009, no payload read
	[ #{880203F1} == ws-request #{81FF0000010000000000000000} 4 ]

	;; listing escapes names in text and encodes them in links
	[ all [
		string? s: try [read http://localhost:8081/listing/]
		did find s {href="a%26b%20%231.txt"}
		did find s {>a&amp;b #1.txt<}
	] ]
	;; directory without trailing slash is redirected (and the listing served)
	[ all [
		string? s: try [read http://localhost:8081/listing]
		did find s "a&amp;b #1.txt"
	] ]

	;; header larger than max-header-size -> 431
	[ all [
		binary? r: raw-request ajoin [
			"GET / HTTP/1.1^M^/X-Big: " append/dup copy "" #"x" 40000 "^M^/^M^/"
		]
		did find/match r "HTTP/1.1 431 "
	] ]
	;; declared body larger than max-content-length -> 413 without reading the body
	[ all [
		binary? r: raw-request "POST / HTTP/1.1^M^/Content-Length: 99999999^M^/^M^/"
		did find/match r "HTTP/1.1 413 "
	] ]

	;; two pipelined requests in one write; both must be answered
	[ all [
		binary? r: raw-request ajoin [
			"GET /plain/ HTTP/1.1^M^/Host: x^M^/^M^/"
			"GET /ip HTTP/1.1^M^/Host: x^M^/Connection: close^M^/^M^/"
		]
		did find r "hello"
		did find r "127.0.0.1"
	] ]

	
	;; connection is closed after max keep-alive requests (server-test uses [30 100])
	[ all [
		binary? r: raw-request append/dup copy "" "GET /plain/ HTTP/1.1^M^/Host: x^M^/^M^/" 105
		(n: 0  parse r [any [thru "HTTP/1.1 200 " (++ n)]]  n = 100)
	] ]

	
	;; HTTP/1.0 without keep-alive request is closed right after the response
	[ all [
		binary? r: raw-request "GET /plain/ HTTP/1.0^M^/Host: x^M^/^M^/"
		did find r "Connection: close"
	] ]
	;; HTTP/1.0 asking for keep-alive gets it; the next request without it closes
	[ all [
		binary? r: raw-request ajoin [
			"GET /plain/ HTTP/1.0^M^/Host: x^M^/Connection: keep-alive^M^/^M^/"
			"GET /plain/ HTTP/1.0^M^/Host: x^M^/^M^/"
		]
		(n: 0  parse r [any [thru "HTTP/1.0 200 " (++ n)]]  n = 2)
		did find r "Connection: keep-alive"
		did find r "Connection: close"
	] ]


	;; server sends `100 Continue` before the body is sent, then the final response
	[ binary? expect-continue-test ]


	;; PUT creates a new file (201), replaces it (204), fails on a missing directory (409)
	[ assert-http/post 201 http://localhost:8081/upload/put-test.txt [PUT [] "hello"] ]
	[ "hello" == read/string %hosts/test/upload/put-test.txt ]
	[ assert-http/post 204 http://localhost:8081/upload/put-test.txt [PUT [] "world"] ]
	[ "world" == read/string %hosts/test/upload/put-test.txt ]
	[ assert-http/post 409 http://localhost:8081/upload/missing-dir/x.txt [PUT [] "x"] ]
	;; PUT outside of the allowed locations is forbidden
	[ assert-http/post 403 http://localhost:8081/put-test.txt [PUT [] "x"] ]
	[ assert-http/post 403 http://localhost:8081/upload/../put-test.txt [PUT [] "x"] ]
	[ not exists? %hosts/test/put-test.txt ]


	[ print as-green "Stopping the server..." assert-http 200 http://localhost:8081/stop ]
	;; server must not be reachable anymore
	[ wait 0.25  error? try [read http://localhost:8081/] ]	
][
	print-hline
	print [as-yellow "Assert:" mold/flat test]
	result: try :test 
	print "------"
	print either :result [
		as-green "    OK:"
	][
		++ fails
		as-red   "FAILED:"
	]
	print mold result
	print ""
]

print-hline
;; an early response from On-Header must not be followed by a second 500 response
if find skip read %logs/test-errors.log log-start " 500 " [
	++ fails
	print as-red "FAILED: unexpected 500 response in error log"
]
print-hline

;print as-green "Stopping the server..."
;access-os/set 'pid :pid
;wait 0:0:1

delete as file! "hosts/test/listing/a&b #1.txt"
delete %hosts/test/listing/
delete %hosts/test/upload/put-test.txt
delete %hosts/test/upload/


if fails > 0 [
	print as-red [fails "tests have failed!"]
	quit/return fails
]
print as-green "All tests have passed."




