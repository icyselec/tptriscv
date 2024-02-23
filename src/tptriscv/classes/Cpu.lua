local RefRelated = require("tptriscv.classes.RefRelated")
local Instruction = require("tptriscv.classes.Instruction")
local Reg = require("tptriscv.classes.Reg")

---@class Cpu
local Cpu = {
	---@class RefRelated
	refs = {},
	---@class CpuConfig
	conf = {},
	---@class CpuStatus
	stat = {},
	---@class Reg
	regs = {},
	---@class Instruction
	instruction = {}
}

---@nodiscard
---@return table?
---@param o? table
function Cpu:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.regs = Reg:new()
	o.refs = RefRelated:new()
	o.refs:add("mem", o.mem)
	o.mem = nil

	local instruction = Instruction:new{core = o}

	if instruction == nil then
		return
	end

	o.instruction = instruction

	return o
end

function Cpu:del ()
	self.instruction:del()
	self.refs:del()
	self.regs:del()
	return true
end


---@deprecated
---@param name string
---@param status boolean
---@return boolean|nil
function Cpu:access_stat (name, status)
	if status == nil then
		return self.stat[name]
	else
		self.stat[name] = status
	end
end

---@param msg string
---@return nil
function Cpu:halt (msg)
	self.stat:set_status("online", false)
	tpt.message_box("Error", "Processor halted! : " .. msg)
end

function Cpu:print_debug_info ()

end

function Cpu:run (dbgarg)
	local disassembled = self.instruction:step(dbgarg)

	if dbgarg then
		if dbgarg.lowercase then
			disassembled = string.lower(disassembled)
		end

		print(disassembled)
	end
end

return Cpu
