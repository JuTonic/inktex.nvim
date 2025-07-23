local M = {}

local config = require("inkfig.config")
local core = require("inkfig.core")
local watcher = require("inkfig.watcher")

---@param opts InkscapeLatexOptionsInput?
function M.setup(opts)
    local success = config.setup(opts)
    if not success then
        return
    end

    -- print(config.opts.figures_dir)

    watcher.setup()

    if config.opts.start_at_buffer_attach then
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "tex",
            callback = function(arg)
                watcher.ensure_running_for_buf(
                    arg.buf,
                    config.opts.silent_watcher_start
                )
            end,
            desc = "starts inkfigd at entering .tex file",
        })
    end

    core.setup()
end

return M
