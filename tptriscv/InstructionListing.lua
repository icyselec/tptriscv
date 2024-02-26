local ExtensionI = require("tptriscv.Instruction.ExtensionI")

local InstructionListing =
{
	-- 000
	[1] = {
		-- 00
		{
			opType = RV.TYPE_I,
			opcode =
			{
				-- 000
				[1] = { opcodeName = "LB",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 001
				[2] = { opcodeName = "LH",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 010
				[3] = { opcodeName = "LW",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 010
				[4] = { opcodeName = nil,	opcodeFrom = nil,			subDecoder = nil, },
				-- 100
				[5] = { opcodeName = "LBU",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 101
				[6] = { opcodeName = "LHU",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 110
				[7] = { opcodeName = nil,	opcodeFrom = nil,			subDecoder = nil, },
				-- 111
				[8] = { opcodeName = nil,	opcodeFrom = nil,			subDecoder = nil, },
			}
		},
		-- 01
		{
			opType = RV.TYPE_S,
			opcode =
			{
				-- 000
				[1] = { opcodeName = "SB",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 001
				[2] = { opcodeName = "SH",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 010
				[3] = { opcodeName = "SW",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 011
				[4] = { opcodeName = nil,	opcodeFrom = nil,			subDecoder = nil, },
				-- 100
				[5] = { opcodeName = nil,	opcodeFrom = nil,			subDecoder = nil, },
				-- 101
				[6] = { opcodeName = nil,	opcodeFrom = nil,			subDecoder = nil, },
				-- 110
				[7] = { opcodeName = nil,	opcodeFrom = nil,			subDecoder = nil, },
				-- 111
				[8] = { opcodeName = nil,	opcodeFrom = nil,			subDecoder = nil, },
			}
		},
		-- 10
		{
			opType = 0,
		},
		-- 11
		{
			opType = RV.TYPE_B,
			opcode =
			{
				-- 000
				[1] = { opcodeName = "BEQ",		opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 001
				[2] = { opcodeName = "BNE",		opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 010
				[3] = { opcodeName = nil,		opcodeFrom = nil,			subDecoder = nil, },
				-- 011
				[4] = { opcodeName = nil,		opcodeFrom = nil,			subDecoder = nil, },
				-- 100
				[5] = { opcodeName = "BLT",		opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 101
				[6] = { opcodeName = "BGE",		opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 110
				[7] = { opcodeName = "BLTU",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 111
				[8] = { opcodeName = "BGEU",	opcodeFrom = ExtensionI,	subDecoder = nil, },
			}
		},
	},
	-- 001
	[2] = {
		-- 00
		{ opType = 0, },
		-- 01
		{ opType = 0, },
		-- 10
		{ opType = 0, },
		-- 11
		{
			opType = RV.TYPE_I,
			opcode =
			{
				-- 000
				[1] = { opcodeName = "JALR",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 001
				[2] = { opcodeName = nil,		opcodeFrom = nil,			subDecoder = nil, },
				-- 010
				[3] = { opcodeName = nil,		opcodeFrom = nil,			subDecoder = nil, },
				-- 011
				[4] = { opcodeName = nil,		opcodeFrom = nil,			subDecoder = nil, },
				-- 100
				[5] = { opcodeName = nil,		opcodeFrom = nil,			subDecoder = nil, },
				-- 101
				[6] = { opcodeName = nil,		opcodeFrom = nil,			subDecoder = nil, },
				-- 110
				[7] = { opcodeName = nil,		opcodeFrom = nil,			subDecoder = nil, },
				-- 111
				[8] = { opcodeName = nil,		opcodeFrom = nil,			subDecoder = nil, },
			}
		},
	},
	-- 010
	[3] = {
		-- 00
		{ opType = 0, },
		-- 01
		{ opType = 0, },
		-- 10
		{ opType = 0, },
		-- 11
		{ opType = 0, },
	},
	-- 011
	[4] = {
		-- 00
		{ opType = 0, },
		-- 01
		{ opType = 0, },
		-- 10
		{ opType = 0, },
		-- 11
		{ opType = RV.TYPE_U, opcode = { opcodeName = nil, opcodeFrom = ExtensionI, subDecoder = ExtensionI.subDecoderJAL, }, },
	},
	-- 100
	[5] = {
		-- 00
		{
			opType = RV.TYPE_I,
			opcode =
			{
				-- 000
				[1] = { opcodeName = "ADDI",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 001
				[2] = { opcodeName = nil,		opcodeFrom = ExtensionI,	subDecoder = ExtensionI.subDecoderSLLI },
				-- 010
				[3] = { opcodeName = "SLTI",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 011
				[4] = { opcodeName = "SLTIU",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 100
				[5] = { opcodeName = "XORI",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 101
				[6] = { opcodeName = nil,		opcodeFrom = ExtensionI,	subDecoder = ExtensionI.subDecoderSRLI_SRAI },
				-- 110
				[7] = { opcodeName = "ORI",		opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 111
				[8] = { opcodeName = "ANDI",	opcodeFrom = ExtensionI,	subDecoder = nil, },
			}
		},
		-- 01
		{
			opType = RV.TYPE_R,
			opcode =
			{
				-- 000
				[1] = { opcodeName = nil,		opcodeFrom = ExtensionI,	subDecoder = ExtensionI.subDecoderADD_SUB, },
				-- 001
				[2] = { opcodeName = nil,		opcodeFrom = ExtensionI,	subDecoder = ExtensionI.subDecoderSLL, },
				-- 010
				[3] = { opcodeName = "SLT",		opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 011
				[4] = { opcodeName = "SLTU",	opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 100
				[5] = { opcodeName = "XOR",		opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 101
				[6] = { opcodeName = nil,		opcodeFrom = ExtensionI,	subDecoder = ExtensionI.subDecoderSRL_SRA, },
				-- 110
				[7] = { opcodeName = "OR",		opcodeFrom = ExtensionI,	subDecoder = nil, },
				-- 111
				[8] = { opcodeName = "AND",		opcodeFrom = ExtensionI,	subDecoder = nil, },
			}
		},
		-- 10
		{ opType = 0, },
		-- 11
		{ opType = 0, },
	},
	-- 101
	[6] = {
		-- 00
		{ opType = RV.TYPE_U, opcode = { opcodeName = "AUIPC",	opcodeFrom = ExtensionI,	subDecoder = nil, }, },
		-- 01
		{ opType = RV.TYPE_U, opcode = { opcodeName = "LUI",	opcodeFrom = ExtensionI,	subDecoder = nil, }, },
		-- 10
		{ opType = 0, },
		-- 11
		{ opType = 0, },
	},
	-- 110
	[7] = {
		-- 00
		{ opType = 0, },
		-- 01
		{ opType = 0, },
		-- 10
		{ opType = 0, },
		-- 11
		{ opType = 0, },
	},
	-- 111
	[8] = {
		-- 00
		{ opType = 0, },
		-- 01
		{ opType = 0, },
		-- 10
		{ opType = 0, },
		-- 11
		{ opType = 0, },
	},
}

return InstructionListing
