"""Exercise launcher installation and command construction without a desktop."""

import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts/install.sh"
LAUNCHER = ROOT / "scripts/nvim-workspace"


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nvim-workspace-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "install home"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        for name in ("mkdir", "mktemp", "mv", "rm", "sleep", "cat"):
            (self.bin / name).symlink_to(shutil.which(name))
        self.project = self.base / "project 'quoted' $(touch SHOULD_NOT_EXIST)"
        self.project.mkdir()
        self.log = self.base / "launches.jsonl"
        self.env = {
            **os.environ,
            "WORKBENCH_INSTALL_HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "DISPLAY": ":workspace-test",
            "WAYLAND_DISPLAY": "",
            "WORKSPACE_TEST_LOG": str(self.log),
            "NVIM_BIN": str(self.bin / "test nvim"),
            "NVIM_WORKSPACE_TERMINAL": "gnome-terminal",
            "NVIM_WORKSPACE_LAYOUT": "three",
        }
        self.executable("test nvim", "#!/bin/sh\nexit 0\n")
        self.executable("gnome-terminal", """#!/usr/bin/python3
import json, os, sys
with open(os.environ['WORKSPACE_TEST_LOG'], 'a') as stream:
    stream.write(json.dumps(sys.argv[1:]) + '\\n')
""")

    def executable(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)
        return path

    def run_script(self, script, *args, env=None):
        return subprocess.run(
            ["/bin/bash", str(script), *map(str, args)],
            env=env or self.env, cwd=self.base,
            capture_output=True, text=True, timeout=10,
        )

    def assert_passes(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_normal_install_includes_launcher_and_is_repeatable(self):
        for _ in range(2):
            self.assert_passes(self.run_script(INSTALLER, "--native"))
        installed = self.home / ".local/bin/nvim-workspace"
        self.assertEqual(installed.resolve(), LAUNCHER)
        self.assertTrue(os.access(installed, os.X_OK))
        self.assertEqual((self.home / ".config/nvim").resolve(), ROOT)

    def test_workspace_only_copy_preserves_existing_configuration(self):
        config = self.home / ".config/nvim"
        config.mkdir(parents=True)
        (config / "init.lua").write_text("-- existing configuration\n")
        self.assert_passes(self.run_script(INSTALLER, "--workspace-only", "--copy"))
        installed = self.home / ".local/bin/nvim-workspace"
        self.assertFalse(installed.is_symlink())
        self.assertEqual(installed.read_bytes(), LAUNCHER.read_bytes())
        self.assertTrue(os.access(installed, os.X_OK))
        self.assertEqual((config / "init.lua").read_text(), "-- existing configuration\n")

    def test_existing_custom_launcher_is_preserved(self):
        installed = self.home / ".local/bin/nvim-workspace"
        installed.parent.mkdir(parents=True)
        installed.write_text("custom launcher\n")
        self.assert_passes(self.run_script(INSTALLER, "--workspace-only"))
        self.assertEqual(installed.read_text(), "custom launcher\n")

    def test_three_windows_keep_project_and_neovim_arguments_intact(self):
        self.assert_passes(self.run_script(LAUNCHER, self.project))
        windows = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(len(windows), 3)
        for window in windows:
            self.assertIn("--window", window)
            self.assertIn(f"--working-directory={self.project}", window)
        self.assertEqual(windows[0][-2:], ["--", self.env["NVIM_BIN"]])
        self.assertEqual(windows[1][-6:], [
            "--", self.env["NVIM_BIN"], "-c", "terminal", "-c", "startinsert",
        ])
        self.assertEqual(windows[2][-1], "-i")
        self.assertFalse((self.base / "SHOULD_NOT_EXIST").exists())

    def test_help_works_without_a_desktop(self):
        env = {**self.env, "DISPLAY": "", "WAYLAND_DISPLAY": ""}
        self.assert_passes(self.run_script(LAUNCHER, "--help", env=env))
        result = self.run_script(LAUNCHER, self.project, env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("graphical desktop session", result.stderr)
        self.assertFalse(self.log.exists())

    def test_detects_native_neovim_on_path_then_flatpak(self):
        env = {**self.env, "PATH": str(self.bin)}
        del env["NVIM_BIN"]
        native = self.executable("nvim", "#!/bin/sh\nexit 0\n")
        self.assert_passes(self.run_script(LAUNCHER, self.project, env=env))
        windows = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(windows[0][-2:], ["--", str(native)])
        native.unlink()
        self.log.unlink()
        self.executable("flatpak", "#!/bin/sh\nexit 0\n")
        self.assert_passes(self.run_script(LAUNCHER, self.project, env=env))
        windows = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(windows[0][-4:], ["--", "flatpak", "run", "io.neovim.nvim"])

    def test_missing_terminal_and_neovim_report_actionable_errors(self):
        (self.bin / "gnome-terminal").unlink()
        result = self.run_script(LAUNCHER, self.project,
                                 env={**self.env, "PATH": str(self.bin)})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sudo apt install gnome-terminal", result.stderr)
        self.executable("gnome-terminal", "#!/bin/sh\nexit 0\n")
        result = self.run_script(LAUNCHER, self.project,
                                 env={**self.env, "NVIM_BIN": "/missing/nvim"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Neovim executable not found", result.stderr)
        self.assertFalse(self.log.exists())

    def test_terminal_failure_is_visible_and_stops_later_windows(self):
        self.executable("gnome-terminal", "#!/bin/sh\necho 'cannot open display' >&2\nexit 3\n")
        result = self.run_script(LAUNCHER, self.project)
        self.assertEqual(result.returncode, 3)
        self.assertIn("cannot open display", result.stderr)

    def test_ptyxis_has_distinct_window_ids_and_reports_startup_errors(self):
        self.executable("ptyxis", (self.bin / "gnome-terminal").read_text())
        env = {**self.env, "NVIM_WORKSPACE_TERMINAL": "ptyxis"}
        self.assert_passes(self.run_script(LAUNCHER, self.project, env=env))
        windows = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(len(windows), 3)
        for window, role in zip(windows, ("Code", "Terminal", "Shell")):
            self.assertIn(f"--gapplication-app-id=io.github.chhenglydia.Nvim{role}", window)
            self.assertIn(f"--working-directory={self.project}", window)
        self.executable("ptyxis", "#!/bin/sh\necho 'cannot open display' >&2\nexit 3\n")
        failed = self.run_script(LAUNCHER, self.project, env=env)
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn("cannot open display", failed.stderr)

    def test_remembered_project_is_used_by_desktop_panes(self):
        self.assert_passes(self.run_script(LAUNCHER, self.project, "--set-only"))
        self.assertFalse(self.log.exists())
        self.assert_passes(self.run_script(LAUNCHER, "--pane", "code"))
        windows = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(len(windows), 1)
        self.assertIn(f"--working-directory={self.project}", windows[0])


if __name__ == "__main__":
    unittest.main()
