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

log-start: any [size? %logs/test-errors.log 0]

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

if fails > 0 [
	print as-red [fails "tests have failed!"]
	quit/return fails
]
print as-green "All tests have passed."




