local ui = require("xcodebuild.ui")
local parser = require("xcodebuild.parser")
local util = require("xcodebuild.util")
local appdata = require("xcodebuild.appdata")
local quickfix = require("xcodebuild.quickfix")
local config = require("xcodebuild.config")
local xcode = require("xcodebuild.xcode")
local logs = require("xcodebuild.logs")
local diagnostics = require("xcodebuild.diagnostics")

local M = {}
local testReport = {}

function M.get_report()
	return testReport
end

function M.setup_log_buffer(bufnr)
	local win = vim.fn.win_findbuf(bufnr)[1]
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	vim.api.nvim_buf_set_option(bufnr, "readonly", false)

	vim.api.nvim_win_set_option(win, "wrap", false)
	vim.api.nvim_win_set_option(win, "spell", false)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "objc")
	vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
	vim.api.nvim_buf_set_option(bufnr, "fileencoding", "utf-8")
	vim.api.nvim_buf_set_option(bufnr, "modified", false)

	vim.api.nvim_buf_set_option(bufnr, "readonly", true)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

	vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<cmd>close<cr>", {})
	vim.api.nvim_buf_set_keymap(bufnr, "n", "o", "", {
		callback = function()
			ui.open_test_file(testReport.tests)
		end,
	})
end

function M.load_last_report()
	local success, log = pcall(appdata.read_original_logs)
	if success then
		parser.clear()
		testReport = parser.parse_logs(log)
		quickfix.set(testReport)
	end
end

function M.refresh_buf_diagnostics(bufnr, file)
	local testClass = util.get_filename(file)
	diagnostics.refresh_diagnostics(bufnr, testClass, testReport)
	diagnostics.set_buf_marks(bufnr, testClass, testReport.tests)
end

function M.build_and_install_app(callback)
	appdata.create_app_dir()
	config.load_settings()

	M.build_project({
		open_logs_on_success = false,
	}, function(report)
		local destination = config.settings().destination
		local target = config.settings().appTarget
		local settings = xcode.get_app_settings(report.output)

		if report.buildErrors and report.buildErrors[1] then
			vim.print("Build Failed")
			logs.open_logs(true, true)
			return
		end

		if target then
			xcode.kill_app(target)
		end

		config.settings().appPath = settings.appPath
		config.settings().appTarget = settings.targetName
		config.settings().bundleId = settings.bundleId
		config.save_settings()

		vim.print("Installing...")
		xcode.install_app(destination, settings.appPath, function()
			vim.print("Launching...")
			xcode.launch_app(destination, settings.bundleId, function()
				callback()
			end)
		end)
	end)
end

