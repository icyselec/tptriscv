local CsrEntry = require("tptriscv.classes.CsrEntry")

---@class Csr
local Csr = {
	csrTab = {

	},
}

function Csr:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function Csr:checkModifiable (address)
	if bit.band(address, 0xC00) == 0xC00 then
		return false
	end

	return true
end

function Csr:read (address)
	return self.csrTab[address + 1]
end

function Csr:write (address, input)
	if not Csr:checkModifiable(address) then
		return false
	end
end

function Csr:setBit (address, input)
	if not Csr:checkModifiable(address) then
		return false
	end
end

function Csr:clearBit (address, input)
	if not Csr:checkModifiable(address) then
		return false
	end
end

return Csr
