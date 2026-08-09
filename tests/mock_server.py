import http.server
import ssl
import json
import sys
import threading
from urllib.parse import urlparse, parse_qs


COLLECTIONS = {
    "300": {"title": "Mock Collection", "items": ["102"], "smart": False, "content": ""},
    "301": {"title": "Smart Mock Collection", "items": [], "smart": True, "content": "server://1234/com.plexapp.plugins.library/library/sections/1/all?genre=action&year=2024&or=1"}
}
NEXT_COLLECTION_ID = 301

class MockPlexHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        with open("/app/tests/mock_server_requests.log", "a") as logf:
            logf.write(format % args + "\n")

    def do_PUT(self):
        global NEXT_COLLECTION_ID
        with open("/app/tests/mock_server_requests.log", "a") as logf:
            logf.write("PUT " + self.path + "\n")
            
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        query = parse_qs(parsed_path.query)

        if "/library/collections/" in path and not path.endswith("/children"):
            cid = path.split("/")[-1]
            uri = query.get('uri', [''])[0]
            if cid in COLLECTIONS and uri:
                COLLECTIONS[cid]["content"] = uri
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Connection', 'close')
            json_bytes = b"{}"
            self.send_header('Content-Length', str(len(json_bytes)))
            self.end_headers()
            self.wfile.write(json_bytes)
            return
            
        if path.startswith("/library/sections/") and path.endswith("/all"):
            col_add = query.get('collection', [''])[0]
            col_tag = query.get('collection[0].tag.tag', [''])[0]
            ids_str = query.get('id', [''])[0]
            ids = ids_str.split(',') if ids_str else []

            if col_tag:
                found_id = None
                for cid, c in COLLECTIONS.items():
                    if c["title"] == col_tag:
                        found_id = cid
                        break
                if not found_id:
                    found_id = str(NEXT_COLLECTION_ID)
                    COLLECTIONS[found_id] = {"title": col_tag, "items": []}
                    NEXT_COLLECTION_ID += 1
                
                for item in ids:
                    if item not in COLLECTIONS[found_id]["items"]:
                        COLLECTIONS[found_id]["items"].append(item)
            elif col_add:
                found_id = col_add
                if found_id in COLLECTIONS:
                    for item in ids:
                        if item not in COLLECTIONS[found_id]["items"]:
                            COLLECTIONS[found_id]["items"].append(item)

        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Connection', 'close')
        json_bytes = b"{}"
        self.send_header('Content-Length', str(len(json_bytes)))
        self.end_headers()
        self.wfile.write(json_bytes)

    def do_POST(self):
        global NEXT_COLLECTION_ID
        with open("/app/tests/mock_server_requests.log", "a") as logf:
            logf.write("POST " + self.path + "\n")
            
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        query = parse_qs(parsed_path.query)

        if path.startswith("/library/collections"):
            col_title = query.get('title', [''])[0]
            if col_title:
                found_id = str(NEXT_COLLECTION_ID)
                COLLECTIONS[found_id] = {"title": col_title, "items": []}
                NEXT_COLLECTION_ID += 1

        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Connection', 'close')
        json_bytes = b"{}"
        self.send_header('Content-Length', str(len(json_bytes)))
        self.end_headers()
        self.wfile.write(json_bytes)

    def do_DELETE(self):
        with open("/app/tests/mock_server_requests.log", "a") as logf:
            logf.write("DELETE " + self.path + "\n")
            
        parsed_path = urlparse(self.path)
        path = parsed_path.path

        if path.startswith("/library/collections/"):
            col_id = path.split("/")[3]
            if col_id in COLLECTIONS:
                del COLLECTIONS[col_id]

        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Connection', 'close')
        json_bytes = b"{}"
        self.send_header('Content-Length', str(len(json_bytes)))
        self.end_headers()
        self.wfile.write(json_bytes)

    def do_GET(self):
        with open("/app/tests/mock_server_requests.log", "a") as logf:
            logf.write("GET " + self.path + "\n")

        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path.startswith("/library/parts/") or path.endswith(".mkv") or path.endswith(".mp3"):
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
        filter_types = ["/genre", "/year", "/decade", "/contentRating", "/collection", "/director", "/actor", "/writer", "/producer", "/country", "/studio", "/resolution", "/videoCodec", "/audioCodec", "/subtitleCodec", "/audioLayout", "/audioLanguage", "/subtitleLanguage", "/editionTitle", "/label"]
        matched_filter = next((f for f in filter_types if f in path and not path.endswith("/collections")), None)
        
        if matched_filter:
            ftype = matched_filter.strip('/')
            if ftype == "genre":
                response_data = {"MediaContainer": {"size": 2, "Directory": [{"fastKey": "action", "title": "Action"}, {"fastKey": "comedy", "title": "Comedy"}]}}
            elif ftype == "year":
                response_data = {"MediaContainer": {"size": 1, "Directory": [{"fastKey": "2024", "title": "2024"}]}}
            else:
                response_data = {"MediaContainer": {"size": 2, "Directory": [{"fastKey": "val1", "title": ftype.capitalize() + " 1"}, {"fastKey": "val2", "title": ftype.capitalize() + " 2"}]}}
        elif path == "/library/sections":
            response_data = {
                "MediaContainer": {
                    "size": 3,
                    "Directory": [
                        {"type": "movie", "title": "Mock Movies", "key": "1", "uuid": "uuid-movies"},
                        {"type": "show", "title": "Mock Shows", "key": "2", "uuid": "uuid-shows"},
                        {"type": "artist", "title": "Mock Music", "key": "3", "uuid": "uuid-music"}
                    ]
                }
            }
        elif path == "/library/recentlyAdded" or path.endswith("/recentlyAdded") or "sort=addedAt:desc" in self.path or "sort=addedAt%3Adesc" in self.path or "sort=lastViewedAt:desc" in self.path or "sort=lastViewedAt%3Adesc" in self.path:
            if "type=8" in self.path:
                response_data = {
                    "MediaContainer": {
                        "size": 1,
                        "Metadata": [
                            {"type": "artist", "title": "Mock Artist", "ratingKey": "ar1", "duration": 50000, "viewOffset": 0}
                        ]
                    }
                }
            elif "type=9" in self.path:
                response_data = {
                    "MediaContainer": {
                        "size": 1,
                        "Metadata": [
                            {"type": "album", "title": "Mock Album", "ratingKey": "al1", "duration": 50000, "viewOffset": 0, "parentTitle": "Mock Artist"}
                        ]
                    }
                }
            elif any(query.get(f, [''])[0] == '1' for f in ['unwatched', 'inProgress', 'hdr', 'dovi', 'atmos', 'unmatched', 'duplicate']):
                response_data = {
                    "MediaContainer": {
                        "size": 1,
                        "Metadata": [
                            {"type": "movie", "title": "Mock Boolean Filtered", "ratingKey": "910", "duration": 50000, "viewOffset": 0, "Media": [{"Part": [{"key": "/library/parts/910/file.mkv"}]}]}
                        ]
                    }
                }
            elif query.get('genre', [''])[0] == 'action':
                response_data = {
                    "MediaContainer": {
                        "size": 1,
                        "Metadata": [
                            {"type": "movie", "title": "Mock Movie Action", "ratingKey": "901", "duration": 50000, "viewOffset": 0, "Media": [{"Part": [{"key": "/library/parts/901/file.mkv"}]}]}
                        ]
                    }
                }
            elif query.get('title', [''])[0] == 'Matrix' or query.get('year>>', [''])[0] == '2000':
                response_data = {
                    "MediaContainer": {
                        "size": 1,
                        "Metadata": [
                            {"type": "movie", "title": "Advanced Mock Result", "ratingKey": "905", "duration": 50000, "viewOffset": 0, "Media": [{"Part": [{"key": "/library/parts/905/file.mkv"}]}]}
                        ]
                    }
                }
            elif query.get('or', [''])[0] == '1':
                response_data = {
                    "MediaContainer": {
                        "size": 2,
                        "Metadata": [
                            {"type": "movie", "title": "OR Match 1", "ratingKey": "908", "duration": 50000, "viewOffset": 0, "Media": [{"Part": [{"key": "/library/parts/908/file.mkv"}]}]},
                            {"type": "movie", "title": "OR Match 2", "ratingKey": "909", "duration": 50000, "viewOffset": 0, "Media": [{"Part": [{"key": "/library/parts/909/file.mkv"}]}]}
                        ]
                    }
                }
            elif any(v[0] in ['val1', 'val2', '2024', 'action'] for k, v in query.items()):
                response_data = {
                    "MediaContainer": {
                        "size": 1,
                        "Metadata": [
                            {"type": "movie", "title": "Mock Movie Dynamic Filtered", "ratingKey": "902", "duration": 50000, "viewOffset": 0, "Media": [{"Part": [{"key": "/library/parts/902/file.mkv"}]}]}
                        ]
                    }
                }
            elif "/sections/4/" in self.path:
                response_data = {
                    "MediaContainer": {
                        "size": 4,
                        "Metadata": [
                            {"type": "show", "title": "Mock Show 1", "ratingKey": "200", "duration": 60000, "viewOffset": 0, "viewedLeafCount": 3, "leafCount": 25, "Media": [{"Part": [{"file": "/app/tests/dummy2.mkv"}]}]},
                            {"type": "show", "title": "Mock Show 2", "ratingKey": "201", "duration": 60000, "viewOffset": 0, "viewedLeafCount": 25, "leafCount": 25, "Media": [{"Part": [{"file": "/app/tests/dummy2.mkv"}]}]},
                            {"type": "show", "title": "Mock Show 3", "ratingKey": "202", "duration": 60000, "viewOffset": 0, "viewedLeafCount": 25, "leafCount": 25, "Media": [{"Part": [{"file": "/app/tests/dummy2.mkv"}]}]},
                            {"type": "show", "title": "Mock Show 4", "ratingKey": "203", "duration": 60000, "viewOffset": 0, "viewedLeafCount": 25, "leafCount": 25, "Media": [{"Part": [{"file": "/app/tests/dummy2.mkv"}]}]}
                        ]
                    }
                }
            else:
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
        elif "/folder" in path:
            # Check for parent query
            import urllib.parse
            qs = urllib.parse.parse_qs(parsed_path.query)
            parent = qs.get("parent", [None])[0]
            
            if parent == "500":
                response_data = {
                    "MediaContainer": {
                        "size": 2,
                        "Metadata": [
                            { "ratingKey": "501", "title": "Album X", "type": "folder" },
                            { "ratingKey": "601", "title": "Track 2", "type": "track", "duration": 180000, "Media": [{"Part": [{"file": "/media/track2.mp3"}]}] }
                        ]
                    }
                }
            elif parent == "501":
                response_data = {
                    "MediaContainer": {
                        "size": 2,
                        "Metadata": [
                            { "ratingKey": "602", "title": "Track 3", "type": "track", "duration": 180000, "Media": [{"Part": [{"file": "/media/track3.mp3"}]}] },
                            { "ratingKey": "603", "title": "Track 4", "type": "track", "duration": 180000, "Media": [{"Part": [{"file": "/media/track4.mp3"}]}] }
                        ]
                    }
                }
            else:
                response_data = {
                    "MediaContainer": {
                        "size": 2,
                        "Metadata": [
                            { "ratingKey": "500", "title": "Artist A", "type": "folder" },
                            { "ratingKey": "600", "title": "Track 1", "parentTitle": "Mock Album", "grandparentTitle": "Mock Artist", "type": "track", "duration": 180000, "Media": [{"Part": [{"file": "/media/track1.mp3"}]}] },
                            { "ratingKey": "604", "title": "", "type": "track", "duration": 180000, "Media": [{"Part": [{"file": "/export/Storage/Music/punk/Fallback Artist/2010 - Fallback Album!/01 - Track Fallback.mp3"}]}] }
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
        elif path == "/playlists":
            if self.command == "POST":
                # Mock creating a playlist
                response_data = {
                    "MediaContainer": {
                        "size": 1,
                        "Metadata": [
                            { "ratingKey": "p99", "title": "Mock Created Playlist", "playlistType": "audio", "leafCount": 1 }
                        ]
                    }
                }
            else:
                response_data = {
                    "MediaContainer": {
                        "size": 5,
                        "Metadata": [
                            { "ratingKey": "p1", "title": "Chill Vibes", "playlistType": "audio", "leafCount": 15, "smart": False },
                            { "ratingKey": "p2", "title": "Workout Mix", "playlistType": "audio", "leafCount": 42, "smart": True },
                            { "ratingKey": "p3", "title": "Video Playlist", "playlistType": "video", "leafCount": 5, "smart": False },
                            { "ratingKey": "p4", "title": "Ambient Sounds", "playlistType": "audio", "leafCount": 10, "smart": False },
                            { "ratingKey": "p5", "title": "Party Time", "playlistType": "audio", "leafCount": 50, "smart": False },
                            { "ratingKey": "p6", "title": "Classical Focus", "playlistType": "audio", "leafCount": 20, "smart": False }
                        ]
                    }
                }
        elif path.startswith("/playlists/") and path.endswith("/items") and self.command in ["PUT", "DELETE"]:
            response_data = {"MediaContainer": {"size": 1, "Metadata": [{"ratingKey": "p1"}]}}
        elif path.startswith("/playlists/") and path.endswith("/items"):
            response_data = {
                "MediaContainer": {
                    "size": 2,
                    "Metadata": [
                        { "ratingKey": "t1", "title": "Playlist Track 1", "parentTitle": "Album 1", "grandparentTitle": "Artist 1", "type": "track", "duration": 150000, "Media": [{"Part": [{"file": "/media/pt1.mp3"}]}] },
                        { "ratingKey": "t2", "title": "Playlist Track 2", "parentTitle": "Album 2", "grandparentTitle": "Artist 2", "type": "track", "duration": 180000, "Media": [{"Part": [{"file": "/media/pt2.mp3"}]}] }
                    ]
                }
            }
        elif path.endswith("/collections"):
            response_data = {
                "MediaContainer": {
                    "size": len(COLLECTIONS),
                    "Metadata": [{"ratingKey": k, "title": v["title"], "type": "collection", "smart": v.get("smart", False), "content": v.get("content", "")} for k, v in COLLECTIONS.items()]
                }
            }
        elif "/library/collections/" in path and path.endswith("/children"):
            cid = path.split("/")[3]
            if cid in COLLECTIONS:
                items = []
                for item_id in COLLECTIONS[cid]["items"]:
                    items.append({"type": "movie", "title": "Collection Movie " + item_id, "ratingKey": item_id, "duration": 60000, "viewOffset": 0, "Media": [{"Part": [{"file": "/app/tests/dummy1.mkv"}]}]})
                response_data = {
                    "MediaContainer": {
                        "size": len(items),
                        "Metadata": items
                    }
                }
            else:
                response_data = {"MediaContainer": {"size": 0, "Metadata": []}}

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
            elif ratingKey == "ar1":
                response_data = {
                    "MediaContainer": {
                        "Metadata": [{
                            "ratingKey": "ar1",
                            "title": "Mock Artist",
                            "summary": "This is a mock artist summary.",
                            "type": "artist",
                            "rating": 8.5,
                            "Country": [{"tag": "Finland"}],
                            "Style": [{"tag": "Symphonic Metal"}, {"tag": "Power Metal"}]
                        }]
                    }
                }
            elif ratingKey == "al1":
                response_data = {
                    "MediaContainer": {
                        "Metadata": [{
                            "ratingKey": "al1",
                            "parentRatingKey": "ar1",
                            "title": "Mock Album Medium",
                            "parentTitle": "Mock Artist",
                            "summary": "This is a mock album summary.",
                            "type": "album",
                            "rating": 9.5,
                            "year": 1998,
                            "studio": "Spinefarm Records",
                            "Style": [{"tag": "Symphonic Metal"}, {"tag": "Heavy Metal"}]
                        }]
                    }
                }
            else:
                rtype = "movie"
                if ratingKey in ["200", "201", "202"]:
                    rtype = "show"
                elif ratingKey == "8888":
                    rtype = "artist"
                elif ratingKey == "9999":
                    rtype = "album"
                response_data = {
                    "MediaContainer": {
                        "Metadata": [{
                            "ratingKey": ratingKey,
                            "title": "Mock Title " + ratingKey,
                            "duration": 3600000,
                            "viewOffset": 0,
                            "type": rtype,
                            "Media": [{"bitrate": 320, "Part": [{"key": "/library/parts/103/file.mkv", "file": "/app/tests/dummy1.mkv", "size": 10485760, "Stream": [{"id":1, "streamType": 1, "codec": "h264"}, {"id":2, "streamType":2, "language": "English", "displayTitle": "English (AAC 5.1)"}]}]}]
                        }]
                    }
                }
        elif "/hubs/search" in path:
            import urllib.parse
            parsed = urllib.parse.urlparse(path)
            query = urllib.parse.parse_qs(parsed.query).get('query', [''])[0]
            
            response_data = {
                "MediaContainer": {
                    "Hub": [
                        {
                            "type": "movie",
                            "title": "Movies",
                            "Metadata": [{"ratingKey": "m1", "type": "movie", "title": "Movie: " + query, "thumb": "/thumb/m1", "librarySectionID": 1, "viewCount": 1}]
                        },
                        {
                            "type": "show",
                            "title": "Shows",
                            "Metadata": [{"ratingKey": "s1", "type": "show", "title": "Show: " + query, "thumb": "/thumb/s1", "librarySectionID": 1, "leafCount": 10, "viewedLeafCount": 5}]
                        },
                        {
                            "type": "episode",
                            "title": "Episodes",
                            "Metadata": [{"ratingKey": "e1", "type": "episode", "title": "Episode: " + query, "thumb": "/thumb/e1", "librarySectionID": 1}]
                        },
                        {
                            "type": "artist",
                            "title": "Artists",
                            "Metadata": [{"ratingKey": "ar1", "type": "artist", "title": "Artist: " + query, "thumb": "/thumb/ar1", "librarySectionID": 1}]
                        },
                        {
                            "type": "album",
                            "title": "Albums",
                            "Metadata": [{"ratingKey": "al1", "type": "album", "title": "Album: " + query, "thumb": "/thumb/al1", "librarySectionID": 1}]
                        },
                        {
                            "type": "track",
                            "title": "Tracks",
                            "Metadata": [{"ratingKey": "t1", "type": "track", "title": "Track: " + query, "thumb": "/thumb/t1", "librarySectionID": 1}]
                        },
                        {
                            "type": "person",
                            "title": "People",
                            "Metadata": [{"ratingKey": "pe1", "type": "person", "title": "Person: " + query, "thumb": "/thumb/pe1", "librarySectionID": 999}]
                        },
                        {
                            "type": "photo",
                            "title": "Photos",
                            "Metadata": [{"ratingKey": "ph1", "type": "photo", "title": "Photo: " + query, "thumb": "/thumb/ph1", "librarySectionID": 999}]
                        }
                    ]
                }
            }
        elif path == "/" or path == "/identity":
            response_data = {"MediaContainer": {"machineIdentifier": "mock_machine"}}
        else:
            response_data = {"MediaContainer": {"size": 0, "Metadata": []}}
            
        print(f"Mock server returning {response_data.get('MediaContainer', {}).get('size', 0)} items for path {path}")
        json_bytes = json.dumps(response_data).encode('utf-8')
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Connection', 'close')
        self.send_header('Content-Length', str(len(json_bytes)))
        self.end_headers()
        
        self.wfile.write(json_bytes)

port = 32400
if len(sys.argv) > 1:
    port = int(sys.argv[1])

httpd = http.server.ThreadingHTTPServer(('127.0.0.1', port), MockPlexHandler)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(certfile='/app/tests/mock_cert.pem', keyfile='/app/tests/mock_key.pem')
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print(f"Starting Mock HTTPS Server on 127.0.0.1:{port}")
httpd.serve_forever()
