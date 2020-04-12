-- Filesystem things --

local filesystem = {}

do
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
end
