local M = {}

local config = require("inkfig.config")
local core = require("inkfig.core")
local watcher = require("inkfig.watcher")

---@param opts InkscapeLatexOptionsInput?
function M.setup(opts)
    local success = config.setup(opts)
    if not success then
        return
    end

    -- print(config.opts.figures_dir)

    watcher.setup()

    if config.opts.start_at_buffer_attach then
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "tex",
            callback = function(arg)
                watcher.ensure_running_for_buf(
                    arg.buf,
                    config.opts.silent_watcher_start
                )
            end,
            desc = "starts inkfigd at entering .tex file",
        })
    end

    core.setup()
end

return M
---@class FigureContext
---@field start_row integer
---@field end_row integer
---@field path Path
---@field new fun(self: FigureContext): FigureContext?
---@field rename fun(self: FigureContext): boolean
---@field remove fun(self: FigureContext): boolean

-- ╭─────────────────────────────────────────────────────────╮
-- │ CONFIG                                                  │
-- ╰─────────────────────────────────────────────────────────╯

--- @class InkscapeLatexOptionsInput
--- @field start_at_buffer_attach? boolean
--- @field start_at_svg_open? boolean
--- @field figures_dir? string
--- @field create_figures_dir? boolean
--- @field inkscape_path? string
--- @field watcher_path? string
--- @field template? string
--- @field aux_prefix? string
--- @field recursively? boolean
--- @field regenerate? boolean
--- @field silent_watcher_start? boolean
--- @field auto_create_dir? boolean

--- @class InkscapeLatexOptions : InkscapeLatexOptionsInput
--- @field start_at_buffer_attach boolean
--- @field start_at_svg_open boolean
--- @field figures_dir string
--- @field create_figures_dir boolean
--- @field inkscape_path string
--- @field watcher_path string
--- @field template string
--- @field aux_prefix string
--- @field recursively boolean
--- @field regenerate boolean
--- @field silent_watcher_start boolean
--- @field auto_create_dir boolean

-- ╭─────────────────────────────────────────────────────────╮
-- │ UTILS                                                   │
-- ╰─────────────────────────────────────────────────────────╯
local M = {}

local PLUGIN_NAME = "inkfig"

-- ╭─────────────────────────────────────────────────────────╮
-- │ FILETYPE UTILITIES                                      │
-- ╰─────────────────────────────────────────────────────────╯

---Get filetype of a buffer by ID.
---@param bufrn integer buffer id
function M.resolve_buf_filetype(bufrn)
    return vim.filetype.match({ buf = bufrn })
end

---Get filetype from a file path.
---@param path string
function M.resolve_filetype_from_path(path)
    return vim.filetype.match({ filename = path })
end

-- ╭─────────────────────────────────────────────────────────╮
-- │ PLUGIN PATH UTILITIES                                   │
-- ╰─────────────────────────────────────────────────────────╯

-- https://neovim.discourse.group/t/get-path-to-plugin-directory/2658

--- Get the root path of the plugin.
---@return string
function M.get_plugin_root_path()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:sub(2)
    return vim.fn.fnamemodify(script_path, ":h:h:h")
end

--- Get the plugin's data directory.
local data_dir_cache = nil
---@return string
function M.get_plugin_data_dir()
    if data_dir_cache then
        return data_dir_cache
    end

    local base_dir = vim.fn.stdpath("data")
    vim.fn.mkdir(base_dir, "p")
    data_dir_cache = vim.fs.joinpath(base_dir, PLUGIN_NAME)

    return data_dir_cache
end

-- ╭─────────────────────────────────────────────────────────╮
-- │ BUFFERS UTILITIES                                       │
-- ╰─────────────────────────────────────────────────────────╯

---Get the full file name of a buffer.
---@param bufnr integer buffer id
function M.get_buf_path(bufnr)
    return vim.api.nvim_buf_get_name(bufnr)
end

---Get or create figures directory for a given buffer.
---@param bufnr integer? buffer id
function M.resolve_figures_dir_for_buffer(bufnr)
    if not bufnr then
        bufnr = vim.api.nvim_get_current_buf()
    end

    local cfg = require("inkfig.config")

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
        vim.notify("Buffer " .. bufnr .. " has no name", vim.log.levels.WARN)
        return
    end
    local bufdir = vim.fn.fnamemodify(bufname, ":p:h")

    local figures_dir_abs = vim.fs.joinpath(bufdir, cfg.opts.figures_dir)

    if cfg.opts.create_figures_dir then
        if vim.fn.mkdir(figures_dir_abs, "p") == 0 then
            vim.notify(
                "Failed to create figures directory: " .. figures_dir_abs,
                vim.log.levels.WARN
            )
            return
        end
    elseif vim.fn.isdirectory(figures_dir_abs) == 0 then
        vim.notify(
            "Figures directory does not exist: " .. cfg.opts.figures_dir,
            vim.log.levels.ERROR
        )
        return
    end

    return figures_dir_abs
end

