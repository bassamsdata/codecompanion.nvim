#!/usr/bin/env -S nvim -l

-- Automated tool testing runner for CodeCompanion
-- Usage: nvim -l scripts/tool_testing/run_tests.lua [options]
-- Options:
--   --adapter=<name>  Run only specific adapter
--   --model=<name>    Run only specific model
--   --scenario=<name> Run only specific scenario
--   --delay=<ms>      Delay between scenarios in milliseconds (default: 0)
--   --parallel        Run tests in parallel
--   --verbose         Show detailed output

-- Better usage in test.sh wrapper for proper terminal rendering

-- Setup runtime path to find CodeCompanion and dependencies
local function setup_runtimepath()
  local script_path = debug.getinfo(1, "S").source:sub(2)
  local plugin_root = vim.fn.fnamemodify(script_path, ":h:h:h")

  -- Add plugin root to runtimepath if not already there
  local rtp = vim.opt.runtimepath:get()
  local found = false
  for _, path in ipairs(rtp) do
    if path == plugin_root then
      found = true
      break
    end
  end

  if not found then
    vim.opt.runtimepath:prepend(plugin_root)
  end

  -- Load from lazy.nvim data directory
  local lazy_root = vim.fn.stdpath("data") .. "/lazy"
  if vim.fn.isdirectory(lazy_root) == 1 then
    -- Add required dependencies
    local deps = {
      "codecompanion.nvim",
      "plenary.nvim",
      "nvim-treesitter",
    }

    for _, dep in ipairs(deps) do
      local dep_path = lazy_root .. "/" .. dep
      if vim.fn.isdirectory(dep_path) == 1 then
        vim.opt.runtimepath:prepend(dep_path)
      end
    end
  end

  -- Also try from .repro path (for minimal init)
  local repro_path = ".repro/plugins"
  if vim.fn.isdirectory(repro_path) == 1 then
    local deps = { "codecompanion.nvim", "plenary.nvim", "nvim-treesitter" }
    for _, dep in ipairs(deps) do
      local dep_path = repro_path .. "/" .. dep
      if vim.fn.isdirectory(dep_path) == 1 then
        vim.opt.runtimepath:prepend(dep_path)
      end
    end
  end
end

setup_runtimepath()

local function load_config()
  local config_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/config.lua"
  local config = dofile(config_path)

  -- Try to load local config overrides
  local local_config_path = config_path:gsub("%.lua$", ".local.lua")
  if vim.fn.filereadable(local_config_path) == 1 then
    local local_config = dofile(local_config_path)
    config = vim.tbl_deep_extend("force", config, local_config)
  end

  return config
end

local function register_custom_adapters(config)
  local log_messages = {}

  if not config.adapter_definitions or vim.tbl_isempty(config.adapter_definitions) then
    return log_messages
  end

  local cc_config = require("codecompanion.config")
  local adapters = require("codecompanion.adapters")

  for adapter_name, adapter_def in pairs(config.adapter_definitions) do
    if not adapter_def.extends then
      table.insert(log_messages, {
        level = "ERROR",
        msg = string.format("Custom adapter '%s' missing 'extends' field", adapter_name),
      })
      goto continue
    end

    -- Check if base adapter exists
    local base_adapter = cc_config.adapters.http[adapter_def.extends]
    if not base_adapter then
      table.insert(log_messages, {
        level = "ERROR",
        msg = string.format("Custom adapter '%s' extends unknown adapter '%s'", adapter_name, adapter_def.extends),
      })
      goto continue
    end

    -- Build custom adapter config
    local custom_config = {
      name = adapter_name,
      formatted_name = adapter_name:gsub("^%l", string.upper):gsub("_(%l)", function(c)
        return " " .. c:upper()
      end),
    }

    -- Copy fields from definition
    if adapter_def.url then
      custom_config.url = adapter_def.url
    end
    if adapter_def.env then
      custom_config.env = adapter_def.env
    end

    -- Override env with API key from config if provided
    if config.api_keys and config.api_keys[adapter_name] then
      local api_key = config.api_keys[adapter_name]
      if type(api_key) == "function" then
        local key_ok, key_value = pcall(api_key)
        if key_ok and key_value then
          custom_config.env = custom_config.env or {}
          custom_config.env.api_key = key_value
        end
      elseif type(api_key) == "string" and api_key ~= "" then
        custom_config.env = custom_config.env or {}
        custom_config.env.api_key = api_key
      end
    end

    if adapter_def.headers then
      custom_config.headers = adapter_def.headers
    end
    if adapter_def.handlers then
      custom_config.handlers = adapter_def.handlers
    end
    if adapter_def.schema then
      custom_config.schema = adapter_def.schema
    end
    if adapter_def.opts then
      custom_config.opts = adapter_def.opts
    end
    if adapter_def.roles then
      custom_config.roles = adapter_def.roles
    end
    if adapter_def.features then
      custom_config.features = adapter_def.features
    end

    local ok, custom_adapter = pcall(function()
      return adapters.extend(adapter_def.extends, custom_config)
    end)

    if ok and custom_adapter then
      -- Register in CodeCompanion config
      cc_config.adapters.http[adapter_name] = custom_adapter
      table.insert(log_messages, {
        level = "INFO",
        msg = string.format("✓ Registered custom adapter: %s (extends %s)", adapter_name, adapter_def.extends),
      })
    else
      table.insert(log_messages, {
        level = "ERROR",
        msg = string.format("Failed to create custom adapter '%s': %s", adapter_name, tostring(custom_adapter)),
      })
    end

    ::continue::
  end

  return log_messages
