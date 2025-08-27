from http.server import SimpleHTTPRequestHandler, HTTPServer
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import threading

REQUESTS = Counter('app_requests_total', 'Total HTTP requests')


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        REQUESTS.inc()
        if self.path == '/metrics':
            # Return Prometheus metrics directly on port 8080
            self.send_response(200)
            self.send_header('Content-Type', CONTENT_TYPE_LATEST)
            self.end_headers()
            self.wfile.write(generate_latest())
            return
        else:
            super().do_GET()


def run_server():
    server = HTTPServer(('0.0.0.0', 8080), Handler)
    print('Starting app server on 0.0.0.0:8080')
    server.serve_forever()


if __name__ == '__main__':
    t = threading.Thread(target=run_server)
    t.start()
    t.join()
