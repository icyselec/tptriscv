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

rv.context = {}
rv.decode = {}
rv.permissions = {}

-- definition constants
RV.MAX_MEMORY_WORD = 65536 -- 256 kiB limit
RV.MAX_MEMORY_SIZE = RV.MAX_MEMORY_WORD * 4
RV.MAX_FREQ_MULTIPLIER = 1667
RV.MAX_TEMPERATURE = 120.0
RV.MOD_IDENTIFIER = "FREECOMPUTER"
RV.EXTENSIONS = {"RV32I"}

-- definition context class
rv.context.cpu = {}
rv.context.mem = {}

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



function rv.new_cpu_instance (instanceId)
	if rv.context.cpu[instanceId] ~= nil then
		rv.throw("rv_new_cpu_instance: Instance id already in use.")
		return false
	end

	rv.context.cpu[instanceId] = {
		conf = {
			mem_id = instanceId,
			freq = 1, -- frequency of operation per frame The effective frequency is calculated as follows (multiplier * maximum frame limit) * (current frame count / maximum frame limit)
			exts = { "RV32I", "RV32C" },
			enable_rv32c = false,
			check_aligned = false
		},
		stat = {
			is_halted = false,
			is_aligned = true,
			is_waiting = false,

		},
		regs = {
			-- general-purpose register
			gp = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
			-- program counter
			pc = 0
		}
	}

	return true
end

function rv.new_mem_instance (instanceId)
	if rv.context.mem[instanceId] ~= nil then
		rv.throw("rv_new_mem_instance: Instance id already in use.")
		return false
	end

	rv.context.mem[instanceId] = {}
	local mem_ctx = rv.context.mem[instanceId]
	mem_ctx.data = {}
	mem_ctx.conf = {
		bit_width = 32,
		size = 65536 * 4
	}

	mem_ctx.debug = {
		segmentation = false,
		segment_size = 32,
		panic_when_fault = false,
		segment_map = {}
	}

	setmetatable(mem_ctx.debug.segment_map, { __index = function(self) return 0 end })

	setmetatable(mem_ctx.data, { __index = function(self) return 0 end })

	return true
end


function rv.print_debug_info(id)
	local mem_ctx = rv.context.mem[id]
	if mem_ctx == nil then
		return false
	end

	print("segmentation: " .. tostring(mem_ctx.debug.segmentation))
	print("segment_size: " .. tostring(mem_ctx.debug.segment_size))
	print("panic_when_fault: " .. tostring(mem_ctx.debug.panic_when_fault))
	print("segment_map: " .. tostring(mem_ctx.debug.segment_map))

	return true
end

function rv.del_cpu_instance (instanceId)
	if rv.context.cpu[instanceId] == nil then
		rv_throw("rv_del_cpu_instance: Instance id already deleted.")
		return false
	end

	rv.context.cpu[instanceId] = nil

	return true
end

function rv.del_mem_instance (instanceId)
	if rv.context.mem[instanceId] == nil then
		rv_throw("rv_del_mem_instance: Instance id already deleted.")
		return false
	end

	-- Actually, I know the order of releasing the memory, but even if I do this, they'll take care of it, right?
	rv.context.mem[instanceId] = nil

	return true
end

