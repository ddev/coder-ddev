#!/usr/bin/env python3
"""Simple HTTP server that logs all incoming headers."""

import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 80

class HeaderLogger(BaseHTTPRequestHandler):
    def do_GET(self):
        print(f"\n--- Request at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ---")
        print(f"Method: {self.command}")
        print(f"Path: {self.path}")
        print("\nHeaders:")
        for header, value in self.headers.items():
            # Highlight the Host header
            if header.lower() == 'host':
                print(f"  >>> {header}: {value} <<<")
            else:
                print(f"  {header}: {value}")
        print("\n" + "="*60 + "\n")

        # Send response
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        html = """<!DOCTYPE html>
<html>
<head><title>Coder Header Test</title></head>
<body>
<h1>✓ Coder Header Test - Success!</h1>
<p>Headers received and logged in the terminal.</p>
<p><strong>Check the terminal where you ran the script to see the headers.</strong></p>
<p>Look for the <code>Host:</code> header - this tells you what hostname Coder is forwarding.</p>
<p>You can close this tab now.</p>
</body>
</html>"""
        self.wfile.write(html.encode())

    def log_message(self, format, *args):
        # Suppress default logging
        pass

if __name__ == '__main__':
    try:
        with HTTPServer(('0.0.0.0', PORT), HeaderLogger) as server:
            print(f"Listening on 0.0.0.0:{PORT}")
            print("Waiting for connections from Coder...")
            print("(Press Ctrl+C to stop)\n")
            server.serve_forever()
    except PermissionError:
        print(f"\nERROR: Permission denied to bind to port {PORT}")
        print("Ports below 1024 require root privileges.")
        print("Try running with sudo:")
        print(f"  sudo python3 {sys.argv[0]} {PORT}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nStopped by user")
        sys.exit(0)
    except Exception as e:
        print(f"\nERROR: {e}")
        sys.exit(1)
