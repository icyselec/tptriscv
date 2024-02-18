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
local RvConstMaxFreqMultiplier = 16666
local RvConstMaxTemperature = 120.0
local RvConstModIdent = "FREECOMPUTER"
local RvCtxCpu = {}
local RvCtxMem = {}

local function RvThrowException (msg)
	print(msg)
end

local function RvLoadTestProgram (instanceId)
	RvCtxMem[instanceId].data = {0x00108093}
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
			isHalted = false
			isAligned = true
		},
		regs = {
			gp = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
			pc = 0
		}
	}
	RvCtxMem[instanceId] = {}
	RvCtxMem[instanceId].data = {} -- {0x00108093}

	setmetatable(RvCtxMem[instanceId].data, { __index = function(self) return 0 end })

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
	local retval = 0

	local ea = bit.rshift(adr, 2) + 1
	local offset = 0

	-- memory limit check
	local rs1Value = ctx.regs.gp[rs1]

	if bit.bxor(bit.band(ea, 0x80000000), bit.band(RvConstMaxMemWord, 0x80000000)) == 0 then
		if ea > RvConstMaxMemWord then
			return nil
		end
	else
		if rs1Value < imm then
			return nil
		end
	end


	local rdOpTab = {
		-- LB
		function ()
			offset = bit.band(adr, 3)
			return bit.arshift(bit.lshift(bit.band(RvCtxMem[ctx.conf.selfId].data[ea], bit.lshift(0xFF, offset * 8)), (3 - offset) * 8))
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
		func = wrOpTab
	end

	if func == nil then return nil end
	return func()
end

local function RvFetchInstruction (ctx)
	local instruction = RvMemoryAccess(ctx, ctx.regs.pc, 3)
	ctx.regs.pc = ctx.regs.pc + 4
	return instruction
end

--[[
==================================================================
==================== Define of RISC-V Decoder ====================
==================================================================

]]

local function RvDecode (ctx)
	local inst = RvFetchInstruction(ctx)
	local retval

	-- When instruction is C extension
	if bit.band(inst, 3) ~= 3 then
		retval = RvDecodeRV32C (ctx, inst)
		retval = retval + RvDecodeRV32C (ctx, bit.rshift(bit.band(inst, 0xFFFF0000), 16))
	else
		retval = RvDecodeRV32I (ctx, inst)
	end

	return retval
end

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

	local func = decTab1_0[decVal4_2()]
	if func == nil then return false end
	local retval = func()

	-- register number 0 is always zero
	ctx.regs.gp[1] = 0
	return func()
end

local function RvDecodeRV32I (ctx, inst)
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
		function ()
			local rd = bit.rshift(bit.band(inst, 0xF80), 7) + 1
			local rs1 = bit.rshift(bit.band(inst, 0xF8000), 15) + 1
			local rs2 = bit.rshift(bit.band(inst, 0x1F00000), 20) + 1 -- maybe plus one
			local imm = bit.arshift(bit.band(inst, 0xFFF00000), 20)

			local decTab6_5 = {
				function ()
					-- LB/LH/LW/LBU/LHU
					if rd ~= 1 then
						ctx.regs.gp[rd] = RvMemoryAccess(ctx, ctx.regs.gp[rs1] + imm12, decValFnt3())
					end

					if ctx.regs.gp[rd] == nil then
						RvThrowException("RvDecode: RvReadMemory returns nil value.")
						return nil
					end
				end,
				-- SB/SH/SW
				function ()
					local imm = bit.bor(bit.arshift(bit.band(inst, 0xFE00000), 20), rd-1)
					return RvMemoryAccess(ctx, ctx.regs.gp[rs1] + imm, decValFnt3(), ctx.regs.gp[rs2])
				end,
				function ()
					return nil
				end,
				-- BEQ/BNE/BLT/BGE/BLTU/BGEU
				function ()
					imm = bit.band(inst, 0x80000000)
					imm = bit.bor(imm, bit.lshift(bit.band(inst, 0x80), 23))
					imm = bit.bor(imm, bit.rshift(bit.band(inst, 0x7E000000), 1))
					imm = bit.bor(imm, bit.lshift(bit.band(inst, 0xF00), 12))
					imm = bit.arshift(imm, 19)

					local decTabFnt3 = {
						-- BEQ
						function ()
							if ctx.regs.gp[rs1] == ctx.regs.gp[rs2] then
								ctx.regs.pc = ctx.regs.pc + imm
							end

							return true
						end,
						-- BNE
						function ()
							if ctx.regs.gp[rs1] ~= ctx.regs.gp[rs2] then
								ctx.regs.pc = ctx.regs.pc + imm
							end

							return true
						end,
						-- BLT
						function ()
							if ctx.regs.gp[rs1] < ctx.regs.gp[rs2] then
								ctx.regs.pc = ctx.regs.pc + imm
							end

							return true
						end,
						-- BGE
						function ()
							if ctx.regs.gp[rs1] >= ctx.regs.gp[rs2] then
								ctx.regs.pc = ctx.regs.pc + imm
							end

							return true
						end,
						-- BLTU
						function ()
							local rs1Value = ctx.regs.gp[rs1]
							local rs2Value = ctx.regs.gp[rs2]

							-- If both numbers are positive, just compare them. If not, reverse the comparison condition.
							if bit.bxor(bit.band(rs1Value, 0x80000000), bit.band(rs2Value, 0x80000000)) == 0 then
								if rs1Value < rs2Value then
									ctx.regs.pc = ctx.regs.pc + imm
								end
							else
								if rs1Value > rs2Value then
									ctx.regs.pc = ctx.regs.pc + imm
								end
							end

							return true
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
								end
							else
								if rs1Value < rs2Value then
									ctx.regs.pc = ctx.regs.pc + imm
								end
							end

							return true
						end,
						-- none
						function () return nil end,
						-- none
						function () return nil end,
					}

					local func = decTabFnt3[decValFnt3()]
					if func == nil then return false end
					local retval = func()

					return retval
				end,
			}

			local func = decTab6_5[decVal6_5()]
			if func == nil then return nil end
			return func()
		end,
		function ()
			return nil
		end,
		function ()
			return nil
		end,
		function ()
			return nil
		end,
		function ()
			local rd = bit.rshift(bit.band(inst, 0xF80), 7) + 1
			local rs1 = bit.rshift(bit.band(inst, 0xF8000), 15) + 1
			local decTab6_5 = {
				function ()
					local imm = bit.arshift(bit.band(inst, 0xFFF00000), 20)
					local shamt = bit.band(imm, 0x1F)

					local decTabFnt3 = {
						-- ADDI
						function ()
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

					-- register number 0 is always zero
					ctx.regs.gp[1] = 0

					return retval
				end,
				function ()
					local rs2 = bit.rshift(bit.band(inst, 0x1F00000), 20) + 1
					local fnt7 = bit.rshift(bit.band(imm, 0xFE0), 25)

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

					-- register number 0 is always zero
					ctx.regs.gp[1] = 0

					return retval
				end,
				function ()
					return nil
				end,
				function ()
					return nil
				end
			}

			local func = decTab6_5[decVal6_5()]
			if func == nil then return false end
			return func()
		end,
		function ()
			return nil
		end,
		function ()
			return nil
		end,
		-- Not Supported other instruction length
		function ()
			RvThrwoException("RvDecode: Invalid instruction.")
			return false
		end
	}

	local func = decTab4_2[decVal4_2()]
	if func == nil then return false end
	return func()
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

elements.property(RvRegisterElements, "HighTemperature", 4000.0 + 273.15)
elements.property(RvRegisterElements, "HighTemperatureTransition", elements.DEFAULT_PT_BMTL)

elements.property(RvRegisterElements, "Create", function (i, x, y, s, n)
	tpt.set_property('ctype', 0, x, y)
end)

-- temp  : If the temperature is high, it means that the processor is operating at a high frequency.
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

	local temp = tpt.get_property('temp', x, y)
	tpt.set_property('temp', temp + ctx.conf.freq * 1.41, x, y)

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
		if errnum < 0 then errnum = -errNum end
		tpt.set_property('life', -errNum, x, y)
	end

	-- Caution! : API is unstable
	local id = tpt.get_property('ctype', x, y)

	local cfgOpTab = {
		-- get the register value
		function ()
			local regNum = tpt.get_property('tmp4', x, y)

			local ctx = RvCtxCpu[id]
			if ctx == nil then
				setErrorLevel(1)
				return
			end

			if regNum == 0 then
				tpt.set_property('tmp', ctx.regs.pc, x, y)
			else
				tpt.set_property('tmp', ctx.regs.gp[regNum], x, y)
			end

			tpt.set_property('tmp2', 0, x, y)
		end,
		-- set the register value
		function ()
			local regNum = tpt.get_property('tmp4', x, y)

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

			tpt.set_property('tmp2', 0, x, y)
		end,
		-- get the current frequency
		function ()
			local ctx
			if RvCtxCpu[id] == nil then
				setErrorLevel(1)
				return
			end
			ctx = RvCtxCpu[id]

			tpt.set_property('tmp', ctx.conf.freq, x, y)

			tpt.set_property('tmp2', 0, x, y)
		end,
		-- set the current frequency
		function ()
			local ctx
			if RvCtxCpu[id] == nil then
				setErrorLevel(1)
				return
			end
			ctx = RvCtxCpu[id]

			local newFreq = tpt.get_property('tmp4', x, y)
			if newFreq > RvConstMaxFreqMultiplier then
				setErrorLevel(1)
				return
			end

			ctx.conf.freq = tpt.get_property('tmp4', x, y)
			tpt.set_property('tmp', 0, x, y)
			tpt.set_property('tmp2', 0, x, y)
		end,
		-- create instance
		function ()
			if not RvCreateInstance(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
			else
				setReturn(0, 0)
			end
		end,
		-- delete instance
		function ()
			if not RvDeleteInstance(id) then
				setReturn(-1, -1)
				setErrorLevel(1)
			else
				setReturn(0, 0)
			end

		end,
		-- read memory
		function ()
			local adr = tpt.get_property('tmp3', x, y)
			local val = RvMemoryAccess(RvCtxCpu[id], adr, 3)

			if val == nil then
				RvThrowException("Configuration: RvMemoryAccess is failed to read.")
				return
			end

			setReturn(val, 0)
			return
		end,
		-- write memory
		function ()
			local adr = tpt.get_property('tmp3', x, y)
			local val = tpt.get_property('tmp4', x, y)

			RvMemoryAccess(RvCtxCpu[id], adr, 3, val)

			setReturn(0, 0)
			return
		end,
	}

	local func = cfgOpTab[currentLife]
	if func == nil then
		setReturn(-1, -1)
	end

	if func() == nil then
		setErrorLevel(0)
	end

	return
end)
