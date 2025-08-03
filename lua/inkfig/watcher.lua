local cfg = require("inkfig.config")
local utils = require("inkfig.utils")

local M = {}

local WATCHER_NAME = "inkwatch"
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
