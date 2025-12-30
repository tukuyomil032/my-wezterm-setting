vim.g.node_host_prg = "/Users/kusoushou/Library/pnpm/neovim-node-host"
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_python3_provider = 0

local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'

  use 'nvim-tree/nvim-web-devicons'

  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate'
  }

  use {
    'nvim-telescope/telescope.nvim',
    requires = { {'nvim-lua/plenary.nvim'} }
  }

  use 'neovim/nvim-lspconfig'

  use 'mfussenegger/nvim-dap'

  use 'folke/which-key.nvim'

  if packer_bootstrap then
    require('packer').sync()
  end
end)


local status_ok, configs = pcall(require, "nvim-treesitter.configs")
if status_ok then
  configs.setup {
    ensure_installed = {"javascript", "typescript", "lua"},
    highlight = { enable = true },
  }
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

keymap("n", "<leader>f", ":Telescope find_files<CR>", opts)

keymap("n", "<leader>g", ":Telescope live_grep<CR>", opts)

keymap("n", "<leader>e", ":Lex 30<CR>", opts)

keymap("i", "jj", "<ESC>", opts)

