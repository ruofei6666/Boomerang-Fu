"""Verify actual Web-exported 3D movement using keyboard and mobile touch events."""

import argparse
import json
import math
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://localhost:8060")
    parser.add_argument("--software-rendering", action="store_true", help="Use SwiftShader when headless hardware WebGL is unavailable")
    args = parser.parse_args()
    checks = []
    console_errors = []
    snapshots = {}

    def check(condition, description):
        checks.append({"check": description, "passed": bool(condition)})
        print(("PASS: " if condition else "FAIL: ") + description, flush=True)

    def state(page):
        return page.evaluate("JSON.parse(document.getElementById('canvas').getAttribute('data-game-state') || 'null')")

    def frames(page, count):
        # SwiftShader may render slowly. Wait for actual physics frames rather than
        # assuming that a fixed wall-clock delay means the game processed input.
        target = state(page)["physics_frame"] + count
        page.wait_for_function("target => JSON.parse(document.getElementById('canvas').getAttribute('data-game-state')).physics_frame >= target", arg=target, timeout=20000)

    def load(page):
        page.on("pageerror", lambda error: console_errors.append(str(error)))
        page.on("console", lambda message: console_errors.append(message.text) if message.type == "error" else None)
        page.goto(args.url + "/?verify=1&movement_only=1")
        page.wait_for_load_state("networkidle")
        page.wait_for_function("document.getElementById('canvas').hasAttribute('data-game-state') || (document.getElementById('error') && !document.getElementById('error').hidden)", timeout=30000)
        if not state(page):
            raise RuntimeError(page.locator("body").inner_text() + "\n" + "\n".join(console_errors))
        frames(page, 18)

    with sync_playwright() as playwright:
        browser_args = ["--autoplay-policy=no-user-gesture-required"]
        if args.software_rendering:
            browser_args += ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
        browser = playwright.chromium.launch(channel="msedge", headless=True, args=browser_args)
        desktop = browser.new_context(viewport={"width": 1440, "height": 810})
        page = desktop.new_page()
        load(page)
        check(page.locator("#loading").count() == 0, "Browser game finishes loading")
        first = state(page)
        check({actor["name"] for actor in first["wanderers"]} == {"EggplantNPC", "DonutNPC", "CarrotNPC"}, "Web build contains all three food NPCs")
        frames(page, 240)
        wandered = state(page)
        for initial, actor in zip(first["wanderers"], wandered["wanderers"]):
            distance = math.hypot(actor["position"][0] - initial["position"][0], actor["position"][2] - initial["position"][2])
            check(distance > 0.2, actor["name"] + " wanders in the browser without input")
        check(abs(wandered["position"][0] - first["position"][0]) < 0.05 and abs(wandered["position"][2] - first["position"][2]) < 0.05, "Browser strawberry waits for player input")
        start = state(page)
        page.keyboard.down("d")
        frames(page, 39)
        moving = state(page)
        page.keyboard.up("d")
        frames(page, 18)
        stopped = state(page)
        snapshots["keyboard"] = {"start": start, "moving": moving, "stopped": stopped}
        check(moving["position"][0] > start["position"][0] + 2.0, "Desktop D moves the 3D strawberry")
        check(math.hypot(*stopped["velocity"]) < 0.02, "Desktop releasing D stops movement")
        check(moving["camera"][0] > start["camera"][0] + 1.0, "Browser camera follows the strawberry")
        before = state(page)
        page.keyboard.down("w")
        frames(page, 30)
        page.keyboard.up("w")
        frames(page, 12)
        check(state(page)["position"][2] < before["position"][2] - 1.3, "Desktop W moves forward")
        page.keyboard.down("a")
        frames(page, 18)
        page.evaluate("window.dispatchEvent(new Event('blur'))")
        frames(page, 18)
        check(math.hypot(*state(page)["velocity"]) < 0.02, "Browser losing focus stops keyboard movement")
        page.keyboard.up("a")
        page.evaluate("window.dispatchEvent(new Event('focus'))")
        frames(page, 12)
        page.screenshot(path=str(ARTIFACTS / "strawberry_browser_desktop.png"))
        snapshots["desktop"] = state(page)
        desktop.close()

        mobile = browser.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=3, is_mobile=True, has_touch=True)
        phone = mobile.new_page()
        load(phone)
        first = state(phone)
        x, y = first["stick_center"]
        radius = first["stick_radius"]
        check(40 < radius < 100 and 0 < x < 195 and 844 - 240 < y < 844, "Portrait joystick stays visible and finger-sized")
        check(phone.evaluate("document.documentElement.scrollHeight <= innerHeight + 1"), "Portrait page does not scroll")
        phone.screenshot(path=str(ARTIFACTS / "strawberry_browser_portrait.png"))
        cdp = mobile.new_cdp_session(phone)

        def touches(kind, points):
            cdp.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": [
                {"id": identifier, "x": px, "y": py, "radiusX": 5, "radiusY": 5, "force": 1}
                for identifier, px, py in points
            ]})

        touches("touchStart", [(10, x, y)])
        touches("touchMove", [(10, x + radius * 0.82, y)])
        frames(phone, 39)
        moved = state(phone)
        check(moved["joystick"][0] > 0.65 and moved["position"][0] > first["position"][0] + 1.5, "Portrait touch joystick moves the actual 3D player")
        check(abs(moved["feet"][0] - moved["feet"][1]) > 0.005, "Ball feet animate in the mobile Web build")
        touches("touchStart", [(10, x + radius * 0.82, y), (11, 250, 170)])
        touches("touchMove", [(10, x + radius * 0.82, y), (11, 210, 200)])
        frames(phone, 12)
        check(state(phone)["joystick"][0] > 0.65, "Second touch does not steal the browser joystick")
        # CDP touchEnd ends all contacts; reducing touchMove's active list releases only finger 11.
        touches("touchMove", [(10, x + radius * 0.82, y)])
        frames(phone, 9)
        check(state(phone)["joystick"][0] > 0.65, "Releasing another finger keeps the joystick active")
        touches("touchMove", [(10, x + radius * 4, y - radius * 4)])
        frames(phone, 9)
        check(abs(math.hypot(*state(phone)["joystick"]) - 1) < 0.02, "Browser diagonal joystick speed is bounded")
        touches("touchEnd", [])
        frames(phone, 24)
        released = state(phone)
        check(math.hypot(*released["velocity"]) < 0.02 and math.hypot(*released["joystick"]) < 0.01, "Releasing outside the joystick stops the browser player")
        touches("touchStart", [(12, x + radius * 0.7, y)])
        frames(phone, 9)
        touches("touchCancel", [])
        frames(phone, 24)
        check(math.hypot(*state(phone)["joystick"]) < 0.01 and math.hypot(*state(phone)["velocity"]) < 0.02, "Browser touch cancellation stops movement")
        snapshots["portrait"] = state(phone)

        phone.set_viewport_size({"width": 844, "height": 390})
        frames(phone, 36)
        landscape = state(phone)
        rx, ry, rw, rh = landscape["match"]["controls"]["settings"]
        phone.touchscreen.tap(rx + rw / 2, ry + rh / 2)
        frames(phone, 21)
        reset = state(phone)
        check(abs(reset["position"][0]) < 0.05 and abs(reset["position"][2] - 3) < 0.05, "Mobile return-to-start button resets the player")
        landscape = reset
        x, y = landscape["stick_center"]
        radius = landscape["stick_radius"]
        check(40 < radius < 100 and 0 < x < 210 and 390 - 230 < y < 390, "Rotating the phone keeps the joystick usable")
        before = landscape["position"]
        touches("touchStart", [(13, x, y)])
        touches("touchMove", [(13, x, y - radius * 0.9)])
        frames(phone, 36)
        touches("touchEnd", [])
        frames(phone, 18)
        check(state(phone)["position"][2] < before[2] - 1.4, "Landscape touch joystick moves the strawberry")
        phone.screenshot(path=str(ARTIFACTS / "strawberry_browser_landscape.png"))
        snapshots["landscape"] = state(phone)
        mobile.close()
        browser.close()

    check(not console_errors, "Web build has no JavaScript or Godot script errors")
    report = {
        "passed": sum(item["passed"] for item in checks),
        "failed": sum(not item["passed"] for item in checks),
        "checks": checks, "console_errors": console_errors, "snapshots": snapshots,
        "mobile_validation": "Browser touchscreen simulation; physical phone not tested",
    }
    (ARTIFACTS / "browser-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f'BROWSER_VERIFICATION: {report["passed"]} passed, {report["failed"]} failed', flush=True)
    if console_errors:
        print(json.dumps(console_errors, ensure_ascii=False), flush=True)
    raise SystemExit(1 if report["failed"] else 0)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # A startup timeout must replace old results, not leave a stale report.
        (ARTIFACTS / "browser-verification.json").write_text(json.dumps({
            "status": "incomplete",
            "automation_error": str(error),
            "mobile_validation": "Browser simulation; physical phone not tested",
        }, ensure_ascii=False, indent=2), encoding="utf-8")
        raise
