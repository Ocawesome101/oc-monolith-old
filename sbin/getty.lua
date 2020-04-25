-- getty implementation --

local tty = require("tty")
local vt100 = require("vt100")
local rk = require("readkey")
local event = require("event")
local keyboard = require("keyboard")
local component = require("component")

local ttys = {}
local current = 0
local max = 3

local function spawn(num)
  local new = {}
  local w, h = component.gpu.getResolution()
  new.buffer = tty.new(w, h)
  new.gpu = component.gpu
  new.emu = vt100.emu(new.buffer)
  new.stdin = {
    read = function(self, amount)
      checkArg(1, amount, "number")
      return rk.read(amount)
    end
  }
  new.stdout = {
    write = function(self, data)
      checkArg(1, data, "string")
      self.emu(data)
    end
  }
  ttys[(num or #ttys + 1)] = new
end

local function loginOn(num)
  local login, err = loadfile("/sbin/login.lua")
  if not login then
    error(err)
  end
  print("Starting login on TTY" .. current)
  os.spawn(login, "/sbin/login.lua", function(err)print("ERROR IN LOGIN:", err)end, {interrupt=true}, {}, "root", ttys[current].stdin, ttys[current].stdout)
end

spawn(0)

local function key_down(evt, addr, char, code)
  if keyboard.isAltDown() then
    if keyboard.isKeyDown(keyboard.keys.right) then
      if not ttys[max] then
        current = #ttys + 1
        spawn()
      else
        if current == max then
          current = 0
        else
          current = current + 1
        end
      end
    elseif keyboard.isKeyDown(keyboard.keys.left) then
      if current == 0 then
        if not ttys[max] then
          spawn(max)
        end
        current = max
      else
        if current == 3 then
          current = 0
        else
          current = current - 1
        end
      end
    end
  end
end

local function init()
  loginOn(0)
end

event.listen("key_down", key_down)
init()

while true do
  event.pull(0.1)
--  ttys[current].buffer.flip(1, 1, ttys[current].gpu)
end
