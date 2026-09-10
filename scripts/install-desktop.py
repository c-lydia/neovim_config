#!/usr/bin/env python3
"""Install the portable workbench desktop with file/settings backups."""

import argparse
import ast
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROFILE = "52fbb813-8aef-43ac-95dd-10a11f532fa9"
OMZ_REVISION = "4b657407c98bbc8830ae66c2ac7ff3d737c55a83"
TILING_SCHEMA = "org.gnome.shell.extensions.tiling-assistant"
TILING_UUIDS = ("tiling-assistant@ubuntu.com", "tiling-assistant@leleat-on-github")
PTYXIS_APPS = ("app.devsuite.Ptyxis", "org.gnome.Ptyxis")
FOCUS_UUID = "neon-workbench-focus@c-lydia"


def run(*args, check=True, env=None):
    return subprocess.run(list(map(str, args)), check=check, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, timeout=120)


def variant_list(value):
    return ast.literal_eval(re.sub(r"^@as\s+", "", value.strip()) or "[]")


def desktop_quote(value):
    # Desktop Exec syntax is not shell syntax. Percent expands field codes.
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%') + '"'


class Backup:
    def __init__(self, state):
        state.mkdir(parents=True, exist_ok=True)
        self.directory = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-"), dir=state))
        self.manifest = {"files": [], "settings": []}
        self.save()

    def save(self):
        path = self.directory / "manifest.json"
        path.write_text(json.dumps(self.manifest, indent=2) + "\n")
        path.chmod(0o600)

    def file(self, target, content, mode=0o644):
        target = Path(target)
        data = content.encode() if isinstance(content, str) else content
        if target.is_file() and not target.is_symlink() and target.read_bytes() == data and target.stat().st_mode & 0o777 == mode:
            return
        record = {"target": str(target), "kind": "absent"}
        if target.is_symlink():
            record.update(kind="symlink", link=os.readlink(target))
        elif target.exists():
            if not target.is_file():
                raise RuntimeError(f"Refusing to replace a directory: {target}")
            saved = self.directory / str(len(self.manifest["files"]))
            shutil.copy2(target, saved)
            record.update(kind="file", saved=str(saved), mode=target.stat().st_mode & 0o777)
        self.manifest["files"].append(record)
        self.save()
        target.parent.mkdir(parents=True, exist_ok=True)
        # Replace the link itself, never a file it points to.
        with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as stream:
            stream.write(data)
            temporary = Path(stream.name)
        temporary.chmod(mode)
        temporary.replace(target)

    def setting(self, get, set_value, reset, value):
        old = run(*get).stdout.strip()
        if old == value:
            return
        self.manifest["settings"].append({"old": old, "set": set_value, "reset": reset})
        self.save()
        run(*set_value, value)

    def dconf(self, key, value):
        self.setting(["dconf", "read", key], ["dconf", "write", key], ["dconf", "reset", key], value)

    def gsettings(self, prefix, schema, key, value):
        self.setting([*prefix, "get", schema, key], [*prefix, "set", schema, key],
                     [*prefix, "reset", schema, key], value)


def restore(path):
    manifest = json.loads(Path(path).read_text())
    for item in reversed(manifest["settings"]):
        run(*(item["set"] + [item["old"]] if item["old"] else item["reset"]))
    for item in reversed(manifest["files"]):
        target = Path(item["target"])
        if target.is_symlink() or target.is_file():
            target.unlink()
        if item["kind"] == "symlink":
            target.symlink_to(item["link"])
        elif item["kind"] == "file":
            shutil.copy2(item["saved"], target)
            target.chmod(item["mode"])
    print(f"Restored files and settings from {path}")


def choose_terminal(requested):
    if requested in ("ptyxis", "auto"):
        if shutil.which("ptyxis"):
            return "ptyxis", None
        if shutil.which("flatpak"):
            for app in PTYXIS_APPS:
                if run("flatpak", "info", app, check=False).returncode == 0:
                    return "ptyxis-flatpak", app
    if requested in ("gnome-terminal", "auto") and shutil.which("gnome-terminal"):
        return "gnome-terminal", None
    raise RuntimeError("Install Ptyxis first (native package or app.devsuite.Ptyxis from Flathub). "
                       "Use --terminal gnome-terminal only if you want that fallback.")