---@param path string
---@param bufnr integer?
function M.add_figures_dir(path, bufnr)
    local figures_dir = M.resolve_figures_dir_for_buffer(bufnr)
    if not figures_dir then
        return path
    end
    return vim.fs.joinpath(figures_dir, path)
end

function M.match_text_in_brackets_under_cursor(bracket_pair)
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    return M.match_text_in_brackets(line, col, bracket_pair)
end

function M.get_word_under_cursor()
    return vim.fn.expand("<cword>")
end

return M
local utils = require("inkfig.utils")
local M = {}

-- ╭─────────────────────────────────────────────────────────╮
-- │                        CONSTANTS                        │
-- ╰─────────────────────────────────────────────────────────╯

local PLUGIN_ROOT = utils.get_plugin_root_path()
local DATA_DIR = utils.get_plugin_data_dir()
local WATCHER_NAME = "inkfigd"
local INKSCAPE_EXPORT_FILENAME_ARG = "--export-filename"

---@type InkscapeLatexOptions
local DEFAULTS_OPTS = {
    start_at_buffer_attach = true,
    start_at_svg_open = true,
    create_figures_dir = true,
    figures_dir = "figures",
    inkscape_path = "inkscape",
    watcher_path = vim.fs.joinpath(PLUGIN_ROOT, "bin", WATCHER_NAME),
    template = vim.fs.joinpath(DATA_DIR, "template.svg"),
    aux_prefix = ".",
    recursively = true,
    regenerate = true,
    silent_watcher_start = true,
    auto_create_dir = true,
}

-- ╭─────────────────────────────────────────────────────────╮
-- │                    UTILITY FUNCTIONS                    │
-- ╰─────────────────────────────────────────────────────────╯

---Verify that the watcher path is valid and executable.
---@param path string
local function resolve_valid_watcher_path(path)
    local abs_path = vim.fs.abspath(path)
    if vim.fn.filereadable(abs_path) == 0 then
        vim.notify(
            "Failed to find watcher binary: " .. DEFAULTS_OPTS.watcher_path,
            vim.log.levels.ERROR
        )
        return
    elseif vim.fn.executable(abs_path) == 0 then
        vim.notify(
            "Watcher binary is not executable: " .. DEFAULTS_OPTS.watcher_path,
            vim.log.levels.ERROR
        )
        return
    end

    return abs_path
end

--- Verify that Inkscape is available in $PATH or at given path.
---@param path string
local function verify_valid_inkscape_path(path)
    local resolved = vim.fn.exepath(path)

    if resolved == "" then
        vim.notify(
            "Inkscape is not found in $PATH or is not executable.",
            vim.log.levels.ERROR
        )
        return
    end

    return resolved
end

--- Ensure default template file exists; create it if necessary.
---@param inkscape string
local function create_default_template_if_needed(inkscape)
    if vim.fn.filereadable(DEFAULTS_OPTS.template) == 1 then
        return DEFAULTS_OPTS.template
    end

    if vim.fn.mkdir(vim.fs.dirname(DEFAULTS_OPTS.template), "p") == 0 then
        vim.notify(
            "Failed to create template directory: " .. DATA_DIR,
            vim.log.levels.ERROR
        )
        return
    end

    local output = vim.system({
        inkscape,
        INKSCAPE_EXPORT_FILENAME_ARG,
        DEFAULTS_OPTS.template,
    }):wait()

    if output.code ~= 0 then
        vim.notify(
            "Failed to create template file: " .. output.stderr,
            vim.log.levels.ERROR
        )
        return
    end

    return DEFAULTS_OPTS.template
end

---Validate the template path or fall back to default.
---@param path string?
---@param inkscape string
local function verify_template(path, inkscape)
    if not path or path == "" then
        return create_default_template_if_needed(inkscape)
    end

    local abs_path = vim.fs.abspath(path)
    if vim.fn.filereadable(abs_path) == 0 then
        vim.notify(
            "Provided template is not readable: "
                .. abs_path
                .. "\nUsing default template.",
            vim.log.levels.ERROR
        )
        return create_default_template_if_needed(inkscape)
    end

    if utils.resolve_filetype_from_path(abs_path) ~= "svg" then
        vim.notify(
            "Using non-SVG template: " .. abs_path .. "?",
            vim.log.levels.WARN
        )
    end

    return abs_path
end

-- ╭─────────────────────────────────────────────────────────╮
-- │                          SETUP                          │
-- ╰─────────────────────────────────────────────────────────╯

---@type InkscapeLatexOptions
---@diagnostic disable-next-line: missing-fields
M.opts = {}
---Configure the plugin with given options.
--- @param opts? InkscapeLatexOptionsInput
--- @return boolean
function M.setup(opts)
    opts = opts or {}

    local watcher_path = resolve_valid_watcher_path(
        opts.watcher_path or DEFAULTS_OPTS.watcher_path
    )
    if not watcher_path then
        return false
    end

    local inkscape_path = verify_valid_inkscape_path(
        opts.inkscape_path or DEFAULTS_OPTS.inkscape_path
    )
    if not inkscape_path then
        return false
    end

    local template = verify_template(opts.template, inkscape_path)
    if not template then
        return false
    end

    M.opts = vim.tbl_deep_extend("force", DEFAULTS_OPTS, opts)
    M.opts.watcher_path = watcher_path
    M.opts.inkscape_path = inkscape_path
    M.opts.template = template

    return true
