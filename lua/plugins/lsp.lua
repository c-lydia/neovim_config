local lsp_servers = {
  -- Existing development stacks
  "pyright",
  "clangd",
  "jdtls",
  "ts_ls",
  "html",
  "cssls",
  "jsonls",
  "lemminx",
  "dockerls",
  "docker_compose_language_service",
  "sqls",
  "bashls",
  "cmake",
  "marksman",
  "esbonio",
  "lua_ls",
  "yamlls",

  -- Reverse engineering / cybersecurity / cryptography
  "asm_lsp",
  "rust_analyzer",
  "gopls",
  "yls",
}

return {
  -- Mason installs LSP servers, formatters, linters, and debug adapters.
  {
    "mason-org/mason.nvim",
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      })
    end,
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    config = function()
      local tools = {
        -- Formatters
        "stylua",
        "black",
        "isort",
        "clang-format",
        "google-java-format",
        "prettier",
        "shfmt",
        "pgformatter",
        "xmlformatter",

        -- Linters
        "ruff",
        "mypy",
        "eslint_d",
        "hadolint",
        "markdownlint",
        "shellcheck",
        "yls-yara",

        -- Debug adapters
        "codelldb",
        "debugpy",
      }
      if vim.fn.executable("go") == 1 then
        vim.list_extend(tools, { "gofumpt", "goimports", "golangci-lint", "delve" })
      end

      require("mason-tool-installer").setup({
        auto_update = false,
        run_on_start = vim.env.NVIM_SKIP_TOOL_INSTALL ~= "1",
        ensure_installed = tools,
      })
    end,
  },

  -- Mason-lspconfig v2 installs servers and Neovim 0.11 enables them below.
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      local mason_servers = vim.tbl_filter(function(name)
        if name == "yls" then return false end
        if name == "asm_lsp" and vim.fn.executable("cargo") ~= 1 then return false end
        if (name == "gopls" or name == "sqls") and vim.fn.executable("go") ~= 1 then return false end
        return true
      end, lsp_servers)
      require("mason-lspconfig").setup({
        automatic_enable = false,
        ensure_installed = vim.env.NVIM_SKIP_TOOL_INSTALL == "1" and {} or mason_servers,
      })
    end,
  },

  { "b0o/schemastore.nvim" },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
      "b0o/schemastore.nvim",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
        callback = function(ev)
          local b = { noremap = true, silent = true, buffer = ev.buf }
          vim.keymap.set("n", "gd", ":Lspsaga peek_definition<CR>", b)
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, b)
          vim.keymap.set("n", "gr", ":Telescope lsp_references<CR>", b)
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, b)
          vim.keymap.set("n", "K", ":Lspsaga hover_doc<CR>", b)
          vim.keymap.set("n", "<leader>rn", ":Lspsaga rename<CR>", b)
          vim.keymap.set("n", "<leader>ca", ":Lspsaga code_action<CR>", b)
          vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, b)
          vim.keymap.set("n", "[d", ":Lspsaga diagnostic_jump_prev<CR>", b)
          vim.keymap.set("n", "]d", ":Lspsaga diagnostic_jump_next<CR>", b)
          vim.keymap.set("n", "<leader>dl", vim.diagnostic.open_float, b)
          vim.keymap.set("n", "<leader>lo", ":Lspsaga outline<CR>", b)
        end,
      })

      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded" },
      })

      local server_config = {
        pyright = {
          filetypes = { "python", "sage" },
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
                autoImportCompletions = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "workspace",
                extraPaths = {
                  "/opt/ros/humble/lib/python3/dist-packages",
                  "/opt/ros/iron/lib/python3/dist-packages",
                },
              },
            },
          },
        },

        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
            "--query-driver=/usr/bin/arm-none-eabi-g++,/usr/bin/xtensa-esp32-elf-g++,/usr/bin/avr-g++",
          },
          root_markers = {
            "compile_commands.json",
            "compile_flags.txt",
            "CMakeLists.txt",
            ".git",
          },
          init_options = { fallbackFlags = { "-std=c++17" } },
        },

        jdtls = {
          settings = {
            java = {
              format = { enabled = true },
              saveActions = { organizeImports = true },
              contentProvider = { preferred = "fernflower" },
            },
          },
        },

        jsonls = {
          settings = {
            json = {
              schemas = require("schemastore").json.schemas(),
              validate = { enable = true },
            },
          },
        },

        yamlls = {
          settings = {
            yaml = {
              schemaStore = { enable = false, url = "" },
              schemas = require("schemastore").yaml.schemas(),
            },
          },
        },

        lua_ls = {
          settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              workspace = {
                checkThirdParty = false,
                library = vim.api.nvim_get_runtime_file("", true),
              },
              diagnostics = { globals = { "vim" } },
              telemetry = { enable = false },
            },
          },
        },

        sqls = {
          on_attach = function(client, bufnr)
            require("sqls").on_attach(client, bufnr)
          end,
        },

        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = { allFeatures = true },
              check = { command = "clippy" },
              procMacro = { enable = true },
            },
          },
        },

        gopls = {
          settings = {
            gopls = {
              gofumpt = true,
              staticcheck = true,
              usePlaceholders = true,
              analyses = {
                shadow = true,
                unusedparams = true,
              },
            },
          },
        },
      }

      -- These servers are useful only when their host toolchain is installed.
      -- Define every config now, but avoid health-check noise until the
      -- executable becomes available. Restart Neovim after installing it.
      local optional_commands = {
        asm_lsp = "asm-lsp",
        gopls = "gopls",
        sqls = "sqls",
      }

      for _, server_name in ipairs(lsp_servers) do
        local config = vim.tbl_deep_extend(
          "force",
          { capabilities = capabilities },
          server_config[server_name] or {}
        )
        local executable = optional_commands[server_name]
        local can_enable = executable == nil or vim.fn.executable(executable) == 1

        if vim.lsp.config and vim.lsp.enable then
          vim.lsp.config(server_name, config)
          if can_enable then
            vim.lsp.enable(server_name)
          end
        else
          local lspconfig = require("lspconfig")
          local legacy_name = server_name == "ts_ls" and "tsserver" or server_name
          if lspconfig[legacy_name] then
            if can_enable then
              lspconfig[legacy_name].setup(config)
            end
          else
            vim.notify("Skipping unsupported LSP server: " .. server_name, vim.log.levels.WARN)
          end
        end
      end
    end,
  },

  { "nanotee/sqls.nvim" },

  {
    "nvimdev/lspsaga.nvim",
    event = "LspAttach",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lspsaga").setup({
        symbol_in_winbar = { enable = true },
        lightbulb = { enable = true, sign = false },
        outline = { auto_preview = true },
      })
    end,
  },

  {
    "ray-x/lsp_signature.nvim",
    event = "LspAttach",
    config = function()
      require("lsp_signature").setup({
        hint_enable = false,
        handler_opts = { border = "rounded" },
        toggle_key = "<C-k>",
      })
    end,
  },

  {
    "RRethy/vim-illuminate",
    event = "LspAttach",
    config = function()
      require("illuminate").configure({ delay = 200, large_file_cutoff = 2000 })
    end,
  },
}
