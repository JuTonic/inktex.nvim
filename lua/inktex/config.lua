local misc = require("neotil.misc")
local utils = require("inktex.utils")
local M = {}

M.var = {}
M.var.WATCHER_NAME = "inktex-watch"
M.var.PLUGIN_NAME = "inktex"
M.var.PLUGIN_ROOT =
    misc.get_plugin_root_path(debug.getinfo(1, "S"), M.var.PLUGIN_NAME)
M.var.DATA_DIR = misc.get_data_dir()

-- ╭─────────────────────────────────────────────────────────╮
-- │                        CONSTANTS                        │
-- ╰─────────────────────────────────────────────────────────╯

local INKSCAPE_EXPORT_FILENAME_ARG = "--export-filename"

---@type InktexOptions
local DEFAULTS_OPTS = {
    start_at_buffer_attach = true,
    start_at_svg_open = true,
    create_figures_dir = true,
    figures_dir = "figures",
    inkscape_path = "inkscape",
    watcher_path = vim.fs.joinpath(
        M.var.PLUGIN_ROOT,
        "bin",
        M.var.WATCHER_NAME
    ),
    template = vim.fs.joinpath(M.var.DATA_DIR, "template.svg"),
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
            "Failed to create template directory: " .. M.var.DATA_DIR,
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

---@type InktexOptions
---@diagnostic disable-next-line: missing-fields
M.opts = {}

--- Configure the plugin with given options.
--- @param opts? InktexOptionsInput
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
