local Cpu = require("tptriscv.classes.Cpu")
local Mem = require("tptriscv.classes.Mem")
local CpuConfig = require("tptriscv.classes.CpuConfig")
local CpuStatus = require("tptriscv.classes.CpuStatus")

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
	o.cpu[1].conf = CpuConfig:new()
	o.cpu[1].conf:set_config("ref_instance", o)
	o.cpu[1].stat = CpuStatus:new()



	o.cpu[1].refs:add("instance", o)
	o.cpu[1].refs:add("mem", o.mem)

	return o
end

function Instance:del ()
	self.cpu[1].refs:del()
	self.mem:del()

	Rv.instance[self.id] = nil
end

return Instance
