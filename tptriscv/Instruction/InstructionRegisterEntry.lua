---@class InstructionRegisterEntry
---@field opcodeType number
---@field opcodeName string
---@field opcodeFrom table
---@field subDecoder function
local InstructionRegisterEntry = {
	opcodeType = 0,
	opcodeName = "",
	opcodeFrom = {},
	subDecoder = function () end, -- Valid Function Prototypes: function(args)
}

return InstructionRegisterEntry
