-- table protection --

local lib = {}

function lib.protect(tbl)
  checkArg(1, tbl, "table")
  setmetatable(tbl, {
    __newindex = function(tbl, k)
      error("cannot assign new index to protected table")
    end
  })
end

return lib
