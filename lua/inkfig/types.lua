---@class FigureContext
---@field start_row integer
---@field end_row integer
---@field path Path
---@field new fun(self: FigureContext): FigureContext?
---@field rename fun(self: FigureContext): boolean
---@field remove fun(self: FigureContext): boolean

-- ╭─────────────────────────────────────────────────────────╮
-- │ CONFIG                                                  │
-- ╰─────────────────────────────────────────────────────────╯

--- @class InkscapeLatexOptionsInput
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

--- @class InkscapeLatexOptions : InkscapeLatexOptionsInput
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

-- ╭─────────────────────────────────────────────────────────╮
-- │ UTILS                                                   │
-- ╰─────────────────────────────────────────────────────────╯

---@class Path
---@field path string
---@field _last_slash_index integer
---@field _last_dot_index integer
---@field new fun(self: Path, path: string): Path
---@field dir fun(self: Path): string?
---@field file fun(self: Path): string?
---@field stem fun(self: Path): string?
---@field ext fun(self: Path): string?

---@class BracketPair
---@field opening string
---@field closing string

---@class EnviromentMatch
---@field name string
---@field content string[]
---@field start_line integer
---@field end_line integer
