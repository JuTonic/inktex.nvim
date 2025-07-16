local utils = require("inkscape-latex.utils")

local M = {}

--- @class InkScapeLatexOptions
--- @field auto_start? boolean
--- @field figures_dir? string
--- @field inkscape_bin? string
--- @field watcher_bin? string
--- @field template? string

local PLUGIN_ROOT = utils.get_plugin_root()
local DATA_DIR = vim.fn.stdpath("data")

local WATCHER_NAME = "inkscape-texd"
local WATCHER_PATH = vim.fs.joinpath(PLUGIN_ROOT, "bin", WATCHER_NAME)
local function get_watcher_bin()
    if vim.fn.filereadable(WATCHER_PATH) == 0 then
        vim.notify("Failed to find '" .. WATCHER_NAME .. "' binary: " .. WATCHER_PATH, vim.log.levels.ERROR)
        return
    end
    if vim.fn.executable(WATCHER_PATH) == 0 then
        vim.notify(WATCHER_PATH .. " is not executable", vim.log.levels.ERROR)
        return
    end

    return WATCHER_PATH
end

local function get_inkscape_bin()
    local path = vim.fn.exepath("inkscape")

    if path == "" then
        vim.notify("Inkscape not found in $PATH.", vim.log.levels.ERROR)
        return
    end

    return path
end

-- local TEMPLATE_PATH = vim.fs.joinpath(vim)
-- local function get_template()
--     if vim.fn.filereadable() == 0 then
--         vim.notify("Failed to find '" .. WATCHER_NAME .. "' binary: " .. watcher_bin_full_path, vim.log.levels.ERROR)
--         return
--     end
-- end
--
local ink

--- @type InkScapeLatexOptions
M.opts = {
    auto_start = true,
    figures_dir = "figures",
    inkscape_bin = nil,
    watcher_bin = nil,
    template = nil,
}

--- @param opts? InkScapeLatexOptions
--- @return boolean
function M.setup(opts)
    if not opts or not opts.watcher_bin then
        M.opts.watcher_bin = get_watcher_bin()
        if not M.opts.watcher_bin then return false end
    end

    if not opts or not opts.inkscape_bin then
        M.opts.inkscape_bin = get_inkscape_bin()
        if not M.opts.inkscape_bin then return false end
    end

    M.opts = vim.tbl_deep_extend(
        "force",
        M.opts,
        opts or {}
    )

    return true
end

return M
