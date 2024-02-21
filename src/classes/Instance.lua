local Cpu = require("Cpu")
local Mem = require("Mem")

---@class Instance
---@field cpu Cpu
---@field mem Mem
---@field conf CpuConfig
---@field stat CpuStatus
local Instance = {
	cpu = {},
	mem = {},
	conf = {},
	stat = {},
}

Rv.instance = {}

function Instance:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.cpu[1] = Cpu:new()
	o.cpu[1].conf:set_config("ref_instance", o)

	o.mem = Mem:new()

	o.cpu[1].ref_mem = o.mem

	return o
end

function Instance:del (o)
	Rv.instance[o.id] = nil
	self = nil
end

return Instance
