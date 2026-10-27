"""Prints a checksum line per script so local files can be compared with what's in Studio.

Run this, then run tools/studio_checksums.luau in Studio (edit mode, e.g. via the Studio MCP
execute_luau tool) and diff the two outputs. Lines are "<path> <bytes> <sum>".
"""
import os

ROOTS = {
    "src/shared": "ReplicatedStorage.Shared",
    "src/server": "ServerScriptService.Server",
    "src/client": "StarterPlayer.StarterPlayerScripts.Client",
}

lines = []
for folder, base in ROOTS.items():
    for name in sorted(os.listdir(folder)):
        data = open(os.path.join(folder, name), "rb").read().replace(b"\r\n", b"\n")
        stem = name.replace(".luau", "")
        path = base if stem.startswith("init.") else f"{base}.{stem}"
        lines.append(f"{path} {len(data)} {sum(data) % 1000003}")
print("\n".join(sorted(lines)))
