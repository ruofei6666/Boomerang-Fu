"""Check the exported game's keyboard/two-finger jump and slash inputs and WebAudio."""

import argparse
import json
import math
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"
AUDIO_PROBE = """window.__combatAudioTaps = [];
window.__combatAudioPeak = 0;
window.__combatAudioSources = [];
const originalStart = AudioBufferSourceNode.prototype.start;
AudioBufferSourceNode.prototype.start = function (...args) {
  let peak = 0;
  if (this.buffer) {
    for (let channel = 0; channel < this.buffer.numberOfChannels; channel++) {
      for (const value of this.buffer.getChannelData(channel)) peak = Math.max(peak, Math.abs(value));
    }
  }
  window.__combatAudioSources.push({peak, state: this.context.state, duration: this.buffer ? this.buffer.duration : 0});
  return originalStart.apply(this, args);
};
const originalConnect = AudioNode.prototype.connect;
AudioNode.prototype.connect = function (...args) {
  const result = originalConnect.apply(this, args);
  if (args[0] instanceof AudioDestinationNode) {
    const analyser = this.context.createAnalyser();
    analyser.fftSize = 512;
    originalConnect.call(this, analyser);
    const silentSink = this.context.createGain();
    silentSink.gain.value = 0;
    originalConnect.call(analyser, silentSink);
    originalConnect.call(silentSink, this.context.destination);
    window.__combatAudioTaps.push(analyser);
  }
  return result;
};
setInterval(() => {
  for (const analyser of window.__combatAudioTaps) {
    const samples = new Float32Array(analyser.fftSize);
    analyser.getFloatTimeDomainData(samples);
    for (const value of samples) window.__combatAudioPeak = Math.max(window.__combatAudioPeak, Math.abs(value));
  }
}, 10);
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8060")
    parser.add_argument("--software-rendering", action="store_true")
    parser.add_argument("--desktop-only", action="store_true", help="Run only the keyboard/audio check while diagnosing a Web audio failure")
    args = parser.parse_args()
    ARTIFACTS.mkdir(exist_ok=True)
    checks, errors, snapshots = [], [], {}

    def check(condition, text):
        checks.append({"check": text, "passed": bool(condition)})
        print(("PASS: " if condition else "FAIL: ") + text, flush=True)

    def state(page):
        return page.evaluate("JSON.parse(document.getElementById('canvas').getAttribute('data-game-state') || 'null')")

    def wait_state(page, expression, argument=None):
        try:
            page.wait_for_function(
                "arg => { const s = JSON.parse(document.getElementById('canvas').getAttribute('data-game-state') || 'null'); return s && (" + expression + "); }",
                arg=argument,
                timeout=30000,
            )
        except Exception:
            snapshots["wait_timeout"] = {"expression": expression, "argument": argument, "state": state(page)}
            raise

    def load(context):
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
        page.add_init_script(AUDIO_PROBE)
        # Use actual combat and physics; freeze NPCs so input checks have a clear route.
        page.goto(args.url.rstrip("/") + "/?verify=1&input_only=1", wait_until="networkidle", timeout=60000)
        wait_state(page, "s.attack_id !== undefined && s.jump_id !== undefined && s.jump_button !== undefined && s.attack_buffered !== undefined")
        return page

    try:
        with sync_playwright() as playwright:
            launch_args = ["--autoplay-policy=no-user-gesture-required"]
            if args.software_rendering:
                launch_args += ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
            browser = playwright.chromium.launch(channel="msedge", headless=True, args=launch_args)
            desktop = browser.new_context(viewport={"width": 1200, "height": 720})
            page = load(desktop)
            check(state(page)["alive"], "Web build loads the living player and combat state")
            before = state(page)
            page.keyboard.press("j")
            wait_state(page, "s.attack_id > arg", before["attack_id"])
            wait_state(page, "s.attack_state === 'idle'")
            after = state(page)
            distance = math.hypot(after["position"][0] - before["position"][0], after["position"][2] - before["position"][2])
            check(after["attack_id"] == before["attack_id"] + 1, "Desktop J performs one slash")
            check(2.70 < distance < 3.20, "Desktop slash advances by the updated 2.85 hop distance")
            check(after["sound_counts"]["slash"] == before["sound_counts"]["slash"] + 1, "Web slash emits the requested audio event once")
            audio = page.evaluate("({peak: window.__combatAudioPeak, taps: window.__combatAudioTaps.map(node => ({state: node.context.state, time: node.context.currentTime})), sources: window.__combatAudioSources})")
            # Headless GL can block JS timers for longer than this 0.23 s clip.
            # Latch the actual WebAudio sample at start instead of missing it between polls.
            sounding = audio["peak"] > 0.001 or any(source["peak"] > 0.001 and source["state"] == "running" for source in audio["sources"])
            check(sounding and len(audio["taps"]) > 0, "WebAudio schedules a non-silent slash sample on its running output graph")
            snapshots["desktop"] = {"before": before, "after": after, "audio": audio}
            print("AUDIO_PROBE: " + json.dumps(audio), flush=True)
            # Reset to the same clear starting area before measuring the longer jump.
            viewport = page.viewport_size
            page.mouse.click(viewport["width"] - 78, viewport["height"] - 46)
            wait_state(page, "Math.abs(s.position[0]) < 0.01 && Math.abs(s.position[2] - 3) < 0.01 && s.attack_state === 'idle'")
            jump_before = state(page)
            page.keyboard.press("k")
            wait_state(page, "s.jump_id > arg", jump_before["jump_id"])
            wait_state(page, "s.attack_state === 'idle'")
            jump_after = state(page)
            jump_distance = math.hypot(jump_after["position"][0] - jump_before["position"][0], jump_after["position"][2] - jump_before["position"][2])
            check(jump_after["jump_id"] == jump_before["jump_id"] + 1, "Desktop K performs one independent jump")
            check(abs(jump_distance - distance * 2) < 0.035 and abs(jump_distance - 5.70) < 0.035, "Measured Web jump travels 5.70, twice the slash hop")
            check(jump_after["attack_id"] == jump_before["attack_id"] and jump_after["sound_counts"]["slash"] == jump_before["sound_counts"]["slash"], "K does not trigger melee damage or slash audio")
            check(abs(jump_after["jump_height"]) < 0.001 and math.hypot(*jump_after["velocity"]) < 0.01, "Web jump lands and stops without continuing forward")
            snapshots["desktop_jump"] = {"before": jump_before, "after": jump_after, "distance": jump_distance, "slash_hop": distance}
            page.mouse.click(viewport["width"] - 78, viewport["height"] - 46)
            wait_state(page, "Math.abs(s.position[0]) < 0.01 && Math.abs(s.position[2] - 3) < 0.01 && s.attack_state === 'idle'")
            buffered_before = state(page)
            # Send J immediately after K, before waiting for a rendered state snapshot.
            page.keyboard.down("k")
            page.keyboard.press("j")
            page.keyboard.up("k")
            wait_state(page, "s.jump_id > arg.jump_id && s.attack_id > arg.attack_id", buffered_before)
            wait_state(page, "s.attack_state === 'idle'")
            buffered_after = state(page)
            landing_distance = math.hypot(buffered_after["attack_origin"][0] - buffered_after["jump_origin"][0], buffered_after["attack_origin"][2] - buffered_after["jump_origin"][2])
            check(buffered_after["jump_id"] == buffered_before["jump_id"] + 1 and buffered_after["attack_id"] == buffered_before["attack_id"] + 1, "Desktop J during K automatically executes one slash after the jump")
            check(abs(landing_distance - 5.70) < 0.035, "Buffered Web slash begins at the completed jump's landing point")
            check(buffered_after["sound_counts"]["slash"] == buffered_before["sound_counts"]["slash"] + 1 and not buffered_after["attack_buffered"], "Keyboard buffering emits one slash sound and consumes its input")
            snapshots["desktop_buffered"] = {"before": buffered_before, "after": buffered_after, "landing_distance": landing_distance}
            page.screenshot(path=str(ARTIFACTS / "combat_browser_desktop.png"))
            desktop.close()

            if args.desktop_only:
                browser.close()
                report = {"passed": sum(item["passed"] for item in checks), "failed": sum(not item["passed"] for item in checks), "checks": checks, "errors": errors, "snapshots": snapshots}
                (ARTIFACTS / "combat-browser-audio-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
                return 1 if errors or report["failed"] else 0

            mobile = browser.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=1, is_mobile=True, has_touch=True)
            phone = load(mobile)
            first = state(phone)
            bx, by = first["attack_button"]
            check(260 < bx < 380 and 600 < by < 790 and 40 <= first["attack_radius"] <= 65, "Portrait slash icon is visible and finger-sized")
            jx, jy = first["jump_button"]
            check(260 < jx < 380 and 480 < jy < 660 and 40 <= first["jump_radius"] <= 65, "Portrait jump icon is visible above the slash icon")
            check(math.hypot(jx - bx, jy - by) > first["jump_radius"] + first["attack_radius"] and math.hypot(jx - first["stick_center"][0], jy - first["stick_center"][1]) > first["jump_radius"] + first["stick_radius"] + 16, "Portrait jump icon does not overlap the slash button or joystick")
            check(phone.evaluate("document.documentElement.scrollHeight <= innerHeight + 1"), "Portrait game stays within the phone viewport")
            cdp = mobile.new_cdp_session(phone)

            def touches(kind, points):
                cdp.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": [
                    {"id": index, "x": x, "y": y, "radiusX": 5, "radiusY": 5, "force": 1}
                    for index, x, y in points
                ]})

            x, y = first["stick_center"]
            radius = first["stick_radius"]
            touches("touchStart", [(1, x + radius * 0.7, y)])
            wait_state(phone, "s.touch >= 0 && s.joystick[0] > 0.5")
            before = state(phone)
            touches("touchStart", [(1, x + radius * 0.7, y), (2, bx, by)])
            wait_state(phone, "s.attack_id > arg", before["attack_id"])
            during = state(phone)
            check(during["touch"] == before["touch"] and during["joystick"][0] > 0.5, "Second finger attacks while the first keeps joystick control")
            touches("touchMove", [(1, x + radius * 0.7, y)])
            touches("touchCancel", [])
            wait_state(phone, "s.attack_state === 'idle' && s.touch === -1")
            after = state(phone)
            check(after["attack_id"] == before["attack_id"] + 1, "Touch press performs one slash without a duplicate simulated mouse attack")
            check(math.hypot(*after["joystick"]) < 0.01, "Canceled touches release the joystick after the attack")
            snapshots["portrait"] = {"before": before, "during": during, "after": after}
            phone.mouse.click(390 - 78, 844 - 46)
            wait_state(phone, "Math.abs(s.position[0]) < 0.01 && Math.abs(s.position[2] - 3) < 0.01 && s.attack_state === 'idle'")
            first_jump = state(phone)
            jx, jy = first_jump["jump_button"]
            touches("touchStart", [(3, x + radius * 0.7, y)])
            wait_state(phone, "s.touch >= 0 && s.joystick[0] > 0.5")
            jump_before = state(phone)
            touches("touchStart", [(3, x + radius * 0.7, y), (4, jx, jy)])
            wait_state(phone, "s.jump_id > arg", jump_before["jump_id"])
            jump_during = state(phone)
            check(jump_during["touch"] == jump_before["touch"] and jump_during["joystick"][0] > 0.5, "Second finger jumps while the first keeps joystick control")
            touches("touchMove", [(3, x + radius * 0.7, y)])
            touches("touchCancel", [])
            wait_state(phone, "s.attack_state === 'idle' && s.touch === -1")
            jump_after = state(phone)
            check(jump_after["jump_id"] == jump_before["jump_id"] + 1 and jump_after["attack_id"] == jump_before["attack_id"], "Touch jump fires once without a simulated mouse duplicate or slash")
            check(math.hypot(*jump_after["joystick"]) < 0.01 and abs(jump_after["jump_height"]) < 0.001, "Canceled touches release the joystick and the jump lands")
            snapshots["portrait_jump"] = {"before": jump_before, "during": jump_during, "after": jump_after}
            phone.mouse.click(390 - 78, 844 - 46)
            wait_state(phone, "Math.abs(s.position[0]) < 0.01 && Math.abs(s.position[2] - 3) < 0.01 && s.attack_state === 'idle'")
            touches("touchStart", [(6, x + radius * 0.7, y)])
            wait_state(phone, "s.touch >= 0 && s.joystick[0] > 0.5")
            buffered_before = state(phone)
            touches("touchStart", [(6, x + radius * 0.7, y), (7, jx, jy)])
            touches("touchStart", [(6, x + radius * 0.7, y), (7, jx, jy), (8, bx, by)])
            wait_state(phone, "s.attack_buffered || s.attack_id > arg", buffered_before["attack_id"])
            buffered_during = state(phone)
            check(buffered_during["touch"] == buffered_before["touch"] and buffered_during["joystick"][0] > 0.5, "Touch slash buffering preserves the joystick's controlling finger")
            touches("touchCancel", [])
            wait_state(phone, "s.attack_id > arg && s.attack_state === 'idle' && s.touch === -1", buffered_before["attack_id"])
            buffered_after = state(phone)
            check(buffered_after["jump_id"] == buffered_before["jump_id"] + 1 and buffered_after["attack_id"] == buffered_before["attack_id"] + 1, "Jump then slash icon queues exactly one attack after landing")
            check(buffered_after["sound_counts"]["slash"] == buffered_before["sound_counts"]["slash"] + 1 and not buffered_after["attack_buffered"] and math.hypot(*buffered_after["joystick"]) < 0.01, "Canceling touch after buffering still completes one slash and clears the controls")
            snapshots["portrait_buffered"] = {"before": buffered_before, "during": buffered_during, "after": buffered_after}
            phone.screenshot(path=str(ARTIFACTS / "combat_browser_portrait.png"))
            phone.set_viewport_size({"width": 844, "height": 390})
            wait_state(phone, "s.attack_button[0] > 680 && s.attack_button[1] < 300")
            landscape = state(phone)
            check(700 < landscape["attack_button"][0] < 830 and 120 < landscape["attack_button"][1] < 300, "Landscape slash button repositions within the phone viewport")
            jx, jy = landscape["jump_button"]
            check(570 < jx < 720 and 120 < jy < 300 and math.hypot(jx - landscape["attack_button"][0], jy - landscape["attack_button"][1]) > landscape["jump_radius"] + landscape["attack_radius"], "Landscape jump and slash icons fit side by side without overlapping")
            snapshots["landscape"] = landscape
            phone.screenshot(path=str(ARTIFACTS / "combat_browser_landscape.png"))
            mobile.close()
            browser.close()
    except Exception as error:
        errors.append(str(error))
    report = {"url": args.url, "passed": sum(item["passed"] for item in checks), "failed": sum(not item["passed"] for item in checks), "checks": checks, "errors": errors, "snapshots": snapshots}
    (ARTIFACTS / "combat-browser-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key not in ("checks", "snapshots")}), flush=True)
    return 1 if errors or report["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
