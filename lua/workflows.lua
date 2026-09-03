local M = {}

local original_path = vim.env.PATH

local function executable(name)
  if vim.fn.executable(name) == 1 then return true end
  vim.notify(name .. " is not installed or not on PATH", vim.log.levels.ERROR)
  return false
end

local function root(markers)
  return vim.fs.root(0, markers) or vim.fn.getcwd()
end

local function scratch(title, filetype, output)
  vim.cmd("botright new")
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(output, "\n", { plain = true }))
  vim.bo[bufnr].filetype = filetype
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  pcall(vim.api.nvim_buf_set_name, bufnr, title .. "://output")
end

local function terminal(title, command, cwd)
  vim.cmd("botright 15new")
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].bufhidden = "hide"
  pcall(vim.api.nvim_buf_set_name, bufnr, title .. "://terminal")
  local job = vim.fn.jobstart(command, {
    term = true,
    cwd = cwd,
    on_exit = function(_, code)
      vim.schedule(function()
        local level = code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(title .. " exited with status " .. code, level)
      end)
    end,
  })
  if job <= 0 then
    vim.notify("Could not start " .. title, vim.log.levels.ERROR)
    return
  end
  vim.cmd("startinsert")
end

-- Python virtual environments ----------------------------------------------

local function python_root()
  return root({ "pyproject.toml", "requirements.txt", "setup.py", ".git" })
end

local function valid_local_name(name, kind)
  if name == "" then return false end
  if name == "." or name == ".." or not name:match("^[%w._-]+$") then
    vim.notify(kind .. " may contain only letters, numbers, dot, underscore, and hyphen", vim.log.levels.ERROR)
    return false
  end
  return true
end

local function restart_pyright()
  if vim.fn.exists(":LspRestart") == 2 then
    vim.schedule(function() pcall(vim.cmd, "LspRestart pyright") end)
  end
end

function M.activate_venv(path)
  path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
  local python = path .. "/bin/python"
  if vim.fn.executable(python) ~= 1 then
    vim.notify("Not a Python virtual environment: " .. path, vim.log.levels.ERROR)
    return
  end

  vim.env.VIRTUAL_ENV = path
  vim.env.PATH = path .. "/bin:" .. original_path
  vim.g.python3_host_prog = python
  restart_pyright()
  vim.notify("Activated venv: " .. vim.fn.fnamemodify(path, ":t"))
end

local function discover_venvs()
  local project = python_root()
  local found = {}
  local seen = {}
  local candidates = {
    project .. "/.venv",
    project .. "/venv",
  }
  vim.list_extend(candidates, vim.fn.globpath(project, "*/bin/python", false, true))

  for _, candidate in ipairs(candidates) do
    local path = candidate:gsub("/bin/python$", "")
    if not seen[path] and vim.fn.executable(path .. "/bin/python") == 1 then
      seen[path] = true
      table.insert(found, path)
    end
  end
  return found
end

vim.api.nvim_create_user_command("VenvCreate", function(opts)
  if not executable("python3") then return end
  local name = opts.args ~= "" and opts.args or vim.fn.input("Virtual environment name: ", ".venv")
  if not valid_local_name(name, "Venv name") then return end

  local path = python_root() .. "/" .. name
  if vim.fn.isdirectory(path) == 1 then
    vim.notify("Directory already exists: " .. path, vim.log.levels.ERROR)
    return
  end

  vim.notify("Creating venv " .. name .. " …")
  vim.system({ "python3", "-m", "venv", "--prompt", name, path }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify((result.stderr or "venv creation failed"):gsub("%s+$", ""), vim.log.levels.ERROR)
        return
      end
      M.activate_venv(path)
    end)
  end)
end, { nargs = "?", desc = "Create and activate a named project venv" })

vim.api.nvim_create_user_command("VenvActivate", function(opts)
  if opts.args ~= "" then
    local path = opts.args
    if not vim.startswith(path, "/") then path = python_root() .. "/" .. path end
    M.activate_venv(path)
    return
  end

  local environments = discover_venvs()
  if #environments == 0 then
    vim.notify("No project venv found; run :VenvCreate NAME", vim.log.levels.WARN)
    return
  end
  vim.ui.select(environments, {
    prompt = "Activate virtual environment",
    format_item = function(item) return vim.fn.fnamemodify(item, ":t") .. "  " .. item end,
  }, function(choice)
    if choice then M.activate_venv(choice) end
  end)
end, { nargs = "?", complete = "dir", desc = "Select or activate a project venv" })

