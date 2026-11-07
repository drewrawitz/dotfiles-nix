-- Ctrl+h/j/k/l moves across Neovim splits and multiplexer panes as one set of panes.
-- tmux: the is_vim binding in home/.tmux.conf passes the key here; vim-tmux-navigator hands
-- back to tmux at the edge.
-- Herdr: the pane-nav mod (home/.config/herdr-app/mods/pane-nav) sends the key over the socket
-- below; at the edge we ask Herdr to move to the next pane.
local in_herdr = vim.env.TMUX == nil and vim.env.HC_TERMINAL_ID ~= nil

-- One socket per Herdr terminal, named after it, so the mod can find this Neovim. Skipped for a
-- Neovim nested in another one's terminal ($NVIM), which shares the outer one's terminal id.
if in_herdr and vim.env.NVIM == nil and vim.env.HC_TERMINAL_ID:match("^[%w_-]+$") then
  local dir = vim.fn.expand("~/.cache/herdr-nvim")
  local sock = dir .. "/" .. vim.env.HC_TERMINAL_ID .. ".sock"
  vim.fn.mkdir(dir, "p")
  vim.fn.delete(sock) -- left behind by a Neovim that crashed
  if pcall(vim.fn.serverstart, sock) then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        vim.fn.delete(sock)
      end,
    })
  end
end

local DIRS = { h = { "left", "Left" }, j = { "down", "Down" }, k = { "up", "Up" }, l = { "right", "Right" } }

local function navigate(key)
  local direction, name = unpack(DIRS[key])
  if not in_herdr then
    vim.cmd("TmuxNavigate" .. name)
    return
  end
  local win = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(key)
  if vim.api.nvim_get_current_win() == win then
    vim.system({ "herdr-app", "do", "pane.go", "--direction", direction }, { detach = true })
  end
end

local keys, term_keys = {}, {}
for key, dir in pairs(DIRS) do
  local lhs, desc = "<C-" .. key .. ">", "Go to " .. dir[2] .. " Window"
  table.insert(keys, { lhs, function() navigate(key) end, desc = desc })
  -- Snacks terminals (LazyVim's <C-/>) bind these in terminal mode to a plain wincmd, which
  -- dead-ends at Neovim's edge. Same as LazyVim's, except leaving goes through navigate().
  term_keys["nav_" .. key] = {
    lhs,
    function(self)
      return self:is_floating() and lhs or vim.schedule(function() navigate(key) end)
    end,
    desc = desc,
    expr = true,
    mode = "t",
  }
end

return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = { "TmuxNavigateLeft", "TmuxNavigateDown", "TmuxNavigateUp", "TmuxNavigateRight" },
    -- Its own <C-h/j/k/l> maps would replace ours as soon as it loads.
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
    keys = keys,
  },
  {
    "folke/snacks.nvim",
    opts = { terminal = { win = { keys = term_keys } } },
  },
}
