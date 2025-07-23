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

---@class VisualSelection
---@field _bufnr integer
---@field _start_row integer
---@field _start_col integer
---@field _end_row integer
---@field _end_col integer

---@class VisualSelection
M.VisualSelection = {}
M.VisualSelection.__index = M.VisualSelection

function M.VisualSelection:new()
    local obj = setmetatable({}, self)

    local bufnr = vim.api.nvim_get_current_buf()
    obj._bufnr = bufnr

    local s_start = vim.fn.getpos("'<")
    local s_end = vim.fn.getpos("'>")

    obj._start_row = s_start[2]
    obj._start_col = s_start[3]
    obj._end_row = s_end[2]
    obj._end_col = s_end[3]

    return obj
end

function M.VisualSelection:get_text()
    local lines = vim.api.nvim_buf_get_lines(
        self._bufnr,
        self._start_row - 1,
        self._end_row,
        false
    )

    if #lines == 0 then
        return nil
    end

    if #lines == 1 then
        lines[1] = lines[1]:sub(self._start_col, self._end_col)
    else
        -- Multi-line selection
        lines[1] = lines[1]:sub(self._start_col)
        lines[#lines] = lines[#lines]:sub(1, self._end_col)
    end

    return table.concat(lines, "\n")
end

---@param new_text string
function M.VisualSelection:replace_with_text(new_text)
    local first_line = vim.api.nvim_buf_get_lines(
        self._bufnr,
        self._start_row - 1,
        self._start_row,
        false
    )[1]
    local last_line = vim.api.nvim_buf_get_lines(
        self._bufnr,
        self._end_row - 1,
        self._end_row,
        false
    )[1]
    local first_line_before_selection = first_line:sub(1, self._start_col - 1)
    local last_line_after_selection = last_line:sub(self._end_col + 1)

    local replacement = vim.split(
        first_line_before_selection .. new_text .. last_line_after_selection,
        "\n",
        { plain = true }
    )

    vim.api.nvim_buf_set_lines(
        self._bufnr,
        self._start_row - 1,
        self._end_row,
        false,
        replacement
    )
end

function M.get_visual_selection()
    return M.VisualSelection:new()
end

M.brackets = {
    CURLY = { opening = "{", closing = "}" },
    SQUARE = { opening = "[", closing = "]" },
    ROUND = { opening = "(", closing = ")" },
}

---@param line string
---@param col integer
---@param bracket_pair BracketPair
function M.match_text_in_brackets(line, col, bracket_pair)
    local opening, closing = bracket_pair.opening, bracket_pair.closing
    local depth = 1

    local end_pos
    for i = col, #line do
        local char = line:sub(i, i)
        if char == opening then
            depth = depth + 1
        elseif char == closing then
            depth = depth - 1
        end
        if depth == 0 then
            end_pos = i - 1
            break
        end
    end
    if not end_pos then
        return
    end

    depth = -1
    local start_pos
    for i = col, 1, -1 do
        local char = line:sub(i, i)
        if char == opening then
            depth = depth + 1
        elseif char == closing then
            depth = depth - 1
        end
        if depth == 0 then
            start_pos = i + 1
            break
        end
    end
    if not start_pos then
        return
    end

    return line:sub(start_pos, end_pos)
end

function M.match_text_in_brackets_under_cursor(bracket_pair)
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    return M.match_text_in_brackets(line, col, bracket_pair)
end

function M.get_word_under_cursor()
    return vim.fn.expand("<cword>")
end

-- ╭─────────────────────────────────────────────────────────╮
-- │ TEX                                                     │
-- ╰─────────────────────────────────────────────────────────╯

M.tex = {}

M.tex.envs = {
    FIGURE = "figure",
}

---@param name string enviroment name
function M.tex.in_env(name)
    local ok, is_inside = pcall(vim.fn["vimtex#env#is_inside"], name)

    if not ok then
        vim.notify("vimtex is not installed", vim.log.levels.WARN)
        return
    end

    return (is_inside[1] > 0 and is_inside[2] > 0)
end

---@return boolean
function M.tex.in_mathzone()
    local ok, is_inside = pcall(vim.fn["vimtex#syntax#in_mathzone"])

    if not ok then
        vim.notify("vimtex is not installed", vim.log.levels.WARN)
        return false
    end

    return is_inside == 1
end

---@param name string
---@param lines string[]
---@param cursor_row integer
---@param target_depth integer? default = 1
---@return EnviromentMatch?
function M.tex.match_env(name, lines, cursor_row, target_depth)
    target_depth = target_depth or 1
    local match_begin = "\\begin%s*{%s*" .. name .. "%s*}%s*.*$"
    local match_end = "\\end%s*{%s*" .. name .. "%s*}%s*.*$"

    local depth = -target_depth

    local start_line

    local cursor_line = lines[cursor_row]
    if cursor_line:match(match_begin) then
        depth = depth - 1
    end

    for i = cursor_row, 1, -1 do
        local line = lines[i]
        if line:match(match_begin) then
            depth = depth + 1
        elseif line:match(match_end) then
            depth = depth - 1
        end
        if depth == 0 then
            start_line = i
            break
        end
    end
    if not start_line then
        return
    end

    depth = target_depth
    if cursor_line:match(match_end) then
        depth = depth + 1
    end

    local end_line
    for i = cursor_row, #lines do
        local line = lines[i]
        if line:match(match_begin) then
            depth = depth + 1
        elseif line:match(match_end) then
            depth = depth - 1
        end
        if depth == 0 then
            end_line = i
            break
        end
    end
    if not end_line then
        return
    end

    ---@type string[]
    local content = {}
    for i = start_line + 1, end_line - 1 do
        table.insert(content, lines[i])
    end
    return {
        name = name,
        content = content,
        start_line = start_line,
        end_line = end_line,
    }
end

---@class Path
M.Path = {}
M.Path.__index = M.Path

---@param path string
---@return Path
function M.Path:new(path)
    local obj = setmetatable({}, self)

    obj.path = path

    obj._last_slash_index = 0
    for i = #path, 1, -1 do
        if path:sub(i, i) == "/" then
            obj._last_slash_index = i
            break
        end
    end

    obj._last_dot_index = #path + 1
    for i = #path, obj._last_slash_index + 2, -1 do
        if path:sub(i, i) == "." then
            obj._last_dot_index = i
            break
        end
    end

    return obj
end

function M.Path:dir()
    if self._last_slash_index == 0 then
        return nil
    elseif self._last_slash_index == 1 then
        return "/"
    end
    return self.path:sub(1, self._last_slash_index - 1)
end

function M.Path:file()
    local file = self.path:sub(self._last_slash_index + 1)
    if file ~= "" then
        return file
    end
    return nil
end

function M.Path:stem()
    local stem =
        self.path:sub(self._last_slash_index + 1, self._last_dot_index - 1)
    if stem ~= "" then
        return stem
    end
    return nil
end

function M.Path:ext()
    local ext = self.path:sub(self._last_dot_index + 1)
    if ext ~= "" then
        return ext
    end
    return nil
end

return M