vim.api.nvim_create_user_command("VenvDeactivate", function()
  vim.env.VIRTUAL_ENV = nil
  vim.env.PATH = original_path
  vim.g.python3_host_prog = nil
  restart_pyright()
  vim.notify("Virtual environment deactivated")
end, { desc = "Deactivate the current project venv" })

vim.api.nvim_create_user_command("VenvInfo", function()
  vim.notify(vim.env.VIRTUAL_ENV and ("Active venv: " .. vim.env.VIRTUAL_ENV) or "No active venv")
end, { desc = "Show the active virtual environment" })

-- Docker images and Compose projects ---------------------------------------

local docker_markers = {
  "compose.yaml",
  "compose.yml",
  "docker-compose.yaml",
  "docker-compose.yml",
  "Dockerfile",
  ".git",
}

local function docker_root()
  return root(docker_markers)
end

local function default_project_name()
  local name = vim.fn.fnamemodify(docker_root(), ":t"):lower():gsub("[^a-z0-9_-]", "-")
  name = name:gsub("^[^a-z0-9]+", "")
  return name ~= "" and name or "workspace"
end

local function valid_docker_value(value, kind)
  if value == "" then return false end
  if value:match("^%-") or value:find("%s") then
    vim.notify(kind .. " cannot start with '-' or contain whitespace", vim.log.levels.ERROR)
    return false
  end
  return true
end

local function list_images(callback)
  if not executable("docker") then return end
  vim.system({
    "docker", "image", "ls",
    "--format", "{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedSince}}",
  }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify((result.stderr or "docker image ls failed"):gsub("%s+$", ""), vim.log.levels.ERROR)
        return
      end
      callback(result.stdout or "")
    end)
  end)
end

vim.api.nvim_create_user_command("DockerBuild", function(opts)
  if not executable("docker") then return end
  local default = default_project_name() .. ":dev"
  local image = opts.args ~= "" and opts.args or vim.fn.input("Docker image name:tag: ", default)
  if not valid_docker_value(image, "Image name") then return end
  terminal("Docker build " .. image, { "docker", "build", "-t", image, "." }, docker_root())
end, { nargs = "?", desc = "Build and name a Docker image" })

vim.api.nvim_create_user_command("DockerImages", function()
  list_images(function(output) scratch("Docker images", "text", output) end)
end, { desc = "List local Docker images" })

local function run_image(image)
  if not valid_docker_value(image, "Image name") then return end
  local suggested = image:gsub(".*/", ""):gsub(":.*", ""):gsub("[^%w_.-]", "-")
  local container = vim.fn.input("Container name: ", suggested .. "-dev")
  if not valid_docker_value(container, "Container name") then return end
  terminal(
    "Docker run " .. image,
    { "docker", "run", "--rm", "-it", "--name", container, image },
    docker_root()
  )
end

vim.api.nvim_create_user_command("DockerRun", function(opts)
  if not executable("docker") then return end
  if opts.args ~= "" then
    run_image(opts.args)
    return
  end
  list_images(function(output)
    local images = {}
    for line in output:gmatch("[^\r\n]+") do
      local image = line:match("^([^\t]+)")
      if image and not image:find("<none>", 1, true) then table.insert(images, image) end
    end
    vim.ui.select(images, { prompt = "Run Docker image" }, function(choice)
      if choice then run_image(choice) end
    end)
  end)
end, { nargs = "?", desc = "Select and run a named Docker image" })

local function compose_project(argument)
  local project = argument ~= "" and argument or vim.fn.input("Compose project name: ", default_project_name())
  if not project:match("^[a-z0-9][a-z0-9_-]*$") then
    vim.notify("Compose project names use lowercase letters, numbers, '_' and '-'", vim.log.levels.ERROR)
    return nil
  end
  return project
end

vim.api.nvim_create_user_command("ComposeUp", function(opts)
  if not executable("docker") then return end
  local project = compose_project(opts.args)
  if project then
    terminal(
      "Compose up " .. project,
      { "docker", "compose", "--project-name", project, "up", "--build" },
      docker_root()
    )
  end
end, { nargs = "?", desc = "Build and start a named Compose project" })

