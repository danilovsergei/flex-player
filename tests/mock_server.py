import http.server
import ssl
import json
import threading
from urllib.parse import urlparse, parse_qs

class MockPlexHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        with open("/app/tests/mock_server_requests.log", "a") as logf:
            logf.write(format % args + "\n")

    def do_GET(self):
        with open("/app/tests/mock_server_requests.log", "a") as logf:
            logf.write("GET " + self.path + "\n")

        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path.startswith("/library/parts/") or path.endswith(".mkv"):
            try:
                import os
                file_size = os.path.getsize('/app/tests/dummy1.mkv')
                self.send_response(200)
                self.send_header('Content-type', 'video/x-matroska')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Connection', 'close')
                self.send_header('Content-Length', str(file_size))
                self.end_headers()
                with open('/app/tests/dummy1.mkv', 'rb') as f_media:
                    self.wfile.write(f_media.read())
            except Exception as e:
                print("Error serving media:", e)
            return

        query = parse_qs(parsed_path.query)
        response_data = {}
        
        if path == "/library/sections":
            response_data = {
                "MediaContainer": {
                    "size": 2,
                    "Directory": [
                        {"type": "movie", "title": "Mock Movies", "key": "1", "uuid": "uuid-movies"},
                        {"type": "show", "title": "Mock Shows", "key": "2", "uuid": "uuid-shows"}
                    ]
                }
            }
        elif path == "/library/recentlyAdded" or path.endswith("/recentlyAdded") or "sort=addedAt:desc" in self.path or "sort=addedAt%3Adesc" in self.path:
            response_data = {
                "MediaContainer": {
                    "size": 4,
                    "Metadata": [
                        {"type": "movie", "title": "Mock Movie Unwatched", "ratingKey": "100", "duration": 50000, "viewOffset": 0, "Media": [{"Part": [{"key": "/library/parts/100/file.mkv"}]}]},
                        {"type": "show", "title": "Mock Show Partially Watched", "ratingKey": "200", "duration": 60000, "viewOffset": 0, "viewedLeafCount": 3, "leafCount": 25, "Media": [{"Part": [{"file": "/app/tests/dummy2.mkv"}]}]},
                        {"type": "show", "title": "Mock Show Watched", "ratingKey": "202", "duration": 60000, "viewOffset": 0, "viewedLeafCount": 25, "leafCount": 25, "Media": [{"Part": [{"file": "/app/tests/dummy2.mkv"}]}]},
                        {"type": "movie", "title": "Mock Movie Watched", "ratingKey": "103", "duration": 50000, "viewOffset": 0, "viewCount": 1, "Media": [{"Part": [{"key": "/library/parts/103/file.mkv"}]}]}
                    ]
                }
            }
        elif path == "/library/onDeck" or path.endswith("/onDeck"):
            response_data = {
                "MediaContainer": {
                    "size": 2,
                    "Metadata": [
                        {"type": "movie", "title": "Mock Movie Deck", "ratingKey": "101", "duration": 60000, "viewOffset": 30000, "Media": [{"Part": [{"file": "/app/tests/dummy2.mkv"}]}]},
                        {"type": "show", "title": "Mock Show Deck", "ratingKey": "201", "duration": 60000, "viewOffset": 30000, "Media": [{"Part": [{"file": "/app/tests/dummy2.mkv"}]}]}
                    ]
                }
            }
        elif path.endswith("/collections"):
            response_data = {
                "MediaContainer": {
                    "size": 1,
                    "Metadata": [
                        {"type": "collection", "title": "Mock Collection", "ratingKey": "300"}
                    ]
                }
            }
        elif "/library/collections/" in path and path.endswith("/children"):
            response_data = {
                "MediaContainer": {
                    "size": 1,
                    "Metadata": [
                        {"type": "movie", "title": "Collection Movie", "ratingKey": "102", "duration": 60000, "viewOffset": 0, "Media": [{"Part": [{"file": "/app/tests/dummy1.mkv"}]}]}
                    ]
                }
            }
        elif "/library/metadata/" in path:
            ratingKey = path.split("/")[-1]
            if ratingKey == "999": # test_38_dropdown_dynamic_width
                response_data = {
                    "MediaContainer": {
                        "Metadata": [{
                            "ratingKey": "999",
                            "title": "Stream Test Movie Width",
                            "viewOffset": 15000,
                            "duration": 50000,
                            "Media": [{
                                "Part": [{
                                    "key": "/library/parts/999/1234/file.mkv",
                                    "file": "/app/tests/dummy1.mkv",
                                    "Stream": [
                                        { "id": 10, "streamType": 1, "codec": "h264", "index": 0 },
                                        { "id": 11, "streamType": 2, "language": "English", "index": 1 },
                                        { "id": 2, "streamType": 2, "language": "Русский", "displayTitle": "Русский (EAC3 5.1)", "extendedDisplayTitle": "Super Long Track Name That Needs Dynamic Resizing To Fit Perfectly (Русский EAC3 5.1)", "title": "Super Long Track Name That Needs Dynamic Resizing To Fit Perfectly", "index": 2 },
                                        { "id": 13, "streamType": 3, "language": "English", "index": 3 },
                                        { "id": 2, "streamType": 3, "language": "Russian", "index": 4 }
                                    ]
                                }]
                            }]
                        }]
                    }
                }
            elif ratingKey == "1": # Generic detail mock
                response_data = {
                    "MediaContainer": {
                        "Metadata": [{
                            "ratingKey": "1",
                            "title": "Mock Detail Title",
                            "duration": 5400000,
                            "viewOffset": 600000,
                            "Genre": [{"tag": "Action"}],
                            "Role": [{"tag": "Actor"}],
                            "Media": [{"Part": [{"key": "/library/parts/103/file.mkv", "file": "/app/tests/dummy1.mkv", "Stream": [{"id":1, "streamType": 1, "codec": "h264"}, {"id":2, "streamType":2, "language": "English", "displayTitle": "English (AAC 5.1)"}]}]}]
                        }]
                    }
                }
            else:
                response_data = {
                    "MediaContainer": {
                        "Metadata": [{
                            "ratingKey": ratingKey,
                            "title": "Mock Title " + ratingKey,
                            "duration": 3600000,
                            "viewOffset": 0,
                            "type": "movie",
                            "Media": [{"Part": [{"key": "/library/parts/103/file.mkv", "file": "/app/tests/dummy1.mkv", "Stream": [{"id":1, "streamType": 1, "codec": "h264"}, {"id":2, "streamType":2, "language": "English", "displayTitle": "English (AAC 5.1)"}]}]}]
                        }]
                    }
                }
        elif path == "/" or path == "/identity":
            response_data = {"MediaContainer": {"machineIdentifier": "mock_machine"}}
        elif path == "/" or path == "/identity":
            response_data = {"MediaContainer": {"machineIdentifier": "mock_machine"}}
        else:
            response_data = {"MediaContainer": {"size": 0, "Metadata": []}}
            
        json_bytes = json.dumps(response_data).encode('utf-8')
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Connection', 'close')
        self.send_header('Content-Length', str(len(json_bytes)))
        self.end_headers()
        
        self.wfile.write(json_bytes)

httpd = http.server.ThreadingHTTPServer(('127.0.0.1', 32400), MockPlexHandler)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(certfile='/app/tests/mock_cert.pem', keyfile='/app/tests/mock_key.pem')
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print("Starting Mock HTTPS Server on 127.0.0.1:32400")
httpd.serve_forever()
