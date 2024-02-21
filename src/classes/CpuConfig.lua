---@class CpuConfig
---@field private frequency number
---@field private extension string[]
local CpuConfig = {
	---@class Ref
	---@field ref_mem Mem
	ref_instance = {
		ref_mem = {}
	},
	-- frequency of operation per frame The effective frequency is calculated as follows (multiplier * maximum frame limit) * (current frame count / maximum frame limit)
	frequency = 0,
	extension = {},
	check_aligned = false,
}


---@param o? table
---@nodiscard
---@return CpuConfig
function CpuConfig:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	self.frequency = 1
	self.extension = { "RV32I", "RV32C" }

	return o
end

---@param conf_name string
---@return any
function CpuConfig:get_config (conf_name)
	return self[conf_name]
end

---@param conf_name string
---@param value any
---@return nil
function CpuConfig:set_config (conf_name, value)
	self[conf_name] = value
end

return CpuConfig