end

return M
local cfg = require("inkfig.config")
local utils = require("inkfig.utils")

local M = {}

local WATCHER_NAME = "inkfigd"
local INKSCAPE_PATH_ARG = "--inkscape-path"
local AUX_PREFIX_ARG = "--aux-prefix"
local NOT_RECURSIVELY = "--not-recursively"
local DO_NOT_REGENERATE = "--do-not-regenerate"

---@type table<integer, integer> # key = bufnr, value = job_id
local active_jobs = {}

-- ╭─────────────────────────────────────────────────────────╮
-- │ INTERNALS                                               │
-- ╰─────────────────────────────────────────────────────────╯

---@param stderr table
local function on_watcher_stderr(_, stderr, _)
    if not stderr then
        return
    end
    for _, line in ipairs(stderr) do
        if line ~= "" then
            vim.notify("[watcher stderr] " .. line, vim.log.levels.WARN)
        end
    end
end

---@param bufnr integer
function M.is_active_for_buf(bufnr)
    return active_jobs[bufnr] ~= nil
end

---@param bufnr integer buffer id
---@param silent boolean?
function M.start_for_buf(bufnr, silent)
    local file_path = utils.get_buf_path(bufnr)

    if M.is_active_for_buf(bufnr) then
        vim.notify(
            "Watcher for " .. file_path .. " is already running",
            vim.log.levels.WARN
        )
        return nil
    end

    if utils.resolve_buf_filetype(bufnr) ~= "tex" then
        vim.notify(file_path .. " is not a .tex file", vim.log.levels.WARN)
        return nil
    end

    local opts = cfg.opts

    local watch_dir = utils.resolve_figures_dir_for_buffer(bufnr)
    if not watch_dir then
        return
    end

    local cmd = { opts.watcher_path, watch_dir }

    if opts.inkscape_path then
        vim.list_extend(cmd, { INKSCAPE_PATH_ARG, opts.inkscape_path })
    end

    if opts.aux_prefix ~= "" then
        vim.list_extend(cmd, { AUX_PREFIX_ARG, opts.aux_prefix })
    end

    if not opts.recursively then
        vim.list_extend(cmd, { NOT_RECURSIVELY })
    end

    if not opts.regenerate then
        vim.list_extend(cmd, { DO_NOT_REGENERATE })
    end

    local job_id = vim.fn.jobstart(cmd, {
        stdout_buffered = false,
        stderr_buffered = true,
        on_stderr = on_watcher_stderr,
        on_exit = function(_, code, _)
            vim.notify(
                WATCHER_NAME
                    .. " exited for "
                    .. file_path
                    .. " (exit code "
                    .. code
                    .. ")",
                vim.log.levels.INFO
            )
            active_jobs[bufnr] = nil
        end,
    })

    if job_id <= 0 then
        vim.notify(
            "Failed to start " .. WATCHER_NAME .. " for buffer " .. bufnr,
            vim.log.levels.ERROR
        )
        return
    end

    active_jobs[bufnr] = job_id

    vim.api.nvim_buf_attach(bufnr, false, {
        on_detach = function()
            M.stop_for_buf(bufnr)
        end,
    })

    if silent == false then
        vim.notify(
            "Started " .. WATCHER_NAME .. " for " .. file_path,
            vim.log.levels.INFO
        )
    end
end

---@param bufnr integer buffer id
---@param silent boolean
function M.ensure_running_for_buf(bufnr, silent)
    if not M.is_active_for_buf(bufnr) then
        M.start_for_buf(bufnr, silent)
    end
end

---@param bufnr integer buffer id
function M.stop_for_buf(bufnr)
    local file_path = utils.get_buf_path(bufnr)
    local job_id = active_jobs[bufnr]

    if not job_id then
        vim.notify(
            "No " .. WATCHER_NAME .. " is running for " .. file_path,
            vim.log.levels.INFO
        )
        return nil
    end

    vim.fn.jobstop(job_id)
    active_jobs[bufnr] = nil

    vim.notify(
        "Stopped " .. WATCHER_NAME .. " for buffer " .. file_path,
        vim.log.levels.INFO
    )
end

function M.setup()
    vim.api.nvim_create_user_command("InkscapeTexdStart", function()
        M.start_for_buf(vim.api.nvim_get_current_buf(), false)
    end, {})
    vim.api.nvim_create_user_command("InkscapeTexdStop", function()
        M.stop_for_buf(vim.api.nvim_get_current_buf())
    end, {})
end

return M
local Path = require("neotil.path")
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
        local dir = Path:new(full_path):dir()
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
