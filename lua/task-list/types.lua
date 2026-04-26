---@class Task
---@field id number
---@field text string
---@field finished boolean
---@field priority number
---@field created_at string
---@field finished_at? string|osdate
---@field due_date string

---@class TaskList
---@field list Task[]

---@class UpdateTaskOpts
---@field text? string
---@field priority? number
---@field due_date? string

---@alias Condition 'All'|'Finished'|'Unfinished'|nil -- default is all
---@alias SortingMethod 'Priority'|'Created_Date'|'Due_Date'|nil -- default is due date
---@alias Order 'Ascending'|"Descending"|nil -- default is Ascending (High priority first / Oldest task first)
---@alias DateRange 0|3|7|14|28|nil -- default is nil (no range specified)

---@enum SortOption
local SortOption = {
  Created_Date = 'Sort by Created Date',
  Priority = 'Sort by Priority',
  Due_Date = 'Sort by Due Date',
}

---@enum FilterOption
local FilterOption = {
  All = 'List all tasks',
  Unfinished = 'List all unfinished tasks',
  Finished = 'List all finished tasks',
}

---@enum UpdateOption
local UpdateOption = {
  Text = 'Update text',
  Priority = 'Update priority',
  Due_Date = 'Update due date',
}

---@enum DateRangeOption
local DateRangeOption = {
  No_Range = 'No range',
  Today = 'Today',
  Within_Three_Days = 'Within 3 days',
  Within_One_Week = 'Withitn 1 week',
  Within_Two_Weeks = 'Within 2 weeks',
  Within_One_Month = 'Within 1 month',
}

---@enum PriorityType
local PriorityType = {
  High = 'TaskHighPriority',
  Medium = 'TaskMediumPriority',
  Low = 'TaskLowPriority',
}

---@class TypesModule
---@field SortOption table<string, SortOption>
---@field FilterOption table<string, FilterOption>
---@field UpdateOption table<string, UpdateOption>
---@field PriorityType table<string, PriorityType>
---@field DateRangeOption table<string, DateRangeOption>
local M = {}

M.FilterOption = FilterOption
M.SortOption = SortOption
M.UpdateOption = UpdateOption
M.PriorityType = PriorityType
M.DateRangeOption = DateRangeOption

return M
