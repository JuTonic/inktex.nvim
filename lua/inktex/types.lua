-- ╭─────────────────────────────────────────────────────────╮
-- │ FIGURE CONTEXT                                          │
-- ╰─────────────────────────────────────────────────────────╯

---@class FigureData
---@field start_row integer
---@field end_row integer
---@field path string

---@class FigureHandler
---@field start_row integer
---@field end_row integer
---@field path Path
---@field new fun(self: FigureHandler): FigureHandler | nil
---@field rename fun(self: FigureHandler, new_path: Path): boolean
---@field remove fun(self: FigureHandler): boolean

-- ╭─────────────────────────────────────────────────────────╮
-- │ CONFIG                                                  │
-- ╰─────────────────────────────────────────────────────────╯

--- @class InktexOptionsInput
--- @field start_at_buffer_attach? boolean
--- @field start_at_svg_open? boolean
--- @field figures_dir? string
--- @field create_figures_dir? boolean
--- @field inkscape_path? string
--- @field watcher_path? string
--- @field template? string
--- @field aux_prefix? string
--- @field recursively? boolean
--- @field regenerate? boolean
--- @field silent_watcher_start? boolean
--- @field auto_create_dir? boolean

--- @class InktexOptions : InktexOptionsInput
--- @field start_at_buffer_attach boolean
--- @field start_at_svg_open boolean
--- @field figures_dir string
--- @field create_figures_dir boolean
--- @field inkscape_path string
--- @field watcher_path string
--- @field template string
--- @field aux_prefix string
--- @field recursively boolean
--- @field regenerate boolean
--- @field silent_watcher_start boolean
--- @field auto_create_dir boolean
