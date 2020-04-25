-- buffered file I/O --

local filesystem = require("filesystem")
local buffer = require("buffer")
local vt100 = require("vt100")
local stream = vt100.stream

_G.io = {}

local stdio = buffer.new("rw", stream)
stdio:setvbuf("no")

io.stdin  = stdio
io.stdout = stdio
io.stderr = stdio

local input, output = io.stdin, io.stdout

function io.output(out)
  checkArg(1, out, "table", "string", "nil")
  if type(out) == "table" then
    if io.type(out) == "file" then
      ouputt = out
      return true
    else
      return false
    end
  elseif type(out) == "string" then
    local ok, err = io.open(out, "r")
    if not ok then
      return nil, err
    end
    output = ok
    return true
  else
    return output
  end
end

function io.input(inp)
  checkArg(1, inp, "table", "string", "nil")
  if type(inp) == "table" then
    if io.type(inp) == "file" then
      input = inp
      return true
    else
      return false
    end
  elseif type(inp) == "string" then
    local ok, err = io.open(inp, "r")
    if not ok then
      return nil, err
    end
    input = ok
    return true
  else
    return input
  end
end

function io.open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  local mode = mode or "r"
  
  local handle, err = filesystem.open(file, mode)
  if not handle then
    return nil, err
  end
  
  return buffer.new(mode, handle)
end

function io.type(file)
  assert(type(file) == "table", "bad argument #1 (expected file, got " .. type(file) .. ")")
  if file.close and (file.read or file.write) then
    if file.closed then
      return "closed file"
    else
      return "file"
    end
  else
    return nil
  end
end

function io.close(file)
  checkArg(1, file, "table", "nil")
  if file then
    return file:close()
  end
end

function io.write(...)
  return io.output():write(table.concat({"", ...}, " "))
end

function io.read(...)
  return io.input():read(...)
end

function io.flush()
  return io.output():flush()
end

function io.lines(file, ...)
  checkArg(1, file, "string", "table")
  if type(file) == "string" then
    local ok, err = io.open(file, "r")
    if not ok then
      return nil, err
    end
    return ok:lines(...)
  else
    return file:lines(...)
  end
end

function io.popen()
  error("TODO: not implemented")
end

function print(...)
  local tp = {}
  for i=1, select("#", ...), 1 do
    tp[i] = tostring(select(i, ...))
  end
  io.stdout:write(table.concat(tp, " ") .. "\n")
end
