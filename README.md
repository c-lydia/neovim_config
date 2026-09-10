# Neovim Multi-Stack Workbench

A Neovim 0.11.3+ configuration for application development, embedded systems,
reverse engineering, cybersecurity, cryptography, databases, and technical
writing. It includes LSP completion, formatting, linting, Tree-sitter,
debugging, terminals, Git, database tools, safe hex editing, disassembly, and a
GNOME launcher for independent tiled IDE windows.

## Supported stacks

- Python, AI/ML, YOLO, ROS2, and GStreamer
- C, C++, Java, JavaScript, TypeScript, HTML, and CSS
- Arduino, ESP32, STM32, CMake, and Docker/Compose
- PostgreSQL, SQL, JSON, YAML, XML, Markdown, and RST
- Reverse engineering: ASM/NASM, GDB, CodeLLDB, hex editing, `objdump`, strings
- Cybersecurity: Python, C/C++, Rust, Go, YARA rules, shell, Docker
- Cryptography: Python/Sage, C/C++, Rust, Go, assembly

## Requirements

Neovim 0.11.3 or newer is required; both the 0.11 and 0.12 release lines are
tested. On Ubuntu, install the common native tools:

```bash
sudo apt install \
  git curl unzip build-essential ripgrep fd-find nodejs npm \
  python3 python3-pip xxd binutils gdb \
  clang clangd clang-format bear cppcheck shellcheck default-jdk \
  cmake ninja-build
```

Docker workflows require Docker Engine and the Compose v2 plugin (`docker
compose version` must work).

Neovim 0.12 uses Tree-sitter's rewritten `main` branch, which requires
`tree-sitter-cli` 0.26.1 or newer. Install the CLI with your system or language
package manager rather than npm. Neovim 0.11 automatically
uses Tree-sitter's frozen compatibility branch and does not need that new API.

For the security and cryptography stacks, install the runtimes you actually
use:

```bash
# Go tools, gopls, formatting, linting, and Delve
sudo apt install golang-go

# Rust, rust-analyzer dependencies, rustfmt, clippy, and asm-lsp
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add rustfmt clippy

# YARA engine used by the YARA language server
sudo apt install yara

# SageMath cryptography/number-theory notebooks (optional and large)
sudo apt install sagemath
```

Mason installs configured language servers, formatters, linters, and debug
adapters on the first normal Neovim start. Open `:Mason` to inspect them or run
`:MasonToolsInstall` to retry tool installation.

Go's `gopls`/`sqls` and Rust's `asm-lsp` are enabled when their host `go` or
`cargo` toolchain exists. After installing one of those runtimes, restart
Neovim and use `:Mason` to install any newly available server.

## Install and start

Clone the workbench once, then use the installer to link it into Neovim's
configuration directory:

```bash
git clone https://github.com/c-lydia/neovim_config.git ~/src/neovim_config
cd ~/src/neovim_config
./scripts/install.sh --native
nvim README.md
```

The installer never overwrites an existing configuration. Move the old target
aside first if necessary. Pass `--copy` if an independent copy is preferable
to the default link. It also installs `nvim-workspace` into `~/.local/bin`,
preserving any existing custom launcher.

### Flatpak Neovim

Install Neovim from Flathub, then target its app-specific configuration path:

```bash
flatpak install flathub io.neovim.nvim
cd ~/src/neovim_config
./scripts/install.sh --flatpak
flatpak run io.neovim.nvim README.md
```

Use `./scripts/install.sh --both` to share one checkout between native and
Flatpak Neovim. Flatpak Neovim reads configuration from
`~/.var/app/io.neovim.nvim/config/nvim` and keeps plugins and other application
data under its own `~/.var/app/io.neovim.nvim/data` tree. Run `:Lazy sync` and
`:MasonToolsInstall` once inside each Neovim installation you use.

The Flatpak is an isolated development environment and cannot automatically
reuse every compiler or SDK installed on the host. Its first-run guide explains
how to enable matching Freedesktop SDK extensions with
`FLATPAK_ENABLE_SDK_EXT`. Markdown Preview does not need Node/npm in the
Flatpak: this configuration installs its prebuilt server and sends the URL to
the desktop through Flatpak's OpenURI portal.

