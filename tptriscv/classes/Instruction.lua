local Integer = require("tptriscv.classes.Integer")


---@class Instruction
local Instruction = {}




--[[
--- Instruction constructor
---@param o? table
---@return Instruction?
function Instruction:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	if o.core == nil then
		print("Instruction:new: Failed to initialization, cpu core reference is nil.")
		return nil
	end

	return o
end

function Instruction:del ()
	self.refcpu = nil
	self.cmdbuf = nil
	return true
end
]]







--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function Instruction.getBit1ToBit0 (i)
	return bit.band(i, 0x0003)
end

--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function Instruction.getBit4ToBit2 (i)
	return bit.rshift(bit.band(i, 0x0000001C), 2)
end

--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function Instruction.getBit6ToBit5 (i)
	return bit.rshift(bit.band(i, 0x00000060), 5)
end



return Instruction
