local M = {}

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
    local cfg = require("inktex.config")

    if not bufnr then
        bufnr = vim.api.nvim_get_current_buf()
    end

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

return M