Useful maintenance commands:

```vim
:Lazy sync
:Mason
:MasonToolsInstall
:TSUpdate
:checkhealth
:LspInfo
```

The configuration automatically selects `lazy-lock.json` on Neovim 0.11 and
`lazy-lock-0.12.json` on Neovim 0.12 or newer. Keep both files: the two
Tree-sitter branches use incompatible APIs, while every other plugin remains
reproducibly pinned.

## Desktop workspace and appearance

The optional desktop installer recreates the workstation appearance as well as
installing the launcher:

- Ptyxis with **DejaVu Sans Mono 10** (the original Monospace font resolves to
  this family), the **Xterm** palette, and dark window appearance.
- The **neon-workbench** Zsh prompt: cyan identity/path, Git state, Python venv,
  last-command failures, and a right-aligned clock.
- A **cyan `#04d9ff`, 4-pixel border** following the focused window.
- Application-menu entries and three Tiling Assistant layouts, including the
  original four-window workspace.

Neovim's Catppuccin Mocha theme and plugins remain part of the Neovim config.
Desktop installation is separate so installing an editor config does not
implicitly change desktop preferences.

### Install the full appearance on the Jetson

Run in the **Jetson's GNOME desktop session**, as your normal user. Install the
small native prerequisites:

```bash
sudo apt install zsh git python3 dconf-cli fontconfig fonts-dejavu-core
```

