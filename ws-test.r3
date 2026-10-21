Rebol [
	Title:  "Test HTTPd WebSocket framing"
	File:   %ws-test.r3
	Needs:  3.16.0
]

import %httpd.reb

encode: :system/schemes/httpd/WS-Encode-Frame
payload: func [n [integer!]][head insert/dup make binary! n #{61} n]

fails: 0
foreach test [
	[ #{8100} == encode #{} ]
	[ #{81026869} == encode "hi" ]
	[ #{817D} == copy/part encode payload 125 2 ]
	[ 127 == length? encode payload 125 ]
	;; 126 must use the 16-bit extended length
	[ #{817E007E} == copy/part encode payload 126 4 ]
	[ 130 == length? encode payload 126 ]
	[ #{817EFFFF} == copy/part encode payload 65535 4 ]
	[ 65539 == length? encode payload 65535 ]
	;; above 65535 must use the 64-bit extended length
	[ #{817F0000000000010000} == copy/part encode payload 65536 10 ]
	[ 65546 == length? encode payload 65536 ]
][
	print [as-yellow "Assert:" mold/flat test]
	either attempt test [print as-green "OK"][++ fails print as-red "FAILED"]
]

if fails > 0 [
	print as-red [fails "tests have failed!"]
	quit/return fails
]
print as-green "All tests have passed."