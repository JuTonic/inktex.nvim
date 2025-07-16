local opts = require("inkscape-latex.config").opts
local utils = require("inkscape-latex.utils")

local M = {}

local WATCHER_NAME = "inkscape-texd"

---@type table<integer, integer> # key = bufnr, value = job_id
local active_jobs = {}

---@param bufnr integer
function M._get_figures_dir(bufnr)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local bufdir = vim.fn.fnamemodify(bufname, ":p:h")
    local figures_dir = vim.fs.joinpath(bufdir, opts.figures_dir)

    if vim.fn.isdirectory(figures_dir) ~= 1 then
        vim.notify("Figures directory does not exist: " .. figures_dir, vim.log.levels.ERROR)
        return nil
    end

    return figures_dir
end

local function on_watcher_stderr(_, data, _)
    if not data then return end
    for _, line in ipairs(data) do
        if line ~= "" then
            vim.notify("[watcher stderr] " .. line, vim.log.levels.WARN)
        end
    end
end

---@param bufnr integer assumes tex extension
function M.start_for_buffer(bufnr)
    print(opts.watcher_bin)

    local name = utils.get_buffer_name(bufnr)

    if utils.get_filetype(bufnr) ~= "tex" then
        vim.notify(name .. " is not a .tex file", vim.log.levels.WARN)
        return nil
    end

    if active_jobs[bufnr] then
        vim.notify("Watcher for " .. name .. " is already running", vim.log.levels.WARN)
        return nil
    end

    local watch_dir = M._get_figures_dir(bufnr)
    if not watch_dir then return end

    local cmd = { opts.watcher_bin, watch_dir }

    if opts.inkscape_bin then
        table.insert(cmd, "--inkscape-bin")
        table.insert(cmd, opts.inkscape_bin)
    end

    local job_id = vim.fn.jobstart(cmd, {
        stdout_buffered = false,
        stderr_buffered = true,
        on_stderr = on_watcher_stderr,
        on_exit = function(_, code, _)
            vim.notify(WATCHER_NAME .. " exited for " .. name .. " (exit code " .. code .. ")",
                vim.log.levels.INFO)
            active_jobs[bufnr] = nil
        end
    })

    if job_id <= 0 then
        vim.notify("Failed to start " .. WATCHER_NAME .. " for buffer " .. bufnr, vim.log.levels.ERROR)
        return
    end

    active_jobs[bufnr] = job_id

    vim.api.nvim_buf_attach(bufnr, false, {
        on_detach = function()
            M.stop_for_buffer(bufnr)
        end,
    })

    vim.notify("Started " .. WATCHER_NAME .. " for " .. name, vim.log.levels.INFO)
end

function M.stop_for_buffer(bufnr)
    local name = utils.get_buffer_name(bufnr)
    local job_id = active_jobs[bufnr]
    if not job_id then
        vim.notify("No " .. WATCHER_NAME .. " is running for " .. name, vim.log.levels.INFO)
        return nil
    end
    vim.fn.jobstop(job_id)
    active_jobs[bufnr] = nil
    vim.notify("Stopped " .. WATCHER_NAME .. " for buffer " .. name, vim.log.levels.INFO)
end

function M.setup()
    vim.api.nvim_create_user_command(
        "InkscapeTexdStart",
        function()
            M.start_for_buffer(vim.api.nvim_get_current_buf())
        end,
        {}
    )
    vim.api.nvim_create_user_command(
        "InkscapeTexdStop",
        function()
            M.stop_for_buffer(vim.api.nvim_get_current_buf())
        end,
        {}
    )
end

return M
