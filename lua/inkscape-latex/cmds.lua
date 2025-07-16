local opts = require("inkscape-latex.config").opts
local watcher = require("inkscape-latex.watcher")
local utils = require("inkscape-latex.utils")
local M = {}

---@param path string
---@param bufnr integer
function M.open_svg_in_inkscape(path, bufnr)
    if opts.start_at_svg_open then
        watcher.ensure_running(bufnr)
    end
    vim.system(
        { opts.inkscape_path, path },
        { text = true },
        function(output)
            if output.code ~= 0 then
                local basename = vim.fs.basename(opts.inkscape_path)
                vim.schedule(function()
                    vim.notify("Failed to run " .. basename .. ": " .. output.stderr, vim.log.levels.ERROR)
                end)
            end
        end
    )
end

---@param path string
function M.copy_svg_template(path)
    if vim.fn.exists(path) == 1 then
        vim.notify("File already exists: " .. path, vim.log.levels.INFO)
        return false
    end

    local template = io.open(opts.template_path, "r")
    if not template then
        vim.notify("Failed to read template file: " .. opts.template_path, vim.log.levels.ERROR)
        return false
    end
    local content = template:read("*a")
    template:close()

    local copy_to = io.open(path, "w")
    if not copy_to then
        vim.notify("Failed to write to: " .. path, vim.log.levels.ERROR)
        return false
    end

    copy_to:write(content)
    copy_to:close()

    return true
end

---@param name string
---@param bufnr integer?
local function create_and_open_in_inkscape(name, bufnr)
    if bufnr then
        if not vim.api.nvim_buf_is_valid(bufnr) then
            vim.notify("Buffer with id " .. bufnr .. "does not exist", vim.log.levels.ERROR)
            return false
        end
    else
        bufnr = vim.api.nvim_get_current_buf()
    end

    local figures_dir = utils.get_figures_dir(bufnr, opts)
    if utils.get_filetype_from_path(name) ~= "svg" then
        name = name .. ".svg"
    end
    local path = vim.fs.joinpath(figures_dir, name)

    if vim.fn.exists(path) == 0 then
        local success = M.copy_svg_template(path)
        if not success then
            return false
        end
    end

    M.open_svg_in_inkscape(path, bufnr)
end

function M.setup()
    vim.api.nvim_create_user_command(
        "InsertFigure",
        function(args)
            local name = args.args
            if name == "" then
                name = vim.fn.input("Enter a file name: ")
                vim.cmd("redraw")
            end

            create_and_open_in_inkscape(name)
        end,
        { nargs = "?" }
    )
end

return M
