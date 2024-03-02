local CpuConfig = require("tptriscv.classes.CpuConfig")
local CpuStatus = require("tptriscv.classes.CpuStatus")
local ExtensionI = require("tptriscv.Instruction.ExtensionI")
local ExtensionA = require("tptriscv.Instruction.ExtensionA")
local InstructionListing = require("tptriscv.InstructionListing")
local RefRelated = require("tptriscv.classes.RefRelated")
local Instruction = require("tptriscv.classes.Instruction")
local Reg = require("tptriscv.classes.Reg")
local Csr = require("tptriscv.classes.Csr")

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
	---@class Csr
	csr = {},
}

---@nodiscard
---@return table?
---@param o? table
function Cpu:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.conf = CpuConfig:new()
	o.conf:setConfig("maxUOpSize", 32)
	o.stat = CpuStatus:new()

	o.regs = Reg:new()
	o.refs = RefRelated:new()
	o.refs:add("mem", o.mem)

	o.csr = Csr:new()

	return o
end

function Cpu:del ()
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
	self.stat:setStatus("online", false)
	tpt.message_box("Error", "Processor halted! : " .. msg)
end

function Cpu:throw (cause)

end

function Cpu:printDebuginfo ()

end

function Cpu:run ()
	local opcode = self:decode()
	if opcode == nil then return end
	self:commit(opcode)
end



function Cpu:decode ()
	local mem = self.refs.mem
	local ib = {}

	ib[1] = mem:readI16(self.regs:getPc())

	local decodedOpc = {}

	local bit1To0 = Instruction.getBit1ToBit0(ib[1])

	-- Compressed 16-bit
	if bit1To0 ~= 3 then
		self:halt("Cpu:decode: Unsupported extension.")
		return false
	end

	ib[1] = mem:readI32(self.regs:getPc())

	local bit4To2 = Instruction.getBit4ToBit2(ib[1])
	local bit6To5 = Instruction.getBit6ToBit5(ib[1])

	-- Standard 32-bit
	if bit4To2 ~= 7 then
		decodedOpc.len = 4

		local cur = InstructionListing.word[bit4To2 + 1][bit6To5 + 1]

		local typTab = {
			{ hasFnt3 = true,	decoder = ExtensionI.decoderTypeR },
			{ hasFnt3 = true,	decoder = ExtensionI.decoderTypeI },
			{ hasFnt3 = true,	decoder = ExtensionI.decoderTypeS },
			{ hasFnt3 = true,	decoder = ExtensionI.decoderTypeB },
			{ hasFnt3 = false,	decoder = ExtensionI.decoderTypeU },
			{ hasFnt3 = false,	decoder = ExtensionI.decoderTypeJ },
		--	{ hasFnt3 = true,	decoder = ExtensionA.decoderTypeA },
		}
		local opType = cur.opType

		if opType == 0 then
			self:halt("Cpu:decode: Not implemented instruction, processor is halted.")
			return nil
		end

		decodedOpc = typTab[opType].decoder(decodedOpc, ib[1])

		local opcode

		if typTab[opType].hasFnt3 then
			if cur.hasFn7 then
				opcode = cur.opcode[ExtensionI.getFunction7Value(ib[1]) + 1][ExtensionI.getFunction3Value(ib[1]) + 1]
			else
				opcode = cur.opcode[ExtensionI.getFunction3Value(ib[1]) + 1]
			end
		else
			opcode = cur.opcode
		end

		if opcode.subDecoder ~= nil then
			decodedOpc = opcode.subDecoder(decodedOpc)
		else
			decodedOpc.fun = opcode.opcodeFrom[opcode.opcodeName]
		end

		return decodedOpc
	end



	ib[2] = mem:safeRead(self, self.regs:getPc() + 4, 3) --[[@as U32]]

	-- Extended 48-bit
	if bit.band(bit6To5, 1) == 0 then
		decodedOpc.len = 6
	-- Extended 64-bit
	elseif bit6To5 == 1 then
		decodedOpc.len = 8
	end

	self:halt("Cpu:decode: Instruction length too long.")
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
end

function Cpu:commit (decodedOpc)
	if not decodedOpc.fun(decodedOpc, self) then
		self.regs:updatePc(decodedOpc.len)
	end
end


return Cpu
