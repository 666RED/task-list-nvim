local M = {}

-- note: MODULES

---@type TaskModule
local task = require("task-list.task")

---@type UtilModule
local util = require("task-list.util")

---@type ConfigModule
local config = require("task-list.config")

---@type PickerActionModule
local picker_action = require("task-list.picker-action")

local snacks = require("snacks")

-- note: TYPES

---@type Condition
local condition = "All"

---@type SortingMethod
local sort = "Due_Date"

---@type Order
local order = "Ascending"

---@type DateRange
local range = nil

-- note: LOCAL FUNCTIONS

local function restore_setting()
	condition = "All"
	sort = "Due_Date"
	order = "Ascending"
	range = nil
end

local function format_item(item, _)
	local icon = item.finished and "✅" or "⬜"
	local priority_icon = config.priority_icons[item.priority] or "⬜"
	local day_diff = util.days_diff(item.due_date)

	local text

	if day_diff == nil then
		text = "Nil"
	elseif day_diff < 0 then
		text = "expired"
	elseif day_diff == 0 then
		text = "today"
	elseif day_diff == 1 then
		text = ("%d day"):format(day_diff)
	else
		text = ("%d days"):format(day_diff)
	end

	local ret = {}
	ret[#ret + 1] = { ("%-4s"):format(icon) }
	ret[#ret + 1] = { ("%-5s"):format(priority_icon) }
	ret[#ret + 1] = { ("[ %-9s]  "):format(text) }
	ret[#ret + 1] = { item.text, item.finished and "Comment" }

	return ret
end

---@return nil
local function pick_all()
	local title

	if condition == "All" or condition == nil then
		title = "All tasks"
	elseif condition == "Unfinished" then
		title = "Unfinished tasks"
	elseif condition == "Finished" then
		title = "Finished tasks"
	end

	snacks.picker.pick({
		title = title,
		show_empty = true,
		finder = function()
			local tasks = util.load_tasks(condition, range)
			local sorted_tasks = task.sort_tasks(tasks, sort, order)

			return sorted_tasks
		end,
		format = format_item,
		preview = function(ctx)
			local item = ctx.item

			if not item then
				return
			end

			-- show task details in preview window
			local finished_text = item.finished and item.finished_at or "Not yet"
			local priority_text = item.priority == 1 and "High" or item.priority == 2 and "Medium" or "Low"

			ctx.preview:set_lines({
				"Task      : " .. item.text,
				"Priority  : " .. priority_text,
				"Due       : " .. item.due_date,
				"Finished  : " .. finished_text,
				"Created   : " .. item.created_at,
			})
		end,
		layout = {
			layout = {
				backdrop = false,
				row = 1,
				width = 0.8,
				min_width = 80,
				height = 0.9,
				border = "none",
				box = "vertical",
				{
					box = "vertical",
					border = true,
					title = "{title} {live} {flags}",
					title_pos = "center",
					{ win = "input", height = 1, border = "bottom" },
					{ win = "list", border = "none" },
				},

				{ win = "preview", title = "{preview}", height = 0.3, border = true },
			},
		},
		---@param picker snacks.Picker
		---@param item Task
		confirm = util.safe_action(function(picker, item)
			if item.finished then
				task.unfinish_task(item.id)
				print("Set to unfinished: " .. item.text)
			else
				task.finish_task(item.id)
				print("Finished: " .. item.text)
			end

			picker:refresh()
		end),
		actions = {
			---@param picker snacks.Picker
			---@param item Task
			delete_task = util.safe_action(function(picker, item)
				picker_action.delete_task(item, picker)
			end),

			add_task = function()
				picker_action.prompt_add_task(function()
					pick_all()
				end)
			end,

			---@param picker snacks.Picker
			---@param item Task
			update_task = util.safe_action(function(picker, item)
				picker_action.update_task(picker, item, function()
					pick_all()
				end)
			end),

			---@param picker snacks.Picker
			filter_tasks = function(picker, _)
				picker_action.filter_tasks(function(result)
					condition = result
					picker:refresh()
				end)
			end,

			---@param picker snacks.Picker
			sort_tasks = function(picker, _)
				picker_action.sort_tasks(function(result)
					sort = result
					picker:refresh()
				end)
			end,

			---@param picker snacks.Picker
			switch_order = function(picker, _)
				order = order == "Ascending" and "Descending" or "Ascending"
				picker:refresh()
			end,

			---@param picker snacks.Picker
			choose_date_range = function(picker, _)
				picker_action.choose_date_range(function(result)
					range = result
					picker:refresh()
				end)
			end,

			---@param picker snacks.Picker
			reset_all = function(picker, _)
				vim.ui.select({ "No", "Yes" }, { prompt = "Restore to default setting?" }, function(choice)
					if choice == "Yes" then
						restore_setting()
						picker:refresh()
					end
				end)
			end,
		},
		win = {
			input = {
				keys = {
					["<M-d>"] = { "delete_task", mode = { "i", "n" } },
					["<M-a>"] = { "add_task", mode = { "i", "n" } },
					["<M-u>"] = { "update_task", mode = { "i", "n" } },
					["<M-f>"] = { "filter_tasks", mode = { "i", "n" } },
					["<M-s>"] = { "sort_tasks", mode = { "i", "n" } },
					["<M-o>"] = { "switch_order", mode = { "i", "n" } },
					["<M-r>"] = { "choose_date_range", mode = { "i", "n" } },
					["<M-p>"] = { "reset_all", mode = { "i", "n" } },
				},
			},
		},
	})
end

-- note: SETUP FUNCTION

function M.setup()
	vim.api.nvim_create_user_command("Task", function()
		pick_all()
	end, {})
end

return M
