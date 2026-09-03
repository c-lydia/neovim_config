# Changelog

## [0.1.0-rc.4] - 2026-09-03

### Fixed

- Guard Markdown Preview and Neominimap against directory, sidebar, dashboard,
  and terminal buffers so their mappings explain how to open a usable file
  instead of failing or displaying a blank minimap.

## [0.1.0-rc.3] - 2026-09-03

### Fixed

- Install Markdown Preview's prebuilt server synchronously without requiring
  Node/npm, including inside the Neovim Flatpak, and repair older caches that
  are missing or contain an interrupted download of the ignored server artifact.
- Open Markdown preview URLs through Neovim's desktop handler so Flatpak uses
  its OpenURI portal and failures retain a manually usable URL.
- Bootstrap lazy.nvim at its published lock revision and keep smoke-test copies
  from rewriting either source lockfile.

### Added

- A safe installer for native Neovim, Flatpak Neovim, or both.
- End-to-end smoke coverage for the Markdown preview server, browser bridge,
  Flatpak detection, and both installation targets.

## [0.1.0-rc.2] - 2026-09-03

### Fixed

- Restore cached plugin checkouts from the selected lockfile before release
  smoke assertions, keeping tag builds reproducible after a CI cache hit.
- Include the expected and actual plugin revisions in lock mismatch failures.

## [0.1.0-rc.1] - 2026-09-03

First release candidate of the multi-stack Neovim workbench.

### Fixed

- Support both Neovim 0.11.3+ and 0.12 with version-specific Tree-sitter APIs and lockfiles.
- Replace the unmaintained, Neovim 0.12-incompatible code-window plugin with neominimap.nvim 3.16.0.
- Keep Dadbod connection data, which can contain credentials, outside the Git checkout.
- Restore the original shell path and Python provider when leaving a virtual environment.
- Avoid false Delve errors when the optional Go debugger is not installed.
- Report lazy.nvim bootstrap failures instead of continuing with a misleading module error.

### Added

- A two-version headless smoke suite that loads every plugin and tests Tree-sitter, commands, custom filetypes, virtual environments, minimap startup, and byte-safe hex writes.
- CI coverage for Neovim 0.11.6 and 0.12.4.
- Separate reproducible plugin locks for the legacy and current Tree-sitter branches.

[0.1.0-rc.3]: https://github.com/c-lydia/neovim_config/releases/tag/v0.1.0-rc.3
[0.1.0-rc.2]: https://github.com/c-lydia/neovim_config/releases/tag/v0.1.0-rc.2
[0.1.0-rc.1]: https://github.com/c-lydia/neovim_config/releases/tag/v0.1.0-rc.1
