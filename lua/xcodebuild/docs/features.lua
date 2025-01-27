---@mod xcodebuild.features Features
---@brief [[
--- - Support for iOS, iPadOS, and macOS apps built using Swift.
--- - Project-based configuration.
--- - Project Manager to deal with project files without using Xcode.
--- - Test Explorer to visually present a tree with all tests and results.
--- - Built using official command line tools like `xcodebuild` and `xcrun simctl`.
--- - Actions to build, run, debug, and test apps on simulators and
---   physical devices.
--- - Buffer integration with test results
---   (code coverage, success & failure marks, duration, extra diagnostics).
--- - Code coverage report with customizable levels.
--- - Browser of failing snapshot tests with a diff preview (if you use
---   `swift-snapshot-testing`).
--- - Advanced log parser to detect all errors, warnings, and failing tests.
--- - `nvim-tree` integration that automatically reflects all file tree
---   operations and updates Xcode project file.
--- - `nvim-dap` helper functions to let you easily build, run, and debug apps.
--- - `nvim-dap-ui` integration with console window to show app logs.
--- - `lualine.nvim` integration to show selected device, test plan,
---   and other project settings.
--- - Picker with all available actions.
--- - Highly customizable (many config options, auto commands, highlights,
---   and user commands).
---
---Availability of features
---
--- |             | Device (iOS <17) | Device (iOS 17+) | via Network (<17 / 17+) | Simulator | MacOS |
--- | :---------: | :--------------: | :--------------: | :---------------------: | :-------: | :---: |
--- |    build    |        🛠️        |        ✅        |         ❌ / ✅         |    ✅     |  ✅   |
--- | (un)install |        🛠️        |        ✅        |         🛠️ / ✅         |    ✅     |  ❌   |
--- |   launch    |        🛠️        |        ✅        |         🛠️ / ✅         |    ✅     |  ✅   |
--- |  run tests  |        🛠️        |        ✅        |         ❌ / ✅         |    ✅     |  ✅   |
--- |    debug    |        🛠️        |       🔐 🛠️      |           ❌            |    ✅     |  ✅   |
--- | debug tests |        ❌        |        ❌        |           ❌            |    ✅     |  ✅   |
--- |  app logs   |        🪲         |       🪲         |          ❌            |    ✅     |  ❌   |
---
---
--- 🔐 - requires passwordless `sudo` permission to `tools/remote_debugger`
---      script (see |xcodebuild.sudo|).
---
--- 🛠️ - available if pymobiledevice3 is installed.
---
--- 🪲  - available while debugging.
---
---@brief ]]

local M = {}
return M
