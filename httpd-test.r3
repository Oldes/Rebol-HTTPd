Rebol [
	Title:  "Test HTTPd Inner code tests"
	File:   %httpd-test.r3
	Needs:  3.16.0
]

import %httpd.reb
fails: 0

print-hline
print as-yellow "[TEST] HTTPd WebSocket framing"
encode: :system/schemes/httpd/WS-Encode-Frame
payload: func [n [integer!]][head insert/dup make binary! n #{61} n]

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


print-hline
print as-yellow "[TEST] HTTPd status line"
status-line: :system/schemes/httpd/Status-Line

foreach test [
	[ "HTTP/1.1 200 OK^M^/"           == status-line "1.1" 200 ]
	[ "HTTP/1.1 418 I'm a teapot^M^/" == status-line "1.1" 418 ]
	[ "HTTP/1.1 429 Too Many Requests^M^/" == status-line "1.1" 429 ]
	;; unknown code must still produce a valid reason phrase
	[ "HTTP/1.1 299 Unknown^M^/"      == status-line "1.1" 299 ]
][
	print [as-yellow "Assert:" mold/flat test]
	either attempt test [print as-green "OK"][++ fails print as-red "FAILED"]
]


print-hline
print as-yellow "[TEST] HTTPd decode-target"

foreach test [
	;; '+' in query is a space, encoded '+' stays '+'
	[ [a: "x y" b: "1+1"] == select decode-target "/p?a=x+y&b=1%2B1" 'values ]
	;; '+' in path is literal
	[ %/a+b == select decode-target "/a+b?x=1" 'file ]
][
	print [as-yellow "Assert:" mold/flat test]
	either attempt test [print as-green "OK"][++ fails print as-red "FAILED"]
]


print-hline
if fails > 0 [
	print as-red [fails "tests have failed!"]
	quit/return fails
]
print as-green "All tests have passed."