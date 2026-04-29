---@class ConfigModule
---@field data_dir string
---@field filepath string
---@field priority_icons table<number, string>
local M = {}

local PriorityType = require("task-list.types").PriorityType

M.data_dir = vim.fn.stdpath("data") .. "/task-list"
M.filepath = M.data_dir .. "/task.json"
M.priority_icons = { [1] = "🔴", [2] = "🟡", [3] = "🟢" }

vim.api.nvim_set_hl(0, PriorityType.High, { link = "DiagnosticError" })
vim.api.nvim_set_hl(0, PriorityType.Medium, { link = "DiagnosticWarn" })
vim.api.nvim_set_hl(0, PriorityType.Low, { link = "DiagnosticInfo" })

return M
