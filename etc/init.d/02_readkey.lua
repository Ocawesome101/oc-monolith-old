-- keyboard input lolz --

local rk = {}
package.loaded.readkey = rk
local event = require("event")
local protect = require("protection").protect
local vt100 = require("vt100")

--local cx, cy

local buffer = ""
--[[
local function redraw()
end]]

function rk.read(amount)
  checkArg(1, amount, "number", "nil")
  local tmp
  if amount then
    if #buffer < amount then
      repeat
        coroutine.yield()
      until #buffer == amount
      tmp = buffer
      buffer = ""
      return tmp
    else
      tmp = buffer:sub(1, amount)
      buffer = buffer:sub(amount + 1)
      return tmp
    end
  else
    if not buffer:find("\n") then
      repeat
        coroutine.yield()
      until buffer:find("\n")
    end
    local nl = buffer:find("\n")
    tmp = buffer:sub(1, nl)
    buffer = buffer:sub(nl + 1)
    return tmp
  end
end

local function key(evt, addr, char, code)
  io.write("KEY")
  if char >= 32 and char <= 126 then
    buffer = buffer .. string.char(char)
    io.write(string.char(char))
  elseif char == 13 then
    buffer = buffer .. "\n"
    io.write("\n")
  elseif char == 8 then
    buffer = buffer:sub(1, -2)
    io.write("\8\27[K")
  end
end

--[[local function cursor_changed(evt, rs, nx, ny)
  if rs == "move" then
    cx, cy = nx, ny
  end
end]]

event.listen("key_down", key)
--event.listen("cursor_changed", cursor_changed)

protect(rk)
