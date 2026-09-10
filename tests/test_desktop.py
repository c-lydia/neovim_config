"""Desktop installation is exercised against an isolated filesystem/settings store."""

import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("desktop_installer", ROOT / "scripts/install-desktop.py")
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)


class Settings:
    def __init__(self, modern=True):
        self.values = {
            ("dconf", "/org/gnome/Ptyxis/profile-uuids"): "['existing-profile']",
            ("dconf", "/org/gnome/Ptyxis/default-profile-uuid"): "'existing-profile'",
            ("org.gnome.shell", "enabled-extensions"): "['other@example.org']",
            ("org.gnome.desktop.interface", "color-scheme"): "'default'",
            ("org.gnome.Ptyxis", "profile-uuids"): "['existing-profile']",
        }
        self.keys = [f"activate-layout{i}" for i in range(20)] + ["window-gap", "single-screen-gap"]
        if modern:
            self.keys += ["dynamic-keybinding-behavior", "focus-hint", "focus-hint-color",
                          "focus-hint-outline-size", "focus-hint-outline-style",
                          "focus-hint-outline-border-radius", "tiling-popup-all-workspace"]

    def run(self, *args, check=True, env=None):
        args = list(map(str, args))
        output = ""
        if args[:3] == ["flatpak", "run", "--command=gsettings"]:
            args = ["gsettings", *args[4:]]
        if args == ["gsettings", "list-schemas"]:
            return subprocess.CompletedProcess(args, 0, "org.gnome.Ptyxis\n", "")
        if args[0] == "dconf":
            action, key = args[1:3]
            key = ("dconf", key)
            if action == "read": output = self.values.get(key, "")
            elif action == "write": self.values[key] = args[3]
            elif action == "reset": self.values.pop(key, None)
        elif args[0] == "gsettings":
            if args[1] == "--schemadir": args = [args[0], *args[3:]]
            action, schema = args[1:3]
            if action == "list-keys":
                output = "\n".join(self.keys if schema == desktop.TILING_SCHEMA else ["color-scheme"])
            else:
                key = (schema, args[3])
                if action == "get": output = self.values.get(key, "[]" if args[3].startswith("activate-layout") else "0")
                elif action == "set": self.values[key] = args[4]
                elif action == "reset": self.values.pop(key, None)
        elif args[:2] == ["gnome-shell", "--version"]: output = "GNOME Shell 42.9"
        elif args[0] == "fc-match": output = "DejaVu Sans Mono"
        elif args[0] == "gdbus": output = "(false,)"
        elif args[:2] == ["gnome-extensions", "enable"]: pass
        else: raise AssertionError(f"Unexpected command: {args}")
        return subprocess.CompletedProcess(args, 0, output + "\n" if output else "", "")


