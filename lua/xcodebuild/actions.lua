---@mod xcodebuild.actions Actions
---@tag xcodebuild.api
---@brief [[
---This module is responsible for handling actions that the user can
---call programmatically. It is the main entry point to the plugin's API.
---
---The interface should stay relatively stable.
---@brief ]]

local helpers = require("xcodebuild.helpers")
local util = require("xcodebuild.util")
local pickers = require("xcodebuild.ui.pickers")
local notifications = require("xcodebuild.broadcasting.notifications")
local logsPanel = require("xcodebuild.xcode_logs.panel")
local coverage = require("xcodebuild.code_coverage.coverage")
local events = require("xcodebuild.broadcasting.events")
local device = require("xcodebuild.platform.device")
local testExplorer = require("xcodebuild.tests.explorer")
local testRunner = require("xcodebuild.tests.runner")
local projectBuilder = require("xcodebuild.project.builder")
local projectConfig = require("xcodebuild.project.config")
local projectManager = require("xcodebuild.project.manager")
local lsp = require("xcodebuild.integrations.lsp")

local M = {}

---Sends a notification with a small delay to fix some glitches.
---@param text string
local function defer_send(text)
  vim.defer_fn(function()
    notifications.send(text)
  end, 100)
end

---Updates the project settings and broadcasts the notification.
---@param callback function|nil
local function update_settings(callback)
  defer_send("Updating project settings...")
  projectConfig.update_settings(function()
    notifications.send("Project settings updated")
    events.project_settings_updated(projectConfig.settings)
    util.call(callback)
  end)
end

---Opens the project in Xcode.
function M.open_in_xcode()
  if helpers.validate_project() then
    vim.fn.system({ "open", projectConfig.settings.projectFile })
  end
end

---Opens the logs panel.
function M.open_logs()
  logsPanel.open_logs(false)
end

---Closes the logs panel.
function M.close_logs()
  logsPanel.close_logs()
end

---Toggles the logs panel.
function M.toggle_logs()
  logsPanel.toggle_logs()
end

---Shows the pickers with all available actions.
function M.show_picker()
  pickers.show_all_actions()
end

---Cancels all running actions.
function M.cancel()
  helpers.cancel_actions()
  notifications.send("Stopped")
end

---Shows configuration wizard.
function M.configure_project()
  helpers.cancel_actions()
  projectConfig.configure_project()
end

---Builds the project.
---@param callback fun(report: ParsedReport)|nil
function M.build(callback)
  helpers.cancel_actions()
  projectBuilder.build_project({}, callback)
end

---Starts clean build.
---@param callback fun(report: ParsedReport)|nil
function M.clean_build(callback)
  helpers.cancel_actions()
  projectBuilder.build_project({ clean = true }, callback)
end

---Builds the project for testing.
---@param callback fun(report: ParsedReport)|nil
function M.build_for_testing(callback)
  helpers.cancel_actions()
  projectBuilder.build_project({ buildForTesting = true }, callback)
end

---Builds and runs the project.
---@param callback fun(report: ParsedReport)|nil
function M.build_and_run(callback)
  helpers.cancel_actions()
  projectBuilder.build_and_run_app(false, callback)
end

---Cleans the derived data.
function M.clean_derived_data()
  projectBuilder.clean_derived_data()
end

---Launches the app.
---@param callback function|nil
function M.run(callback)
  helpers.cancel_actions()
  device.run_app(false, callback)
end

---Starts tests.
function M.run_tests()
  helpers.cancel_actions()
  testRunner.run_tests()
end

---Starts tests of the current target.
function M.run_target_tests()
  helpers.cancel_actions()
  testRunner.run_selected_tests({ currentTarget = true })
end

---Starts tests of the current class.
function M.run_class_tests()
  helpers.cancel_actions()
  testRunner.run_selected_tests({ currentClass = true })
end

---Starts test in the current function.
function M.run_func_test()
  helpers.cancel_actions()
  testRunner.run_selected_tests({ currentTest = true })
end

---Starts selected tests.
function M.run_selected_tests()
  helpers.cancel_actions()
  testRunner.run_selected_tests({ selectedTests = true })
end

---Starts tests that failed previously.
function M.run_failing_tests()
  helpers.cancel_actions()
  testRunner.run_selected_tests({ failingTests = true })
end

---Shows a pickers with failing snapshot tests.
function M.show_failing_snapshot_tests()
  testRunner.show_failing_snapshot_tests()
end

---Starts the pickers with project file selection.
---@param callback function|nil
function M.select_project(callback)
  helpers.cancel_actions()
  pickers.select_project(function()
    pickers.select_xcodeproj_if_needed(function()
      update_settings(callback)
    end, { close_on_select = true })
  end, { close_on_select = true })
end

