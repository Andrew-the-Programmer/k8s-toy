import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import override


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/healthz":
            self._send({"status": "ok"})
            return
        self._send(
            {
                "message": "bad message",
                "pod": os.environ.get("POD_NAME", "unknown"),
                "version": os.environ.get("VERSION", "dev"),
            }
        )

    def _send(self, body: dict[str, str]) -> None:
        payload = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        _ = self.wfile.write(payload)

    @override
    def log_message(self, format: str, *args: object) -> None:
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
