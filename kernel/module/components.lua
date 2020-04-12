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
