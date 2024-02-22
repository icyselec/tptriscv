local Integer = require("tptriscv.classes.Integer")

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
		segment_size = 32,
		panic_when_fault = false,
		segment_map = {},
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
	setmetatable(o.debug.segment_map, { __index = function() return 0 end })

	return o
end

---@return nil
function Mem:print_debug_info ()
	print("segmentation: " .. tostring(self.debug.segmentation))
	print("segment_size: " .. tostring(self.debug.segment_size))
	print("panic_when_fault: " .. tostring(self.debug.panic_when_fault))
	print("segment_map: " .. tostring(self.debug.segment_map))
end


---@param ptr Pointer Pure address value.
---@return Address # Effective address value that can be used as a table index for Lua.
function Mem:get_effective_address (ptr) return bit.rshift(ptr, 2) + 1 end

---@deprecated
---@param ptr Pointer Pure address value.
---@return Address # Effective address value that can be used as a table index for Lua.
function Mem:get_ea (ptr) return self:get_effective_address(ptr) end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return u8
function Mem:read_u8 (ptr)
	---@type Index
	local i = bit.band(ptr, 3)
	---@type Integer
	local mask = 0xFF
	---@type Address
	local ea = Mem:get_effective_address(ptr)

	return bit.rshift(bit.band(self.data[ea], bit.lshift(mask, i * 8)), i * 8)
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val u8 If you want to store a value in memory, pass this value.
---@return nil
function Mem:write_u8 (ptr, val)
	---@type Index
	local i = bit.band(ptr, 3)
	---@type Integer
	local mask = 0xFF
	---@type Address
	local ea = Mem:get_effective_address(ptr)

	self.data[ea] = bit.bor(bit.band(self.data[ea], bit.bnot(bit.lshift(mask, i * 8))), bit.lshift(bit.band(val, mask), i * 8))
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return u16
function Mem:read_u16 (ptr)
	---@type Index
	local i = bit.rshift(bit.band(ptr, 3), 1)
	---@type Integer
	local mask = 0xFFFF
	---@type Address
	local ea = Mem:get_effective_address(ptr)

	return bit.rshift(bit.band(self.data[ea], bit.lshift(mask, i * 16)), i * 16)
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val u16 If you want to store a value in memory, pass this value.
---@return nil
function Mem:write_u16 (ptr, val)
	---@type Index
	local i = bit.rshift(bit.band(ptr, 3), 1)
	---@type Integer
	local mask = 0xFFFF
	---@type Address
	local ea = Mem:get_effective_address(ptr)

	self.data[ea] = bit.bor(bit.band(self.data[ea], bit.bnot(bit.lshift(mask, i * 16))), bit.lshift(bit.band(val, mask), i * 16))
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return u32
function Mem:read_u32 (ptr)
	---@type Address
	local ea = Mem:get_effective_address(ptr)

	return self.data[ea]
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val u32 If you want to store a value in memory, pass this value.
---@return nil
function Mem:write_u32 (ptr, val)
	---@type Address
	local ea = Mem:get_effective_address(ptr)

	self.data[ea] = val
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return i8
function Mem:read_i8 (ptr)
	---@type Index
	local i = bit.band(ptr, 3)
	---@type Integer
	local mask = 0xFF
	---@type Address
	local ea = Mem:get_effective_address(ptr)

	return bit.arshift(bit.lshift(bit.band(self.data[ea], bit.lshift(mask, i * 8)), (3 - i) * 8), 24)
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val i8 If you want to store a value in memory, pass this value.
---@return nil
function Mem:write_i8 (ptr, val)
	---@type Index
	local i = bit.band(ptr, 3)
	---@type Integer
	local mask = 0xFF
	---@type Address
	local ea = Mem:get_effective_address(ptr)

	self.data[ea] = bit.bor(bit.band(self.data[ea], bit.bnot(bit.lshift(mask, i * 8))), bit.lshift(bit.band(val, mask), i * 8))
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return i16
function Mem:read_i16 (ptr)
	---@type Index
	local i = bit.rshift(bit.band(ptr, 3), 1)
	---@type Integer
	local mask = 0xFFFF
	---@type Address
	local ea = self:get_effective_address(ptr)

	return bit.arshift(bit.lshift(bit.band(self.data[ea], bit.lshift(mask, (1 - i) * 16))), (1 - i) * 16)
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val i16 If you want to store a value in memory, pass this value.
---@return nil
function Mem:write_i16 (ptr, val)
	---@type Index
	local i = bit.rshift(bit.band(ptr, 3), 1)
	---@type Integer
	local mask = 0xFFFF
	---@type Address
	local ea = self:get_effective_address(ptr)

	self.data[ea] = bit.bor(bit.band(self.data[ea], bit.bnot(bit.lshift(mask, i * 16))), bit.lshift(bit.band(val, mask), i * 16))
end



---@param ptr Pointer Pure address value, not table index for Lua.
---@return i32
function Mem:read_i32 (ptr)
    return self:read_u32(ptr) --[[@as i32]]
end

---@param ptr Pointer Pure address value, not table index for Lua.
---@param val i32 If you want to store a value in memory, pass this value.
---@return nil
function Mem:write_i32 (ptr, val)
    return self:write_u32(ptr, val) --[[@as i32]]
end



