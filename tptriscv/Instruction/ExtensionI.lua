local Cpu = require("tptriscv.classes.Cpu")
local Reg = require("tptriscv.classes.Reg")
local Mem = require("tptriscv.classes.Mem")
local Integer = require("tptriscv.classes.Integer")

-- for editor warning
if bit == nil then
	bit = {}
end

--- static class
---@class ExtensionI
local ExtensionI = {}

-- Instruction List (According to RISC-V Spec v2.2)
--[[
<Implemented>
ADDI	SLTI	SLTIU	ANDI	ORI		XORI
SLLI	SRLI	SRAI
LUI		AUIPC
ADD		SLT		SLTU	AND		OR		XOR		SLL		SRL		SUB		SRA
JAL		JALR	BEQ		BNE		BLT		BLTU	BGE		BGEU
LB		LH		LW		LBU		LHU		SB		SH		SW
<Not Implemented>
FENCE	ECALL	EBREAK
]]

-- Integer Register-Immediate Instructions

function ExtensionI:ADDI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, reg:getGp(opc.rs1) + opc.imm)
end

function ExtensionI:SLTI (opc, cpu)
	local reg = cpu.regs

	if reg:getGp(opc.rs1) < opc.imm then
		reg:setGp(opc.rd0, 1)
	else
		reg:setGp(opc.rd0, 0)
	end
end

function ExtensionI:SLTIU (opc, cpu)
	local reg = cpu.regs
	local rs1Value = reg:getGp(opc.rs1)

	if Integer:exclusive_or(rs1Value, opc.imm) then
		if rs1Value < opc.imm then
			reg:setGp(opc.rd0, 0)
		else
			reg:setGp(opc.rd0, 1)
		end
	else
		if rs1Value < opc.imm then
			reg:setGp(opc.rd0, 1)
		else
			reg:setGp(opc.rd0, 0)
		end
	end
end

function ExtensionI:ANDI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.band(reg:getGp(opc.rs1), opc.imm))
end

function ExtensionI:ORI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.bor(reg:getGp(opc.rs1), opc.imm))
end

function ExtensionI:XORI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.bxor(reg:getGp(opc.rs1), opc.imm))
end

function ExtensionI:SLLI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.lshift(reg:getGp(opc.rs1), opc.imm))
end

function ExtensionI:SRLI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.rshift(reg:getGp(opc.rs1), opc.imm))
end

function ExtensionI:SRAI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.arshift(reg:getGp(opc.rs1), opc.imm))
end

function ExtensionI:LUI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, reg:getPc() + opc.imm)
end

function ExtensionI:AUIPC (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, opc.imm)
end


-- Integer Register-Register Instructions

function ExtensionI:ADD (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, reg:getGp(opc.rs1) + reg:getGp(opc.rs2))
end

function ExtensionI:SLT (opc, cpu)
	local reg = cpu.regs

	if reg:getGp(opc.rs1) < reg:getGp(opc.rs2) then
		reg:setGp(opc.rd0, 1)
	else
		reg:setGp(opc.rd0, 0)
	end
end

function ExtensionI:SLTU (opc, cpu)
	local reg = cpu.regs
	local rs1Value = reg:getGp(opc.rs1)
	local rs2Value = reg:getGp(opc.rs2)

	if Integer:exclusive_or(rs1Value, rs2Value) then
		if rs1Value < rs2Value then
			reg:setGp(opc.rd0, 0)
		else
			reg:setGp(opc.rd0, 1)
		end
	else
		if rs1Value < rs2Value then
			reg:setGp(opc.rd0, 1)
		else
			reg:setGp(opc.rd0, 0)
		end
	end
end

