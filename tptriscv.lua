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

local RvConstMaxMemWord = 65536 -- 256 kiB limit
local RvConstMaxFreqMultiplier = 1667
local RvConstMaxTemperature = 120.0
local RvConstModIdent = "FREECOMPUTER"
local RvCtxCpu = {}
local RvCtxMem = {}

local function RvThrowException (msg)
	print(msg)
end

local function RvLoadTestCode (instanceId)
	RvCtxMem[instanceId].data = {0x00001537,0x008000ef,0x0000006f,0x00000293,0x00a28333,0x00030303,0x00030663,0x00128293,0xff1ff06f,0x00028513,0x00008067}
	RvCtxMem[instanceId].data[4097] = 0x6c6c6548
	RvCtxMem[instanceId].data[4098] = 0x77202c6f
	RvCtxMem[instanceId].data[4099] = 0x646c726f
	RvCtxMem[instanceId].data[4100] = 0x00000a21
	setmetatable(RvCtxMem[instanceId].data, { __index = function(self) return 0 end })
end

local function RvCreateInstance (instanceId)
	if RvCtxCpu[instanceId] ~= nil then
		RvThrowException("RvCreateInstance: Instance id already in use.")
		return false
	end

	RvCtxCpu[instanceId] = {
		conf = {
			selfId = instanceId,
			freq = 1
		},
		stat = {
			isHalted = false,
			isAligned = true,
		},
		regs = {
			gp = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
			pc = 0
		}
	}
	RvCtxMem[instanceId] = {}
	local mem_ctx = RvCtxMem[instanceId]
	mem_ctx.data = {} -- {0x00108093}
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

local function RvPrintDebugInfo(id)
	if RvCtxMem[id] == nil then
		return false
	end

	local mem_ctx = RvCtxMem[id]
	print("segmentation: " .. tostring(mem_ctx.debug.segmentation))
	print("segment_size: " .. tostring(mem_ctx.debug.segment_size))
	print("panic_when_fault: " .. tostring(mem_ctx.debug.panic_when_fault))
	print("segment_map: " .. tostring(mem_ctx.debug.segment_map))

	return true
end

local function RvDeleteInstance (instanceId)
	if RvCtxCpu[instanceId] == nil then
		RvThrowException("RvDeleteInstance: Instance id already deleted.")
		return false
	end

	RvCtxMem[instanceId] = nil
	RvCtxCpu[instanceId] = nil

	return true
end

