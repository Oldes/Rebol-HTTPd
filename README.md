[![rebol-httpd](https://github.com/user-attachments/assets/2953d428-2100-4920-a68b-74831a6b9741)](https://github.com/oldes/Rebol-HTTPd)

[![Rebol-HTTPd CI](https://github.com/Oldes/Rebol-HTTPd/actions/workflows/main.yml/badge.svg)](https://github.com/Oldes/Rebol-HTTPd/actions/workflows/main.yml)
[![Zulip](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://rebol.zulipchat.com/#narrow/stream/371632-Rebol.2FHTTPd)

# Rebol/HTTPd

A small, dependency-free web server for [Rebol3](https://github.com/Oldes/Rebol3).

Serve a directory with one line, generate responses from Rebol code, render
Rebol Server Pages, or talk to a browser over WebSockets. It is good for local
development, small services, and short-lived servers (like an OAuth2 callback).

## Features

* **Static files:** GET, HEAD and POST, with large files streamed in chunks and `304 Not Modified` support
* **Custom handlers:** override any step of request processing with simple _actor_ functions
* **Request bodies:** form-urlencoded, multipart, JSON and text bodies are decoded for you; chunked uploads and `Expect: 100-continue` are supported
* **Connections:** keep-alive (HTTP/1.1 and HTTP/1.0), pipelined requests
* **RSP (Rebol Server Pages):** HTML templates with embedded Rebol code
* **WebSockets:** text and binary messages, automatic ping/pong
* **Directory listing** (optional)
* **Logging:** access and error logs in Common Log Format
* **Safe by default:** requests can't escape the root directory, request sizes are limited
* **Stop from a client:** a handler can stop the server and return a value to the script that started it

## Quick start

Serve the current directory on port `8000`:
```rebol
serve-http 8000
```

Serve a specific directory (on the default port `8000`):
```rebol
serve-http %hosts/test/
```

Generate responses in code, without any directory (root-less):
```rebol
serve-http [port: 8000 actor: [
    On-Get: func [ctx][
        ;; just respond with what we received...
        ctx/out/content: mold ctx/inp
    ]
    On-Post: func [ctx][
        ;; respond with the decoded body, including a custom header...
        ctx/out/header/X-Response: "Just a custom message in the header."
        ctx/out/content: mold ctx/inp/content
    ]
]]
```

`serve-http` waits and handles requests until the server is stopped. Use
`serve-http/no-wait` to get the server port back and run your own `wait` loop,
for example to run several servers at once (see [multi-server-test.r3](multi-server-test.r3)).

## Configuration

Pass a block (or map, or object) to `serve-http`. Everything is optional:

```rebol
serve-http [
    port: 8080
    root: %www/
    keep-alive: [30 100]           ;; timeout in seconds, max requests per connection
    log-access: %logs/access.log
    log-errors: %logs/errors.log
    actor: [...]                   ;; your handlers, see below
]
```

| Option | Default | Meaning |
|---|---|---|
| `port` | `8000` | Port to listen on |
| `root` | `none` | Directory to serve files from. Without it, all content comes from your handlers |
| `index` | `[%index.html %index.htm]` | Files used when a directory is requested |
| `list-dir?` | `true` | List directory content when there is no index file |
| `keep-alive` | `true` | `true` (15 s, 100 requests), `[timeout max-requests]`, or `false` |
| `server-name` | `"Rebol3-HTTPd"` | Value of the `Server` response header |
| `trust-ips` | `[127.0.0.1]` | Proxies whose `X-Real-IP` header is trusted in logs |
| `follow-symlinks?` | `false` | Allow symbolic links pointing outside of `root` |
| `max-header-size` | `32768` | Max request header size in bytes (`431` above it), `none` = unlimited |
| `max-content-length` | `10485760` | Max request body size in bytes (`413` above it), `none` = unlimited |
| `max-websocket-frame` | `1048576` | Max WebSocket frame size in bytes (connection closed with `1009` above it), `none` = unlimited |
| `log-access` | `none` | File for the access log |
| `log-errors` | `none` | File for requests which ended with an error status |
| `app` | `none` | An object; enables RSP pages (see below) |

How much the server prints is set by `system/schemes/httpd/set-verbose` (`0` = errors only, up to `3` = debug).

## Actors (request handlers)

Actors are functions called at each step of processing a request. You only
need to define the ones you want to change; the rest keep their default
behavior. Each server has its own set, so two servers in one script don't
affect each other.

| Actor | When it is called |
|---|---|
| `On-Accept` | A new connection arrives. Return `false` to refuse it (for example, by IP) |
| `On-Header` | The request header is parsed. Set `ctx/out/status` to answer right away (redirects, simple endpoints) |
| `On-Get` | GET or HEAD request |
| `On-Post` | POST request, with the body already decoded in `ctx/inp/content` |
| `On-Read-Post` | POST request with the raw body, before decoding |
| `On-Read` | Any request; override it to support other methods (PUT, DELETE...) |
| `On-List-Dir` | A directory without an index file is requested |
| `On-Not-Found` | The requested file doesn't exist; good place for custom 404 pages or in-memory files |
| `On-Read-Websocket` | A WebSocket message arrives |
| `On-Close-Websocket` | The client closes a WebSocket connection |

Every actor gets `ctx`, the request context:

* `ctx/inp` holds the request: `method`, `target` (`file`, `values` from the query string, `original`), `header`, `content`
* `ctx/out` holds the response: set `status`, `header/...` and `content`
* `ctx/config` holds the server configuration
* `ctx/remote-ip` is the client's address

For example, a redirect and a tiny API endpoint:
```rebol
On-Header: func [ctx][
    switch ctx/inp/target/file [
        %/old-page [
            ctx/out/status: 301
            ctx/out/header/Location: %/new-page
        ]
        %/ip [
            ctx/out/status: 200
            ctx/out/header/Content-Type: "text/plain"
            ctx/out/content: form ctx/remote-ip
        ]
    ]
]
```

### Stopping the server from a request

Set `ctx/done?` to any value. The response is sent, all connections are
closed, and `serve-http` returns that value. Handy for an OAuth2 redirect
target:
```rebol
code: serve-http [port: 8000 actor: [
    On-Get: func [ctx][
        ctx/out/content: "You can close this window now."
        ctx/done?: select ctx/inp/target/values 'code
    ]
]]
```

For a more complete setup, see [server-test.r3](server-test.r3).

## RSP (Rebol Server Pages)

When `app` is given, files ending with `.rsp` are processed as templates:

```rebol
serve-http [
    port: 8000
    root: %www/
    app: context [
        name: "My App"
        hits: 0
    ]
]
```

Inside a page:

| Tag | Meaning |
|---|---|
| `<% code %>` | Runs Rebol code. Use `print`, `prin` or `probe` to write into the page |
| `<%= expr %>` | Inserts the result of an expression |
| `<%@ %file.html %>` | Inserts a file as it is |

```html
<h1><%= app/name %></h1>
<% app/hits: app/hits + 1 %>
<p>Visits: <%= app/hits %></p>
<% include %parts/footer.rsp %>
```

* Values from `app` can be read directly (`name`). To change them, use a path: `app/hits: ...`
* Variables you set in a page are local to the request; they don't leak into other requests
* `include` processes another RSP file, sharing the page's variables
* The request is available as `ctx` (for example `ctx/inp/target/values`)

See [server-test-rsp.r3](server-test-rsp.r3) and the pages in `hosts/app/`.

## WebSockets

Accept the upgrade in `On-Header` and answer messages in `On-Read-Websocket`.
Whatever you put into `ctx/out/content` is sent back: a string as a text
message, a binary as a binary message. Pings are answered automatically.

```rebol
serve-http [port: 8000 actor: [
    On-Header: func [ctx][
        if ctx/inp/target/file = %/echo [
            system/schemes/httpd/actor/WS-handshake ctx
        ]
    ]
    On-Read-Websocket: func [ctx final? opcode][
        ;; opcode 1 = text, 2 = binary
        if opcode = 1 [ctx/out/content: to string! ctx/inp/content]
    ]
]]
```

## Security notes

* Requested paths are checked, so `..`, encoded `%2e%2e` or backslashes can't reach files outside `root`
* Symbolic links leading outside `root` are blocked unless `follow-symlinks?` is set
* Request headers and bodies are size-limited (see `max-header-size` and `max-content-length`)
* Directory listings escape file names
* Code in RSP pages and your actors runs with full rights; only serve pages you wrote

## Running the tests

```
rebol3 httpd-test.r3       ;; unit tests of internal functions
rebol3 client-test.r3      ;; starts server-test.r3 and sends real requests
rebol3 client-test-rsp.r3  ;; the same for RSP pages
```

## Setup a service on Linux

The best way to start a Linux service that persists through a reboot is to create a systemd service:

1. Create a new service file in `/etc/systemd/system`, for example `mywebserver.service`:
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

2. Reload systemd, enable the service to start at boot, and start it:
```
sudo systemctl daemon-reload
sudo systemctl enable mywebserver.service
sudo systemctl start mywebserver.service
```

3. Manage it with `systemctl`:
```
sudo systemctl status mywebserver.service
sudo systemctl restart mywebserver.service
sudo systemctl stop mywebserver.service
```

## TODO

* Serving multiple domains using the `Host` header
* Built-in support for other methods (PUT, DELETE, OPTIONS...)
* Better error handling

## History

* 04-Nov-2009 Andreas Bolka: [A Tiny HTTP Server](https://github.com/earl/rebol3/blob/master/scripts/shttpd.r)
* 04-Jan-2017 Christopher Ross-Gill: [Adaptation to Scheme](https://gist.github.com/rgchris/73510e7d643eb0a6b9fa69b849cd9880)
* 01-Apr-2019 Oldes: Rewritten to be usable in real life situations
* 10-May-2020 Oldes: Directory listing, logging and multipart POST processing
* 02-Jul-2020 Oldes: Stopping the server from a client and returning data (useful for OAuth2)
* 06-Dec-2022 Oldes: Minimal support for WebSocket connections
* 09-Jan-2023 Oldes: New home on [GitHub](https://github.com/Oldes/Rebol-HTTPd)
* 09-May-2023 Oldes: Root-less configuration (default)
* 14-Dec-2023 Oldes: `http-server` deprecated in favor of `serve-http`
* 06-Mar-2025 Oldes: RSP (Rebol Server Pages)
* 21-Oct-2026 Oldes: Security and protocol review: path checks, request limits, chunked uploads, `100-continue`, pipelining, HTTP/1.0 keep-alive, WebSocket ping and binary frames, per-server actors, request-local RSP variables
* See also: https://github.com/Oldes/Rebol-HTTPd/commits/master/

Based on '[A Tiny HTTP Server](https://github.com/earl/rebol3/blob/master/scripts/shttpd.r)' by Andreas Bolka and Christopher Ross-Gill's [Adaptation to Scheme](https://gist.github.com/rgchris/73510e7d643eb0a6b9fa69b849cd9880).