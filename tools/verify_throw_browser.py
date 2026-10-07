"""Check the actual Web game's held keyboard/touch throws, aim, audio and layouts."""

import argparse
import json
import math
from pathlib import Path

from playwright.sync_api import sync_playwright
from verify_combat_browser import AUDIO_PROBE

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8060")
    parser.add_argument("--software-rendering", action="store_true")
    args = parser.parse_args()
    ARTIFACTS.mkdir(exist_ok=True)
    checks, errors, snapshots = [], [], {}

    def check(condition, description):
        checks.append({"check": description, "passed": bool(condition)})
        print(("PASS: " if condition else "FAIL: ") + description, flush=True)

    def state(page):
        return page.evaluate("JSON.parse(document.getElementById('canvas').getAttribute('data-game-state') || 'null')")

    def wait(page, expression, argument=None):
        try:
            page.wait_for_function("arg => { const s = JSON.parse(document.getElementById('canvas').getAttribute('data-game-state') || 'null'); return s && (" + expression + "); }", arg=argument, timeout=30000)
        except Exception:
            snapshots["timeout"] = {"expression": expression, "state": state(page)}
            raise

    def load(context):
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
        page.add_init_script(AUDIO_PROBE)
        page.goto(args.url.rstrip("/") + "/?verify=1&input_only=1", wait_until="networkidle", timeout=60000)
        wait(page, "s.throw_id !== undefined && s.throw_button !== undefined && s.projectiles !== undefined")
        return page

    def reset(page):
        x, y, width, height = state(page)["match"]["controls"]["settings"]
        page.mouse.click(x + width / 2, y + height / 2)
        wait(page, "s.has_boomerang && s.attack_state === 'idle' && s.projectiles.length === 0 && Math.abs(s.position[0]) < 0.01 && Math.abs(s.position[2] - 3) < 0.01")

    try:
        with sync_playwright() as playwright:
            flags = ["--autoplay-policy=no-user-gesture-required", "--disable-background-timer-throttling", "--disable-renderer-backgrounding"]
            if args.software_rendering:
                flags += ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
            browser = playwright.chromium.launch(channel="msedge", headless=True, args=flags)
            desktop = browser.new_context(viewport={"width": 1200, "height": 720})
            page = load(desktop)
            first = state(page)
            page.keyboard.down("l")
            page.keyboard.down("d")
            wait(page, "s.attack_state === 'aim' && s.throw_direction[0] > 0.99")
            aiming = state(page)
            wait(page, "s.physics_frame > arg + 18", aiming["physics_frame"])
            held = state(page)
            check(math.dist(held["position"], aiming["position"]) < 0.001 and math.hypot(*held["velocity"]) < 0.001, "Desktop held L freezes movement while D aims right")
            check(held["aim_visible"] and held["has_boomerang"] and held["throw_id"] == first["throw_id"] and held["sound_counts"]["slash"] == first["sound_counts"]["slash"], "Holding shows aim without throwing early or playing audio")
            page.keyboard.up("d")
            page.keyboard.down("w")
            wait(page, "s.throw_direction[1] < -0.99")
            check(state(page)["attack_state"] == "aim", "W changes direction while the throw remains held")
            page.keyboard.up("w")
            page.screenshot(path=str(ARTIFACTS / "throw_browser_desktop_aim.png"))
            page.keyboard.up("l")
            wait(page, "s.throw_id > arg && !s.has_boomerang", first["throw_id"])
            released = state(page)
            check(released["throw_id"] == first["throw_id"] + 1 and released["sound_counts"]["slash"] == first["sound_counts"]["slash"] + 1 and not released["aim_visible"], "L release launches one projectile with one slash sound and clears aim")
            wait(page, "s.projectiles.some(p => !p.flying)")
            stopped = state(page)
            dropped = stopped["projectiles"][0]
            check(abs(dropped["distance"] - dropped["range"]) < 0.001 and dropped["range"] == 38 and dropped["speed"] == 0 and dropped["bounces"] > 0, "Web projectile ricochets and stops after 38 metres of travel")
            check(not stopped["has_boomerang"], "The Web player remains unarmed until picking up the stopped weapon")
            attack_id = stopped["attack_id"]
            page.keyboard.press("j")
            page.keyboard.press("l")
            wait(page, "s.physics_frame > arg + 12", stopped["physics_frame"])
            check(state(page)["attack_id"] == attack_id and state(page)["throw_id"] == released["throw_id"], "Empty-handed J and L cannot start attacks")
            audio = page.evaluate("({peak: window.__combatAudioPeak, taps: window.__combatAudioTaps.length, sources: window.__combatAudioSources})")
            # SwiftShader can block analyser polling past the short clip; the source
            # hook also latches the actual non-silent buffer on the running graph.
            sounding = audio["peak"] > 0.001 or any(source["peak"] > 0.001 and source["state"] == "running" for source in audio["sources"])
            check(sounding and audio["taps"] > 0, "Throwing schedules a non-silent sample on the running WebAudio output graph")
            snapshots["desktop"] = {"held": held, "released": released, "stopped": stopped, "audio": audio}
            reset(page)
            before = state(page)
            page.keyboard.down("l")
            wait(page, "s.attack_state === 'aim'")
            page.evaluate("window.dispatchEvent(new Event('blur'))")
            wait(page, "s.attack_state === 'idle' && !s.aim_visible")
            page.keyboard.up("l")
            page.evaluate("window.dispatchEvent(new Event('focus'))")
            check(state(page)["has_boomerang"] and state(page)["throw_id"] == before["throw_id"], "Web blur cancels aiming without releasing a projectile")
            desktop.close()

            mobile = browser.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=1, is_mobile=True, has_touch=True)
            phone = load(mobile)
            first = state(phone)
            tx, ty = first["throw_button"]
            check(260 < tx < 380 and 360 < ty < 560 and 40 <= first["throw_radius"] <= 65, "Portrait throw icon is visible above jump and slash")
            x, y = first["stick_center"]
            radius = first["stick_radius"]
            cdp = mobile.new_cdp_session(phone)

            def touches(kind, points):
                cdp.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": [{"id": identifier, "x": at_x, "y": at_y, "radiusX": 5, "radiusY": 5, "force": 1} for identifier, at_x, at_y in points]})

            touches("touchStart", [(1, x + radius * 0.8, y)])
            wait(phone, "s.touch >= 0 && s.joystick[0] > 0.5")
            touches("touchStart", [(1, x + radius * 0.8, y), (2, tx, ty)])
            wait(phone, "s.attack_state === 'aim' && s.throw_touch >= 0")
            held = state(phone)
            touches("touchMove", [(1, x, y - radius * 0.8), (2, tx, ty)])
            wait(phone, "s.throw_direction[1] < -0.99 && s.physics_frame > arg + 12", held["physics_frame"])
            aiming = state(phone)
            check(math.dist(held["position"], aiming["position"]) < 0.001 and aiming["touch"] == held["touch"] and aiming["throw_touch"] == held["throw_touch"], "Two-finger touch aims with the joystick while the character stays still")
            phone.screenshot(path=str(ARTIFACTS / "throw_browser_portrait_aim.png"))
            # CDP touchMove with an omitted finger does not emit touchend for it.
            # Dispatch the browser's real touchend shape with one changed touch
            # and the joystick touch retained, then cancel CDP's remaining state.
            phone.evaluate("""p => {
                const canvas = document.getElementById('canvas');
                const make = (id, x, y) => new Touch({identifier: id, target: canvas, clientX: x, clientY: y, pageX: x, pageY: y, screenX: x, screenY: y, radiusX: 5, radiusY: 5, force: 1});
                const retained = make(1, p.x, p.y);
                const ended = make(2, p.tx, p.ty);
                canvas.dispatchEvent(new TouchEvent('touchend', {bubbles: true, cancelable: true, touches: [retained], targetTouches: [retained], changedTouches: [ended]}));
            }""", {"x": x, "y": y - radius * 0.8, "tx": tx, "ty": ty})
            wait(phone, "s.throw_id > arg && s.throw_touch === -1", held["throw_id"])
            released = state(phone)
            check(released["throw_id"] == held["throw_id"] + 1 and released["touch"] == held["touch"] and released["joystick"][1] < -0.5, "Lifting the throw finger launches once without taking the joystick finger")
            touches("touchCancel", [])
            wait(phone, "s.touch === -1")
            snapshots["portrait"] = {"held": held, "aiming": aiming, "released": released}
            reset(phone)
            before = state(phone)
            tx, ty = before["throw_button"]
            touches("touchStart", [(3, tx, ty)])
            wait(phone, "s.attack_state === 'aim'")
            touches("touchCancel", [])
            wait(phone, "s.attack_state === 'idle' && s.throw_touch === -1")
            check(state(phone)["has_boomerang"] and state(phone)["throw_id"] == before["throw_id"], "Touch cancel keeps the weapon and does not throw")
            snapshots["touch_cancel"] = {"before": before, "after": state(phone)}
            phone.set_viewport_size({"width": 844, "height": 390})
            wait(phone, "s.throw_button[0] > 450 && s.throw_button[1] < 390")
            landscape = state(phone)
            centers = [landscape[name] for name in ["throw_button", "jump_button", "attack_button"]]
            extent = landscape["throw_radius"]
            check(all(extent <= at_x <= 844 - extent and extent <= at_y <= 390 - extent for at_x, at_y in centers) and all(math.dist(centers[a], centers[b]) > extent * 2 for a in range(3) for b in range(a + 1, 3)), "Landscape throw, jump and slash controls fit without overlapping")
            check(math.dist(centers[0], landscape["stick_center"]) > extent + landscape["stick_radius"] + 16, "Landscape throw input is clear of the movement joystick")
            phone.screenshot(path=str(ARTIFACTS / "throw_browser_landscape.png"))
            snapshots["landscape"] = landscape
            mobile.close()
            browser.close()
    except Exception as error:
        errors.append(repr(error))
        print("ERROR:", repr(error), flush=True)
    check(not errors, "No browser or Godot script errors")
    result = {"checks": checks, "errors": errors, "snapshots": snapshots, "passed": sum(item["passed"] for item in checks)}
    (ARTIFACTS / "throw-browser-verification.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    failed = sum(not item["passed"] for item in checks)
    print(f"THROW_BROWSER_VERIFICATION: {result['passed']} passed, {failed} failed", flush=True)
    raise SystemExit(1 if errors or failed else 0)


if __name__ == "__main__":
    main()
