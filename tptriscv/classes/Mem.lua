local Boolean = require("tptriscv.classes.Boolean")

---@class Mem
local Mem = {
	conf = {
		bit_width = 32,
		size = RV.MAX_MEMORY_SIZE
	},
	stat = {},
	data = {},
	debug = {
		segmentation = false,
		segmentSize = 32,
		panicWhenFault = false,
		segmentMap = {},
		checkMemoryUsage = true,
		memoryUsage = 0,
	},
}

---@param o? table
---@nodiscard
---@return table
function Mem:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	setmetatable(o.data, { __index = function() return 0 end })
	setmetatable(o.debug.segmentMap, { __index = function() return 0 end })

	return o
end

function Mem:del ()
	self.conf = nil
	self.stat = nil
	self.data = nil
	self.debug = nil

	return true
end

---@return nil
function Mem:print_debug_info ()
	print("segmentation: " .. tostring(self.debug.segmentation))
	print("segment_size: " .. tostring(self.debug.segmentSize))
	print("panic_when_fault: " .. tostring(self.debug.panicWhenFault))
	print("segment_map: " .. tostring(self.debug.segmentMap))
end


---@param ptr Pointer Pure address value.
---@return Address # Effective address value that can be used as a table index for Lua.
function Mem:getEffectiveAddress (ptr) return bit.rshift(ptr, 2) + 1 end

---@deprecated
---@param ptr Pointer Pure address value.
---@return Address # Effective address value that can be used as a table index for Lua.
function Mem:getEa (ptr) return self:getEffectiveAddress(ptr) end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return integer|number
function Mem:readU8 (ptr)
	---@type Index
	local i = bit.band(ptr, 3)
	---@type Integer
	local mask = 0xFF
	---@type Address
	local ea = Mem:getEffectiveAddress(ptr)

	return bit.rshift(bit.band(self.data[ea], bit.lshift(mask, i * 8)), i * 8)
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val integer|number If you want to store a value in memory, pass this value.
---@return nil
function Mem:writeU8 (ptr, val)
	---@type Index
	local i = bit.band(ptr, 3)
	---@type Integer
	local mask = 0xFF
	---@type Address
	local ea = Mem:getEffectiveAddress(ptr)

	self.data[ea] = bit.band(self.data[ea], bit.bnot(bit.lshift(mask, i * 8))) + bit.lshift(bit.band(val, mask), i * 8)
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return integer|number
function Mem:readU16 (ptr)
	---@type Index
	local i = bit.rshift(bit.band(ptr, 3), 1)
	---@type Integer
	local mask = 0xFFFF
	---@type Address
	local ea = Mem:getEffectiveAddress(ptr)

	return bit.rshift(bit.band(self.data[ea], bit.lshift(mask, i * 16)), i * 16)
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val integer|number If you want to store a value in memory, pass this value.
---@return nil
function Mem:writeU16 (ptr, val)
	---@type Index
	local i = bit.rshift(bit.band(ptr, 3), 1)
	---@type Integer
	local mask = 0xFFFF
	---@type Address
	local ea = Mem:getEffectiveAddress(ptr)

	self.data[ea] = bit.bor(bit.band(self.data[ea], bit.bnot(bit.lshift(mask, i * 16))), bit.lshift(bit.band(val, mask), i * 16))
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return integer|number
function Mem:readU32 (ptr)
	---@type Address
	local ea = Mem:getEffectiveAddress(ptr)

	if self.debug.checkMemoryUsage then
		if self.debug.memoryUsage < ea then
			self.debug.memoryUsage = ea - 1
		end
	end

	return self.data[ea]
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val integer|number If you want to store a value in memory, pass this value.
---@return nil
function Mem:writeU32 (ptr, val)
	---@type Address
	local ea = Mem:getEffectiveAddress(ptr)

	self.data[ea] = val
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return integer|number
function Mem:readI8 (ptr)
	---@type Index
	local i = bit.band(ptr, 3)
	---@type Integer
	local mask = 0xFF
	---@type Address
	local ea = Mem:getEffectiveAddress(ptr)

	return bit.arshift(bit.lshift(bit.band(self.data[ea], bit.lshift(mask, i * 8)), (3 - i) * 8), 24)
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val integer|number If you want to store a value in memory, pass this value.
---@return nil
function Mem:writeI8 (ptr, val)
	---@type Index
	local i = bit.band(ptr, 3)
	---@type Integer
	local mask = 0xFF
	---@type Address
	local ea = Mem:getEffectiveAddress(ptr)

	self.data[ea] = bit.band(self.data[ea], bit.bnot(bit.lshift(mask, i * 8))) + bit.lshift(bit.band(val, mask), i * 8)
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return integer|number
function Mem:readI16 (ptr)
	---@type Index
	local i = bit.rshift(bit.band(ptr, 3), 1)
	---@type Integer
	local mask = 0xFFFF
	---@type Address
	local ea = self:getEffectiveAddress(ptr)

	return bit.arshift(bit.lshift(bit.band(self.data[ea], bit.lshift(mask, i * 16)), (1 - i) * 16), (1 - i) * 16)
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val integer|number If you want to store a value in memory, pass this value.
---@return nil
function Mem:writeI16 (ptr, val)
	---@type Index
	local i = bit.rshift(bit.band(ptr, 3), 1)
	---@type Integer
	local mask = 0xFFFF
	---@type Address
	local ea = self:getEffectiveAddress(ptr)

	self.data[ea] = bit.band(self.data[ea], bit.bnot(bit.lshift(mask, i * 16))) + bit.lshift(bit.band(val, mask), i * 16)
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return integer|number
function Mem:readI32 (ptr)
    return self:readU32(ptr) --[[@as I32]]
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val integer|number If you want to store a value in memory, pass this value.
---@return nil
function Mem:writeI32 (ptr, val)
	self:writeU32(ptr, val)