class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nvim-desktop-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "home 'quoted' $directory"
        self.config = self.home / ".config"
        self.data = self.home / ".local/share"
        self.state = self.home / ".local/state"
        self.env = {**os.environ, "WORKBENCH_INSTALL_HOME": str(self.home),
                    "XDG_CONFIG_HOME": str(self.config), "XDG_DATA_HOME": str(self.data),
                    "XDG_STATE_HOME": str(self.state), "XDG_DATA_DIRS": str(self.base / "system")}
        (self.home / ".oh-my-zsh").mkdir(parents=True)
        (self.home / ".oh-my-zsh/oh-my-zsh.sh").write_text("git_prompt_info() { :; }\nvirtualenv_prompt_info() { :; }\n")
        (self.home / ".zshrc").write_text("export WORKBENCH_USER_RC_LOADED=yes\n")
        extension = self.data / "gnome-shell/extensions" / desktop.TILING_UUIDS[1]
        extension.mkdir(parents=True)
        (extension / "metadata.json").write_text(json.dumps({"shell-version": ["42"]}))
        self.settings = Settings()
        self.args = argparse.Namespace(terminal="ptyxis", dry_run=False, no_downloads=True)

    def install(self, settings=None):
        output = io.StringIO()
        with patch.dict(os.environ, self.env, clear=True), \
             patch.object(desktop.shutil, "which", side_effect=lambda command: "/usr/bin/" + command), \
             patch.object(desktop, "run", side_effect=(settings or self.settings).run), \
             contextlib.redirect_stdout(output):
            desktop.install(self.args)
        return output.getvalue()

    def test_install_backs_up_custom_files_and_preserves_unrelated_settings(self):
        launcher = self.home / ".local/bin/nvim-workspace"
        launcher.parent.mkdir(parents=True)
        launcher.write_text("custom launcher\n")
        original_rc = (self.home / ".zshrc").read_text()
        self.install()
        self.assertEqual(launcher.read_bytes(), (ROOT / "scripts/nvim-workspace").read_bytes())
        self.assertEqual((self.home / ".zshrc").read_text(), original_rc)
        self.assertEqual(self.settings.values[("dconf", "/org/gnome/Ptyxis/profile-uuids")],
                         repr(["existing-profile", desktop.PROFILE]))
        self.assertIn("other@example.org", self.settings.values[("org.gnome.shell", "enabled-extensions")])
        self.assertEqual(self.settings.values[(desktop.TILING_SCHEMA, "focus-hint-color")], "'rgb(4,217,255)'")
        self.assertEqual(self.settings.values[(desktop.TILING_SCHEMA, "focus-hint-outline-size")], "4")
        manifest = next((self.state / "nvim-workbench/backups").glob("*/manifest.json"))
        self.assertEqual(manifest.parent.stat().st_mode & 0o777, 0o700)
        with patch.object(desktop, "run", side_effect=self.settings.run):
            desktop.restore(manifest)
        self.assertEqual(launcher.read_text(), "custom launcher\n")
        self.assertEqual(self.settings.values[("dconf", "/org/gnome/Ptyxis/default-profile-uuid")], "'existing-profile'")
        self.assertFalse((self.config / "nvim-workbench/desktop.env").exists())

    def test_preferences_file_quotes_paths_and_allows_explicit_overrides(self):
        self.install()
        config = self.config / "nvim-workbench/desktop.env"
        command = 'source "$1"; printf "%s\\n" "$NVIM_WORKSPACE_SHELL" "$NVIM_WORKSPACE_TERMINAL"'
        result = subprocess.run(["bash", "-c", command, "test", str(config)],
                                env={**self.env, "NVIM_WORKSPACE_TERMINAL": "gnome-terminal"},
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.splitlines(), [str(self.home / ".local/bin/nvim-workbench-shell"), "gnome-terminal"])

    @unittest.skipUnless(shutil.which("zsh"), "Zsh is required for the prompt smoke test")
    def test_real_zsh_loads_original_rc_prompt_and_helpers(self):
        self.install()
        shell = self.home / ".local/bin/nvim-workbench-shell"
        result = subprocess.run([str(shell), "-ic", 'print -r -- "$WORKBENCH_USER_RC_LOADED" "$PROMPT"; whence -w venv-create; alias nws'],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("yes", result.stdout)
        self.assertIn("#04d9ff", result.stdout)
        self.assertIn("venv-create: function", result.stdout)
        self.assertIn("nws=nvim-workspace", result.stdout)
        self.assertNotIn("command not found", result.stderr)

    def test_rerun_does_not_duplicate_profiles_layouts_or_extensions(self):
        self.install()
        first = dict(self.settings.values)
        self.install()
        self.assertEqual(self.settings.values, first)
        self.assertEqual(len(json.loads((self.config / "tiling-assistant/layouts.json").read_text())), 3)

    def test_older_extension_reports_unavailable_border_settings(self):
        output = self.install(Settings(modern=False))
        self.assertIn("Tiling feature unavailable in this extension version: focus-hint-outline-size", output)
        extension = self.data / "gnome-shell/extensions" / desktop.FOCUS_UUID
        metadata = json.loads((extension / "metadata.json").read_text())
        self.assertIn("42", metadata["shell-version"])
        source = (extension / "extension.js").read_text()
        self.assertIn("imports.gi", source)
        self.assertIn("function init()", source)
        self.assertIn("#04d9ff", source)

    def test_flatpak_preferences_use_the_application_settings_backend(self):
        with patch.object(desktop, "choose_terminal", return_value=("ptyxis-flatpak", "app.devsuite.Ptyxis")):
            self.install()
        self.assertEqual(self.settings.values[("org.gnome.Ptyxis", "font-name")], "'DejaVu Sans Mono 10'")
        self.assertEqual(self.settings.values[("org.gnome.Ptyxis", "profile-uuids")], repr(["existing-profile", desktop.PROFILE]))
        self.assertNotIn(("dconf", "/org/gnome/Ptyxis/font-name"), self.settings.values)
        self.assertIn("app.devsuite.Ptyxis", (self.config / "nvim-workbench/desktop.env").read_text())

    @unittest.skipUnless(shutil.which("node"), "Node is required to parse the modern extension")
    def test_modern_border_entry_uses_es_modules(self):
        with patch.object(desktop, "shell_version", return_value="50"):
            self.install()
        extension = self.data / "gnome-shell/extensions" / desktop.FOCUS_UUID
        metadata = json.loads((extension / "metadata.json").read_text())
        self.assertIn("50", metadata["shell-version"])
        self.assertNotIn("42", metadata["shell-version"])
        source = (extension / "extension.js").read_text()
        self.assertIn("export default FocusBorder", source)
        result = subprocess.run(["node", "--input-type=module", "--check"], input=source, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("desktop-file-validate"), "desktop-file-utils is required")
    def test_generated_desktop_files_pass_system_validation(self):
        self.install()
        for entry in (self.data / "applications").glob("*.desktop"):
            result = subprocess.run(["desktop-file-validate", str(entry)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_dry_run_does_not_create_desktop_files_or_change_preferences(self):
        self.args.dry_run = True
        initial = dict(self.settings.values)
        self.install()
        self.assertEqual(self.settings.values, initial)
        self.assertFalse((self.config / "nvim-workbench").exists())

    def test_symlink_backup_does_not_change_original_target(self):
        actual = self.base / "original"
        actual.write_text("keep me")
        link = self.base / "link"
        link.symlink_to(actual)
        backup = desktop.Backup(self.state)
        backup.file(link, "new file")
        self.assertEqual(actual.read_text(), "keep me")
        desktop.restore(backup.directory / "manifest.json")
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.read_text(), "keep me")

    def test_layouts_keep_existing_layout_and_use_real_browser_desktop_id(self):
        original = {"_name": "Unrelated layout", "_items": []}
        merged, indices = desktop.layouts([original], "org.mozilla.firefox.desktop")
        self.assertEqual(merged[0], original)
        self.assertEqual(indices, [1, 2, 3])
        self.assertEqual(merged[1]["_items"][1]["appId"], "org.mozilla.firefox.desktop")
        self.assertEqual(desktop.layouts(merged, "org.mozilla.firefox.desktop")[0], merged)
        fallback, _ = desktop.layouts([], None, "gnome-terminal")
        self.assertTrue(all(item["appId"] is None for layout in fallback for item in layout["_items"]))

    def test_extension_download_requires_matching_shell_and_expected_uuid(self):
        info = {"uuid": desktop.TILING_UUIDS[1], "shell_version_map": {"42": {"pk": 34016}}}
        self.assertIn("version_tag=34016", desktop.extension_metadata(info, "42"))
        with self.assertRaises(RuntimeError): desktop.extension_metadata(info, "50")
        info["uuid"] = "unexpected@example.org"
        with self.assertRaises(RuntimeError): desktop.extension_metadata(info, "42")


if __name__ == "__main__":
    unittest.main()
