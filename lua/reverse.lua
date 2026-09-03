local M = {}
local bitlib = require("bit")

local hex_write_autocmds = {}

local function require_executable(name)
  if vim.fn.executable(name) == 1 then return true end
  vim.notify(name .. " is not installed or not on PATH", vim.log.levels.ERROR)
  return false
end

local function decode_hex_dump(bufnr, path)
  local input = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") .. "\n"
  local result = vim.system({ "xxd", "-r" }, { stdin = input }):wait()
  if result.code ~= 0 then
    vim.notify((result.stderr or "xxd could not decode this dump"):gsub("%s+$", ""), vim.log.levels.ERROR)
    return false
  end

  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(path)
  local mode = stat and bitlib.band(stat.mode, 511) or 420
  local fd, temporary_path, open_error = uv.fs_mkstemp(path .. ".nvim-hex-XXXXXX")
  if not fd then
    vim.notify("Could not create a temporary file: " .. tostring(open_error), vim.log.levels.ERROR)
    return false
  end

  local data = result.stdout or ""
  local offset = 0
  local write_error
  while offset < #data do
    local written
    written, write_error = uv.fs_write(fd, data:sub(offset + 1), offset)
    if not written then break end
    offset = offset + written
  end
  if offset == #data then
    uv.fs_fchmod(fd, mode)
    uv.fs_fsync(fd)
  end
  uv.fs_close(fd)
  if offset ~= #data then
    uv.fs_unlink(temporary_path)
    vim.notify("Could not write " .. path .. ": " .. tostring(write_error), vim.log.levels.ERROR)
    return false
  end

  local renamed, rename_error = uv.fs_rename(temporary_path, path)
  if not renamed then
    uv.fs_unlink(temporary_path)
    vim.notify("Could not replace " .. path .. ": " .. tostring(rename_error), vim.log.levels.ERROR)
    return false
  end

  vim.bo[bufnr].modified = false
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = bufnr, modeline = false })
  vim.notify("Wrote binary bytes to " .. path)
  return true
end

local function enter_hex(bufnr)
  if not require_executable("xxd") then return end
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" or vim.fn.filereadable(path) ~= 1 then
    vim.notify("Hex view needs an existing readable file", vim.log.levels.ERROR)
    return
  end
  if vim.bo[bufnr].modified then
    vim.notify("Write or discard current changes before entering hex view", vim.log.levels.WARN)
    return
  end

  local result = vim.system({ "xxd", "-g", "1", path }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify((result.stderr or "xxd failed"):gsub("%s+$", ""), vim.log.levels.ERROR)
    return
  end

  vim.b[bufnr].hex_original_options = {
    filetype = vim.bo[bufnr].filetype,
    binary = vim.bo[bufnr].binary,
    endofline = vim.bo[bufnr].endofline,
    fixendofline = vim.bo[bufnr].fixendofline,
  }

  local lines = vim.split(result.stdout or "", "\n", { plain = true })
  if lines[#lines] == "" then table.remove(lines) end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "xxd"
  vim.bo[bufnr].endofline = false
  vim.bo[bufnr].fixendofline = false
  vim.b[bufnr].hex_mode = true
  vim.bo[bufnr].modified = false

  hex_write_autocmds[bufnr] = vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function(args)
      local target = args.file ~= "" and vim.fn.fnamemodify(args.file, ":p")
        or vim.api.nvim_buf_get_name(args.buf)
      decode_hex_dump(args.buf, target)
    end,
    desc = "Write an editable xxd dump as raw bytes",
  })
  vim.notify("Hex view enabled; :write uses byte-preserving output")
end

local function leave_hex(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if vim.bo[bufnr].modified and not decode_hex_dump(bufnr, path) then return end

  if hex_write_autocmds[bufnr] then
    pcall(vim.api.nvim_del_autocmd, hex_write_autocmds[bufnr])
    hex_write_autocmds[bufnr] = nil
  end

  local original = vim.b[bufnr].hex_original_options or {}
  vim.b[bufnr].hex_mode = false
  vim.bo[bufnr].filetype = original.filetype or ""
  vim.bo[bufnr].binary = original.binary or false
  vim.bo[bufnr].endofline = original.endofline ~= false
  vim.bo[bufnr].fixendofline = original.fixendofline ~= false
  vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent edit!") end)
  vim.notify("Hex view disabled and file reloaded")
end

function M.toggle_hex()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.b[bufnr].hex_mode then
    leave_hex(bufnr)
  else
    enter_hex(bufnr)
  end
end

vim.api.nvim_create_autocmd("BufWipeout", {
  group = vim.api.nvim_create_augroup("SafeHexEditing", { clear = true }),
  callback = function(args) hex_write_autocmds[args.buf] = nil end,
})

local function target_file(argument)
  local path = argument ~= "" and vim.fn.fnamemodify(argument, ":p")
    or vim.api.nvim_buf_get_name(0)
  if path == "" or vim.fn.filereadable(path) ~= 1 then
    vim.notify("Choose a readable file first", vim.log.levels.ERROR)
    return nil
  end
  return path
end

local function open_tool_output(title, path, filetype, lines)
  vim.cmd("botright new")
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = filetype
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  pcall(vim.api.nvim_buf_set_name, bufnr, title .. "://" .. vim.fn.fnamemodify(path, ":t"))
end

local function run_inspection(tool, arguments, title, filetype, path)
  if not require_executable(tool) then return end
  local command = { tool }
  vim.list_extend(command, arguments)
  table.insert(command, path)

  vim.system(command, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify((result.stderr or (tool .. " failed")):gsub("%s+$", ""), vim.log.levels.ERROR)
        return
      end
      open_tool_output(title, path, filetype, vim.split(result.stdout or "", "\n", { plain = true }))
    end)
  end)
end

vim.api.nvim_create_user_command("HexToggle", M.toggle_hex, {
  desc = "Toggle a safe editable xxd view of the current file",
})

vim.api.nvim_create_user_command("Disassemble", function(opts)
  local path = target_file(opts.args)
  if path then run_inspection("objdump", { "-d", "-M", "intel" }, "Disassembly", "asm", path) end
end, { nargs = "?", complete = "file", desc = "Disassemble a binary with objdump" })

vim.api.nvim_create_user_command("BinaryStrings", function(opts)
  local path = target_file(opts.args)
  if path then run_inspection("strings", { "-a", "-t", "x" }, "Strings", "text", path) end
end, { nargs = "?", complete = "file", desc = "Extract offset-annotated strings from a binary" })

vim.keymap.set("n", "<leader>hx", M.toggle_hex, { desc = "Toggle hex view", silent = true })
vim.keymap.set("n", "<leader>rd", "<cmd>Disassemble<cr>", { desc = "Disassemble current file", silent = true })
vim.keymap.set("n", "<leader>rs", "<cmd>BinaryStrings<cr>", { desc = "Extract binary strings", silent = true })

return M
