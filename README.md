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

1. Minimal server setup for serving content of the current directory:
```rebol
http-server/config 8888 [root: current-dir]
```

2. Minimal server setup for in-memory generated content (root-less)
```rebol
http-server/actor 8888 [
    ;- Server's actor functions                                                                  
    On-Header: func [ctx][
        ;; Just respond with data we recieved... 
        ctx/out/status: 200
        ctx/out/header/Content-Type: "text/plain; charset=UTF-8"
        ctx/out/content: mold ctx/inp
    ]
]
```

3. For more complete server setup check [server-test.r3](https://github.com/Oldes/Rebol-HTTPd/blob/master/server-test.r3) script.

## Setup a service on Linux

The best way to start a Linux service that persists through a boot is to create a systemd service. Here are the steps to create a systemd service:

1. Create a new service file in the `/etc/systemd/system` directory using a text editor. For example, create a file named `mywebserver.service`.

2. Inside the service file, define the service by providing a `[Unit]` section with a `Description` and `After` directive, and a `[Service]` section with the `ExecStart` directive. For example:
```makefile
[Unit]
Description=My Rebol Web Server
After=network.target

[Service]
ExecStart=/usr/local/bin/rebol3 -qs /path/to/server/script.r3
Restart=always
User=rebol
Group=www-data

[Install]
WantedBy=multi-user.target
```

3. Save the service file and reload the systemd daemon to pick up the new service:
```
sudo systemctl daemon-reload
```

4. Enable the service to start at boot:
```
sudo systemctl enable mywebserver.service
```

5. Start the service:
```
sudo systemctl start mywebserver.service
```

The service should now be running and will start automatically on boot. You can use the `systemctl` command to manage the service, such as to stop or restart it:
```
sudo systemctl stop mywebserver.service
sudo systemctl restart mywebserver.service
```
Or to get a status of the service:
```
sudo systemctl status mywebserver.service
```
