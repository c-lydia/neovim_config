local M = {}

local function regular_file_buffer(bufnr)
  bufnr = bufnr or 0
  if vim.bo[bufnr].buftype ~= "" then return false end

  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and vim.fn.isdirectory(name) == 0
end

function M.toggle_markdown_preview()
  if vim.bo.filetype ~= "markdown" then
    vim.notify(
      "Markdown Preview needs an open Markdown file. Open a .md file with <leader>ff, then retry.",
      vim.log.levels.WARN
    )
    return false
  end

  if vim.fn.exists(":MarkdownPreviewToggle") ~= 2 then
    vim.notify(
      "Markdown Preview is not ready. Run :Lazy build markdown-preview.nvim, reopen the file, and retry.",
      vim.log.levels.ERROR
    )
    return false
  end

  local ok, err = pcall(vim.cmd, "MarkdownPreviewToggle")
  if not ok then
    vim.notify("Could not toggle Markdown Preview: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.toggle_minimap()
  if not regular_file_buffer(0) then
    vim.notify(
      "The minimap needs an open file. Select one with <leader>ff or <Enter> in Neo-tree, then retry.",
      vim.log.levels.WARN
    )
    return false
  end

  local ok, api = pcall(require, "neominimap.api")
  if not ok then
    vim.notify("Neominimap is not ready: " .. tostring(api), vim.log.levels.ERROR)
    return false
  end

  local toggled, err = pcall(api.toggle)
  if not toggled then
    vim.notify("Could not toggle Neominimap: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  vim.notify(api.enabled() and "Minimap enabled" or "Minimap disabled")
  return true
end

return M
