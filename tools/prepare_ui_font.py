"""Create a small CJK UI font from Google's OFL-licensed Noto Sans SC."""

from pathlib import Path
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "assets" / "fonts"
CACHE = ROOT / ".cache"


def main():
    CACHE.mkdir(exist_ok=True)
    DESTINATION.mkdir(parents=True, exist_ok=True)
    source = CACHE / "NotoSansSC.ttf"
    base = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/"
    if not source.exists():
        urllib.request.urlretrieve(base + "NotoSansSC%5Bwght%5D.ttf", source)
    if not (DESTINATION / "OFL.txt").exists():
        urllib.request.urlretrieve(base + "OFL.txt", DESTINATION / "OFL.txt")
    characters = "".join(chr(code) for code in range(32, 127))
    for file in [*sorted((ROOT / "scripts").glob("*.gd")), ROOT / "project.godot", ROOT / "tools" / "map_builder.gd"]:
        characters += file.read_text(encoding="utf-8")
    font = TTFont(source)
    if "fvar" in font:
        font = instantiateVariableFont(font, {"wght": 400}, inplace=True)
    options = subset.Options()
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    options.name_legacy = True
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=characters)
    subsetter.subset(font)
    target = DESTINATION / "noto_sans_sc_ui.ttf"
    font.save(target)
    print(f"UI_FONT_READY: {target} ({target.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
