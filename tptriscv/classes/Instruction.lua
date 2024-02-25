local Reg = require("tptriscv.classes.Reg")
local Integer = require("tptriscv.classes.Integer")
local ExtensionI = require("tptriscv.Instruction.ExtensionI")

---@class Instruction
---@field refcpu Cpu
---@field length Integer
---@field cmdbuf U32[]
---@field disasm string
local Instruction = {
	refcpu = {},
	length = 0,
	cmdbuf = {},
	disasm = "",
	registered = {},
}





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




--- Register with the decoder so that instructions can be processed.
---@param w table		Where.
---@param n string		Instruction processing function name. Valid function prototypes: function(DecodedOpc, Cpu)
---@param t number		Instruction format or type. 0 = Invalid, 1 = R-Type, 2 = I-Type, 3 = S-Type, 4 = B-Type, 5 = U-Type, 6 = J-Type
---@return boolean	#	Returns true value if registration is successful and false value if registration fails.
function Instruction:register (w, n, t)
	if t < 1 or t > 6 then
		return false
	end
end

function Instruction:decode ()
	---@type Cpu
	local cpu = self.refcpu
	---@type Mem
	local mem = cpu.refs.mem
	local i = mem:safeRead(cpu, cpu.regs:getPc(), 3) --[[@as U32]]

	local bit1To0 = Instruction.getBit1ToBit0(i)

	-- Compressed 16-bit
	if bit1To0 ~= 3 then
		if cpu.conf:getConfig("enableRv32c") then
			self.size = 2
			return true
		else
			cpu:halt("Instruction:run: Unsupported extension.")
			return false
		end
	end

	local bit4To2 = Instruction.getBit4ToBit2(i)

	-- Standard 32-bit
	if bit4To2 ~= 7 then
		self.size = 4
		return true
	end

	--[==[
	local bit6_5 = bit.rshift(bit.band(self.cmds[1], 0x0060), 5)
	self.cmds[2] = mem:safeRead(cpu, cpu.regs:getPc() + 4, 3) --[[@as u32]]

	-- Extended 48-bit
	if bit.band(bit6_5, 1) == 0 then
		self.length = 6
	-- Extended 64-bit
	elseif bit6_5 == 1 then
		self.length = 8
	end

	cpu:halt("Instruction:fetchInstruction: Instruction length too long.")
	return false


	--[=[
	local bit14_12 = bit.rshift(bit.band(self.cmds[1], 0x7000), 12)

	self.size = 10 + 2 * bit14_12
	self.cmds[3] = mem:access(cpu, cpu.regs:access_pc() + 4, 3) --[[@as u32]]

	if bit14_12 == 7 then
		rv.throw("Instruction:fetch_instruction: Instruction length too long.")
		return false
	end

	local optab = {
		function ()
			return
		end,
		function ()

		end,
		function () end,
		function () end,
	}

	optab[bit14_12 + 1]()

	]=]
	]==]
end

function Instruction:commit ()

end



--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function Instruction:getBit1ToBit0 (i)
	return bit.band(i, 0x0003)
end

--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function Instruction:getBit4ToBit2 (i)
	return bit.rshift(bit.band(i, 0x0000001C), 2)
end

--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function Instruction:getBit6ToBit5 (i)
	return bit.rshift(bit.band(i, 0x00000060), 5)
end

--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function Instruction:getFunction7Value (i)
	return bit.rshift(bit.band(i, 0xFE000000), 29)
end

--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function Instruction:getFunction3Value (i)
	return bit.rshift(bit.band(i, 0x00007000), 12)
end



---@param dbgarg table
---@return string
function Instruction:step (dbgarg)
	if not self:fetchInstruction() then
		return RV.ILLEGAL_INSTRUCTION
	end

	local optab = {
		-- Compressed Instruction
		function ()
			return self:decode16Bit(dbgarg)
		end,
		-- Standard Instruction
		function ()
			--return self:decode32Bit(dbgarg)
		end,
		-- Extended 48-bit Instruction (Not Supported)
		function ()
			return RV.ILLEGAL_INSTRUCTION
		end,
		-- Extended 64-bit Instruction (Not Supported)
		function ()
			return RV.ILLEGAL_INSTRUCTION
		end,
	}

	return optab[bit.rshift(self.size, 1)]()
end

return Instruction
