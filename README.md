# Neovim Multi-Stack Workbench

A Neovim 0.11 configuration for application development, embedded systems,
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

Neovim 0.11 or newer is required. On Ubuntu, install the common native tools:

```bash
sudo apt install \
  git curl unzip build-essential ripgrep fd-find nodejs npm \
  python3 python3-pip xxd binutils gdb \
  clang clangd clang-format bear cppcheck shellcheck default-jdk \
  cmake ninja-build
```

Docker workflows require Docker Engine and the Compose v2 plugin (`docker
compose version` must work).

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

This configuration is active at `~/.config/nvim`. If copying it to another
machine:

```bash
mv ~/.config/nvim ~/.config/nvim.bak
cp -r /path/to/this/config ~/.config/nvim
nvim
```

Useful maintenance commands:

```vim
:Lazy sync
:Mason
:MasonToolsInstall
:TSUpdate
:checkhealth
:LspInfo
```

## Desktop workspace

Run the launcher from a terminal or choose **Neovim Workspace** from GNOME's
application menu:

```bash
nvim-workspace ~/projects/my-project
```

It opens three independent tiled-workspace-friendly windows:

1. A normal Neovim code IDE.
2. A separate Neovim instance starting in a terminal buffer.
3. A plain shell terminal.

Optional native GUI apps can be launched into the same GNOME workspace:

```bash
nvim-workspace ~/projects/my-project \
  --gui org.gnome.Nautilus \
  --gui firefox
```

Flatpak applications use their application ID. List installed IDs and then
pass one or more `--flatpak` options:

```bash
flatpak list --app --columns=application,name
nvim-workspace ~/projects/my-project \
  --flatpak com.brave.Browser \
  --flatpak md.obsidian.Obsidian
```

Native GUI apps cannot live inside terminal Neovim buffers; they remain normal
GNOME windows so input, rendering, clipboard, and application isolation keep
working correctly. Tile them with `Super+Arrow` or the numeric keypad tiling
shortcuts. The focused desktop window has a neon-blue outline. Inside Neovim,
the active split has a bright separator and cursor line while inactive splits
dim.

Two Tiling Assistant layouts make a desktop-level side-by-side workspace
available from inside Neovim or any other app:

| Key | Desktop layout |
|---|---|
| `Super+Alt+B` | Tile the focused Ptyxis/Neovim window on the left and open or reuse Firefox on the right |
| `Super+Alt+G` | Tile the focused Ptyxis/Neovim window on the left and choose an already-open GUI window for the right |

Once the windows are tiled, use `Super+Left` and `Super+Right` to move focus
between desktop apps. Continue using `Ctrl+h/j/k/l` for splits inside Neovim.
The layouts are stored in `~/.config/tiling-assistant/layouts.json`; change an
`appId` there if a different browser or fixed GUI app should replace Firefox.

## Oh My Zsh terminal workbench

Oh My Zsh uses the custom `neon-workbench` theme, matching the neon-blue
desktop focus outline and active Neovim separator. The prompt shows the current
directory, Git state, active Python environment, last-command failures, and
time. Git, Docker, Compose, Python, pip, virtualenv, fzf, systemd, sudo,
colored-man-pages, extract, command-not-found, and directory-jump plugins are
enabled.

Open a new terminal or reload the configuration with:

```zsh
source ~/.zshrc
```

Useful terminal helpers mirror the Neovim commands:

| Command | Action |
|---|---|
| `v`, `vi`, `vim` | Open Neovim |
| `nws [DIR]` | Open the multi-window Neovim workspace |
| `venv-create NAME` | Create and activate a named Python venv |
| `venv-use NAME` | Activate an existing project venv |
| `deactivate` | Leave the active Python venv |
| `docker-build-name IMAGE:TAG` | Build a named Docker image |
| `compose-up-name PROJECT` | Build/start a named Compose project |
| `compose-down-name PROJECT` | Stop it without deleting volumes |
| `cmake-presets` | List CMake configure presets |
| `cmake-build-presets` | List CMake build presets |
| `ctest-presets` | List CTest presets |

## Core key mappings

`<leader>` is the Space key.

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Open buffers |
| `<leader>e` | Toggle file tree |
| `<leader>cf` | Format current file |
| `<leader>mp` | Toggle Markdown preview in the browser |
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
`:DBUIAddConnection`. Keep credentials outside the repository; environment
variables or a protected local SQLS config are preferable.

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
- Tree-sitter errors: run `:Lazy sync` followed by `:TSUpdate`. Neovim 0.11 is
  intentionally pinned to Tree-sitter's compatibility branch.
- Markdown preview fails: run `:Lazy build markdown-preview.nvim`, reopen the
  Markdown file, and press `<leader>mp`. The preview URL is also printed in
  Neovim so it can be opened manually if desktop browser launching is blocked.
- Clipboard unavailable: install the Wayland clipboard provider (`wl-clipboard`).
