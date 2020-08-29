-- Logmein -- 

io.write("\27[2J")
print("This is the Monolith system. Welcome.")

local users = pcall(require, "users")

while true do
  io.write("localhost login: \27[0m")

  local rk = require("readkey")
  local name = rk.read()
  
  io.write("password: \27[8m")
  local pwd = rk.read()
  pwd = pwd:gsub("\n", "")
  io.write("\27[8m")

  local ok, err = users.login(name, password)
  if not ok then
    error(err)
  else
    local ok, err = loadfile(users.shell())
    if not ok then
      error(err)
    else
      local pid = os.spawn(ok, users.shell(), nil, nil, {}, users.user())
      repeat
        local info = os.find(require("users").shell())
      until not info
    end
  end
end
