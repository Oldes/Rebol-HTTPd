[![Rebol-HTTPd CI](https://github.com/Oldes/Rebol-HTTPd/actions/workflows/main.yml/badge.svg)](https://github.com/Oldes/Rebol-HTTPd/actions/workflows/main.yml)
[![Zulip](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://rebol.zulipchat.com/#narrow/stream/371632-Rebol.2FHTTPd)

# Rebol/HTTPd

A Webserver Scheme for [Rebol3](https://github.com/Oldes/Rebol3).
Based on '[A Tiny HTTP Server](https://github.com/earl/rebol3/blob/master/scripts/shttpd.r)' by Andreas Bolka and Christopher Ross-Gill's [Adaptation to Scheme](https://gist.github.com/rgchris/73510e7d643eb0a6b9fa69b849cd9880) made as a part of Oldes' Rebol3 sources as a more feature complete web server. Now having its own home here to better track future improvements.

## Features:

 * handle basic POST, GET and HEAD methods
 * send large files in chunks (using a file port)
 * using _actors_ for main actions which may be customized
 * implemented `keep-alive` behaviour
 * sends `Not modified` response if file was not modified in given time
 * client can stop the server (useful for OAuth2 as a short-living server)

## TODO:

 * support for multidomain serving using `Host` header field
 * add support for other methods - PUT, DELETE, TRACE, CONNECT, OPTIONS?
 * better error handling
 * test in real life

## History:
 * 04-Nov-2009 Andreas Bolka: [A Tiny HTTP Server](https://github.com/earl/rebol3/blob/master/scripts/shttpd.r) 
 * 04-Jan-2017 Christopher Ross-Gill: [Adaptation to Scheme](https://gist.github.com/rgchris/73510e7d643eb0a6b9fa69b849cd9880)
 * 01-Apr-2019 Oldes: Rewritten to be usable in real life situations
 * 10-May-2020 Oldes: Implemented directory listing, logging and multipart POST processing
 * 02-Jul-2020 Oldes: Added possibility to stop server and return data back to client (useful for OAuth2)
 * 06-Dec-2022 Oldes: Added minimal support for WebSocket connections
 * 09-Jan-2023 Oldes: Setting up a new home for the project on [Github](https://github.com/Oldes/Rebol-HTTPd)

## Usage:

Check [%server-test.r3](https://github.com/Oldes/Rebol-HTTPd/blob/master/server-test.r3) script how to start a simple server}
