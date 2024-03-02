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


---@param x number
---@param y number
---@return boolean
function Integer:unsigned_comparer (x, y)
	return Integer:exclusive_or(x, y)
end

function Integer:toUnsigned (n)
	return tonumber(bit.tohex(n), 16)
end


-- source code from: https://gist.github.com/MikuAuahDark/257a763f43efd00012a9afbe65932770
--- Performs a multiplication of 32-bit unsigned integers.
---@param x number
---@param y number
---@return number
function Integer:unsignedMultiply(x, y)
	local xh, xl = bit.rshift(x, 16), bit.band(x, 0xFFFF)
	local yh, yl = bit.rshift(y, 16), bit.band(y, 0xFFFF)
	local high = bit.band(xh*yl + xl*yh, 0xFFFF)
	return (bit.lshift(high, 16) + xl*yl) % 2^32
end

--- Returns true values if the conditions match, false values if they do not match.
---@param x number
---@param y number
---@return boolean
function Integer:isUnsignedLt (x, y)
	if (x < 0 or y < 0) and not (x < 0 and y < 0) then
		return not (x < y)
	else
		return x < y
	end
end

--- Returns true values if the conditions match, false values if they do not match.
---@param x number
---@param y number
---@return boolean
function Integer:isUnsignedGe (x, y)
	if (x < 0 or y < 0) and not (x < 0 and y < 0) then
		return not (x >= y)
	else
		return x >= y
	end
end

--- Returns true values if the conditions match, false values if they do not match.
---@param x number
---@param y number
---@return boolean
function Integer:isUnsignedLe (x, y)
	if (x < 0 or y < 0) and not (x < 0 and y < 0) then
		return not (x <= y)
	else
		return x <= y
	end
end

--- Returns true values if the conditions match, false values if they do not match.
---@param x number
---@param y number
---@return boolean
function Integer:isUnsignedGt (x, y)
	if (x < 0 or y < 0) and not (x < 0 and y < 0) then
		return not (x > y)
	else
		return x > y
	end
end

return Integer
