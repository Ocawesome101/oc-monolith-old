-- iniiiiiiiit --

local _ISTART = computer.uptime()
local _KSTART = computer.uptime() - kernel.starttime

local logger    = logger
local component = component
local computer  = computer

local init_cfg, err = filesystem.open("/etc/init.conf")
if not init_cfg then
  logger.panic(err)
end

local tmp = init_cfg:read(math.huge)
init_cfg:close()

local conf, err = load("return " .. tmp, "=/etc/init.conf", "bt", {})
if not conf then
  error(err)
end

conf = conf()

for i=1, #conf, 1 do
  local ent = conf[i]
  if ent.type == "script" then
    logger.log(ent.file)
    local ok, err = loadfile(ent.file)
    if not ok then
      logger.panic("error in " .. ent.file .. ": " .. err)
    end
    local stat, ret = pcall(ok)
    if not stat and ret then
      logger.panic("error in " .. ent.file .. ": " .. ret)
    end
  end
end

_G.logger = nil

local rc = {}

local rcfg = {}

local handle, err = filesystem.open("/etc/rc.cfg")
if handle then
  local data = handle:read(math.huge)
  handle:close()
  local ok, err = load("return " .. data, "=/etc/rc.cfg", "bt", {})
  if ok then
    rcfg = ok()
  end
end

local function saveConfig()
  local str = require("serialization").serialize(rcfg)
  local handle, err = require("filesystem").open("/etc/rc.cfg", "w")
  if not handle then
    return nil, err
  end
  handle:write(str)
  handle:close()
  return true
end

function rc.start(svc)
  checkArg(1, svc, "string")
  if os.find("rc-" .. svc) then
    return nil, "service already running"
  end
  if fs.exists("/etc/rc.d/" .. svc .. ".lua") then
    local ok, err = loadfile("/etc/rc.d/" .. svc .. ".lua")
    if not ok then
      return nil, err
    end
    os.spawn(ok, "rc-" .. svc)
  else
    return nil, "service not found"
  end
end

function rc.enable(svc)
  checkArg(1, svc, "string")
  if fs.exists("/etc/rc.d/" .. svc .. ".lua") then
    rcfg[svc] = "/etc/rc.d/" .. svc .. ".lua"
    saveConfig()
  else
    return nil, "service not found"
  end
end

function rc.stop(svc)
  checkArg(1, svc, "string")
  if os.find("rc-" .. svc) then
    return os.kill(os.find("rc-" .. svc).pid)
  else
    return nil, "service not running"
  end
end

function rc.disable(svc)
  checkArg(1, svc, "string")
  rcfg[svc] = nil
  saveConfig()
end

while true do
  coroutine.yield()
end
