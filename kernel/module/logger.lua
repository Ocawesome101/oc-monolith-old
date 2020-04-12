-- Logger --

local kernel      = {}
kernel.logger     = {}
kernel.logger.log = function()end
local y, w, h
if component.gpu and component.screen then
  component.gpu.bind(component.screen.address)
  if not screen.isOn() then
    screen.turnOn()
  end
  y, w, h =, 1, component.gpu.maxResolution()
  component.gpu.setResolution(w, h)
  function kernel.logger.log(...)
    local str = table.concat({...}, " ")
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
  kernel.logger.log(("="):rep(w // 2))
  local trace = debug.traceback(err, lvl):gsub("\t", "  "):gsub("stack traceback", "Call Trace")
  for line in trace:gmatch("[^\n]+") do
    kernel.logger.log(line)
  end
  kernel.logger.log(("="):rep(w // 2))
  kernel.logger.log("Kernel panic - not syncing: " .. err)
  while true do
    computer.pullSignal(0.1)
    computer.beep(500, 0.1)
  end
end
local old_error = error
_G.error = kernel.logger.panic -- for now, error == kernel panic
