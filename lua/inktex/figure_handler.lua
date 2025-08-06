local cfg = require("inktex.config")
local core = require("inktex.core")
local path = require("neotil.path")
local utils = require("inktex.utils")

local M = {}

---@class FigureHandler
local FigureHandler = {}
FigureHandler.__index = FigureHandler

function FigureHandler:new()
    local data = self._new and self._new()
    if not data then
        return
    end
    return setmetatable({
        path = path:new(data.path),
        start_row = data.start_row,
        end_row = data.end_row,
    }, self)
end

FigureHandler._new = nil
FigureHandler._remove = nil
FigureHandler._rename = nil

function FigureHandler:remove()
    return self._remove and self._remove(self)
end

---@param new_path Path
function FigureHandler:rename(new_path)
    return self._rename and self._rename(self, new_path)
end

---@param creator fun(): { start_row: integer, end_row: integer, path: string } | nil
local function register_commands(name_prefix, creator)
    ---@param name string
    ---@param callback fun(handler: FigureHandler)
    local function define(name, callback)
        vim.api.nvim_create_user_command(name, function()
            local data = creator()
            if not data then
                return
            end
            local handler = FigureHandler:new(data)
            if not handler then
                vim.notify("Not in figure environment", vim.log.levels.INFO)
                return
            end
            callback(handler)
            vim.cmd("w")
        end, {})
    end

    define(name_prefix .. "Open", function(handler)
        -- vim.notify(handler.path.path, vim.log.levels.ERROR)
        core.open_in_inkscape(handler.path.path)
    end)

    define(name_prefix .. "Delete", function(handler)
        if handler:remove() then
            vim.fs.rm(handler.path.path)
        end
    end)

    define(name_prefix .. "Rename", function(handler)
        local input = vim.fn.input("Enter new path: ")
        vim.cmd("redraw!")
        if input == "" then
            return
        end

        local new_path = path:new(input)
        if handler:rename(new_path) then
            local dir = new_path:dir()
            if dir then
                vim.fn.mkdir(utils.add_figures_dir(dir), "p")
            end
            vim.fn.rename(
                handler.path.path,
                utils.add_figures_dir(new_path.path .. ".svg")
            )
        end
    end)
end

---@class FigureHandlerOptions
---@field new fun(): { start_row: integer, end_row: integer, path: string } | nil
---@field remove fun(self: FigureHandler): boolean
---@field rename fun(self: FigureHandler, new_path: Path): boolean

---@param opts FigureHandlerOptions
function M.setup(opts)
    FigureHandler._new = opts.new
    FigureHandler._remove = opts.remove
    FigureHandler._rename = opts.rename

    local plugin_name = cfg.var.PLUGIN_NAME
    plugin_name = plugin_name:sub(1, 1):upper() .. plugin_name:sub(2)
    register_commands(plugin_name, opts.new)
end

return M
