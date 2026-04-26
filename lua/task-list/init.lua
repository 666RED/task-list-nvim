local M = {}

-- note: MODULES

---@type TaskModule
local task = require 'task-list.task'

---@type UtilModule
local util = require 'task-list.util'

---@type ConfigModule
local config = require 'task-list.config'

-- note: TELESCOPE
local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'

-- note: TYPES

---@type Condition
local condition = 'All'

---@type SortingMethod
local sort = 'Due_Date'

---@type Order
local order = 'Ascending'

---@type DateRange
local range = nil

local FilterOption = require('task-list.types').FilterOption
local SortOption = require('task-list.types').SortOption
local UpdateOption = require('task-list.types').UpdateOption
local PriorityType = require('task-list.types').PriorityType
local DateRangeOption = require('task-list.types').DateRangeOption

-- note: LOCAL FUNCTIONS

local function restore_setting()
  condition = 'All'
  sort = 'Due_Date'
  order = 'Ascending'
  range = nil
end

---@param prompt_bufnr integer
---@param callback fun(): nil
local function prompt_add_task(prompt_bufnr, callback)
  local text = vim.fn.input 'New task: '

  if text == '' then
    print 'Cancelled'
    return
  end

  local priority

  repeat
    priority = vim.fn.input('Priority (1 = high, 2 = medium, 3 = low): ', '2')

    if priority == '' then
      print 'Cancelled'
      return
    end

    if priority ~= '1' and priority ~= '2' and priority ~= '3' then
      print 'Invalid priority, please enter 1, 2 or 3'
    end
  until priority == '1' or priority == '2' or priority == '3'

  actions.close(prompt_bufnr)

  vim.schedule(function()
    util.pick_date(function(due_date)
      if due_date ~= nil then
        task.add_task(text, priority, due_date)
        print 'Added new task'

        callback()
      end
    end)
  end)
end