end

local function validate_adapter_exists(adapter_name)
  local cc_config = require("codecompanion.config")

  -- Check if adapter exists in built-in adapters
  if cc_config.adapters.http[adapter_name] or cc_config.adapters.acp[adapter_name] then
    return true, nil
  end

  -- Get list of available adapters
  local available = {}
  for name, _ in pairs(cc_config.adapters.http) do
    table.insert(available, name)
  end
  for name, _ in pairs(cc_config.adapters.acp) do
    table.insert(available, name)
  end
  table.sort(available)

  local error_msg = string.format(
    "Adapter '%s' not found.\n\nAvailable built-in adapters:\n  %s\n\nTo use custom adapters, define them in config.adapter_definitions",
    adapter_name,
    table.concat(available, ", ")
  )

  return false, error_msg
end

local function parse_args()
  local args = {
    adapter = nil,
    model = nil,
    scenario = nil,
    parallel = false,
    verbose = false,
    delay = 0,
  }

  for _, arg in ipairs(vim.v.argv) do
    if arg:match("^%-%-adapter=") then
      args.adapter = arg:match("^%-%-adapter=(.+)$")
    elseif arg:match("^%-%-model=") then
      args.model = arg:match("^%-%-model=(.+)$")
    elseif arg:match("^%-%-scenario=") then
      args.scenario = arg:match("^%-%-scenario=(.+)$")
    elseif arg:match("^%-%-delay=") then
      args.delay = tonumber(arg:match("^%-%-delay=(.+)$")) or 0
    elseif arg == "--parallel" then
      args.parallel = true
    elseif arg == "--verbose" then
      args.verbose = true
    end
  end

  return args
end

local function setup_output_dir(config)
  local dir = config.output.results_dir
  vim.fn.mkdir(dir, "p")
  return dir
end

local function log(msg, level, verbose_only)
  level = level or "INFO"
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")

  -- Skip verbose-only messages if not in verbose mode
  if verbose_only and not _G._test_verbose then
    return
  end

  local level_str = level
  if level == "PASS" then
    level_str = "✓ PASS"
  elseif level == "FAIL" then
    level_str = "✗ FAIL"
  elseif level == "ERROR" then
    level_str = "✗ ERROR"
  elseif level == "INFO" then
    level_str = "INFO"
  elseif level == "SUCCESS" then
    level_str = "✓ SUCCESS"
  end

  print(string.format("[%s] %s: %s", timestamp, level_str, msg))
end

local function save_result(results_dir, adapter_name, scenario_name, result)
  -- Sanitize adapter name to replace all non-alphanumeric chars with underscores
  local sanitized_adapter = adapter_name:gsub("[^%w]", "_")

  local filename = string.format(
    "%s/%s_%s_%s.json",
    results_dir,
    os.date("%Y%m%d_%H%M%S"),
    sanitized_adapter,
    scenario_name:gsub("%s+", "_")
  )

  local content = vim.json.encode(result)
  vim.fn.writefile(vim.split(content, "\n"), filename)
  return filename
end

