from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/healthz", "/readyz"):
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(b"ok\n")
            return

        self.send_error(404, "Not found")

    def log_message(self, format, *args):
        return


HTTPServer(("0.0.0.0", 5000), Handler).serve_forever()