function M.build_project(opts, callback)
	appdata.create_app_dir()
	config.load_settings()

	local open_logs_on_success = (opts or {}).open_logs_on_success
	vim.print("Building...")
	vim.cmd("silent wa!")
	parser.clear()

	local on_stdout = function(_, output)
		testReport = parser.parse_logs(output)

		if testReport.buildErrors and testReport.buildErrors[1] then
			vim.cmd("echo 'Building... [Errors: " .. #testReport.buildErrors .. "]'")
		end
	end

	local on_stderr = function(_, output)
		testReport = parser.parse_logs(output)
	end

	local on_exit = function()
		logs.set_logs(testReport, false, open_logs_on_success)
		if not testReport.buildErrors or not testReport.buildErrors[1] then
			vim.print("Build Succeeded")
		end
		quickfix.set(testReport)
		callback(testReport)
	end

	xcode.build_project({
		on_exit = on_exit,
		on_stdout = on_stdout,
		on_stderr = on_stderr,

		destination = config.settings().destination,
		projectCommand = config.settings().projectCommand,
		scheme = config.settings().scheme,
		testPlan = config.settings().testPlan,
	})
end

function M.run_tests(testsToRun)
	appdata.create_app_dir()
	config.load_settings()

	vim.print("Starting Tests...")
	vim.cmd("silent wa!")
	parser.clear()

	local isFirstChunk = true
	local on_stdout = function(_, output)
		testReport = parser.parse_logs(output)
		ui.show_tests_progress(testReport, isFirstChunk)
		diagnostics.refresh_buf_diagnostics(testReport)
		isFirstChunk = false
	end

	local on_stderr = function(_, output)
		isFirstChunk = false
		testReport = parser.parse_logs(output)
	end

	local on_exit = function()
		logs.set_logs(testReport, true, true)
		quickfix.set(testReport)
		diagnostics.refresh_buf_diagnostics(testReport)
	end

	xcode.run_tests({
		on_exit = on_exit,
		on_stdout = on_stdout,
		on_stderr = on_stderr,

		destination = config.settings().destination,
		projectCommand = config.settings().projectCommand,
		scheme = config.settings().scheme,
		testPlan = config.settings().testPlan,
		testsToRun = testsToRun,
	})
end

local function find_tests(opts)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local selectedClass = nil
	local selectedTests = {}

	for _, line in ipairs(lines) do
		selectedClass = string.match(line, "class ([^:%s]+)%s*%:?")
		if selectedClass then
			break
		end
	end

	if opts.selectedTests then
		local vstart = vim.fn.getpos("'<")
		local vend = vim.fn.getpos("'>")
		local lineStart = vstart[2]
		local lineEnd = vend[2]

		for i = lineStart, lineEnd do
			local test = string.match(lines[i], "func (test[^%s%(]+)")
			if test then
				table.insert(selectedTests, {
					name = test,
					class = selectedClass,
				})
			end
		end
	elseif opts.currentTest then
		local winnr = vim.api.nvim_get_current_win()
		local currentLine = vim.api.nvim_win_get_cursor(winnr)[1]

		for i = currentLine, 1, -1 do
			local test = string.match(lines[i], "func (test[^%s%(]+)")
			if test then
				table.insert(selectedTests, {
					name = test,
					class = selectedClass,
				})
				break
			end
		end
	elseif opts.failingTests and testReport.failedTestsCount > 0 then
		for _, testsPerClass in pairs(testReport.tests) do
			for _, test in ipairs(testsPerClass) do
				if not test.success then
					table.insert(selectedTests, {
						name = test.name,
						class = test.class,
					})
				end
			end
		end
	end

	return selectedClass, selectedTests
end

function M.run_selected_tests(opts)
	local selectedClass, selectedTests = find_tests(opts)

	appdata.create_app_dir()
	config.load_settings()
	local testOpts = {
		destination = config.settings().destination,
		projectCommand = config.settings().projectCommand,
		scheme = config.settings().scheme,
		testPlan = config.settings().testPlan,
	}

	vim.print("Building...")
	xcode.list_tests(testOpts, function(tests)
		local testsToRun = {}

		for _, test in ipairs(tests) do
			if opts.currentClass and test.class == selectedClass then
				table.insert(testsToRun, test.classId)
				break
			end

			if not opts.currentClass then
				local matchingTest = util.find(selectedTests, function(val)
					return val.class == test.class and val.name == test.name
				end)

				if matchingTest then
					table.insert(testsToRun, test.testId)
					if #testsToRun == #selectedTests then
						break
					end
				end
			end
		end

		vim.print("Discovered tests: " .. vim.inspect(testsToRun))

		if next(testsToRun) then
			M.run_tests(testsToRun)
		else
			vim.print("Tests not found")
		end
	end)
end

function M.configure_project()
	appdata.create_app_dir()

	require("xcodebuild.pickers").select_project(function()
		require("xcodebuild.pickers").select_scheme(function()
			require("xcodebuild.pickers").select_testplan(function()
				require("xcodebuild.pickers").select_destination(function()
					vim.defer_fn(function()
						vim.print("xcodebuild configuration has been saved!")
					end, 100)
				end)
			end)
		end)
	end)
end

return M