function ExtensionI:AND (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.band(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end

function ExtensionI:OR (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.bor(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end

function ExtensionI:XOR (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.bxor(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end

function ExtensionI:SLL (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.lshift(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end

function ExtensionI:SRL (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.rshift(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end

function ExtensionI:SUB (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, reg:getGp(opc.rs1) + reg:getGp(opc.rs2))
end

function ExtensionI:SRA (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.arshift(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end



-- Unconditional Jumps

function ExtensionI:JAL (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, reg:getPc() + 4)
	reg:setPc(reg:getPc() + opc.imm)
	return true
end

function ExtensionI:JALR (opc, cpu)
	local reg = cpu.regs
	local backup = reg:getPc()

	reg:setPc(bit.band(reg:getGp(opc.rs1) + opc.imm, 0xFFFFFFFE)) -- then setting least-significant bit of the result to zero.
	reg:setGp(opc.rd0, backup)
	return true
end



-- Conditional Branches

function ExtensionI:BEQ (opc, cpu)
	local reg = cpu.regs

	if reg:getGp(opc.rs1) == reg:getGp(opc.rs2) then
		reg:setPc(reg:getPc() + opc.imm)
		return true
	end
end

function ExtensionI:BNE (opc, cpu)
	local reg = cpu.regs

	if opc.rs1 ~= opc.rs2 then
		reg:setPc(reg:getPc() + opc.imm)
		return true
	end
end

function ExtensionI:BLT (opc, cpu)
	local reg = cpu.regs

	if opc.rs1 < opc.rs2 then
		reg:setPc(reg:getPc() + opc.imm)
		return true
	end
end

function ExtensionI:BLTU (opc, cpu)
	local reg = cpu.regs
	local rs1Value = reg:getGp(opc.rs1)
	local rs2Value = reg:getGp(opc.rs2)

	-- If both numbers are positive, just compare them. If not, reverse the comparison condition.
	if Integer:exclusive_or(rs1Value, rs2Value) then
		if rs1Value < rs2Value then
			reg:updatePc(opc.siz)
			return false
		else
			reg:setPc(reg:getPc() + opc.imm)
			return true
		end
	else
		if rs1Value < rs2Value then
			reg:setPc(reg:getPc() + opc.imm)
			return true
		else
			reg:updatePc(opc.siz)
			return false
		end
	end
end

function ExtensionI:BGE (opc, cpu)
	local reg = cpu.regs

	if opc.rs1 >= opc.rs2 then
		reg:setPc(reg:getPc() + opc.imm)
		return true
	end
end

function ExtensionI:BGEU (opc, cpu)
	local reg = cpu.regs
	local rs1Value = reg:getGp(opc.rs1)
	local rs2Value = reg:getGp(opc.rs2)

	-- If both numbers are positive, just compare them. If not, reverse the comparison condition.
	if Integer:exclusive_or(rs1Value, rs2Value) then
		if rs1Value >= rs2Value then
			reg:updatePc(opc.siz)
			return false
		else
			reg:setPc(reg:getPc() + opc.imm)
			return true
		end
	else
		if rs1Value >= rs2Value then
			reg:setPc(reg:getPc() + opc.imm)
			return true
		else
			reg:updatePc(opc.siz)
			return false
		end
	end
end



-- Load and Store Instructions

function ExtensionI:LB (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	reg:setGp(opc.rd0, mem:readI8(reg:getGp(opc.rs1) + opc.imm) --[[@as Integer]])
end

function ExtensionI:LH (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	reg:setGp(opc.rd0, mem:readI16(reg:getGp(opc.rs1) + opc.imm) --[[@as Integer]])
end

function ExtensionI:LW (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	reg:setGp(opc.rd0, mem:readI32(reg:getGp(opc.rs1) + opc.imm) --[[@as Integer]])
end

function ExtensionI:LBU (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	reg:setGp(opc.rd0, mem:readU8(reg:getGp(opc.rs1) + opc.imm) --[[@as Integer]])
end

function ExtensionI:LHU (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	reg:setGp(opc.rd0, mem:readU16(reg:getGp(opc.rs1) + opc.imm) --[[@as Integer]])
end

function ExtensionI:SB (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	mem:writeI8(reg:getGp(opc.rs1) + opc.imm, reg:getGp(opc.rs2))
end

function ExtensionI:SH (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	mem:writeI16(reg:getGp(opc.rs1) + opc.imm, reg:getGp(opc.rs2))
end

function ExtensionI:SW (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	mem:writeI32(reg:getGp(opc.rs1) + opc.imm, reg:getGp(opc.rs2))
end



function ExtensionI.subDecoderJAL (args)
	local imm = bit.band(args.imm, 0x80000000)
	imm = imm + bit.rshift(bit.band(args.imm, 0x7FE00000), 9)
	imm = imm + bit.lshift(bit.band(args.imm, 0x00100000), 2)
	imm = imm + bit.lshift(bit.band(args.imm, 0x000FF000), 11)
	args.imm  = bit.arshift(imm, 11)
	args.fun  = ExtensionI.JAL
	return args
end

function ExtensionI.subDecoderADD_SUB (args)
	local funct7 = bit.rshift(bit.band(args.imm, 0xFE0), 5)

	if funct7 == 0 then
		args.fun = ExtensionI.ADD
		return args
	elseif funct7 == 0x20 then
		args.fun = ExtensionI.SUB
		return args
	end
end

function ExtensionI.subDecoderSLL (args)
	if bit.rshift(bit.band(args.imm, 0xFE0), 5) == 0 then
		args.fun = ExtensionI.SLL
		return args
	end
end

function ExtensionI.subDecoderSRL_SRA (args)
	local funct7 = bit.rshift(bit.band(args.imm, 0xFE0), 5)

	if funct7 == 0 then
		args.fun = ExtensionI.SRL
		return args
	elseif funct7 == 0x20 then
		args.fun = ExtensionI.SRA
		return args
	end
end

function ExtensionI.subDecoderSLLI (args)
	if bit.rshift(bit.band(args.imm, 0xFE0), 5) == 0 then
		args.fun = ExtensionI.SLLI
		args.imm = bit.band(args.imm, 0x1F)
		return args
	end
end

function ExtensionI.subDecoderSRLI_SRAI (args)
	local funct7 = bit.rshift(bit.band(args.imm, 0xFE0), 5)

	if funct7 == 0 then
		args.fun = ExtensionI.SRLI
		args.imm = bit.band(args.imm, 0x1F)
		return args
	elseif funct7 == 0x20 then
		args.fun = ExtensionI.SRAI
		args.imm = bit.band(args.imm, 0x1F)
		return args
	end
end



-- get register number of the specified type.
function ExtensionI:getRegisterNumRd0 (i)
	return bit.rshift(bit.band(i, 0x00000F80), 7)
end

-- get register number of the specified type.
function ExtensionI:getRegisterNumRs1 (i)
	return bit.rshift(bit.band(i, 0x000F8000), 15)
end

-- get register number of the specified type.
function ExtensionI:getRegisterNumRs2 (i)
	return bit.rshift(bit.band(i, 0x01F00000), 20)
end



--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function ExtensionI:getImmediateShamt (i)
	return bit.rshift(bit.band(i, 0x01F00000), 20)
end

--- get immediate values of the specified type.
--- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function ExtensionI:getImmediateTypeI (i)
	return bit.arshift(bit.band(i, 0xFFF00000), 20)
end

-- get immediate values of the specified type.
-- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function ExtensionI:getImmediateTypeS (i)
	local  imm = bit.rshift (bit.band(i, 0x00000F80), 7)
	return imm + bit.arshift(bit.band(i, 0xFE000000), 20)
end

-- get immediate values of the specified type.
-- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function ExtensionI:getImmediateTypeB (i)
	local imm = bit.band(i, 0x80000000)
	imm = imm + bit.rshift(bit.band(i, 0x7E000000), 1)
	imm = imm + bit.lshift(bit.band(i, 0x00000080), 23)
	imm = imm + bit.lshift(bit.band(i, 0x00000F00), 12)
	return bit.arshift(imm, 19)
end

-- get immediate values of the specified type.
-- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function ExtensionI:getImmediateTypeU (i)
	return bit.band(i, 0xFFFFF000)
end

-- get immediate values of the specified type.
-- If the actual type of the instruction is different from the immediate type, the behavior is not defined.
function ExtensionI:getImmediateTypeJ (i)
	local imm = bit.band(i, 0x80000000)
	imm = imm + bit.rshift(bit.band(i, 0x7FE00000), 9)
	imm = imm + bit.lshift(bit.band(i, 0x00100000), 2)
	imm = imm + bit.lshift(bit.band(i, 0x000FF000), 11)
	return bit.arshift(i, 11)
end



return ExtensionI