end



---@param ptr Pointer
---@param mod number
---@return integer|number
function Mem:unsafeRead (ptr, mod)
	local rdOpTab = {
		-- LB (i8)
		function () return self:readI8(ptr)  end,
		-- LH (i16)
		function () return self:readI16(ptr) end,
		-- LW (i32)
		function () return self:readI32(ptr) end,
		-- none
		function () return 0 end,
		-- LBU (u8)
		function () return self:readU8(ptr)  end,
		-- LHU (u16)
		function () return self:readU16(ptr) end,
		-- none
		function () return 0 end,
		-- none
		function () return 0 end,
	}

	return rdOpTab[mod]() --[[@as integer|number]]
end

---@param ptr Pointer
---@param val integer|number
---@param mod number
---@return nil
function Mem:unsafeWrite (ptr, val, mod)
	local wrOpTab = {
		-- SB (i8/u8)
		function () self:writeI8(ptr, val) end,
		-- SH (i16/u16)
		function () self:writeI16(ptr, val) end,
		-- SW (i32/u32)
		function () self:writeI32(ptr, val) end,
		-- none
		function () return nil end,
		-- none
		function () return nil end,
		-- none
		function () return nil end,
		-- none
		function () return nil end,
		-- none
		function () return nil end,
	}

	wrOpTab[mod]()
end


---@param ptr Address value to check if memory limits are exceeded
---@return nil
function Mem:checkBound (ptr)
	local ea = self:getEffectiveAddress(ptr)

	-- memory limit check
	if Boolean:exclusive_or(ea, RV.MAX_MEMORY_WORD) then
		if ea >= RV.MAX_MEMORY_WORD then
			return true
		else
			return false
		end
	else
		if ea >= RV.MAX_MEMORY_WORD then
			return false
		else
			return true
		end
	end
end


