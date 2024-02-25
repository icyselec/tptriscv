local Cpu = require("tptriscv.classes.Cpu")
local Reg = require("tptriscv.classes.Reg")
local Mem = require("tptriscv.classes.Mem")
local Integer = require("tptriscv.classes.Integer")

-- for editor warning
if bit == nil then
	bit = {}
end

--- static class
---@class ExtensionC
local ExtensionC = {}

--[[
<Stack-Pointer-Based Loads and Stores>
C.LWSP
C.LDSP -- Not Implemented
C.LQSP -- Not Implemented
C.FLWSP -- Not Implemented
C.FLDSP -- Not Implemented
C.SWSP
C.SDSP -- Not Implemented
C.SQSP -- Not Implemented
C.FSWSP -- Not Implemented
C.FSDSP -- Not Implemented

<Register-Based Loads and Stores>
C.LW
C.LD -- Not Implemented
C.LQ -- Not Implemented
C.FLW -- Not Implemented
C.FLD -- Not Implemented
C.SW
C.SD -- Not Implemented
C.SQ -- Not Implemented
C.FSW -- Not Implemented
C.FSD -- Not Implemented

<Control Transfer Instructions>
C.J
C.JAL
C.JR
C.JALR
C.BEQZ
C.BNEZ

<Integer Constant-Generation Instruction>
C.LI
C.LUI

<Integer Register-Immediate Operations>
C.ADDI
C.ADDIW
C.ADDI16SP
C.ADDI4SPN
C.SLLI
C.SRLI
C.SRAI
C.ANDI

<Integer Register-Register Operations>
C.MV
C.ADD
C.AND
C.OR
C.XOR
C.SUB
C.ADDW -- Not Implemented
C.SUBW -- Not Implemented

<Breapoint Instruction>
C.EBREAK -- Not Implemented
]]





function ExtensionC:LWSP (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	reg:setGp(opc.rd0, mem:readI32(reg:getGp(2) + opc.imm))
end

function ExtensionC:LDSP (opc, cpu)
	cpu:halt("ExtensionC:LDSP: Not implemented instruction, processor is halted.")
end

function ExtensionC:LQSP (opc, cpu)
	cpu:halt("ExtensionC:LQSP: Not implemented instruction, processor is halted.")
end

function ExtensionC:FLWSP (opc, cpu)
	cpu:halt("ExtensionC:FLWSP: Not implemented instruction, processor is halted.")
end

function ExtensionC:FLDSP (opc, cpu)
	cpu:halt("ExtensionC:FLDSP: Not implemented instruction, processor is halted.")
end

function ExtensionC:SWSP (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	mem:writeI32(reg:getGp(2) + opc.imm, reg:getGp(opc.rs2))
end

function ExtensionC:SDSP (opc, cpu)
	cpu:halt("ExtensionC:SDSP: Not implemented instruction, processor is halted.")
end

function ExtensionC:SQSP (opc, cpu)
	cpu:halt("ExtensionC:SQSP: Not implemented instruction, processor is halted.")
end

function ExtensionC:FSWSP (opc, cpu)
	cpu:halt("ExtensionC:FSWSP: Not implemented instruction, processor is halted.")
end

function ExtensionC:FSDSP (opc, cpu)
	cpu:halt("ExtensionC:FSDSP: Not implemented instruction, processor is halted.")
end



function ExtensionC:LW (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	reg:setGp(opc.rd0, mem:readI32(reg:getGp(rs1) + opc.imm))
end

function ExtensionC:LD (opc, cpu)
	cpu:halt("ExtensionC:LD: Not implemented instruction, processor is halted.")
end

function ExtensionC:LQ (opc, cpu)
	cpu:halt("ExtensionC:LQ: Not implemented instruction, processor is halted.")
end

function ExtensionC:FLW (opc, cpu)
	cpu:halt("ExtensionC:FLW: Not implemented instruction, processor is halted.")
end

function ExtensionC:FLD (opc, cpu)
	cpu:halt("ExtensionC:FLD: Not implemented instruction, processor is halted.")
end

function ExtensionC:SW (opc, cpu)
	local reg = cpu.regs
	local mem = cpu.refs.mem

	mem:writeI32(reg:getGp(opc.rs1) + opc.imm, reg:getGp(opc.rs2))
end

function ExtensionC:SD (opc, cpu)
	cpu:halt("ExtensionC:SD: Not implemented instruction, processor is halted.")
end

function ExtensionC:SQ (opc, cpu)
	cpu:halt("ExtensionC:SQ: Not implemented instruction, processor is halted.")
end

function ExtensionC:FSW (opc, cpu)
	cpu:halt("ExtensionC:FSW: Not implemented instruction, processor is halted.")
end

function ExtensionC:FSD (opc, cpu)
	cpu:halt("ExtensionC:FSD: Not implemented instruction, processor is halted.")
end


function ExtensionC:J (opc, cpu)
	local reg = cpu.regs

	reg:setPc(reg:getPc() + opc.imm)
	return true
end

function ExtensionC:JAL (opc, cpu)
	local reg = cpu.regs

	reg:setGp(1, reg:getPc() + 2)
	reg:setPc(reg:getPc() + opc.imm)
	return true
end

function ExtensionC:JR (opc, cpu)
	local reg = cpu.regs

	reg:setPc(reg:getGp(opc.rs1))
	return true
end

function ExtensionC:JALR (opc, cpu)
	local reg = cpu.regs
	local backup = reg:getGp(opc.rs1)

	reg:setGp(1, reg:getPc() + 2)
	reg:setPc(backup)
end

function ExtensionC:BEQZ (opc, cpu)
	local reg = cpu.regs

	if reg:setGp(opc.rs1) == 0 then
		reg:setPc(reg:getPc() + opc.imm)
		return true
	end
end

function ExtensionC:BNEZ (opc, cpu)
	local reg = cpu.regs

	if reg:setGp(opc.rs1) ~= 0 then
		reg:setPc(reg:getPc() + opc.imm)
		return true
	end
end



function ExtensionC:LI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rs1, opc.imm)
end

function ExtensionC:LUI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rs1, opc.imm)
end


function ExtensionC:ADDI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rs1, reg:getGp(opc.rs1) + opc.imm)
end

