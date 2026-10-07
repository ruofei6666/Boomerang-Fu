"""Export and verify an unsigned Xcode handoff ZIP; never claim an IPA build."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile

from fetch_web_template import fetch_template


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build" / "ios"
XCODE = OUTPUT / "Xcode"
NAME = "BoomerangArena"
VERSION = "4.7.2"
BUNDLE_ID = "io.github.ruofei6666.boomerangarena"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run_logged(command, log_name, cwd=ROOT):
    log = ROOT / "artifacts" / log_name
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
    content = log.read_text(encoding="utf-8", errors="replace")
    if result.returncode != 0 or re.search(r"(?m)^(?:SCRIPT ERROR|ERROR):", content):
        raise RuntimeError(f"Command failed; see {log}\n" + "\n".join(content.splitlines()[-25:]))
    return log


def find_godot(requested):
    candidates = [requested, os.environ.get("GODOT_PATH"), shutil.which("godot")]
    if os.name == "nt":
        candidates.append(str(Path(os.environ["LOCALAPPDATA"]) / "Programs" / "Godot" / VERSION /
                              f"Godot_v{VERSION}-stable_win64_console.exe"))
    else:
        candidates.append("/Applications/Godot.app/Contents/MacOS/Godot")
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(Path(candidate).resolve())
    raise RuntimeError("Godot 4.7.2 not found; pass --godot /path/to/godot")


def validate_xcode():
    checks = []

    def check(condition, name):
        if not condition:
            raise RuntimeError("Xcode handoff validation failed: " + name)
        checks.append(name)

    pbx_path = XCODE / f"{NAME}.xcodeproj" / "project.pbxproj"
    pbx = pbx_path.read_text(encoding="utf-8")
    check("DEVELOPMENT_TEAM = UNSIGNED00;" in pbx, "Team ID is explicitly unsigned placeholder")
    check(f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};" in pbx, "Bundle identifier configured")
    check('CODE_SIGN_STYLE = "Automatic";' in pbx, "Xcode automatic signing is configured")
    check("TARGETED_DEVICE_FAMILY = 1,2;" in pbx or 'TARGETED_DEVICE_FAMILY = "1,2";' in pbx,
          "iPhone and iPad targets configured")
    check('ARCHS = "arm64";' in pbx, "ARM64 device target configured")
    check('MARKETING_VERSION = "0.1.0";' in pbx or "MARKETING_VERSION = 0.1.0;" in pbx,
          "Application version configured")
    check(not re.search(r"\$(team_id|bundle_identifier|binary|os_deployment_target|godot_apple_embedded)", pbx),
          "Exporter template placeholders resolved")
    check(not re.search(r"[A-Za-z]:[\\/]", pbx), "Xcode project has no Windows absolute paths")
    scheme = XCODE / f"{NAME}.xcodeproj/xcshareddata/xcschemes/{NAME}.xcscheme"
    scheme_xml = ET.parse(scheme).getroot()
    check(scheme_xml.find("ArchiveAction").get("buildConfiguration") == "Release",
          "Shared scheme supports Release archive")

    info_path = XCODE / NAME / f"{NAME}-Info.plist"
    with info_path.open("rb") as stream:
        info = plistlib.load(stream)
    check(info["CFBundleIdentifier"] == "$(PRODUCT_BUNDLE_IDENTIFIER)",
          "Bundle identifier follows Xcode build settings")
    for key in ("UISupportedInterfaceOrientations", "UISupportedInterfaceOrientations~ipad"):
        check(len(info[key]) == 4, key + " includes landscape and portrait")
    with (XCODE / NAME / f"{NAME}.entitlements").open("rb") as stream:
        check(isinstance(plistlib.load(stream), dict), "Entitlements are valid plist")
    with (XCODE / "PrivacyInfo.xcprivacy").open("rb") as stream:
        privacy = plistlib.load(stream)
        check(privacy.get("NSPrivacyTracking") is False, "Privacy manifest disables tracking")

    for framework in (f"{NAME}.xcframework", "MoltenVK.xcframework"):
        directory = XCODE / framework
        with (directory / "Info.plist").open("rb") as stream:
            libraries = plistlib.load(stream)["AvailableLibraries"]
        ios_libraries = [item for item in libraries if item["SupportedPlatform"] == "ios"]
        check(any(item.get("SupportedPlatformVariant") is None and "arm64" in item["SupportedArchitectures"]
                  for item in ios_libraries), framework + " contains iPhone ARM64 slice")
        check(any(item.get("SupportedPlatformVariant") == "simulator" for item in ios_libraries),
              framework + " contains simulator slice")
        for item in ios_libraries:
            library = directory / item["LibraryIdentifier"] / item["LibraryPath"]
            check(library.is_file() and library.stat().st_size > 1024,
                  framework + "/" + item["LibraryIdentifier"] + " binary is present")

    icon_directory = XCODE / NAME / "Images.xcassets" / "AppIcon.appiconset"
    contents = json.loads((icon_directory / "Contents.json").read_text(encoding="utf-8"))
    icons = [item for item in contents["images"] if item.get("filename")]
    check(len(icons) >= 16 and all((icon_directory / item["filename"]).is_file() for item in icons),
          "All exported application icons are present")
    with (icon_directory / "Icon-1024.png").open("rb") as stream:
        header = stream.read(24)
    check(header[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", header[16:24]) == (1024, 1024),
          "App Store icon is a 1024 by 1024 PNG")
    check((XCODE / NAME / "Launch Screen.storyboard").is_file(), "Launch storyboard is present")
    pack = XCODE / f"{NAME}.pck"
    with pack.open("rb") as stream:
        check(stream.read(4) == b"GDPC", "Game resource pack has valid Godot PCK header")
    check(pack.stat().st_size > 1024, "Game resource pack is nonempty")
    check(not list(XCODE.rglob("*.ipa")), "No IPA or signing completion is claimed")
    deployment = re.search(r"IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);", pbx).group(1)
    return checks, deployment


def source_files():
    paths = [ROOT / name for name in ("project.godot", "export_presets.cfg", "README.md", ".gitignore", ".gitattributes")]
    for directory in ("assets", "scenes", "scripts", "tools", "web", "ios"):
        for path in (ROOT / directory).rglob("*"):
            if path.is_file() and "__pycache__" not in path.parts and path.suffix not in {".pyc", ".tmp"}:
                paths.append(path)
    return sorted(paths)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--skip-export", action="store_true", help="Package the Xcode export just generated in this session")
    args = parser.parse_args()
    godot = find_godot(args.godot)
    engine = subprocess.check_output([godot, "--version"], text=True).strip()
    if not engine.startswith(VERSION + ".stable"):
        raise RuntimeError(f"Expected Godot {VERSION}.stable, got {engine}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if not args.skip_export:
        fetch_template(VERSION, "ios.zip")
        XCODE.mkdir(parents=True, exist_ok=True)
        run_logged([godot, "--headless", "--editor", "--path", str(ROOT), "--import"], "ios-import.log")
        run_logged([godot, "--headless", "--path", str(ROOT), "--export-release", "iOS",
                    str(XCODE / f"{NAME}.xcodeproj")], "ios-export.log")
    checks, deployment = validate_xcode()
    startup_log = run_logged([godot, "--headless", "--main-pack", str(XCODE / f"{NAME}.pck"),
                              "--quit-after", "180", "--max-fps", "60"], "ios-pck-startup.log", cwd=OUTPUT)
    checks.append("Exported iOS PCK starts with Windows Godot headless without script errors")
    verification = {
        "engine": engine, "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "checks": checks, "failures": [], "xcode_compiled_on_macos": False, "iphone_tested": False,
    }
    verification_path = ROOT / "artifacts" / "ios-project-verification.json"
    verification_path.write_text(json.dumps(verification, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    entries = []
    for path in sorted(XCODE.rglob("*")):
        if path.is_file() and not path.relative_to(XCODE).parts[0].startswith("libgodot_camera.visionos"):
            entries.append((path, "Xcode/" + path.relative_to(XCODE).as_posix()))
    entries.extend((path, "GodotProject/" + path.relative_to(ROOT).as_posix()) for path in source_files())
    entries.extend([(ROOT / "ios" / "README.md", "README.md"), (ROOT / "ios" / "build-ipa.sh", "build-ipa.sh"),
                    (verification_path, "verification/ios-project-verification.json"),
                    (startup_log, "verification/ios-pck-startup.log"),
                    (ROOT / "artifacts" / "ios-export.log", "verification/ios-export.log")])
    regression_path = ROOT / "artifacts" / "verification.json"
    if regression_path.is_file():
        entries.append((regression_path, "verification/windows-scene-regression.json"))
    files = [{"path": name, "bytes": path.stat().st_size, "sha256": digest(path)} for path, name in entries]
    manifest = {
        "artifact_type": "unsigned_xcode_handoff", "engine": engine,
        "bundle_identifier": BUNDLE_ID, "app_version": "0.1.0", "build_number": "1",
        "minimum_ios_version_from_xcode": deployment, "team_id": "UNSIGNED00",
        "team_id_is_placeholder": True, "signed": False, "ipa_generated": False,
        "macos_build_tested": False, "ios_device_tested": False,
        "checked_at_utc": verification["checked_at_utc"], "checks": checks, "files": files,
    }
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    archive = OUTPUT / f"{NAME}-iOS-Xcode.zip"
    partial = archive.with_suffix(".zip.tmp")
    print(f"Packaging {len(entries)} files ({sum(item['bytes'] for item in files) / 1024**2:.1f} MiB uncompressed)", flush=True)
    with zipfile.ZipFile(partial, "w", zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as zipped:
        for path, name in entries:
            if any(part in {".git", ".env", ".venv", ".cache", ".firecrawl", "__pycache__"} for part in Path(name).parts):
                raise RuntimeError("Unexpected local-only file in handoff: " + name)
            if path.suffix in {".p12", ".pfx", ".mobileprovision", ".key"}:
                raise RuntimeError("Signing credentials must not be included in this handoff: " + name)
            item = zipfile.ZipInfo.from_file(path, name)
            item.create_system = 3
            mode = 0o755 if path.suffix == ".sh" else 0o644
            item.external_attr = (stat.S_IFREG | mode) << 16
            item.compress_type = zipfile.ZIP_DEFLATED
            with path.open("rb") as source, zipped.open(item, "w", force_zip64=True) as target:
                shutil.copyfileobj(source, target)
        zipped.writestr("manifest.json", manifest_bytes)
    print("Checking every ZIP entry against its SHA-256 manifest", flush=True)
    with zipfile.ZipFile(partial) as zipped:
        for item in files:
            with zipped.open(item["path"]) as stream:
                checksum = hashlib.file_digest(stream, "sha256").hexdigest()
            if checksum != item["sha256"] or zipped.getinfo(item["path"]).file_size != item["bytes"]:
                raise RuntimeError("ZIP content differs from manifest: " + item["path"])
        if zipped.read("manifest.json") != manifest_bytes:
            raise RuntimeError("Manifest content differs inside archive")
    partial.replace(archive)
    (OUTPUT / "manifest.json").write_bytes(manifest_bytes)
    checksum = digest(archive)
    archive.with_suffix(".zip.sha256").write_text(f"{checksum}  {archive.name}\n", encoding="utf-8")
    print(f"IOS_XCODE_HANDOFF_READY: {archive}")
    print(f"XCODE_CHECKS: {len(checks)} passed; macOS build and iPhone tests pending")
    print(f"ZIP_BYTES: {archive.stat().st_size}; SHA256: {checksum}")


if __name__ == "__main__":
    main()