function rv.access_memory (cpu_ctx, adr, mod, val)
	local retval
	local mem_ctx = rv.context.mem[cpu_ctx.conf.mem_id]

	local ea = bit.rshift(adr, 2) + 1
	local offset = 0

	local function report_error (cmd, msg)
		rv.throw("rv.access_memory: " .. cmd .. " failed, " .. msg)
	end

	-- memory limit check
	if bit.bxor(bit.band(ea, 0x80000000), bit.band(RV.MAX_MEMORY_WORD, 0x80000000)) == 0 then
		if ea > RV.MAX_MEMORY_WORD then
			rv.throw("rv.access_memory: Memory out of bound.")
			return nil
		end
	else
		if ea < RV.MAX_MEMORY_WORD then
			rv.throw("rv.access_memory: Memory out of bound.")
			return nil
		end
	end

	if mem_ctx.debug.segmentation == true then
		local ea = bit.rshift(adr, 2)
		ea = bit.rshift(ea, mem_ctx.debug.segment_size)
		if val ~= nil and mem_ctx.debug.segment_map[ea] == true then
			if mem_ctx.debug.panic_when_fault == true then
				rv_panic()
			end
		end
	end


	local rdOpTab = {
		-- LB
		function ()
			offset = bit.band(adr, 3)
			return bit.arshift(bit.lshift(bit.band(mem_ctx.data[ea], bit.lshift(0xFF, offset * 8)), (3 - offset) * 8), offset * 8)
		end,
		-- LH
		function ()
			offset = bit.rshift(bit.band(adr, 3), 1)

			if cpu_ctx.conf.check_aligned then
				local sub_offset = bit.band(adr, 1)
				if sub_offset ~= 0 then
					report_error("LH", "Attempt to access unaligned memory.")
					return
				end
			end

			return bit.arshift(bit.lshift(bit.band(mem_ctx.data[ea], bit.lshift(0xFFFF, offset * 16))), offset * 16)
		end,
		-- LW
		function ()
			offset = bit.band(adr, 3)
			local case_tab = {
				function ()
					return mem_ctx.data[ea]
				end,
				function ()
					report_error("LW", "Not Supported load halfword using byte-addressing.")
					return
				end,
				function ()
					local retval = rv.access_memory(cpu_ctx, adr, 6)
					return bit.bor(retval, bit.lshift(rv.access_memory(cpu_ctx, adr + 2, 6), 16))
				end,
				function ()
					report_error("LW", "Not Supported load halfword using byte-addressing.")
					return
				end,
			}

			if offset ~= 0 and cpu_ctx.conf.check_aligned then
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
			offset = bit.band(adr, 3)
			local retval = bit.rshift(bit.band(mem_ctx.data[ea], bit.lshift(0xFF, offset * 8)), offset * 8)
			return retval
		end,
		-- LHU
		function ()
			offset = bit.rshift(bit.band(adr, 3), 1)
			if cpu_ctx.conf.check_aligned then
				local sub_offset = bit.band(adr, 1)
				if sub_offset ~= 0 then
					report_error("LHU", "Attempt to access unaligned memory.")
					return nil
				end
			end

			return bit.rshift(bit.band(mem_ctx.data[ea], bit.lshift(0xFFFF, offset * 16)), offset * 16)
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
			offset = bit.band(adr, 3)
			mem_ctx.data[ea] = bit.bor(bit.band(mem_ctx.data[ea], bit.bnot(bit.lshift(0xFF, offset * 8))), bit.lshift(bit.band(val, 0xFF), offset * 8))
			return true
		end,
		-- SH
		function ()
			if cpu_ctx.conf.check_aligned then
				local sub_offset = bit.band(adr, 1)
				if sub_offset ~= 0 then
					report_error("SH", "Attempt to access unaligned memory.")
					return
				end
			end

			offset = bit.rshift(bit.band(adr, 3), 1)
			mem_ctx.data[ea] = bit.bor(bit.band(mem_ctx.data[ea], bit.bnot(bit.lshift(0xFFFF, offset * 16))), bit.lshift(bit.band(val, 0xFFFF), offset * 16))
			return true
		end,
		-- SW
		function ()
			offset = bit.band(adr, 3)
			if offset ~= 0 then
				if cpu_ctx.conf.check_aligned then
					report_error("SW", "Attempt to access unaligned memory.")
					return nil
				elseif bit.band(offset, 2) == 0 then
					rv.access_memory(cpu_ctx, adr, 2, val)
					val = bit.rshift(val, 16)
					rv.access_memory(cpu_ctx, adr + 2, 2, val)
					return true
				else
					report_error("SW", "Attempt to access unaligned memory.")
					return nil
				end
			end

			mem_ctx.data[ea] = val
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

	if val == nil then
		func = rdOpTab[mod]
	else
		func = wrOpTab[mod]
	end



	if func == nil then return nil end
	retval = func()

	if retval == nil then
		rv.throw("rv.access_memory: Not implemented instruction dectected. processor is halted.")
		cpu_ctx.stat.is_halted = true
		return nil
	end

	return retval
end

-- deprecated warning
function rv.load_test_code (instanceId)
	local cpu_ctx = rv.context.cpu[instanceId]
	rv.context.mem[instanceId].data = {0x00001537,0x008000ef,0x0000006f,0x00000293,0x00a28333,0x00034303,0x00030663,0x00128293,0xff1ff06f,0x00028513,0x00008067}
	setmetatable(rv.context.mem[instanceId].data, { __index = function(self) return 0 end })
	rv.access_memory(cpu_ctx, 4096, 3, 0x6c6c6548)
	rv.access_memory(cpu_ctx, 4100, 3, 0x77202c6f)
	rv.access_memory(cpu_ctx, 4104, 3, 0x646c726f)
	rv.access_memory(cpu_ctx, 4108, 3, 0x00000a21)
	setmetatable(rv.context.mem[instanceId].data, { __index = function(self) return 0 end })
end

function rv.string_to_memory (id, begin, value)
	local cpu_ctx = rv.context.cpu[id]
	local mem_ctx = rv.context.mem[cpu_ctx.conf.mem_id]

	-- Not Implemeted

end

function rv.load_memory (id, base, size, filename)
	local cpu_ctx = rv.context.cpu[id]
	local mem_ctx = rv.context.mem[cpu_ctx.conf.mem_id]

	local f = assert(io.open(filename, "rb"))
	local i = 0

	for line in f:lines() do
		rv.access_memory(cpu_ctx, base + i, 3, tonumber(line, 16))
		if i > size then
			break
		end

		i = i + 4
	end
--	setmetatable(mem_ctx.data, { __index = function(self) return 0 end })
	f:close()
end

function rv.dump_memory (id, base, size, filename)
	local cpu_ctx = rv.context.cpu[id]
	local mem_ctx = rv.context.mem[cpu_ctx.conf.mem_id]

	local f = assert(io.open(filename, "wb"))
	local i = 0

	repeat
		local data = rv.access_memory(cpu_ctx, base + i, 3)
		f:write(string.format("%X\n", data))
		i = i + 4
	until i > size

	f:close()
end

function rv.fetch_instruction (cpu_ctx, compact_mode)
	if compact_mode then
		return rv.access_memory(cpu_ctx, cpu_ctx.regs.pc, 6)
	else
		return rv.access_memory(cpu_ctx, cpu_ctx.regs.pc, 3)
	end
end

function rv.update_pc_rv32c (cpu_ctx)
	cpu_ctx.regs.pc = cpu_ctx.regs.pc + 2
	cpu_ctx.stat.check_aligned = false
end

function rv.update_pc (cpu_ctx)
	cpu_ctx.regs.pc = cpu_ctx.regs.pc + 4
end

--[[
==================================================================
==================== Define of RISC-V Decoder ====================
==================================================================

]]

function rv.decode_rv32c (cpu_ctx, inst)
	local function decVal1_0 ()
		return bit.band(inst, 0x3) + 1
	end

	local function decValFnt3 ()
		return bit.rshift(bit.band(inst, 0xE000), 13) + 1
	end


	local decTab1_0 = {
		function ()
			local rd_rs2 = bit.rshift(bit.band(inst, 0x0000001C), 2)
			local rs1 = bit.rshift(bit.band(inst, 0x00000380), 7)
			local uimm = bit.rshift(bit.band(inst, 0x00001C00), 7)
			uimm = bit.bor(uimm, bit.rshift(bit.band(inst, 0x00000040), 4))
			uimm = bit.bor(uimm, bit.lshift(bit.band(inst, 0x00000080), 1))

			local decTabFnt3 = {
				function ()
					local nzuimm = bit.rshift(bit.band(inst, 0x00001FE0), 5)


				end,
				-- C.FLD
				function () return nil end, -- Not usable
				-- C.LW
				function ()
					cpu_ctx.regs.gp[rd_rs2] = rv.access_memory(cpu_ctx, cpu_ctx.regs.gp[rs1] + uimm, 3)
				end,
				-- C.FLW
				function () return nil end,
				-- Reserved
				function () return nil end,
				-- C.FSD
				function () return nil end,
				-- C.SW
				function ()
					rv.access_memory(cpu_ctx, cpu_ctx.regs.gp[rs1] + uimm, 3, cpu_ctx.regs.gp[rd_rs2])
				end,
				-- C.FSW
				function () return nil end,
			}
		end,
		function () end,
		function () end,
	}

	local func = decTab1_0[decVal1_0()]
	if func == nil then return false end
	local retval = func()

	-- register number 0 is always zero
	cpu_ctx.regs.gp[1] = 0
	return func()
end

function rv.decode_rv32i (cpu_ctx, inst)
	local retval

	local function decVal4_2 ()
		return bit.rshift(bit.band(inst, 0x1C), 2) + 1
	end

	local function decVal6_5 ()
		return bit.rshift(bit.band(inst, 0x60), 5) + 1
	end

	local function decValFnt3 ()
		return bit.rshift(bit.band(inst, 0x7000), 12) + 1
	end

	local decTab4_2 = {
		-- ========== 000
		function ()
			local rd = bit.rshift(bit.band(inst, 0x00000F80), 7) + 1
			local rs1 = bit.rshift(bit.band(inst, 0x000F8000), 15) + 1
			local rs2 = bit.rshift(bit.band(inst, 0x01F00000), 20) + 1 -- maybe plus one
			local imm = bit.arshift(bit.band(inst, 0xFFF00000), 20)

			local decTab6_5 = {
				function ()
					-- LB/LH/LW/LBU/LHU
					rv.update_pc(cpu_ctx)
					if rd ~= 1 then
						cpu_ctx.regs.gp[rd] = rv.access_memory(cpu_ctx, cpu_ctx.regs.gp[rs1] + imm, decValFnt3())
					end

					if cpu_ctx.regs.gp[rd] == nil then
						rv.throw("rv.decode_rv32i: rv.access_memory returns nil value.")
						return nil
					end
				end,
				-- SB/SH/SW
				function ()
					local imm = bit.bor(bit.arshift(bit.band(inst, 0xFE000000), 20), rd-1)
					local retval = rv.access_memory(cpu_ctx, cpu_ctx.regs.gp[rs1] + imm, decValFnt3(), cpu_ctx.regs.gp[rs2])
					rv.update_pc(cpu_ctx)
					return retval
				end,
				function ()
					return nil
				end,
				-- BEQ/BNE/BLT/BGE/BLTU/BGEU
				function ()
					local rs1_value = bit.bor(cpu_ctx.regs.gp[rs1], 0)
					local rs2_value = bit.bor(cpu_ctx.regs.gp[rs2], 0)

					local imm = bit.band(inst, 0x80000000)
					imm = bit.bor(imm, bit.rshift(bit.band(inst, 0x7E000000), 1))
					imm = bit.bor(imm, bit.lshift(bit.band(inst, 0x00000080), 23))
					imm = bit.bor(imm, bit.lshift(bit.band(inst, 0x00000F00), 12))
					imm = bit.arshift(imm, 19)

					local decTabFnt3 = {
						-- BEQ
						function ()
							if rs1_value == rs2_value then
								cpu_ctx.regs.pc = cpu_ctx.regs.pc + imm
								return true
							end

							return false
						end,
						-- BNE
						function ()
							if rs1_value ~= rs2_value then
								cpu_ctx.regs.pc = cpu_ctx.regs.pc + imm
								return true
							end

							return false
						end,
						-- BLT
						function ()
							if rs1_value < rs2_value then
								cpu_ctx.regs.pc = cpu_ctx.regs.pc + imm
								return true
							end

							return false
						end,
						-- BGE
						function ()
							if rs1_value >= rs2_value then
								cpu_ctx.regs.pc = cpu_ctx.regs.pc + imm
								return true
							end

							return false
						end,
						-- BLTU
						function ()
							local rs1_value = cpu_ctx.regs.gp[rs1]
							local rs2_value = cpu_ctx.regs.gp[rs2]

							-- If both numbers are positive, just compare them. If not, reverse the comparison condition.
							if bit.bxor(bit.band(rs1_value, 0x80000000), bit.band(rs2_value, 0x80000000)) == 0 then
								if rs1_value < rs2Value then
									cpu_ctx.regs.pc = cpu_ctx.regs.pc + imm
									return true
								end
							else
								if rs1Value > rs2Value then
									cpu_ctx.regs.pc = cpu_ctx.regs.pc + imm
									return true
								end
							end

							return false
						end,
						-- BGEU
						function ()
							local rs1_value = cpu_ctx.regs.gp[rs1]
							local rs2_value = cpu_ctx.regs.gp[rs2]

							if rs1_value == rs2_value then
								cpu_ctx.regs.pc = cpu_ctx.regs.pc + imm
							elseif bit.bxor(bit.band(rs1_value, 0x80000000), bit.band(rs2_value, 0x80000000)) == 0 then
								if rs1_value >= rs2_value then
									cpu_ctx.regs.pc = cpu_ctx.regs.pc + imm
									return true
								end
							else
								if rs1_value < rs2_value then
									cpu_ctx.regs.pc = cpu_ctx.regs.pc + imm
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
					if func == nil then return false end
					local retval = func()

					if not retval then rv.update_pc(cpu_ctx) end

					return retval
				end,
			}

			local func = decTab6_5[decVal6_5()]
			if func == nil then return nil end
			return func()
		end,
		-- ========== 001
		function ()
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
				-- JALR
				function ()
					local rd = bit.rshift(bit.band(inst, 0x00000F80), 7) + 1
					local rs1 = bit.rshift(bit.band(inst, 0x000F8000), 15) + 1
					local imm = bit.arshift(bit.band(inst, 0xFFF00000), 20)

					if bit.band(inst, 0x00007000) ~= 0 then
						return nil
					end

					local backup = cpu_ctx.regs.pc

					cpu_ctx.regs.pc = bit.band(cpu_ctx.regs.gp[rs1] + imm, 0xFFFFFFFE) -- then setting least-significant bit of the result to zero.
					cpu_ctx.regs.gp[rd] = backup
				end,
			}

			local func = decTab6_5[decVal6_5()]
			if func == nil then return false end
			local retval = func()

			return retval
		end,
		-- ========== 010
		function ()
			return nil
		end,
		-- ========== 011
		function ()
			local rd = bit.rshift(bit.band(inst, 0x00000F80), 7) + 1
			local imm20 = bit.band(inst, 0x80000000)
			imm20 = bit.bor(imm20, bit.rshift(bit.band(inst, 0x7FE00000), 9))
			imm20 = bit.bor(imm20, bit.lshift(bit.band(inst, 0x00100000), 2))
			imm20 = bit.bor(imm20, bit.lshift(bit.band(inst, 0x000FF000), 11))
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
					cpu_ctx.regs.gp[rd] = cpu_ctx.regs.pc + 4
					cpu_ctx.regs.pc = bit.band(cpu_ctx.regs.pc + imm20, 0xFFFFFFFF)
				end,
			}
			local func = decTab6_5[decVal6_5()]
			if func == nil then return false end
			local retval = func()

			return retval
		end,
		-- ========== 100
		function ()
			local rd = bit.rshift(bit.band(inst, 0x00000F80), 7) + 1
			local rs1 = bit.rshift(bit.band(inst, 0x000F8000), 15) + 1
			local decTab6_5 = {
				-- ========== 00
				function ()
					local imm = bit.arshift(bit.band(inst, 0xFFF00000), 20)
					local shamt = bit.band(imm, 0x1F)

					local decTabFnt3 = {
						-- ADDI
						function ()
							cpu_ctx.regs.gp[rd] = bit.band(cpu_ctx.regs.gp[rs1] + imm, 0xFFFFFFFF)
						end,
						-- SLLI
						function ()
							if bit.rshift(bit.band(imm, 0xFE0), 5) ~= 0 then
								cpu_ctx.regs.gp[rd] = bit.band(bit.lshift(cpu_ctx.regs.gp[rs1], shamt), 0xFFFFFFFF)
							else
								return true
							end
						end,
						-- SLTI
						function ()
							if cpu_ctx.regs.gp[rs1] < imm then
								cpu_ctx.regs.gp[rd] = 1
							else
								cpu_ctx.regs.gp[rd] = 0
							end
						end,
						-- SLTIU
						function ()
							local rs1_value = cpu_ctx.regs.gp[rs1]

							if bit.bxor(bit.band(rs1_value, 0x80000000), bit.band(imm, 0x80000000)) == 0 then
								if rs1_value < imm then
									cpu_ctx.regs.gp[rd] = 1
								end
							else
								if not (rs1_value > imm) then
									cpu_ctx.regs.gp[rd] = 0
								end
							end
						end,
						-- XORI
						function ()
							cpu_ctx.regs.gp[rd] = bit.bxor(cpu_ctx.regs.gp[rs1], imm)
						end,
						-- SRLI/SRAI
						function ()
							local imm11_5 = bit.band(imm, 0xFE0)
							local op
							if imm11_5 == 0 then
								op = bit.rshift
							elseif imm11_5 ~= 0 then
								op = bit.arshift
							end

							cpu_ctx.regs.gp[rd] = bit.band(op(cpu_ctx.regs.gp[rs1], shamt), 0xFFFFFFFF)
						end,
						-- ORI
						function ()
							cpu_ctx.regs.gp[rd] = bit.bor(cpu_ctx.regs.gp[rs1], imm)
						end,
						-- ANDI
						function ()
							cpu_ctx.regs.gp[rd] = bit.band(cpu_ctx.regs.gp[rs1], imm)
						end
					}

					local func = decTabFnt3[decValFnt3()]
					if func == nil then return false end
					local retval = func()

					rv.update_pc(cpu_ctx)
					return retval
				end,
				-- ========== 01
				function ()
					local rs2 = bit.rshift(bit.band(inst, 0x01F00000), 20) + 1
					local fnt7 = bit.rshift(bit.band(inst, 0xFE0000000), 29)

					local decTabFnt3 = {
						-- ADD/SUB
						function ()
							if fnt7 == 0 then
								cpu_ctx.regs.gp[rd] = bit.band(cpu_ctx.regs.gp[rs1] + cpu_ctx.regs.gp[rs2], 0xFFFFFFFF)
							elseif fnt7 ~= 0 then
								cpu_ctx.regs.gp[rd] = bit.band(cpu_ctx.regs.gp[rs1] - cpu_ctx.regs.gp[rs2], 0xFFFFFFFF)
							end

							return true
						end,
						-- SLL
						function ()
							cpu_ctx.regs.gp[rd] = bit.band(bit.lshift(cpu_ctx.regs.gp[rs1], cpu_ctx.regs.gp[rs2]))

							return true
						end,
						-- SLT
						function ()
							if cpu_ctx.regs.gp[rs1] < cpu_ctx.regs.gp[rs2] then
								cpu_ctx.regs.gp[rd] = 1
							else
								cpu_ctx.regs.gp[rd] = 0
							end

							return true
						end,
						-- SLTU
						function ()
							local rs1_value = cpu_ctx.regs.gp[rs1]
							local rs2_value = cpu_ctx.regs.gp[rs2]

							if bit.bxor(bit.band(rs1_value, 0x80000000), bit.band(rs2_value, 0x80000000)) == 0 then
								if rs1_value < rs2_value then
									cpu_ctx.regs.gp[rd] = 1
								end
							else
								if not (rs1_value > rs2_value) then
									cpu_ctx.regs.gp[rd] = 0
								end
							end

							return true
						end,
						-- XOR
						function ()
							cpu_ctx.regs.gp[rd] = bit.bxor(cpu_ctx.regs.gp[rs1], cpu_ctx.regs.gp[rs2])
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

							cpu_ctx.regs.gp[rd] = op(cpu_ctx.regs.gp[rs1], cpu_ctx.regs.gp[rs2])
							return true
						end,
						-- OR
						function ()
							cpu_ctx.regs.gp[rd] = bit.bor(cpu_ctx.regs.gp[rs1], cpu_ctx.regs.gp[rs2])
							return true
						end,
						-- AND
						function ()
							cpu_ctx.regs.gp[rd] = bit.band(cpu_ctx.regs.gp[rs1], cpu_ctx.regs.gp[rs2])
							return true
						end
					}

					local func = decTabFnt3[decValFnt3()]
					if func == nil then return false end
					local retval = func()

					rv.update_pc(cpu_ctx)
					return retval
				end,
				-- ========== 10
				function ()
					return nil
				end,
				-- ========== 11
				function ()
					return nil
				end
			}

			local func = decTab6_5[decVal6_5()]
			if func == nil then return false end
			return func()
		end,
		-- ========== 101
		function ()
			local imm20 = bit.band(inst, 0xFFFFF000)
			local rd = bit.rshift(bit.band(inst, 0x00000F80), 7) + 1

			local decTab6_5 = {
				function ()
					cpu_ctx.regs.gp[rd] = bit.band(cpu_ctx.regs.pc + imm20, 0xFFFFFFFF)
				end,
				function ()
					cpu_ctx.regs.gp[rd] = imm20
				end,
				function ()
					return nil
				end,
				function ()
					return nil
				end,
			}

			local func = decTab6_5[decVal6_5()]
			if func == nil then return false end

			rv.update_pc(cpu_ctx)
			return func()
		end,
		-- ========== 110
		function ()
			return nil
		end,
		-- ========== 111 Not Supported other instruction length
		function ()
			rv.throw("rv32i_decode: Invalid instruction.")
			return false
		end
	}

	local func = decTab4_2[decVal4_2()]
	if func == nil then return false end
	retval = func()

	cpu_ctx.regs.gp[1] = 0
	return retval
