---@class RefRelated
local RefRelated = {}

---@param o? table
---@nodiscard
---@return RefRelated
function RefRelated:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

---@param s string Related object name.
---@param o any Related object reference.
---@return nil
function RefRelated:add (s, o)
	self[s] = o
end

function RefRelated:del (s)
	self[s] = nil
end

return RefRelated
