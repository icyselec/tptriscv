local Cpu = require("tptriscv.classes.Cpu")
local Mem = require("tptriscv.classes.Mem")

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

function Instance:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.mem = Mem:new()

	o.cpu = {}
	o.cpu[1] = Cpu:new{mem = o.mem}

	return o
end

function Instance:del ()
	self.cpu[1]:del()
	self.mem:del()

	Rv.instance[self.id] = nil
end

return Instance
