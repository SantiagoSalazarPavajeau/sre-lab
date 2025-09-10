from http.server import SimpleHTTPRequestHandler, HTTPServer
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import os
import random
import threading
import time
import sys

APP_NAME = os.getenv("APP_NAME", "slack")
FAILURE_MODE = os.getenv("FAILURE_MODE", "none")
FAILURE_RATE = float(os.getenv("FAILURE_RATE", "0.0"))
LATENCY_MS = int(os.getenv("LATENCY_MS", "0"))

REQUESTS = Counter('app_requests_total', 'Total HTTP requests', ['app', 'path'])
ERRORS = Counter('app_request_errors_total', 'HTTP error responses', ['app', 'path'])
LATENCY = Histogram('app_request_duration_seconds', 'Request latency', ['app', 'path'])


def maybe_fail(path: str):
    global FAILURE_MODE, FAILURE_RATE, LATENCY_MS
    if FAILURE_MODE == 'crash':
        print(f"[{APP_NAME}] crashing on purpose", file=sys.stderr)
        sys.stderr.flush()
        os._exit(1)
    if FAILURE_MODE == 'latency' and random.random() < FAILURE_RATE:
        time.sleep(max(0, LATENCY_MS) / 1000.0)
    elif FAILURE_MODE == 'error' and random.random() < FAILURE_RATE:
        raise RuntimeError("Injected failure")


class Handler(SimpleHTTPRequestHandler):
    def _send(self, code: int, body: str, content_type: str = 'text/plain'):
        self.send_response(code)
        self.send_header('Content-Type', content_type)
        self.end_headers()
        if isinstance(body, str):
            body = body.encode('utf-8')
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split('?')[0]
        REQUESTS.labels(APP_NAME, path).inc()
        if path == '/metrics':
            self._send(200, generate_latest(), CONTENT_TYPE_LATEST)
            return
        start = time.time()
        try:
            maybe_fail(path)
            if path in ('/', '/index.html'):
                self._send(200, f"hello from {APP_NAME}\n")
            elif path == '/healthz':
                self._send(200, 'ok')
            elif path == '/readyz':
                self._send(200, 'ready')
            else:
                return super().do_GET()
        except Exception as e:
            ERRORS.labels(APP_NAME, path).inc()
            self._send(500, f"error: {e}\n")
        finally:
            LATENCY.labels(APP_NAME, path).observe(time.time() - start)


def run_server():
    server = HTTPServer(('0.0.0.0', 8080), Handler)
    print(f'Starting {APP_NAME} server on 0.0.0.0:8080')
    server.serve_forever()


if __name__ == '__main__':
    t = threading.Thread(target=run_server)
    t.start()
    t.join()
