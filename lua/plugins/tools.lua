return {
  -- ── Telescope ────────────────────────────────────────────────
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("telescope").setup({
        defaults = {
          path_display = { "smart" },
          file_ignore_patterns = {
            "%.git/",
            "node_modules/",
            "__pycache__/",
            "%.pyc",
            -- ROS2 / colcon build artifacts
            "^build/", "^install/", "^log/",
            -- Embedded build artifacts
            "%.o$", "%.a$", "%.so$", "%.elf$", "%.bin$", "%.hex$",
            -- Python virtual envs
            "%.venv/", "venv/",
            -- AI model weights (large files)
            "%.pt$", "%.pth$", "%.onnx$", "%.weights$",
          },
        },
        extensions = {
          fzf = {
            fuzzy                   = true,
            override_generic_sorter = true,
            override_file_sorter    = true,
          },
        },
      })
      require("telescope").load_extension("fzf")
    end,
  },

  -- ── Formatting (conform.nvim) ────────────────────────────────
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd   = { "ConformInfo" },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          lua         = { "stylua" },
          -- Python: sort imports first, then format
          python      = { "isort", "black" },
          -- C/C++ (also covers Arduino .ino via filetype override)
          c           = { "clang_format" },
          cpp         = { "clang_format" },
          java        = { "google_java_format" },
          javascript  = { "prettier" },
          typescript  = { "prettier" },
          html        = { "prettier" },
          css         = { "prettier" },
          json        = { "prettier" },
          yaml        = { "prettier" },
          markdown    = { "prettier" },
          -- RST: install with `pip install rstfmt`
          rst         = { "rstfmt" },
          xml         = { "xmlformat" },
          sql         = { "pg_format" },
          sh          = { "shfmt" },
          bash        = { "shfmt" },
          go          = { "goimports", "gofumpt" },
          rust        = { "rustfmt" },
          -- Catch-all for unrecognised types
          ["_"]       = { "trim_whitespace" },
        },
        format_on_save = function(bufnr)
          -- A hex dump must be converted back to bytes before any formatter
          -- sees it, otherwise whitespace cleanup can corrupt the file.
          if vim.b[bufnr].hex_mode then return end
          return { timeout_ms = 3000, lsp_format = "fallback" }
        end,
        -- clang-format style for embedded: adjust per project
        formatters = {
          clang_format = {
            prepend_args = { "--style=file,{BasedOnStyle: LLVM, IndentWidth: 4}" },
          },
        },
      })
    end,
  },

  -- ── Linting (nvim-lint) ──────────────────────────────────────
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python     = { "ruff", "mypy" },
        c          = { "cppcheck" },
        cpp        = { "cppcheck" },
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        dockerfile = { "hadolint" },
        markdown   = { "markdownlint" },
        sh         = { "shellcheck" },
        bash       = { "shellcheck" },
        go         = { "golangcilint" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        callback = function() lint.try_lint() end,
      })
    end,
  },

  -- ── Git signs in gutter ──────────────────────────────────────
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        current_line_blame      = true,
        current_line_blame_opts = { delay = 500 },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local b  = { buffer = bufnr }
          vim.keymap.set("n", "<leader>hs", gs.stage_hunk,   b)
          vim.keymap.set("n", "<leader>hr", gs.reset_hunk,   b)
          vim.keymap.set("n", "<leader>hu", gs.undo_stage_hunk, b)
          vim.keymap.set("n", "<leader>hp", gs.preview_hunk, b)
        end,
      })
    end,
  },

  -- ── LazyGit ──────────────────────────────────────────────────
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- ── Terminal ─────────────────────────────────────────────────
  -- Useful for: running ROS2 nodes, esptool.py flash, openocd, etc.
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size      = 20,
        open_mapping = [[<C-\>]],
        direction = "float",
        float_opts = { border = "curved" },
        shell     = vim.o.shell,
        -- Useful terminal presets
        -- <leader>t  → general float terminal
        -- Ctrl-\     → toggle
      })

      -- Named terminals for common workflows
      local Terminal = require("toggleterm.terminal").Terminal

      -- ROS2 terminal (sources setup.bash automatically)
      local ros2_term = Terminal:new({
        cmd  = "bash --rcfile <(echo 'source /opt/ros/humble/setup.bash 2>/dev/null || source /opt/ros/iron/setup.bash 2>/dev/null; exec bash')",
        direction = "float",
        hidden = true,
      })
      vim.keymap.set("n", "<leader>tr", function() ros2_term:toggle() end,
        { desc = "ROS2 terminal", noremap = true, silent = true })

      -- Python/IPython terminal
      local python_term = Terminal:new({ cmd = "python3", direction = "float", hidden = true })
      vim.keymap.set("n", "<leader>tp", function() python_term:toggle() end,
        { desc = "Python REPL", noremap = true, silent = true })

      -- PostgreSQL terminal
      local pg_term = Terminal:new({ cmd = "psql", direction = "float", hidden = true })
      vim.keymap.set("n", "<leader>tq", function() pg_term:toggle() end,
        { desc = "psql", noremap = true, silent = true })
    end,
  },

  -- ── Trouble (diagnostics list) ───────────────────────────────
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("trouble").setup()
    end,
  },

  -- ── Comment toggling ─────────────────────────────────────────
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("Comment").setup({
        -- Handles C/C++ block comments, Python #, XML/HTML <!-- -->
        toggler  = { line = "gcc", block = "gbc" },
        opleader = { line = "gc",  block = "gb"  },
      })
    end,
  },

  -- ── Surround ─────────────────────────────────────────────────
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    config = function() require("nvim-surround").setup() end,
  },

  -- ── PostgreSQL / Database UI ─────────────────────────────────
  -- Usage: <leader>db → open DBUI
  -- Add connections with :DBUIAddConnection
  -- Example connection string: postgresql://user:pass@localhost/mydb
  {
    "tpope/vim-dadbod",
    lazy = true,
  },
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = { "tpope/vim-dadbod" },
    cmd  = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
    init = function()
      -- connections.json may contain database credentials. Keep it with
      -- application data instead of inside this Git repository. These globals
      -- must be set before plugin/db_ui.vim reads them.
      vim.g.db_ui_save_location     = vim.fn.stdpath("data") .. "/db_ui"
      vim.g.db_ui_use_nerd_fonts    = 1
      vim.g.db_ui_show_database_icon = 1
    end,
  },

  -- ── Markdown preview ─────────────────────────────────────────
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    -- A colon command makes Lazy load the plugin before calling its autoload
    -- installer. The synchronous variant prevents a first-run race.
    build = ":call mkdp#util#install_sync(v:true)",
    init = function()
      require("workbench.platform").configure_markdown_preview()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_theme = "dark"
      vim.g.mkdp_echo_preview_url = 1
      vim.g.mkdp_auto_close = 1
    end,
    config = function(plugin)
      local package = vim.json.decode(table.concat(vim.fn.readfile(plugin.dir .. "/package.json"), "\n"))
      local function server_is_valid()
        local ok, version = pcall(vim.fn["mkdp#util#pre_build_version"])
        return ok and vim.trim(version) == package.version
      end
      if server_is_valid() then return end

      -- Existing Lazy caches may contain the checkout but not the ignored
      -- prebuilt artifact, or an interrupted download. Repair those installs
      -- when the plugin loads and validate the binary rather than just its mode.
      vim.notify("Markdown Preview server is missing; installing its prebuilt server …")
      local ok, err = pcall(vim.fn["mkdp#util#install_sync"], true)
      if not ok or not server_is_valid() then
        vim.notify(
          "Could not install the Markdown Preview server: " .. tostring(err or "download failed"),
          vim.log.levels.ERROR
        )
      end
    end,
    ft = { "markdown" },
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Toggle Markdown preview" },
    },
  },

  -- ── Global search & replace ──────────────────────────────────
  {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Spectre",
  },

  -- ── Better f/t with multi-char support ──────────────────────
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    config = function() require("flash").setup() end,
    keys  = {
      { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end },
      { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end },
    },
  },

  -- ── Minimap / code overview ──────────────────────────────────
  {
    "Isrothy/neominimap.nvim",
    version = "v3.16.0",
    lazy = false,
    init = function()
      vim.g.neominimap = {
        auto_enable = false,
        notification_level = vim.log.levels.WARN,
        -- Neominimap's optional Tree-sitter integration follows the rewritten
        -- API. The minimap itself remains fully usable on Neovim 0.11.
        treesitter = { enabled = vim.fn.has("nvim-0.12") == 1 },
      }
    end,
    keys = {
      { "<leader>mm", "<cmd>Neominimap Toggle<cr>", desc = "Toggle minimap" },
    },
  },
}
