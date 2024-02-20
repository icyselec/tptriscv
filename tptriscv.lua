--[[
Implement the RISC-V instruction set on TPT.
Copyright (C) 2024  icyselec

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
]]

-- RISC-V 32-Bit Emulator for 'The Powder Toy'


-- created new namespace for code re-factoring
rv = {}
-- created new namespace for constants
RV = {}

-- It prevents access to undeclared or uninitialized variables and print the name of variable.
-- source by LBPHacker
-- License: Do Whatever You Want With It 42.0™
do
	local old_env = getfenv(1)
	local env = setmetatable({}, { __index = function(_, key)
		error("__index on env: " .. tostring(key), 2)
	end, __newindex = function(_, key)
		error("__newindex on env: " .. tostring(key), 2)
	end })
	for key, value in pairs(old_env) do
		rawset(env, key, value)
	end
	setfenv(1, env)
end

rv.decode = {}
rv.permissions = {}

-- definition constants
RV.MAX_MEMORY_WORD = 65536 -- 256 kiB limit
RV.MAX_MEMORY_SIZE = RV.MAX_MEMORY_WORD * 4
RV.MAX_FREQ_MULTIPLIER = 1667
RV.MAX_TEMPERATURE = 120.0
RV.MOD_IDENTIFIER = "FREECOMPUTER"
RV.EXTENSIONS = {"RV32I"}

local Cpu = {
	conf = {
		ref_instance = nil,
		-- frequency of operation per frame The effective frequency is calculated as follows (multiplier * maximum frame limit) * (current frame count / maximum frame limit)
		freq = 1,
		exts = { "RV32I", "RV32C", "RV32D" },
		enable_rv32c = false,
		check_aligned = false,
	},
	stat = {
		is_halted = false,
		is_aligned = true,
		is_waiting = false,
		online = true,
	},
	regs = {
		-- general-purpose register
		gp = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,},
		-- program counter
		pc = 0,
		-- double precision floating-point register
		fp = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,},
		fcsr = 0,
	},
}

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

function Cpu:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Cpu:access_gp (r, v)
	if r < 0 or r > 31 then
		rv.throw("Cpu:access_gp: Invalid register access, register number is " .. tostring(r))
		return
	end

	r = r + 1

	if v == nil then
		return self.regs.gp[r]
	elseif r == 1 then -- write protection to zero register
		return
	end

	self.regs.gp[r] = bit.band(v, 0xFFFFFFFF)
end

function Cpu:fetch_instruction (compact_mode)
	local mem = self.conf.ref_instance.mem

	if compact_mode then
		return mem:access(self, self.regs.pc, 6)
	else
		return mem:access(self, self.regs.pc, 3)
	end
end

function Cpu:update_pc (compact_mode)
	compact_mode = compact_mode or false

	if compact_mode then
		self:access_pc(self:access_pc() + 2)
		self.stat.is_aligned = false
	else
		self:access_pc(self:access_pc() + 4)
	end
end

function Cpu:access_pc (v)
	if v == nil then
		return self.regs.pc
	else
		self.regs.pc = bit.band(v, 0xFFFFFFFF)
	end
end

function Cpu:access_stat (name, status)
	if status == nil then
		return self.stat[name]
	else
		self.stat[name] = status
	end
end

function Cpu:halt (msg)

end

function Cpu:print_debug_info ()

end



function Mem:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	setmetatable(o.data, { __index = function(self) return 0 end })
	setmetatable(o.debug.segment_map, { __index = function(self) return 0 end })

	return o
end

