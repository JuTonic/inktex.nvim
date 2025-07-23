local cfg = require("inkfig.config")
local utils = require("inkfig.utils")
local watcher = require("inkfig.watcher")

local M = {}

-- ╭─────────────────────────────────────────────────────────╮
-- │ CORE FUNCTIONALITY                                      │
-- ╰─────────────────────────────────────────────────────────╯

---Launch Inkscape with the given file and optionally start the watcher.
---@param path string
---@param bufnr integer?
function M.open_in_inkscape(path, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if cfg.opts.start_at_svg_open then
        watcher.ensure_running_for_buf(bufnr)
    end

    vim.system(
        { cfg.opts.inkscape_path, path },
        { text = true },
        function(output)
            if output.code ~= 0 then
                local bin_name = vim.fs.basename(opts.inkscape_path)
                vim.schedule(function()
                    vim.notify(
                        "Failed to run " .. bin_name .. ": " .. output.stderr,
                        vim.log.levels.ERROR
                    )
                end)
            end
        end
    )
end

---Create an SVG file from the configured template.
---@param path string where to copy
local function copy_svg_from_template(path)
    local opts = cfg.opts
    if vim.fn.filereadable(path) == 1 then
        vim.notify("File already exists: " .. path, vim.log.levels.INFO)
        return false
    end

    local template = io.open(opts.template, "r")
    if not template then
        vim.notify(
            "Failed to read template file: " .. opts.template,
            vim.log.levels.ERROR
        )
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

---Create a new SVG (if needed) and open it in Inkscape.
---@param filename string
---@param bufnr integer?
function M.create_and_open_in_inkscape(filename, bufnr)
    if bufnr then
        if not vim.api.nvim_buf_is_valid(bufnr) then
            vim.notify(
                "Buffer with id " .. bufnr .. "does not exist",
                vim.log.levels.ERROR
            )
            return false
        end
    else
        bufnr = vim.api.nvim_get_current_buf()
    end

    if utils.resolve_filetype_from_path(filename) ~= "svg" then
        filename = filename .. ".svg"
    end

    local full_path = utils.add_figures_dir(filename)

    if cfg.opts.auto_create_dir then
        local dir = utils.Path:new(full_path):dir()
        if dir then
            vim.fn.mkdir(dir, "p")
        end
    end

    if vim.fn.filereadable(full_path) == 0 then
        local success = copy_svg_from_template(full_path)
        if not success then
            return false
        end
    end

    M.open_in_inkscape(full_path, bufnr)
end

function M.setup()
    vim.api.nvim_create_user_command("InsertFigure", function(args)
        local filename = args.args
        if filename == "" then
            filename = vim.fn.input("Enter a file name: ")
            vim.cmd("redraw")
        end

        M.create_and_open_in_inkscape(filename)
    end, { nargs = "?" })

    vim.api.nvim_create_user_command("OpenFigure", function(args)
        local mode = vim.fn.mode()

        local match

        if mode == "v" or mode == "V" then
            print("test")
            match = utils.get_visually_selected_text()
        else
            match = utils.match_text_in_brackets_under_cursor(
                utils.brackets.CURLY
            ) or utils.get_word_under_cursor()
        end

        print(match)
    end, { range = true })

    -- Use a Lua wrapper to preserve visual mode
    vim.keymap.set({ "n" }, "gO", "<Cmd>OpenFigure<CR>")
    vim.keymap.set({ "v" }, "gO", ":OpenFigure<CR>")
end

return M
