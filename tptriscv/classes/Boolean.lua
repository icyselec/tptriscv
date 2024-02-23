-- static class
---@class Boolean
local Boolean = {}

--[[ Usage:
--  unsigned integer compare
--  if Boolean:exclusive_or(x, y) then
--      if x > y then
--          --  if false
--      else
--          --  if true
--      end
--  else
--      if x > y then
--          --  if true
--      else
--          --  if false
--      end
--  end
]]
---@param x integer|number
---@param y integer|number
---@return boolean # Returns the true value if both are positive or negative; returns the false value if only one is negative.
function Boolean:exclusive_or (x, y)
	return (x < 0 or y < 0) and not (x < 0 and y < 0)
end


---@param x
---@param y
---@return boolean
function Boolean:unsigned_comparer (x, y)
	return Boolean:exclusive_or(x, y)
end

return Boolean
