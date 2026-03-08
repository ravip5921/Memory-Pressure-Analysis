from http.server import BaseHTTPRequestHandler, HTTPServer
import time

HOST = "0.0.0.0"
PORT = 8080

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        start = time.time()

        # Small amount of work per request
        data = [i for i in range(10000)]
        total = sum(data)

        elapsed = time.time() - start
        response = f"OK total={total} elapsed={elapsed:.6f}s\n"

        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        self.wfile.write(response.encode())

    def log_message(self, format, *args):
        return  # suppress default console spam

if __name__ == "__main__":
    print(f"Starting server on {HOST}:{PORT}")
    server = HTTPServer((HOST, PORT), Handler)
    server.serve_forever()