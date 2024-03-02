---@class Reg
---@field private gp Integer[]
---@field private pc Integer
---@field private fp F64[]
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
function Reg:setGp (r, v)
	if r < 0 or r > 31 then
		print("Reg:set_gp: Invalid register access, register number is " .. tostring(r))
		return
	end

	if r == 0 then
		return
	end

	self.gp[r+1] = bit.tobit(v)
end

---@param r Integer The number of the register, the value is from 0 to 31.
---@return Integer
function Reg:getGp (r)
	return bit.tobit(self.gp[r+1])
end


---@param v U32 This is the value if you want to store the value in the program counter.
---@return nil
function Reg:setPc (v)
	self.pc = bit.band(v, 0xFFFFFFFF)
end

---@return U32
function Reg:getPc ()
	return self.pc --[[@as U32]]
end



---@param size U32 instruction length.
---@return nil
function Reg:updatePc (size)
	if size < 0 or size > 8 then
		return
	end

	self:setPc(self:getPc() + size)
end

--- get the ABI register name
---@param regNumber number Number of register.
---@return string|nil
function Reg:getAbiName (regNumber)
	local regTab = {
		"ZERO", "RA", "SP", "GP", "TP", "T0", "T1", "T2",
		"S0/FP", "S1", "A0", "A1", "A2", "A3", "A4", "A5",
		"A6", "A7", "S2", "S3", "S4", "S5", "S6", "S7",
		"S8", "S9", "S10", "S11", "T3", "T4", "T5", "T6",
	}

	return regTab[regNumber+1]
end

---@deprecated
--- get the register name
---@param regNumber number
---@return string|nil
function Reg:getname (regNumber)
	return Reg:getAbiName(regNumber)
end

return Reg
