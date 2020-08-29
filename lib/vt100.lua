-- VT100 emulator-ish thing. The terminal for all of Monolith. --

local tty = require("tty")
local component = require("component")
local event = require("event")
local vt100 = {}

local cx, cy = 1, 1
local hide = false

function vt100.isHidden()
  return hide
end

function vt100.cursorPos()
  return cx, cy
end

-- Credit to Izaya, and his PsychOS2, for this function.
function vt100.emu(gpu) -- takes GPU component proxy *gpu* and returns a function to write to it in a manner like an ANSI terminal
  local colours = {0x0,0xFF0000,0x00FF00,0xFFFF00,0x0000FF,0xFF00FF,0x00B6FF,0xFFFFFF}
  local mx, my = gpu.maxResolution()
  local pc = " "
  local lc = ""
  local mode = 0 -- 0 normal, 1 escape, 2 command
  local lw = true
  local sx, sy = 1,1
  local cs = ""
  local bg, fg = 0, 0xFFFFFF

 -- setup
  gpu.setResolution(mx,my)
  gpu.fill(1,1,mx,my," ")
  local function checkCursor()
    if cx > mx and lw then
      cx, cy = 1, cy+1
    end
    if cy > my then
      gpu.copy(1,2,mx,my-1,0,-1)
      gpu.fill(1,my,mx,1," ")
      cy=my
    end
    if cy < 1 then cy = 1 end
    if cx < 1 then cx = 1 end
  end

  local function termwrite(s)
    local wb = ""
    local lb, ec = nil, nil
    local function flushwb()
      while wb:len() > 0 do
        checkCursor()
        local wl = wb:sub(1,mx-cx+1)
        wb = wb:sub(wl:len()+1)
        if not hide then
          gpu.set(cx, cy, wl)
          cx = cx + wl:len()
        end
      end
    end
    local rs = ""
    s=s:gsub("\8","\27[D")
    pc = gpu.get(cx,cy)
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    gpu.set(cx,cy,pc)
    for cc in s:gmatch(".") do
      if mode == 0 then
        if cc == "\n" then
          flushwb()
          cx,cy = 1, cy+1
        elseif cc == "\t" then
          wb=wb..(" "):rep(8*((cx+9)//8))
        elseif cc == "\27" then
          flushwb()
          mode = 1
        else
          wb = wb .. cc
        end
      elseif mode == 1 then
        if cc == "[" then
          mode = 2
        else
          mode = 0
        end
      elseif mode == 2 then
        if cc:match("[%d;]") then
          cs = cs .. cc
        else
          mode = 0
          local tA = {}
          for s in cs:gmatch("%d+") do
            tA[#tA+1] = tonumber(s)
          end
          if cc == "H" then
            cx, cy = tA[1] or 1, tA[2] or 1
          elseif cc == "A" then
            cy = cy - (tA[1] or 1)
          elseif cc == "B" then
            cy = cy + (tA[1] or 1)
          elseif cc == "C" then
            cx = cx + (tA[1] or 1)
          elseif cc == "D" then
            cx = cx - (tA[1] or 1)
          elseif cc == "s" then
            sx, sy = cx, cy
          elseif cc == "u" then
            cx, cy = sx, sy
          elseif cc == "n" and tA[1] == 6 then
            rs = string.format("%s\27[%d;%dR",rs,cx,cy)
          elseif cc == "K" and tA[1] == 2 then
            gpu.fill(1,cy,cx,1," ")
          elseif cc == "K" and tA[1] == 1 then
            gpu.fill(1,cy,mx,1," ")
          elseif cc == "K" then
            gpu.fill(cx,cy,mx,1," ")
          elseif cc == "J" and tA[1] == 1 then
            gpu.fill(1,1,mx,cy," ")
          elseif cc == "J" and tA[1] == 2 then
            gpu.fill(1,1,mx,my," ")
            cx, cy = 1, 1
          elseif cc == "J" then
            gpu.fill(1,cy,mx,my," ")
          elseif cc == "m" then
            for _,num in ipairs(tA) do
              if num == 0 then
                fg,bg,ec,lb = 0xFFFFFF,0,true,true
              elseif num == 7 then
                local nfg,nbg = bg, fg
                fg, bg = nfg, nbg
              elseif num == 8 then
                hide = false
                ec = false
              elseif num > 29 and num < 38 then
                fg = colours[num-29]
              elseif num > 39 and num < 48 then
                bg = colours[num-39]
              elseif num == 100 then -- disable local echo
                ec = false
              elseif num == 101 then -- disable line mode
                lb = false
              end
            end
            gpu.setForeground(fg)
            gpu.setBackground(bg)
          end
          cs = ""
          checkCursor()
        end
      end
    end
    flushwb()
    checkCursor()
    pc = gpu.get(cx,cy)
    gpu.setForeground(bg)
    gpu.setBackground(fg)
    gpu.set(cx,cy,pc)
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    return rs, lb, ec
  end

  return termwrite
end

local write = vt100.emu(component.gpu)--tty.window)

local rbuf = require("readkey")

vt100.stream = {}

function vt100.stream:read(amount)
  checkArg(1, amount, "number", "nil")
  return rbuf.read(amount)
end

function vt100.stream:write(data)
  checkArg(1, data, "string")
  return write(data)
end

return vt100
