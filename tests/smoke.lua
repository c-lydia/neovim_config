local failures = {}

local function check(condition, message)
  if not condition then failures[#failures + 1] = message end
end

local function run_check(label, callback)
  local ok, err = xpcall(callback, debug.traceback)
  if not ok then failures[#failures + 1] = label .. ": " .. tostring(err) end
end

local function normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/$", "")
end

local version = vim.version()
local is_nvim_012 = vim.fn.has("nvim-0.12") == 1
local configured_lockfile = vim.fn.stdpath("config")
  .. (is_nvim_012 and "/lazy-lock-0.12.json" or "/lazy-lock.json")
local expected_root = vim.env.NVIM_RC_ROOT or vim.fn.stdpath("config")
local expected_lockfile = expected_root
  .. (is_nvim_012 and "/lazy-lock-0.12.json" or "/lazy-lock.json")
local lock = vim.json.decode(table.concat(vim.fn.readfile(expected_lockfile), "\n"))

local function plugin_revision(plugin)
  local result = vim.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }, { text = true }):wait()
  return result.code, (result.stdout or ""):gsub("%s+$", "")
end

check(vim.fn.has("nvim-0.11.3") == 1, "Neovim 0.11.3 or newer is required")

run_check("restore locked plugin revisions", function()
  local lazy_config = require("lazy.core.config")
  local drifted = {}

  for name, plugin in pairs(lazy_config.plugins) do
    if plugin._.installed and lock[name] then
      local result_code, actual = plugin_revision(plugin)
      if result_code == 0 and actual ~= lock[name].commit then
        drifted[#drifted + 1] = name
      end
    end
  end

  if #drifted > 0 then
    table.sort(drifted)
    require("lazy").restore({ plugins = drifted, wait = true, show = false })
    print("RC_SMOKE_RESTORED plugins=" .. table.concat(drifted, ","))
  end
end)

run_check("load every plugin", function()
  local lazy_config = require("lazy.core.config")
  local plugin_names = vim.tbl_keys(lazy_config.plugins)
  table.sort(plugin_names)

  require("lazy.core.loader").load(plugin_names, { start = "release-smoke" }, { force = true })
  vim.wait(500)

  check(
    normalize(lazy_config.options.lockfile) == normalize(configured_lockfile),
    "wrong lockfile selected: " .. tostring(lazy_config.options.lockfile)
  )

  for _, name in ipairs(plugin_names) do
    local plugin = lazy_config.plugins[name]
    check(plugin._.installed, "plugin is not installed: " .. name)
    check(plugin._.loaded, "plugin did not load: " .. name)
    check(lock[name] ~= nil, "plugin is not present in the selected lockfile: " .. name)

    if lock[name] then
      local result_code, actual = plugin_revision(plugin)
      check(result_code == 0, "could not read plugin revision: " .. name)
      check(
        actual == lock[name].commit,
        ("plugin revision does not match lockfile: %s (expected %s, got %s)"):format(
          name,
          lock[name].commit,
          actual
        )
      )
    end
  end

  local expected_branch = is_nvim_012 and "main" or "master"
  check(lock["nvim-treesitter"].branch == expected_branch, "wrong nvim-treesitter branch in lockfile")
  check(
    lock["nvim-treesitter-textobjects"].branch == expected_branch,
    "wrong nvim-treesitter-textobjects branch in lockfile"
  )
  check(lock["codewindow.nvim"] == nil, "removed codewindow.nvim is still locked")
  check(
    lock["neominimap.nvim"] and lock["neominimap.nvim"].commit == "0676085d898019f06044923934e38663f5efa290",
    "neominimap.nvim is not pinned to v3.16.0"
  )
end)

run_check("Tree-sitter API", function()
  if is_nvim_012 then
    check(pcall(require, "nvim-treesitter"), "Neovim 0.12 Tree-sitter API is unavailable")
    check(
      #vim.api.nvim_get_autocmds({ group = "ModernTreesitter" }) > 0,
      "Neovim 0.12 Tree-sitter autocmd was not registered"
    )
  else
    check(pcall(require, "nvim-treesitter.configs"), "Neovim 0.11 Tree-sitter API is unavailable")
  end
  local textobjects_module = is_nvim_012
      and "nvim-treesitter-textobjects.select"
    or "nvim-treesitter.textobjects.select"
  check(pcall(require, textobjects_module), "Tree-sitter textobjects failed to load")
  check(vim.treesitter.language.get_lang("sage") == "python", "Sage Tree-sitter alias is missing")
  check(vim.treesitter.language.get_lang("asm") == "nasm", "ASM Tree-sitter alias is missing")
end)

local required_commands = {
  "BinaryStrings",
  "CMakeBuildPreset",
  "CMakeConfigurePreset",
  "ComposeDown",
  "ComposeLogs",
  "ComposeUp",
  "CTestPreset",
  "DBUIToggle",
  "Disassemble",
  "DockerBuild",
  "DockerImages",
  "DockerRun",
  "HexToggle",
  "Lazy",
  "Mason",
  "Neominimap",
  "TSUpdate",
  "VenvActivate",
  "VenvCreate",
  "VenvDeactivate",
  "VenvInfo",
}
for _, command in ipairs(required_commands) do
  check(vim.fn.exists(":" .. command) == 2, "missing command :" .. command)
end

run_check("custom filetypes", function()
  local cases = {
    ["docker-compose.yml"] = "yaml.docker-compose",
    ["firmware.ino"] = "cpp",
    ["notebook.sage"] = "sage",
    ["threat.yara"] = "yara",
  }
  for filename, expected in pairs(cases) do
    check(
      vim.filetype.match({ filename = filename }) == expected,
      ("wrong filetype for %s (expected %s)"):format(filename, expected)
    )
  end
end)

run_check("Dadbod credential storage", function()
  local expected = normalize(vim.fn.stdpath("data") .. "/db_ui")
  local configured = normalize(vim.g.db_ui_save_location or "")
  check(configured == expected, "Dadbod state is not stored under stdpath('data')")
  check(
    not vim.startswith(configured .. "/", normalize(vim.fn.stdpath("config")) .. "/"),
    "Dadbod credentials would be written inside the Git checkout"
  )
end)

run_check("Flatpak detection and Markdown browser bridge", function()
  local platform = require("workbench.platform")
  local original_flatpak_id = vim.env.FLATPAK_ID
  vim.env.FLATPAK_ID = "io.neovim.nvim"
  check(platform.is_flatpak(), "Flatpak environment was not detected")
  vim.env.FLATPAK_ID = original_flatpak_id

  check(
    vim.g.mkdp_browserfunc == "WorkbenchMarkdownPreviewOpen",
    "Markdown preview is not using the workbench browser bridge"
  )
  check(
    vim.fn.exists("*WorkbenchMarkdownPreviewOpen") == 1,
    "Markdown preview browser bridge was not registered"
  )

  local original_open = vim.ui.open
  local opened_url
  vim.ui.open = function(url)
    opened_url = url
    return {}, nil
  end
  local ok, err = pcall(vim.fn.WorkbenchMarkdownPreviewOpen, "http://localhost:8765/page/1")
  vim.ui.open = original_open

  check(ok, "Markdown browser bridge failed: " .. tostring(err))
  check(opened_url == "http://localhost:8765/page/1", "Markdown browser bridge opened the wrong URL")
end)

run_check("Markdown preview end to end", function()
  local original_open = vim.ui.open
  local opened_url
  local ok, err = xpcall(function()
    vim.ui.open = function(url)
      opened_url = url
      return {}, nil
    end

    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Release preview", "", "Flatpak smoke test." })
    vim.bo.filetype = "markdown"
    check(vim.fn.exists(":MarkdownPreview") == 2, "missing buffer command :MarkdownPreview")
    vim.cmd("MarkdownPreview")
    check(vim.wait(8000, function() return opened_url ~= nil end, 100), "preview server did not open a URL")
    check(
      opened_url and opened_url:match("^http://localhost:%d+/page/%d+$") ~= nil,
      "preview server returned an invalid URL: " .. tostring(opened_url)
    )

    if opened_url and vim.fn.executable("curl") == 1 then
      local response
      vim.system({
        "curl", "--fail", "--silent", "--show-error", "--max-time", "5", opened_url,
      }, { text = true }, function(result) response = result end)
      check(vim.wait(6000, function() return response ~= nil end, 100), "preview page request timed out")
      response = response or {}
      check(response.code == 0, "preview page request failed: " .. tostring(response.stderr))
      check(
        response.stdout and response.stdout:find("<!DOCTYPE html", 1, true) ~= nil,
        "preview server did not return its HTML application"
      )
    end
  end, debug.traceback)

  vim.ui.open = original_open
  pcall(vim.cmd, "MarkdownPreviewStop")
  pcall(vim.cmd, "bwipeout!")
  if not ok then error(err) end
end)

run_check("inherited virtual environment cleanup", function()
  local test_venv = vim.env.RC_TEST_VENV
  local base_path = vim.env.RC_TEST_BASE_PATH
  check(test_venv and test_venv ~= "", "RC_TEST_VENV was not provided by the smoke runner")
  check(base_path ~= nil, "RC_TEST_BASE_PATH was not provided by the smoke runner")
  if not test_venv or base_path == nil then return end

  local original_python_host = vim.g.python3_host_prog
  require("workflows").activate_venv(test_venv)
  check(vim.env.VIRTUAL_ENV == normalize(test_venv), "virtual environment was not activated")
  check(vim.g.python3_host_prog == normalize(test_venv) .. "/bin/python", "Python provider was not updated")

  vim.cmd("VenvDeactivate")
  check(vim.env.VIRTUAL_ENV == nil, "virtual environment was not cleared")
  check(vim.env.PATH == base_path, "PATH did not return to its pre-venv value")
  check(vim.g.python3_host_prog == original_python_host, "Python provider was not restored")
end)

run_check("safe hex round trip", function()
  if vim.fn.executable("xxd") ~= 1 then return end

  local uv = vim.uv or vim.loop
  local path = vim.fn.tempname() .. ".bin"
  local expected = string.char(0, 1, 2, 10, 127, 128, 255) .. "release-candidate"
  local fd = assert(uv.fs_open(path, "w", 384))
  assert(uv.fs_write(fd, expected, 0))
  assert(uv.fs_close(fd))

  vim.cmd("edit! " .. vim.fn.fnameescape(path))
  vim.cmd("HexToggle")
  check(vim.b.hex_mode == true, "hex mode did not start")
  vim.cmd("write")
  vim.cmd("HexToggle")
  check(not vim.b.hex_mode, "hex mode did not stop")

  local read_fd = assert(uv.fs_open(path, "r", 384))
  local stat = assert(uv.fs_fstat(read_fd))
  local actual = assert(uv.fs_read(read_fd, stat.size, 0))
  assert(uv.fs_close(read_fd))
  check(actual == expected, "hex write changed the file bytes")

  vim.cmd("bwipeout!")
  assert(uv.fs_unlink(path))
end)

run_check("minimap toggle", function()
  check(
    require("neominimap.config").treesitter.enabled == is_nvim_012,
    "minimap selected the wrong Tree-sitter integration path"
  )
  vim.cmd("enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "local function release_candidate()",
    "  return true",
    "end",
  })
  vim.bo.filetype = "lua"
  vim.cmd("Neominimap Toggle")
  vim.wait(200)
  vim.cmd("Neominimap Toggle")
  vim.wait(100)
  vim.cmd("bwipeout!")
end)

vim.wait(200)

for _, message in ipairs(_G.RC_SMOKE_ERRORS or {}) do
  failures[#failures + 1] = "error notification: " .. message
end

local messages = vim.api.nvim_exec2("messages", { output = true }).output
for _, marker in ipairs({ "Error detected while processing", "Error executing callback", "stack traceback:" }) do
  if messages:find(marker, 1, true) then
    failures[#failures + 1] = "Neovim reported an error during startup; inspect :messages"
    break
  end
end

if #failures > 0 then
  vim.api.nvim_err_writeln("RC smoke test failed:\n- " .. table.concat(failures, "\n- "))
  vim.cmd("cquit 1")
  return
end

print(("RC_SMOKE_OK nvim=%d.%d.%d plugins=%d"):format(
  version.major,
  version.minor,
  version.patch,
  vim.tbl_count(require("lazy.core.config").plugins)
))
vim.cmd("qa!")