vim.api.nvim_create_user_command("ComposeDown", function(opts)
  if not executable("docker") then return end
  local project = compose_project(opts.args)
  if project then
    terminal(
      "Compose down " .. project,
      { "docker", "compose", "--project-name", project, "down" },
      docker_root()
    )
  end
end, { nargs = "?", desc = "Stop a named Compose project (keeps volumes)" })

vim.api.nvim_create_user_command("ComposeLogs", function(opts)
  if not executable("docker") then return end
  local project = compose_project(opts.args)
  if project then
    terminal(
      "Compose logs " .. project,
      { "docker", "compose", "--project-name", project, "logs", "--follow" },
      docker_root()
    )
  end
end, { nargs = "?", desc = "Follow logs for a named Compose project" })

-- CMake configure/build/test presets ---------------------------------------

local function cmake_root()
  return root({ "CMakePresets.json", "CMakeUserPresets.json", "CMakeLists.txt", ".git" })
end

local preset_commands = {
  configure = {
    tool = "cmake",
    list = { "cmake", "--list-presets" },
    run = function(name) return { "cmake", "--preset", name } end,
  },
  build = {
    tool = "cmake",
    list = { "cmake", "--build", "--list-presets" },
    run = function(name) return { "cmake", "--build", "--preset", name } end,
  },
  test = {
    tool = "ctest",
    list = { "ctest", "--list-presets" },
    run = function(name) return { "ctest", "--preset", name } end,
  },
}

local function run_preset(kind, requested)
  local definition = preset_commands[kind]
  if not executable(definition.tool) then return end
  local project = cmake_root()

  local function run(name)
    if name and name ~= "" then
      terminal("CMake " .. kind .. " preset " .. name, definition.run(name), project)
    end
  end

  if requested ~= "" then
    run(requested)
    return
  end

  vim.system(definition.list, { cwd = project, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify((result.stderr or "Could not list presets"):gsub("%s+$", ""), vim.log.levels.ERROR)
        return
      end
      local presets = {}
      for line in (result.stdout or ""):gmatch("[^\r\n]+") do
        local name = line:match('^%s*"([^"]+)"')
        if name then table.insert(presets, name) end
      end
      if #presets == 0 then
        vim.notify("No " .. kind .. " presets found", vim.log.levels.WARN)
        return
      end
      vim.ui.select(presets, { prompt = "CMake " .. kind .. " preset" }, run)
    end)
  end)
end

vim.api.nvim_create_user_command("CMakeConfigurePreset", function(opts)
  run_preset("configure", opts.args)
end, { nargs = "?", desc = "Select or run a CMake configure preset" })

vim.api.nvim_create_user_command("CMakeBuildPreset", function(opts)
  run_preset("build", opts.args)
end, { nargs = "?", desc = "Select or run a CMake build preset" })

vim.api.nvim_create_user_command("CTestPreset", function(opts)
  run_preset("test", opts.args)
end, { nargs = "?", desc = "Select or run a CTest preset" })

vim.keymap.set("n", "<leader>vc", "<cmd>VenvCreate<cr>", { desc = "Create named venv" })
vim.keymap.set("n", "<leader>va", "<cmd>VenvActivate<cr>", { desc = "Activate venv" })
vim.keymap.set("n", "<leader>vd", "<cmd>VenvDeactivate<cr>", { desc = "Deactivate venv" })
vim.keymap.set("n", "<leader>vi", "<cmd>VenvInfo<cr>", { desc = "Venv info" })
vim.keymap.set("n", "<leader>ob", "<cmd>DockerBuild<cr>", { desc = "Build named image" })
vim.keymap.set("n", "<leader>oi", "<cmd>DockerImages<cr>", { desc = "List images" })
vim.keymap.set("n", "<leader>or", "<cmd>DockerRun<cr>", { desc = "Run image" })
vim.keymap.set("n", "<leader>ou", "<cmd>ComposeUp<cr>", { desc = "Compose up" })
vim.keymap.set("n", "<leader>od", "<cmd>ComposeDown<cr>", { desc = "Compose down" })
vim.keymap.set("n", "<leader>ol", "<cmd>ComposeLogs<cr>", { desc = "Compose logs" })
vim.keymap.set("n", "<leader>pc", "<cmd>CMakeConfigurePreset<cr>", { desc = "Configure preset" })
vim.keymap.set("n", "<leader>pb", "<cmd>CMakeBuildPreset<cr>", { desc = "Build preset" })
vim.keymap.set("n", "<leader>pt", "<cmd>CTestPreset<cr>", { desc = "Test preset" })

return M
