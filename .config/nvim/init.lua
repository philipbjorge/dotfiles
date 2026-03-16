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
    cmd = { "ClaudeCode", "ClaudeCodeSend" },
    opts = {
      terminal = {
        split_side = "right",
        split_width_percentage = 0.40,
        provider = "snacks",
        snacks_win_opts = {
          keys = {
            term_normal = { "<esc>", "<C-\\><C-n>", mode = "t", desc = "Exit terminal mode" },
          },
        },
      },
    },
    keys = {
      { "<leader>c", "<cmd>ClaudeCode<CR>",     desc = "claude" },
      { "<leader>c", "<cmd>ClaudeCodeSend<CR>", mode = "v", desc = "claude (send selection)" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      icons = { mappings = false },
      win = {
        border = "rounded",
        padding = { 1, 2 },
        title = " keybindings ",
        title_pos = "center",
        width = 0.5,
      },
      layout = {
        width = { min = 20, max = 40 },
        spacing = 4,
      },
      spec = {
        { "<leader>?",  desc = "command palette" },
        { "<leader>b",  desc = "buffers" },
        { "<leader>c",  desc = "claude" },
        { "<leader>e",  desc = "explorer" },
        { "<leader>q",  desc = "close buffer" },
        { "<leader>t",  desc = "terminal" },
        { "<leader>d",  group = "diagnostics" },
        { "<leader>g",  group = "git" },
        { "<leader>l",  group = "lsp" },
      },
    },
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      open_mapping = [[<leader>t]],
      insert_mappings = false,
      direction = "horizontal",
      size = 15,
      persist_size = true,
      persist_mode = true,
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      -- Tab winbar: shows all open terminals above the terminal window
      local function term_label(id)
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.b[buf].toggle_number == id then
            local title = vim.b[buf].term_title or ""
            if title ~= "" then
              -- strip "user@host: " prefix, just show the path/command
              return title:match(": (.+)$") or title
            end
          end
        end
        return "terminal " .. id
      end

      _G.ToggleTermRefreshWinbar = function()
        local ok, tt = pcall(require, "toggleterm.terminal")
        if not ok then return end
        local terms = tt.get_all(true)
        if #terms == 0 then return end
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "toggleterm" then
            local cur_id = vim.b[buf].toggle_number
            local parts = {}
            for _, t in ipairs(terms) do
              local label = term_label(t.id)
              if t.id == cur_id then
                table.insert(parts, "%#TabLineSel# ● " .. label .. " %#WinBar#")
              else
                table.insert(parts, "%#TabLine# " .. label .. " %#WinBar#")
              end
            end
            vim.wo[win].winbar = "  " .. table.concat(parts, " ")
          end
        end
      end

      vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter" }, {
        pattern = "term://*toggleterm*",
        callback = vim.schedule_wrap(_G.ToggleTermRefreshWinbar),
      })
      -- refresh tab names when shell updates the terminal title (e.g. on cd)
      vim.api.nvim_create_autocmd("TermResponse", {
        callback = function()
          if vim.bo.filetype == "toggleterm" then
            vim.schedule(_G.ToggleTermRefreshWinbar)
          end
        end,
      })
    end,
  },
  -- ── Treesitter ───────────────────────────────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "python", "typescript", "tsx", "javascript", "dart",
        "lua", "yaml", "hcl", "json", "bash", "dockerfile",
      },
      highlight = { enable = true },
      indent    = { enable = true },
    },
  },
  -- ── LSP ──────────────────────────────────────────────────────────────
  { "williamboman/mason.nvim", config = true },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = { "basedpyright", "ts_ls", "lua_ls", "yamlls", "terraformls", "jsonls" },
      automatic_enable = true, -- calls vim.lsp.enable() for each installed server
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      -- Apply capabilities to all servers via the new 0.11 API
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Auto-detect YAML schemas (kubernetes, github actions, etc.) by file content
      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            schemaStore = { enable = true },
          },
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = args.buf, desc = desc })
          end
          map("<leader>ln", vim.lsp.buf.rename,          "rename")
          map("<leader>la", vim.lsp.buf.code_action,   "code action")
          map("<leader>lt", vim.lsp.buf.type_definition, "type definition")
          map("<leader>le", vim.diagnostic.open_float,  "show error")
          -- standard vim motions (preferred over <leader>l equivalents)
          map("gd", vim.lsp.buf.definition, "go to definition")
          map("K",  vim.lsp.buf.hover,      "hover docs")
          -- inlay hints
          vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })

        end,
      })
    end,
  },
  {
    "akinsho/flutter-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      flutter_path = (function()
        -- Walk up from cwd to find a project-local .flutter-sdk (e.g. ~/src/apog)
        local path = vim.fn.getcwd()
        while path ~= "/" do
          local bin = path .. "/.flutter-sdk/flutter/bin/flutter"
          if vim.fn.executable(bin) == 1 then return bin end
          path = vim.fn.fnamemodify(path, ":h")
        end
        return vim.fn.exepath("flutter") -- fall back to system flutter
      end)(),
    },
  },
  -- ── Glance ───────────────────────────────────────────────────────────
  {
    "dnlhc/glance.nvim",
    opts = {},
    keys = {
      { "gD", "<cmd>Glance definitions<cr>",      desc = "Peek definition" },
      { "gR", "<cmd>Glance references<cr>",       desc = "Peek references" },
      { "gY", "<cmd>Glance type_definitions<cr>", desc = "Peek type definition" },
      { "gM", "<cmd>Glance implementations<cr>",  desc = "Peek implementations" },
    },
  },
  -- ── Bufferline ───────────────────────────────────────────────────────
  {
    "akinsho/bufferline.nvim",
    lazy = false,
    opts = {
      options = {
        diagnostics = "nvim_lsp",           -- show error/warn counts on tabs
        show_buffer_close_icons = true,
        show_close_icon = false,
        custom_filter = function(buf)
          local bt = vim.bo[buf].buftype
          local ft = vim.bo[buf].filetype
          local name = vim.api.nvim_buf_get_name(buf)
          if bt == "terminal" then return false end
          if ft:match("^snacks_") then return false end
          if name:match("^term://") then return false end
          return true
        end,
      },
    },
    keys = {
      { "H",           "<cmd>BufferLineCyclePrev<cr>",  desc = "Prev buffer" },
      { "L",           "<cmd>BufferLineCycleNext<cr>",  desc = "Next buffer" },
      { "<leader>q",   "<cmd>bdelete<cr>",              desc = "Close buffer" },
    },
  },
  -- ── Fidget ───────────────────────────────────────────────────────────
  { "j-hui/fidget.nvim", opts = {} },
  -- ── Statuscolumn ─────────────────────────────────────────────────────
  {
    "luukvbaal/statuscol.nvim",
    opts = function()
      local builtin = require("statuscol.builtin")
      return {
        segments = {
          { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
          { text = { "%s" },             click = "v:lua.ScSa" },
          { text = { builtin.lnumfunc, " " }, click = "v:lua.ScLa" },
        },
      }
    end,
  },
  -- ── Lualine ──────────────────────────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        disabled_filetypes = {
          statusline = { "toggleterm", "snacks_terminal", "snacks_picker_list" },
        },
      },
    },
  },
  -- ── Treesitter context ───────────────────────────────────────────────
  { "nvim-treesitter/nvim-treesitter-context", opts = {} },
  -- ── Diffview ─────────────────────────────────────────────────────────
  {
    "sindrets/diffview.nvim",
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>",             desc = "diff view" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>",    desc = "file history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>",      desc = "repo history" },
      { "<leader>gx", "<cmd>DiffviewClose<cr>",            desc = "close diff" },
    },
  },
  -- ── Flash ────────────────────────────────────────────────────────────
  {
    "folke/flash.nvim",
    opts = {},
    keys = {
      { "s", function() require("flash").jump() end, desc = "Flash jump" },
    },
  },
  -- ── Trouble ──────────────────────────────────────────────────────────
  {
    "folke/trouble.nvim",
    opts = {},
    keys = {
      { "<leader>dd", "<cmd>Trouble diagnostics toggle<cr>",    desc = "diagnostics" },
      { "<leader>dr", "<cmd>Trouble lsp_references toggle<cr>", desc = "references" },
    },
  },
  -- ── Comments ─────────────────────────────────────────────────────────
  {
    "folke/ts-comments.nvim",
    opts = {},
    keys = {
      { "<C-/>", "gcc", desc = "Toggle comment", remap = true },
      { "<C-/>", "gc",  desc = "Toggle comment", mode = "v", remap = true },
    },
  },
  -- ── Surround ─────────────────────────────────────────────────────────
  { "kylechui/nvim-surround", opts = {} },
  -- ── Folding ──────────────────────────────────────────────────────────
  {
    "kevinhwang91/nvim-ufo",
    dependencies = "kevinhwang91/promise-async",
    opts = {
      provider_selector = function()
        return { "treesitter", "indent" }
      end,
    },
    keys = {
      { "zR", function() require("ufo").openAllFolds() end,  desc = "Open all folds" },
      { "zM", function() require("ufo").closeAllFolds() end, desc = "Close all folds" },
    },
  },
  -- ── Autopairs ────────────────────────────────────────────────────────
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
  -- ── Formatting ───────────────────────────────────────────────────────
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        python     = { "ruff_format" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        -- dart falls back to LSP (dartls via flutter-tools handles dart format)
      },
      format_on_save = {
        timeout_ms = 2000,
        lsp_format = "fallback",  -- use LSP if no conform formatter matched
      },
    },
  },
  -- ── Completion ───────────────────────────────────────────────────────
  {
    "saghen/blink.cmp",
    version = "*",
    dependencies = { "L3MON4D3/LuaSnip" },
    opts = {
      keymap = { preset = "super-tab" },
      snippets = { preset = "luasnip" },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
    },
  },
  -- ─────────────────────────────────────────────────────────────────────
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      picker = {
        layout = { preset = "sidebar" },
      },
      scroll = { enabled = true },
      gitbrowse = {},
      lazygit = {},
      notifier = { enabled = true },
      input = { enabled = true },
      terminal = {
        win = { wo = { winbar = "" } },
      },
      dashboard = {
        enabled = true,
        sections = {
          { section = "header" },
          { section = "keys",   gap = 1, padding = 1 },
          { section = "recent_files", limit = 10, padding = 1 },
          { section = "startup" },
        },
      },
      indent = { enabled = true },
    },
    keys = {
      { "<leader>?", function()
          local items = {}
          for _, mode in ipairs({ "n", "v" }) do
            for _, km in ipairs(vim.api.nvim_get_keymap(mode)) do
              if km.lhs:find("^ ") and km.desc and km.desc ~= "" then
                table.insert(items, {
                  text = km.desc .. "  " .. vim.fn.keytrans(km.lhs),
                  lhs  = km.lhs,
                  desc = km.desc,
                })
              end
            end
          end
          Snacks.picker({
            title = " keymaps ",
            items = items,
            format = function(item) return { { item.desc, "Normal" } } end,
            confirm = function(picker, item)
              picker:close()
              if item then vim.api.nvim_input(item.lhs) end
            end,
          })
        end, desc = "keymaps" },
      { "<leader><space>", function() Snacks.picker.smart() end,    desc = "files" },
      { "<leader>/",       function() Snacks.picker.grep() end,     desc = "grep" },
      { "<leader>e",       function() Snacks.picker.explorer() end, desc = "explorer" },
      { "<leader>b",       function() Snacks.picker.buffers() end,  desc = "buffers" },
      { "<leader>gg",      function() Snacks.lazygit() end,         desc = "lazygit" },
      { "<leader>go",      function() Snacks.gitbrowse() end,       desc = "open on github" },
      { "<leader>gs",      function() Snacks.picker.git_diff() end, desc = "staged diff" },
      { "<leader>ls",      function() Snacks.picker.lsp_symbols() end, desc = "symbols" },
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

-- Float styling (hover docs, diagnostics popups)
vim.o.winborder = "rounded"  -- nvim 0.11+: default border for all floating windows
local function set_float_highlights()
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#44475a" })              -- dracula current-line, clearly distinct
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#ff79c6", bg = "#44475a" })  -- dracula pink border
end
set_float_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_float_highlights })

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

