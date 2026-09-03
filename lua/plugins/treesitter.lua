local is_nvim_012 = vim.fn.has("nvim-0.12") == 1

local parsers = {
  -- Languages
  "python", -- AI / YOLO / ROS2 / GStreamer Python bindings
  "c", -- C / Arduino / STM32 / GStreamer core
  "cpp", -- C++ / ROS2 / ESP32
  "java",
  "javascript",
  "typescript",
  "rust", -- memory-safe security / cryptography tooling
  "go", -- network and security tooling
  "nasm", -- reverse engineering / disassembly

  -- Web and data formats
  "html",
  "css",
  "json",
  "xml", -- URDF / ROS2 launch.xml / SVG
  "yaml", -- ROS2 param files / Docker Compose / k8s
  "toml",
  "ini", -- ESP-IDF sdkconfig

  -- Build systems and infrastructure
  "cmake", -- ROS2 / ESP-IDF / STM32
  "make",
  "dockerfile",

  -- Documentation and databases
  "markdown",
  "markdown_inline",
  "rst",
  "sql",

  -- Shell and Neovim configuration
  "bash",
  "lua",
  "vim",
  "vimdoc",

  -- Miscellaneous
  "regex",
  "comment",
  "diff",
  "gitcommit",
  "gitignore",
}

local function register_language_aliases()
  vim.treesitter.language.register("nasm", "asm")
  vim.treesitter.language.register("python", "sage")
  vim.treesitter.language.register("yaml", {
    "yaml.docker-compose",
    "yaml.gitlab",
    "yaml.helm-values",
  })
end

local function setup_legacy()
  require("nvim-treesitter.configs").setup({
    ensure_installed = vim.env.NVIM_SKIP_TOOL_INSTALL == "1" and {} or parsers,
    auto_install = vim.env.NVIM_SKIP_TOOL_INSTALL ~= "1",

    highlight = {
      enable = true,
      additional_vim_regex_highlighting = { "markdown", "rst" },
    },

    indent = { enable = true },

    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<C-space>",
        node_incremental = "<C-space>",
        scope_incremental = "<C-s>",
        node_decremental = "<M-space>",
      },
    },

    textobjects = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          ["ic"] = "@class.inner",
          ["ab"] = "@block.outer",
          ["ib"] = "@block.inner",
          ["aa"] = "@parameter.outer",
          ["ia"] = "@parameter.inner",
        },
      },
      move = {
        enable = true,
        set_jumps = true,
        goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
        goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer" },
        goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
        goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer" },
      },
      swap = {
        enable = true,
        swap_next = { ["<leader>sp"] = "@parameter.inner" },
        swap_previous = { ["<leader>sP"] = "@parameter.inner" },
      },
    },
  })
end

local modern_filetypes = {
  "python",
  "sage",
  "c",
  "cpp",
  "java",
  "javascript",
  "javascriptreact",
  "typescript",
  "rust",
  "go",
  "asm",
  "html",
  "css",
  "json",
  "jsonc",
  "xml",
  "xsd",
  "xslt",
  "svg",
  "yaml",
  "yaml.docker-compose",
  "yaml.gitlab",
  "yaml.helm-values",
  "toml",
  "confini",
  "dosini",
  "cmake",
  "make",
  "dockerfile",
  "markdown",
  "rst",
  "sql",
  "sh",
  "bash",
  "lua",
  "vim",
  "vimdoc",
  "diff",
  "gitdiff",
  "gitcommit",
  "gitignore",
}

local function setup_modern_textobjects()
  require("nvim-treesitter-textobjects").setup({
    select = { lookahead = true },
    move = { set_jumps = true },
  })

  local select = require("nvim-treesitter-textobjects.select")
  local move = require("nvim-treesitter-textobjects.move")
  local swap = require("nvim-treesitter-textobjects.swap")

  local selections = {
    af = "@function.outer",
    ["if"] = "@function.inner",
    ac = "@class.outer",
    ic = "@class.inner",
    ab = "@block.outer",
    ib = "@block.inner",
    aa = "@parameter.outer",
    ia = "@parameter.inner",
  }
  for lhs, capture in pairs(selections) do
    local capture_name = capture
    vim.keymap.set({ "x", "o" }, lhs, function()
      select.select_textobject(capture_name, "textobjects")
    end, { desc = "Select " .. capture_name })
  end

  local movements = {
    ["]f"] = { move.goto_next_start, "@function.outer" },
    ["]c"] = { move.goto_next_start, "@class.outer" },
    ["]F"] = { move.goto_next_end, "@function.outer" },
    ["]C"] = { move.goto_next_end, "@class.outer" },
    ["[f"] = { move.goto_previous_start, "@function.outer" },
    ["[c"] = { move.goto_previous_start, "@class.outer" },
    ["[F"] = { move.goto_previous_end, "@function.outer" },
    ["[C"] = { move.goto_previous_end, "@class.outer" },
  }
  for lhs, movement in pairs(movements) do
    local movement_fn = movement[1]
    local capture_name = movement[2]
    vim.keymap.set({ "n", "x", "o" }, lhs, function()
      movement_fn(capture_name, "textobjects")
    end, { desc = "Move to " .. capture_name })
  end

  vim.keymap.set("n", "<leader>sp", function()
    swap.swap_next("@parameter.inner")
  end, { desc = "Swap with next parameter" })
  vim.keymap.set("n", "<leader>sP", function()
    swap.swap_previous("@parameter.inner")
  end, { desc = "Swap with previous parameter" })
end

local function setup_modern()
  local treesitter = require("nvim-treesitter")
  treesitter.setup({})

  if vim.env.NVIM_SKIP_TOOL_INSTALL ~= "1" then
    -- Upstream defaults to 100 parallel parser jobs, which can exhaust DNS or
    -- file-descriptor limits during a first install of this broad parser set.
    treesitter.install(parsers, { max_jobs = 4 })
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ModernTreesitter", { clear = true }),
    pattern = modern_filetypes,
    callback = function(args)
      if pcall(vim.treesitter.start, args.buf) then
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end,
    desc = "Enable Tree-sitter highlighting and indentation",
  })

  setup_modern_textobjects()
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = is_nvim_012 and "main" or "master",
    lazy = false,
    build = ":TSUpdate",
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = is_nvim_012 and "main" or "master",
      },
    },
    config = function()
      register_language_aliases()
      if is_nvim_012 then
        setup_modern()
      else
        setup_legacy()
      end
    end,
  },
}
