-- This file is just for examples and proper first time testing
-- Configuration for automated tool testing
-- Copy this to config.local.lua and add API keys - calling test.sh setup will create that file

local M = {}

-- API Keys Configuration
-- Set these in config.local.lua or via environment variables
-- Can be strings, functions that return strings, or tables
M.api_keys = {
  openai = os.getenv("OPENAI_API_KEY"),
  anthropic = os.getenv("ANTHROPIC_API_KEY"),
  openrouter = os.getenv("OPENROUTER_API_KEY"),
  groq = os.getenv("GROQ_API_KEY"),
  copilot = nil, -- Uses token from Copilot plugin

  -- openai = function() return get_api_key("openai") end,
}

-- Custom Adapter Definitions
-- Define custom adapters that aren't built into CodeCompanion
-- These will be registered before tests run
M.adapter_definitions = {
  -- Example: OpenRouter adapter
  -- openrouter = {
  --   extends = "openai", -- Base adapter to extend from
  --   url = "https://openrouter.ai/api/v1/chat/completions",
  --   env = {
  --     api_key = "cmd:api-pass openrouter", -- or function() return get_api_key("openrouter") end
  --   },
  --   headers = {
  --     ["HTTP-Referer"] = "https://github.com/codecompanion-test",
  --     ["X-Title"] = "CodeCompanion Tool Testing",
  --   },
  --   schema = {
  --     model = {
  --       default = "openai/gpt-oss-120b",
  --     },
  --   },
  -- },
}

-- Adapters to test
-- Each adapter configuration with model(s) and tools to test
-- You can specify a single model or multiple models per adapter
M.adapters = {
  {
    name = "openai",
    enabled = true,
    models = { "gpt-4.1", "gpt-5-mini" }, -- Multiple models
    timeout = 30000, -- 30 seconds
  },
  -- {
  --   name = "anthropic",
  --   enabled = true,
  --   models = { "claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022" },
  --   timeout = 30000,
  -- },
  {
    name = "copilot",
    enabled = true, -- Requires Copilot setup
    models = { "gpt-4.1", "gpt-5-mini" }, -- Multiple models
    timeout = 30000,
  },
  -- Add custom adapters here (must be defined in adapter_definitions above)
  -- {
  --   name = "openrouter",
  --   enabled = true,
  --   models = { "qwen/qwen3-14b", "anthropic/claude-3.5-sonnet" },
  --   timeout = 30000,
  -- },
  -- {
  --   name = "groq",
  --   enabled = true,
  --   models = { "llama-3.1-70b-versatile", "llama-3.1-8b-instant" },
  --   timeout = 30000,
  -- },

  -- You can also use the old format with a single model:
  -- {
  --   name = "openai",
  --   enabled = true,
  --   model = "gpt-4o-mini", -- Single model (backward compatible)
  --   timeout = 30000,
  -- },
}

-- Test scenarios
M.scenarios = {
  {
    name = "Simple file edit",
    description = "Test basic insert_edit_into_file functionality",
    tools = { "insert_edit_into_file" },
    setup = function()
      -- Create test file
      local test_file = vim.fn.tempname() .. ".lua"
      vim.fn.writefile({
        "local M = {}",
        "",
        "function M.greet(name)",
        '  return "Hello, " .. name',
        "end",
        "",
        "return M",
      }, test_file)
      return { test_file = test_file }
    end,
    prompt = function(context)
      local content = table.concat(vim.fn.readfile(context.test_file), "\n")
      return string.format(
        [[Use @{insert_edit_into_file} to edit the file at `%s`.

Here is the current content:
```lua
%s
```

Changes needed:
1. Change the function name from `greet` to `welcome`
2. Change "Hello" to "Welcome"

DON'T ASK ME FOR PERMISSIONS , JUST DO IT AND USE THE TOOL]],
        context.test_file,
        content
      )
    end,
    validate = function(context)
      local content = vim.fn.readfile(context.test_file)
      local text = table.concat(content, "\n")
      local has_welcome_function = text:match("function M%.welcome")
      local has_welcome_text = text:match('"Welcome')
      local success = has_welcome_function and has_welcome_text

      return success,
        {
          has_welcome_function = has_welcome_function,
          has_welcome_text = has_welcome_text,
          file_content = text,
        }
    end,
    cleanup = function(context)
      if context.test_file then
        vim.fn.delete(context.test_file)
      end
    end,
  },
  {
    name = "Multiple edits",
    description = "Test multiple edits in single tool call",
    tools = { "insert_edit_into_file" },
    setup = function()
      local test_file = vim.fn.tempname() .. ".js"
      vim.fn.writefile({
        "const API_VERSION = 1;",
        "const MAX_RETRIES = 3;",
        "",
        "function fetchData() {",
        "  console.log('Fetching...');",
        "}",
      }, test_file)
      return { test_file = test_file }
    end,
    prompt = function(context)
      local content = table.concat(vim.fn.readfile(context.test_file), "\n")
      return string.format(
        [[Use @{insert_edit_into_file} to edit the file at `%s`.

Here is the current content:
```js
%s
```

Changes needed:
1. Change API_VERSION from 1 to 2
2. Change MAX_RETRIES from 3 to 5
3. Change console.log message to 'Loading data...'

Make all these changes in a single tool call with multiple edits.

DON'T ASK ME FOR PERMISSIONS, JUST DO IT]],
        context.test_file,
        content
      )
    end,
    validate = function(context)
      local content = table.concat(vim.fn.readfile(context.test_file), "\n")
      local has_v2 = content:match("API_VERSION = 2")
      local has_retry5 = content:match("MAX_RETRIES = 5")
      local has_loading = content:match("Loading data")

      return (has_v2 and has_retry5 and has_loading),
        {
          has_v2 = has_v2,
          has_retry5 = has_retry5,
          has_loading = has_loading,
          file_content = content,
        }
    end,
    cleanup = function(context)
      if context.test_file then
        vim.fn.delete(context.test_file)
      end
    end,
  },
  {
    name = "Tool group test",
    description = "Test using file tools together",
    tools = { "read_file", "insert_edit_into_file" },
    setup = function()
      local test_file = vim.fn.tempname() .. ".py"
      vim.fn.writefile({
        "def calculate(x, y):",
        "    return x + y",
      }, test_file)
      return { test_file = test_file }
    end,
    prompt = function(context)
      return string.format(
        [[First use @{read_file} to read the file `%s`, then use @{insert_edit_into_file} to change the calculate function to multiply (x * y) instead of add (x + y).

Make sure to read the file first to see the exact content before editing.]],
        context.test_file
      )
    end,
    validate = function(context)
      local content = table.concat(vim.fn.readfile(context.test_file), "\n")
      local has_multiply = content:match("x %* y") or content:match("x%*y")

      return has_multiply ~= nil, {
        has_multiply = has_multiply,
        file_content = content,
      }
    end,
    cleanup = function(context)
      if context.test_file then
        vim.fn.delete(context.test_file)
      end
    end,
  },
}

-- Output configuration
M.output = {
  -- Directory to save test results
  results_dir = vim.fn.stdpath("data") .. "/codecompanion_tests",
  -- Save full conversation logs
  save_logs = true,
  -- Show detailed output
  verbose = true,
}

-- Concurrency settings
M.concurrency = {
  -- Run adapters in parallel (true) or sequentially (false)
  parallel = false,
  -- Maximum concurrent tests
  max_concurrent = 3,
}

return M
