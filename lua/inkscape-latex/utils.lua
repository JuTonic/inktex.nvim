local M = {}

---@param bufrn integer
function M.get_filetype(bufrn)
    return vim.filetype.match({ buf = bufrn })
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
    return plugin_data_dir
end

---@param bufnr integer
function M.get_buffer_name(bufnr)
    return vim.api.nvim_buf_get_name(bufnr)
end

return M
