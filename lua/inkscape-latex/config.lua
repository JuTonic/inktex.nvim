local utils = require("inkscape-latex.utils")
local M = {}

--- @class InkscapeLatexOptionsInput
--- @field start_at_buffer_attach? boolean
--- @field start_at_svg_open? boolean
--- @field figures_dir? string
--- @field create_figures_dir? boolean
--- @field inkscape_path? string
--- @field watcher_path? string
--- @field template_path? string
---
--- @class InkscapeLatexOptions : InkscapeLatexOptionsInput
--- @field start_at_buffer_attach boolean
--- @field start_at_svg_open boolean
--- @field figures_dir string
--- @field create_figures_dir boolean
--- @field inkscape_path string
--- @field watcher_path string
--- @field template_path string

local PLUGIN_ROOT = utils.get_plugin_root()
local DATA_DIR = utils.get_plugin_data_dir()
local WATCHER_NAME = "inkscape-texd"
local WATCHER_PATH = vim.fs.joinpath(PLUGIN_ROOT, "bin", WATCHER_NAME)
local TEMPLATE_DIR = DATA_DIR
local TEMPLATE_PATH = vim.fs.joinpath(TEMPLATE_DIR, "template.svg")
local INKSCAPE_BIN = "inkscape"

---@param path string
local function verify_watcher_path(path)
    if vim.fn.filereadable(path) == 0 then
        vim.notify("Failed to find '" .. WATCHER_NAME .. "' binary: " .. WATCHER_PATH, vim.log.levels.ERROR)
        return
    end
    if vim.fn.executable(path) == 0 then
        vim.notify(WATCHER_PATH .. " is not executable", vim.log.levels.ERROR)
        return
    end

    return path
end

---@param path string
local function verify_inkscape_path(path)
    path = vim.fn.exepath(path)

    if path == "" then
        vim.notify("Inkscape not found in $PATH or not executable.", vim.log.levels.ERROR)
        return
    end

    return path
end

---@param inkscape string
local function ensure_template_existence(inkscape)
    if vim.fn.filereadable(TEMPLATE_PATH) == 0 then
        local code = vim.fn.mkdir(TEMPLATE_DIR, "p")
        if code == 0 then
            vim.notify("Failed to create template directory: " .. TEMPLATE_DIR, vim.log.levels.ERROR)
            return
        end

        local output = vim.system({ inkscape, "--export-filename", TEMPLATE_PATH }):wait()
        if output.code ~= 0 then
            vim.notify("Failed to create template file: " .. TEMPLATE_PATH, vim.log.levels.ERROR)
            return
        end
    end
    return TEMPLATE_PATH
end

---@param path string?
---@param inkscape string
local function verify_template(path, inkscape)
    if not path then
        return ensure_template_existence(inkscape)
    end

    if vim.fn.filereadable(path) == 0 then
        vim.notify(
            "Provided template (" ..
            path .. ") does not exist or is not readable. \nFalling back to default template",
            vim.log.levels
            .ERROR)
        return ensure_template_existence(inkscape)
    end

    if utils.get_filetype_from_path(path) ~= "svg" then
        vim.notify("Using non svg file (" .. path .. ") as a template?", vim.log.levels.WARN)
    end

    return path
end

--- @type InkscapeLatexOptions
M.opts = {
    start_at_buffer_attach = true,
    start_at_svg_open = true,
    figures_dir = "figures",
    create_figures_dir = true,
    inkscape_path = "",
    watcher_path = "",
    template_path = "",
}

--- @param opts? InkscapeLatexOptionsInput
--- @return boolean
function M.setup(opts)
    opts = opts or {}

    print(opts.start_at_buffer_attach)

    local watcher_path = verify_watcher_path(opts.watcher_path or WATCHER_PATH)
    if not watcher_path then return false end
    M.opts.watcher_path = watcher_path

    local inkscape_path = verify_inkscape_path(opts.inkscape_path or INKSCAPE_BIN)
    if not inkscape_path then return false end
    M.opts.inkscape_path = inkscape_path

    local template_path = verify_template(opts.template_path, inkscape_path)
    if not template_path then return false end
    M.opts.template_path = template_path

    M.opts = vim.tbl_deep_extend(
        "force",
        M.opts,
        opts
    )

    utils.opts = M.opts

    return true
end

return M
