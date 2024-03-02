---@class CsrEntry
---@field private data number
---@field private wpri number
---@field private wlrl number
---@field private warl number
local CsrEntry = {
	data = 0,
	wpri = 0xFFFFFFFF,
	wlrl = 0,
	warl = 0,
}

function CsrEntry:new (data, wpri, wlrl, warl)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.data = data
	o.wpri = wpri
	o.wlrl = wlrl
	o.warl = warl

	return o
end

function CsrEntry:checkPrivilegeLevel (cpu)

end

function CsrEntry:getValue (cpu)
	local value = self.data
	value = bit.band(value, bit.bnot(self.wpri))
	return value
end

function CsrEntry:setValue (cpu, input)
	value = 0xFFFFFFFF - self.wpri
end


return CsrEntry
