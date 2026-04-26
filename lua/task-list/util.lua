---@class UtilModule
---@field safe_action fun(fn: fun(selection: any, prompt_bufnr: integer, map: any)): fun(prompt_bufnr: integer, map: any)
---@field load_tasks fun(condition: Condition, range?: DateRange): TaskList
---@field pick_date fun(fn: function): nil
---@field days_diff fun(due_date_str: string): integer
local M = {}

local DATE_PICKER_WIDTH = 0.5

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'

---@type ConfigModule
local config = require 'task-list.config'

local action_state = require 'telescope.actions.state'

---@return nil
local function ensure_file()
  vim.fn.mkdir(config.data_dir, 'p')

  -- if no such file, create one
  if vim.fn.filereadable(config.filepath) == 0 then
    vim.fn.writefile({ vim.fn.json_encode { list = {} } }, config.filepath)
  end
end

local function days_diff(due_date_str)
  local year, month, day = due_date_str:match '(%d+)-(%d+)-(%d+)'
  local due_time = os.time { year = year, month = month, day = day }
  local now_time = os.time()
  local diff = math.floor((due_time - now_time) / 86400)
  return diff
end

---@param tasks TaskList
---@param range DateRange
---@return Task[]
local function get_tasks_in_date_range(tasks, range)
  local result = {}

  for _, task in ipairs(tasks.list) do
    local diff = days_diff(task.due_date)

    if diff <= range then
      table.insert(result, task)
    end
  end

  return { list = result }
end

function M.safe_action(fn)
  return function(prompt_bufnr, map)
    local selection = action_state.get_selected_entry()
    if not selection then
      print 'No item selected'
      return
    end
    fn(selection, prompt_bufnr, map)
  end
end

function M.load_tasks(condition, range)
  ensure_file()

  local content = table.concat(vim.fn.readfile(config.filepath), '\n')

  if content == '' or content == nil then
    return { list = {} }
  end

  local decoded_content = vim.fn.json_decode(content)

  local task_list = {}

  if condition == nil or condition == 'All' then
    task_list = decoded_content
  elseif condition == 'Finished' then
    local tasks = {}

    for _, task in ipairs(decoded_content.list) do
      if task.finished then
        table.insert(tasks, task)
      end
    end

    task_list = { list = tasks }
  else
    local tasks = {}

    for _, task in ipairs(decoded_content.list) do
      if not task.finished then
        table.insert(tasks, task)
      end
    end

    task_list = { list = tasks }
  end

  return range == nil and task_list or get_tasks_in_date_range(task_list, range)
end

function M.pick_date(on_select)
  local now = os.time()
  local now_t = os.date('*t', now)

  -- Step 3: Pick day
  local function pick_day(year, month, on_done)
    local days_in_month = os.date(
      '*t',
      os.time {
        year = year,
        month = month + 1,
        day = 0,
      }
    ).day

    local days = {}

    for day = 1, days_in_month do
      local t = os.time { year = year, month = month, day = day }
      -- skip days before today
      if t >= os.time { year = now_t.year, month = now_t.month, day = now_t.day } then
        local weekday = os.date('%a', t)
        local date_str = os.date('%Y-%m-%d', t)
        local is_today = date_str == os.date('%Y-%m-%d', now)

        table.insert(days, {
          date = date_str,
          display = string.format('%s %s%s', weekday, date_str, is_today and '  ← today' or ''),
        })
      end
    end

    if #days == 0 then
      print 'No valid days in this month'
      return
    end

    pickers
      .new({
        sorting_strategy = 'ascending',
        layout_config = { width = DATE_PICKER_WIDTH, height = 0.8 },
      }, {
        prompt_title = string.format('Pick task due date (Day) — %d/%02d', year, month),
        finder = finders.new_table {
          results = days,
          entry_maker = function(entry)
            return {
              value = entry.date,
              display = entry.display,
              ordinal = entry.date,
            }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if selection and on_done then
              on_done(selection.value)
            end
          end)
          return true
        end,
      })
      :find()
  end

  -- Step 2: Pick month
  local function pick_month(year, on_done)
    local month_names = {
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    }

    local months = {}
    for i, name in ipairs(month_names) do
      -- skip months before current month if same year
      local valid = year > now_t.year or (year == now_t.year and i >= now_t.month)

      if valid then
        table.insert(months, { index = i, name = name })
      end
    end

    pickers
      .new({
        sorting_strategy = 'ascending',
        layout_config = { width = DATE_PICKER_WIDTH, height = #months + 5 },
      }, {
        prompt_title = 'Pick task due date (Month) — ' .. year,
        finder = finders.new_table {
          results = months,
          entry_maker = function(entry)
            return {
              value = entry,
              display = string.format(entry.name),
              ordinal = entry.name,
            }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if selection then
              vim.schedule(function()
                on_done(selection.value.index)
              end)
            end
          end)
          return true
        end,
      })
      :find()
  end

  -- Step 1: Pick year
  local function pick_year(on_done)
    local years = {}
    for i = now_t.year, now_t.year + 5 do
      table.insert(years, i)
    end

    pickers
      .new({
        sorting_strategy = 'ascending',
        layout_config = { width = DATE_PICKER_WIDTH, height = #years + 5 },
      }, {
        prompt_title = 'Pick task due date (Year)',
        finder = finders.new_table {
          results = years,
          entry_maker = function(entry)
            return {
              value = entry,
              display = tostring(entry),
              ordinal = tostring(entry),
            }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()

            if selection then
              vim.schedule(function()
                on_done(selection.value)
              end)
            end
          end)
          return true
        end,
      })
      :find()
  end

  -- chain: year → month → day
  pick_year(function(year)
    pick_month(year, function(month)
      pick_day(year, month, function(date)
        if on_select then
          on_select(date)
        end
      end)
    end)
  end)
end

M.days_diff = days_diff

return M
