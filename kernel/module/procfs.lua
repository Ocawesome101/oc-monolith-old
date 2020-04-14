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