-- Folding (nvim-ufo)
o.foldlevel      = 99   -- open all folds by default
o.foldlevelstart = 99
o.foldenable     = true
o.foldcolumn     = "1"

-- Diagnostics
vim.diagnostic.config({
  virtual_text = true,                        -- error indicators on all lines
  virtual_lines = { current_line = true },    -- full message inline on current line
  signs = true,
})

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

-- Close floats (hover docs, etc.) then clear search highlight
vim.keymap.set("n", "<Esc>", function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      vim.api.nvim_win_close(win, false)
      return
    end
  end
  vim.cmd("nohlsearch")
end, { silent = true, desc = "Close float / clear search" })

-- Terminal mode: exit and window navigation (global, not plugin-dependent)
vim.keymap.set("t", "<Esc>",   "<C-\\><C-n>",       { desc = "Exit terminal mode" })
vim.keymap.set("t", "<C-h>",   "<Cmd>wincmd h<CR>", { desc = "Move to left window" })
vim.keymap.set("t", "<C-j>",   "<Cmd>wincmd j<CR>", { desc = "Move to lower window" })
vim.keymap.set("t", "<C-k>",   "<Cmd>wincmd k<CR>", { desc = "Move to upper window" })
vim.keymap.set("t", "<C-l>",   "<Cmd>wincmd l<CR>", { desc = "Move to right window" })

