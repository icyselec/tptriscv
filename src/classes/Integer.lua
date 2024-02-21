local bit = require("bit")

-- static class
---@class Integer
local Integer = {}

--[[ Usage:
-- memory limit check
if Integer:unsigned_comparer(ea, RV.MAX_MEMORY_WORD) then
	if ea > RV.MAX_MEMORY_WORD then
		rv.throw("Mem:access: Memory out of bound.")
		return nil
	end
else
	if ea < RV.MAX_MEMORY_WORD then
		rv.throw("Mem:access: Memory out of bound.")
		return nil
	end
end
]]
---@param x Integer
---@param y Integer
---@return boolean # Returns the true value if both are positive or negative; returns the false value if only one is negative.
function Integer:unsigned_comparer (x, y)
	return bit.bxor(bit.band(x, 0x80000000), bit.band(y, 0x80000000)) == 0
end

return Integer