local function run_scenario_for_adapter(adapter_config, scenario, config, args)
  log(
    string.format("Testing %s/%s with scenario: %s", adapter_config.name, adapter_config.model, scenario.name),
    "INFO"
  )

  local result = {
    adapter = adapter_config.name,
    model = adapter_config.model,
    scenario = scenario.name,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    success = false,
    error = nil,
    validation = nil,
    duration_ms = 0,
    messages = {},
  }

  local start_time = vim.uv.hrtime()

  -- Setup test scenario
  local context = {}
  local setup_ok, setup_result = pcall(scenario.setup)
  if not setup_ok then
    result.error = "Setup failed: " .. tostring(setup_result)
    result.duration_ms = (vim.uv.hrtime() - start_time) / 1000000
    return result
  end
  context = setup_result or {}

  -- Initialize CodeCompanion
  local ok, codecompanion = pcall(require, "codecompanion")
  if not ok then
    result.error = "Failed to load CodeCompanion: " .. tostring(codecompanion)
    log(result.error, "ERROR")
    if scenario.cleanup then
      pcall(scenario.cleanup, context)
    end
    result.duration_ms = (vim.uv.hrtime() - start_time) / 1000000
    return result
  end

  -- Create a test buffer for chat
  vim.cmd("enew")
  local bufnr = vim.api.nvim_get_current_buf()

  -- Initialize chat with adapter
  local chat_ok, chat = pcall(function()
    return codecompanion.chat({
      fargs = { adapter_config.name },
      auto_submit = false,
    })
  end)

  if not chat_ok or not chat then
    result.error = "Failed to create chat: " .. tostring(chat)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    if scenario.cleanup then
      pcall(scenario.cleanup, context)
    end
    result.duration_ms = (vim.uv.hrtime() - start_time) / 1000000
    return result
  end

  -- Apply the model to the chat (this updates adapter.schema.model.default and settings.model)
  if chat.apply_model then
    local apply_ok, apply_err = pcall(function()
      chat:apply_model(adapter_config.model)
    end)
    if not apply_ok then
      result.error = "Failed to apply model: " .. tostring(apply_err)
      vim.api.nvim_buf_delete(bufnr, { force = true })
      if scenario.cleanup then
        pcall(scenario.cleanup, context)
      end
      result.duration_ms = (vim.uv.hrtime() - start_time) / 1000000
      return result
    end
  end

  log(string.format("  Using model: %s", adapter_config.model), "INFO", true)

  -- Automatic tool approval
  vim.g.codecompanion_yolo_mode = true

  -- This is for tools
  local cc_config = require("codecompanion.config")

  -- Add tools to the chat from CodeCompanion config
  for _, tool_name in ipairs(scenario.tools) do
    local tool_config = cc_config.strategies.chat.tools and cc_config.strategies.chat.tools[tool_name]
    if not tool_config then
      result.error = "Tool not found in config: " .. tool_name
      vim.api.nvim_buf_delete(bufnr, { force = true })
      if scenario.cleanup then
        pcall(scenario.cleanup, context)
      end
      result.duration_ms = (vim.uv.hrtime() - start_time) / 1000000
      return result
    end

    local tool_added, add_err = pcall(function()
      chat.tool_registry:add(tool_name, tool_config)
    end)
    if not tool_added then
      result.error = "Failed to add tool: " .. tool_name .. " - " .. tostring(add_err)
      vim.api.nvim_buf_delete(bufnr, { force = true })
      if scenario.cleanup then
        pcall(scenario.cleanup, context)
      end
      result.duration_ms = (vim.uv.hrtime() - start_time) / 1000000
      return result
    end
  end

  -- Generate prompt with tool references using @{tool_name} syntax
  local prompt = scenario.prompt(context)

  -- Send message and wait for completion
  local completed = false
  local tool_calls = {}
  local response_content = ""
  local tool_executed = false

  -- Track tool usage and execution by monitoring messages after submit
  local function capture_tool_data()
    for _, msg in ipairs(chat.messages) do
      if msg.role == "assistant" and msg.tools then
        if msg.tools.calls then
          for _, tool_call in ipairs(msg.tools.calls) do
            local already_captured = false
            for _, captured in ipairs(tool_calls) do
              if captured.id == tool_call.id then
                already_captured = true
                break
              end
            end
            if not already_captured then
              table.insert(tool_calls, {
                id = tool_call.id,
                name = tool_call["function"] and tool_call["function"].name or "unknown",
                arguments = tool_call["function"] and tool_call["function"].arguments or "{}",
              })
            end
          end
        end
      end
      if msg.role == "tool" then
        tool_executed = true
      end
      if msg.role == "assistant" and msg.content then
        if not response_content:find(msg.content, 1, true) then
          response_content = response_content .. msg.content
        end
      end
    end
  end

  -- Add user message
  chat:add_message({
    role = "user",
    content = prompt,
  })

  -- Submit and wait for completion
  local submit_ok, submit_err = pcall(function()
    chat:submit()

    -- Wait for completion (with timeout)
    local timeout = adapter_config.timeout or 30000
    local wait_time = 0
    local interval = 200

    while wait_time < timeout do
      vim.wait(interval)
      wait_time = wait_time + interval

      -- Capture tool data on each iteration
      capture_tool_data()

      -- Check completion status
      if chat.current_request then
        local status = chat.current_request.status and chat.current_request.status()
        if status == "success" then
          -- Wait a bit more for tool execution to complete
          vim.wait(1000)
          capture_tool_data()
          completed = true
          break
        elseif status == "error" then
          result.error = "Request returned error status"
          break
        end
      else
        -- No active request, might be done
        vim.wait(1000)
        capture_tool_data()
        completed = true
        break
      end
    end

    if not completed then
      result.error = "Timeout waiting for response (waited " .. wait_time .. "ms)"
    end
  end)

  if not submit_ok then
    result.error = "Submit failed: " .. tostring(submit_err)
  end

  -- Final capture of tool data
  capture_tool_data()

  -- Collect messages for debugging
  for _, msg in ipairs(chat.messages) do
    table.insert(result.messages, {
      role = msg.role,
      content = type(msg.content) == "string" and msg.content or vim.inspect(msg.content),
      tool_calls = msg.tools and msg.tools.calls or nil,
      _meta = msg._meta,
    })
  end

  -- Always validate results if we completed (even if no tools were detected)
  -- The tool might have executed successfully but we missed tracking it
  if completed then
    local validate_ok, validate_success, validation_details = pcall(scenario.validate, context)
    if validate_ok then
      -- Ensure success is always a boolean (validation might return truthy match results)
      result.success = not not validate_success
      result.validation = validation_details
      if not result.success and not result.error then
        result.error = "Validation failed - file was not modified as expected"
      elseif result.success then
        -- Clear any premature errors if validation passed
        result.error = nil
      end
    else
      result.success = false
      if not result.error then
        result.error = "Validation error: " .. tostring(validate_success)
      end
    end
  end

  -- Add diagnostic info if validation failed but tool was called
  if not result.success and #tool_calls > 0 then
    result.error = (result.error or "Unknown error")
      .. string.format(" (Tool called: %s, Executed: %s)", #tool_calls > 0, tool_executed)
  end

  result.tool_calls = tool_calls
  result.response_content = response_content
  result.duration_ms = (vim.uv.hrtime() - start_time) / 1000000

  -- Cleanup
  vim.g.codecompanion_yolo_mode = nil
  vim.api.nvim_buf_delete(bufnr, { force = true })
  if scenario.cleanup then
    pcall(scenario.cleanup, context)
  end

  return result
end

local function run_tests(config, args)
  log("Starting CodeCompanion Tool Tests", "INFO")
  log("================================", "INFO")

  local results_dir = setup_output_dir(config)
  log("Results directory: " .. results_dir, "INFO")

  -- Register custom adapters before running tests
  local registration_logs = register_custom_adapters(config)
  for _, log_entry in ipairs(registration_logs) do
    log(log_entry.msg, log_entry.level)
  end
  if #registration_logs > 0 then
    log("", "INFO") -- Empty line for spacing
  end

  -- Filter adapters
  local adapters_to_test = vim.tbl_filter(function(adapter)
    if not adapter.enabled then
      return false
    end
    if args.adapter and adapter.name ~= args.adapter then
      return false
    end
    return true
  end, config.adapters)

  -- Filter scenarios
  local scenarios_to_test = vim.tbl_filter(function(scenario)
    if args.scenario and scenario.name ~= args.scenario then
      return false
    end
    return true
  end, config.scenarios)

  -- Expand adapters with multiple models into separate test runs
  local test_runs = {}
  for _, adapter in ipairs(adapters_to_test) do
    -- Support both 'models' (array) and 'model' (single string)
    local models = adapter.models or (adapter.model and { adapter.model } or { "default" })
    for _, model in ipairs(models) do
      -- Filter by model if specified
      if not args.model or model:find(args.model, 1, true) then
        local adapter_copy = vim.tbl_deep_extend("force", {}, adapter)
        adapter_copy.model = model
        adapter_copy.models = nil -- Remove models array to avoid confusion
        table.insert(test_runs, adapter_copy)
      end
    end
  end

  log(string.format("Testing %d adapter+model combinations with %d scenarios", #test_runs, #scenarios_to_test), "INFO")

  local all_results = {}
  local summary = {
    total = 0,
    passed = 0,
    failed = 0,
    errors = 0,
  }

  -- Run tests
  for _, adapter in ipairs(test_runs) do
    -- Validate adapter exists before running any scenarios
    local adapter_valid, adapter_error = validate_adapter_exists(adapter.name)
    if not adapter_valid then
      -- Mark all scenarios for this adapter as errors
      for _, scenario in ipairs(scenarios_to_test) do
        summary.total = summary.total + 1
        summary.errors = summary.errors + 1

        log(string.format("%s/%s - %s: %s", adapter.name, adapter.model, scenario.name, adapter_error), "ERROR")

        table.insert(all_results, {
          adapter = adapter.name,
          model = adapter.model,
          scenario = scenario.name,
          timestamp = os.date("%Y-%m-%d %H:%M:%S"),
          success = false,
          error = adapter_error,
          validation = nil,
          duration_ms = 0,
          messages = {},
          tool_calls = {},
        })
      end
      goto next_adapter
    end

    for _, scenario in ipairs(scenarios_to_test) do
      summary.total = summary.total + 1

      local result = run_scenario_for_adapter(adapter, scenario, config, args)

      if result.success then
        summary.passed = summary.passed + 1
        log(
          string.format("%s/%s - %s (%.2fs)", adapter.name, adapter.model, scenario.name, result.duration_ms / 1000),
          "PASS"
        )
      elseif result.error then
        summary.errors = summary.errors + 1
        log(string.format("%s/%s - %s: %s", adapter.name, adapter.model, scenario.name, result.error), "ERROR")
      else
        summary.failed = summary.failed + 1
        log(string.format("%s/%s - %s", adapter.name, adapter.model, scenario.name), "FAIL")
      end

      -- Save detailed result (verbose only)
      if config.output.save_logs then
        local adapter_model_name = adapter.name .. "_" .. adapter.model:gsub("[^%w]", "_")
        local result_file = save_result(results_dir, adapter_model_name, scenario.name, result)
        result.result_file = result_file -- Save file path in result for failures command
        log("  Result saved to: " .. result_file, "INFO", true)
      end

      -- Show validation details (verbose only)
      if result.validation then
        log("  Validation: " .. vim.inspect(result.validation), "INFO", true)
      end
      if result.tool_calls and #result.tool_calls > 0 then
        log("  Tools called: " .. vim.inspect(result.tool_calls), "INFO", true)
      end

      table.insert(all_results, result)

      -- Add delay between scenarios if specified
      if args.delay > 0 and scenario ~= scenarios_to_test[#scenarios_to_test] then
        vim.wait(args.delay)
      end
    end

    ::next_adapter::
  end

  -- Print summary
  print("")
  log("================================", "INFO")
  log("Test Summary", "INFO")
  log("================================", "INFO")
  log(string.format("Total:  %d", summary.total), "INFO")
  log(string.format("Passed: %d", summary.passed), "INFO")
  log(string.format("Failed: %d", summary.failed), "INFO")
  log(string.format("Errors: %d", summary.errors), "INFO")
  log(string.format("Success Rate: %.1f%%", (summary.passed / summary.total) * 100), "INFO")

  -- Save summary
  local summary_file = results_dir .. "/summary_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
  vim.fn.writefile(vim.split(vim.json.encode({ summary = summary, results = all_results }), "\n"), summary_file)
  log("Summary saved to: " .. summary_file, "INFO", true)

  -- Exit code
  vim.cmd(string.format("cquit %d", summary.failed + summary.errors))
end

-- Main execution
local config = load_config()
local args = parse_args()

-- Override config with args
if args.parallel then
  config.concurrency.parallel = true
end
if args.verbose then
  config.output.verbose = true
  _G._test_verbose = true
else
  _G._test_verbose = false
end

-- Run tests
local ok, err = pcall(run_tests, config, args)
if not ok then
  log("Fatal error: " .. tostring(err), "FATAL")
  vim.cmd("cquit 1")
end