function ExtensionC:ADDIW (opc, cpu)
	cpu:halt("ExtensionC:ADDIW: Not implemented instruction, processor is halted.")
end

function ExtensionC:ADDI16SP (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rs1, reg:getGp(opc.rs1) + opc.imm)
end

function ExtensionC:ADDI4SPN (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd, reg:getGp(2) + opc.imm)
end

function ExtensionC:SLLI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.lshift(reg:getGp(opc.rd0), opc.imm))
end

function ExtensionC:SRLI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.rshift(reg:getGp(opc.rd0), opc.rs2))
end

function ExtensionC:SRAI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.arshift(reg:getGp(opc.rd0), opc.rs2))
end

function ExtensionC:ANDI (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.band(reg:getGp(opc.rd0), opc.imm))
end



function ExtensionC:MV (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, reg:getGp(opc.rs2))
end

function ExtensionC:ADD (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, reg:getGp(opc.rs1) + reg:getGp(opc.rs2))
end

function ExtensionC:AND (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.band(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end

function ExtensionC:OR (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.bor(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end

function ExtensionC:XOR (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, bit.bxor(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end

function ExtensionC:SUB (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, reg:getGp(opc.rs1) - reg:getGp(opc.rs2))
end

function ExtensionC:ADDW (opc, cpu)
	cpu:halt("ExtensionC:ADDW: Not implemented instruction, processor is halted.")
end

function ExtensionC:SUBW (opc, cpu)
	cpu:halt("ExtensionC:SUBW: Not implemented instruction, processor is halted.")
end



function ExtensionC:EBREAK (opc, cpu)
	cpu:halt("ExtensionC:EBREAK: Not implemented instruction, processor is halted.")
end



function ExtensionC:getFunction3Value (i)
	return bit.rshift(bit.band(i, 0xE000), 13)
end

function ExtensionC:getRegisterNumRs1 (i)
	return bit.rshift(bit.band(i, 0x0F80), 7)
end

function ExtensionC:getRegisterNumRs2 (i)
	return bit.rshift(bit.band(i, 0x007C), 2)
end

function ExtensionC:getImmediateTypeCI (i)
	local   value = bit.lshift(bit.band(i, 0x1000), 19)
	value = value + bit.lshift(bit.band(i, 0x007C), 28)
	return  bit.arshift(value, 14)
end

function ExtensionC:getImmediateTypeCI16SP (i)
	local   value = bit.lshift(bit.band(i, 0x1000), 19)
	value = value + bit.lshift(bit.band(i, 0x0018), 26)
	value = value + bit.lshift(bit.band(i, 0x0020), 23)
	value = value + bit.lshift(bit.band(i, 0x0004), 25)
	value = value + bit.lshift(bit.band(i, 0x0040), 20)
	return  bit.arshift(value, 22)
end

function ExtensionC:getImmediateTypeCIU (i)
	local   value = bit.lshift(bit.band(i, 0x1000), 19)
	value = value + bit.lshift(bit.band(i, 0x007C), 28)
	return  bit.arshift(value, 26)
end

function ExtensionC:getImmediateTypeCSS (i)
	return bit.rshift(bit.band(i, 0x1FE0), 5)
end

function ExtensionC:getImmediateTypeCL (i)
	local   value = bit.rshift(bit.band(i, 0x1C00), 7)
	value = value + bit.rshift(bit.band(i, 0x0040), 4)
	return  value + bit.lshift(bit.band(i, 0x0080), 1)
end

function ExtensionC:getImmediateTypeCS (i)
	local   value = bit.rshift(bit.band(i, 0x1C00), 7)
	value = value + bit.rshift(bit.band(i, 0x0040), 4)
	return  value + bit.lshift(bit.band(i, 0x0080), 1)
end

function ExtensionC:getImmediateTypeCB (i)
	local   value = bit.lshift(bit.band(i, 0x1000), 19)
	value = value + bit.lshift(bit.band(i, 0x0060), 24)
	value = value + bit.lshift(bit.band(i, 0x0004), 26)
	value = value + bit.lshift(bit.band(i, 0x0C00), 16)
	value = value + bit.lshift(bit.band(i, 0x0018), 21)
	return  bit.arshift(value, 26)
end

function ExtensionC:getImmediateTypeCJ (i)
	local   value = bit.lshift(bit.band(i, 0x1000), 19)
	value = value + bit.lshift(bit.band(i, 0x0100), 22)
	value = value + bit.lshift(bit.band(i, 0x0600), 19)
	value = value + bit.lshift(bit.band(i, 0x0040), 17)
	value = value + bit.lshift(bit.band(i, 0x0080), 19)
	value = value + bit.lshift(bit.band(i, 0x0004), 23)
	value = value + bit.lshift(bit.band(i, 0x0800), 14)
	value = value + bit.lshift(bit.band(i, 0x0038), 18)
	return  bit.arshift(value, 23)
end

return ExtensionC
