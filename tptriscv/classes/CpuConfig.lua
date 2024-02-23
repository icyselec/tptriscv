---@class CpuConfig
---@field private frequency number
---@field private extension string[]
local CpuConfig = {
	-- frequency of operation per frame The effective frequency is calculated as follows (multiplier * maximum frame limit) * (current frame count / maximum frame limit)
	frequency = 5,
	check_aligned = false,
	disasm = false,
}


---@param o? table
---@nodiscard
---@return CpuConfig
function CpuConfig:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function CpuConfig:del ()
	for k, _ in pairs(self) do
		if type(self[k]) ~= "function" then
			self:set_config(k, nil)
		end
	end

	return true
end

---@param conf_name string
---@return any
function CpuConfig:getConfig (conf_name)
	return self[conf_name]
end

---@param conf_name string
---@param value any
---@return nil
function CpuConfig:setConfig (conf_name, value)
	self[conf_name] = value
end

return CpuConfig
