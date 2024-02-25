local Cpu = require("tptriscv.classes.Cpu")
local Reg = require("tptriscv.classes.Reg")
local Mem = require("tptriscv.classes.Mem")
local Integer = require("tptriscv.classes.Integer")

-- for editor warning
if bit == nil then
	bit = {}
end

--- static class
---@class ExtensionM
local ExtensionM = {}

--[[
<Multiplication Operations>
MUL
MULH
MULHU
MULHSU
<Division Operations>
DIV
DIVU
REM
REMU
]]

function ExtensionM:MUL (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, reg:getGp(opc.rs1) * reg:getGp(opc.rs2))
end

function ExtensionM:MULH (opc, cpu)
	local reg = cpu.regs

	cpu:halt("Instruction:decodeExtensionM: Not implemented instruction, processor is stopped.")
end

function ExtensionM:MULHU (opc, cpu)
	local reg = cpu.regs

	cpu:halt("Instruction:decodeExtensionM: Not implemented instruction, processor is stopped.")
end

function ExtensionM:MULHSU (opc, cpu)
	local reg = cpu.regs

	cpu:halt("Instruction:decodeExtensionM: Not implemented instruction, processor is stopped.")
end



function ExtensionM:DIV (opc, cpu)
	local reg = cpu.regs

	if reg:getGp(opc.rs2) == 0 then
		cpu:halt("Extension:DIV: Divide by Zero.")
		return
	end

	reg:setGp(opc.rd0, reg:getGp(opc.rs1) / reg:getGp(opc.rs2))
end

function ExtensionM:DIVU (opc, cpu)
	local reg = cpu.regs

	cpu:halt("Instruction:decodeExtensionM: Not implemented instruction, processor is stopped.")
end

function ExtensionM:REM (opc, cpu)
	local reg = cpu.regs

	if reg:getGp(opc.rs2) == 0 then
		cpu:halt("Instruction:decodeExtensionM: Divide by Zero.")
		return
	end

	reg:setGp(opc.rd0, reg:getGp(opc.rs1) % reg:getGp(opc.rs2))
end

function ExtensionM:REMU (opc, cpu)
	local reg = cpu.regs

	cpu:halt("Instruction:decodeExtensionM: Not implemented instruction, processor is stopped.")
end

return ExtensionM
