local M = {}

local config = require("inkscape-latex.config")
local watcher = require("inkscape-latex.watcher")
local cmds = require("inkscape-latex.cmds")

function M.setup(options)
    local success = config.setup()
    if not success then
        return
    end
    watcher.setup()
    cmds.setup()
end

return M
