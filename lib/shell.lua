-- shell lib --

local shell = {}

function shell.variables(str)
  checkArg(1, str, "string")
  for name in str:gmatch("%$([%w_]+)") do
    local got = os.getenv(name) or ""
    str = str:gsub(name, got)
  end
  return str
end

function shell.getPrompt(prompt)
  checkArg(1, prompt, "string", "nil")
  local prompt = prompt or os.getenv("PS1")
  return shell.variables(prompt)
end

return shell