end

function rv.decode (cpu_ctx)
	local inst = rv.fetch_instruction(cpu_ctx, true)
	local retval1
	local retval2

	-- When instruction is C extension
	if bit.band(inst, 3) ~= 3 then
		if cpu_ctx.conf.enable_rv32c then
			retval1 = rv.decode_rv32c(cpu_ctx, inst)
			inst = rv.fetch_instruction(cpu_ctx, true)
			retval2 = rv.decode_rv32c(cpu_ctx, inst)
			if retval1 == nil and retval2 == nil then
				return nil
			else
				return false
			end
		else
			rv_throw("rv_decode: Unsupported extension.")
		end
	else
		inst = rv.fetch_instruction(cpu_ctx, false)
		retval1 = rv.decode_rv32i(cpu_ctx, inst)
	end

	return retval1
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
	local instanceId = tpt.get_property('ctype', x, y)

	if instanceId <= 0 then -- When processor is not active
		return
	elseif rv.context.cpu[instanceId] == nil then
		tpt.set_property('ctype', -1, x, y) -- this instance id is not initialized or invalid.
		return
	end

	-- Debug
	-- tpt.set_property('life', instanceId, x, y)
	
	local cpu_ctx = rv.context.cpu[instanceId]
	local freq = cpu_ctx.conf.freq

	if not cpu_ctx.stat.is_halted then
		for i = 1, freq do
			rv.decode(cpu_ctx)
			if cpu_ctx.stat.is_halted then break end
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
	local currentLife = tpt.get_property('life', x, y)

	if currentLife <= 0 then -- no operation or error
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
			local regNum = tpt.get_property('tmp3', x, y)

			local cpu_ctx = rv.context.cpu[id]
			if cpu_ctx == nil then
				setErrorLevel(1)
				return
			end

			local ret1

			if regNum == 0 then
				ret1 = cpu_ctx.regs.pc
			else
				ret1 = cpu_ctx.regs.gp[regNum]
			end

			setReturn(ret1, 0)

			return true
		end,
		-- (2) set the register value
		function ()
			local regNum = tpt.get_property('tmp3', x, y)

			local cpu_ctx = rv.context.cpu[id]
			if cpu_ctx == nil then
				setErrorLevel(1)
				return
			end

			if regNum == 0 then
				cpu_ctx.regs.pc = bit.band(tpt.get_property('tmp', x, y))
			else
				cpu_ctx.regs.gp[regNum] = bit.band(tpt.get_property('tmp', x, y))
			end

			setReturn(0, 0)

			return true
		end,
		-- (3) get the current frequency
		function ()
			local cpu_ctx = rv.context.cpu[id]
			if cpu_ctx == nil then
				setErrorLevel(1)
				return
			end

			setReturn(cpu_ctx.conf.freq, 0)

			return true
		end,
		-- (4) set the current frequency
		function ()
			local cpu_ctx = rv.context.cpu[id]
			if cpu_ctx == nil then
				setErrorLevel(1)
				return
			end

			local newFreq = tpt.get_property('tmp3', x, y)
			if newFreq > rv.const.max_freq_multiplier then
				setErrorLevel(1)
				return
			end

			cpu_ctx.conf.freq = newFreq
			setReturn(0, 0)

			return true
		end,
		-- (5) create instance
		function ()
			if not rv.new_cpu_instance(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			else
				setReturn(0, 0)
			end

			return true
		end,
		-- (6) delete instance
		function ()
			if not rv.del_cpu_instance(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			else
				setReturn(0, 0)
			end

			return true
		end,
		-- (7) read memory
		function ()
			local adr = tpt.get_property('tmp3', x, y)
			local val = rv.access_memory(rv.context.cpu[id], adr, 3)

			if val == nil then
				rv.throw("Configuration: rv.access_memory is failed to read.")
				return false
			end

			setReturn(val, 0)
			return true
		end,
		-- (8) write memory
		function ()
			local adr = getter('tmp3')
			local val = getter('tmp4')

			rv.access_memory(rv.context.cpu[id], adr, 3, val)

			setReturn(0, 0)
			return true
		end,
		-- (9) load test program
		function ()
			rv.load_test_code(id)

			setReturn(0, 0)
			return true
		end,
		-- (10) get debug info
		function ()
			if not rv.print_debug_info(id) then
				setErrorLevel(1)
			end

			setReturn(0, 0)
		end,
		-- (11) toggle debugging segmentation
		function ()
			rv.context.mem[id].debug.segmentation = bit.bxor(rv.context.mem[id].debug.segmentation, 1)
			setReturn(0, 0)
			return true
		end,
		-- (12) set or unset write protection on selected segment
		function ()
			local mem_ctx = rv.context.mem[id]
			local pos = getter('tmp3')
			local val = getter('tmp4')

			if val == 0 then
				val = false
			else
				val = true
			end

			mem_ctx.debug.segment_map[pos] = val

			setReturn(0, 0)
			return true
		end,
		-- (13) create memory instance
		function ()
			if not rv.new_mem_instance(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			else
				setErrorLevel(0)
			end

			return true
		end,
		-- (14) delete memory instance
		function ()
			if not rv.del_mem_instance(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			else
				setErrorLevel(0)
			end

			return true
		end,
		-- (15) register dump
		function ()
			local cpu_ctx = rv.context.cpu[id]

			if cpu_ctx == nil then
				tpt.message_box("Error", "Invalid instance ID.")
				setReturn(-1, -1)
				setErrorLevel(1)
				return false
			end

			local msg = ""

			for i = 0, 31 do
				msg = msg .. "R" .. tostring(i) .. ":\t" .. string.format("0x%X\n", cpu_ctx.regs.gp[i+1])
			end
			msg = msg .. "PC:\t" .. string.format("0x%X", cpu_ctx.regs.pc)

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

			local cpu_ctx = rv.context.cpu[id]

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
					data = rv.access_memory(cpu_ctx, i + j, 3)
					msg = msg .. string.format("0x%X ", data)
				end

				msg = msg .. "\n"
			end

			tpt.message_box("RISC-V Memory Dump", "beg: " .. tostring(beg) .. ", max: " .. tostring(max) .. "\n" .. msg)
			return true
		end,
		-- (17) clipboard to RAM -- do not use!
		function ()
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
			return true
		end,
		-- (18) read file and load memory
		function ()
			local base = getter('tmp3')
			local size = getter('tmp4')

			local filename = tpt.input("File Load", "Which file do you want to open?")

			rv.load_memory(id, base, size, filename)
			return true
		end,
		-- (19) write file and dump memory
		function ()
			local base = getter('tmp3')
			local size = getter('tmp4')

			local filename = tpt.input("File Dump", "What file do you want to print?")

			rv.dump_memory(id, base, size, filename)
			return true
		end,
	}

	local func = cfgOpTab[currentLife]
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

	local cpu_ctx = rv.context.cpu[getter('ctype')]
	if cpu_ctx == nil then return end

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
					local value = rv.access_memory(rv.context.cpu[id], ptr, 3)
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
					rv.access_memory(rv.context.cpu[id], ptr, 3, value)
				end
			end
		end
	end

	return
end)

-- Also try Legend of Astrum!
