local cfg = require("inktex.config")
local utils = require("inktex.utils")

local M = {}

local watcher_args = {
    INKSCAPE_PATH = "--inkscape-path",
    AUX_PREFIX = "--aux-prefix",
    NOT_RECURSIVELY = "--not-recursively",
    DO_NOT_REGENERATE = "--do-not-regenerate",
}

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

    local watch_dir = utils.resolve_figures_dir_for_buffer(bufnr)
    if not watch_dir then
        return
    end

    local cmd = { cfg.opts.watcher_path, watch_dir }

    if cfg.opts.inkscape_path then
        vim.list_extend(
            cmd,
            { watcher_args.INKSCAPE_PATH, cfg.opts.inkscape_path }
        )
    end

    if cfg.opts.aux_prefix ~= "" then
        vim.list_extend(cmd, { watcher_args.AUX_PREFIX, cfg.opts.aux_prefix })
    end

    if not cfg.opts.recursively then
        vim.list_extend(cmd, { watcher_args.NOT_RECURSIVELY })
    end

    if not cfg.opts.regenerate then
        vim.list_extend(cmd, { watcher_args.DO_NOT_REGENERATE })
    end

    local job_id = vim.fn.jobstart(cmd, {
        stdout_buffered = false,
        stderr_buffered = true,
        on_stderr = on_watcher_stderr,
        -- on_exit = function(_, code, _)
        --     vim.notify(
        --         cfg.var.WATCHER_NAME
        --             .. " exited for "
        --             .. file_path
        --             .. " (exit code "
        --             .. code
        --             .. ")",
        --         vim.log.levels.INFO
        --     )
        --     active_jobs[bufnr] = nil
        -- end,
    })

    if job_id <= 0 then
        vim.notify(
            "Failed to start "
                .. cfg.var.WATCHER_NAME
                .. " for buffer "
                .. bufnr,
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
            "Started " .. cfg.var.WATCHER_NAME .. " for " .. file_path,
            vim.log.levels.INFO
        )
    end
end

---@param bufnr integer buffer id
---@param silent? boolean
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
            "No " .. cfg.var.WATCHER_NAME .. " is running for " .. file_path,
            vim.log.levels.INFO
        )
        return nil
    end

    vim.fn.jobstop(job_id)
    active_jobs[bufnr] = nil

    vim.notify(
        "Stopped " .. cfg.var.WATCHER_NAME .. " for buffer " .. file_path,
        vim.log.levels.INFO
    )
end

function M.setup()
    local plugin_name = cfg.var.PLUGIN_NAME
    local first_char = plugin_name:sub(1, 1)
    plugin_name = first_char:upper() .. first_char:sub(2)
    vim.api.nvim_create_user_command(plugin_name .. "WatcherStart", function()
        M.start_for_buf(vim.api.nvim_get_current_buf(), false)
    end, {})
    vim.api.nvim_create_user_command(plugin_name .. "WatcherStop", function()
        M.stop_for_buf(vim.api.nvim_get_current_buf())
    end, {})
end

return M
