-- ============================================================
-- Bootstrap lazy.nvim
-- ============================================================

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================
-- Plugins
-- ============================================================

require("lazy").setup({
  {
    "Mofiqul/dracula.nvim",
    priority = 1000,  -- load before other plugins
    config = function()
      vim.cmd.colorscheme("dracula")
    end,
  },
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    config = true,
    keys = {
      { "<leader>c", "<cmd>ClaudeCode<CR>",     desc = "claude" },
      { "<leader>c", "<cmd>ClaudeCodeSend<CR>", mode = "v", desc = "claude (send selection)" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      icons = { mappings = false },
      spec = {
        { "<leader>t",  desc = "terminal" },
        { "<leader>c",  group = "claude" },
      },
    },
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      open_mapping = [[<leader>t]],
      direction = "horizontal",
      size = 15,
      persist_size = true,
      persist_mode = true,
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      -- Exit terminal mode with Esc
      vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

      -- Window navigation from terminal mode
      vim.keymap.set("t", "<C-h>", "<Cmd>wincmd h<CR>")
      vim.keymap.set("t", "<C-j>", "<Cmd>wincmd j<CR>")
      vim.keymap.set("t", "<C-k>", "<Cmd>wincmd k<CR>")
      vim.keymap.set("t", "<C-l>", "<Cmd>wincmd l<CR>")
    end,
  },
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        layout = { preset = "sidebar" },
      },
      scroll = { enabled = true },
      gitbrowse = {},
      indent = { enabled = true },
    },
    keys = {
      { "<leader><space>", function() Snacks.picker.smart() end,    desc = "files" },
      { "<leader>/",       function() Snacks.picker.grep() end,     desc = "grep" },
      { "<leader>e",       function() Snacks.picker.explorer() end, desc = "explorer" },
      { "<leader>d",       function() Snacks.picker.git_diff() end, desc = "diff" },
      { "<leader>o",       function() Snacks.gitbrowse() end,       desc = "open on github" },
    },
  },
})

-- ============================================================
-- Options
-- ============================================================

local o = vim.opt

-- Line numbers
o.number = true
o.relativenumber = false

-- Indentation
o.expandtab = true       -- spaces instead of tabs
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true

-- Search
o.ignorecase = true      -- case-insensitive search...
o.smartcase = true       -- ...unless uppercase is typed
o.hlsearch = false       -- don't keep matches highlighted after search

-- UI
o.signcolumn = "yes"     -- always show gutter (avoids layout shifts)
o.cursorline = true
o.scrolloff = 8          -- keep 8 lines visible above/below cursor
o.wrap = false
o.termguicolors = true
o.splitright = true      -- vsplit opens to the right
o.splitbelow = true      -- split opens below

-- Files
o.swapfile = false
o.backup = false
o.undofile = true        -- persistent undo across sessions

-- Clipboard
o.clipboard = "unnamedplus"  -- use system clipboard

-- Misc
o.updatetime = 250       -- faster CursorHold events
o.timeoutlen = 300       -- faster which-key / chord timeout
o.mouse = "a"
o.confirm = true         -- ask to save instead of erroring on :q

-- ============================================================
-- Keymaps
-- ============================================================

local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", "Clear search highlight")

-- Better window navigation (normal + terminal mode)
map("n", "<C-h>", "<C-w>h", "Move to left window")
map("n", "<C-j>", "<C-w>j", "Move to lower window")
map("n", "<C-k>", "<C-w>k", "Move to upper window")
map("n", "<C-l>", "<C-w>l", "Move to right window")

-- Stay in visual mode after indent
map("v", "<", "<gv", "Indent left")
map("v", ">", ">gv", "Indent right")
