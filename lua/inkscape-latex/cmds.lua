local opts = require("inkscape-latex.config").opts
local watcher = require("inkscape-latex.watcher")
local M = {}

local cmd = (opts.inkscape_bin or "inkscape")

---@param path string
function M.open_figure(path)
    print(path)
    vim.fn.jobstart({ cmd, path }, { detach = true })
end

function M.setup()
    vim.api.nvim_create_user_command(
        "InsertFigure",
        function()
            local name = vim.fn.input("Enter a file name: ")
            local bufnr = vim.api.nvim_get_current_buf()
            local figures_dir = watcher._get_figures_dir(bufnr)
            local path = vim.fs.joinpath(figures_dir, name)
            M.insert_figure(path)
        end,
        {}
    )
end

return M
