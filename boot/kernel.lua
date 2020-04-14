-- The most Linuxy Linux clone to ever Linux --


-- Kernel version --

local _KERNEL   = "Monolith"
local _DATE     = "Mon Apr 13 16:49:21 EDT 2020"
local _COMPILER = "luacomp " .. "1.2.0"
local _USER     = "ocawesome101" .. "@" .. "manjaro-pbp"
local _VER      = "1.0.0"
local _PATCH    = "0"
local _NAME     = "oc"
_G._OSVERSION   = ("%s version %s-%s-%s (%s) (%s) %s"):format(_KERNEL, _VER, _PATCH, _NAME, _USER, _COMPILER, _DATE)
local _START    = computer.uptime()


-- Initial component setup --

setmetatable(component, {
  __index = function(tbl, k)
    local comp = component.list(k)()
    if not comp then
      return nil, "no such component"
    end
    tbl[k] = component.proxy(comp)
    return component.proxy(comp)
  end
})

component.filesystem = component.proxy(computer.getBootAddress())
component.tmpfs      = component.proxy(computer.tmpAddress())

function component.address()
  -- Generate a component address. Definitely not copied from OpenOS. Nope. No, siree.
  local s = {4,2,2,2,6}
  local addr = ""
  local p = 0

  for _,_s in ipairs(s) do
    if #addr > 0 then
      addr = addr .. "-"
    end
    for _=1, _s, 1 do
      local b = math.random(0, 255)
      if p == 6 then
        b = (b & 0x0F) | 0x40
      elseif p == 8 then
        b = (b & 0x3F) | 0x80
      end
      addr = addr .. ("%02x"):format(b)
      p = p + 1
    end
  end
  return addr