local function RvMemoryAccess (ctx, adr, mod, val)
	local retval
	local mem_ctx = RvCtxMem[ctx.conf.selfId]

	local ea = bit.rshift(adr, 2) + 1
	local offset = 0

	-- memory limit check
	if bit.bxor(bit.band(ea, 0x80000000), bit.band(RvConstMaxMemWord, 0x80000000)) == 0 then
		if ea > RvConstMaxMemWord then
			return nil
		end
	else
		if ea < RvConstMaxMemWord then
			return nil
		end
	end

	if mem_ctx.debug.segmentation == true then
		local ea = bit.rshift(adr, 2)
		ea = bit.rshift(ea, mem_ctx.debug.segment_size)
		if val ~= nil and mem_ctx.debug.segment_map[ea] == true then
			if mem_ctx.debug.panic_when_fault == true then
				RvPanic()
			end
		end
	end


	local rdOpTab = {
		-- LB
		function ()
			offset = bit.band(adr, 3)
			return bit.arshift(bit.lshift(bit.band(RvCtxMem[ctx.conf.selfId].data[ea], bit.lshift(0xFF, offset * 8)), (3 - offset) * 8), (3 - offset) * 8)
		end,
		-- LH
		function ()
			offset = bit.rshift(bit.band(adr, 3), 1)
			return bit.arshift(bit.lshift(bit.band(RvCtxMem[ctx.conf.selfId].data[ea], bit.lshift(0xFFFF, offset * 16))), (1 - offset) * 16)
		end,
		-- LW
		function ()
			return RvCtxMem[ctx.conf.selfId].data[ea]
		end,
		-- none
		function ()
			return nil
		end,
		-- LBU
		function ()
			offset = bit.band(adr, 3)
			return bit.rshift(bit.band(RvCtxMem[ctx.conf.selfId].data[ea], bit.lshift(0xFF, offset * 8)), offset)
		end,
		-- LHU
		function ()
			offset = bit.rshift(bit.band(adr, 3), 1)
			return bit.rshift(bit.band(RvCtxMem[ctx.conf.selfId].data[ea], bit.lshift(0xFFFF, offset * 16)), offset)
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
			local maskBit = bit.lshift(0xFF, offset * 8)
			RvCtxMem[ctx.conf.selfId].Data[ea] = bit.bor(bit.bxor(RvCtxMem[ctx.conf.selfId].data[ea], maskBit), bit.band(val, maskBit))
			return true
		end,
		-- SH
		function ()
			offset = bit.rshift(bit.band(adr, 3), 1)
			local maskBit = bit.lshift(0xFFFF, offset * 16)
			RvCtxMem[ctx.conf.selfId].Data[ea] = bit.bor(bit.bxor(RvCtxMem[ctx.conf.selfId].data[ea], maskBit), bit.band(val, maskBit))
			return true
		end,
		-- SW
		function ()
			RvCtxMem[ctx.conf.selfId].data[ea] = val
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

	return retval
end

local function RvFetchInstruction (ctx)
	return RvMemoryAccess(ctx, ctx.regs.pc, 3)
end

local function RvUpdatePc (ctx)
	ctx.regs.pc = ctx.regs.pc + 4
end

--[[
==================================================================
==================== Define of RISC-V Decoder ====================
==================================================================

]]

local function RvDecodeRV32C (ctx, inst)
	local function decVal1_0 ()
		return bit.band(inst, 0x3) + 1
	end

	local function decValFnt3 ()
		return bit.rshift(bit.band(inst, 0xE000), 13) + 1
	end


	local decTab1_0 = {
		function ()
			local rd_rs2 = bit.rshift(bit.band(inst, 0x1C), 2)
			local rs1 = bit.rshift(bit.band(inst, 0x0380), 7)
			local uimm = bit.rshift(bit.band(inst, 0x1C00), 7)
			uimm = bit.bor(uimm, bit.rshift(bit.band(inst, 0x0040), 4))
			uimm = bit.bor(uimm, bit.lshift(bit.band(inst, 0x0080), 1))

			local decTabFnt3 = {
				function ()
					local nzuimm = bit.rshift(bit.band(inst, 0x1FE0), 5)


				end,
				-- C.FLD
				function () return nil end, -- Not usable
				-- C.LW
				function ()
					ctx.regs.gp[rd_rs2] = RvMemoryAccess(ctx, ctx.regs.gp[rs1] + uimm, 3)
				end,
				-- C.FLW
				function () return nil end,
				-- Reserved
				function () return nil end,
				-- C.FSD
				function () return nil end,
				-- C.SW
				function ()
					RvMemoryAccess(ctx, ctx.regs.gp[rs1] + uimm, 3, ctx.regs.gp[rd_rs2])
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
	ctx.regs.gp[1] = 0
	return func()
end

local function RvDecodeRV32I (ctx, inst)
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
			local rd = bit.rshift(bit.band(inst, 0xF80), 7) + 1
			local rs1 = bit.rshift(bit.band(inst, 0xF8000), 15) + 1
			local rs2 = bit.rshift(bit.band(inst, 0x1F00000), 20) + 1 -- maybe plus one
			local imm = bit.arshift(bit.band(inst, 0xFFF00000), 20)

			local decTab6_5 = {
				function ()
					-- LB/LH/LW/LBU/LHU
					RvUpdatePc(ctx)
					if rd ~= 1 then
						ctx.regs.gp[rd] = RvMemoryAccess(ctx, ctx.regs.gp[rs1] + imm, decValFnt3())
					end

					if ctx.regs.gp[rd] == nil then
						RvThrowException("RvDecode: RvReadMemory returns nil value.")
						return nil
					end
				end,
				-- SB/SH/SW
				function ()
					RvUpdatePc(ctx)
					local imm = bit.bor(bit.arshift(bit.band(inst, 0xFE00000), 20), rd-1)
					return RvMemoryAccess(ctx, ctx.regs.gp[rs1] + imm, decValFnt3(), ctx.regs.gp[rs2])
				end,
				function ()
					return nil
				end,
				-- BEQ/BNE/BLT/BGE/BLTU/BGEU
				function ()
					imm = bit.band(inst, 0x80000000)
					imm = bit.bor(imm, bit.rshift(bit.band(inst, 0x7E000000), 1))
					imm = bit.bor(imm, bit.lshift(bit.band(inst, 0x00000080), 23))
					imm = bit.bor(imm, bit.lshift(bit.band(inst, 0x00000F00), 12))
					imm = bit.arshift(imm, 19)

					local decTabFnt3 = {
						-- BEQ
						function ()
							if ctx.regs.gp[rs1] == ctx.regs.gp[rs2] then
								ctx.regs.pc = ctx.regs.pc + imm
								return true
							end

							return false
						end,
						-- BNE
						function ()
							if ctx.regs.gp[rs1] ~= ctx.regs.gp[rs2] then
								ctx.regs.pc = ctx.regs.pc + imm
								return true
							end

							return false
						end,
						-- BLT
						function ()
							if ctx.regs.gp[rs1] < ctx.regs.gp[rs2] then
								ctx.regs.pc = ctx.regs.pc + imm
								return true
							end

							return false
						end,
						-- BGE
						function ()
							if ctx.regs.gp[rs1] >= ctx.regs.gp[rs2] then
								ctx.regs.pc = ctx.regs.pc + imm
								return true
							end

							return false
						end,
						-- BLTU
						function ()
							local rs1Value = ctx.regs.gp[rs1]
							local rs2Value = ctx.regs.gp[rs2]

							-- If both numbers are positive, just compare them. If not, reverse the comparison condition.
							if bit.bxor(bit.band(rs1Value, 0x80000000), bit.band(rs2Value, 0x80000000)) == 0 then
								if rs1Value < rs2Value then
									ctx.regs.pc = ctx.regs.pc + imm
									return true
								end
							else
								if rs1Value > rs2Value then
									ctx.regs.pc = ctx.regs.pc + imm
									return true
								end
							end

							return false
						end,
						-- BGEU
						function ()
							local rs1Value = ctx.regs.gp[rs1]
							local rs2Value = ctx.regs.gp[rs2]

							if rs1Value == rs2Value then
								ctx.regs.pc = ctx.regs.pc + imm
							elseif bit.bxor(bit.band(rs1Value, 0x80000000), bit.band(rs2Value, 0x80000000)) == 0 then
								if rs1Value >= rs2Value then
									ctx.regs.pc = ctx.regs.pc + imm
									return true
								end
							else
								if rs1Value < rs2Value then
									ctx.regs.pc = ctx.regs.pc + imm
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

					if not retval then RvUpdatePc(ctx) end

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

					local backup = ctx.regs.pc

					ctx.regs.pc = bit.band(ctx.regs.gp[rs1] + imm, 0xFFFFFFFE) -- then setting least-significant bit of the result to zero.
					ctx.regs.gp[rd] = backup
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
					ctx.regs.gp[rd] = ctx.regs.pc + 4
					ctx.regs.pc = bit.band(ctx.regs.pc + imm20, 0xFFFFFFFF)
				end,
			}
			local func = decTab6_5[decVal6_5()]
			if func == nil then return false end
			local retval = func()

			return retval
		end,
		-- ========== 100
		function ()
			local rd = bit.rshift(bit.band(inst, 0xF80), 7) + 1
			local rs1 = bit.rshift(bit.band(inst, 0xF8000), 15) + 1
			local decTab6_5 = {
				-- ========== 00
				function ()
					local imm = bit.arshift(bit.band(inst, 0xFFF00000), 20)
					local shamt = bit.band(imm, 0x1F)

					local decTabFnt3 = {
						-- ADDI
						function ()
							-- NOP
							if rd - 1 == 0 and imm == 0 then
								return true
							end

							ctx.regs.gp[rd] = bit.band(ctx.regs.gp[rs1] + imm, 0xFFFFFFFF)
						end,
						-- SLLI
						function ()
							if bit.rshift(bit.band(imm, 0xFE0), 5) ~= 0 then
								ctx.regs.gp[rd] = bit.band(bit.lshift(ctx.regs.gp[rs1], shamt), 0xFFFFFFFF)
							else
								return true
							end
						end,
						-- SLTI
						function ()
							if ctx.regs.gp[rs1] < imm then
								ctx.regs.gp[rd] = 1
							else
								ctx.regs.gp[rd] = 0
							end
						end,
						-- SLTIU
						function ()
							local rs1Value = ctx.regs.gp[rs1]

							if bit.bxor(bit.band(rs1Value, 0x80000000), bit.band(imm, 0x80000000)) == 0 then
								if rs1Value < imm then
									ctx.regs.gp[rd] = 1
								end
							else
								if not (rs1Value > imm) then
									ctx.regs.gp[rd] = 0
								end
							end
						end,
						-- XORI
						function ()
							ctx.regs.gp[rd] = bit.bxor(ctx.regs.gp[rs1], imm)
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

							ctx.regs.gp[rd] = op(ctx.regs[rs1], shamt)
						end,
						-- ORI
						function ()
							ctx.regs.gp[rd] = bit.bor(ctx.regs.gp[rs1], imm)
						end,
						-- ANDI
						function ()
							ctx.regs.gp[rd] = bit.band(ctx.regs.gp[rs1], imm)
						end
					}

					local func = decTabFnt3[decValFnt3()]
					if func == nil then return false end
					local retval = func()

					RvUpdatePc(ctx)
					return retval
				end,
				-- ========== 01
				function ()
					local rs2 = bit.rshift(bit.band(inst, 0x1F00000), 20) + 1
					local fnt7 = bit.rshift(bit.band(inst, 0xFE0000000), 29)

					local decTabFnt3 = {
						-- ADD/SUB
						function ()
							local op

							if fnt7 == 0 then
								ctx.regs.gp[rd] = bit.band(ctx.regs.gp[rs1] + ctx.regs.gp[rs2], 0xFFFFFFFF)
							elseif fnt7 ~= 0 then
								ctx.regs.gp[rd] = bit.band(ctx.regs.gp[rs1] - ctx.regs.gp[rs2], 0xFFFFFFFF)
							end

							return true
						end,
						-- SLL
						function ()
							ctx.regs.gp[rd] = bit.band(bit.lshift(ctx.regs.gp[rs1], ctx.regs.gp[rs2]))

							return true
						end,
						-- SLT
						function ()
							if ctx.regs.gp[rs1] < ctx.regs.gp[rs2] then
								ctx.regs.gp[rd] = 1
							else
								ctx.regs.gp[rd] = 0
							end

							return true
						end,
						-- SLTU
						function ()
							local rs1Value = ctx.regs.gp[rs1]
							local rs2Value = ctx.regs.gp[rs2]

							if bit.bxor(bit.band(rs1Value, 0x80000000), bit.band(rs2Value, 0x80000000)) == 0 then
								if rs1Value < rs2Value then
									ctx.regs.gp[rd] = 1
								end
							else
								if not (rs1Value > rs2Value) then
									ctx.regs.gp[rd] = 0
								end
							end

							return true
						end,
						-- XOR
						function ()
							ctx.regs.gp[rd] = bit.bxor(ctx.regs.gp[rs1], ctx.regs.gp[rs2])
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

							ctx.regs.gp[rd] = op(ctx.regs.gp[rs1], ctx.regs.gp[rs2])
							return true
						end,
						-- OR
						function ()
							ctx.regs.gp[rd] = bit.bor(ctx.regs.gp[rs1], ctx.regs.gp[rs2])
							return true
						end,
						-- AND
						function ()
							ctx.regs.gp[rd] = bit.band(ctx.regs.gp[rs1], ctx.regs.gp[rs2])
							return true
						end
					}

					local func = decTabFnt3[decValFnt3()]
					if func == nil then return false end
					local retval = func()

					RvUpdatePc(ctx)
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
					ctx.regs.gp[rd] = bit.band(ctx.regs.pc + imm20, 0xFFFFFFFF)
				end,
				function ()
					ctx.regs.gp[rd] = imm20
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

			RvUpdatePc(ctx)
			return func()
		end,
		-- ========== 110
		function ()
			return nil
		end,
		-- ========== 111 Not Supported other instruction length
		function ()
			RvThrowException("RvDecode: Invalid instruction.")
			return false
		end
	}

	local func = decTab4_2[decVal4_2()]
	if func == nil then return false end
	print("Debug Info, PC: " .. tostring(ctx.regs.pc))
	retval = func()

	ctx.regs.gp[1] = 0
	return retval
end

local function RvDecode (ctx)
	local inst = RvFetchInstruction(ctx)
	local retval1
	local retval2

	-- When instruction is C extension
	if bit.band(inst, 3) ~= 3 then
		retval1 = RvDecodeRV32C (ctx, inst)
		retval2 = RvDecodeRV32C (ctx, bit.rshift(bit.band(inst, 0xFFFF0000), 16))
		if retval1 == nil and retval2 == nil then
			return nil
		else
			return false
		end
	else
		retval1 = RvDecodeRV32I (ctx, inst)
	end

	return retval1
end

local RvRegisterElements

RvRegisterElements = elements.allocate(RvConstModIdent, "CPU")
elements.element(RvRegisterElements, elements.element(elements.DEFAULT_PT_ARAY))
elements.property(RvRegisterElements, "Name", "CPU")
elements.property(RvRegisterElements, "Description", "RISC-V 32-Bit CPU, RV32I set is being implemented.")
elements.property(RvRegisterElements, "Colour", 0x6644FF)
elements.property(RvRegisterElements, "MenuSection", elem.SC_ELEC)
elements.property(RvRegisterElements, "Gravity", 0)
elements.property(RvRegisterElements, "Flammable", 0)
elements.property(RvRegisterElements, "Explosive", 0)
elements.property(RvRegisterElements, "Loss", 0)
elements.property(RvRegisterElements, "AirLoss", 1)
elements.property(RvRegisterElements, "AirDrag", 0)
elements.property(RvRegisterElements, "Advection", 1)
elements.property(RvRegisterElements, "Weight", 0)
elements.property(RvRegisterElements, "Diffusion", 0)

--[[ deprecated
elements.property(RvRegisterElements, "HighTemperature", 4000.0 + 273.15)
elements.property(RvRegisterElements, "HighTemperatureTransition", elements.DEFAULT_PT_BMTL)
]]

elements.property(RvRegisterElements, "Create", function (i, x, y, s, n)
	tpt.set_property('ctype', 0, x, y)
end)

-- temp  : not allocated
-- ctype : instance id, if any negative value, cpu is halted.
-- life  : not allocated
-- tmp   : not allocated
-- tmp2  : not allocated
-- tmp3  : not allocated
-- tmp4  : not allocated

elements.property(RvRegisterElements, "Update", function (i, x, y, s, n)
	local instanceId = tpt.get_property('ctype', x, y)

	if instanceId <= 0 then -- When processor is not active
		return
	elseif RvCtxCpu[instanceId] == nil then
		tpt.set_property('ctype', -1, x, y) -- this instance id is not initialized or invalid.
		return
	end

	-- Debug
	-- tpt.set_property('life', instanceId, x, y)
	
	local ctx = RvCtxCpu[instanceId]
	local freq = ctx.conf.freq

	for i = 1, freq do
		RvDecode(ctx)
	end

	--[[ What the fscking that?
	local temp = tpt.get_property('temp', x, y)
	tpt.set_property('temp', temp + ctx.conf.freq * 1.41, x, y)
	]]

	return
end)

RvRegisterElements = elements.allocate(RvConstModIdent, "CFG")
elements.element(RvRegisterElements, elements.element(elements.DEFAULT_PT_ARAY))
elements.property(RvRegisterElements, "Name", "CFG")
elements.property(RvRegisterElements, "Description", "Configuration, check or set the instance state of Computer mod.")
elements.property(RvRegisterElements, "Colour", 0x6644FF)
elements.property(RvRegisterElements, "MenuSection", elem.SC_ELEC)
elements.property(RvRegisterElements, "Gravity", 0)
elements.property(RvRegisterElements, "Flammable", 0)
elements.property(RvRegisterElements, "Explosive", 0)
elements.property(RvRegisterElements, "Loss", 0)
elements.property(RvRegisterElements, "AirLoss", 1)
elements.property(RvRegisterElements, "AirDrag", 0)
elements.property(RvRegisterElements, "Advection", 1)
elements.property(RvRegisterElements, "Weight", 0)
elements.property(RvRegisterElements, "Diffusion", 0)

elements.property(RvRegisterElements, "Update", function (i, x, y, s, n)
	local currentLife = tpt.get_property('life', x, y)

	if currentLife == 0 then -- no operation
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

	-- Caution! : API is unstable
	local id = tpt.get_property('ctype', x, y)

	local cfgOpTab = {
		-- get the register value
		function ()
			local regNum = tpt.get_property('tmp3', x, y)

			local ctx = RvCtxCpu[id]
			if ctx == nil then
				setErrorLevel(1)
				return
			end

			local ret1

			if regNum == 0 then
				ret1 = ctx.regs.pc
			else
				ret1 = ctx.regs.gp[regNum]
			end

			setReturn(ret1, 0)

			return true
		end,
		-- set the register value
		function ()
			local regNum = tpt.get_property('tmp3', x, y)

			local ctx = RvCtxCpu[id]
			if ctx == nil then
				setErrorLevel(1)
				return
			end

			if regNum == 0 then
				ctx.regs.pc = bit.band(tpt.get_property('tmp', x, y))
			else
				ctx.regs.gp[regNum] = bit.band(tpt.get_property('tmp', x, y))
			end

			setReturn(0, 0)

			return true
		end,
		-- get the current frequency
		function ()
			local ctx
			if RvCtxCpu[id] == nil then
				setErrorLevel(1)
				return
			end
			ctx = RvCtxCpu[id]

			setReturn(ctx.conf.freq, 0)

			return true
		end,
		-- set the current frequency
		function ()
			local ctx
			if RvCtxCpu[id] == nil then
				setErrorLevel(1)
				return
			end
			ctx = RvCtxCpu[id]

			local newFreq = tpt.get_property('tmp3', x, y)
			if newFreq > RvConstMaxFreqMultiplier then
				setErrorLevel(1)
				return
			end

			ctx.conf.freq = newFreq
			setReturn(0, 0)

			return true
		end,
		-- (5) create instance
		function ()
			if not RvCreateInstance(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
			else
				setReturn(0, 0)
			end

			return true
		end,
		-- (6) delete instance
		function ()
			if not RvDeleteInstance(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
			else
				setReturn(0, 0)
			end

			return true
		end,
		-- (7) read memory
		function ()
			local adr = tpt.get_property('tmp3', x, y)
			local val = RvMemoryAccess(RvCtxCpu[id], adr, 3)

			if val == nil then
				RvThrowException("Configuration: RvMemoryAccess is failed to read.")
				return
			end

			setReturn(val, 0)
			return true
		end,
		-- (8) write memory
		function ()
			local adr = tpt.get_property('tmp3', x, y)
			local val = tpt.get_property('tmp4', x, y)

			RvMemoryAccess(RvCtxCpu[id], adr, 3, val)

			setReturn(0, 0)
			return true
		end,
		-- (9) load test program
		function ()
			RvLoadTestCode(id)
			return true
		end,
		-- (10) get debug info
		function ()
			if not RvPrintDebugInfo(id) then
				setErrorLevel(1)
			end

			setReturn(0, 0)
		end,
		-- (11) toggle debugging segmentation
		function ()
			RvCtxMem[id].debug.segmentation = bit.bxor(RvCtxMem[id].debug.segmentation, 1)
			setReturn(0, 0)
			return true
		end,
		-- (12) set or unset write protection on selected segment
		function ()
			local mem_ctx = RvCtxMem[id]
			local pos = tpt.get_property('tmp3', x, y)
			local val = tpt.get_property('tmp4', x, y)

			if val == 0 then
				val = false
			else
				val = true
			end

			mem_ctx.debug.segment_map[pos] = val

			setReturn(0, 0)
			return true
		end

	}

	local func = cfgOpTab[currentLife]
	if func == nil then
		setReturn(-1, -1)
	end

	if func() == nil then
		setErrorLevel(1)
	end

	return
end)
