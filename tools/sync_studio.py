"""
Synchronizes all Luau scripts from src/ directly into the running Roblox Studio instance via HTTP and MCP execute_luau.
"""
import http.server
import json
import os
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def collect_scripts():
    items = []
    
    # Mapping definitions matching default.project.json
    mappings = [
        (ROOT / "src" / "server", "ServerScriptService.HatchTheEgg"),
        (ROOT / "src" / "shared", "ReplicatedStorage.HatchTheEgg.Shared"),
        (ROOT / "src" / "client", "StarterPlayer.StarterPlayerScripts.HatchTheEggClient"),
    ]
    
    for base_dir, roblox_prefix in mappings:
        if not base_dir.exists():
            continue
        for root, dirs, files in os.walk(base_dir):
            rel_dir = Path(root).relative_to(base_dir)
            for f in sorted(files):
                if not f.endswith(".luau"):
                    continue
                file_path = Path(root) / f
                content = file_path.read_text(encoding="utf-8")
                
                # Determine className and roblox instance name
                if f.endswith(".server.luau"):
                    class_name = "Script"
                    inst_name = f[:-12]
                elif f.endswith(".client.luau"):
                    class_name = "LocalScript"
                    inst_name = f[:-12]
                elif f == "init.luau":
                    class_name = "ModuleScript"
                    # init.luau defines the folder itself as a ModuleScript
                    # but in Roblox Rojo convention, parent folder is the ModuleScript
                    inst_name = None
                else:
                    class_name = "ModuleScript"
                    inst_name = f[:-5]
                
                # Construct path
                path_parts = [roblox_prefix]
                if str(rel_dir) != ".":
                    for part in rel_dir.parts:
                        path_parts.append(part)
                if inst_name:
                    path_parts.append(inst_name)
                
                dot_path = ".".join(path_parts)
                items.append({
                    "path": dot_path,
                    "className": class_name,
                    "source": content,
                })
    return items

def run_sync_server():
    scripts = collect_scripts()
    payload = json.dumps(scripts).encode("utf-8")
    
    class SyncHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/scripts":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
            else:
                self.send_response(404)
                self.end_headers()
        def log_message(self, *args):
            pass
            
    server = http.server.HTTPServer(("127.0.0.1", 28989), SyncHandler)
    server.timeout = 15.0
    print(f"Collected {len(scripts)} scripts ({len(payload)} bytes). Ready on port 28989.")
    return server

if __name__ == "__main__":
    server = run_sync_server()
    # Handle single request
    t = threading.Thread(target=server.handle_request)
    t.start()
    t.join(10.0)
    server.server_close()
    print("Sync server finished.")