---@param entry any
local function create_entry_maker(entry)
  local diff = util.days_diff(entry.due_date)

  local due_label = diff <= 0 and entry.due_date .. ' (today)' or entry.due_date .. ' (' .. diff .. 'd)'

  local icon = entry.finished and '✅' or '⬜'
  local priority_icon = config.priority_icons[entry.priority] or '⬜'

  -- fixed width columns using string.format
  local col_status = string.format('%-2s', icon)
  local col_priority = string.format('%-2s', priority_icon)
  local col_due = string.format('%-20s', due_label)
  local col_text = string.format('%-40s', entry.text)

  local display_text = col_status .. ' ' .. col_priority .. ' ' .. col_due .. ' ' .. col_text

  return {
    value = entry,
    ordinal = entry.text,
    display = function()
      local highlights = {}

      -- highlight due date based on urgency
      local due_start = #col_status + #col_priority + 2
      local due_end = due_start + #col_due

      if diff <= 0 then
        table.insert(highlights, { { due_start, due_end }, PriorityType.High }) -- red today
      elseif diff < 7 then
        table.insert(highlights, { { due_start, due_end }, PriorityType.Medium }) -- yellow 1 week
      else
        table.insert(highlights, { { due_start, due_end }, PriorityType.Low }) -- blue upcoming
      end

      -- highlight finished tasks as dimmed
      if entry.finished then
        table.insert(highlights, { { 0, #display_text }, 'Comment' })
      end

      return display_text, highlights
    end,
  }
end

---@param callback fun(): nil
---@param selection any
---@return nil
local function update_task_text(callback, selection)
  local updated_text = vim.fn.input('Updated task', selection.value.text)

  -- update text
  if updated_text == '' then
    print 'Discard changes'
    callback()
    return
  end

  task.update_task(selection.value.id, { text = updated_text })
  print 'Text updated'

  callback()
end

---@param callback fun(): nil
---@param selection any
---@return nil
local function update_task_priority(callback, selection)
  local updated_priority

  repeat
    updated_priority = vim.fn.input('Priority (1 = high, 2 = medium, 3 = low): ', selection.value.priority)

    if updated_priority == '' then
      print 'Cancelled'
      callback()
    end

    if updated_priority ~= '1' and updated_priority ~= '2' and updated_priority ~= '3' then
      print 'Invalid updated_priority, please enter 1, 2 or 3'
    end
  until updated_priority == '1' or updated_priority == '2' or updated_priority == '3'

  task.update_task(selection.value.id, { priority = tonumber(updated_priority) })
  print 'Priority updated'

  callback()
end

---@param callback fun(): nil
---@return nil
local function update_task_due_date(callback)
  local selection = action_state.get_selected_entry()

  vim.schedule(function()
    util.pick_date(function(updated_due_date)
      if updated_due_date ~= nil then
        task.update_task(selection.value.id, { due_date = updated_due_date })
        print 'Due date updated'
      end

      callback()
    end)
  end)
end

---@param picker table
---@return nil
local function refresh_window(picker)
  local tasks = util.load_tasks(condition, range)
  local updated_all = task.sort_tasks(tasks, sort, order)

  local title

  if condition == 'All' or condition == nil then
    title = 'All tasks'
  elseif condition == 'Unfinished' then
    title = 'Unfinished tasks'
  elseif condition == 'Finished' then
    title = 'Finished tasks'
  end

  picker.prompt_title = title

  picker:refresh(
    finders.new_table {
      results = updated_all,
      entry_maker = function(entry)
        return create_entry_maker(entry)
      end,
    },
    { reset_prompt = false }
  )
end

---@return nil
local function pick_all()
  local tasks = util.load_tasks(condition, range)
  local all = task.sort_tasks(tasks, sort, order)
  local title

  if condition == 'All' or condition == nil then
    title = 'All tasks'
  elseif condition == 'Unfinished' then
    title = 'Unfinished tasks'
  elseif condition == 'Finished' then
    title = 'Finished tasks'
  end

  pickers
    .new({ sorting_strategy = 'ascending', layout_config = {
      width = 0.7,
      height = 0.7,
    }, selection_strategy = 'row' }, {
      prompt_title = title,
      finder = finders.new_table {
        results = all,
        entry_maker = function(entry)
          return create_entry_maker(entry)
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(util.safe_action(function()
          local selection = action_state.get_selected_entry()
          local picker = action_state.get_current_picker(prompt_bufnr)

          if selection.value.finished then
            task.unfinish_task(selection.value.id)
            print('Set to unfinished: ' .. selection.value.text)
          else
            task.finish_task(selection.value.id)
            print('Finished: ' .. selection.value.text)
          end

          refresh_window(picker)
        end))

        -- note: delete
        map(
          'i',
          '<M-d>',
          util.safe_action(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)

            vim.ui.select({ 'No', 'Yes' }, { prompt = 'Delete "' .. selection.value.text .. '"?' }, function(choice)
              if choice == 'Yes' then
                task.delete_task(selection.value.id)
                print('Deleted: ' .. selection.value.text)
              end

              pick_all()
            end)
          end)
        )

        -- note: add
        map('i', '<M-a>', function()
          prompt_add_task(prompt_bufnr, function()
            vim.schedule(function()
              pick_all()
            end)
          end)
        end)

        -- note: update
        map(
          'i',
          '<M-u>',
          util.safe_action(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)

            vim.ui.select({
              UpdateOption.Text,
              UpdateOption.Priority,
              UpdateOption.Due_Date,
            }, { prompt = 'Choose one to update' }, function(choice)
              local callback = function()
                vim.schedule(function()
                  pick_all()
                end)
              end

              if choice == UpdateOption.Text then
                update_task_text(callback, selection)
              elseif choice == UpdateOption.Priority then
                update_task_priority(callback, selection)
              elseif choice == UpdateOption.Due_Date then
                update_task_due_date(callback)
              end
            end)
          end)
        )

        -- note: filter
        map('i', '<M-f>', function()
          actions.close(prompt_bufnr)

          vim.ui.select({
            FilterOption.All,
            FilterOption.Finished,
            FilterOption.Unfinished,
          }, { prompt = 'Select filter method' }, function(choice)
            vim.schedule(function()
              if choice == nil or choice == FilterOption.All then
                condition = 'All'
              elseif choice == FilterOption.Unfinished then
                condition = 'Unfinished'
              elseif choice == FilterOption.Finished then
                condition = 'Finished'
              end

              pick_all()
            end)
          end)
        end)

        -- note: sort
        map('i', '<M-s>', function()
          actions.close(prompt_bufnr)

          vim.ui.select({
            SortOption.Due_Date,
            SortOption.Created_Date,
            SortOption.Priority,
          }, { prompt = 'Select sorting method' }, function(choice)
            vim.schedule(function()
              if choice == nil or choice == SortOption.Due_Date then
                sort = 'Due_Date'
              elseif choice == SortOption.Priority then
                sort = 'Priority'
              elseif choice == SortOption.Created_Date then
                sort = 'Created_Date'
              end

              pick_all()
            end)
          end)
        end)

        -- note: switch order
        map('i', '<M-o>', function()
          local picker = action_state.get_current_picker(prompt_bufnr)

          order = order == 'Ascending' and 'Descending' or 'Ascending'
          print(order)
          refresh_window(picker)
        end)

        -- note: choose due date range (today, < 3 days, < 1 week, < 2 weeks, < 1 month)
        map('i', '<M-r>', function()
          actions.close(prompt_bufnr)

          vim.ui.select({
            DateRangeOption.No_Range,
            DateRangeOption.Today,
            DateRangeOption.Within_Three_Days,
            DateRangeOption.Within_One_Week,
            DateRangeOption.Within_Two_Weeks,
            DateRangeOption.Within_One_Month,
          }, { prompt = 'Select date range' }, function(choice)
            vim.schedule(function()
              if choice == DateRangeOption.Today then
                range = 0
              elseif choice == DateRangeOption.Within_Three_Days then
                range = 3
              elseif choice == DateRangeOption.Within_One_Week then
                range = 7
              elseif choice == DateRangeOption.Within_Two_Weeks then
                range = 14
              elseif choice == DateRangeOption.Within_One_Month then
                range = 28
              elseif choice == DateRangeOption.No_Range or choice == nil then
                range = nil
              end

              pick_all()
            end)
          end)
        end)

        -- note: Clear all settings (All, Due date, Ascending, No range)
        map('i', '<M-p>', function()
          actions.close(prompt_bufnr)
          vim.ui.select({ 'No', 'Yes' }, { prompt = 'Restore to default setting?' }, function(choice)
            if choice == 'Yes' then
              restore_setting()
              pick_all()
            end
          end)
        end)

        return true
      end,
    })
    :find()
end

-- note: SETUP FUNCTION

function M.setup()
  vim.api.nvim_create_user_command('Task', function()
    pick_all()
  end, {})
end

return M
