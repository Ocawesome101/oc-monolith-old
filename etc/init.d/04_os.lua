-- Quick wrapper around `os.spawn`, for proper stdio things --

local spawn = os.spawn

function os.spawn(func, name, handler, blacklist, env, owner, stdin, stdout)
  checkArg(1, func,      "function")
  checkArg(2, name,      "string")
  checkArg(3, handler,   "function", "nil")
  checkArg(4, blacklist, "table",    "nil")
  checkArg(5, env,       "table",    "nil")
  checkArg(6, owner,     "string",   "nil")
  checkArg(7, stdin,     "table",    "nil")
  checkArg(8, stdout,    "table",    "nil")
--[[  local stdin = stdin or io.stdin
  local stdout = stdout or io.stdout]]
  return spawn(func, name, handler, blacklist, env, owner, stdin, stdout)
end

--require("event").timer(0, function()require("tty").window.flip(1, 1, require("component").gpu)end, math.huge)
