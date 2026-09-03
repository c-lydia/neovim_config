return {
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",       -- LSP
      "hrsh7th/cmp-buffer",          -- buffer words
      "hrsh7th/cmp-path",            -- file paths
      "hrsh7th/cmp-cmdline",         -- : / ? command line
      "saadparwaiz1/cmp_luasnip",    -- snippet completions
      "L3MON4D3/LuaSnip",            -- snippet engine
      "rafamadriz/friendly-snippets", -- 50+ language snippet packs
      "onsails/lspkind.nvim",        -- VSCode-style icons
      "kristijanhusak/vim-dadbod-completion", -- SQL completions
    },
    config = function()
      local cmp     = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      -- Load pre-built snippets (Python, JS, C/C++, Java, etc.)
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },

        mapping = cmp.mapping.preset.insert({
          ["<C-k>"]     = cmp.mapping.select_prev_item(),
          ["<C-j>"]     = cmp.mapping.select_next_item(),
          ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<CR>"]      = cmp.mapping.confirm({ select = false }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),

        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip",  priority = 750 },
          { name = "buffer",   priority = 500 },
          { name = "path",     priority = 250 },
          -- SQL completions via dadbod
          { name = "vim-dadbod-completion", priority = 900 },
        }),

        formatting = {
          format = lspkind.cmp_format({
            mode       = "symbol_text",
            maxwidth   = 50,
            ellipsis_char = "...",
            menu = {
              nvim_lsp = "[LSP]",
              luasnip  = "[Snip]",
              buffer   = "[Buf]",
              path     = "[Path]",
              ["vim-dadbod-completion"] = "[DB]",
            },
          }),
        },

        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },

        experimental = { ghost_text = true },
      })

      -- Search completion (/ and ?)
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })

      -- Command-line completion (:)
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
          { { name = "path" } },
          { { name = "cmdline" } }
        ),
      })
    end,
  },

  -- Autopairs (integrates with cmp)
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({ check_ts = true })
      require("cmp").event:on(
        "confirm_done",
        require("nvim-autopairs.completion.cmp").on_confirm_done()
      )
    end,
  },

  -- Auto-close HTML/JSX tags
  {
    "windwp/nvim-ts-autotag",
    ft = { "html", "javascript", "typescript", "xml" },
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },
}
