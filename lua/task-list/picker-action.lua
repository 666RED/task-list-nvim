---@class PickerActionModule
---@field delete_task fun(item: Task, picker: snacks.Picker): nil
---@field prompt_add_task fun(callback: function): nil
---@field update_task fun(picker: snacks.Picker, item: Task, callback: function): nil
---@field filter_tasks fun(callback: function): nil
---@field sort_tasks fun(callback: function): nil
---@field choose_date_range fun(callback: function): nil
local M = {}

-- note: MODULES

---@type TaskModule
local task = require("task-list.task")

---@type UtilModule
local util = require("task-list.util")

-- note: TYPES

local UpdateOption = require("task-list.types").UpdateOption
local FilterOption = require("task-list.types").FilterOption
local SortOption = require("task-list.types").SortOption
local DateRangeOption = require("task-list.types").DateRangeOption

-- note: LOCAL FUNCTIONS

---@param picker snacks.Picker
---@param item any
---@return nil
local function update_task_text(picker, item)
	local updated_text = vim.fn.input("Updated task: ", item.text)

	-- update text
	if updated_text == "" then
		print("Discard changes")
		return
	end

	task.update_task(item.id, { text = updated_text })
	print("Text updated")

	picker:refresh()
end

---@param picker snacks.Picker
---@param item any
---@return nil
local function update_task_priority(picker, item)
	local updated_priority

	repeat
		updated_priority = vim.fn.input("Priority (1 = high, 2 = medium, 3 = low): ", item.priority)

		if updated_priority == "" then
			print("Cancelled")
			return
		end

		if updated_priority ~= "1" and updated_priority ~= "2" and updated_priority ~= "3" then
			print("Invalid updated_priority, please enter 1, 2 or 3")
		end
	until updated_priority == "1" or updated_priority == "2" or updated_priority == "3"

	task.update_task(item.id, { priority = tonumber(updated_priority) })
	print("Priority updated")

	picker:refresh()
end

---@param item Task
---@param callback function
---@return nil
local function update_task_due_date(item, callback)
	util.pick_date(function(updated_due_date)
		if updated_due_date ~= nil then
			task.update_task(item.id, { due_date = updated_due_date })
			print("Due date updated")
			callback()
		end
	end)
end

-- note: FUNCTIONS

function M.delete_task(item, picker)
	vim.schedule(function()
		vim.ui.select({ "No", "Yes" }, { prompt = 'Delete "' .. item.text .. '"?' }, function(choice)
			if choice == "Yes" then
				task.delete_task(item.id)
				print("Deleted: " .. item.text)
			end

			picker:refresh()
		end)
	end)
end

function M.prompt_add_task(callback)
	local text = vim.fn.input("New task: ")

	if text == "" then
		print("Cancelled")
		return
	end

	local priority

	repeat
		priority = vim.fn.input("Priority (1 = high, 2 = medium, 3 = low): ", "2")

		if priority == "" then
			print("Cancelled")
			return
		end

		if priority ~= "1" and priority ~= "2" and priority ~= "3" then
			print("Invalid priority, please enter 1, 2 or 3")
		end
	until priority == "1" or priority == "2" or priority == "3"

	vim.schedule(function()
		util.pick_date(function(due_date)
			if due_date ~= nil then
				task.add_task(text, priority, due_date)
				print("Added new task")
				callback()
			end
		end)
	end)
end

function M.update_task(picker, item, callback)
	vim.ui.select({
		UpdateOption.Text,
		UpdateOption.Priority,
		UpdateOption.Due_Date,
	}, { prompt = "Choose one to update" }, function(choice)
		if choice == UpdateOption.Text then
			update_task_text(picker, item)
		elseif choice == UpdateOption.Priority then
			update_task_priority(picker, item)
		elseif choice == UpdateOption.Due_Date then
			update_task_due_date(item, callback)
		end
	end)
end

function M.filter_tasks(callback)
	vim.ui.select({
		FilterOption.All,
		FilterOption.Finished,
		FilterOption.Unfinished,
	}, { prompt = "Select filter method" }, function(choice)
		vim.schedule(function()
			if choice == nil or choice == FilterOption.All then
				callback("All")
			elseif choice == FilterOption.Unfinished then
				callback("Unfinished")
			elseif choice == FilterOption.Finished then
				callback("Finished")
			end
		end)
	end)
end

function M.sort_tasks(callback)
	vim.ui.select({
		SortOption.Due_Date,
		SortOption.Created_Date,
		SortOption.Priority,
	}, { prompt = "Select sorting method" }, function(choice)
		vim.schedule(function()
			if choice == nil or choice == SortOption.Due_Date then
				callback("Due_Date")
			elseif choice == SortOption.Priority then
				callback("Priority")
			elseif choice == SortOption.Created_Date then
				callback("Created_Date")
			end
		end)
	end)
end

function M.choose_date_range(callback)
	vim.ui.select({
		DateRangeOption.No_Range,
		DateRangeOption.Today,
		DateRangeOption.Within_Three_Days,
		DateRangeOption.Within_One_Week,
		DateRangeOption.Within_Two_Weeks,
		DateRangeOption.Within_One_Month,
	}, { prompt = "Select date range" }, function(choice)
		vim.schedule(function()
			if choice == DateRangeOption.Today then
				callback(0)
			elseif choice == DateRangeOption.Within_Three_Days then
				callback(3)
			elseif choice == DateRangeOption.Within_One_Week then
				callback(8)
			elseif choice == DateRangeOption.Within_Two_Weeks then
				callback(14)
			elseif choice == DateRangeOption.Within_One_Month then
				callback(28)
			elseif choice == DateRangeOption.No_Range or choice == nil then
				callback(nil)
			end
		end)
	end)
end

return M
