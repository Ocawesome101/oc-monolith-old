-- a tty lib I wrote --

local tty = {}

function tty.new(w, h)
  checkArg(1, w, "number")
  checkArg(2, h, "number")
  local buffer = {
    buf = {}
  }
  local w, h = w, h
  local x, y = 1, 1
  local fg, bg = 0xFFFFFF, 0x000000
  local blink = false
  for i=1, w, 1 do
    buffer.buf[i] = {}
    for j=1, h, 1 do
      buffer.buf[i][j] = string.pack(">I1I3I3", (" "):byte(), 0xFFFFFF, 0x000000)
    end
  end
  
  function buffer.setCursor(bool)
    checkArg(1, bool, "boolean")
    blink = bool
  end
  
  function buffer.setChar(_x, _y, c)
    checkArg(1, _x, "number")
    checkArg(2, _y, "number")
    checkArg(3, c, "string")
    if not buffer.buf[_x] or not buffer.buf[_x][_y] then
      return nil, "index " .. _x .. "," .. _y .. " out of bounds " .. w .. "," .. h
    end
    buffer.buf[_x][_y] = string.pack(">I1I3I3", string.byte(c) or 0x20, fg or 0xFFFFFF, bg or 0x000000)
    return true
  end
  
  function buffer.set(_x, _y, s, v)
    checkArg(1, _x, "number")
    checkArg(2, _y, "number")
    checkArg(3, s, "string")
    checkArg(4, v, "boolean", "nil")
    if v then
      for __y=_y, _y+#s, 1 do
        local ok, err = buffer.setChar(_x, __y, s:sub(_y - y + 1, _y - y + 1))
        if not ok then
          return nil, err
        end
      end
    else
      for __x=_x, _x+#s, 1 do
        local ok, err = buffer.setChar(__x, _y, s:sub(__x - _x + 1, __x - _x + 1))
        if not ok then
          return nil, err
        end
      end
    end
    return true
  end
  
  function buffer.get(_x, _y)
    checkArg(1, _x, "number")
    checkArg(2, _y, "number")
    if not buffer.buf[_x] or not buffer.buf[_x][_y] then
      error("index " .. _x .. "," .. _y .. " out of bounds")
    end
    local byte, _fg, _bg = string.unpack(">I1I3I3", buffer.buf[_x][_y])
    return string.char(byte), _fg, _bg
  end
  
  function buffer.fill(x, y, w, h, c)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, c, "string")
    for _x=x, x+w, 1 do
      for _y=y, y+h, 1 do
        local ok, err = buffer.setChar(_x, _y, c)
        if not ok then
          return nil, err
        end
      end
    end
    return true
  end
  
  function buffer.copy(x, y, w, h, rx, ry)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, rx, "number")
    checkArg(6, ry, "number")
    if rx > 0 or ry > 0 then -- this check is required, else we'd overwrite some pixels before copying
      for _x=x+w, x, -1 do
        for _y=y+h, y, -1 do
          buffer.setChar(_x + rx, _y + ry, buffer.get(_x, _y))
        end
      end
    else
      for _x=x, x+w, 1 do
        for _y=y, y+h, 1 do
          buffer.setChar(_x + rx, _y + ry, buffer.get(_x, _y))
        end
      end
    end
    return true
  end
  
  function buffer.setForeground(_fg)
    checkArg(1, _fg, "number")
    if _fg > 0xFFFFFF or _fg < 0 then
      return nil, "invalid color"
    end
    fg = _fg
  end
  
  function buffer.setBackground(_bg)
    checkArg(1, _bg, "number")
    if _bg > 0xFFFFFF or _bg < 0 then
      return nil, "invalid color"
    end
    bg = _bg
  end
  
  function buffer.getForeground()
    return fg
  end
  
  function buffer.getBackground()
    return bg
  end
  
  function buffer.setViewport()
    error("attempt to set viewport on buffer")
  end
  
  function buffer.getViewport()
    return nil, "viewports are not necessary when using buffers"
  end
  
  function buffer.setResolution()
    return nil, "unsupported"
  end
  
  function buffer.maxResolution()
    return w, h
  end
  
  function buffer.getResolution()
    return w, h
  end
  
  function buffer.flip(realX, realY, gpu)
    checkArg(1, realX, "number")
    checkArg(2, realY, "number")
    checkArg(3, gpu, "table")
    if not gpu.set or not gpu.setForeground or not gpu.setBackground then
      return nil, "invalid GPU object"
    end
    local ofg = gpu.getForeground()
    local obg = gpu.getBackground()
    for _x=realX, realX + w, 1 do
      for _y=realY, realY + h, 1 do
        local char, _fg, _bg = buffer.get(_x - realX + 1, _y - realY + 1)
        if not char then return end
        if _fg ~= ofg then
          gpu.setForeground(_fg)
        end
        if _bg ~= obg then
          gpu.setForeground(_bg)
        end
        gpu.set(_x, _y, char)
      end
    end
    return true
  end

  return buffer
end

local w, h = require("component").gpu.getResolution()
tty.window = tty.new(w, h)

return tty
