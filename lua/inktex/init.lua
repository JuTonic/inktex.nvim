local M = {}

---@param opts InktexOptionsInput?
function M.setup(opts)
    local cfg = require("inktex.config")
    local success = cfg.setup(opts)
    if not success then
        return
    end

    local watcher = require("inktex.watcher")
    watcher.setup()
    if cfg.opts.start_at_buffer_attach then
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "tex",
            callback = function(arg)
                watcher.ensure_running_for_buf(
                    arg.buf,
                    cfg.opts.silent_watcher_start
                )
            end,
            desc = "starts "
                .. cfg.var.WATCHER_NAME
                .. " at entering .tex file",
        })
    end
end

return M
