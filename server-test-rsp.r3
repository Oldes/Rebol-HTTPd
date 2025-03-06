Rebol [
	Title:  "Test HTTPd Scheme"
	File:   %server-test-rsp.r3
	Date:    5-Mar-2025
	Author: "Oldes"
	Version: 0.9.0
	Needs:   3.16.0
]

import %httpd.reb

system/options/log/httpd: 4
system/schemes/httpd/set-verbose 4
system/options/quiet: true
? system/options/log/httpd
make-dir %logs/  ;; make sure that there is the directory for logs

serve-http [
	port: 8083
	root: %hosts/app/
	app: context [
		;; some predefined values
		name: "Test RSP Application"
		;; some function
		random-number: does [random 99999]
	]
]