Install **Ptyxis** through your distribution if available. On an older Ubuntu
release that does not package it, its [official Flatpak package](https://github.com/flathub/app.devsuite.Ptyxis)
is another option:

```bash
sudo apt install flatpak
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub app.devsuite.Ptyxis
```

From this release's checkout, install the desktop setup for your existing config:

```bash
./scripts/install.sh --desktop-only
export PATH="$HOME/.local/bin:$PATH"
```

**Log out and back in once** so GNOME discovers new or updated extensions, then:

```bash
nvim-workspace ~/projects/my-project
```

For a fresh editor installation, `./scripts/install.sh --native --desktop`
installs both parts. The installer reuses an existing Oh My Zsh framework or
fetches a pinned upstream revision. It reuses a compatible Tiling Assistant
installation or downloads the release selected for your GNOME Shell version
from [GNOME Extensions](https://extensions.gnome.org/extension/3733/tiling-assistant/).
It does not install Snap packages or change your login shell.

The default desktop installation requires native Ptyxis or its installed Flatpak.
For a themed GNOME Terminal fallback, explicitly select it:

```bash
sudo apt install gnome-terminal
python3 scripts/install-desktop.py --terminal gnome-terminal
```

That fallback matches the font, palette, and prompt, but its window decorations
remain GNOME Terminal's. Its tiling layouts use the window chooser for terminal
panes because they do not have Ptyxis's distinct application IDs.

### Windows, borders, and shortcuts

The full desktop setup opens Neovim code, a Neovim terminal, a browser, and a
Codex terminal. If the Codex executable is absent, the fourth pane is a themed
shell. Browser discovery uses installed desktop IDs rather than requiring a
Snap-specific Firefox shortcut. If no browser is found, install one or use the
GUI chooser layout. Optional `--gui APP` and `--flatpak APP_ID` arguments still
open additional applications.

| Shortcut | Action |
|---|---|
| `Super+Alt+B` | Neovim beside the browser |
| `Super+Alt+G` | Neovim beside a window you choose |
| `Super+Alt+W` | Open/reuse and tile the remembered four-window workspace |

Select a project without opening windows using `nvim-workspace DIRECTORY
--set-only`. Use `nvim-workspace DIRECTORY --layout three` for the original
three-terminal arrangement. The launcher alone defaults to that arrangement;
the desktop installer selects the four-window layout.

On newer Tiling Assistant versions, the focus outline uses the extension's
built-in settings. Older supported versions, including GNOME 42's Tiling
Assistant 36, lack that feature. The installer supplies **Neon Workbench Focus
Border**, with separate entry points for GNOME 40–44 and 45–50. The border is
non-interactive, follows focus/movement/resizing, and hides during overview,
screen lock, fullscreen, and inactive-workspace transitions. It does not tile
windows itself. Unknown GNOME versions are reported instead of loading an
incompatible extension.

The generated layout file is `~/.config/tiling-assistant/layouts.json`. Existing
unrelated layouts and enabled extensions are retained. Add the PATH export to
`~/.bashrc` or `~/.zshrc` if needed. `NVIM_WORKSPACE_TERMINAL`, `NVIM_BIN`, and
`NVIM_WORKSPACE_LAYOUT` override terminal, Neovim executable, and layout
selection for a particular launch.

### Backups, inspection, and restore

Inspect the detected setup without changing preferences:

```bash
python3 scripts/install-desktop.py --dry-run
```

`--no-downloads` reuses installed dependencies; it requires Oh My Zsh to exist
and reports when Tiling Assistant is unavailable. The desktop installer copies
managed scripts and assets into `~/.local/bin`, `~/.local/share/nvim-workbench`,
and `~/.config/nvim-workbench`. It backs up replaced launchers, desktop files,
layouts, and modified settings under a private timestamped directory in
`~/.local/state/nvim-workbench/backups/` and prints the manifest path.

Restore a particular installation's appearance changes with:

```bash
python3 scripts/install-desktop.py --restore /path/printed/by/installer/manifest.json
```

Framework/extension downloads remain installed after appearance restoration.
Log out and back in after restoring extensions. Keep backups private: existing
personal configuration files may contain private data.

## Oh My Zsh terminal workbench

Workspace shells use Zsh through `nvim-workbench-shell`, which loads your existing
`~/.zshrc` first and then applies the packaged theme and helpers. The original
file is not rewritten. The managed configuration is in
`~/.config/nvim-workbench/zsh/.zshrc`; open a new workspace window after changes.
The prompt also appears inside Neovim's terminal buffer when launched through
the desktop workspace.

| Command | Action |
|---|---|
| `v`, `vi`, `vim` | Open Neovim |
| `nws [DIR]` | Open the workspace |
| `venv-create NAME` | Create and activate a named Python venv |
| `venv-use NAME` | Activate an existing project venv |
| `deactivate` | Leave the active Python venv |
| `docker-build-name IMAGE:TAG` | Build a named Docker image |
| `compose-up-name PROJECT` | Build/start a named Compose project |
| `compose-down-name PROJECT` | Stop a named Compose project |
| `cmake-presets` | List CMake configure presets |
| `cmake-build-presets` | List CMake build presets |
| `ctest-presets` | List CTest presets |

The bootstrap plugin list includes Git, Docker, Compose, Python, pip,
virtualenv, fzf, systemd, sudo, colored man pages, extract, command-not-found,
and directory jumping. If your own `.zshrc` already loads Oh My Zsh, its plugin
selection is retained while the theme and workbench helpers are applied.

## Core key mappings

`<leader>` is the Space key.

Markdown Preview and Neominimap operate on document buffers. If Neovim was
started with a directory such as `nvim .`, first select a file with
`<leader>ff` or press `<Enter>` on one in Neo-tree. They intentionally do not
run against the sidebar, dashboard, or terminal buffers.

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Open buffers |
| `<leader>e` | Toggle file tree |
| `<leader>cf` | Format current file |
| `<leader>mp` | Toggle Markdown preview in the browser |
| `<leader>mm` | Toggle the code minimap |
| `<leader>ca` | LSP code action |
| `<leader>rn` | Rename symbol |
| `gd` / `gr` | Peek definition / references |
| `K` | Hover documentation |
| `[d` / `]d` | Previous / next diagnostic |
| `<leader>xx` | Diagnostics panel |
| `<leader>gg` | LazyGit |
| `<leader>db` | Database UI |
| `<leader>t` | Floating terminal |
| `<C-\>` | Toggle floating terminal |
| `<Esc>` | Leave terminal mode |
| `<C-h/j/k/l>` | Move between Neovim splits |

## Debugging

Native C/C++/Rust/assembly programs can use GDB or CodeLLDB. Python/Sage uses
debugpy, and Go uses Delve. Build native programs with debug symbols (`-g`) and
avoid stripping the binary while debugging.

| Key | Action |
|---|---|
| `F5` / `<leader>dc` | Start or continue |
| `F10` / `<leader>do` | Step over |
| `F11` / `<leader>di` | Step into |
| `F12` / `<leader>dO` | Step out |
| `<leader>bp` | Toggle breakpoint |
| `<leader>bP` | Conditional breakpoint |
| `<leader>du` | Toggle debugger UI |
| `<leader>dr` | Open debugger REPL |
| `<leader>dt` | Terminate session |

Project-specific debugger definitions can be placed in `.vscode/launch.json`.
The built-in configurations prompt for a native executable when needed.

## Reverse-engineering workflow

The following commands avoid shell interpolation and open results in scratch
buffers:

| Key / command | Action |
|---|---|
| `<leader>hx` / `:HexToggle` | Toggle a safe editable `xxd` view |
| `<leader>rd` / `:Disassemble [file]` | Intel-syntax `objdump` disassembly |
| `<leader>rs` / `:BinaryStrings [file]` | Extract strings with hex offsets |

While hex view is enabled, `:write` automatically converts the dump back into
bytes before saving and then restores the hex view. Disable it with
`:HexToggle` before using normal text formatters or editing as plain text.

For deeper analysis, launch Ghidra, Rizin, or another GUI tool as a normal
tiled desktop window and keep source, debugger, shell, and analysis views next
to one another.

## Cybersecurity and cryptography workflow

- `.yar` and `.yara` files attach the YARA language server for diagnostics.
- Rust uses rust-analyzer with all Cargo features and Clippy checks.
- Go uses gopls with static analysis, goimports/gofumpt, golangci-lint, and Delve.
- `.sage` files use Python completion/highlighting and the Python debugger.
- C/C++ keeps clangd, clang-tidy, cppcheck, clang-format, GDB, and CodeLLDB.
- Do not put secrets, private keys, tokens, or production database passwords in
  this config, command history, debugger launch files, or Git.

## Named Python environments

Create environments under the current project root with any simple local name:

```vim
:VenvCreate .venv
:VenvCreate crypto-lab
:VenvCreate malware-sandbox
```

The new environment is activated automatically. Activation updates Neovim's
Python provider, new terminal jobs, pyright, and debugpy; its name also appears
in the status line. Other commands:

| Key / command | Action |
|---|---|
| `<leader>vc` / `:VenvCreate [NAME]` | Prompt for or create a named venv |
| `<leader>va` / `:VenvActivate [NAME_OR_PATH]` | Select/activate an existing venv |
| `<leader>vd` / `:VenvDeactivate` | Return to the original Python environment |
| `<leader>vi` / `:VenvInfo` | Show the active venv |

Add project environment directories such as `.venv/` or `crypto-lab/` to
`.gitignore`; never commit the environment itself.

## Named Docker images and Compose projects

Build an explicitly tagged image from the current project:

```vim
:DockerBuild forensic-toolkit:dev
:DockerBuild registry.example.com/team/scanner:1.2.0
```

Run `:DockerBuild` without an argument to get a prompt with
`PROJECT_NAME:dev` as the default. Image and Compose commands are:

| Key / command | Action |
|---|---|
| `<leader>ob` / `:DockerBuild [IMAGE:TAG]` | Build and name an image |
| `<leader>oi` / `:DockerImages` | List local image names, IDs, sizes, and ages |
| `<leader>or` / `:DockerRun [IMAGE:TAG]` | Select/run an image and name its container |
| `<leader>ou` / `:ComposeUp [PROJECT]` | Build and start a named Compose project |
| `<leader>od` / `:ComposeDown [PROJECT]` | Stop it without deleting volumes |
| `<leader>ol` / `:ComposeLogs [PROJECT]` | Follow logs for that project name |

Example Compose isolation for two copies of the same stack:

```vim
:ComposeUp crypto-red
:ComposeUp crypto-blue
:ComposeLogs crypto-red
:ComposeDown crypto-blue
```

## CMake presets

The config discovers configure, build, and test names from
`CMakePresets.json` and `CMakeUserPresets.json`. Run without an argument for a
selector, or pass the preset name directly:

```vim
:CMakeConfigurePreset debug
:CMakeBuildPreset debug
:CTestPreset unit-debug
```

| Key | Action |
|---|---|
| `<leader>pc` | Select a configure preset |
| `<leader>pb` | Select a build preset |
| `<leader>pt` | Select a CTest preset |

## Stack-specific setup

### ROS2

```bash
colcon build --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
ln -s build/compile_commands.json compile_commands.json
cp ~/.config/nvim/.clangd.example ~/ros2_ws/.clangd
```

`<leader>tr` opens a terminal pre-sourced for ROS2 Humble or Iron.

### ESP32, STM32, and Arduino

Generate `compile_commands.json` so clangd can resolve SDK and board headers:

```bash
# PlatformIO
pio run
ln -s .pio/build/ENV/compile_commands.json compile_commands.json

# ESP-IDF
idf.py build
ln -s build/compile_commands.json compile_commands.json
```

Arduino `.ino` and `.pde` files are treated as C++. PlatformIO gives the most
reliable completion database.

### PostgreSQL

`<leader>db` opens Dadbod UI. Add a connection with
`:DBUIAddConnection`. Dadbod state is stored under Neovim's data directory
(`~/.local/share/nvim/db_ui` on a default Linux installation), not in this Git
checkout. If an older installation has `~/.config/nvim/db_ui/connections.json`,
migrate it to the data directory and make sure it is not tracked. Environment
variables or a protected local SQLS config are preferable for secrets.

### Python virtual environments

Activate the environment before starting Neovim. The debugger automatically
checks `.venv/bin/python` and `venv/bin/python` before falling back to
`python3`.

## Troubleshooting

- Startup error: run `NVIM_SKIP_TOOL_INSTALL=1 nvim` to separate configuration
  problems from failed downloads.
- Missing LSP: check `:LspInfo`, `:Mason`, and whether the project has a root
  marker such as `.git`, `Cargo.toml`, `go.mod`, or `compile_commands.json`.
- No C/C++ headers: regenerate `compile_commands.json` and restart clangd.
- Debug adapter missing: install `codelldb`, `debugpy`, or `delve` in `:Mason`.
- Docker permission denied: make sure the Docker daemon is running and your
  account can access `/var/run/docker.sock` (commonly via the `docker` group),
  then log out and back in after changing group membership.
- Tree-sitter errors: verify `nvim --version`, run `:Lazy restore`, and then run
  `:TSUpdate`. Neovim 0.11 is pinned to the compatibility branches; Neovim
  0.12 uses the rewritten `main` branches and needs `tree-sitter-cli` 0.26.1+.
- Markdown preview fails: run `:Lazy build markdown-preview.nvim`, reopen the
  Markdown file, and press `<leader>mp`. Building the prebuilt server requires
  `curl` or `wget`, but not Node/npm. The preview URL is also printed in Neovim
  so it can be opened manually if the desktop handler or Flatpak portal is
  unavailable.
- Minimap is blank: open a normal source or document file before pressing
  `<leader>mm`; sidebar, dashboard, and terminal buffers are not valid sources.
- Clipboard unavailable: install the Wayland clipboard provider (`wl-clipboard`).

## Release smoke test

Run the same gate used by CI from the repository root:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py'
node tests/focus_border.test.cjs
python3 tests/desktop_integration.py
./scripts/smoke-test.sh
```

The launcher tests check installation, preservation of existing files, executable
discovery, argument quoting, and errors without opening desktop windows.

Set `NVIM_BIN=/path/to/nvim` to test another Neovim executable. The suite loads
every plugin after restoring the selected version-specific lockfile without
installing Mason tools, then checks both Tree-sitter paths, commands, custom
filetypes, virtual-environment cleanup, Dadbod storage, native/Flatpak install
targets, the live Markdown preview server and browser bridge, the minimap, and
a byte-preserving hex-edit round trip.
