Rebol [
	Title:  "Test HTTPd Scheme using RSP (client)"
	File:   %client-test-rsp.r3
	Needs: 3.16.0
]

import 'json

print-horizontal-line
print as-green "Launching the server..."
pid: launch %server-test-rsp.r3
wait 0:0:1

print-horizontal-line
print as-green "Doing the tests..."

fails: 0
url: http://localhost:8083/

foreach test [
	[  1 == load url/test_01.rsp ]
	[  2 == load url/test_02.rsp ]
	[ [method: GET values: []] == load url/test_03.rsp ]
	[ [method: GET values: [a: "1" b: "2"]] == load url/test_03.rsp?a=1&b=2 ]
	[ #[test: 4] == decode 'json read url/test_04.rsp ]
	[ "124" == read url/test_05.rsp ]
][
	print-horizontal-line
	print [as-yellow "Assert:" mold/flat test]
	result: try :test 
	print "------"
	print either :result [
		as-green "OK"
	][
		++ fails
		as-red   "FAILED"
	]
	print ""
]

print-horizontal-line
print as-green "Stopping the server..."
access-os/set 'pid :pid
wait 0:0:1

if fails > 0 [
	print as-red [fails "tests have failed!"]
	quit/return fails
]
print as-green "All tests have passed."
