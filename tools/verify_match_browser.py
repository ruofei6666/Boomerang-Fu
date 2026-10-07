"""Verify the exported lobby, both scoring modes, bot jumps and responsive layout."""

import argparse
import json
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"
STATE_JS = "JSON.parse(document.getElementById('canvas').getAttribute('data-game-state') || 'null')"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8060")
    parser.add_argument("--software-rendering", action="store_true")
    args = parser.parse_args()
    ARTIFACTS.mkdir(exist_ok=True)
    checks, errors, snapshots = [], [], {}

    def check(condition, description):
        checks.append({"check": description, "passed": bool(condition)})
        print(("PASS: " if condition else "FAIL: ") + description, flush=True)

    def state(page):
        return page.evaluate(STATE_JS)

    def wait(page, expression, argument=None):
        try:
            page.wait_for_function(
                "arg => { const s = " + STATE_JS + "; return s && (" + expression + "); }",
                arg=argument, timeout=30000,
            )
        except Exception:
            snapshots["timeout"] = {"expression": expression, "state": state(page)}
            raise

    def frames(page, count):
        wait(page, "s.physics_frame >= arg", state(page)["physics_frame"] + count)

    def load(context):
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
        page.goto(args.url.rstrip("/") + "/?verify=1&match_testing=1", wait_until="networkidle", timeout=60000)
        if page.locator("#pwa-dialog").evaluate("dialog => dialog.open"):
            page.locator("#pwa-continue").click()
        wait(page, "s.match && s.match.phase === 'lobby'")
        frames(page, 6)
        page.evaluate("document.getElementById('canvas').setAttribute('data-match-scripted', '1')")
        return page

    def click(page, control, mobile=False, seat=None):
        controls = state(page)["match"]["controls"]
        rect = controls[control] if seat is None else controls[control][seat]
        x, y, width, height = rect
        if mobile:
            page.touchscreen.tap(x + width / 2, y + height / 2)
        else:
            page.mouse.click(x + width / 2, y + height / 2)

    def choose(page, control, index, mobile=False, seat=None):
        if seat is not None:
            # All six selectors remain available through the participant scroll.
            for _ in range(5):
                controls = state(page)["match"]["controls"]
                x, y, width, height = controls["roles"][seat]
                sx, sy, sw, sh = controls["participants"]
                if sy <= y and y + height <= sy + sh:
                    break
                page.mouse.move(sx + sw / 2, sy + sh / 2)
                page.mouse.wheel(0, 170 if y + height > sy + sh else -170)
                frames(page, 8)
        click(page, control, mobile, seat)
        wait(page, "s.match.controls.popup.visible")
        x, y = state(page)["match"]["controls"]["popup"]["items"][index]
        if mobile:
            page.touchscreen.tap(x, y)
        else:
            page.mouse.click(x, y)
        if seat is None:
            field = "scoring_mode" if control == "scoring" else "difficulty"
            wait(page, f"s.match.{field} === arg", index)
        else:
            wait(page, "s.match.roles[arg[0]] === arg[1]", [seat, index])

    def eliminate(page, seats):
        page.evaluate("command => document.getElementById('canvas').setAttribute('data-match-command', JSON.stringify(command))", {"action": "eliminate", "seats": seats})

    def strike(page, attacker, targets):
        # Stage a real swing; Combat performs collision checks, kills and scoring.
        page.evaluate("command => document.getElementById('canvas').setAttribute('data-match-command', JSON.stringify(command))", {"action": "strike", "attacker": attacker, "targets": targets})
        wait(page, "s.match.phase === 'match_over' || arg.every(seat => !s.match.actors[seat].alive)", targets)

    def on_screen(rect, width, height):
        x, y, rw, rh = rect
        return rw > 0 and rh > 0 and x >= -1 and y >= -1 and x + rw <= width + 1 and y + rh <= height + 1

    report_path = ARTIFACTS / "match-browser-verification.json"
    try:
        with sync_playwright() as playwright:
            launch_args = ["--autoplay-policy=no-user-gesture-required"]
            if args.software_rendering:
                launch_args += ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
            browser = playwright.chromium.launch(channel="msedge", headless=True, args=launch_args)
            desktop = browser.new_context(viewport={"width": 1440, "height": 810})
            page = load(desktop)
            first = state(page)["match"]
            check(first["bot_count"] == 3 and first["difficulty"] == 1, "Browser opens lobby with three normal bots")
            check(first["scoring_mode"] == 0 and "最后存活者" in first["rules"], "Web settings default to survival scoring with its matching instructions")
            check(all(not actor["round_active"] for actor in first["actors"]), "Browser lobby pauses all character actions")
            page.screenshot(path=str(ARTIFACTS / "match_lobby_desktop.png"))
            for expected in [4, 5]:
                click(page, "plus")
                wait(page, "s.match.bot_count === arg", expected)
            check(state(page)["match"]["bot_count"] == 5, "Desktop count buttons configure five bots")
            choose(page, "difficulty", 2)
            roles = [3, 0, 1, 2, 4, 5]
            for seat, role in enumerate(roles):
                choose(page, "roles", role, seat=seat)
            check(state(page)["match"]["roles"] == roles, "Desktop dropdowns set every player and bot role")
            click(page, "start")
            wait(page, "s.match.phase === 'playing' && s.match.actors.length === 6")
            started = state(page)["match"]
            check(started["difficulty"] == 2 and started["actors"][0]["role"] == 3 and started["scores"] == [0] * 6, "Start runs a six-role hard match with carrot player and zero scores")
            check(all(actor["attack_state"] == "idle" and actor["throw_id"] == 0 for actor in started["actors"]), "Scripted scoring scenarios start before autonomous attacks or throws")
            starts = started["actors"]
            distances = [((a["position"][0] - b["position"][0]) ** 2 + (a["position"][2] - b["position"][2]) ** 2) ** 0.5 for i, a in enumerate(starts) for b in starts[i + 1:]]
            check(min(distances) > 5, "Web-exported actors start distributed across the arena")
            eliminate(page, [1, 2, 3, 4, 5])
            wait(page, "s.match.survivor_time > 0 && s.match.survivor_time < 0.8")
            check(state(page)["match"]["scores"] == [0] * 6, "Web sole survivor has no early point during the one-second hold")
            wait(page, "s.match.phase === 'scores'")
            check(state(page)["match"]["scores"] == [1, 0, 0, 0, 0, 0], "Web score screen gives exactly one point to the survivor")
            frames(page, 75)
            check(state(page)["match"]["phase"] == "scores" and state(page)["match"]["round"] == 1, "Web score screen waits for the next-round button")
            page.screenshot(path=str(ARTIFACTS / "match_scores_desktop.png"))
            click(page, "next")
            wait(page, "s.match.phase === 'playing' && s.match.round === 2")
            check(all(actor["alive"] for actor in state(page)["match"]["actors"]), "Web next-round button revives every participant")
            eliminate(page, list(range(6)))
            wait(page, "s.match.phase === 'scores'")
            check(state(page)["match"]["winner"] == -1 and state(page)["match"]["scores"] == [1, 0, 0, 0, 0, 0], "Web all-dead round keeps every accumulated score")
            for point in range(2, 11):
                click(page, "next")
                wait(page, "s.match.phase === 'playing'")
                eliminate(page, [1, 2, 3, 4, 5])
                wait(page, "s.match.phase === 'scores' || s.match.phase === 'match_over'")
                round_state = state(page)
                if round_state["match"]["scores"][0] != point:
                    snapshots["ten_point_mismatch"] = round_state
                    raise AssertionError(
                        f"Unexpected score during ten-point match: expected {point}, "
                        f"got {round_state['match']['scores']}, "
                        f"winner {round_state['match']['winner']}"
                    )
            check(state(page)["match"]["phase"] == "match_over" and state(page)["match"]["champion"] == 0, "Web tenth point opens match victory and identifies the champion")
            page.screenshot(path=str(ARTIFACTS / "match_victory_desktop.png"))
            click(page, "next")
            wait(page, "s.match.phase === 'lobby'")
            check(state(page)["match"]["roles"] == roles, "Web play-again returns to settings and keeps role choices")
            snapshots["desktop"] = state(page)["match"]
            choose(page, "scoring", 1)
            check("每击杀" in state(page)["match"]["rules"], "Desktop scoring dropdown selects kills and updates the rules")
            click(page, "start")
            wait(page, "s.match.phase === 'playing'")
            await_score = [2, 0, 0, 0, 0, 0]
            strike(page, 0, [2, 3])
            wait(page, "s.match.scores[0] === 2")
            check(state(page)["match"]["scores"] == await_score, "Web real multi-target swing awards the player two kill points")
            frames(page, 20)
            check(state(page)["match"]["scores"] == await_score, "Repeated Web hit resolution does not score dead targets again")
            strike(page, 1, [0])
            wait(page, "s.match.scores[1] === 1")
            check(state(page)["match"]["scores"] == [2, 1, 0, 0, 0, 0], "Web bot gets its kill point while the eliminated player retains two")
            strike(page, 1, [4, 5])
            wait(page, "s.match.phase === 'scores'")
            kill_round = state(page)["match"]
            check(kill_round["scores"] == [2, 3, 0, 0, 0, 0] and kill_round["round_points"] == [2, 3, 0, 0, 0, 0], "Web kill scoreboard displays every seat's gains without a survival bonus")
            check("不额外加分" in kill_round["result"], "Web kill-score result explains the lack of a survivor bonus")
            page.screenshot(path=str(ARTIFACTS / "match_kills_desktop.png"))
            click(page, "next")
            wait(page, "s.match.phase === 'playing'")
            check(state(page)["match"]["scores"] == [2, 3, 0, 0, 0, 0] and state(page)["match"]["round_points"] == [0] * 6, "Web next kill round retains totals and resets per-round gains")
            eliminate(page, list(range(6)))
            wait(page, "s.match.phase === 'scores'")
            check(state(page)["match"]["scores"] == [2, 3, 0, 0, 0, 0] and "击杀分保留" in state(page)["match"]["result"], "Web all-dead kill round keeps the earned cumulative points")
            click(page, "lobby")
            wait(page, "s.match.phase === 'lobby'")
            check(state(page)["match"]["scoring_mode"] == 1, "Web return to settings remembers the scoring selection")
            for expected in [4, 3, 2]:
                click(page, "minus")
                wait(page, "s.match.bot_count === arg", expected)
            click(page, "start")
            wait(page, "s.match.phase === 'playing'")
            check(state(page)["match"]["scores"] == [0, 0, 0], "Web new kill match resets all seat totals")
            for point in range(1, 11):
                strike(page, 0, [1, 2] if point == 10 else [1])
                if point < 10:
                    eliminate(page, [2])
                    wait(page, "s.match.phase === 'scores'")
                    click(page, "next")
                    wait(page, "s.match.phase === 'playing'")
            wait(page, "s.match.phase === 'match_over'")
            kill_victory = state(page)["match"]
            check(kill_victory["scores"] == [10, 0, 0] and kill_victory["champion"] == 0 and sum(actor["alive"] for actor in kill_victory["actors"]) == 2, "Web tenth kill wins immediately and stops additional hits while an opponent still lives")
            check("击杀计分" in kill_victory["result"], "Web match victory reports kill scoring")
            page.screenshot(path=str(ARTIFACTS / "match_kills_victory_desktop.png"))
            snapshots["kill_victory"] = kill_victory
            click(page, "next")
            wait(page, "s.match.phase === 'lobby'")
            choose(page, "scoring", 0)
            for expected in [3, 4, 5]:
                click(page, "plus")
                wait(page, "s.match.bot_count === arg", expected)
            # Run real FFA without injected actions; observe autonomous NPC jumps.
            page.evaluate("document.getElementById('canvas').removeAttribute('data-match-scripted')")
            snapshots["bot_jumps"] = {}
            for difficulty in range(3):
                choose(page, "difficulty", difficulty)
                click(page, "start")
                wait(page, "s.match.phase === 'playing'")
                observed = False
                for attempt in range(3):
                    # Keep the completed jump counter: a bot can land or be hit
                    # between polling the canvas and fetching its next snapshot.
                    wait(page, "s.match.phase !== 'playing' || s.wanderers.some(bot => bot.jump_id > 0)")
                    current = state(page)
                    observed = any(bot["jump_id"] > 0 and bot["jump_reason"] in ("chase", "dodge") for bot in current["wanderers"])
                    if observed or current["match"]["phase"] != "scores":
                        break
                    if attempt < 2:
                        click(page, "next")
                        wait(page, "s.match.phase === 'playing'")
                check(observed, f"Web difficulty {difficulty} bots autonomously jump during real FFA")
                actor_names = {"Player" if actor["seat"] == 0 else f"Bot{actor['seat']}" for actor in current["match"]["actors"]}
                check(all(
                    set(bot.get("dodges_by_opponent", {})) == actor_names - {bot["name"]}
                    and all(isinstance(count, int) and 0 <= count <= 2 for count in bot["dodges_by_opponent"].values())
                    for bot in current["wanderers"]
                ), f"Web difficulty {difficulty} exposes separate dodge counts capped at two for every opponent")
                snapshots["bot_jumps"][str(difficulty)] = current["wanderers"]
                page.screenshot(path=str(ARTIFACTS / f"ai_jump_web_{difficulty}.png"))
                click(page, "settings" if state(page)["match"]["phase"] == "playing" else "lobby")
                wait(page, "s.match.phase === 'lobby'")
            desktop.close()

            mobile = browser.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=3, is_mobile=True, has_touch=True)
            phone = load(mobile)
            page_match = state(phone)["match"]
            check(on_screen(page_match["controls"]["panel"], 390, 844) and on_screen(page_match["controls"]["start"], 390, 844), "Portrait settings panel and start button fit on screen")
            check(on_screen(page_match["controls"]["scoring"], 390, 844), "Portrait scoring selector fits on screen")
            choose(phone, "scoring", 1, True)
            check(state(phone)["match"]["scoring_mode"] == 1 and "每击杀" in state(phone)["match"]["rules"], "Portrait touch can choose kill scoring and read the matching rules")
            choose(phone, "scoring", 0, True)
            for expected in [4, 5]:
                click(phone, "plus", True)
                wait(phone, "s.match.bot_count === arg", expected)
            choose(phone, "difficulty", 0, True)
            choose(phone, "roles", 2, True, 0)
            choose(phone, "roles", 1, True, 5)
            check(state(phone)["match"]["roles"][0] == 2 and state(phone)["match"]["roles"][5] == 1, "Touch opens role selectors for both player and the last scrolled bot")
            phone.screenshot(path=str(ARTIFACTS / "match_lobby_portrait.png"))
            click(phone, "start", True)
            wait(phone, "s.match.phase === 'playing'")
            check(state(phone)["match"]["difficulty"] == 0 and state(phone)["match"]["actors"][0]["role"] == 2, "Touch start enters an easy match with the pumpkin player")
            eliminate(phone, list(range(6)))
            wait(phone, "s.match.phase === 'scores'")
            check(state(phone)["match"]["scores"] == [0] * 6, "Portrait drawn round displays unchanged scores")
            controls = state(phone)["match"]["controls"]
            check(on_screen(controls["panel"], 390, 844) and on_screen(controls["next"], 390, 844) and on_screen(controls["lobby"], 390, 844), "Portrait scoreboard and both continuation buttons fit on screen")
            phone.screenshot(path=str(ARTIFACTS / "match_scores_portrait.png"))
            click(phone, "next", True)
            wait(phone, "s.match.phase === 'playing' && s.match.round === 2")
            eliminate(phone, [0, 2, 3, 4, 5])
            wait(phone, "s.match.phase === 'scores'")
            check(state(phone)["match"]["scores"] == [0, 1, 0, 0, 0, 0], "Mobile scoreboard can award a bot after player elimination")
            phone.set_viewport_size({"width": 844, "height": 390})
            frames(phone, 18)
            controls = state(phone)["match"]["controls"]
            check(on_screen(controls["panel"], 844, 390) and on_screen(controls["next"], 844, 390), "Rotated landscape scoreboard remains fully inside the screen")
            phone.screenshot(path=str(ARTIFACTS / "match_scores_landscape.png"))
            click(phone, "lobby", True)
            wait(phone, "s.match.phase === 'lobby'")
            frames(phone, 6)
            controls = state(phone)["match"]["controls"]
            check(on_screen(controls["panel"], 844, 390) and on_screen(controls["start"], 844, 390), "Landscape settings retain visible controls and start button")
            check(controls["participants"][3] > 120, "Compact landscape settings leave usable room for participant rows")
            check(on_screen(controls["scoring"], 844, 390), "Landscape scoring selector fits beside count and difficulty")
            choose(phone, "scoring", 1, True)
            phone.screenshot(path=str(ARTIFACTS / "match_lobby_landscape.png"))
            check(phone.evaluate("document.documentElement.scrollHeight <= innerHeight + 1"), "The game page itself does not scroll in landscape")
            click(phone, "start", True)
            wait(phone, "s.match.phase === 'playing'")
            strike(phone, 0, [1, 2])
            wait(phone, "s.match.scores[0] === 2")
            eliminate(phone, [3, 4, 5])
            wait(phone, "s.match.phase === 'scores'")
            check(state(phone)["match"]["scores"] == [2, 0, 0, 0, 0, 0], "Touch-started kill match awards two actual kills and no survivor bonus")
            phone.screenshot(path=str(ARTIFACTS / "match_kills_landscape.png"))
            phone.set_viewport_size({"width": 390, "height": 844})
            frames(phone, 18)
            controls = state(phone)["match"]["controls"]
            check(on_screen(controls["panel"], 390, 844) and on_screen(controls["next"], 390, 844), "Kill scoreboard remains usable after rotating back to portrait")
            phone.screenshot(path=str(ARTIFACTS / "match_kills_portrait.png"))
            snapshots["mobile"] = state(phone)["match"]
            mobile.close()
            browser.close()
    except Exception as error:
        report_path.write_text(json.dumps({"status": "incomplete", "error": str(error), "checks": checks, "console_errors": errors, "snapshots": snapshots}, ensure_ascii=False, indent=2), encoding="utf-8")
        raise
    check(not errors, "Match Web build has no browser or Godot script errors")
    report = {"passed": sum(c["passed"] for c in checks), "failed": sum(not c["passed"] for c in checks), "checks": checks, "console_errors": errors, "snapshots": snapshots,
              "validation": "Browser touch simulation; scripted scoring scenarios freeze actor physics only in the dedicated verification URL before injected eliminations or staged real strikes. Hits, kill attribution, timing, scoring, match transitions and UI use the real game. The separate three-difficulty FFA checks enable autonomous actor physics. Physical phone not tested."}
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f'MATCH_BROWSER_VERIFICATION: {report["passed"]} passed, {report["failed"]} failed', flush=True)
    raise SystemExit(1 if report["failed"] else 0)


if __name__ == "__main__":
    main()
