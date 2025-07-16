local M = {}

---@param bufrn integer
function M.get_buffer_filetype(bufrn)
    return vim.filetype.match({ buf = bufrn })
end

---@param path string
function M.get_filetype_from_path(path)
    return vim.filetype.match({ filename = path })
end

-- https://neovim.discourse.group/t/get-path-to-plugin-directory/2658
---@return string
function M.get_plugin_root()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:sub(2)
    return vim.fn.fnamemodify(script_path, ":h:h:h")
end

local PLUGIN_NAME = "inkscape-texd"

M._data_dir = nil
---@return string
function M.get_plugin_data_dir()
    if M._data_dir then return M._data_dir end

    local plugin_data_dir = vim.fn.stdpath("data")
    vim.fn.mkdir(plugin_data_dir, "p")
    return vim.fs.joinpath(plugin_data_dir, PLUGIN_NAME)
end

---@param bufnr integer
function M.get_buffer_name(bufnr)
    return vim.api.nvim_buf_get_name(bufnr)
end

---@param bufnr integer
---@param opts InkscapeLatexOptionsInput
function M.get_figures_dir(bufnr, opts)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
        vim.notify("Buffer " .. bufnr .. " has no name", vim.log.levels.WARN)
        return
    end
    local bufdir = vim.fn.fnamemodify(bufname, ":p:h")

    local figures_dir_abs = vim.fs.joinpath(bufdir, opts.figures_dir)

    if vim.fn.isdirectory(figures_dir_abs) ~= 1 then
        vim.notify("Figures directory does not exist: " .. opts.figures_dir, vim.log.levels.ERROR)
        return nil
    end

    return figures_dir_abs
end

return M
