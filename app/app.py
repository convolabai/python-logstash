import http.server
import socketserver

print('Hello Python! - This is default scripts \"/app/app.py\"')

PORT = 8089
Handler = http.server.SimpleHTTPRequestHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print("serving at port", PORT)
    httpd.serve_forever()