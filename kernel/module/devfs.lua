-- Virtual devfs component --

do
  local devfs = {
    label   = "devfs",
    type    = "filesystem"
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

  filesystem.mount(devfs, "/dev")
end
