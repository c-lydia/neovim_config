return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      local function executable(name)
        local mason_path = vim.fn.stdpath("data") .. "/mason/bin/" .. name
        if vim.fn.executable(mason_path) == 1 then return mason_path end
        return name
      end

      local function pick_program()
        return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
      end

      local function program_arguments()
        local args = vim.fn.input("Arguments: ")
        return args == "" and {} or vim.split(args, " ", { trimempty = true })
      end

      -- GDB 14+ has a native DAP adapter and is especially useful when
      -- stepping through stripped or partially symbolized binaries.
      dap.adapters.gdb = {
        type = "executable",
        command = "gdb",
        args = { "-i", "dap" },
      }

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = executable("codelldb"),
          args = { "--port", "${port}" },
        },
      }

      dap.adapters.python = {
        type = "executable",
        command = executable("debugpy-adapter"),
      }

      dap.adapters.delve = {
        type = "server",
        port = "${port}",
        executable = {
          command = executable("dlv"),
          args = { "dap", "-l", "127.0.0.1:${port}" },
        },
      }

      local native_configurations = {
        {
          name = "Launch executable (GDB)",
          type = "gdb",
          request = "launch",
          program = pick_program,
          args = program_arguments,
          cwd = "${workspaceFolder}",
          stopAtBeginningOfMainSubprogram = false,
        },
        {
          name = "Launch executable (CodeLLDB)",
          type = "codelldb",
          request = "launch",
          program = pick_program,
          args = program_arguments,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
        {
          name = "Attach to process (CodeLLDB)",
          type = "codelldb",
          request = "attach",
          pid = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
        },
      }

      dap.configurations.c = native_configurations
      dap.configurations.cpp = native_configurations
      dap.configurations.rust = native_configurations
      dap.configurations.asm = native_configurations

      dap.configurations.python = {
        {
          name = "Launch current Python/Sage file",
          type = "python",
          request = "launch",
          program = "${file}",
          cwd = "${workspaceFolder}",
          pythonPath = function()
            if vim.env.VIRTUAL_ENV and vim.fn.executable(vim.env.VIRTUAL_ENV .. "/bin/python") == 1 then
              return vim.env.VIRTUAL_ENV .. "/bin/python"
            end
            local candidates = {
              vim.fn.getcwd() .. "/.venv/bin/python",
              vim.fn.getcwd() .. "/venv/bin/python",
            }
            for _, path in ipairs(candidates) do
              if vim.fn.executable(path) == 1 then return path end
            end
            return vim.fn.exepath("python3")
          end,
        },
      }
      dap.configurations.sage = dap.configurations.python

      dap.configurations.go = {
        {
          name = "Debug current Go file",
          type = "delve",
          request = "launch",
          program = "${file}",
        },
        {
          name = "Debug Go package",
          type = "delve",
          request = "launch",
          program = "${workspaceFolder}",
        },
      }

      local launch_json = vim.fn.getcwd() .. "/.vscode/launch.json"
      if vim.fn.filereadable(launch_json) == 1 then
        require("dap.ext.vscode").load_launchjs(launch_json, {
          cppdbg = { "c", "cpp", "rust", "asm" },
          codelldb = { "c", "cpp", "rust", "asm" },
          python = { "python", "sage" },
          go = { "go" },
        })
      end

      dapui.setup({
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.35 },
              { id = "breakpoints", size = 0.2 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.2 },
            },
            size = 42,
            position = "left",
          },
          {
            elements = { "repl", "console" },
            size = 12,
            position = "bottom",
          },
        },
      })
      require("nvim-dap-virtual-text").setup({ commented = true })

      dap.listeners.before.attach.dapui = function() dapui.open() end
      dap.listeners.before.launch.dapui = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui = function() dapui.close() end
      dap.listeners.before.event_exited.dapui = function() dapui.close() end

      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "Visual" })

      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: continue/start" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: step over" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: step into" })
      vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: step out" })
      vim.keymap.set("n", "<leader>bp", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
      vim.keymap.set("n", "<leader>bP", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Conditional breakpoint" })
      vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Continue/start" })
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Step into" })
      vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Step over" })
      vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "Step out" })
      vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug REPL" })
      vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Terminate debug session" })
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Toggle debug UI" })
    end,
  },
}
