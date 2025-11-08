# CodeCompanion Automated Tool Testing

Automated testing framework for validating CodeCompanion tools (like `insert_edit_into_file`) across multiple LLM adapters to ensure they work correctly.

## Table of Contents

- [What is This?](#what-is-this)
- [Quick Start](#quick-start-for-beginners)
- [Advanced Usage](#advanced-usage)
- [Configuration Guide](#configuration-guide)
- [Custom Adapters](#custom-adapters)
- [Creating Test Scenarios](#creating-test-scenarios)
- [Troubleshooting](#troubleshooting)
- [CI/CD Integration](#cicd-integration)

---

## What is This?

This testing framework automatically validates that CodeCompanion's tools (like file editing, code execution, etc.) work correctly with different LLM providers and models (OpenAI, Anthropic, Gemini, Groq, xAI, Qwen, Kimi, etc.).

**Why?** Because different LLMs have different capabilities and different API specs, and we need to ensure tools work across all of them.

---

## Quick Start

### Step 1: Clone and Navigate to the Repository

```bash
git clone https://github.com/olimorris/codecompanion.nvim
cd codecompanion.nvim
```

### Step 2: Set Up the Tool Testing Directory

Create the tool testing directory structure and copy the required files:

```bash
mkdir -p scripts/tool_testing
cd scripts/tool_testing
```

Ensure the following files are in this directory:
- `test_setup.lua`
- `test.sh`
- `run_tests.lua`
- `config.local.lua.example`
- `config.lua`

### Step 3: Make the Test Script Executable

```bash
chmod +x test.sh
```

### Step 4: Setup Configuration

Create personal config file:

```bash
./test.sh setup
```

This creates `config.local.lua` from the template.

### Step 5: Add Your API Keys

Edit `config.local.lua` and add your API keys:

```bash
# edit the file
# if you have API key env variable then you can skip to number 6 and 7 for now for quick testing and do
nvim config.local.lua
```

Update the `api_keys` section:


```lua
M.api_keys = {
  openai = "",
  anthropic = "",
  openrouter = "",
  xai = "",
  copilot = nil,
}
```

**OR** use environment variables in the terminal:

```bash
export OPENAI_API_KEY=""
export ANTHROPIC_API_KEY=""
export OPENROUTER_API_KEY=""
export XAI_API_KEY=""
```

### Step 6: Verify Setup

Check that everything is configured correctly:

```bash
./test.sh verify
```

You should see:
```
✓ SUCCESS: CodeCompanion loaded
✓ SUCCESS: All dependencies found
✓ SUCCESS: Adapter created successfully
✓ SUCCESS: Config loaded
✓ All checks passed!
```

### Step 7: Run Your First Test

Test with a specific adapter:

```bash
# inside the codecompanion dir
./test.sh run --adapter=openai
```


> 💡 **Note:**
>
> You can always check what commands are available by running:
>
> ```bash
> ./test.sh help
> ```
>
> This will display a list of all supported commands and usage information.


Or test all enabled adapters:

```bash
# inside the codecompanion dir
./test.sh run
```

**Expected output:**
```
✓ Using minimal setup...
[2025-11-07 14:30:00] INFO: Starting CodeCompanion Tool Tests
[2025-11-07 14:30:00] INFO: ✓ Registered custom adapter: openrouter (extends openai)
[2025-11-07 14:30:00] INFO: Testing 1 adapter+model combinations with 3 scenarios

[2025-11-07 14:30:05] ✓ PASS: openai/gpt-4o-mini - Simple file edit (4.2s)
[2025-11-07 14:30:12] ✓ PASS: openai/gpt-4o-mini - Multiple edits (6.8s)
[2025-11-07 14:30:18] ✓ PASS: openai/gpt-4o-mini - Tool group test (5.1s)

================================
Test Summary
================================
Total:  3
Passed: 3
Failed: 0
Errors: 0
Success Rate: 100.0%

✓ All tests passed
```

Then run those two commands:

```bash
# View latest test results
./test.sh results

# If Errors/failed calls, Show failures and related files for inspection
./test.sh failures

# NOTE: `jq` tool is recommended here and actually, it's very excellent for viewing JSON files in terminal
```


---

## Advanced Usage

### Using the Bash Script (Recommended)

The `test.sh` script provides convenient shortcuts:

#### Run Tests

```bash
# Test specific adapter
./test.sh run --adapter=openai

# Test specific model
./test.sh run --adapter=openai --model=gpt-4.1

# Test specific scenario
./test.sh run --scenario="Simple file edit"

# Add delay between scenarios (for rate limiting) - Gemini issue
./test.sh run --adapter=gemini --delay=2000  # 2 seconds

# Verbose output (shows validation details, tool calls, etc.)
./test.sh run --adapter=openai --verbose

# Test all enabled adapters
./test.sh run
```

#### Other Commands

```bash
# Verify setup and dependencies
./test.sh verify

# View latest test results
./test.sh results

# Show failures and related files for inspection
./test.sh failures

# Clean old test results
./test.sh clean

# Show help
./test.sh help

```

### Using Neovim Directly (Advanced)

If you prefer to run the Lua script directly:

```bash
# From the plugin root directory
cd /path/to/codecompanion.nvim

# Run all tests
nvim -l scripts/tool_testing/run_tests.lua

# With options
nvim -l scripts/tool_testing/run_tests.lua --adapter=openai --verbose

# Run from any directory (if in PATH)
cd ~/.config/nvim/plugins/codecompanion.nvim
nvim -l scripts/tool_testing/run_tests.lua --adapter=anthropic
```

**Available Options:**
- `--adapter=<name>` - Test only specific adapter
- `--model=<name>` - Test only specific model (partial match)
- `--scenario=<name>` - Test only specific scenario
- `--delay=<ms>` - Add delay between scenarios (milliseconds)
- `--verbose` - Show detailed output (validation, tool calls, logs)

---

## Configuration Guide

### Adapter Configuration

Edit `config.local.lua` to enable/disable adapters and specify models:

```lua
M.adapters = {
  -- Built-in adapters
  {
    name = "openai",
    enabled = true,
    models = { "gpt-4.1", "gpt-5-mini" },  -- Test multiple models
    timeout = 30000,  -- 30 seconds
  },
  {
    name = "anthropic",
    enabled = true,
    models = { "claude-sonnet-4-5-20250929", "claude-haiku-4-5-20251001" },
    timeout = 30000,
  },
  {
    name = "copilot",
    enabled = true,
    models = { "gpt-4.1", "gpt-5-mini", "grok-code-fast-1", "claude-haiku-4.5" },
    timeout = 30000,
  },

  -- Custom adapters (see next section)
  {
    name = "openrouter",
    enabled = true,
    models = { "qwen/qwen3-14b", "qwen/qwen3-coder-30b-a3b-instruct", },
    timeout = 30000,
  },
}
```

**Notes:**
- `enabled` - Set to `false` to skip this adapter
- `models` - Array of models to test (each model runs all scenarios)
- `timeout` - Maximum time to wait for LLM response (milliseconds)
- You can also use single `model` instead of `models` array

### Output Configuration

```lua
M.output = {
  verbose = true,        -- Show detailed logs
  save_logs = true,       -- Save JSON logs to disk
}
```


---

## Custom Adapters

For LLM providers not built into CodeCompanion (like OpenRouter, Groq, xAI), you can define custom adapters.

### Example: OpenRouter

```lua
M.adapter_definitions = {
  openrouter = {
    extends = "openai",  -- Base adapter
    url = "https://openrouter.ai/api/v1/chat/completions",
    env = {
      api_key = os.getenv("OPENROUTER_API_KEY") or "sk-or-...",
    },
    headers = {
      ["HTTP-Referer"] = "https://github.com/your-username",
      ["X-Title"] = "CodeCompanion Testing",
    },
    schema = {
      model = {
        default = "qwen/qwen3-coder-30b-a3b-instruct",
      },
    },
  },
}
```

### Example: xAI (Grok) Builtin xai adapter is old

```lua
M.adapter_definitions = {
  xai = {
    extends = "openai",
    url = "https://api.x.ai/v1/chat/completions",
    env = {
      api_key = os.getenv("XAI_API_KEY") or "xai-...",
    },
    handlers = {
      form_parameters = function(self, params, messages)
        local cleaned_params = vim.tbl_deep_extend("force", {}, params)
        -- Remove parameters Grok doesn't support
        cleaned_params.presence_penalty = nil
        cleaned_params.frequency_penalty = nil
        cleaned_params.logprobs = nil
        return cleaned_params
      end,
    },
    schema = {
      model = {
        default = "xai/grok-code-fast-1",
      },
    },
  },
}
```

**Key fields:**
- `extends` - Base adapter to inherit from (`"openai"`, `"anthropic"`, etc.)
- `url` - API endpoint URL
- `env.api_key` - API key (from env var or hardcoded)
- `headers` - Custom HTTP headers (optional)
- `handlers` - Custom request/response formatting (optional)
- `schema.model.default` - Default model to use

Once defined, add to the adapters list:

```lua
M.adapters = {
  {
    name = "openrouter",  -- Must match key in adapter_definitions
    enabled = true,
    models = { "qwen/qwen3-coder-30b-a3b-instruct" },
    timeout = 30000,
  },
}
```

---

## Creating Test Scenarios

Scenarios test specific tool functionality. Each scenario has 4 parts:

### Scenario Structure

````lua
{
  name = "Your test name",
  description = "What this tests",
  tools = { "insert_edit_into_file" },  -- Tools available to LLM

  -- 1. SETUP: Create test environment
  setup = function()
    local test_file = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({
      "local M = {}",
      "return M",
    }, test_file)
    return { test_file = test_file }  -- Return context for other functions
  end,

  -- 2. PROMPT: Instructions for the LLM
  prompt = function(context)
    local file_content = table.concat(vim.fn.readfile(context.test_file), "\n")
    return string.format([[
Use @{insert_edit_into_file} to edit the file at `%s`.

Current content:
```lua
%s
```

Add a function called `greet` that returns "Hello".

DON'T ASK FOR PERMISSIONS, JUST DO IT AND USE THE TOOL
]], context.test_file, file_content)
  end,

  -- 3. VALIDATE: Check if tool worked
  validate = function(context)
    local content = table.concat(vim.fn.readfile(context.test_file), "\n")
    local has_greet = content:match("function.*greet")
    local has_hello = content:match('"Hello"')

    local success = has_greet and has_hello
    local details = {
      has_greet = has_greet,
      has_hello = has_hello,
      file_content = content,
    }

    return success, details
  end,

  -- 4. CLEANUP: Remove test files
  cleanup = function(context)
    if context.test_file then
      vim.fn.delete(context.test_file)
    end
  end,
}
````

### Example Scenarios

See `config.lua` for built-in scenarios:

1. **Simple file edit** - Change function name and string
2. **Multiple edits** - Make multiple changes in one tool call
3. **Tool group test** - Use multiple tools together (read_file + insert_edit_into_file)

### Best Practices

1. **Use `vim.fn.tempname()`** - Creates unique temp files to avoid conflicts
2. **Include file content in prompt** - Helps LLM understand context
3. **Use `@{tool_name}` syntax** - Explicitly tell LLM which tool to use
4. **Validate specific changes** - Check exact strings/patterns, not just "file changed"
5. **Always cleanup** - Delete temp files in cleanup function
6. **Add "DON'T ASK FOR PERMISSIONS"** - Prevents LLM from asking for confirmation

---

## Output & Logs

### Console Output

```
Running CodeCompanion Tool Tests...
====================================

✓ Using minimal setup...
[2025-11-07 14:30:00] INFO: Starting CodeCompanion Tool Tests
[2025-11-07 14:30:00] INFO: ================================
[2025-11-07 14:30:00] INFO: Results directory: ~/.local/share/nvim/codecompanion_tests
[2025-11-07 14:30:00] INFO: ✓ Registered custom adapter: openrouter (extends openai)
[2025-11-07 14:30:00] INFO:
[2025-11-07 14:30:00] INFO: Testing 2 adapter+model combinations with 3 scenarios

[2025-11-07 14:30:05] ✓ PASS: openai/gpt-4.1 - Simple file edit (4.2s)
[2025-11-07 14:30:12] ✓ PASS: openai/gpt-4.1 - Multiple edits (6.8s)
[2025-11-07 14:30:18] ✗ FAIL: openai/gpt-4.1 - Tool group test
[2025-11-07 14:30:25] ✓ PASS: anthropic/claude-4.5-sonnet - Simple file edit (5.1s)

================================
Test Summary
================================
Total:  6
Passed: 5
Failed: 1
Errors: 0
Success Rate: 83.3%

✗ Tests failed (exit code: 1)
```

### Verbose Output

Use `--verbose` to see detailed information:

```bash
./test.sh run --adapter=openai --verbose
```

Shows:
- Tool calls made by the LLM
- Validation details
- File paths and saved result locations

```
[2025-11-07 14:30:05] ✓ PASS: openai/gpt-4.1 - Simple file edit (4.2s)
[2025-11-07 14:30:05] INFO:   Result saved to: ~/.local/share/nvim/codecompanion_tests/20251107_143005_openai_gpt_4o_mini_Simple_file_edit.json
[2025-11-07 14:30:05] INFO:   Validation: {
  has_welcome_function = "function M.welcome",
  has_welcome_text = '"Welcome',
  file_content = 'local M = {}\n\nfunction M.welcome(name)\n  return "Welcome, " .. name\nend\n\nreturn M'
}
[2025-11-07 14:30:05] INFO:   Tools called: [
  {
    id = "call_abc123",
    name = "insert_edit_into_file",
    arguments = '{"filepath": "/tmp/...", "edits": [...]}'
  }
]
```

### JSON Logs

Results are saved to `~/.local/share/nvim/codecompanion_tests/`:

**Individual test results:**
```
20251107_143005_openai_gpt_4o_mini_Simple_file_edit.json
20251107_143012_openai_gpt_4o_mini_Multiple_edits.json
```

**Summary file:**
```
summary_20251107_143000.json
```

**Example result file:**
```json
{
  "adapter": "openai",
  "model": "gpt-4.1",
  "scenario": "Simple file edit",
  "timestamp": "2025-11-07 14:30:05",
  "success": true,
  "duration_ms": 4234.5,
  "error": null,
  "validation": {
    "has_welcome_function": "function M.welcome",
    "has_welcome_text": "\"Welcome\"",
    "file_content": "local M = {}\n\nfunction M.welcome(name)..."
  },
  "tool_calls": [
    {
      "id": "call_abc123",
      "name": "insert_edit_into_file",
      "arguments": "{\"filepath\": \"/tmp/nvim.../0.lua\", \"edits\": [...]}"
    }
  ],
  "response_content": "I've updated the file...",
  "messages": [...]
}
```

### View Results

```bash
# View latest results with jq (if installed)
./test.sh results

# Show failures and related files for inspection
./test.sh failures

# Or manually
cat ~/.local/share/nvim/codecompanion_tests/summary_*.json | tail -1
```

---

## Troubleshooting

### "Failed to load CodeCompanion"

Make sure you're running from the plugin root directory:

```bash
cd /path/to/codecompanion.nvim
./scripts/tool_testing/test.sh run --adapter=openai
```

Or use absolute paths:

```bash
cd /path/to/codecompanion.nvim
nvim -l scripts/tool_testing/run_tests.lua
```

### "Adapter not found"

**For custom adapters:** Make sure you defined them in `adapter_definitions` before using them in `adapters`:

```lua
-- 1. First define the adapter
M.adapter_definitions = {
  myapi = { extends = "openai", url = "...", ... }
}

-- 2. Then use it
M.adapters = {
  { name = "myapi", enabled = true, models = {...} }
}
```

### "Invalid API Key" / 401 errors

1. Check your API key is correct:
```bash
echo $OPENAI_API_KEY
```

2. Or check `config.local.lua`:
```lua
M.api_keys = {
  openai = "sk-proj-...",  -- Make sure this is correct
}
```


### Tests timeout

Increase timeout in config:

```lua
M.adapters = {
  {
    name = "openai",
    enabled = true,
    models = { "gpt-4o" },
    timeout = 60000,  -- Increase to 60 seconds
  },
}
```

Or add delays between scenarios:

```bash
./test.sh run --adapter=gemini --delay=5000  # 5 second delay
```

### Validation fails but tool was called

Enable verbose mode to see what actually happened:

```bash
./test.sh run --adapter=openai --scenario="Simple file edit" --verbose
```

Check:
- Was the file actually modified?
- Did the LLM call the tool correctly?
- Is your validation logic correct?

### "permission denied: ./test.sh"

Make the script executable:

```bash
chmod +x test.sh
```

### Rate limiting / Too many requests

Add delays between scenarios:

```bash
./test.sh run --delay=3000  # 3 seconds between each scenario
```

Or reduce the number of models/scenarios being tested.

---

## Examples

### Test Multiple Models

```bash
# Test both GPT-4o and GPT-4o-mini
./test.sh run --adapter=openai
```

Config:
```lua
M.adapters = {
  {
    name = "openai",
    enabled = true,
    models = { "gpt-4.1", "gpt-5-mini" },  -- Both will be tested
    timeout = 30000,
  },
}
```

### Test Specific Model

```bash
# Only test models with "qwen" in the name
./test.sh run --model=qwen

# Only test GPT-5-mini
./test.sh run --adapter=openai --model=gpt-5-mini
```

### Rate Limit Friendly

```bash
# Add 5 second delay between scenarios
./test.sh run --adapter=gemini --delay=5000
```

### Debug Failed Test

```bash
# Run single scenario with verbose output
./test.sh run --scenario="Simple file edit" --verbose
```

---

## Best Practices

1. **Use environment variables for API keys** - Don't commit keys to git
2. **Test one adapter first** - Make sure setup works before running all
3. **Use `--verbose` for debugging** - See exactly what's happening
4. **Keep scenarios focused** - One tool/feature per scenario
5. **Add cleanup** - Always delete temp files
6. **Use realistic prompts** - Include file contents, clear instructions
7. **Validate specifically** - Check exact changes, not just "something changed"
8. **Set appropriate timeouts** - Complex tasks need more time
9. **Use delays for rate limiting** - Especially with free-tier APIs