def ensure_omz(install_home, data, no_downloads):
    destination = data / "oh-my-zsh"
    if (destination / "oh-my-zsh.sh").is_file():
        return
    existing = install_home / ".oh-my-zsh"
    if (existing / "oh-my-zsh.sh").is_file():
        # Reuse the installed framework; custom themes/helpers are separate.
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.symlink_to(existing)
        return
    if no_downloads:
        raise RuntimeError("Oh My Zsh is missing; rerun without --no-downloads or install it first.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="omz-", dir=data) as temp:
        run("git", "init", temp)
        run("git", "-C", temp, "fetch", "--depth=1", "https://github.com/ohmyzsh/ohmyzsh.git", OMZ_REVISION)
        run("git", "-C", temp, "checkout", "--detach", "FETCH_HEAD")
        shutil.copytree(temp, destination)


def shell_version():
    if not shutil.which("gnome-shell"):
        return None
    match = re.search(r"(\d+)(?:\.(\d+))?", run("gnome-shell", "--version").stdout)
    if not match:
        return None
    return match[0] if match[1] == "3" else match[1]


def extension_metadata(info, version):
    selected = info.get("shell_version_map", {}).get(version)
    if not selected or info.get("uuid") != TILING_UUIDS[1]:
        raise RuntimeError(f"Tiling Assistant has no supported release for GNOME {version}")
    return ("https://extensions.gnome.org/download-extension/" + TILING_UUIDS[1]
            + ".shell-extension.zip?version_tag=" + str(int(selected["pk"])))


def ensure_tiling(data_home, no_downloads):
    version = shell_version()
    if not version:
        print("Tiling skipped: GNOME Shell was not detected.")
        return None
    system_roots = [Path(p) for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")]
    for base in [data_home, *system_roots]:
        for uuid in TILING_UUIDS:
            extension = base / "gnome-shell/extensions" / uuid
            metadata = extension / "metadata.json"
            if metadata.is_file() and version in json.loads(metadata.read_text()).get("shell-version", []):
                return uuid, extension
    if no_downloads:
        print(f"Tiling skipped: install Tiling Assistant for GNOME {version}, then rerun.")
        return None
    for command in ("gnome-extensions", "glib-compile-schemas"):
        if not shutil.which(command):
            raise RuntimeError(f"{command} is required to install Tiling Assistant")
    query = urllib.parse.urlencode({"pk": 3733, "shell_version": version})
    with urllib.request.urlopen("https://extensions.gnome.org/extension-info/?" + query, timeout=30) as response:
        info = json.load(response)
    with urllib.request.urlopen(extension_metadata(info, version), timeout=30) as response:
        archive = response.read()
    with tempfile.TemporaryDirectory(prefix="nvim-tiling-") as temp:
        path = Path(temp) / "extension.zip"
        path.write_bytes(archive)
        with zipfile.ZipFile(path) as bundle:
            metadata = json.loads(bundle.read("metadata.json"))
            if metadata.get("uuid") != TILING_UUIDS[1] or version not in metadata.get("shell-version", []):
                raise RuntimeError("Downloaded extension does not match this GNOME version")
        run("gnome-extensions", "install", path)
    directory = data_home / "gnome-shell/extensions" / TILING_UUIDS[1]
    if (directory / "schemas").is_dir() and not (directory / "schemas/gschemas.compiled").is_file():
        run("glib-compile-schemas", directory / "schemas")
    return TILING_UUIDS[1], directory


def shell_is_running():
    if not shutil.which("gdbus"):
        return False
    result = run("gdbus", "call", "--session", "--dest", "org.freedesktop.DBus",
                 "--object-path", "/org/freedesktop/DBus", "--method",
                 "org.freedesktop.DBus.NameHasOwner", "org.gnome.Shell", check=False)
    return result.returncode == 0 and "true" in result.stdout


def enable_extension(backup, uuid):
    enabled = variant_list(run("gsettings", "get", "org.gnome.shell", "enabled-extensions").stdout)
    if uuid not in enabled:
        backup.gsettings(["gsettings"], "org.gnome.shell", "enabled-extensions", repr([*enabled, uuid]))
    if not shell_is_running() or run("gnome-extensions", "enable", uuid, check=False).returncode:
        print(f"{uuid} is installed. Log out and back in to activate it.")


def install_focus_border(backup, data_home):
    version = shell_version()
    if version not in [str(v) for v in range(40, 51)]:
        print(f"Focus border unavailable: GNOME {version or 'not detected'} is outside the supported 40–50 range.")
        return
    modern = int(version) >= 45
    assets = ROOT / "desktop/focus-border"
    content = (assets / ("modern.js" if modern else "legacy.js")).read_text() + "\n"
    content += (assets / "controller.js").read_text()
    content += "\nexport default FocusBorder;\n" if modern else "\nfunction init() { return new FocusBorder(); }\n"
    target = data_home / "gnome-shell/extensions" / FOCUS_UUID
    backup.file(target / "extension.js", content)
    backup.file(target / "metadata.json", json.dumps({
        "uuid": FOCUS_UUID, "name": "Neon Workbench Focus Border",
        "description": "Cyan 4-pixel border following the focused window.",
        "shell-version": [str(v) for v in (range(45, 51) if modern else range(40, 45))],
        "version": 1, "url": "https://github.com/c-lydia/neovim_config",
    }, indent=2) + "\n")
    enable_extension(backup, FOCUS_UUID)
    print("Installed the cyan focus-border compatibility extension.")


def browser_desktop(data_home):
    roots = [data_home, *(Path(p) for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"))]
    for name in ("firefox.desktop", "org.mozilla.firefox.desktop", "firefox_firefox.desktop", "chromium.desktop", "chromium-browser.desktop", "com.google.Chrome.desktop"):
        if any((root / "applications" / name).is_file() for root in roots):
            return name
    return None


def layouts(existing, browser=None, terminal="ptyxis"):
    if not isinstance(existing, list):
        raise RuntimeError("Existing Tiling Assistant layouts.json must contain a list")
    def item(x, y, width, height, role=None):
        app_id = f"io.github.chhenglydia.Nvim{role}.desktop" if role else None
        if role == "Browser": app_id = browser
        elif terminal == "gnome-terminal": app_id = None
        return {"rect": {"x": x, "y": y, "width": width, "height": height},
                "appId": app_id, "loopType": None}
    wanted = [
        {"_name": "Neovim + Browser", "_items": [item(0, 0, .5, 1, "Code"), item(.5, 0, .5, 1, "Browser")]},
        {"_name": "Neovim + GUI chooser", "_items": [item(0, 0, .5, 1, "Code"), item(.5, 0, .5, 1)]},
        {"_name": "Neovim Four-Up", "_items": [item(0, 0, .5, .5, "Code"), item(0, .5, .5, .5, "Terminal"), item(.5, 0, .5, .5, "Browser"), item(.5, .5, .5, .5, "Codex")]},
    ]
    result = list(existing)
    indices = []
    for layout in wanted:
        index = next((i for i, old in enumerate(result) if old.get("_name") == layout["_name"]), len(result))
        if index == len(result): result.append(layout)
        else: result[index] = layout
        indices.append(index)
    if max(indices) >= 20:
        raise RuntimeError("No free Tiling Assistant layout slots; keep fewer than 18 unrelated layouts first")
    return result, indices


def install(args):
    install_home = Path(os.environ.get("WORKBENCH_INSTALL_HOME", str(Path.home())))
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", str(install_home / ".config")))
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(install_home / ".local/share")))
    state_home = Path(os.environ.get("XDG_STATE_HOME", str(install_home / ".local/state")))
    data = data_home / "nvim-workbench"
    config = config_home / "nvim-workbench"
    bin_dir = install_home / ".local/bin"
    appearance = json.loads((ROOT / "desktop/appearance.json").read_text())
    terminal, app = choose_terminal(args.terminal)
    layout_path = config_home / "tiling-assistant/layouts.json"
    browser = browser_desktop(data_home)
    merged, indices = layouts(json.loads(layout_path.read_text()) if layout_path.is_file() else [], browser, terminal)
    if args.dry_run:
        print(json.dumps({"terminal": terminal, "flatpak_app": app, "font": appearance["font"],
                          "shell_theme": "neon-workbench", "layout_slots": indices,
                          "gnome_version": shell_version(), "install_home": str(install_home)}, indent=2))
        return
    missing = [name for name in ("zsh", "git", "dconf", "gsettings", "fc-match") if not shutil.which(name)]
    if missing:
        raise RuntimeError("Missing dependencies: " + ", ".join(missing) + ". On Ubuntu: sudo apt install zsh git dconf-cli fontconfig fonts-dejavu-core")
    if "DejaVu Sans Mono" not in run("fc-match", "-f", "%{family}", "DejaVu Sans Mono").stdout:
        raise RuntimeError("Install the matching font first: sudo apt install fonts-dejavu-core")
    # Fail before changing preferences if a required framework/download is unavailable.
    ensure_omz(install_home, data, args.no_downloads)
    extension = ensure_tiling(data_home, args.no_downloads)
    flatpak_settings = ["flatpak", "run", "--command=gsettings", app] if app else None
    if flatpak_settings and "org.gnome.Ptyxis" not in run(*flatpak_settings, "list-schemas").stdout.splitlines():
        raise RuntimeError("Ptyxis Flatpak does not expose its settings schema; update it before installing this theme")

    backup = Backup(state_home / "nvim-workbench/backups")
    print(f"Backup: {backup.directory / 'manifest.json'}")
    try:
        for filename in ("nvim-workspace", "nvim-workbench-shell"):
            backup.file(bin_dir / filename, (ROOT / "scripts" / filename).read_bytes(), 0o755)
        for filename in ("neon-workbench.zsh-theme", "workbench.zsh"):
            backup.file(data / "zsh" / filename, (ROOT / "desktop/zsh" / filename).read_bytes())
        backup.file(config / "zsh/.zshrc", (ROOT / "desktop/zsh/startup.zsh").read_bytes())
        values = {"NVIM_WORKSPACE_TERMINAL": terminal, "NVIM_WORKSPACE_LAYOUT": "four",
                  "NVIM_WORKSPACE_SHELL": str(bin_dir / "nvim-workbench-shell")}
        if app: values["NVIM_WORKSPACE_PTYXIS_APP"] = app
        if browser: values["NVIM_WORKSPACE_BROWSER_DESKTOP"] = browser
        if terminal == "gnome-terminal": values["NVIM_WORKSPACE_GNOME_PROFILE"] = PROFILE
        backup.file(config / "desktop.env", "".join(f"if [[ ! -v {key} ]]; then {key}={shlex.quote(value)}; fi\n" for key, value in values.items()))

        for role in ("Code", "Terminal", "Shell", "Browser", "Codex"):
            entry = ("[Desktop Entry]\nType=Application\nVersion=1.0\n"
                     f"Name=Neovim {role} Workspace\nExec={desktop_quote(bin_dir / 'nvim-workspace')} --pane {role.lower()}\n"
                     "Icon=utilities-terminal\nTerminal=false\nCategories=Development;IDE;\n"
                     f"StartupWMClass=io.github.chhenglydia.Nvim{role}\n")
            backup.file(data_home / "applications" / f"io.github.chhenglydia.Nvim{role}.desktop", entry)
        backup.file(data_home / "applications/nvim-workspace.desktop",
                    "[Desktop Entry]\nType=Application\nName=Neovim Four-Up Workspace\n"
                    f"Exec={desktop_quote(bin_dir / 'nvim-workspace')} %f\n"
                    "Icon=utilities-terminal\nTerminal=false\nCategories=Development;IDE;\n")
        backup.file(layout_path, json.dumps(merged, indent=2) + "\n")

        if terminal.startswith("ptyxis"):
            root = "/org/gnome/Ptyxis/"
            schema = "org.gnome.Ptyxis"
            profile_schema = f"{schema}.Profile:{root}Profiles/{PROFILE}/"
            if flatpak_settings:
                profiles = variant_list(run(*flatpak_settings, "get", schema, "profile-uuids").stdout)
                def setting(scope, key, value):
                    backup.gsettings(flatpak_settings, schema if scope == "root" else profile_schema, key, value)
            else:
                profiles = variant_list(run("dconf", "read", root + "profile-uuids").stdout)
                def setting(scope, key, value):
                    backup.dconf(root + ("" if scope == "root" else f"Profiles/{PROFILE}/") + key, value)
            if PROFILE not in profiles: profiles.append(PROFILE)
            for key, value in {"profile-uuids": repr(profiles), "default-profile-uuid": repr(PROFILE),
                               "use-system-font": "false", "font-name": repr(appearance["font"]),
                               "interface-style": "'dark'", "window-size": "(uint32 117, uint32 24)"}.items():
                setting("root", key, value)
            for key, value in {"label": "'Neon Workbench'", "palette": repr(appearance["ptyxis_palette"]),
                               "bold-is-bright": "true", "backspace-binding": "'ascii-delete'",
                               "use-custom-command": "true", "custom-command": repr(shlex.quote(str(bin_dir / "nvim-workbench-shell")) + " -i")}.items():
                setting("profile", key, value)
        else:
            root = "/org/gnome/terminal/legacy/profiles:/"
            profiles = variant_list(run("dconf", "read", root + "list").stdout)
            if PROFILE not in profiles: profiles.append(PROFILE)
            backup.dconf(root + "list", repr(profiles))
            for key, value in {"visible-name": "'Neon Workbench'", "use-system-font": "false", "font": repr(appearance["font"]),
                               "use-theme-colors": "false", "foreground-color": repr(appearance["foreground"]),
                               "background-color": repr(appearance["background"]), "palette": repr(appearance["palette"]),
                               "bold-is-bright": "true", "use-custom-command": "true",
                               "custom-command": repr(shlex.quote(str(bin_dir / "nvim-workbench-shell")) + " -i")}.items():
                backup.dconf(root + f":{PROFILE}/" + key, value)

        interface_keys = run("gsettings", "list-keys", "org.gnome.desktop.interface").stdout.splitlines()
        if "color-scheme" in interface_keys:
            backup.gsettings(["gsettings"], "org.gnome.desktop.interface", "color-scheme", "'prefer-dark'")
        native_focus = False
        if extension:
            uuid, directory = extension
            prefix = ["gsettings"]
            if (directory / "schemas").is_dir():
                prefix += ["--schemadir", str(directory / "schemas")]
            keys = run(*prefix, "list-keys", TILING_SCHEMA).stdout.splitlines()
            native_focus = all(key in keys for key in ("focus-hint", "focus-hint-color", "focus-hint-outline-size", "focus-hint-outline-style"))
            settings = dict(appearance["tiling"])
            if not native_focus and "focus-hint" in keys:
                settings["focus-hint"] = "0"
            shortcuts = ["<Super><Alt>b", "<Super><Alt>g", "<Super><Alt>w"]
            for index, shortcut in zip(indices, shortcuts): settings[f"activate-layout{index}"] = repr([shortcut])
            for key in keys:
                if key.startswith("activate-layout") and key not in settings:
                    current = variant_list(run(*prefix, "get", TILING_SCHEMA, key).stdout)
                    remaining = [shortcut for shortcut in current if shortcut not in shortcuts]
                    if current != remaining: settings[key] = repr(remaining)
            for key, value in settings.items():
                if key in keys: backup.gsettings(prefix, TILING_SCHEMA, key, value)
                else: print(f"Tiling feature unavailable in this extension version: {key}")
            enable_extension(backup, uuid)
        if not native_focus:
            install_focus_border(backup, data_home)
        else:
            enabled = variant_list(run("gsettings", "get", "org.gnome.shell", "enabled-extensions").stdout)
            if FOCUS_UUID in enabled:
                backup.gsettings(["gsettings"], "org.gnome.shell", "enabled-extensions", repr([uuid for uuid in enabled if uuid != FOCUS_UUID]))
                if shell_is_running():
                    run("gnome-extensions", "disable", FOCUS_UUID, check=False)
        print("Installed desktop appearance. Run ~/.local/bin/nvim-workspace from a desktop terminal.")
        print('For the nvim-workspace command, keep this in your shell configuration: export PATH="$HOME/.local/bin:$PATH"')
        print("Log out and back in once after installation so GNOME loads new or updated extensions.")
        print("Super+Alt+B: browser split; Super+Alt+G: GUI chooser; Super+Alt+W: four-window layout (with Tiling Assistant active).")
    except Exception:
        print(f"Installation interrupted; restore with: python3 {shlex.quote(str(__file__))} --restore {shlex.quote(str(backup.directory / 'manifest.json'))}", file=sys.stderr)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal", choices=("ptyxis", "gnome-terminal", "auto"), default="ptyxis")
    parser.add_argument("--no-downloads", action="store_true", help="reuse installed Oh My Zsh and Tiling Assistant")
    parser.add_argument("--dry-run", action="store_true", help="show the detected setup without changing it")
    parser.add_argument("--restore", metavar="MANIFEST", help="restore a backup created by this installer")
    args = parser.parse_args()
    try:
        restore(args.restore) if args.restore else install(args)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"install-desktop: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError): print(error.stderr, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
