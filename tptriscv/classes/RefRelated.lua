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

function RefRelated:del ()
	for k, _ in pairs(self) do
		if type(self[k]) ~= "function" then
			self:remove(k)
		end
	end

	return true
end

---@param s string Related object name.
---@param o any Related object reference.
---@return nil
function RefRelated:add (s, o)
	self[s] = o
end

function RefRelated:remove (s)
	self[s] = nil
end

return RefRelated
