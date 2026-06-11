#!/usr/bin/env python3
"""Minimal wake service for the sprite.

Any HTTP hit (e.g. a phone bookmark) creates/refreshes a Tasks-API hold so the
sprite stays awake long enough for the long-polling Hermes gateway to drain the
Telegram backlog and reply. This service is PUBLIC: it must never serve files
or expose env/secrets. It only talks to the local sprite API socket.
"""
import http.client
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

API_SOCK = "/.sprite/api.sock"
TASK_NAME = "hermes-active"   # same task the pre_llm_call hook refreshes
TASK_EXPIRE = "5m"
LISTEN_PORT = 8080


class _UnixHTTPConnection(http.client.HTTPConnection):
    """HTTPConnection over the sprite's unix domain socket."""
    def connect(self):
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(API_SOCK)
        self.sock = s


def refresh_hold():
    """PUT the task hold. Returns the API HTTP status code."""
    conn = _UnixHTTPConnection("sprite")
    try:
        conn.request(
            "PUT", "/v1/tasks/" + TASK_NAME,
            body='{"expire":"%s"}' % TASK_EXPIRE,
            headers={"Host": "sprite", "Content-Type": "application/json"},
        )
        resp = conn.getresponse()
        resp.read()
        return resp.status
    finally:
        conn.close()


class WakeHandler(BaseHTTPRequestHandler):
    def _wake(self):
        try:
            ok = 200 <= refresh_hold() < 300
        except Exception:
            ok = False
        self.send_response(200 if ok else 503)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"awake\n" if ok else b"wake-failed\n")

    do_GET = _wake
    do_HEAD = _wake

    def log_message(self, *args):
        return  # stay quiet; no request paths in logs


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", LISTEN_PORT), WakeHandler).serve_forever()
