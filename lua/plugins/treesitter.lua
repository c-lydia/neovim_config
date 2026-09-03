return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- The main branch is a Neovim 0.12 rewrite. Neovim 0.11 needs the
    -- backward-compatible master branch and its configs module.
    branch = "master",
    build = ":TSUpdate",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" },
    },
    config = function()
      -- Neovim calls assembly buffers `asm`; the available parser is `nasm`.
      vim.treesitter.language.register("nasm", "asm")
      vim.treesitter.language.register("python", "sage")

      require("nvim-treesitter.configs").setup({
        ensure_installed = vim.env.NVIM_SKIP_TOOL_INSTALL == "1" and {} or {
          -- Languages you use
          "python",       -- AI / YOLO / ROS2 / GStreamer Python bindings
          "c",            -- C / Arduino / STM32 / GStreamer core
          "cpp",          -- C++ / ROS2 / ESP32
          "java",
          "javascript",
          "typescript",
          "rust",         -- memory-safe security / cryptography tooling
          "go",           -- network and security tooling
          "nasm",         -- reverse engineering / disassembly

          -- Web
          "html",
          "css",

          -- Data formats
          "json",
          "xml",          -- URDF / ROS2 launch.xml / SVG
          "yaml",         -- ROS2 param files / Docker Compose / k8s
          "toml",
          "ini",          -- ESP-IDF sdkconfig

          -- Build systems & infra
          "cmake",        -- ROS2 / ESP-IDF / STM32
          "make",
          "dockerfile",

          -- Docs
          "markdown",
          "markdown_inline",
          "rst",          -- Sphinx docs

          -- Database
          "sql",

          -- Shell (ROS2 scripts, flash scripts)
          "bash",

          -- Neovim config
          "lua",
          "vim",
          "vimdoc",

          -- Misc
          "regex",
          "comment",
          "diff",
          "gitcommit",
          "gitignore",
        },

        auto_install = vim.env.NVIM_SKIP_TOOL_INSTALL ~= "1",

        highlight = {
          enable = true,
          -- RST and Markdown need this for embedded code blocks
          additional_vim_regex_highlighting = { "markdown", "rst" },
        },

        indent = { enable = true },

        -- <C-space> to expand selection by treesitter node
        incremental_selection = {
          enable  = true,
          keymaps = {
            init_selection    = "<C-space>",
            node_incremental  = "<C-space>",
            scope_incremental = "<C-s>",
            node_decremental  = "<M-space>",
          },
        },

        -- Text objects: select/move by function, class, block
        textobjects = {
          select = {
            enable   = true,
            lookahead = true,
            keymaps  = {
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
            enable     = true,
            set_jumps  = true,
            goto_next_start     = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
            goto_next_end       = { ["]F"] = "@function.outer", ["]C"] = "@class.outer" },
            goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
            goto_previous_end   = { ["[F"] = "@function.outer", ["[C"] = "@class.outer" },
          },
          swap = {
            enable   = true,
            swap_next     = { ["<leader>sp"] = "@parameter.inner" },
            swap_previous = { ["<leader>sP"] = "@parameter.inner" },
          },
        },
      })
    end,
  },
}
