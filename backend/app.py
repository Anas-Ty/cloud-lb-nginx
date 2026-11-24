from http.server import BaseHTTPRequestHandler, HTTPServer
import os
import socket
import time

SERVER_NAME = os.environ.get("SERVER_NAME", socket.gethostname())
SERVER_IP = socket.gethostbyname(socket.gethostname())

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/slow":
            time.sleep(2)
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        response = f"Handled by: {SERVER_NAME} | Container IP: {SERVER_IP} | Path: {self.path}\n"
        self.wfile.write(response.encode())

if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 5000), Handler).serve_forever()
