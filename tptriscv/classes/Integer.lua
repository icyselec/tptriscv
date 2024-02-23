local Boolean = require("tptriscv.classes.Boolean")

---static class
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
function Integer:exclusive_or (x, y)
	return Boolean:exclusive_or(x, y)
end


---@param x
---@param y
---@return boolean
function Integer:unsigned_comparer (x, y)
	return Integer:exclusive_or(x, y)
end

return Integer