end


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
    writeinfo("    name: " .. info.short_src)
    local attributes = {
      "what=" .. info.what,
      "type=" .. info.namewhat,
      "src=" .. info.source:gsub("=", "")
    }
    if attributes[2] == "" then
      attributes[2] = "<main chunk>"
    end
    if info.currentline > 0 then
      attributes[#attributes + 1] = "line=" .. info.currentline
    end
    if info.linedefined > 0 then
      attributes[#attributes + 1] = "defined=" .. info.linedefined
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

kernel.logger.log("Booting Linux on physical CPU 0x893fc8d [" .. _VERSION .. "]")
kernel.logger.log(_OSVERSION)
kernel.logger.log("Machine model: MightyPirates GmbH & Co. KG Blocker")
kernel.logger.log("Memory: " .. computer.freeMemory() // 1024 .. "K/" .. computer.totalMemory() // 1024 .. "K free")

-- Filesystem things --

kernel.filesystem = {}

kernel.logger.log("Initializing hierarchical VFS")

do
  local filesystem = {}
  local mtab       = {name = "/", proxy = component.filesystem, children = {}, not_unmountable = true}
  filesystem.fstab = {}

  local function split(path)
    local parts = {}
    for part in path:gmatch("[^\\/]+") do
      local current, up = part:find("^%.?%.$") -- I have no idea what "^%.?%.$" does. At all.
      if current then
        if up == 2 then
          table.remove(parts)
        end
      else
        table.insert(parts, part)
      end
    end
    return parts
  end

  local function find(path, create, proxy, no_unmount)
    checkArg(1, path, "string")
    checkArg(2, create, "boolean", "nil")
    checkArg(3, proxy, "table", "nil")
    checkArg(4, no_unmount, "boolean", "nil")
    local checked = {}
    local parts   = split(path)
    local parents = {}
    local current = mtab
    local index   = 1
    if mtab.proxy.exists(path) then
      return mtab, path
    end
    while index <= #parts do
      local part = parts[index]
      if current.children[part] then
        if index == #parts then
          return current.children[part], table.concat(parts, "/", index)
        else
          current = current.children[part]
        end
      elseif create and index == #parts then
        if not proxy then
          return nil, "no proxy provided"
        end
        current.children[part] = {name = part, proxy = proxy, parent = current, children = {}, not_unmountable = no_unmount}
        filesystem.fstab[path] = proxy
      else
        return nil, "no such file or directory"
      end
    end
  end

  function filesystem.mount(fs, path)
    checkArg(1, fs, "string", "table")
    checkArg(2, path, "string")
    if type(fs) == "table" then
      return find(path, true, fs)
    else
      local proxy = component.proxy(fs)
      if not proxy then
        return nil, "invalid filesystem"
      end
      return find(path, true, proxy)
    end
  end

  function filesystem.umount(fs)
    checkArg(1, fs, "string", "table")
    if type(fs) == "table" then
      for k, v in pairs(mtab) do
        if v.proxy == fs then
          if #v.children > 0 then
            return nil, "cannot perform recursive unmounting"
          elseif v.not_unmountable then
            return nil, "filesystem is not unmountable"
          else
            mtab[k] = nil
          end
        end
      end
    elseif type(fs) == "string" then
      local node, path = find(fs)
      if node then
        node = nil
      else
        return nil, "filesystem is not mounted"
      end
    end
    return true
  end

  kernel.logger.log("setting up filesystem interfaces")

  function filesystem.canonical(path)
    checkArg(1, path, "string")
    return "/" .. table.concat(split(path), "/")
  end

  function filesystem.segments(path)
    checkArg(1, path, "string")
    return split(path)
  end

  function filesystem.concat(...)
    local args = {...}
    for i=1, #args, 1 do
      checkArg(i, args[i], "string")
    end
    return filesystem.canonical(table.concat(args, "/"))
  end

  function filesystem.path(path)
    checkArg(1, path, "string")
    local segments = split(path)
    table.remove(segments, #segments)
    return filesystem.canonical(table.concat(segments, "/"))
  end

  function filesystem.name(path)
    checkArg(1, path, "string")
    local segments = split(path)
    return segments[#segments]
  end

  function filesystem.mounts()
    local mts = {}
    for path, proxy in pairs(filesystem.fstab) do
      mts[#mts + 1] = {proxy, path}
    end

    return setmetatable(mts, {__call = function()
      local tmp = table.remove(mts, 1)
      if tmp then
        return table.unpack(tmp)
      end
    end})
  end

  function filesystem.isLink()
    return false
  end

  function filesystem.link()
    error("linking is not implemented")
  end

  function filesystem.get(path)
    checkArg(1, path, "string")
    local node, path = find(path)
    if node then
      return node, path
    else
      return nil, "filesystem not found"
    end
  end

  function filesystem.exists(path)
    checkArg(1, path, "string")
    local node, path = find(path)
    if not node then
      return false
    end
    return node.proxy.exists(path)
  end

  function filesystem.size(path)
    checkArg(1, path, "string")
    local node, path = find(path)
    if not node or not node.proxy.exists(path) then
      return nil, "no such file or directory"
    end
    return node.proxy.size(path)
  end

  function filesystem.isDirectory(path)
    checkArg(1, path, "string")
    local node, path = find(path)
    if not node or not node.proxy.exists(path) then
      return nil, "no such file or directory"
    end
    return node.proxy.isDirectory(path)
  end

  function filesystem.lastModified(path)
    checkArg(1, path, "string")
    local node, path = find(path)
    if not node or not node.proxy.exists(path) then
      return nil, "no such file or directory"
    end
    return node.proxy.lastModified(path)
  end

  function filesystem.list(path)
    checkArg(1, path, "string")
    local files = {}
    local node, path = find(path)
    if not node or not node.proxy.exists(path) then
      return nil, "no such file or directory"
    end

    if node.proxy.isDirectory(path) then
      files = node.proxy.list(path)
    else
      files = {path}
    end
    setmetatable(files, {__call = function()
      local tmp = next(files)
      if tmp then
        return tmp
      end
    end})
  end

  function filesystem.makeDirectory(path)
    checkArg(1, path, "string")
    local node, path = find(path)
    if not node then
      return nil, "no such file or directory"
    end

    return node.proxy.makeDirectory(path)
  end

  function filesystem.remove(path)
    checkArg(1, path, "string")
    local node, path = find(path)
    if not node or not node.proxy.exists(path) then
      return nil, "no such file or directory"
    end

    return node.proxy.remove(path)
  end

  function filesystem.open(path, mode)
    checkArg(1, path, "string")
    checkArg(2, mode, "string", "nil")
    local mode = mode or "r"
    if not filesystem.exists(path) and not mode:match("[wa]") then
      return nil, "no such file or directory"
    end

    local node, path = find(path)
    if not node or not node.proxy.exists(path) then
      return nil, "no such file or directory"
    end

    local source = node.proxy.open(path)
    if not source then
      return nil, "no such file or directory"
    end

    local handle = {
      mode   = {},
      file   = source,
      proxy  = node.proxy,
      closed = false
    }
    for char in mode:gmatch(".") do
      handle.mode[char] = true
    end
    if handle.mode.a then
      handle.mode[w] = true
    end

    function handle:read(amount)
      checkArg(1, amount, "number")
      if not self.mode.r then
        return nil, "file not opened for reading"
      end
      if self.closed then
        return nil, "cannot read from closed file"
      end
      return self.proxy.read(self.file, amount)
    end

    function handle:write(data)
      checkArg(1, data, "string")
      if not self.mode.w then
        return nil, "file not opened for writing"
      end
      if self.closed then
        return nil, "cannot write to closed file"
      end
      return node.proxy.write(self.file, data)
    end

    function handle:seek(whence, offset)
      checkArg(1, whence, "string")
      checkArg(2, offset, "number", "nil")
      if not self.mode.r then
        return nil, "cannot seek in file not opened for reading"
      end
      if self.closed then
        return nil, "cannot seek in closed file"
      end
      local offset = offset or 0
      return self.proxy.seek(self.file, whence, offset)
    end

    function handle:close()
      if self.closed then
        return nil, "cannot close closed file"
      end
      self.closed = true
      return true
    end

    return handle
  end

  function filesystem.copy(from, to)
    checkArg(1, from, "string")
    checkArg(2, to, "string")
    local fromN, fromP = find(from)
    local toN, toP     = find(to)
    if not fromN or not fromN.proxy.exists(fromP) or not toN then
      return nil, "mo such file or directory"
    end

    local input = filesystem.open(from, "r")
    if input then
      local output, err = filesystem.open(to, "w")
      if not output then
        if err then
          return nil, err
        else
          return nil, "failed opening file for writing"
        end
      end
    end
    return nil, "no such file or directory"
  end

  function filesystem.rename(old, new)
    checkArg(1, old, "string")
    checkArg(2, new, "string")
    local oldN, oldP = find(old)
    local newN, newP = find(new)
    if not oldN or not oldN.proxy.exists(oldP) or not newN then
      return nil, "no such file or directory"
    end

    if oldN ~= newN then
      if oldN.proxy.isDirectory(oldP) then
        return nil, "cannot move directories across filesystem nodes"
      else
        filesystem.copy(old, new)
        filesystem.remove(old)
      end
    else
      return oldN.proxy.rename(oldP, newP)
    end
  end

  kernel.filesystem = filesystem
end

kernel.logger.log("Initialized VFS")


-- Virtual devfs component --

kernel.logger.log("Initializing device FS")

do
  local devfs = {
    label   = "devfs",
    type    = "filesystem",
    address = component.address(),
    nodes   = {
      path     = "/",
      type     = "directory",
      writable = false,
      children = {
        ["by-uuid"] = {
          path      = "by-uuid",
          type      = "directory",
          writable  = false,
          parent    = "/",
          children  = {}
        },
        ["random"]  = {
          path      = "random",
          type      = "file",
          writable  = false,
          parent    = "/",
          read      = function(amount)
            checkArg(1, amount, "number")
            if amount > 2048 then amount = 2048 end
            local r = ""
            for i=1, amount, 1 do
              r = r .. string.char(math.random(0, 255))
            end
            return r
          end
        },
        ["zero"]    = {
          path      = "zero",
          type      = "file",
          writable  = false,
          parent    = "/",
          read      = function(amount)
            checkArg(1, amount, "number")
            if amount > 2048 then amount = 2048 end
            return string.char(0):rep(amount)
          end
        }
      }
    }
  }

  local function split(path)
    local parts = {}
    for part in path:gmatch("[^\\/]+") do
      local current, up = part:find("^%.?%.$")
      if current then
        if up == 2 then
          table.remove(parts)
        end
      else
        table.insert(parts, part)
      end
    end
    return parts
  end

  local function find(path)
    checkArg(1, path, "string")
    local cur = devfs.nodes
    local parts = split(path)
    local index = 1
    while index >= #parts do
      local part = parts[index]
      if cur.children[part] then
        if index == #parts then
          return cur.children[part], table.concat(parts, "/", index)
        else
          cur = cur.children[part]
        end
      else
        return nil, "no such file or directory"
      end
    end
  end

  function devfs.addComponent(address, ctype)
    devfs.nodes.children["by-uuid"].children[address] = {path = address, type = "component", writable = true}
  end

  function devfs.removeComponent(address, ctype)
    devfs.nodes.children["by-uuid"].children[address] = nil
  end

  local handles = {}

  function devfs.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    local node, file = find(file)
    mode = mode or "r"
    if not node.writable and mode:match("[aw]") then
      return nil, "cannot open file for writing"
    end
    local handle = {}
    if node.read and mode:match("[ar]") then
      handle.read = node.read
    end
    if node.write and mode:match("[aw]") then
      handle.write = node.write
    end
    function handle.close()
      handle.closed = true
    end
    handles[#handles + 1] = handle
    return #handles
  end

  function devfs.read(handle, amount)
    checkArg(1, handle, "number")
    checkArg(2, amount, "number")
    return handles[handle].read(amount)
  end

  function devfs.write(handle, data)
    checkArg(1, handle, "number")
    checkArg(2, data, "string")
    return handles[handle].write(data)
  end

  function devfs.close(handle)
    checkArg(1, handle, "number")
    handles[handle].close()
  end

  function devfs.exists(file)
    local node, path = find(file)
    return (path and node and true) or false
  end

  function devfs.isReadOnly()
    return true
  end

  function devfs.makeDirectory()
    return nil, "filesystem is read-only"
  end

  function devfs.seek()
    return nil, "seeking not implemented"
  end

  function devfs.spaceUsed()
    return 0
  end

  function devfs.spaceTotal()
    return 0
  end

  function devfs.isDirectory(file)
    local node, path = find(file)
    return node and node.type == "directory"
  end

  function devfs.rename()
    return nil, "filesystem is read-only"
  end

  function devfs.list(path)
    checkArg(1, path, "string")
    local files = {}
    local node = find(path) or {children = {}}
    if not devfs.isDirectory(path) then
      return {path}
    end
    for name, _ in pairs(node.children) do
      files[#files + 1] = name
    end
    return files
  end

  function devfs.lastModified()
    return 0
  end

  function devfs.getLabel()
    return devfs.label
  end

  function devfs.remove()
    return nil, "filesystem is read-only"
  end

  function devfs.size()
    return 0
  end

  function devfs.setLabel()
    return nil, "filesystem is read-only"
  end

  kernel.logger.log("Mounting devfs at /dev")

  kernel.filesystem.mount(devfs, "/dev")
end


-- TODO: Implement a sysfs

kernel.logger.log("Skipping sysfs: Not implemented")


-- Task scheduler --

kernel.logger.log("Initializing task scheduler")

do
  local threads = {}
  local cur     = 0
  local last    = 0
  local signals = {}

  local function endCycle()
    local dead = {}
    for pid, thread in pairs(threads) do
      if thread.dead or threads[thread.parent].dead or coroutine.status(thread.coro) == "dead" or coroutine.status(threads[thread.parent].coro) == "dead" then
        dead[#dead + 1] = pid
      end
    end
    for i=1, #dead, 1 do
      if kernel.procfs then
        kernel.procfs.rm(dead[i])
      end
      threads[dead[i]] = nil
    end

    local timeout = math.huge
    for pid, thread in pairs(threads) do
      if thread.deadline - computer.uptime() < timeout then
        timeout = thread.deadline + computer.uptime()
      end
      if timeout <= 0 then
        timeout = 0
        break
      end
    end

    local sig = {computer.pullSignal(timeout)}
    if #sig > 0 then
      signals[#signals + 1] = sig
    end
  end

  local function getHandler(pid)
    return threads[pid].handler or getHandler(threads[pid].parent) or error
  end

  local function handle(err, pid)
    local handler, kill = getHandler(pid)
    handler(err)
    os.kill(kill)
  end

  local PROCESS_ENV = {}

  function os.spawn(func, name, handler, blacklist, env, owner)
    checkArg(1, func,      "function")
    checkArg(2, name,      "string")
    checkArg(3, handler,   "function", "nil")
    checkArg(4, blacklist, "table",    "nil")
    checkArg(5, env,       "table",    "nil")
    checkArg(6, owner,     "string",   "nil")
    env = setmetatable(env or {}, { __index = PROCESS_ENV })
    local new = {
      coro      = coroutine.create(func),
      name      = name,
      handler   = handler,
      blacklist = blacklist or {},
      ipc       = {},
      env       = env,
      uptime    = 0,
      owner     = owner or "root",
      parent    = cur,
      start     = computer.uptime(),
      deadline  = computer.uptime()
    }
    last = last + 1
    threads[last] = new
    if kernel.procfs then
      kernel.procfs.add(last, new)
    end
    return last
  end

  function os.setenv(env, val, global)
    checkArg(1, env,    "string")
    checkArg(2, val,    "string", "nil")
    checkArg(3, global, "boolean", "nil")
    if global then
      PROCESS_ENV[env] = val
    elseif threads[cur] then
      threads[cur].env[env] = val
    end
  end

  function os.getenv(env)
    checkArg(1, env, "string")
    if threads[cur] and threads[cur].env[env] then
      return threads[cur].env[env]
    end
    return nil
  end

  function os.kill(pid)
    checkArg(1, pid, "number")
    if not threads[pid] then
      return nil, "no such thread"
    end
    threads[pid].dead = true
  end

  function os.threads()
    local thr = {}
    for pid, thread in pairs(threads) do
      thr[#thr + 1] = {
        pid = pid,
        name = thread.name,
        uptime = thread.uptime,
        owner = thread.owner,
        start = thread.start,
        parent = thread.parent
      }
    end
    return thr
  end

  function os.pid()
    return cur
  end

  function os.find(name)
    checkArg(1, name, "string")
    for pid, thread in pairs(threads) do
      if thread.name == name then
        return pid
      end
    end

    return nil, "thread not found"
  end

  function os.start()
    os.start = nil
    kernel.logger.log("Starting scheduler")
    while true do
      local torun = {}
      for pid, thread in pairs(threads) do
        if thread.deadline <= computer.uptime() or #signals > 0 or #thread.ipc > 0 then
          torun[pid] = thread
        end
      end

      table.sort(torun)

      local sig = {}
      if #signals > 0 then
        sig = table.remove(signals, 1)
      end

      for pid, thread in pairs(torun) do
        local ret
        cur = pid
        if #thread.ipc > 0 then
          local ipc = table.remove(thread.ipc, 1)
          ret = {coroutine.resume(thread.coro, "ipc", ipc.from, table.unpack(ipc.data))}
        elseif #sig > 0 and not thread.blacklist[sig[1]] then
          ret = {coroutine.resume(thread.coro, table.unpack(sig))}
        else
          ret = {coroutine.resume(thread.coro)}
        end

        if ret[2] then
          if not ret[1] then
            handle(ret[2], cur)
          elseif type(ret[2]) == "number" then
            thread.deadline = computer.uptime() + ret[2]
          end
        end
      end
      kernel.logger.panic("all tasks exited")
    end
  end
end

kernel.logger.log("Scheduler initialized")


-- procfs

kernel.logger.log("Initializing process FS")

do
  local files = {
    path     = "/",
    type     = "directory",
    children = {}
  }

  local function split(path)
    local parts = {}
    for part in path:gmatch("[^\\/]+") do
      local current, up = part:find("^%.?%.$")
      if current then
        if up == 2 then
          table.remove(parts)
        end
      else
        table.insert(parts, part)
      end
    end
    return parts
  end

  local function find(path)
    checkArg(1, path, "string")
    local cur = files
    local parts = split(path)
    local index = 1
    while index >= #parts do
      local part = parts[index]
      if cur.children[part] then
        if index == #parts then
          return cur.children[part], table.concat(parts, "/", index)
        else
          cur = cur.children[part]
        end
      else
        return nil, "no such file or directory"
      end
    end
  end

  local function z()
    return 0
  end

  local function t()
    return true
  end

  local function ro()
    return nil, "filesystem is read-only"
  end

  local procfs = {
    type       = "filesystem",
    address    = component.address(),
    setLabel   = ro,
    makeDirectory = ro,
    getSize    = z,
    spaceUsed  = z,
    write      = ro,
    isReadOnly = t,
    spaceTotal = z,
    rename     = ro,
    lastModified = z,
    size       = z
  }

  function procfs.add(pid, data)
    checkArg(1, pid, "number")
    checkArg(2, data, "table")
    files.children[tostring(pid)] = {
      path = tostring(pid),
      type = "directory",
      children = {
        name = {
          path = "name",
          type = "file",
          data = data.name
        },
        parent = {
          path = "parent",
          type = "file",
          data = tostring(data.parent)
        },
        start = {
          path = "start",
          type = "file",
          data = tostring(data.start)
        }
      }
    }
  end

  function procfs.rm(pid)
    checkArg(1, pid, "number")
    if files.children[tostring(pid)] then
      files.children[tostring(pid)] = nil
    end
  end

  function procfs.isDirectory(path)
    checkArg(1, path, "string")
    local node, path = find(path)
    if not node then
      return nil, path
    else
      return node.type == "directory"
    end
  end

  function procfs.list(path)
    checkArg(1, path, "string")
    local node, path = find(path)
    if not node then
      return nil, path
    end
    local files = {}
    if node.type == "directory" then
      for name, _ in pairs(node.children) do
        files[#files + 1] = name
      end
    else
      files = {path}
    end
    return files
  end

  local handles = {}

  function procfs.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    mode = mode or "r"
    if mode:find("[wa]") then
      return ro()
    end

    local node, path = find(file)
    if not node then
      return nil, path
    end

    if node.type == "directory" then
      return nil, "cannot open a directory"
    end

    if not node.data then
      return nil, "file has no readable data"
    end

    local h = {
      node = node,
      mode = {},
      closed = false,
      pointer = 0
    }

    for char in mode:gmatch(".") do
      h.mode[char] = true
    end

    handles[#handles + 1] = h
    return #handles
  end

  function procfs.read(handle, amount)
    checkArg(1, handle, "number")
    checkArg(2, amount, "number")
    if not handles[handle] then
      return nil, "invalid file handle"
    end
    
    if amount == math.huge then amount = 2048 end
    local h = handles[handle]
    if h.closed then
      return nil, "cannot read from closed file"
    end

    local tmp = h.node.data:sub(h.pointer, h.pointer + amount)
    h.pointer = h.pointer + amount + 1

    return tmp
  end

  function procfs.seek()
    return nil, "seeking not implemented"
  end

  function procfs.close(handle)
    checkArg(1, handle, "number")
    if not handles[handle] then
      return nil, "invalid file handle"
    end

    handles[handle].closed = true
    return true
  end

  kernel.procfs = procfs

  kernel.logger.log("Mounting procfs at /proc")

  kernel.filesystem.mount(procfs, "/proc")
end


-- uuuuuuuuuuuuusersoaaaaaaaaaaace

kernel.logger.log("Setting up userspace sandbox")

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
    variation  = _NAME,
    starttime  = _START
  },
  logger       = kernel.logger,
  os           = setmetatable({}, { __index = os }),
  string       = setmetatable({}, { __index = string }),
  math         = setmetatable({}, { __index = math }),
  debug        = setmetatable({}, { __index = debug }),
  bit32        = setmetatable({}, { __index = bit32 }),
  table        = setmetatable({}, { __index = table }),
  unicode      = setmetatable({}, { __index = unicode }),
  component    = component,
  filesystem   = kernel.filesystem,
  coroutine    = setmetatable({}, { __index = coroutine })
}

kernel.logger.log("Loading init from /sbin/init.lua")

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
if not ok then kernel.logger.panic("failed loading init: " .. err) end

os.spawn(ok, "/sbin/init.lua", function(err)kernel.logger.panic("attempted to kill init! " .. err)end, {interrupt = true}, {}, "root")
os.start()