---Starts the pickers with scheme selection.
---@param callback function|nil
function M.select_scheme(callback)
  defer_send("Loading schemes...")
  helpers.cancel_actions()

  pickers.select_xcodeproj_if_needed(function()
    pickers.select_scheme(nil, function()
      update_settings(callback)
    end, { close_on_select = true })
  end, { close_on_select = true })
end

---Starts the pickers with configuration selection.
---@param callback function|nil
function M.select_config(callback)
  defer_send("Loading schemes...")
  helpers.cancel_actions()

  pickers.select_xcodeproj_if_needed(function()
    pickers.select_config(function()
      update_settings(callback)
    end, { close_on_select = true })
  end, { close_on_select = true })
end

---Starts the pickers with test plan selection.
---@param callback fun(testPlan: string)|nil
function M.select_testplan(callback)
  defer_send("Loading test plans...")
  helpers.cancel_actions()
  pickers.select_testplan(callback, { close_on_select = true })
end

---Starts the pickers with device selection.
---@param callback function|nil
function M.select_device(callback)
  defer_send("Loading devices...")
  helpers.cancel_actions()
  pickers.select_destination(function()
    update_settings(callback)
  end, { close_on_select = true })
end

---Sends a notification with the current project settings.
function M.show_current_config()
  if not helpers.validate_project() then
    return
  end

  vim.defer_fn(function()
    notifications.send_project_settings(projectConfig.settings)
  end, 100)
end

---Installs the app on the device.
---@param callback function|nil
function M.install_app(callback)
  helpers.cancel_actions()
  device.install_app(callback)
end

---Uninstalls the app from the device.
---@param callback function|nil
function M.uninstall_app(callback)
  helpers.cancel_actions()
  device.uninstall_app(callback)
end

--- deprecated
---@private
function M.uninstall(callback) -- backward compatibility
  M.uninstall_app(callback)
end

---Boots the simulator.
---@param callback function|nil
function M.boot_simulator(callback)
  device.boot_simulator(callback)
end

-- Code Coverage

---Toggles the code coverage.
---@param isVisible boolean
function M.toggle_code_coverage(isVisible)
  coverage.toggle_code_coverage(isVisible)
end

---Shows the code coverage report.
function M.show_code_coverage_report()
  coverage.show_report()
end

---Jumps to the next coverage marker.
function M.jump_to_next_coverage()
  coverage.jump_to_next_coverage()
end

---Jumps to the previous coverage marker.
function M.jump_to_previous_coverage()
  coverage.jump_to_previous_coverage()
end

-- Test Explorer

---Shows the test explorer.
function M.test_explorer_show()
  testExplorer.show()
end

---Hides the test explorer.
function M.test_explorer_hide()
  testExplorer.hide()
end

---Toggles the test explorer.
function M.test_explorer_toggle()
  testExplorer.toggle()
end

---Runs the selected tests.
function M.test_explorer_run_selected_tests()
  testExplorer.run_selected_tests()
end

---Runs the last tests.
function M.test_explorer_rerun_tests()
  testExplorer.repeat_last_run()
end

-- Project Management

---Returns the project targets.
---@return string[]|nil
function M.get_project_targets()
  return projectManager.get_project_targets()
end

---Adds a file to the targets.
---@param filepath string
---@param targets string[]
function M.add_file_to_targets(filepath, targets)
  projectManager.add_file_to_targets(filepath, targets)
end

---Creates a new file and updates the project.
---It asks the user to input the name and select targets.
function M.create_new_file()
  projectManager.create_new_file()
end

---Adds the current file to the project.
function M.add_current_file()
  projectManager.add_current_file()
end

---Renames the current file.
---It asks the user for a new name.
function M.rename_current_file()
  projectManager.rename_current_file()
end

---Deletes the current file.
---It asks the user to confirm the action.
function M.delete_current_file()
  projectManager.delete_current_file()
end

---Creates a new group and updates the project.
---It asks the user to input the name.
function M.create_new_group()
  projectManager.create_new_group()
end

---Adds the group to the project.
function M.add_current_group()
  projectManager.add_current_group()
end

---Renames the current group.
---It asks the user for a new name.
function M.rename_current_group()
  projectManager.rename_current_group()
end

---Deletes the current group.
---It asks the user to confirm the action.
function M.delete_current_group()
  projectManager.delete_current_group()
end

---Shows a picker with targets of the current file.
function M.show_current_file_targets()
  projectManager.show_current_file_targets()
end

---Shows a picker to select the targets for the current file.
function M.update_current_file_targets()
  projectManager.update_current_file_targets()
end

---Shows all available actions for the project manager.
function M.show_project_manager_actions()
  projectManager.show_action_picker()
end

-- LSP

---Automatically fixes the current line if possible.
function M.quickfix_line()
  lsp.quickfix_line()
end

---Shows the code actions for the current line.
function M.show_code_actions()
  lsp.code_actions()
end

return M
