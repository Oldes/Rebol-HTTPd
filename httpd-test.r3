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
	;; key without `=` doesn't stop parsing
	[ [flag: "" a: "1"] == select decode-target "/p?flag&a=1" 'values ]
	;; empty values are kept
	[ [a: "" b: "2"] == select decode-target "/p?a=&b=2" 'values ]
	;; `=` and `?` are valid inside a value
	[ [a: "b=c" d: "1"] == select decode-target "/p?a=b=c&d=1" 'values ]
	[ [a: "x?y"] == select decode-target "/p?a=x?y" 'values ]
	;; pair without a key is skipped
	[ [b: "2"] == select decode-target "/p?=1&b=2" 'values ]
	;; key which is not a valid word doesn't fail the decoding
	[ 4 = length? select decode-target "/p?1=x&b=2" 'values ]
	[ #{66} == select decode-target "/p?a=1#f" 'fragment ]
][
	print [as-yellow "Assert:" mold/flat test]
	either attempt test [print as-green "OK"][++ fails print as-red "FAILED"]
]


print-hline
print as-yellow "[TEST] HTTPd Safe-Path"
safe-path: :system/schemes/httpd/Safe-Path
;; on Windows %/srv/ would be a UNC path (network lookup), so use a local drive
root: either system/platform = 'Windows [%/C/srv/www/][%/srv/www/]
;; result must be NONE or a path inside root without any `..` segment
inside?: func [p][any [none? p all [find/match p root not find p "/../"]]]

foreach test [
	[ (join root %a/b.txt) == safe-path root %/a/b.txt ]
	[ root == safe-path root %/ ]
	;; `..` is resolved by clean-path (clamped at root) or rejected
	[ inside? safe-path root %/a/../b ]
	[ inside? safe-path root %/../etc/passwd ]
	[ inside? safe-path root %/a/../../etc/passwd ]
	[ inside? safe-path root %../x ]
	[ inside? safe-path root select decode-target "/%2e%2e/%2e%2e/etc/passwd" 'file ]
	;; file literals convert `\` to `/`, so build these from strings
	[ none? safe-path root as file! "/..\..\windows\win.ini" ]
	[ none? safe-path root as file! "/a^@b" ]
][
	print [as-yellow "Assert:" mold/flat test]
	either attempt test [print as-green "OK"][++ fails print as-red "FAILED"]
]


print-hline
print as-yellow "[TEST] HTTPd Safe-Path symlinks"
either system/platform = 'Windows [
	print "skipped on Windows"
][
	base: join what-dir %tmp-safe-path/
	make-dir/deep base/www
	make-dir/deep base/outside
	write base/outside/secret.txt "x"
	write base/www/ok.txt "y"
	call/shell/wait "cd tmp-safe-path/www && ln -s ../outside out && ln -s ok.txt alias.txt"
	root: to-real-file base/www

	foreach test [
		[ (join root %ok.txt) == safe-path root %/ok.txt ]
		;; link inside root is allowed
		[ (join root %alias.txt) == safe-path root %/alias.txt ]
		;; link leading outside root is blocked by default...
		[ none? safe-path root %/out/secret.txt ]
		[ none? safe-path root %/out/ ]
		;; ...unless following is allowed
		[ (join root %out/secret.txt) == safe-path/follow root %/out/secret.txt ]
	][
		print [as-yellow "Assert:" mold/flat test]
		either attempt test [print as-green "OK"][++ fails print as-red "FAILED"]
	]
	call/shell/wait "rm -rf tmp-safe-path"
]


print-hline
print as-yellow "[TEST] HTTPd Escape-HTML"
escape-html: :system/schemes/httpd/Escape-HTML

foreach test [
	[ "a &amp; b" == escape-html "a & b" ]
	[ "&lt;x&gt;" == escape-html "<x>" ]
	[ "&quot;q&quot;" == escape-html {"q"} ]
	[ "&amp;lt;" == escape-html "&lt;" ] ;; no double-unescaping
	[ "a&amp;b" == escape-html %a&b ]
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