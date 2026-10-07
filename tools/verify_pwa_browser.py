"""Exercise the exported Godot PWA in a persistent browser and Pages subpath."""

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import re
from pathlib import Path
import tempfile
import threading

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"
PREFIX = "/Boomerang-Fu/"
STATE = "JSON.parse(document.getElementById('canvas').getAttribute('data-game-state') || 'null')"
ANDROID = "Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36"
IOS = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Version/26.0 Mobile/15E148 Safari/604.1"
release = {"version": "", "corrupt": ""}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", default="build/web", help="Built site relative to the project")
    parser.add_argument("--software-rendering", action="store_true")
    args = parser.parse_args()
    directory = (ROOT / args.directory).resolve()
    files = json.loads(re.search(r"const FILES = (.*?);\n", (directory / "sw.js").read_text(encoding="utf-8")).group(1))
    ARTIFACTS.mkdir(exist_ok=True)
    report = {"checks": [], "browserErrors": [], "passed": False}

    class Site(BaseHTTPRequestHandler):
        def do_GET(self):
            name = self.path.split("?", 1)[0]
            if name in ("/other-project.html", "/health"):
                content, mime = b"<html><title>Unrelated project</title></html>", "text/html"
            elif name.startswith(PREFIX):
                filename = directory / (name[len(PREFIX):] or "index.html")
                if not filename.is_file() or not filename.resolve().is_relative_to(directory):
                    self.send_error(404)
                    return
                content = filename.read_bytes()
                mime = {".js": "text/javascript", ".css": "text/css", ".html": "text/html", ".webmanifest": "application/manifest+json", ".wasm": "application/wasm", ".png": "image/png"}.get(filename.suffix, "application/octet-stream")
                if filename.name == "sw.js" and release["version"]:
                    content = content.replace(b"const VERSION = ", ("const VERSION = '" + release["version"] + "' + ").encode(), 1)
                if filename.name == release["corrupt"]:
                    content = content[:-1] + bytes([content[-1] ^ 1])
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(content)

        def log_message(self, *_args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Site)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_port}{PREFIX}"
    report["url"] = base

    def passed(name, **detail):
        report["checks"].append({"check": name, **detail})
        print("PASS:", name, json.dumps(detail, ensure_ascii=True), flush=True)

    def game(page, expression="s.match && s.match.phase === 'lobby'"):
        page.wait_for_function("() => { const s = " + STATE + "; return s && (" + expression + "); }", timeout=60000)
        return page.evaluate(STATE)

    def click_game(page, control):
        x, y, width, height = page.evaluate(STATE)["match"]["controls"][control]
        page.touchscreen.tap(x + width / 2, y + height / 2)

    try:
        with tempfile.TemporaryDirectory(prefix="boomerang-pwa-") as profile, sync_playwright() as playwright:
            launch_args = ["--autoplay-policy=no-user-gesture-required", "--host-resolver-rules=MAP boomerang.test 127.0.0.1", "--no-proxy-server"]
            if args.software_rendering:
                launch_args += ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
            context = playwright.chromium.launch_persistent_context(profile, channel="msedge", headless=True, args=launch_args,
                viewport={"width": 390, "height": 844}, user_agent=ANDROID, is_mobile=True, has_touch=True)
            page = context.new_page()
            page.set_default_timeout(30000)
            page.on("pageerror", lambda error: report["browserErrors"].append(str(error)))
            page.on("console", lambda message: report["browserErrors"].append(message.text) if message.type == "error" and ("SCRIPT ERROR:" in message.text or message.text.startswith("ERROR:")) else None)
            page.goto(f"http://127.0.0.1:{server.server_port}/other-project.html")
            sentinels = page.evaluate("""async () => {
                const names = ['other-game-cache', 'boomerang-arena-pwa-' + encodeURIComponent(location.origin + '/Other-Game/') + '-old'];
                for (const name of names) await (await caches.open(name)).put('/sentinel', new Response('keep'));
                return names;
            }""")
            url = base + "?verify=1&match_testing=1"
            page.goto(url, wait_until="networkidle", timeout=120000)
            page.wait_for_function("document.getElementById('pwa-status').textContent === '离线可玩'", timeout=120000)
            assert page.locator("#pwa-dialog").evaluate("dialog => dialog.open")
            assert page.locator("#pwa-android-tab").get_attribute("aria-pressed") == "true"
            page.screenshot(path=str(ARTIFACTS / "pwa_android_portrait.png"))
            passed("ordinary Android browser shows installation tutorial automatically")

            cdp = context.new_cdp_session(page)
            manifest = cdp.send("Page.getAppManifest")
            assert not manifest["errors"], manifest
            data = json.loads(manifest["data"])
            assert data["scope"] == "./" and data["start_url"] == "./"
            assert data["display"] == "fullscreen"
            install_errors = cdp.send("Page.getInstallabilityErrors")["installabilityErrors"]
            assert not install_errors, install_errors
            passed("manifest, icons and Chromium installability are valid under the Pages subpath")

            for width, height in [(390, 844), (844, 390), (320, 568), (1440, 810)]:
                page.set_viewport_size({"width": width, "height": height})
                bounds = page.locator("#pwa-dialog").bounding_box()
                assert bounds["x"] >= 0 and bounds["y"] >= 0 and bounds["x"] + bounds["width"] <= width + 1 and bounds["y"] + bounds["height"] <= height + 1, bounds
                assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
                assert page.locator("#pwa-continue").is_visible()
                page.locator("#pwa-ios-tab").click()
                assert page.locator("#pwa-ios-guide").is_visible() and not page.locator("#pwa-android-guide").is_visible()
                assert "添加到主屏幕" in page.locator("#pwa-ios-guide").inner_text()
                page.screenshot(path=str(ARTIFACTS / f"pwa_ios_guide_{width}x{height}.png"))
            page.set_viewport_size({"width": 390, "height": 844})
            page.locator("#pwa-android-tab").click()
            before_scroll = page.locator(".pwa-body").evaluate("body => body.scrollTop")
            body = page.locator(".pwa-body").bounding_box()
            sx, sy = body["x"] + body["width"] / 2, body["y"] + body["height"] - 40
            for kind, y in [("touchStart", sy), ("touchMove", sy - 160), ("touchMove", sy - 220)]:
                cdp.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": [{"id": 9, "x": sx, "y": y}]})
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            page.wait_for_function("before => document.querySelector('.pwa-body').scrollTop > before", arg=before_scroll)
            passed("Android and Apple tutorials fit four viewports and support finger scrolling")

            page.evaluate("""() => {
                const event = new Event('beforeinstallprompt', {cancelable: true});
                event.prompt = async () => { window.__installClicked = true; };
                event.userChoice = Promise.resolve({outcome: 'accepted'});
                window.dispatchEvent(event);
            }""")
            page.locator("#pwa-install").click()
            assert page.evaluate("window.__installClicked")
            assert "桌面" in page.locator("#pwa-feedback").inner_text()
            passed("install button handles the browser prompt and explains desktop launch")
            page.locator("#pwa-continue").click()
            game(page)

            def overlap(first, second):
                x, y, width, height = second
                return first["x"] < x + width and x < first["x"] + first["width"] and first["y"] < y + height and y < first["y"] + first["height"]

            for width, height in [(390, 844), (844, 390), (320, 568)]:
                page.set_viewport_size({"width": width, "height": height})
                previous_frame = page.evaluate(STATE)["physics_frame"]
                current = game(page, f"s.physics_frame >= {previous_frame + 6}")
                button = page.locator("#pwa-menu").bounding_box()
                controls = current["match"]["controls"]
                assert all(not overlap(button, controls[name]) for name in ["minus", "plus", "difficulty", "scoring", "start"]), (width, controls)
            page.set_viewport_size({"width": 390, "height": 844})
            previous_frame = page.evaluate(STATE)["physics_frame"]
            game(page, f"s.physics_frame >= {previous_frame + 6}")
            click_game(page, "difficulty")
            current = game(page, "s.match.controls.popup.visible")
            x, y = current["match"]["controls"]["popup"]["items"][0]
            page.touchscreen.tap(x, y)
            game(page, "s.match.difficulty === 0")
            passed("PWA entry leaves mobile settings unobstructed and native difficulty selector remains usable")

            keys = page.evaluate("""async () => {
                const name = (await caches.keys()).find(name => name.startsWith('boomerang-arena-pwa-' + encodeURIComponent(new URL('./', location.href).href) + '-'));
                return (await (await caches.open(name)).keys()).map(request => request.url);
            }""")
            assert len(keys) == len(files), keys
            assert all(key.startswith(base) for key in keys)
            assert not any(key.endswith("/sw.js") or key.endswith("/health") for key in keys)
            passed("complete precache contains the game, audio worklets, tutorial, manifest and icons", files=len(keys))

            context.set_offline(True)
            # Also stop the origin: this proves the game does not accidentally
            # use service-worker traffic that bypasses browser emulation.
            port = server.server_port
            server.shutdown()
            server.server_close()
            page.goto(base + "?verify=1&match_testing=1&offline=1", wait_until="networkidle", timeout=60000)
            page.wait_for_function("document.getElementById('pwa-status').textContent === '离线可玩'")
            bad = page.evaluate("""async files => {
                const failures = [];
                for (const file of files) {
                    const response = await fetch(file.path + '?offline-cache-check=1');
                    if (!response.ok || (await response.arrayBuffer()).byteLength !== file.bytes) failures.push(file.path);
                }
                return failures;
            }""", files)
            assert not bad, bad
            ranged = page.evaluate("""async () => {
                const response = await fetch('index.wasm', {headers: {'Range': 'bytes=0-7'}});
                return {status: response.status, bytes: [...new Uint8Array(await response.arrayBuffer())]};
            }""")
            assert ranged == {"status": 206, "bytes": [0, 97, 115, 109, 1, 0, 0, 0]}, ranged
            passed("offline reload with query strings serves every resource and valid WASM byte ranges")
            page.locator("#pwa-continue").click()
            game(page)
            click_game(page, "start")
            started = game(page, "s.match.phase === 'playing'")
            advanced = game(page, f"s.physics_frame >= {started['physics_frame'] + 15}")
            assert len(started["match"]["actors"]) == 4
            assert any(a["position"] != b["position"] for a, b in zip(started["match"]["actors"][1:], advanced["match"]["actors"][1:]))
            page.screenshot(path=str(ARTIFACTS / "pwa_offline_game.png"))
            passed("offline Godot game starts a real match and bots move through actual physics")

            page.locator("#pwa-menu").click()
            page.wait_for_timeout(150)
            paused = page.evaluate(STATE)
            page.wait_for_timeout(800)
            assert page.evaluate(STATE) == paused, "Game state changed while the tutorial was open"
            page.locator("#pwa-check").click()
            page.wait_for_function("document.getElementById('pwa-feedback').textContent.includes('当前离线')")
            assert "当前离线" in page.locator("#pwa-feedback").inner_text(), page.locator("#pwa-feedback").inner_text()
            passed("tutorial pauses the entire game and checking updates offline keeps the playable version")

            context.set_offline(False)
            server = ThreadingHTTPServer(("127.0.0.1", port), Site)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            page.evaluate("window.__originalDocument = true")
            release["version"] = "upgrade"
            page.evaluate("async () => (await navigator.serviceWorker.getRegistration()).update()")
            page.wait_for_function("async () => !!(await navigator.serviceWorker.getRegistration()).waiting", timeout=120000)
            assert page.evaluate("window.__originalDocument")
            page.locator("#pwa-update").wait_for(state="visible")
            page.locator("#pwa-update-later").click()
            game(page, f"s.physics_frame > {paused['physics_frame']}")
            assert page.evaluate("window.__originalDocument")
            passed("complete new release waits for acceptance and postponing resumes the same match")

            page.locator("#pwa-menu").click()
            page.add_init_script("Object.defineProperty(navigator, 'standalone', {get: () => true})")
            with page.expect_navigation(wait_until="networkidle", timeout=60000):
                page.locator("#pwa-update-now").click()
            page.wait_for_function("document.getElementById('pwa-status').textContent === '离线可玩'")
            game(page)
            assert not page.locator("#pwa-dialog").evaluate("dialog => dialog.open")
            names = page.evaluate("caches.keys()")
            own_prefix = "boomerang-arena-pwa-" + page.evaluate("encodeURIComponent(new URL('./', location.href).href)") + "-"
            own = [name for name in names if name.startswith(own_prefix)]
            assert len(own) == 1 and "upgrade" in own[0], names
            assert all(name in names for name in sentinels), names
            passed("accepted update reloads once, skips tutorial for installed mode and only removes this scope's old cache")

            release["version"], release["corrupt"] = "broken", "index.pck"
            result = page.evaluate("""async () => {
                const registration = await navigator.serviceWorker.getRegistration();
                const failed = new Promise(resolve => registration.addEventListener('updatefound', () => {
                    const worker = registration.installing;
                    worker.addEventListener('statechange', () => {
                        if (worker.state === 'redundant') resolve(true);
                        if (worker.state === 'installed') resolve(false);
                    });
                }, {once: true}));
                await registration.update();
                return failed;
            }""")
            assert result, "Corrupt release was incorrectly accepted"
            names = page.evaluate("caches.keys()")
            assert own[0] in names and not any("broken" in name for name in names)
            context.set_offline(True)
            server.shutdown()
            server.server_close()
            page.reload(wait_until="networkidle")
            game(page)
            passed("same-size corrupted download fails SHA-256 and leaves the previous version able to restart offline")

            context.set_offline(False)
            server = ThreadingHTTPServer(("127.0.0.1", port), Site)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            release["version"], release["corrupt"] = "upgrade", ""
            page.evaluate("""async () => {
                const registration = await navigator.serviceWorker.getRegistration();
                const name = (await caches.keys()).find(name => name.startsWith('boomerang-arena-pwa-' + encodeURIComponent(registration.scope) + '-'));
                await (await caches.open(name)).delete(new URL('icons/icon-192.png', registration.scope));
            }""")
            page.locator("#pwa-menu").click()
            page.wait_for_function("document.getElementById('pwa-status').textContent.includes('离线包不完整')")
            page.locator("#pwa-check").click()
            page.wait_for_function("document.getElementById('pwa-status').textContent === '离线可玩'")
            passed("evicted resources are detected and repaired by checking updates")

            ios = context.new_page()
            ios.add_init_script("Object.defineProperty(navigator, 'standalone', {get: () => false}); Object.defineProperty(navigator, 'userAgent', {get: () => " + json.dumps(IOS) + "})")
            ios.goto(base, wait_until="networkidle", timeout=60000)
            assert ios.locator("#pwa-dialog").evaluate("dialog => dialog.open")
            assert ios.locator("#pwa-ios-tab").get_attribute("aria-pressed") == "true"
            ios.close()
            passed("iPhone browser detection selects Apple steps automatically")

            insecure = context.new_page()
            insecure.add_init_script("Object.defineProperty(navigator, 'standalone', {get: () => false})")
            insecure.goto(f"http://boomerang.test:{server.server_port}{PREFIX}", wait_until="networkidle", timeout=60000)
            assert insecure.evaluate("window.isSecureContext") is False
            assert insecure.locator("#pwa-insecure").is_visible()
            assert insecure.locator("#pwa-check").is_disabled()
            insecure.close()
            passed("ordinary HTTP shows HTTPS guidance and does not claim offline support")

            assert not report["browserErrors"], report["browserErrors"]
            passed("no uncaught browser errors")
            report["passed"] = True
            context.close()
    except Exception as error:
        report["error"] = str(error)
        raise
    finally:
        server.shutdown()
        server.server_close()
        destination = ARTIFACTS / "pwa-browser-verification.json"
        destination.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print("REPORT:", destination, flush=True)


if __name__ == "__main__":
    main()
