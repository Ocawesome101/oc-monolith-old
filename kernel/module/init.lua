-- uuuuuuuuuuuuusersoaaaaaaaaaaace

local userspace = {
  _VERSION = _VERSION,
  _OSVERSION = _OSVERSION,
  pcall        = pcall,
  xpcall       = xpcall,
  rawget       = rawget,
  rawset       = rawset,
  rawequal     = rawequal,
  rawlen       = rawlen,
  rawequal     = rawequal,
  load         = load,
  setmetatable = setmetatable,
  getmetatable = getmetatable,
  assert       = assert,
  error        = old_error,
  ipairs       = ipairs,
  pairs        = pairs,
  type         = type,
  tostring     = tostring,
  tonumber     = tonumber,
  select       = select,
  next         = next,
  checkArg     = checkArg,
  computer     = setmetatable({
    pullSignal = function(timeout)
      checkArg(1, timeout, "number", "nil")
      return coroutine.yield(timeout)
    end
  }, { __index = computer }),
  kernel       = {
    name       = _KERNEL,
    compiled   = _DATE,
    compiler   = _COMPILER,
    compiledby = _USER,
    version    = _VER,
    patch      = _PATCH,
    variation  = _NAME
  },
  os           = setmetatable({}, { __index = os }),
  string       = setmetatable({}, { __index = string }),
  math         = setmetatable({}, { __index = math }),
  debug        = setmetatable({}, { __index = debug }),
  bit32        = setmetatable({}, { __index = bit32 }),
  table        = setmetatable({}, { __index = table }),
  unicode      = setmetatable({}, { __index = unicode }),
  component    = component,
  filesystem   = filesystem,
  coroutine    = setmetatable({}, { __index = coroutine })
}

local function loadfile(file, mode, env)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  checkArg(3, env, "table", "nil")
  
  local hand, err = kernel.filesystem.open(file, 'r')
  if not hand then
    return nil, err
  end

  local tmp = ""
  repeat
    local chunk = hand:read(math.huge)
    tmp = tmp .. (chunk or "")
  until not chunk

  return load(tmp, "=" .. file, mode or "bt", env or userspace)
end

userspace.loadfile = loadfile
userspace._G = userspace

local ok, err = loadfile("/sbin/init.lua", nil, userspace)
if not ok then kernel.logger.panic(err) end

os.spawn(ok, "/sbin/init.lua", kernel.logger.panic, {interrupt = true}, {}, "root")
os.start()
