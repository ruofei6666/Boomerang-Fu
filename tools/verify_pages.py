"""Check that the public Pages site serves the exact exported Godot assets."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="https://ruofei6666.github.io/Boomerang-Fu/")
    args = parser.parse_args()
    base = args.url.rstrip("/") + "/"
    expected = json.loads((ROOT / "docs/build-manifest.json").read_text(encoding="utf-8"))
    checks = []
    try:
        with urllib.request.urlopen(base + "build-manifest.json", timeout=40) as response:
            deployed_manifest = json.load(response)
        if deployed_manifest != expected:
            raise RuntimeError("Public manifest differs from the current local build")
        for item in expected["files"]:
            digest = hashlib.sha256()
            size = 0
            with urllib.request.urlopen(base + item["path"], timeout=40) as response:
                mime = response.headers.get_content_type()
                status = response.status
                while chunk := response.read(1024 * 1024):
                    size += len(chunk)
                    digest.update(chunk)
            matched = size == item["bytes"] and digest.hexdigest() == item["sha256"]
            if item["path"].endswith(".wasm"):
                matched = matched and mime == "application/wasm"
            checks.append({"path": item["path"], "status": status, "bytes": size,
                           "mime": mime, "sha256": digest.hexdigest(), "passed": matched})
            print(("PASS: " if matched else "FAIL: ") + item["path"], flush=True)
        report = {"url": base, "passed": sum(check["passed"] for check in checks),
                  "failed": sum(not check["passed"] for check in checks), "checks": checks}
    except Exception as error:
        report = {"url": base, "status": "incomplete", "error": str(error), "checks": checks}
    destination = ROOT / "artifacts/pages-live-verification.json"
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key != "checks"}), flush=True)
    return 1 if report.get("status") == "incomplete" or report.get("failed") else 0


if __name__ == "__main__":
    raise SystemExit(main())
