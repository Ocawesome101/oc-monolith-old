-- Logger --

local kernel      = {}
kernel.logger     = {}
kernel.logger.log = function()end
local y, w, h
if component.gpu and component.screen then
  component.gpu.bind(component.screen.address)
  if not component.screen.isOn() then
    component.screen.turnOn()
  end
  y, w, h = 1, component.gpu.maxResolution()
  component.gpu.setResolution(w, h)
  component.gpu.fill(1, 1, w, h, " ")
  function kernel.logger.log(...)
    local str = table.concat({string.format("[%08f]", computer.uptime() - _START), ...}, " ")
    component.gpu.set(1, y, str)
    if y == h then
      component.gpu.copy(1, 1, w, h, 0, -1)
      component.gpu.fill(1, h, w, 1, " ")
    else
      y = y + 1
    end
  end
end
function kernel.logger.panic(err, lvl) -- kernel panics
  local level = lvl or 1
  local lines = {}
  local function writeinfo(str, log)
    if log then kernel.logger.log(str) end
    table.insert(lines, str)
  end
  local base = " crash " .. os.date() .. " "
  writeinfo(("="):rep((w // 4) - (#base // 2)) .. base .. ("="):rep((w // 4) - (#base // 2)), true)
  writeinfo("Kernel panic! " .. err, true)
  writeinfo("Kernel version: " .. _OSVERSION)
  while true do
    local info = debug.getinfo(level)
    if not info then break end
    writeinfo("  " .. level .. ":")
    kernel.logger.log("  At", info.what, info.namewhat, info.short_src)
    writeinfo("    name: " .. (info.name or info.short_src))
    local attributes = {
      "what: " .. info.what,
      "type: " .. info.namewhat,
      "src: " .. info.source:gsub("=", "")
    }
    if attributes[2] == "" then
      attributes[2] = "<main chunk>"
    end
    if info.currentline > 0 then
      attributes[#attributes + 1] = "line " .. info.currentline
    end
    if info.linedefined > 0 then
      attributes[#attributes + 1] = "defined " .. info.linedefined
    end
    if info.istailcall then
      attributes[#attributes + 1] = "is tail call"
    end
    if info.isvararg then
      attributes[#attributes + 1] = "is vararg"
    end
    attributes = table.concat(attributes, ", ")
    writeinfo("    attributes: " .. attributes)
    level = level + 1
  end
  local crash = component.filesystem.open("/crash.txt", "w")
  writeinfo("Detailed traceback written to /crash.txt", true)
  writeinfo(("="):rep(w // 2), true)
  for i=1, #lines, 1 do
    component.filesystem.write(crash, lines[i] .. "\n")
  end
  component.filesystem.close(crash)
  while true do
    computer.pullSignal(0.1)
    computer.beep(500, 0.1)
  end
end
local old_error = error
_G.error = kernel.logger.panic -- for now, error == kernel panic