---@param cpu Cpu
---@param ptr Pointer
---@param mod number
---@return integer|number
function Mem:safeRead (cpu, ptr, mod)
	if not Mem:checkBound(ptr) then
		cpu:halt("Mem:safe_read: Memory out of bound.")
	end

	local rdOpTab = {
		-- LB (i8)
		function () return self:readI8(ptr)  end,
		-- LH (i16)
		function ()
			if cpu.conf.checkAligned then
				local sub_offset = bit.band(ptr, 1)
				if sub_offset ~= 0 then
					cpu:halt("Mem:safe_read: Attempt to access unaligned memory.")
					return 0
				end
			end

			return self:readI16(ptr)
		end,
		-- LW (i32)
		function ()
			local offset = bit.band(ptr, 3)
			local case_tab = {
				function ()
					return self:readI32(ptr)
				end,
				function ()
					cpu:halt("Mem:safe_read: Not Supported to load word using byte-addressing.")
				end,
				function ()
					return bit.bor(self:readU16(ptr), bit.lshift(self:readU16(ptr + 2), 16))
				end,
				function ()
					cpu:halt("Mem:safe_read: Not Supported to load word using byte-addressing.")
				end,
			}

			if offset ~= 0 and cpu.conf.checkAligned then
				cpu:halt("Mem:safe_read: Attempt to access unaligned memory.")
				return
			end

			return case_tab[offset + 1]()
		end,
		-- none
		function () return 0 end,
		-- LBU (u8)
		function () return self:readU8(ptr)  end,
		-- LHU (u16)
		function ()
			if cpu.conf.checkAligned then
				local sub_offset = bit.band(ptr, 1)
				if sub_offset ~= 0 then
					cpu:halt("Mem:safe_read: Attempt to access unaligned memory.")
					return nil
				end
			end

			return self:readU16(ptr)
		end,
		-- none
		function () return 0 end,
		-- none
		function () return 0 end,
	}

	return rdOpTab[mod]()
end

---@param cpu Cpu
---@param ptr Pointer
---@param mod number
---@param val Integer
---@return nil
function Mem:safeWrite (cpu, ptr, mod, val)
	if not Mem:checkBound(ptr) then
		cpu:halt("Mem:safe_write: Memory out of bound.")
	end

	if self.debug.segmentation then
		local sub_ea = bit.rshift(ptr, 2)
		sub_ea = bit.rshift(sub_ea, self.debug.segmentSize)
		if self.debug.segment_map[sub_ea] == true then
			if self.debug.panicWhenFault == true then
				cpu:halt("Segmentation fault")
				return
			end
		end
	end

	if self.debug.checkMemoryUsage then
		local ea = self:getEffectiveAddress(ptr)

		if self.debug.memoryUsage < ea then
			self.debug.memoryUsage = ea - 1
		end
	end

	local wrOpTab = {
		-- SB (i8/u8)
		function () self:writeI8(ptr, val) end,
		-- SH (i16/u16)
		function ()
			if cpu.conf.checkAligned then
				local subOffset = bit.band(ptr, 1)
				if subOffset ~= 0 then
					cpu:halt("Mem:safe_write: Attempt to access misaligned memory.")
					return
				end
			end

			if not Mem:checkBound(ptr) then
				cpu:halt("Mem:safe_write: Memory out of bound.")
			end

			self:writeI16(ptr, val)
		end,
		-- SW (i32/u32)
		function ()
			local offset = bit.band(ptr, 3)

			if offset ~= 0 then
				if cpu.conf.checkAligned then
					cpu:halt("Mem:safe_write: Attempt to access misaligned memory.")
					return
				elseif bit.band(offset, 2) == 0 then
					self:writeU16(ptr, val)
					val = bit.rshift(val, 16)
					self:writeU16(ptr + 2, val)
					return
				else
					cpu:halt("Mem:safe_write: Attempt to access misaligned memory.")
					return
				end
			end

			if not Mem:checkBound(ptr) then
				cpu:halt("Mem:safe_write: Memory out of bound.")
			end

			self:writeI32(ptr, val)
		end,
		-- none
		function () return nil end,
		-- none
		function () return nil end,
		-- none
		function () return nil end,
		-- none
		function () return nil end,
		-- none
		function () return nil end,
	}

	wrOpTab[mod]()
end

function Mem:loadMemory (base, size, filename)
	local f = assert(io.open(filename, "rb"))
	if f == nil then return false end

	local i = 0
	local found

	-- unlimited mode
	if size == -1 then
		size = RV.MAX_MEMORY_WORD
	end

	for line in f:lines() do
		found = string.find(line, "^[-][-]")

		if found == nil then
			self:writeI32(base + i * 4, tonumber(line, 16))

			if i > size then
				break
			end

			i = i + 1
		end
	end

	self.debug.memoryUsage = i

	f:close()
	return true
end

function Mem:dumpMemory (base, size, filename)
	local f = assert(io.open(filename, "wb"))
	if f == nil then return false end
	local i = 0

	-- unlimited mode, but the maximum limit is determined by memory usage.
	if size == -1 then
		size = self.debug.memoryUsage
	end

	repeat
		local data = self:readI32(base + i * 4)
		f:write(string.format("%X\n", data))
		i = i + 1
	until i > size

	f:close()
	return true
end

return Mem
