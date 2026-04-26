---@class TaskModule
---@field add_task fun(text: string, priority: number, due_date: string): nil
---@field finish_task fun(id: number): nil
---@field unfinish_task fun(id: number): nil
---@field delete_task fun(id: number): nil
---@field sort_tasks fun(tasks: TaskList, sort: SortingMethod, order: Order): Task[]
---@field add_task fun(text: string, priority: string, due_date: string): nil
---@field update_task fun(id: number, opts: UpdateTaskOpts): nil
local M = {}

-- note: MODULES

---@type ConfigModule
local config = require 'task-list.config'

---@type UtilModule
local util = require 'task-list.util'

-- note: LOCAL FUNCTIONS

---@param tasks TaskList
local function save_tasks(tasks)
  vim.fn.writefile({ vim.fn.json_encode(tasks) }, config.filepath)
end

-- note: EXPORT FUNCTIONS

function M.add_task(text, priority, due_date)
  local tasks = util.load_tasks()

  table.insert(tasks.list, {
    id = os.time(),
    text = text,
    created_at = os.date '%Y-%m-%d %H:%M:%S',
    finished = false,
    priority = tonumber(priority),
    due_date = due_date,
  })

  save_tasks(tasks)
end

function M.finish_task(id)
  local tasks = util.load_tasks()

  for _, task in ipairs(tasks.list) do
    if task.id == id then
      task.finished_at = os.date '%Y-%m-%d %H:%M:%S'
      task.finished = true
      break
    end
  end

  save_tasks(tasks)
end

function M.unfinish_task(id)
  local tasks = util.load_tasks()

  for _, task in ipairs(tasks.list) do
    if task.id == id then
      task.finished_at = nil
      task.finished = false
      break
    end
  end

  save_tasks(tasks)
end

function M.update_task(id, opts)
  local updated_field
  local updated_value

  if opts.text ~= nil then
    updated_field = 'text'
    updated_value = opts.text
  elseif opts.priority ~= nil then
    updated_field = 'priority'
    updated_value = opts.priority
  elseif opts.due_date ~= nil then
    updated_field = 'due_date'
    updated_value = opts.due_date
  end

  local tasks = util.load_tasks()

  local new_list = {}

  for _, task in ipairs(tasks.list) do
    if task.id == id then
      task[updated_field] = updated_value
    end

    table.insert(new_list, task)
  end

  save_tasks(tasks)
end

function M.delete_task(id)
  local tasks = util.load_tasks()

  local new_list = {}

  for _, task in ipairs(tasks.list) do
    if task.id ~= id then
      table.insert(new_list, task)
    end
  end

  tasks.list = new_list

  save_tasks(tasks)
end

function M.sort_tasks(tasks, sort, order)
  table.sort(tasks.list, function(a, b)
    local key

    if sort == 'Due_Date' then
      key = 'due_date'
    elseif sort == 'Priority' then
      key = 'priority'
    else
      key = 'created_at'
    end

    if order == 'Ascending' then
      return a[key] < b[key]
    else
      return a[key] > b[key]
    end
  end)

  return tasks.list
end

return M
