"""Fetch only the official Web release template from Godot's large TPZ archive."""

import argparse
import os
from pathlib import Path
import struct
import urllib.request
import zlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="4.7.2")
    parser.add_argument("--template", default="web_nothreads_release.zip", choices=["web_nothreads_release.zip", "web_nothreads_debug.zip"])
    args = parser.parse_args()
    url = (f"https://github.com/godotengine/godot-builds/releases/download/"
           f"{args.version}-stable/Godot_v{args.version}-stable_export_templates.tpz")
    destination = Path(os.environ["APPDATA"]) / "Godot" / "export_templates" / f"{args.version}.stable"
    target = destination / args.template
    if target.exists():
        print(f"WEB_TEMPLATE_READY: {target}", flush=True)
        return
    headers = {"User-Agent": "Godot-Strawberry-Template-Setup"}
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers, method="HEAD"), timeout=45) as response:
        final_url = response.url
        size = int(response.headers["Content-Length"])

    def get_range(start, end):
        request_headers = dict(headers, Range=f"bytes={start}-{end}")
        request = urllib.request.Request(final_url, headers=request_headers)
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError("Server did not honor the byte range; refusing to download the entire archive.")
            content_range = response.headers.get("Content-Range", "")
            if not content_range.startswith(f"bytes {start}-"):
                raise RuntimeError(f"Unexpected range: {content_range}")
            return response.read(end - start + 1)

    tail = get_range(max(0, size - 65557), size - 1)
    offset = tail.rfind(b"PK\x05\x06")
    if offset < 0:
        raise RuntimeError("ZIP central directory not found")
    fields = struct.unpack_from("<4s4H2IH", tail, offset)
    directory_size, directory_offset = fields[5:7]
    directory = get_range(directory_offset, directory_offset + directory_size - 1)
    cursor = 0
    entry = None
    while cursor < len(directory):
        if directory[cursor:cursor + 4] != b"PK\x01\x02":
            raise RuntimeError("Invalid ZIP directory entry")
        method = struct.unpack_from("<H", directory, cursor + 10)[0]
        crc, compressed_size, unpacked_size = struct.unpack_from("<III", directory, cursor + 16)
        name_len, extra_len, comment_len = struct.unpack_from("<HHH", directory, cursor + 28)
        local_offset = struct.unpack_from("<I", directory, cursor + 42)[0]
        name = directory[cursor + 46:cursor + 46 + name_len].decode("utf-8")
        if name == "templates/" + args.template:
            entry = (method, crc, compressed_size, unpacked_size, local_offset)
            break
        cursor += 46 + name_len + extra_len + comment_len
    if entry is None:
        raise RuntimeError("Web release template absent from official archive")
    method, crc, compressed_size, unpacked_size, local_offset = entry
    local_header = get_range(local_offset, local_offset + 29)
    name_len, extra_len = struct.unpack_from("<HH", local_header, 26)
    data_offset = local_offset + 30 + name_len + extra_len
    print(f"Fetching Web release template: {compressed_size / 1024**2:.1f} MiB", flush=True)
    compressed = get_range(data_offset, data_offset + compressed_size - 1)
    data = zlib.decompress(compressed, -15) if method == 8 else compressed
    if len(data) != unpacked_size or zlib.crc32(data) != crc:
        raise RuntimeError("Web template size or CRC check failed")
    destination.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f"WEB_TEMPLATE_READY: {target}", flush=True)


if __name__ == "__main__":
    main()