-- Edge-aware window navigation: move normally, or open a panel at the edge
local function edge_nav(dir, edge_fn)
  local cur = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. dir)
  if vim.api.nvim_get_current_win() == cur then
    edge_fn()
  end
end

map("n", "<C-h>", function() edge_nav("h", function() Snacks.picker.explorer() end) end, "Move left / open explorer")
map("n", "<C-j>", function() edge_nav("j", function() vim.cmd("ToggleTerm") end) end,    "Move down / open terminal")
map("n", "<C-k>", "<C-w>k", "Move to upper window")
map("n", "<C-l>", function() edge_nav("l", function() vim.cmd("ClaudeCode") end) end,    "Move right / open claude")

-- ============================================================
-- Neovide
-- ============================================================

if vim.g.neovide then
  vim.o.guifont = "JetBrainsMono Nerd Font:h14"

  vim.g.neovide_cursor_animation_length    = 0.08
  vim.g.neovide_cursor_trail_size          = 0.4
  vim.g.neovide_scroll_animation_length    = 0.2
  vim.g.neovide_floating_shadow            = false

  -- Cmd+V paste in insert/command mode
  vim.keymap.set({ "i", "c" }, "<D-v>", "<C-r>+", { desc = "Paste" })
  -- Cmd+V paste in normal/visual mode
  vim.keymap.set({ "n", "v" }, "<D-v>", '"+p',    { desc = "Paste" })

  -- Cmd+S save
  vim.keymap.set({ "n", "i", "v" }, "<D-s>", "<cmd>w<cr>", { desc = "Save" })

  -- Multi-terminal: Cmd+T new, Cmd+[ / Cmd+] cycle, Cmd+D vertical split
  local function max_term_id()
    local max = 0
    for _, t in ipairs(require("toggleterm.terminal").get_all(true)) do
      if t.id > max then max = t.id end
    end
    return max
  end

  local function refresh_winbar()
    vim.schedule(function()
      if _G.ToggleTermRefreshWinbar then _G.ToggleTermRefreshWinbar() end
    end)
  end

  vim.keymap.set({ "n", "t" }, "<D-t>", function()
    local new_id = max_term_id() + 1
    if vim.b.toggle_number then vim.cmd("hide") end
    vim.cmd(new_id .. "ToggleTerm")
    refresh_winbar()
    vim.schedule(function() vim.cmd("startinsert") end)
  end, { desc = "New terminal" })

  vim.keymap.set("t", "<D-[>", function()
    local terms = require("toggleterm.terminal").get_all(true)
    if #terms < 2 then return end
    local cur = vim.b.toggle_number
    for i, t in ipairs(terms) do
      if t.id == cur then
        vim.cmd("hide")
        terms[((i - 2) % #terms) + 1]:open()
        refresh_winbar()
        vim.schedule(function() vim.cmd("startinsert") end)
        return
      end
    end
  end, { desc = "Prev terminal" })

  vim.keymap.set("t", "<D-]>", function()
    local terms = require("toggleterm.terminal").get_all(true)
    if #terms < 2 then return end
    local cur = vim.b.toggle_number
    for i, t in ipairs(terms) do
      if t.id == cur then
        vim.cmd("hide")
        terms[(i % #terms) + 1]:open()
        refresh_winbar()
        vim.schedule(function() vim.cmd("startinsert") end)
        return
      end
    end
  end, { desc = "Next terminal" })

  vim.keymap.set({ "n", "t" }, "<D-d>", function()
    vim.cmd((max_term_id() + 1) .. "ToggleTerm direction=vertical size=80")
  end, { desc = "Split terminal" })

  -- Cmd+= / Cmd+- font scaling
  vim.keymap.set("n", "<D-=>", function()
    vim.g.neovide_scale_factor = (vim.g.neovide_scale_factor or 1) + 0.1
  end, { desc = "Increase font size" })
  vim.keymap.set("n", "<D-->", function()
    vim.g.neovide_scale_factor = math.max(0.5, (vim.g.neovide_scale_factor or 1) - 0.1)
  end, { desc = "Decrease font size" })
end

-- Markdown settings
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

-- Stay in visual mode after indent
map("v", "<", "<gv", "Indent left")
map("v", ">", ">gv", "Indent right")
