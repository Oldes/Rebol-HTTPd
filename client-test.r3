Rebol [
	Title:  "Test HTTPd Scheme (client)"
	File:   %client-test.r3
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

print-horizontal-line
print as-green "Launching the server..."
pid: launch %server-test.r3
wait 0:0:1

print-horizontal-line
print as-green "Doing the tests..."

fails: 0

foreach test [
	[ assert-http      200 http://localhost:8081/            ]
	[ assert-http      200 http://localhost:8081/ip          ]
	[ assert-http      418 http://localhost:8081/ip.php      ]
	[ assert-http      404 http://localhost:8081/xxx         ]
	[ assert-http      200 http://localhost:8081/form.htm    ]
	[ assert-http      200 http://localhost:8081/humans.txt  ]
	[ assert-http/post 200 http://localhost:8081 {msg=hello} ]
	[ assert-http/post 200 http://localhost:8081 [post [user-agent: "UA"] "hello"] ]

][
	print-horizontal-line
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

print-horizontal-line
print as-green "Stopping the server..."
access-os/set 'pid :pid
wait 0:0:1

if fails > 0 [ quit/return fails ]
print as-green "DONE"




