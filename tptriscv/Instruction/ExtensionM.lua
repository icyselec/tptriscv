local Integer = require("tptriscv.classes.Integer")

bit = _G.bit or _G.bit32

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

	reg:setGp(opc.rd0, Integer:unsignedMultiply(reg:getGp(opc.rs1), reg:getGp(opc.rs2)))
end

function ExtensionM:MULH (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, math.floor(reg:getGp(opc.rs1) * reg:getGp(opc.rs2) / 2^32))
end

function ExtensionM:MULHU (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, math.floor(Integer:toUnsigned(reg:getGp(opc.rs1)) * Integer:toUnsigned(reg:getGp(opc.rs2)) / 2^32))
end

function ExtensionM:MULHSU (opc, cpu)
	local reg = cpu.regs

	reg:setGp(opc.rd0, math.floor(reg:getGp(opc.rs1) * Integer:toUnsigned(reg:getGp(opc.rs2)) / 2^32))
end



function ExtensionM:DIV (opc, cpu)
	local reg = cpu.regs

	if reg:getGp(opc.rs2) == 0 then
		reg:setGp(opc.rd0, -1)
	else
		reg:setGp(opc.rd0, reg:getGp(opc.rs1) / reg:getGp(opc.rs2))
	end
end

function ExtensionM:DIVU (opc, cpu)
	local reg = cpu.regs

	if reg:getGp(opc.rs2) == 0 then
		reg:setGp(opc.rd0, 2^RV.XLEN-1)
	else
		reg:setGp(opc.rd0, Integer:toUnsigned(reg:getGp(opc.rs1)) / Integer:toUnsigned(reg:getGp(opc.rs2)))
	end
end

function ExtensionM:REM (opc, cpu)
	local reg = cpu.regs

	if reg:getGp(opc.rs2) == 0 then
		reg:setGp(opc.rd0, reg:getGp(opc.rs1))
	else
		reg:setGp(opc.rd0, reg:getGp(opc.rs1) % reg:getGp(opc.rs2))
	end
end

function ExtensionM:REMU (opc, cpu)
	local reg = cpu.regs

	if reg:getGp(opc.rs2) == 0 then
		reg:setGp(opc.rd0, reg:getGp(opc.rs1))
	else
		reg:setGp(opc.rd0, Integer:toUnsigned(reg:getGp(opc.rs1)) % Integer:toUnsigned(reg:getGp(opc.rs2)))
	end
end

return ExtensionM
