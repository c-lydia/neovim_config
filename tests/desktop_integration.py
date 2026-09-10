#!/usr/bin/env python3
"""Check real dconf/GSettings and restore under a private D-Bus session."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PROFILE = "52fbb813-8aef-43ac-95dd-10a11f532fa9"


def run(*args):
    return subprocess.run(list(map(str, args)), check=True, capture_output=True, text=True, timeout=30).stdout.strip()


def session():
    home = Path(os.environ["WORKBENCH_INSTALL_HOME"])
    data = Path(os.environ["XDG_DATA_HOME"])
    state = Path(os.environ["XDG_STATE_HOME"])
    framework = home / ".oh-my-zsh"
    framework.mkdir(parents=True)
    (framework / "oh-my-zsh.sh").write_text("git_prompt_info() { :; }\nvirtualenv_prompt_info() { :; }\n")
    terminal = "ptyxis" if shutil.which("ptyxis") else "gnome-terminal"
    key = "/org/gnome/Ptyxis/default-profile-uuid" if terminal == "ptyxis" else "/org/gnome/terminal/legacy/profiles:/list"
    assert run("dconf", "read", key) == "", "Settings database is not isolated"
    print(run(sys.executable, ROOT / "scripts/install-desktop.py", "--terminal", terminal, "--no-downloads"))
    assert PROFILE in run("dconf", "read", key)
    font_key = "/org/gnome/Ptyxis/font-name" if terminal == "ptyxis" else f"/org/gnome/terminal/legacy/profiles:/:{PROFILE}/font"
    assert run("dconf", "read", font_key) == "'DejaVu Sans Mono 10'"
    for entry in (data / "applications").glob("*.desktop"):
        run("desktop-file-validate", entry)
    manifest = next((state / "nvim-workbench/backups").glob("*/manifest.json"))
    assert json.loads(manifest.read_text())["settings"]
    print(run(sys.executable, ROOT / "scripts/install-desktop.py", "--restore", manifest))
    assert run("dconf", "read", key) == ""
    assert run("dconf", "read", font_key) == ""
    print(f"DESKTOP_SETTINGS_OK terminal={terminal}")


if __name__ == "__main__":
    if "--session" in sys.argv:
        session()
    else:
        required = ("dbus-run-session", "dconf", "gsettings", "zsh", "desktop-file-validate")
        missing = [name for name in required if not shutil.which(name)]
        if missing:
            sys.exit("Missing desktop test dependencies: " + ", ".join(missing))
        if not (shutil.which("ptyxis") or shutil.which("gnome-terminal")):
            sys.exit("Install Ptyxis or GNOME Terminal for this integration test")
        with tempfile.TemporaryDirectory(prefix="nvim-desktop-integration-") as temp:
            base = Path(temp)
            runtime = base / "runtime"
            runtime.mkdir(mode=0o700)
            env = {**os.environ, "WORKBENCH_INSTALL_HOME": str(base / "home 'quoted' $directory"),
                   "XDG_CONFIG_HOME": str(base / "config"), "XDG_DATA_HOME": str(base / "data"),
                   "XDG_STATE_HOME": str(base / "state"), "XDG_CACHE_HOME": str(base / "cache"),
                   "XDG_RUNTIME_DIR": str(runtime), "PYTHONDONTWRITEBYTECODE": "1"}
            result = subprocess.run(["dbus-run-session", "--", sys.executable, __file__, "--session"], env=env)
            sys.exit(result.returncode)
