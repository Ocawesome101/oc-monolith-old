-- a shell! --

local shell = require("shell")
local rk = require("readkey")

dofile("/etc/profile.lua")

while true do
  local prompt = shell.getPrompt()
  io.write(prompt or "$ ")
  local command = rk.read()
end