function Mem:raw_access (addr, mode, data)
	local ea = bit.rshift(addr, 2) + 1
	local offset = 0

	local function report_error (cmd, msg)
		rv.throw("Mem:raw_access: " .. cmd .. " failed, " .. msg)
	end

	local rdOpTab = {
		-- LB
		function ()
			offset = bit.band(addr, 3)
			return bit.arshift(bit.lshift(bit.band(self.data[ea], bit.lshift(0xFF, offset * 8)), (3 - offset) * 8), offset * 8)
		end,
		-- LH
		function ()
			offset = bit.rshift(bit.band(addr, 3), 1)
			return bit.arshift(bit.lshift(bit.band(self.data[ea], bit.lshift(0xFFFF, offset * 16))), offset * 16)
		end,
		-- LW
		function ()
			offset = bit.band(addr, 3)
			return self.data[ea]
		end,
		-- none
		function ()
			return nil
		end,
		-- LBU
		function ()
			offset = bit.band(addr, 3)
			local retval = bit.rshift(bit.band(self.data[ea], bit.lshift(0xFF, offset * 8)), offset * 8)
			return retval
		end,
		-- LHU
		function ()
			offset = bit.rshift(bit.band(addr, 3), 1)
			return bit.rshift(bit.band(self.data[ea], bit.lshift(0xFFFF, offset * 16)), offset * 16)
		end,
		-- none
		function ()
			return nil
		end,
		-- none
		function ()
			return nil
		end,
	}

	local wrOpTab = {
		-- SB
		function ()
			offset = bit.band(addr, 3)
			self.data[ea] = bit.bor(bit.band(self.data[ea], bit.bnot(bit.lshift(0xFF, offset * 8))), bit.lshift(bit.band(data, 0xFF), offset * 8))
			return true
		end,
		-- SH
		function ()
			offset = bit.rshift(bit.band(addr, 3), 1)
			self.data[ea] = bit.bor(bit.band(self.data[ea], bit.bnot(bit.lshift(0xFFFF, offset * 16))), bit.lshift(bit.band(data, 0xFFFF), offset * 16))
			return true
		end,
		-- SW
		function ()
			offset = bit.band(addr, 3)
			self.data[ea] = data
			return true
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

	local func

	if data == nil then
		func = rdOpTab[mode]
	else
		func = wrOpTab[mode]
	end

	if func == nil then return nil end
	return func()
end


function Mem:access (core, addr, mode, data)
	local retval

	local ea = bit.rshift(addr, 2) + 1
	local offset = 0

	local function report_error (cmd, msg)
		rv.throw("Mem:access: " .. cmd .. " failed, " .. msg)
	end

	-- memory limit check
	if bit.bxor(bit.band(ea, 0x80000000), bit.band(RV.MAX_MEMORY_WORD, 0x80000000)) == 0 then
		if ea > RV.MAX_MEMORY_WORD then
			rv.throw("Mem:Access: Memory out of bound.")
			return nil
		end
	else
		if ea < RV.MAX_MEMORY_WORD then
			rv.throw("Mem:Access: Memory out of bound.")
			return nil
		end
	end

	if self.debug.segmentation == true then
		local ea = bit.rshift(addr, 2)
		ea = bit.rshift(ea, self.debug.segment_size)
		if val ~= nil and self.debug.segment_map[ea] == true then
			if self.debug.panic_when_fault == true then
				rv.panic()
			end
		end
	end


	local rdOpTab = {
		-- LB
		function ()
			offset = bit.band(addr, 3)
			return bit.arshift(bit.lshift(bit.band(self.data[ea], bit.lshift(0xFF, offset * 8)), (3 - offset) * 8), offset * 8)
		end,
		-- LH
		function ()
			offset = bit.rshift(bit.band(addr, 3), 1)

			if core.conf.check_aligned then
				local sub_offset = bit.band(addr, 1)
				if sub_offset ~= 0 then
					report_error("LH", "Attempt to access unaligned memory.")
					return
				end
			end

			return bit.arshift(bit.lshift(bit.band(self.data[ea], bit.lshift(0xFFFF, offset * 16))), offset * 16)
		end,
		-- LW
		function ()
			offset = bit.band(addr, 3)
			local case_tab = {
				function ()
					return self.data[ea]
				end,
				function ()
					report_error("LW", "Not Supported load word using byte-addressing.")
					return
				end,
				function ()
					local retval = self:access(core, addr, 6)
					return bit.bor(retval, bit.lshift(self:access(core, addr + 2, 6), 16))
				end,
				function ()
					report_error("LW", "Not Supported load word using byte-addressing.")
					return
				end,
			}

			if offset ~= 0 and core.conf.check_aligned then
				report_error("LW", "Attempt to access unaligned memory.")
				return
			end

			local func = case_tab[offset + 1]
			return func()
		end,
		-- none
		function ()
			return nil
		end,
		-- LBU
		function ()
			offset = bit.band(addr, 3)
			local retval = bit.rshift(bit.band(self.data[ea], bit.lshift(0xFF, offset * 8)), offset * 8)
			return retval
		end,
		-- LHU
		function ()
			offset = bit.rshift(bit.band(addr, 3), 1)
			if core.conf.check_aligned then
				local sub_offset = bit.band(addr, 1)
				if sub_offset ~= 0 then
					report_error("LHU", "Attempt to access unaligned memory.")
					return nil
				end
			end

			return bit.rshift(bit.band(self.data[ea], bit.lshift(0xFFFF, offset * 16)), offset * 16)
		end,
		-- none
		function ()
			return nil
		end,
		-- none
		function ()
			return nil
		end,
	}

	local wrOpTab = {
		-- SB
		function ()
			offset = bit.band(addr, 3)
			self.data[ea] = bit.bor(bit.band(self.data[ea], bit.bnot(bit.lshift(0xFF, offset * 8))), bit.lshift(bit.band(data, 0xFF), offset * 8))
			return true
		end,
		-- SH
		function ()
			if core.conf.check_aligned then
				local sub_offset = bit.band(addr, 1)
				if sub_offset ~= 0 then
					report_error("SH", "Attempt to access misaligned memory.")
					return
				end
			end

			offset = bit.rshift(bit.band(addr, 3), 1)
			self.data[ea] = bit.bor(bit.band(self.data[ea], bit.bnot(bit.lshift(0xFFFF, offset * 16))), bit.lshift(bit.band(data, 0xFFFF), offset * 16))
			return true
		end,
		-- SW
		function ()
			offset = bit.band(addr, 3)
			if offset ~= 0 then
				if core.conf.check_aligned then
					report_error("SW", "Attempt to access misaligned memory.")
					return nil
				elseif bit.band(offset, 2) == 0 then
					self:access(core, addr, 2, data)
					val = bit.rshift(val, 16)
					self:access(core, addr + 2, 2, data)
					return true
				else
					report_error("SW", "Attempt to access misaligned memory.")
					return nil
				end
			end

			self.data[ea] = data
			return true
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

	local func

	if data == nil then
		func = rdOpTab[mode]
	else
		func = wrOpTab[mode]
	end



	if func == nil then return nil end
	retval = func()

	if retval == nil then
		rv.throw("Mem:access: Not implemented instruction dectected. processor is halted.")
		core.stat.is_halted = true
		return nil
	end

	return retval
end

function Mem:load_memory (base, size, filename)
	local f = assert(io.open(filename, "rb"))
	local i = 0

	for line in f:lines() do
		self:raw_access(base + i, 3, tonumber(line, 16))
		if i > size then
			break
		end

		i = i + 4
	end

	f:close()
end

function Mem:dump_memory (base, size, filename)
	local f = assert(io.open(filename, "wb"))
	local i = 0

	repeat
		local data = self:raw_access(base + i, 3)
		f:write(string.format("%X\n", data))
		i = i + 4
	until i > size

	f:close()
end



local Instance = {
	cpu = {},
	mem = {},
	conf = {},
	stat = {},
}

rv.instance = {}

function Instance:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.cpu[1] = Cpu:new()
	o.cpu[1].conf.ref_instance = o

	o.mem = Mem:new()

	o.cpu[1].ref_mem = o.mem

	return o
end

function Instance:del (o)
	rv.instance[o.id] = nil
	self = nil
end

-- definition of permissions
rv.permissions.clipboard_access = nil

function rv.panic ()

end

function rv.throw (msg)
	print(msg)
end

function rv.get_permission (perm_name)
	if rv.permissions[perm_name] == false then
		return false
	end

	local title = "Grant Permission"
	local failed = ""
	local answer = ""
	local msg = "Approve the following permissions with y (or Y), deny n (or N). (Note: This message will never appear again once you deny it until you restart the game.)"
	msg = msg .. "\n" .. perm_name

	while answer == "y" or answer == "Y" do
		answer = tpt.input(msg .. failed)
		if failed == "" and (answer ~= "n" or answer ~= "N") then
			failed = "\n\nPlease answer correctly."
		elseif answer == "n" or answer == "N" then
			rv.permissions[perm_name] = false
			return false
		end
	end

	return true
end

function rv.try_permission (perm_name)
	if rv.permissions[perm_name] == nil then
		return rv.get_permission(perm_name)
	elseif rv.permissions[perm_name] == false then
		return false
	else return true end
end

function rv.print_debug_info(instance)
	local mem = instance.mem
	if mem == nil then
		return false
	end

	print("segmentation: " .. tostring(mem.debug.segmentation))
	print("segment_size: " .. tostring(mem.debug.segment_size))
	print("panic_when_fault: " .. tostring(mem.debug.panic_when_fault))
	print("segment_map: " .. tostring(mem.debug.segment_map))

	return true
end






--[[
==================================================================
==================== Define of RISC-V Decoder ====================
==================================================================

]]

function Cpu:decode_rv32c (cmd)
	local function decVal1_0 ()
		return bit.band(cmd, 0x3) + 1
	end

	local function decValFnt3 ()
		return bit.rshift(bit.band(cmd, 0xE000), 13) + 1
	end


	local decTab1_0 = {
		-- ==================== 00, C.ADDI4SPN/C.FLD/C.LW/C.FLW/Reserved/C.FSD/C.SW/C.FSW
		function ()
			local rd = bit.rshift(bit.band(cmd, 0x001C), 2)
			local rs1 = bit.rshift(bit.band(cmd, 0x0380), 7)
			local rs2 = rd
			local uimm = bit.rshift(bit.band(cmd, 0x1C00), 7)
			uimm = bit.bor(uimm, bit.rshift(bit.band(cmd, 0x0040), 4))
			uimm = bit.bor(uimm, bit.lshift(bit.band(cmd, 0x0080), 1))

			local decTabFnt3 = {
				-- C.ADDI4SPN
				function ()
					local nzuimm = bit.rshift(bit.band(cmd, 0x1FE0), 5)
					if bit.band(cmd, 0x0000FFFF) == 0 then
						rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
						self:access_stat("online", false)
						return nil
					end

					self:access_gp(rd, self:access_gp(2) + nzuimm)
					return true
				end,
				-- C.FLD -- not yet implemented
				function ()
					rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- C.LW
				function ()
					local mem = self.ref_mem
					self:access_gp(rd, mem:access(self, self:access_gp(rs1) + uimm, 3))
				end,
				-- C.FLW
				function ()
					rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- Reserved
				function ()
					rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- C.FSD -- not yet implemented
				function ()
					rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- C.SW
				function ()
					local mem = self.ref_mem
					mem:access(self, self:access_gp(rs1) + uimm, 3, self:access_gp(rd_rs2))
				end,
				-- C.FSW
				function ()
					rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
			}

			return decTabFnt3[decValFnt3()]()
		end,
		-- ==================== 01,
		function ()
			local rs1 = bit.rshift(bit.band(cmd, 0x0F80), 7)
			local rs2 = bit.rshift(bit.band(cmd, 0x007C), 2)

			local decTabFnt3 = {
				-- C.NOP/C.ADDI
				function ()
					local  imm6 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm6 = imm6 + bit.lshift(rs2, 28)
					imm6 = bit.arshift(imm6, 26)

					if rs1 == 0 and imm6 == 0 then
						return true -- C.NOP
					elseif imm6 == 0 then
						return false
					end

					self:access_gp(rs1, self:access_gp(rs1) + imm6)
					self:update_pc(true)
					return true
				end,
				-- C.JAL (ADDIW is RV64/RV128 only)
				function ()
					local   imm11 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0100), 22)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0600), 19)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0040), 17)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0080), 19)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0004), 23)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0800), 14)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0038), 18)
					imm11 = bit.arshift(imm11, 23)

					self:access_gp(1, self:access_pc() + 2)
					self:access_pc(self:access_pc() + imm11)
				end,
				-- C.LI
				function ()
					if rs1 == 0 then
						return false
					end

					local  imm6 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm6 = imm6 + bit.lshift(rs2, 28)
					imm6 = bit.arshift(imm6, 26)

					self:access_gp(rs1, imm6)
					self:update_pc(true)
					return true
				end,
				-- C.ADDI16SP/C.LUI
				function ()
					-- HINT
					if rs1 == 0 then
						return false
					-- C.ADDI16SP
					elseif rs1 == 2 then
						local     imm16sp = bit.lshift(bit.band(cmd, 0x1000), 19)
						imm16sp = imm16sp + bit.lshift(bit.band(cmd, 0x0018), 26)
						imm16sp = imm16sp + bit.lshift(bit.band(cmd, 0x0020), 23)
						imm16sp = imm16sp + bit.lshift(bit.band(cmd, 0x0004), 25)
						imm16sp = imm16sp + bit.lshift(bit.band(cmd, 0x0040), 20)
						imm16sp = bit.arshift(imm16sp, 22)

						self:access_gp(rs1, self:access_gp(rs1) + imm16sp)
					-- C.LUI
					else
						local  imm6 = bit.lshift(bit.band(cmd, 0x1000), 19)
						imm6 = imm6 + bit.lshift(rs2, 28)
						imm6 = bit.arshift(imm6, 14)

						self:access_gp(rs1, imm6)
					end

					self:update_pc(true)
					return true
				end,
				-- C.SRLI/C.SRAI/C.ANDI/C.SUB/C.XOR/C.OR/C.AND
				function ()
					local rd = bit.band(rs1, 0x7)

					local decTabFnt2 = {
						-- C.SRLI
						function ()
							if bit.band(cmd, 0x1000) ~= 0 then
								rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
								self:access_stat("online", false)
								return nil
							end

							self:access_gp(rd, bit.rshift(self:access_gp(rd), rs2))
							self:update_pc(true)
							return true
						end,
						-- C.SRAI
						function ()
							if bit.band(cmd, 0x1000) ~= 0 then
								rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
								self:access_stat("online", false)
								return nil
							end

							self:access_gp(rd, bit.arshift(self:access_gp(rd), rs2))
							self:update_pc(true)
							return true
						end,
						-- C.ANDI
						function ()
							local imm6 = rs2 + bit.arshift(bit.lshift(bit.band(cmd, 0x1000), 19), 26)

							self:access_gp(rd, bit.band(self:access_gp(rd), imm6))
							self:update_pc(true)
							return true
						end,
						-- C.SUB/C.XOR/C.OR/C.AND
						function ()
							local rs1 = bit.band(rs1, 0x7)
							local rs2 = bit.band(rs2, 0x7)
							local rd = rs1

							if bit.band(cmd, 0x1000) ~= 0 then
								rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
								self:access_stat("online", false)
								return nil
							end

							local decTabSubFnt2 = {
								function ()
									self:access_gp(rd, self:access_gp(rs1) - self:access_gp(rs2))
									return true
								end,
								function ()
									self:access_gp(rd, bit.bxor(self:access_gp(rs1), self:access_gp(rs2)))
									return true
								end,
								function ()
									self:access_gp(rd, bit.bor(self:access_gp(rs1), self:access_gp(rs2)))
									return true
								end,
								function ()
									self:access_gp(rd, bit.band(self:access_gp(rs1), self:access_gp(rs2)))
									return true
								end,
							}

							local retval = decTabSubFnt2[bit.rshift(bit.band(cmd, 0x0060), 5) + 1]()
							self:update_pc(true)
							return retval
						end,
					}

					return decTabFnt2[bit.rshift(bit.band(cmd, 0x0C00), 10) + 1]()
				end,
				-- C.J
				function ()
					local   imm11 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0100), 22)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0600), 19)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0040), 17)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0080), 19)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0004), 23)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0800), 14)
					imm11 = imm11 + bit.lshift(bit.band(cmd, 0x0038), 18)
					imm11 = bit.arshift(imm11, 23)

					self:access_pc(self:access_pc() + imm11)
					return true
				end,
				-- C.BEQZ
				function ()
					local  imm8 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0060), 24)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0004), 26)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0C00), 16)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0018), 21)
					imm8 = bit.arshift(imm8, 26)

					if self:access_gp(bit.band(rs1, 0x7)) == 0 then
						self:access_pc(self:access_pc() + imm8)
						return true
					end

					self:update_pc(true)
					return false
				end,
				-- C.BNEZ
				function ()
					local  imm8 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0060), 24)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0004), 26)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0C00), 16)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0018), 21)
					imm8 = bit.arshift(imm8, 26)

					if self:access_gp(bit.band(rs1, 0x7)) ~= 0 then
						self:access_pc(self:access_pc() + imm8)
						return true
					end

					self:update_pc(true)
					return false
				end,
			}
		end,
		-- ==================== 10,
		function ()
			local rd = bit.rshift(bit.band(cmd, 0x0F80), 7)
			local rs1 = rd
			local rs2 = bit.rshift(bit.band(cmd, 0x007C), 2)
			local imm1 = bit.rshift(bit.band(cmd, 0x1000), 7)

			local decTabFnt3 = {
				-- C.SLLI
				function ()
					local nzuimm = imm1 + rs2

					if rd == 0 then
						return false
					end

					self:access_gp(rd, bit.lshift(self:access_gp(rd), nzuimm))
					self:update_pc(true)
					return true
				end,
				-- C.FLDSP
				function ()
					rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- C.LWSP
				function ()
					local mem = self.ref_mem
					local uimm = imm1 + bit.rshift(bit.band(cmd, 0x0070), 2) + bit.lshift(bit.band(cmd, 0x00C0), 4)
					self:access_gp(rd, mem:access(self, self:access_gp(2) + uimm, 3))
					self:update_pc(true)
				end,
				-- C.FLWSP (Not Implement)
				function ()
					rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- C.JR/C.MV/C.EBREAK/C.JALR/C.ADD
				function ()
					if bit.band(cmd, 0x1000) == 0 then
						-- C.MV
						if rd ~= 0 and rs2 ~= 0 then
							self:access_gp(rd, self:access_gp(rs2))
							self:update_pc(true)
						-- C.JR
						elseif rd ~= 0 and rs2 == 0 then
							self:access_pc(self:access_gp(rs1))
						end
					else
						-- C.EBREAK
						if rs1 == 0 and rs2 == 0 then

						-- C.JALR
						elseif rs1 ~= 0 and rs2 == 0 then
							local backup = self:access_gp(rs1)
							self:access_gp(1, self:access_pc() + 2)
							self:access_pc(backup)
						elseif rs1 ~= 0 and rs2 ~= 0 then
							self:access_gp(rd, self:access_gp(rs1) + self:access_gp(rs2))
							self:update_pc(true)
						end
					end

					return true
				end,
				-- C.FSDSP
				function ()
					rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- C.SWSP
				function ()
					local mem = self.ref_mem
					local uimm = bit.lshift(rs1, 2) + bit.rshift(bit.band(cmd, 0x1000), 5)
					self:access_gp(rd, mem:access(self, self:access_gp(2) + uimm, 3, self:access_gp(rs2)))
					self:update_pc(true)
				end,
				-- C.FSWSP (Not Implement)
				function ()
					rv.throw("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
			}

			return decTabFnt3[decValFnt3()]()
		end,
	}

	return decTab1_0[decVal1_0()]()
