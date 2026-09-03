local M = {}

local uv = vim.uv or vim.loop

function M.is_flatpak()
  return (vim.env.FLATPAK_ID and vim.env.FLATPAK_ID ~= "")
    or uv.fs_stat("/.flatpak-info") ~= nil
end

local function open_error(url, message)
  local context = M.is_flatpak() and " through the Flatpak desktop portal" or ""
  vim.notify(
    ("Could not open the Markdown preview%s: %s\nPreview URL: %s"):format(
      context,
      tostring(message),
      url
    ),
    vim.log.levels.ERROR
  )
end

function M.open_url(url)
  local ok, process, err = pcall(vim.ui.open, url)
  if not ok then
    open_error(url, process)
    return false
  end
  if not process then
    open_error(url, err or "no desktop URL handler was found")
    return false
  end
  return true
end

function M.configure_markdown_preview()
  vim.api.nvim_exec2([[
    function! WorkbenchMarkdownPreviewOpen(url) abort
      return luaeval('require("workbench.platform").open_url(_A)', a:url)
    endfunction
  ]], {})
  vim.g.mkdp_browserfunc = "WorkbenchMarkdownPreviewOpen"
end

return M
