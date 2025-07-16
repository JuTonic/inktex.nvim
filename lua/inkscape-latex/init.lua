local M = {}

local config = require("inkscape-latex.config")
local watcher = require("inkscape-latex.watcher")
local cmds = require("inkscape-latex.cmds")

---@param opts InkscapeLatexOptionsInput?
function M.setup(opts)
    local success = config.setup()
    if not success then
        return
    end

    watcher.setup()

    if config.opts.start_at_buffer_attach then
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "tex",
            callback = function(arg)
                watcher.ensure_running(arg.buf)
            end,
            desc = "start inkscape-texd at entering .tex file"
        })
    end

    cmds.setup()
end

return M
