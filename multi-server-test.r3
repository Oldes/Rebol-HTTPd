Rebol [
	Title:  "Test multiple HTTP servers"
	File:   %multi-server-test.r3
	Date:    14-Dec-2023
	Author: "Oldes"
	Version: 0.9.0
]

import %httpd.reb

system/options/log/httpd: 4 ; for verbose output
system/options/quiet: false

make-dir %logs/  ;; make sure that there is the directory for logs

;; Starting 2 servers listening on different ports...
srv1: serve-http/no-wait [port: 8081 root: %hosts/test/]
srv2: serve-http/no-wait [port: 8082 root: %logs/]
;; Handle checking both server clients
forever [
	p: wait [srv1 srv2 15]
	;; In regular intervals check clients of both servers and close unused connections
	srv1/scheme/Check-Clients srv1
	srv2/scheme/Check-Clients srv2
]