---@param ptr Pointer
---@param mod number
---@return Integer|nil
function Mem:unsafe_read (ptr, mod)
	local rdOpTab = {
		-- LB (i8)
		function () return self:read_i8(ptr)  end,
		-- LH (i16)
		function () return self:read_i16(ptr) end,
		-- LW (i32)
		function () return self:read_i32(ptr) end,
		-- none
		function () return 0 end,
		-- LBU (u8)
		function () return self:read_u8(ptr)  end,
		-- LHU (u16)
		function () return self:read_u16(ptr) end,
		-- none
		function () return 0 end,
		-- none
		function () return 0 end,
	}

	return rdOpTab[mod]()
end

---@param ptr Pointer
---@param val Integer
---@param mod number
---@return nil
function Mem:unsafe_write (ptr, val, mod)
	local wrOpTab = {
		-- SB (i8/u8)
		function () self:write_i8(ptr, val) end,
		-- SH (i16/u16)
		function () self:write_i16(ptr, val) end,
		-- SW (i32/u32)
		function () self:write_i32(ptr, val) end,
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
function Mem:check_bound (ptr)
	local ea = self:get_effective_address(ptr)

	-- memory limit check
	if Integer:unsigned_comparer(ea, RV.MAX_MEMORY_WORD) then
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
---@return Integer
function Mem:safe_read (cpu, ptr, mod)
	if not Mem:check_bound(ptr) then
		cpu:halt("Mem:safe_read: Memory out of bound.")
	end

	local rdOpTab = {
		-- LB (i8)
		function () return self:read_i8(ptr)  end,
		-- LH (i16)
		function ()
			if cpu.conf.check_aligned then
				local sub_offset = bit.band(ptr, 1)
				if sub_offset ~= 0 then
					cpu:halt("Mem:safe_read: Attempt to access unaligned memory.")
					return 0
				end
			end

			return self:read_i16(ptr)
		end,
		-- LW (i32)
		function ()
			local offset = bit.band(ptr, 3)
			local case_tab = {
				function ()
					return self:read_i32(ptr)
				end,
				function ()
					cpu:halt("Mem:safe_read: Not Supported to load word using byte-addressing.")
				end,
				function ()
					return bit.bor(self:read_u16(ptr), bit.lshift(self:read_u16(ptr + 2), 16))
				end,
				function ()
					cpu:halt("Mem:safe_read: Not Supported to load word using byte-addressing.")
				end,
			}

			if offset ~= 0 and cpu.conf.check_aligned then
				cpu:halt("Mem:safe_read: Attempt to access unaligned memory.")
				return
			end

			return case_tab[offset + 1]()
		end,
		-- none
		function () return 0 end,
		-- LBU (u8)
		function () return self:read_u8(ptr)  end,
		-- LHU (u16)
		function ()
			if cpu.conf.check_aligned then
				local sub_offset = bit.band(ptr, 1)
				if sub_offset ~= 0 then
					cpu:halt("Mem:safe_read: Attempt to access unaligned memory.")
					return nil
				end
			end

			return self:read_u16(ptr)
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
function Mem:safe_write (cpu, ptr, mod, val)
	if not Mem:check_bound(ptr) then
		cpu:halt("Mem:safe_write: Memory out of bound.")
	end

	if self.debug.segmentation == true then
		local sub_ea = bit.rshift(ptr, 2)
		sub_ea = bit.rshift(sub_ea, self.debug.segment_size)
		if self.debug.segment_map[sub_ea] == true then
			if self.debug.panic_when_fault == true then
				cpu:halt("Segmentation fault")
				return
			end
		end
	end

	local wrOpTab = {
		-- SB (i8/u8)
		function () self:write_i8(ptr, val) end,
		-- SH (i16/u16)
		function ()
			if cpu.conf.check_aligned then
				local sub_offset = bit.band(ptr, 1)
				if sub_offset ~= 0 then
					cpu:halt("Mem:safe_write: Attempt to access misaligned memory.")
					return
				end
			end

			if not Mem:check_bound(ptr) then
				cpu:halt("Mem:safe_write: Memory out of bound.")
			end

			self:write_i16(ptr, val)
		end,
		-- SW (i32/u32)
		function ()
			local offset = bit.band(ptr, 3)

			if offset ~= 0 then
				if cpu.conf.check_aligned then
					cpu:halt("Mem:safe_write: Attempt to access misaligned memory.")
					return
				elseif bit.band(offset, 2) == 0 then
					self:write_u16(ptr, val)
					val = bit.rshift(val, 16)
					self:write_u16(ptr + 2, val)
					return
				else
					cpu:halt("Mem:safe_write: Attempt to access misaligned memory.")
					return
				end
			end

			if not Mem:check_bound(ptr) then
				cpu:halt("Mem:safe_write: Memory out of bound.")
			end

			self:write_i32(ptr, val)
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

function Mem:load_memory (base, size, filename)
	local f = assert(io.open(filename, "rb"))
	if f == nil then return false end

	local i = 0
	local found

	for line in f:lines() do
		found = string.find(line, "^[-][-]")

		if found == nil then
			self:write_i32(base + i, tonumber(line, 16))

			if i > size then
				break
			end

			i = i + 4
		end
	end

	f:close()
	return true
end

function Mem:dump_memory (base, size, filename)
	local f = assert(io.open(filename, "wb"))
	if f == nil then return false end
	local i = 0

	repeat
		local data = self:read_i32(base + i)
		f:write(string.format("%X\n", data))
		i = i + 4
	until i > size

	f:close()
	return true
end

return Mem
