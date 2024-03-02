local ExtensionI = require("tptriscv.Instruction.ExtensionI")

--- static class
---@class ExtensionA
local ExtensionA = {}


function ExtensionA.getFunction5Value (i)
	return bit.rshift(bit.band(i, 0xF8000000), 27)
end

function ExtensionA.getMOrderingValue (i)
	return bit.rshift(bit.band(i, 0x06000000), 25)
end

function ExtensionA.decoderTypeA (args, i)
	args.rd0 = ExtensionI.getRegisterNumRd0(i)
	args.rs1 = ExtensionI.getRegisterNumRs1(i)
	args.rs2 = ExtensionI.getRegisterNumRs2(i)
	args.ord = ExtensionA.getMOrderingValue(i)
	args.fn5 = ExtensionA.getFunction5Value(i)
	return args
end

return ExtensionA
