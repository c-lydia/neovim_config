return {
  -- ── Colorscheme ─────────────────────────────────────────────
  {
    "catppuccin/nvim",
    name     = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",   -- latte | frappe | macchiato | mocha
        auto_integrations = false,
        integrations = {
          treesitter  = true,
          native_lsp  = { enabled = true },
          telescope   = { enabled = true },
          neotree     = true,
          gitsigns    = true,
          mason       = true,
          which_key   = true,
          bufferline  = true,
          lsp_saga    = true,
          noice       = true,
          notify      = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- ── Status line ─────────────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local function active_venv()
        if not vim.env.VIRTUAL_ENV then return "" end
        return " " .. vim.fn.fnamemodify(vim.env.VIRTUAL_ENV, ":t")
      end

      require("lualine").setup({
        options  = { theme = "catppuccin-nvim", globalstatus = true },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { active_venv, "filetype", "encoding" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })
    end,
  },

  -- ── Buffer tabs ─────────────────────────────────────────────
  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          offsets = {{
            filetype  = "neo-tree",
            text      = "File Explorer",
            highlight = "Directory",
          }},
          separator_style = "slant",
        },
      })
    end,
  },

  -- ── File tree ───────────────────────────────────────────────
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
        filesystem = {
          filtered_items = {
            hide_dotfiles  = false,
            hide_gitignored = false,
          },
          follow_current_file = { enabled = true },
          use_libuv_file_watcher = true,
        },
        window = { width = 30 },
      })
    end,
  },

  -- ── Indent guides ───────────────────────────────────────────
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    config = function()
      require("ibl").setup({ scope = { enabled = true } })
    end,
  },

  -- ── Which-key ───────────────────────────────────────────────
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local wk = require("which-key")
      wk.setup()
      wk.add({
        { "<leader>b", group = "Breakpoints" },
        { "<leader>c", group = "Code" },
        { "<leader>d", group = "Debug / Database" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>h", group = "Hex / Git hunks" },
        { "<leader>m", group = "Markdown / Minimap" },
        { "<leader>o", group = "Docker / Compose" },
        { "<leader>p", group = "CMake presets" },
        { "<leader>r", group = "Reverse engineering" },
        { "<leader>s", group = "Search" },
        { "<leader>t", group = "Terminals" },
        { "<leader>v", group = "Python venv" },
        { "<leader>x", group = "Diagnostics" },
      })
    end,
  },

  -- ── Noice (pretty cmdline / messages) ───────────────────────
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    config = function()
      require("noice").setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"]   = true,
          },
        },
        presets = {
          bottom_search     = true,
          command_palette   = true,
          long_message_to_split = true,
        },
      })
    end,
  },

  -- ── Colorizer (hex colors in CSS / HTML / JS) ───────────────
  {
    "NvChad/nvim-colorizer.lua",
    ft = { "css", "html", "javascript", "typescript", "json", "yaml" },
    config = function()
      require("colorizer").setup()
    end,
  },

  -- ── TODO / FIXME / HACK highlights ─────────────────────────
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup()
    end,
  },

  -- ── Dim inactive code ───────────────────────────────────────
  {
    "folke/twilight.nvim",
    cmd = "Twilight",
    config = function()
      require("twilight").setup()
    end,
  },
}
