# Changelog

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

[0.1.0-rc.1]: https://github.com/c-lydia/neovim_config/releases/tag/v0.1.0-rc.1
