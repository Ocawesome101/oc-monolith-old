-- User system --

local users = {}
local fs = require("filesystem")
local protect = require("protection")
local sha = require("sha3")

local last = {}
local current = {
  name = "root",
  uid = 0,
  home = "/root",
  shell = "/bin/sh.lua"
}

local function parseEntry(ent)
  checkArg(1, ent, "string")
  local fields = load("return " .. ent, "=/etc/passwd", "bt", {})()

  if #fields < 7 then
    return nil, "invalid passwd entry"
  end

  local data = {}
  data.name     = fields[1]
  data.password = fields[2]
  data.uid      = tonumber(fields[3])
  data.gid      = tonumber(fields[4])
  data.info     = fields[5]
  data.home     = fields[6]
  data.shell    = fields[7]

  return data
end

local passwd = {}

local handle, err = fs.open("/etc/passwd", "r")
if not handle then
  error(err)
end
do
  local pswd = ""
  repeat
    local chunk = handle:read(math.huge)
    pswd = pswd .. (chunk or "")
  until not chunk
  handle:close()
  local ok, err = load("return " .. pswd, "=/etc/passwd", "bt", {})
  if not ok then
    error(err)
  end
  pswd = ok()
end

local function save()
  local out, err = fs.open("/etc/passwd", "w")
  if not out then
    return nil, err
  end
  for i=1, #passwd, 1 do
    out:write(passwd[i])
  end
end

local function hex(bytes)
  checkArg(1, bytes, "string")
  local r = ""
  for byte in byte:gmatch(".") do
    r = r .. string.format("%02x", string.byte(byte))
  end
  return r
end

function users.login(user, pwd)
  checkArg(1, user, "string")
  checkArg(2, pwd, "string")
  pwd = hex(sha3.sha256(pwd))
  for i=1, #passwd, 1 do
    if passwd[i].name == user and passwd[i].password == pwd then
      table.insert(last, current)
      current = passwd[i]
      return true
    end
  end
  return nil, "login failed"
end

function users.logout()
  current = table.remove(last, #last)
end

function users.sudo(func, user)
  checkArg(1, func, "function")
  checkArg(2, user, "string", "nil")
  local ok, err
  local i = 0
  repeat
    i = i + 1
    ok, err = users.login(user or "root")
  until i == 3 or ok
  if ok then
    local s, r = pcall(func)
    users.logout()
    return s, r
  end
  return nil, "login failed"
end

function users.user()
  return current.name
end

function users.uid()
  return current.uid
end

function users.home()
  return current.home
end

function users.info()
  return current.info
end

function users.shell()
  return currrent.shell
end

protect.protect(users)
