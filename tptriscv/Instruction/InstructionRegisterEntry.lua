---@class InstructionRegisterEntry
---@field opcodeName string
---@field opcodeFrom table
---@field subDecoder function
local InstructionRegisterEntry = {
	opcodeName = "",
	opcodeFrom = {},
	subDecoder = function () end, -- Valid Function Prototypes: function(args)
}

return InstructionRegisterEntry
