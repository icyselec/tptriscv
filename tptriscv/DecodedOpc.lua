---@class DecodedOpc
---@field fun function
---@field rd0 number
---@field rs1 number
---@field rs2 number
---@field imm number
---@field fmt number
local DecodedOpc = {
	fun = function () end,
	rd0 = 0,
	rs1 = 0,
	rs2 = 0,
	imm = 0,
	fmt = 0, -- 0 = Invalid, 1 = R-Type, 2 = I-Type, 3 = S-Type, 4 = B-Type, 5 = U-Type, 6 = J-Type
	siz = 0,
}

return DecodedOpc