end

function Cpu:decode_rv32i (cmd)
	local retval
	local mem = self.ref_mem

	local function decVal4_2 ()
		return bit.rshift(bit.band(cmd, 0x1C), 2) + 1
	end

	local function decVal6_5 ()
		return bit.rshift(bit.band(cmd, 0x60), 5) + 1
	end

	local function decValFnt3 ()
		return bit.rshift(bit.band(cmd, 0x7000), 12) + 1
	end

	local decTab4_2 = {
		-- ========== 000
		function ()
			local rd = bit.rshift(bit.band(cmd, 0x00000F80), 7)
			local rs1 = bit.rshift(bit.band(cmd, 0x000F8000), 15)
			local rs2 = bit.rshift(bit.band(cmd, 0x01F00000), 20)


			local decTab6_5 = {
				-- LB/LH/LW/LBU/LHU
				function ()
					local imm = bit.arshift(bit.band(cmd, 0xFFF00000), 20)
					self:access_gp(rd, mem:access(self, self:access_gp(rs1) + imm, decValFnt3()))
					self:update_pc(false)
				end,
				-- SB/SH/SW
				function ()
					local imm = bit.bor(bit.arshift(bit.band(cmd, 0xFE000000), 20), rd)
					mem:access(self, self:access_gp(rs1) + imm, decValFnt3(), self:access_gp(rs2))
					self:update_pc(false)
				end,
				function ()
					rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- BEQ/BNE/BLT/BGE/BLTU/BGEU
				function ()
					local rs1_value = self:access_gp(rs1)
					local rs2_value = self:access_gp(rs2)

					local decTabFnt3 = {
						-- BEQ
						function ()
							if rs1_value == rs2_value then
								return true
							end

							return false
						end,
						-- BNE
						function ()
							if rs1_value ~= rs2_value then
								return true
							end

							return false
						end,
						-- BLT
						function ()
							if rs1_value < rs2_value then
								return true
							end

							return false
						end,
						-- BGE
						function ()
							if rs1_value >= rs2_value then
								return true
							end

							return false
						end,
						-- BLTU
						function ()
							local rs1_value = self:access_gp(rs1)
							local rs2_value = self:access_gp(rs2)

							-- If both numbers are positive, just compare them. If not, reverse the comparison condition.
							if bit.bxor(bit.band(rs1_value, 0x80000000), bit.band(rs2_value, 0x80000000)) == 0 then
								if rs1_value < rs2Value then
									return true
								end
							else
								if rs1Value > rs2Value then
									return true
								end
							end

							return false
						end,
						-- BGEU
						function ()
							local rs1_value = self:access_gp(rs1)
							local rs2_value = self:access_gp(rs2)

							if rs1_value == rs2_value then
								return true
							elseif bit.bxor(bit.band(rs1_value, 0x80000000), bit.band(rs2_value, 0x80000000)) == 0 then
								if rs1_value >= rs2_value then
									return true
								end
							else
								if rs1_value < rs2_value then
									return true
								end
							end

							return false
						end,
						-- none
						function () return nil end,
						-- none
						function () return nil end,
					}

					local func = decTabFnt3[decValFnt3()]
					local retval = func()

					if not retval then self:update_pc(false)
					elseif retval then
						local imm = bit.band(cmd, 0x80000000)
						imm = bit.bor(imm, bit.rshift(bit.band(cmd, 0x7E000000), 1))
						imm = bit.bor(imm, bit.lshift(bit.band(cmd, 0x00000080), 23))
						imm = bit.bor(imm, bit.lshift(bit.band(cmd, 0x00000F00), 12))
						imm = bit.arshift(imm, 19)

						self:access_pc(self:access_pc() + imm)
					end

					return retval
				end,
			}

			return decTab6_5[decVal6_5()]()
		end,
		-- ========== 001
		function ()
			local decTab6_5 = {
				function ()
					rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				function ()
					rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				function ()
					rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- JALR
				function ()
					local rd = bit.rshift(bit.band(cmd, 0x00000F80), 7)
					local rs1 = bit.rshift(bit.band(cmd, 0x000F8000), 15)
					local imm = bit.arshift(bit.band(cmd, 0xFFF00000), 20)

					if bit.band(cmd, 0x00007000) ~= 0 then
						return nil
					end

					local backup = self:access_pc()

					self:access_pc(bit.band(self:access_gp(rs1) + imm, 0xFFFFFFFE)) -- then setting least-significant bit of the result to zero.
					self:access_gp(rd, backup)
				end,
			}

			return decTab6_5[decVal6_5()]()
		end,
		-- ========== 010
		function ()
			rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
			self:access_stat("online", false)
			return nil
		end,
		-- ========== 011
		function ()
			local rd = bit.rshift(bit.band(cmd, 0x00000F80), 7)
			local imm20 = bit.band(cmd, 0x80000000)
			imm20 = bit.bor(imm20, bit.rshift(bit.band(cmd, 0x7FE00000), 9))
			imm20 = bit.bor(imm20, bit.lshift(bit.band(cmd, 0x00100000), 2))
			imm20 = bit.bor(imm20, bit.lshift(bit.band(cmd, 0x000FF000), 11))
			imm20 = bit.arshift(imm20, 11)

			local decTab6_5 = {
				function ()
					return nil
				end,
				function ()
					return nil
				end,
				function ()
					return nil
				end,
				-- JAL
				function ()
					self:access_gp(rd, self:access_pc() + 4)
					self:access_pc(self:access_pc() + imm20)
				end,
			}

			return decTab6_5[decVal6_5()]()
		end,
		-- ========== 100
		function ()
			local rd = bit.rshift(bit.band(cmd, 0x00000F80), 7)
			local rs1 = bit.rshift(bit.band(cmd, 0x000F8000), 15)
			local decTab6_5 = {
				-- ========== 00
				function ()
					local imm = bit.arshift(bit.band(cmd, 0xFFF00000), 20)

					local decTabFnt3 = {
						-- ADDI
						function ()
							self:access_gp(rd, self:access_gp(rs1) + imm)
						end,
						-- SLLI
						function ()
							local shamt = bit.band(imm, 0x1F)
							if bit.rshift(bit.band(imm, 0xFE0), 5) == 0 then
								self:access_gp(rd, bit.lshift(self:access_gp(rs1), shamt))
							else
								rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
								self:access_stat("online", false)
								return nil
							end
						end,
						-- SLTI
						function ()
							if self:access_gp(rs1) < imm then
								self:access_gp(rd, 1)
							else
								self:access_gp(rd, 0)
							end
						end,
						-- SLTIU
						function ()
							local rs1_value = self:access_gp(rs1)

							if bit.bxor(bit.band(rs1_value, 0x80000000), bit.band(imm, 0x80000000)) == 0 then
								if rs1_value < imm then
									self:access_gp(rd, 1)
								end
							else
								if not (rs1_value > imm) then
									self:access_gp(rd, 0)
								end
							end
						end,
						-- XORI
						function ()
							self:access_gp(rd, bit.bxor(self:access_gp(rs1), imm))
						end,
						-- SRLI/SRAI
						function ()
							local shamt = bit.band(imm, 0x1F)

							local imm11_5 = bit.rshift(bit.band(imm, 0xFE0), 5)
							local op
							if imm11_5 == 0 then
								op = bit.rshift
							elseif imm11_5 == 0x20 then
								op = bit.arshift
							else
								rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
								self:access_stat("online", false)
								return nil
							end

							self:access_gp(rd, bit.band(op(self:access_gp(rs1), shamt), 0xFFFFFFFF))
						end,
						-- ORI
						function ()
							self:access_gp(rd, bit.bor(self:access_gp(rs1), imm))
						end,
						-- ANDI
						function ()
							self:access_gp(rd, bit.band(self:access_gp(rs1), imm))
						end
					}
					local retval = decTabFnt3[decValFnt3()]()

					self:update_pc(false)
					return retval
				end,
				-- ========== 01
				function ()
					local rs2 = bit.rshift(bit.band(cmd, 0x01F00000), 20)
					local fnt7 = bit.rshift(bit.band(cmd, 0xFE0000000), 29)

					local decTabFnt3 = {
						-- ADD/SUB
						function ()
							if fnt7 == 0 then
								self:access_gp(rd, self:access_gp(rs1) + self:access_gp(rs2))
							elseif fnt7 ~= 0 then
								self:access_gp(rd, self:access_gp(rs1) - self:access_gp(rs2))
							end

							return true
						end,
						-- SLL
						function ()
							self:access_gp(rd, bit.lshift(self:access_gp(rs1), self:access_gp(rs2)))
							return true
						end,
						-- SLT
						function ()
							if self:access_gp(rs1) < self:access_gp(rs2) then
								self:access_gp(rd, 1)
							else
								self:access_gp(rd, 0)
							end

							return true
						end,
						-- SLTU
						function ()
							local rs1_value = self:access_gp(rs1)
							local rs2_value = self:access_gp(rs2)

							if bit.bxor(bit.band(rs1_value, 0x80000000), bit.band(rs2_value, 0x80000000)) == 0 then
								if rs1_value < rs2_value then
									self:access_gp(rd, 1)
								end
							else
								if not (rs1_value > rs2_value) then
									self:access_gp(rd, 0)
								end
							end

							return true
						end,
						-- XOR
						function ()
							self:access_gp(rd, bit.bxor(self:access_gp(rs1), self:access_gp(rs2)))
							return true
						end,
						-- SRL/SRA
						function ()
							local op

							if fnt7 == 0 then
								op = bit.rshift
							elseif fnt7 ~= 0 then
								op = bit.arshift
							end

							self:access_gp(rd, op(self:access_gp(rs1), self:access_gp(rs2)))
							return true
						end,
						-- OR
						function ()
							self:access_gp(rd, bit.bor(self:access_gp(rs1), self:access_gp(rs2)))
							return true
						end,
						-- AND
						function ()
							self:access_gp(rd, bit.band(self:access_gp(rs1), self:access_gp(rs2)))
							return true
						end
					}
					local retval = decTabFnt3[decValFnt3()]()

					self:update_pc(false)
					return retval
				end,
				-- ========== 10
				function ()
					rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				-- ========== 11
				function ()
					rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end
			}

			local func = decTab6_5[decVal6_5()]
			if func == nil then return false end
			return func()
		end,
		-- ========== 101
		function ()
			local imm20 = bit.band(cmd, 0xFFFFF000)
			local rd = bit.rshift(bit.band(cmd, 0x00000F80), 7)

			local decTab6_5 = {
				-- AUIPC
				function ()
					self:access_gp(rd, self:access_pc() + imm20)
				end,
				-- LUI
				function ()
					self:access_gp(rd, imm20)
				end,
				function ()
					rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
				function ()
					rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					self:access_stat("online", false)
					return nil
				end,
			}

			local func = decTab6_5[decVal6_5()]
			if func == nil then return false end

			self:update_pc(false)
			return func()
		end,
		-- ========== 110
		function ()
			rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
			self:access_stat("online", false)
			return nil
		end,
		-- ========== 111 Not Supported other instruction length
		function ()
			rv.throw("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
			self:access_stat("online", false)
			return nil
		end
	}

	local func = decTab4_2[decVal4_2()]
	if func == nil then return false end
	retval = func()

	return retval
end

function Cpu:decode ()
	local cmd = self:fetch_instruction(true)
	local retval

	-- When instruction is C extension
	if bit.band(cmd, 3) ~= 3 then
		if self.conf.enable_rv32c == true then
			retval = self:decode_rv32c(cmd)
			if retval == nil then
				return nil
			end
		else
			rv.throw("Cpu:decode: Unsupported extension.")
		end
	else
		cmd = self:fetch_instruction(false)
		retval = self:decode_rv32i(cmd)
	end

	return retval
end

local RVREGISTER

RVREGISTER = elements.allocate(RV.MOD_IDENTIFIER, "CPU")
elements.element(RVREGISTER, elements.element(elements.DEFAULT_PT_ARAY))
elements.property(RVREGISTER, "Name", "CPU")
elements.property(RVREGISTER, "Description", "RISC-V 32-Bit CPU, RV32I set is being implemented.")
elements.property(RVREGISTER, "Colour", 0x6644FF)
elements.property(RVREGISTER, "MenuSection", elem.SC_ELEC)
elements.property(RVREGISTER, "Gravity", 0)
elements.property(RVREGISTER, "Flammable", 0)
elements.property(RVREGISTER, "Explosive", 0)
elements.property(RVREGISTER, "Loss", 0)
elements.property(RVREGISTER, "AirLoss", 1)
elements.property(RVREGISTER, "AirDrag", 0)
elements.property(RVREGISTER, "Advection", 1)
elements.property(RVREGISTER, "Weight", 0)
elements.property(RVREGISTER, "Diffusion", 0)

--[[ deprecated
elements.property(RvRegisterElements, "HighTemperature", 4000.0 + 273.15)
elements.property(RvRegisterElements, "HighTemperatureTransition", elements.DEFAULT_PT_BMTL)
]]

elements.property(RVREGISTER, "Create", function (i, x, y, s, n)
	tpt.set_property('ctype', 0, x, y)
end)

-- temp  : not allocated
-- ctype : instance id, if any negative value, cpu is halted.
-- life  : not allocated
-- tmp   : not allocated
-- tmp2  : not allocated
-- tmp3  : not allocated
-- tmp4  : not allocated

elements.property(RVREGISTER, "Update", function (i, x, y, s, n)
	local instance_id = tpt.get_property('ctype', x, y)

	if instance_id <= 0 then -- When processor is not active
		return
	elseif rv.instance[instance_id].cpu[1] == nil then
		tpt.set_property('ctype', -1, x, y) -- this instance id is not initialized or invalid.
		return
	end

	-- Debug
	-- tpt.set_property('life', instance_id, x, y)
	
	local instance = rv.instance[instance_id]
	local cpu = instance.cpu[1]
	local freq = cpu.conf.freq -- multiprocessiong not yet

	if cpu.stat.online then
		for i = 1, freq do
			cpu:decode()
			if not cpu.stat.online then break end
		end
	end

	--[[ What the fscking that?
	local temp = tpt.get_property('temp', x, y)
	tpt.set_property('temp', temp + ctx.conf.freq * 1.41, x, y)
	]]

	return
end)

RVREGISTER = elements.allocate(RV.MOD_IDENTIFIER, "CFG")
elements.element(RVREGISTER, elements.element(elements.DEFAULT_PT_ARAY))
elements.property(RVREGISTER, "Name", "CFG")
elements.property(RVREGISTER, "Description", "Configuration, check or set the instance state of Computer mod.")
elements.property(RVREGISTER, "Colour", 0x6644FF)
elements.property(RVREGISTER, "MenuSection", elem.SC_ELEC)
elements.property(RVREGISTER, "Gravity", 0)
elements.property(RVREGISTER, "Flammable", 0)
elements.property(RVREGISTER, "Explosive", 0)
elements.property(RVREGISTER, "Loss", 0)
elements.property(RVREGISTER, "AirLoss", 1)
elements.property(RVREGISTER, "AirDrag", 0)
elements.property(RVREGISTER, "Advection", 1)
elements.property(RVREGISTER, "Weight", 0)
elements.property(RVREGISTER, "Diffusion", 0)

elements.property(RVREGISTER, "Update", function (i, x, y, s, n)
	local current_life = tpt.get_property('life', x, y)

	if current_life <= 0 then -- no operation or error
		return
	end

	local setReturn = function (tmpOne, tmpTwo)
		tpt.set_property('tmp', tmpOne, x, y)
		tpt.set_property('tmp2', tmpTwo, x, y)
	end

	local setErrorLevel = function (errNum)
		if errNum < 0 then errNum = -errNum end
		tpt.set_property('life', -errNum, x, y)
	end

	local function getter (prop_name) return tpt.get_property(prop_name, x, y) end
	local function setter (prop_name, val) tpt.set_property(prop_name, val, x, y) end

	-- Caution! : API is unstable
	local id = tpt.get_property('ctype', x, y)

	local cfgOpTab = {
		-- (1) get the register value
		function ()
			local cpu_number = gettter('tmp3')
			local reg_number = getter('tmp4', x, y)

			local cpu = rv.instance[id].cpu[cpu_number]
			if cpu == nil then
				setErrorLevel(1)
				return
			end

			local retval

			if reg_number == 0 then
				retval = cpu:access_pc()
			else
				retval = cpu:access_gp(reg_number - 1)
			end

			setReturn(retval, 0)

			return true
		end,
		-- (2) set the register value
		function ()
			local cpu_number = getter('tmp3')
			local reg_number = getter('tmp4')

			local cpu = rv.instance[id].cpu[cpu_number]
			if cpu == nil then
				setErrorLevel(1)
				return
			end

			if regNum == 0 then
				cpu:access_pc(getter('tmp'))
			else
				cpu:access_gp(reg_number, getter('tmp'))
			end

			setReturn(0, 0)

			return true
		end,
		-- (3) get the current frequency
		function ()
			local cpu_number = getter('tmp3') + 1
			local cpu = rv.instance[id].cpu[cpu_number]
			if cpu == nil then
				setErrorLevel(1)
				return
			end

			setReturn(cpu.conf.freq, 0)

			return true
		end,
		-- (4) set the current frequency
		function ()
			local cpu_number = getter('tmp3')
			local cpu = rv.instance[id].cpu[cpu_number]
			if cpu == nil then
				setErrorLevel(1)
				return
			end

			local newFreq = tpt.get_property('tmp4', x, y)
			if newFreq > RV.MAX_FREQ_MULTIPLIER then
				setErrorLevel(1)
				return
			end

			cpu.conf.freq = newFreq
			setReturn(0, 0)

			return true
		end,
		-- (5) create instance
		function ()
			if rv.instance[id] ~= nil then
				rv.throw("rv.new_instance: Instance id already in use.")
				return
			end

			local instance = Instance:new{id = id}

			if instance == nil then
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			else
				setReturn(0, 0)
			end

			rv.instance[id] = instance

			return true
		end,
		-- (6) delete instance
		function ()
			if rv.instance[id] == nil then
				rv.throw("Configuration: API 6, delete failed. please restart the game.")
				return
			end

			Instance:del()

			return true
		end,
		-- (7) read memory
		function ()
			local cpu_number = getter('tmp3')
			local adr = getter('tmp4')
			local instance = rv.instance[id]
			local mem = instance.mem
			local val = mem:raw_access(adr, 3)

			if val == nil then
				rv.throw("Configuration: rv.access_memory is failed to read.")
				return false
			end

			setReturn(val, 0)
			return true
		end,
		-- (8) write memory
		function ()
			local cpu_number = getter('tmp3')
			local adr = getter('tmp4')
			local val = getter('tmp')
			local instance = rv.instance[id]
			local mem = instance.mem

			mem:raw_access(adr, 3, val)

			setReturn(0, 0)
			return true
		end,
		-- (9) load test program
		function ()
			return -- deprecated, do not use!
			--[[
			rv.load_test_code(id)

			setReturn(0, 0)
			return true
			]]
		end,
		-- (10) get debug info
		function ()
			local cpu_number = getter('tmp3')
			local instance = rv.instance[id]
			local cpu = instance.cpu[cpu_number]
			if not rv.print_debug_info(cpu) then
				setErrorLevel(1)
			end

			setReturn(0, 0)
		end,
		-- (11) toggle debugging segmentation
		function ()
			local cpu_number = getter('tmp3')
			rv.instance[id].mem.debug.segmentation = bit.bxor(rv.instance[id].mem.debug.segmentation, 1)
			setReturn(0, 0)
			return true
		end,
		-- (12) set or unset write protection on selected segment
		function ()
			local mem = rv.instance[id].mem
			local pos = getter('tmp3')
			local val = getter('tmp4')

			if val == 0 then
				val = false
			else
				val = true
			end

			mem.debug.segment_map[pos] = val

			setReturn(0, 0)
			return true
		end,
		-- (13) create memory instance
		function ()
			return -- deprecated
			--[[
			if not rv.new_mem(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			else
				setErrorLevel(0)
			end

			return true
			]]
		end,
		-- (14) delete memory instance
		function ()
			return -- deprecated
			--[[
			if not rv.del_mem(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			else
				setErrorLevel(0)
			end

			return true
			]]
		end,
		-- (15) register dump
		function ()
			local cpu_number = getter('tmp3')
			local cpu = rv.instance[id].cpu[cpu_number+1]

			if cpu == nil then
				tpt.message_box("Error", "Invalid instance ID.")
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			end

			local msg = ""

			for i = 0, 31 do
				local value = cpu:access_gp(i)
				if value == nil then value = "nil" end
				msg = string.format("%sR%d:\t0x%X\n", msg, i, value)
			end
			msg = string.format("%sPC:\t0x%X", msg, cpu:access_pc())

			tpt.message_box("RISC-V Register Dump", msg)

			return true
		end,
		-- (16) memory dump
		-- tmp3: start of memory
		-- tmp4: end of memory
		function ()
			local beg = getter('tmp3')
			local max = getter('tmp4')
			local msg = ""

			local mem = rv.instance[id].mem

			if beg > max then
				tpt.message_box("Error", "Invalid range.")
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			end

			if max - beg > 16 then
				tpt.message_box("Error", "Range too big.")
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			end

			for i = beg, max, 16 do
				local data

				for j = 0, 12, 4 do
					data = mem:raw_access(i + j, 3)
					msg = msg .. string.format("0x%X ", data)
				end

				msg = msg .. "\n"
			end

			tpt.message_box("RISC-V Memory Dump", "beg: " .. tostring(beg) .. ", max: " .. tostring(max) .. "\n" .. msg)
			return true
		end,
		-- (17) clipboard to RAM -- deprecated, do not use!
		function ()
			--[[
			-- permission check
			local perm = rv.try_permission("clipboard_access")
			if perm == false then
				setReturn(-1, -1)
				setErrorLevel(2)
				return false
			end

			local beg = getter('tmp3')

			local str = tpt.get_clipboard()
			rv.string_to_memory(id, beg, str)

			setReturn(0, 0)
			setErrorLevel(0)
			]]
			return false
		end,
		-- (18) read file and load memory
		function ()
			local base = getter('tmp3')
			local size = getter('tmp4')
			local instance = rv.instance[id]
			local mem = instance.mem

			local filename = tpt.input("File Load", "Which file do you want to open?")

			mem:load_memory(base, size, filename)
			return true
		end,
		-- (19) write file and dump memory
		function ()
			local base = getter('tmp3')
			local size = getter('tmp4')
			local instance = rv.instance[id]
			local mem = instance.mem

			local filename = tpt.input("File Dump", "What file do you want to print?")

			mem:dump_memory(base, size, filename)
			return true
		end,
	}

	local func = cfgOpTab[current_life]
	if func == nil then
		setReturn(-1, -1)
		setErrorLevel(1)
		return
	end

	local retval = func()

	if retval == nil then
		setErrorLevel(1)
	elseif retval == true then
		setErrorLevel(0)
	end

	return
end)

RVREGISTER = elements.allocate(RV.MOD_IDENTIFIER, "RAM")
elements.element(RVREGISTER, elements.element(elements.DEFAULT_PT_ARAY))
elements.property(RVREGISTER, "Name", "RAM")
elements.property(RVREGISTER, "Description", "Random-Access Memory, can transfer data to the FILT and operate it as a PSCN, NSCN.")
elements.property(RVREGISTER, "Colour", 0xDF3FBF)
elements.property(RVREGISTER, "MenuSection", elem.SC_ELEC)
elements.property(RVREGISTER, "Gravity", 0)
elements.property(RVREGISTER, "Flammable", 1)
elements.property(RVREGISTER, "Explosive", 0)
elements.property(RVREGISTER, "Loss", 0)
elements.property(RVREGISTER, "AirLoss", 1)
elements.property(RVREGISTER, "AirDrag", 0)
elements.property(RVREGISTER, "Advection", 1)
elements.property(RVREGISTER, "Weight", 0)
elements.property(RVREGISTER, "Diffusion", 0)

elements.property(RVREGISTER, "Update", function (i, x, y, s, n)
	local function getter (prop_name) return tpt.get_property(prop_name, x, y) end
	local function setter (prop_name, val) tpt.set_property(prop_name, val, x, y) end

	local instance = rv.instance[getter('ctype')]
	if instance == nil then return end
	local mem = instance.mem

	local ptr = getter('life')
	local detected_pscn
	local detected_nscn

	for ry = -2, 2 do
		for rx = -2, 2 do
			local el = tpt.get_property('type', x + rx, y + ry)

			if el == elements.DEFAULT_PT_SPRK and tpt.get_property('life', x + rx, y + ry) == 3 then
				if tpt.get_property('ctype', x + rx, y + ry) == elements.DEFAULT_PT_PSCN then
					detected_pscn = true
				elseif tpt.get_property('ctype', x + rx, y + ry) then
					detected_nscn = true
				end
			end
		end
	end

	if detected_pscn then
		for ry = -2, 2 do
			for rx = -2, 2 do
				local found = tpt.get_property('type', x + rx, y + ry)

				if found == elements.DEFAULT_PT_FILT then
					local value = mem:raw_access(ptr, 3)
					value = value + 0x10000000 -- serialization
					tpt.set_property('ctype', value, x + rx, y + ry)
				end
			end
		end
	elseif detected_nscn then
		for ry = -2, 2 do
			for rx = -2, 2 do
				local found = tpt.get_property('type', x + rx, y + ry)

				if found == elements.DEFAULT_PT_FILT then
					local value = tpt.get_property('ctype', x + rx, y + ry)
					value = value - 0x10000000 -- deserialization
					mem:raw_access(ptr, 3, value)
				end
			end
		end
	end

	return
end)

-- Also try Legend of Astrum!
