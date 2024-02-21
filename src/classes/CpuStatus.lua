---@class CpuStatus
---@field private is_halted boolean
---@field private is_aligned boolean
---@field private is_waiting boolean
---@field private online boolean
CpuStatus = {
	is_halted = false,
	is_aligned = true,
	is_waiting = false,
	online = true,
}

---@param o? table
---@nodiscard
---@return CpuStatus
function CpuStatus:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return self
end

---@param stat_name string
---@return any
function CpuStatus:get_status (stat_name)
	return self[stat_name]
end

---@param stat_name string
---@param value any
---@return nil
function CpuStatus:set_status (stat_name, value)
	self[stat_name] = value
end
