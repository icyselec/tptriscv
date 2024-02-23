---@class Reg
---@field private gp Integer[]
---@field private pc Integer
---@field private fp f64[]
---@field private fcsr Integer
local Reg = {
	-- general-purpose register
	gp = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,},
	-- program counter
	pc = 0,
	-- double precision floating-point register
	fp = {0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,},
	fcsr = 0,
}

---@param o? table
---@nodiscard
---@return table
function Reg:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Reg:del ()
	self.gp = nil
	self.fp = nil
	return true
end

---@param r Integer The number of the register, the value is from 0 to 31.
---@param v Integer This is the value if you want to store the value in the register.
---@return nil
function Reg:set_gp (r, v)
	if r < 0 or r > 31 then
		print("Reg:set_gp: Invalid register access, register number is " .. tostring(r))
		return
	end

	if r == 0 then
		return
	end

	self.gp[r+1] = bit.band(v, 0xFFFFFFFF)
end

---@param r Integer The number of the register, the value is from 0 to 31.
---@return Integer
function Reg:get_gp (r)
	return self.gp[r+1]
end


---@param v u32 This is the value if you want to store the value in the program counter.
---@return nil
function Reg:set_pc (v)
	self.pc = bit.band(v, 0xFFFFFFFF)
end

---@return u32
function Reg:get_pc ()
	return self.pc
end



---@param size u32 instruction length.
---@return nil
function Reg:update_pc (size)
	if size < 0 or size > 8 then
		return
	end

	self:set_pc(self:get_pc() + size)
end

--- get the register assembly symbol
---@param reg_number number Number of register.
---@return string|nil
function Reg:getname (reg_number)
	local regtab = {
		"ZERO", "RA", "SP", "GP", "TP", "T0", "T1", "T2",
		"S0/FP", "S1", "A0", "A1", "A2", "A3", "A4", "A5",
		"A6", "A7", "S2", "S3", "S4", "S5", "S6", "S7",
		"S8", "S9", "S10", "S11", "T3", "T4", "T5", "T6",
	}

	return regtab[reg_number+1]
end

return Reg
