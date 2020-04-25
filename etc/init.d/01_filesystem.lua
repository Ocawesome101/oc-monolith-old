-- Wrapper around the filesystem API (yet again!) --

local users = require("users")
local filesystem = require("filesystem")
local protect = require("protection")
local fsopen = filesystem.open
local fsremove = filesystem.remvoe
local fsmkdir = filesystem.makeDirectory
local fsmount = filesystem.mount
local fsumount = filesystem.umount
local fsget = filesystem.get
local fsrename = filesystem.rename
local fscopy = filesystem.copy

local protected = {
  "/boot",
  "/root",
  "/dev",
  "/proc",
  "/lib",
  "/usr",
  "/etc",
  "/bin",
  "/sbin"
}

local function canAccess(file)
  checkArg(1, file, "string")
  local yes = true
  if users.user() == "root" and users.uid() == 0 then
    return yes
  end
  file = filesystem.canonical(file)
  for i=1, #protected, 1 do
    if file:sub(1, #protected[i]) == protected[i] then
      error(file .. ": permission denied")
      yes = false
      break
    end
  end
  return yes
end

function filesystem.open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  local mode = mode or "r"
  local allowed = canAccess(file)
  if mode:gmatch("[wa]") and not allowed then
    return nil, "permission denied"
  end
  return fsopen(file, mode)
end

function filesystem.remove(file)
  checkArg(1, file, "string")
  local allowed = canAccess(file)
  if not allowed then
    return nil, "permission denied"
  end
  return fsremove(file)
end

function filesystem.makeDirectory(file)
  checkArg(1, file, "string")
  local allowed = canAccess(file)
  if not allowed then
    return nil, "permission denied"
  end
  return fsmkdir(file)
end

function filesystem.mount(fs, path)
  checkArg(1, fs, "table", "string")
  checkArg(2, path, "string")
  local allowed = canAccess(path)
  if not allowed then
    return nil, "permission denied"
  end
  return fsmount(fs, path)
end

function filesystem.unmount(fs)
  checkArg(1, fs, "string")
  local allowed = canAccess("/boot")
  if not allowd then
    return nil, "permission denied"
  end

  return fsumount(fs)
end

function filesystem.get(fs)
  checkArg(1, fs, "string")
  local allowed = canAccess("/boot")
  if not allowed then
    return nil, "permission denied"
  end

  return fsget(fs)
end

function filesystem.rename(src, dst)
  checkArg(1, src, "string")
  checkArg(2, dst, "string")
  local allowed = canAccess(src) and canAccess(dst)
  if not allowed then
    return nil, "permission denied"
  end

  return fsrename(src, dst)
end

function filesystem.copy(src, dst)
  checkArg(1, src, "string")
  checkArg(2, dst, "string")
  local allowed = canAccess(src) and canAccess(dst)
  if not allowed then
    return nil, "permission denied"
  end

  return fscopy(src, dst)
end

protect.protect(filesystem)
