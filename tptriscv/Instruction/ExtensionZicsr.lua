local CsrEntry = require("tptriscv.classes.CsrEntry")

local ExtensionZicsr = {}

--[[
CSRRW	CSRRS	CSRRC	CSRRWI	CSRRSI	CSRRCI
]]


function ExtensionZicsr:subDecoderCSRRWI (args)
	args.csr = args.imm
	args.imm = args.rs1
	args.fun = ExtensionZicsr.CSRRWI
	return args
end

function ExtensionZicsr:subDecoderCSRRSI (args)
	args.csr = args.imm
	args.imm = args.rs1
	args.fun = ExtensionZicsr.CSRRSI
	return args
end

function ExtensionZicsr:subDecoderCSRRCI (args)
	args.csr = args.imm
	args.imm = args.rs1
	args.fun = ExtensionZicsr.CSRRCI
	return args
end


function ExtensionZicsr:CSRRW (opc, cpu)

end

function ExtensionZicsr:CSRRS (opc, cpu)

end

function ExtensionZicsr:CSRRC (opc, cpu)

end

function ExtensionZicsr:CSRRWI (opc, cpu)

end

function ExtensionZicsr:CSRRSI (opc, cpu)

end

function ExtensionZicsr:CSRRCI (opc, cpu)

end


return ExtensionZicsr
