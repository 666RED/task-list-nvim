---@class UtilModule
---@field safe_action fun(fn: fun(picker: snacks.Picker, item: Task)): fun(picker: snacks.Picker, item: Task)
---@field load_tasks fun(condition: Condition, range?: DateRange): Task[]
---@field pick_date fun(fn: function): nil
---@field days_diff fun(due_date_str: string): integer
local M = {}

-- note: MODULES

local snacks = require("snacks")

---@type ConfigModule
local config = require("task-list.config")

-- note: LOCAL FUNCTION

---@return nil
local function ensure_file()
	vim.fn.mkdir(config.data_dir, "p")

	-- if no such file, create one
	if vim.fn.filereadable(config.filepath) == 0 then
		vim.fn.writefile({ vim.fn.json_encode({ list = {} }) }, config.filepath)
	end
end

local function days_diff(due_date_str)
	local year, month, day = due_date_str:match("(%d+)-(%d+)-(%d+)")
	local due_time = os.time({ year = year, month = month, day = day })
	local now = os.date("*t")

	local now_time = os.time({
		year = now.year,
		month = now.month,
		day = now.day,
		hour = 0,
	})

	local diff = math.floor((due_time - now_time) / 86400)
	return diff
end

---@param tasks Task[]
---@param range DateRange
---@return Task[]
local function get_tasks_in_date_range(tasks, range)
	local result = {}

	for _, task in ipairs(tasks) do
		local diff = days_diff(task.due_date)

		if diff <= range then
			table.insert(result, task)
		end
	end

	return result
end

-- note: EXPORT FUNCTION

function M.safe_action(fn)
	return function(picker, item)
		if not item then
			print("No item selected")
			return
		end

		fn(picker, item)
	end
end

function M.load_tasks(condition, range)
	ensure_file()

	local content = table.concat(vim.fn.readfile(config.filepath), "\n")

	if content == "" or content == nil then
		return { list = {} }
	end

	local decoded_content = vim.fn.json_decode(content)

	local task_list = {}

	if condition == nil or condition == "All" then
		task_list = decoded_content.list
	elseif condition == "Finished" then
		for _, task in ipairs(decoded_content.list) do
			if task.finished then
				table.insert(task_list, task)
			end
		end
	else
		for _, task in ipairs(decoded_content.list) do
			if not task.finished then
				table.insert(task_list, task)
			end
		end
	end

	return range == nil and task_list or get_tasks_in_date_range(task_list, range)
end

function M.pick_date(on_select)
	local now = os.time()
	local now_t = os.date("*t", now)

	-- Step 3: Pick day
	local function pick_day(year, month, on_done)
		local days_in_month = os.date(
			"*t",
			os.time({
				year = year,
				month = month + 1,
				day = 0,
			})
		).day
		local confirmed = false

		local days = {}

		for day = 1, days_in_month do
			local t = os.time({ year = year, month = month, day = day })
			-- skip days before today
			if t >= os.time({ year = now_t.year, month = now_t.month, day = now_t.day }) then
				local weekday = os.date("%a", t)
				local date_str = os.date("%Y-%m-%d", t)
				local is_today = date_str == os.date("%Y-%m-%d", now)

				table.insert(days, {
					text = date_str,
					date = date_str,
					display = string.format("%s %s%s", weekday, date_str, is_today and "  ← today" or ""),
				})
			end
		end

		if #days == 0 then
			print("No valid days in this month")
			return
		end

		snacks.picker.pick({
			title = string.format("Pick task due date (Day) — %d/%02d", year, month),
			layout = {
				preset = "select",
			},
			items = days,
			format = function(item, _)
				return { { item.display } }
			end,
			confirm = function(picker, item)
				if item then
					confirmed = true
					on_done(item.text)
					picker:close()
				end
			end,
			on_close = function()
				if not confirmed then
					print("Cancelled")
				end
			end,
		})
	end

	-- Step 2: Pick month
	local function pick_month(year, on_done)
		local month_names = {
			"January",
			"February",
			"March",
			"April",
			"May",
			"June",
			"July",
			"August",
			"September",
			"October",
			"November",
			"December",
		}
		local confirmed = false

		local months = {}
		for i, name in ipairs(month_names) do
			-- skip months before current month if same year
			local valid = year > now_t.year or (year == now_t.year and i >= now_t.month)

			if valid then
				table.insert(months, { text = name, index = i, name = name })
			end
		end

		snacks.picker.pick({
			title = "Pick task due date (Month) - " .. year,
			sort = {
				fields = { "text" },
			},
			layout = {
				preset = "select",
			},
			items = months,
			format = function(item, _)
				return { { item.name } }
			end,
			confirm = function(_, item)
				if item then
					confirmed = true
					on_done(item.index)
				end
			end,
			on_close = function()
				if not confirmed then
					print("Cancelled")
				end
			end,
		})
	end

	-- Step 1: Pick year
	local function pick_year(on_done)
		local years = {}
		local idx = 1
		local confirmed = false

		for i = now_t.year, now_t.year + 5 do
			table.insert(years, {
				idx = idx,
				text = tostring(i),
			})
			idx = idx + 1
		end

		snacks.picker.pick({
			title = "Pick task due date (Year)",
			items = years,
			sort = {
				fields = { "text" },
			},
			layout = {
				preset = "select",
			},
			format = function(item, _)
				return { { item.text } }
			end,
			confirm = function(_, item)
				if item then
					confirmed = true
					on_done(tonumber(item.text))
				end
			end,
			on_close = function()
				if not confirmed then
					print("Cancelled")
				end
			end,
		})
	end

	-- chain: year → month → day
	pick_year(function(year)
		pick_month(year, function(month)
			pick_day(year, month, function(date)
				on_select(date)
			end)
		end)
	end)
end

M.days_diff = days_diff

return M
