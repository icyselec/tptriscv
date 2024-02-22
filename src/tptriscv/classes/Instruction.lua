local Reg = require("tptriscv.classes.Reg")
local Integer = require("tptriscv.classes.Integer")

---@class Instruction
---@field core Cpu
---@field size Integer
---@field cmds u32[]
local Instruction = {
	core = {},
	size = 0,
	cmds = {},
}

--- Instruction constructor
---@param o? table
---@return Instruction?
function Instruction:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	if o.core == nil then
		print("Instruction:constructor: Failed to initialization, cpu core reference is nil.")
		return nil
	end

	return o
end

---@return boolean
function Instruction:fetch_instruction ()
	---@type Cpu
	local cpu = self.core
	---@type Mem
	local mem = cpu.refs.mem
	self.cmds[1] = mem:safe_read(cpu, cpu.regs:get_pc(), 3) --[[@as u32]]

	local bit1_0 = bit.band(self.cmds[1], 0x03)

	-- When instruction is C extension
	if bit1_0 ~= 3 then
		if cpu.conf:get_config("enable_rv32c") then
			self.size = 2
			return true
		else
			cpu:halt("Instruction:run: Unsupported extension.")
			return false
		end
	end

	local bit4_2 = bit.rshift(bit.band(self.cmds[1], 0x001C), 2)

	-- Standard 32-bit
	if bit4_2 ~= 7 then
		self.size = 4
		return true
	end

	local bit6_5 = bit.rshift(bit.band(self.cmds[1], 0x0060), 5)
	self.cmds[2] = mem:safe_read(cpu, cpu.regs:get_pc() + 4, 3) --[[@as u32]]

	-- Extended 48-bit
	if bit.band(bit6_5, 1) == 0 then
		self.size = 6
	-- Extended 64-bit
	elseif bit6_5 == 1 then
		self.size = 8
	end

	cpu:halt("Instruction:fetch_instruction: Instruction length too long.")
	return false


	--[=[
	local bit14_12 = bit.rshift(bit.band(self.cmds[1], 0x7000), 12)

	self.size = 10 + 2 * bit14_12
	self.cmds[3] = mem:access(cpu, cpu.regs:access_pc() + 4, 3) --[[@as u32]]

	if bit14_12 == 7 then
		rv.throw("Instruction:fetch_instruction: Instruction length too long.")
		return false
	end

	local optab = {
		function ()
			return
		end,
		function ()

		end,
		function () end,
		function () end,
	}

	optab[bit14_12 + 1]()

	]=]
end

---@param disasm boolean
---@return boolean|nil
function Instruction:decode_ext_m (disasm)
	local cmd = self.cmds[1]
	local rd  = bit.rshift(bit.band(cmd, 0x00000F80),  7)
	local rs1 = bit.rshift(bit.band(cmd, 0x000F8000), 15)
	local rs2 = bit.rshift(bit.band(cmd, 0x01F00000), 20)
--	local fnt7 = bit.rshift(bit.band(cmd, 0xFE0000000), 29)
	local cpu = self.core
	local reg = cpu.regs

	local decTabFnt3 = {
		-- MUL
		function ()
			reg:set_gp(rd, reg:get_gp(rs1) * reg:get_gp(rs2))

			if disasm then
				return string.format("%s %s, %s, %s", "MUL", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
			end
		end,
		-- MULH
		function ()
			cpu:halt("Instruction:decode_ext_m: Not implemented instruction, processor is stopped.")

			if disasm then
				return string.format("%s %s, %s, %s", "MULH", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
			end
		end,
		-- MULHSU
		function ()
			cpu:halt("Instruction:decode_ext_m: Not implemented instruction, processor is stopped.")

			if disasm then
				return string.format("%s %s, %s, %s", "MULHSU", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
			end
		end,
		-- MULHU
		function ()
			cpu:halt("Instruction:decode_ext_m: Not implemented instruction, processor is stopped.")

			if disasm then
				return string.format("%s %s, %s, %s", "MULHU", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
			end
		end,
		-- DIV
		function ()
			if reg:get_gp(rs2) == 0 then
				cpu:halt("Instruction:decode_ext_m: Divide by Zero.")
				return RV.ILLEGAL_INSTRUCTION
			end

			reg:set_gp(rd, reg:get_gp(rs1) / reg:get_gp(rs2))

			if disasm then
				return string.format("%s %s, %s, %s", "DIV", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
			end
		end,
		-- DIVU
		function ()
			cpu:halt("Instruction:decode_ext_m: Not implemented instruction, processor is stopped.")

			if disasm then
				return string.format("%s %s, %s, %s", "DIVU", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
			end
		end,
		-- REM '꽈배기'
		function ()
			if reg:get_gp(rs2) == 0 then
				cpu:halt("Instruction:decode_ext_m: Divide by Zero.")
				return nil
			end

			reg:set_gp(rd, reg:get_gp(rs1) % reg:get_gp(rs2))

			if disasm then
				return string.format("%s %s, %s, %s", "REM", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
			end
		end,
		-- REMU
		function ()
			cpu:halt("Instruction:decode_ext_m: Not implemented instruction, processor is stopped.")

			if disasm then
				return string.format("%s %s, %s, %s", "REMU", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
			end
		end,
	}

	return decTabFnt3[bit.rshift(bit.band(cmd, 0x7000), 12) + 1]()
end

--- Decoding and execute 16-bit length instruction.
---@private
---@param disasm boolean If true, then print the disassembled instruction.
---@return string|nil
function Instruction:decode_16bit (disasm)
	disasm = disasm or false
	local cpu = self.core
	local mem = self.core.ref_mem
	local reg = self.core.regs
	local cmd = self.cmds[1]
	local size = self.size

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
						cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")

						if disasm then
							return RV.ILLEGAL_INSTRUCTION
						else
							return nil
						end
					end

					reg:set_gp(rd, reg:get_gp(2) + nzuimm)

					if disasm then
						return string.format("%s %s, %d", "C.ADDI4SPN", Reg:getname(rd), nzuimm)
					end
				end,
				-- C.FLD -- not yet implemented
				function ()
					cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")

					if disasm then
						return RV.ILLEGAL_INSTRUCTION
					end
				end,
				-- C.LW
				function ()
					reg:set_gp(rd, mem:safe_read(cpu, reg:get_gp(rs1) + uimm, 3) --[[@as i32]])

					if disasm then
						return string.format("%s %s, %s(%s)", "C.LW", Reg:getname(rd), tostring(uimm), Reg:getname(rs1))
					end
				end,
				-- C.FLW
				function ()
					cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")

					if disasm then
						return RV.ILLEGAL_INSTRUCTION
					else
						return nil
					end
				end,
				-- Reserved
				function ()
					cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")

					if disasm then
						return RV.ILLEGAL_INSTRUCTION
					else
						return nil
					end
				end,
				-- C.FSD -- not yet implemented
				function ()
					cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")

					if disasm then
						return RV.ILLEGAL_INSTRUCTION
					else
						return nil
					end
				end,
				-- C.SW
				function ()
					mem:safe_write(cpu, reg:get_gp(rs1) + uimm, 3, reg:get_gp(rs2))
					if disasm then
						return string.format("%s %s, %d(%s)", "C.SW", Reg:getname(rs2), uimm, Reg:getname(rs1))
					end
				end,
				-- C.FSW
				function ()
					cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")

					if disasm then
						return RV.ILLEGAL_INSTRUCTION
					end
				end,
			}

			return decTabFnt3[decValFnt3()]()
		end,
		-- ==================== 01,
		function ()
			local rs1 = bit.rshift(bit.band(cmd, 0x0F80), 7) --[[@as Integer]]
			local rs2 = bit.rshift(bit.band(cmd, 0x007C), 2) --[[@as Integer]]

			local decTabFnt3 = {
				-- C.NOP/C.ADDI
				function ()
					local  imm6 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm6 = imm6 + bit.lshift(rs2, 28)
					imm6 = bit.arshift(imm6, 26)

					if rs1 == 0 and imm6 == 0 then
						return "C.NOP"
					elseif imm6 == 0 then
						return nil
					end

					reg:set_gp(rs1, reg:get_gp(rs1) + imm6)
					reg:update_pc(size)

					if disasm then
						return string.format("%s %s, %d", "C.ADDI", Reg:getname(rs1), imm6)
					end
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

					reg:set_gp(1, reg:get_pc() + 2)
					reg:set_pc(reg:get_pc() + imm11)

					if disasm then
						return string.format("%s %s, %d", "C.JAL", Reg:getname(1), imm11)
					end
				end,
				-- C.LI
				function ()
					if rs1 == 0 then
						return false
					end

					local  imm6 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm6 = imm6 + bit.lshift(rs2, 28)
					imm6 = bit.arshift(imm6, 26)

					reg:set_gp(rs1, imm6)
					reg:update_pc(size)

					if disasm then
						return string.format("%s %s, %d", "C.LI", Reg:getname(rs1), imm6)
					end
				end,
				-- C.ADDI16SP/C.LUI
				function ()
					local retstr = nil
					-- HINT
					if rs1 == 0 then
						retstr = "HINT"
					-- C.ADDI16SP
					elseif rs1 == 2 then
						local     imm16sp = bit.lshift(bit.band(cmd, 0x1000), 19)
						imm16sp = imm16sp + bit.lshift(bit.band(cmd, 0x0018), 26)
						imm16sp = imm16sp + bit.lshift(bit.band(cmd, 0x0020), 23)
						imm16sp = imm16sp + bit.lshift(bit.band(cmd, 0x0004), 25)
						imm16sp = imm16sp + bit.lshift(bit.band(cmd, 0x0040), 20)
						imm16sp = bit.arshift(imm16sp, 22)

						reg:set_gp(rs1, reg:get_gp(rs1) + imm16sp)
						if disasm then
							retstr = string.format("%s %s, %d", "C.ADDI16SP", Reg:getname(2), imm16sp)
						end
					-- C.LUI
					else
						local  imm6 = bit.lshift(bit.band(cmd, 0x1000), 19)
						imm6 = imm6 + bit.lshift(rs2, 28)
						imm6 = bit.arshift(imm6, 14)

						reg:set_gp(rs1, imm6)
						if disasm then
							retstr = string.format("%s %s, %d", "C.LUI", Reg:getname(rs1), imm6)
						end
					end

					reg:update_pc(size)
					return retstr
				end,
				-- C.SRLI/C.SRAI/C.ANDI/C.SUB/C.XOR/C.OR/C.AND
				function ()
					local rd = bit.band(rs1, 0x7)

					local decTabFnt2 = {
						-- C.SRLI
						function ()
							if bit.band(cmd, 0x1000) ~= 0 then
								cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
								return RV.ILLEGAL_INSTRUCTION
							end

							reg:set_gp(rd, bit.rshift(reg:get_gp(rd), rs2))
							reg:update_pc(size)

							if disasm then
								return string.format("%s %s, %d", "C.SRLI", Reg:getname(rd), rs2)
							end
						end,
						-- C.SRAI
						function ()
							if bit.band(cmd, 0x1000) ~= 0 then
								cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
								return RV.ILLEGAL_INSTRUCTION
							end

							reg:set_gp(rd, bit.arshift(reg:get_gp(rd), rs2))
							reg:update_pc(size)

							if disasm then
								return string.format("%s %s, %d", "C.SRAI", Reg:getname(rd), rs2)
							end
						end,
						-- C.ANDI
						function ()
							local imm6 = rs2 + bit.arshift(bit.lshift(bit.band(cmd, 0x1000), 19), 26)

							reg:set_gp(rd, bit.band(reg:get_gp(rd), imm6))
							reg:update_pc(size)

							if disasm then
								return string.format("%s %s, %d", "C.ANDI", Reg:getname(rd), imm6)
							end
						end,
						-- C.SUB/C.XOR/C.OR/C.AND
						function ()
							rs1 = bit.band(rs1, 0x7)
							rs2 = bit.band(rs2, 0x7)
							rd = rs1

							if bit.band(cmd, 0x1000) ~= 0 then
								cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
								return RV.ILLEGAL_INSTRUCTION
							end

							local decTabSubFnt2 = {
								-- C.SUB
								function ()
									reg:set_gp(rd, reg:get_gp(rs1) - reg:get_gp(rs2))

									if disasm then
										return string.format("%s %s, %s", "C.SUB", Reg:getname(rs1), Reg:getname(rs2))
									end
								end,
								-- C.XOR
								function ()
									reg:set_gp(rd, bit.bxor(reg:get_gp(rs1), reg:get_gp(rs2)))

									if disasm then
										return string.format("%s %s, %s", "C.XOR", Reg:getname(rs1), Reg:getname(rs2))
									end
								end,
								-- C.OR
								function ()
									reg:set_gp(rd, bit.bor(reg:get_gp(rs1), reg:get_gp(rs2)))

									if disasm then
										return string.format("%s %s, %s", "C.OR", Reg:getname(rs1), Reg:getname(rs2))
									end
								end,
								-- C.AND
								function ()
									reg:set_gp(rd, bit.band(reg:get_gp(rs1), reg:get_gp(rs2)))

									if disasm then
										return string.format("%s %s, %s", "C.AND", Reg:getname(rs1), Reg:getname(rs2))
									end
								end,
							}

							local retval = decTabSubFnt2[bit.rshift(bit.band(cmd, 0x0060), 5) + 1]()
							reg:update_pc(size)
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

					reg:set_pc(reg:get_pc() + imm11)

					if disasm then
						return string.format("%s %d", "C.J", imm11)
					end
				end,
				-- C.BEQZ
				function ()
					local  imm8 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0060), 24)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0004), 26)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0C00), 16)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0018), 21)
					imm8 = bit.arshift(imm8, 26)

					if reg:set_gp(bit.band(rs1, 0x7)) == 0 then
						reg:set_pc(reg:get_pc() + imm8)
					end

					if disasm then
						return string.format("%s %s, %d", "C.BEQZ", Reg:getname(rs1), imm8)
					end
				end,
				-- C.BNEZ
				function ()
					local  imm8 = bit.lshift(bit.band(cmd, 0x1000), 19)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0060), 24)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0004), 26)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0C00), 16)
					imm8 = imm8 + bit.lshift(bit.band(cmd, 0x0018), 21)
					imm8 = bit.arshift(imm8, 26)

					if reg:set_gp(bit.band(rs1, 0x7)) ~= 0 then
						reg:set_pc(reg:get_pc() + imm8)
					end

					if disasm then
						return string.format("%s %s, %d", "C.BNEZ", Reg:getname(rs1), imm8)
					end
				end,
			}
			local func = decTabFnt3[decValFnt3()]
			return func()
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
						return RV.ILLEGAL_INSTRUCTION
					end

					reg:set_gp(rd, bit.lshift(reg:get_gp(rd), nzuimm))
					reg:update_pc(size)

					if disasm then
						return string.format("%s %s, %d", "C.SLLI", Reg:getname(rd), nzuimm)
					end
				end,
				-- C.FLDSP
				function ()
					cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
				-- C.LWSP
				function ()
					local uimm = imm1 + bit.rshift(bit.band(cmd, 0x0070), 2) + bit.lshift(bit.band(cmd, 0x00C0), 4)
					reg:set_gp(rd, mem:safe_read(cpu, reg:get_gp(2) + uimm, 3) --[[@as i32]])
					reg:update_pc(size)

					if disasm then
						return string.format("%s %s, %d(%s)", "C.LWSP", Reg:getname(rd), uimm, Reg:getname(2))
					end
				end,
				-- C.FLWSP (Not Implement)
				function ()
					cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
				-- C.JR/C.MV/C.EBREAK/C.JALR/C.ADD
				function ()
					local retstr = nil
					if bit.band(cmd, 0x1000) == 0 then
						-- C.MV
						if rd ~= 0 and rs2 ~= 0 then
							reg:set_gp(rd, reg:get_gp(rs2))
							reg:update_pc(size)
							retstr = string.format("%s %s, %s", "C.MV", Reg:getname(rd), Reg:getname(rs2))
						-- C.JR
						elseif rd ~= 0 and rs2 == 0 then
							reg:set_pc(reg:get_gp(rs1))
							retstr = string.format("%s %s", "C.JR", Reg:getname(rs1))
						end
					else
						-- C.EBREAK
						if rs1 == 0 and rs2 == 0 then
							retstr = "C.EBREAK"
						-- C.JALR
						elseif rs1 ~= 0 and rs2 == 0 then
							local backup = reg:get_gp(rs1)
							reg:set_gp(1, reg:get_pc() + 2)
							reg:set_pc(backup)
							retstr = string.format("%s %s", "C.JALR", Reg:getname(rs1))
						-- C.ADD
						elseif rs1 ~= 0 and rs2 ~= 0 then
							reg:set_gp(rd, reg:get_gp(rs1) + reg:get_gp(rs2))
							reg:update_pc(size)
							retstr = string.format("%s %s, %s", "C.ADD", Reg:getname(rs1), Reg:getname(rs2))
						end
					end

					return retstr
				end,
				-- C.FSDSP
				function ()
					cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
				-- C.SWSP
				function ()
					local uimm = bit.lshift(rs1, 2) + bit.rshift(bit.band(cmd, 0x1000), 5)
					reg:set_gp(rd, mem:safe_write(cpu, reg:get_gp(2) + uimm, 3, reg:get_gp(rs2)) --[[@as number]])
					reg:update_pc(size)

					if disasm then
						return string.format("%s %s, %d(%s)", "C.SWSP", Reg:getname(rs2), uimm, Reg:getname(2))
					end
				end,
				-- C.FSWSP (Not Implement)
				function ()
					cpu:halt("Cpu:decode_rv32c: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
			}

			return decTabFnt3[decValFnt3()]()
		end,
	}
	return decTab1_0[decVal1_0()]()
end



function Instruction:decode_32bit (disasm)
	local cpu = self.core
	local reg = cpu.regs
	local mem = cpu.refs.mem
	local cmd = self.cmds[1]
	local size = self.size

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
			local rd  = bit.rshift(bit.band(cmd, 0x00000F80), 7)
			local rs1 = bit.rshift(bit.band(cmd, 0x000F8000), 15)
			local rs2 = bit.rshift(bit.band(cmd, 0x01F00000), 20)

			local function get_ldtype (mod)
				local typtab = {
					"LB",
					"LH",
					"LW",
					nil,
					"LBU",
					"LHU",
				}
				return typtab[mod]
			end

			local function get_sttype (mod)
				local typtab = {
					"SB",
					"SH",
					"SW",
				}
				return typtab[mod]
			end

			local function get_branch_target ()
				local imm = bit.band(cmd, 0x80000000)
				imm = bit.bor(imm, bit.rshift(bit.band(cmd, 0x7E000000), 1))
				imm = bit.bor(imm, bit.lshift(bit.band(cmd, 0x00000080), 23))
				imm = bit.bor(imm, bit.lshift(bit.band(cmd, 0x00000F00), 12))
				return bit.arshift(imm, 19)
			end

			local decTab6_5 = {
				-- LB/LH/LW/LBU/LHU
				function ()
					local imm = bit.arshift(bit.band(cmd, 0xFFF00000), 20)
					local fnt = decValFnt3()
					reg:set_gp(rd, mem:safe_read(cpu, reg:get_gp(rs1) + imm, fnt) --[[@as Integer]])
					reg:update_pc(size)

					if disasm then
						local ldtype = get_ldtype(fnt)

						if ldtype == nil then
							return RV.ILLEGAL_INSTRUCTION
						end

						return string.format("%s %s, %d(%s)", ldtype, Reg:getname(rd), imm, Reg:getname(rs1))
					end
				end,
				-- SB/SH/SW
				function ()
					local imm = bit.bor(bit.arshift(bit.band(cmd, 0xFE000000), 20), rd)
					local fnt = decValFnt3()
					mem:safe_write(cpu, reg:get_gp(rs1) + imm, fnt, reg:get_gp(rs2))
					reg:update_pc(size)

					if disasm then
						local sttype = get_sttype(fnt)

						if sttype == nil then
							return RV.ILLEGAL_INSTRUCTION
						end

						return string.format("%s %s, %d(%s)", sttype, Reg:getname(rs2), imm, Reg:getname(rs1))
					end
				end,
				function ()
					cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
				-- BEQ/BNE/BLT/BGE/BLTU/BGEU
				function ()
					local rs1_value = reg:get_gp(rs1)
					local rs2_value = reg:get_gp(rs2)

					local decTabFnt3 = {
						-- BEQ
						function ()
							local target = get_branch_target()

							if rs1_value == rs2_value then
								reg:set_pc(reg:get_pc() + target)
							else
								reg:update_pc(size)
							end

							if disasm then
								return string.format("%s %s, %s, %d", "BEQ", Reg:getname(rs1), Reg:getname(rs2), target)
							end
						end,
						-- BNE
						function ()
							local target = get_branch_target()

							if rs1_value ~= rs2_value then
								reg:set_pc(reg:get_pc() + target)
							else
								reg:update_pc(size)
							end

							if disasm then
								return string.format("%s %s, %s, %d", "BNE", Reg:getname(rs1), Reg:getname(rs2), target)
							end
						end,
						-- none
						function () return nil end,
						-- none
						function () return nil end,
						-- BLT
						function ()
							local target = get_branch_target()

							if rs1_value < rs2_value then
								reg:set_pc(reg:get_pc() + target)
							else
								reg:update_pc(size)
							end

							if disasm then
								return string.format("%s %s, %s, %d", "BLT", Reg:getname(rs1), Reg:getname(rs2), target)
							end
						end,
						-- BGE
						function ()
							local target = get_branch_target()

							if rs1_value >= rs2_value then
								reg:set_pc(reg:get_pc() + target)
							else
								reg:update_pc(size)
							end

							if disasm then
								return string.format("%s %s, %s, %d", "BGE", Reg:getname(rs1), Reg:getname(rs2), target)
							end
						end,
						-- BLTU
						function ()
							local target = get_branch_target()

							-- If both numbers are positive, just compare them. If not, reverse the comparison condition.
							if Integer:exclusive_or(rs1_value, rs2_value) then
								if rs1_value < rs2_value then
									reg:update_pc(size)
								else
									reg:set_pc(reg:get_pc() + target)
								end
							else
								if rs1_value < rs2_value then
									reg:set_pc(reg:get_pc() + target)
								else
									reg:update_pc(size)
								end
							end

							if disasm then
								return string.format("%s %s, %s, %d", "BLTU", Reg:getname(rs1), Reg:getname(rs2), target)
							end
						end,
						-- BGEU
						function ()
							local target = get_branch_target()

							if Integer:exclusive_or(rs1_value, rs2_value) then
								if rs1_value >= rs2_value then
									reg:update_pc(size)
								else
									reg:set_pc(reg:get_pc() + target)
								end
							else
								if rs1_value >= rs2_value then
									reg:set_pc(reg:get_pc() + target)
								else
									reg:update_pc(size)
								end
							end

							if disasm then
								return string.format("%s %s, %s, %d", "BGEU", Reg:getname(rs1), Reg:getname(rs2), target)
							end
						end,
					}

					return decTabFnt3[decValFnt3()]()
				end,
			}

			return decTab6_5[decVal6_5()]()
		end,
		-- ========== 001
		function ()
			local decTab6_5 = {
				function ()
					cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
				function ()
					cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
				function ()
					cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
				-- JALR
				function ()
					local rd = bit.rshift(bit.band(cmd, 0x00000F80), 7)
					local rs1 = bit.rshift(bit.band(cmd, 0x000F8000), 15)
					local imm = bit.arshift(bit.band(cmd, 0xFFF00000), 20)

					if bit.band(cmd, 0x00007000) ~= 0 then
						return RV.ILLEGAL_INSTRUCTION
					end

					local backup = reg:get_pc()

					reg:set_pc(bit.band(reg:get_gp(rs1) + imm, 0xFFFFFFFE)) -- then setting least-significant bit of the result to zero.
					reg:set_gp(rd, backup)

					if disasm then
						return string.format("%s %s, %d(%s)", "JALR", Reg:getname(rd), imm, Reg:getname(rs1))
					end
				end,
			}

			return decTab6_5[decVal6_5()]()
		end,
		-- ========== 010
		function ()
			cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
			return RV.ILLEGAL_INSTRUCTION
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
					reg:set_gp(rd, reg:get_pc() + 4)
					reg:set_pc(reg:get_pc() + imm20)

					if disasm then
						return string.format("%s %s, %d", "JAL", Reg:getname(rd), imm20)
					end
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
							reg:set_gp(rd, reg:get_gp(rs1) + imm)

							if disasm then
								return string.format("%s %s, %s, %d", "ADDI", Reg:getname(rd), Reg:getname(rs1), imm)
							end
						end,
						-- SLLI
						function ()
							local shamt = bit.band(imm, 0x1F)

							if bit.rshift(bit.band(imm, 0xFE0), 5) == 0 then
								reg:set_gp(rd, bit.lshift(reg:get_gp(rs1), shamt))

								if disasm then
									return string.format("%s %s, %s, %d", "SLLI", Reg:getname(rd), Reg:getname(rs1), shamt)
								end
							else
								cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
								return RV.ILLEGAL_INSTRUCTION
							end
						end,
						-- SLTI
						function ()
							if reg:get_gp(rs1) < imm then
								reg:set_gp(rd, 1)
							else
								reg:set_gp(rd, 0)
							end

							if disasm then
								return string.format("%s %s, %s, %d", "SLTI", Reg:getname(rd), Reg:getname(rs1), imm)
							end
						end,
						-- SLTIU
						function ()
							local rs1_value = reg:get_gp(rs1)

							if Integer:unsigned_comparer(rs1_value, imm) then
								if rs1_value < imm then
									reg:set_gp(rd, 1)
								end
							else
								if not (rs1_value > imm) then
									reg:set_gp(rd, 0)
								end
							end

							if disasm then
								return string.format("%s %s, %s, %d", "SLTIU", Reg:getname(rd), Reg:getname(rs1), imm)
							end
						end,
						-- XORI
						function ()
							reg:set_gp(rd, bit.bxor(reg:get_gp(rs1), imm))

							if disasm then
								return string.format("%s %s, %s, %s", "XORI", Reg:getname(rd), Reg:getname(rs1), imm)
							end
						end,
						-- SRLI/SRAI
						function ()
							local shamt = bit.band(imm, 0x1F)
							local opname

							local imm11_5 = bit.rshift(bit.band(imm, 0xFE0), 5)
							local op
							if imm11_5 == 0 then
								op = bit.rshift
								opname = "SRLI"
							elseif imm11_5 == 0x20 then
								op = bit.arshift
								opname = "SRAI"
							else
								cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
								return RV.ILLEGAL_INSTRUCTION
							end

							reg:set_gp(rd, bit.band(op(reg:get_gp(rs1), shamt), 0xFFFFFFFF))

							if disasm then
								return string.format("%s %s, %s, %d", opname, Reg:getname(rd), Reg:getname(rs1), shamt)
							end
						end,
						-- ORI
						function ()
							reg:set_gp(rd, bit.bor(reg:get_gp(rs1), imm))

							if disasm then
								return string.format("%s %s, %s, %d", "ORI", Reg:getname(rd), Reg:getname(rs1), imm)
							end
						end,
						-- ANDI
						function ()
							reg:set_gp(rd, bit.band(reg:get_gp(rs1), imm))

							if disasm then
								return string.format("%s %s, %s, %d", "ANDI", Reg:getname(rd), Reg:getname(rs1), imm)
							end
						end
					}
					local retval = decTabFnt3[decValFnt3()]()

					reg:update_pc(size)
					return retval
				end,
				-- ========== 01
				function ()
					local rs2 = bit.rshift(bit.band(cmd, 0x01F00000), 20)
					local fnt7 = bit.rshift(bit.band(cmd, 0xFE0000000), 29)

					local decTabFnt3 = {
						-- ADD/SUB
						function ()
							local opname

							if fnt7 == 0 then
								reg:set_gp(rd, reg:get_gp(rs1) + reg:get_gp(rs2))
								opname = "ADD"
							elseif fnt7 ~= 0 then
								reg:set_gp(rd, reg:get_gp(rs1) - reg:get_gp(rs2))
								opname = "SUB"
							end

							if disasm then
								return string.format("%s %s, %s, %s", opname, Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
							end
						end,
						-- SLL
						function ()
							reg:set_gp(rd, bit.lshift(reg:get_gp(rs1), reg:get_gp(rs2)))

							if disasm then
								return string.format("%s %s, %s, %s", "SLL", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
							end
						end,
						-- SLT
						function ()
							if reg:get_gp(rs1) < reg:get_gp(rs2) then
								reg:set_gp(rd, 1)
							else
								reg:set_gp(rd, 0)
							end

							if disasm then
								return string.format("%s %s, %s, %s", "SLT", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
							end
						end,
						-- SLTU
						function ()
							local rs1_value = reg:get_gp(rs1)
							local rs2_value = reg:get_gp(rs2)

							if Integer:unsigned_comparer(rs1_value, rs2_value) then
								if rs1_value < rs2_value then
									reg:set_gp(rd, 1)
								end
							else
								if not (rs1_value > rs2_value) then
									reg:set_gp(rd, 0)
								end
							end

							if disasm then
								return string.format("%s %s, %s, %s", "SLTU", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
							end
						end,
						-- XOR
						function ()
							reg:set_gp(rd, bit.bxor(reg:get_gp(rs1), reg:get_gp(rs2)))

							if disasm then
								return string.format("%s %s, %s, %s", "XOR", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
							end
						end,
						-- SRL/SRA
						function ()
							local op
							local opname

							if fnt7 == 0 then
								op = bit.rshift
								opname = "SRL"
							elseif fnt7 ~= 0 then
								op = bit.arshift
								opname = "SRA"
							end

							reg:set_gp(rd, op(reg:get_gp(rs1), reg:get_gp(rs2)))

							if disasm then
								return string.format("%s %s, %s, %s", opname, Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
							end
						end,
						-- OR
						function ()
							reg:set_gp(rd, bit.bor(reg:get_gp(rs1), reg:get_gp(rs2)))

							if disasm then
								return string.format("%s %s, %s, %s", "OR", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
							end
						end,
						-- AND
						function ()
							reg:set_gp(rd, bit.band(reg:get_gp(rs1), reg:get_gp(rs2)))

							if disasm then
								return string.format("%s %s, %s, %s", "AND", Reg:getname(rd), Reg:getname(rs1), Reg:getname(rs2))
							end
						end
					}
					local retval

					if fnt7 == 1 then
						retval = self:decode_ext_m(disasm)
					else
						retval = decTabFnt3[decValFnt3()]()
					end

					reg:update_pc(size)
					return retval
				end,
				-- ========== 10
				function ()
					cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
				-- ========== 11
				function ()
					cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end
			}
			return decTab6_5[decVal6_5()]()
		end,
		-- ========== 101
		function ()
			local imm20 = bit.band(cmd, 0xFFFFF000)
			local rd = bit.rshift(bit.band(cmd, 0x00000F80), 7)

			local decTab6_5 = {
				-- AUIPC
				function ()
					reg:set_gp(rd, reg:get_pc() + imm20)

					if disasm then
						return string.format("%s %s, %d", "AUIPC", Reg:getname(rd), imm20)
					end
				end,
				-- LUI
				function ()
					reg:set_gp(rd, imm20)

					if disasm then
						return string.format("%s %s, %d", "LUI", Reg:getname(rd), imm20)
					end
				end,
				function ()
					cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
				function ()
					cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
					return RV.ILLEGAL_INSTRUCTION
				end,
			}

			local disassembled = decTab6_5[decVal6_5()]()
			reg:update_pc(size)
			return disassembled
		end,
		-- ========== 110
		function ()
			cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
			return RV.ILLEGAL_INSTRUCTION
		end,
		-- ========== 111 Not Supported other instruction length
		function ()
			cpu:halt("Cpu:decode_rv32i: Illegal instruction, processor is stopped.")
			return RV.ILLEGAL_INSTRUCTION
		end
	}

	local retval = decTab4_2[decVal4_2()]()
	if retval == nil then
		return RV.ILLEGAL_INSTRUCTION
	end

	return retval
end

---
---@param disasm boolean
function Instruction:step (disasm)
	if not self:fetch_instruction() then
		return RV.ILLEGAL_INSTRUCTION
	end

	local optab = {
		-- Compressed Instruction
		function ()
			return self:decode_16bit(disasm)
		end,
		-- Standard Instruction
		function ()
			return self:decode_32bit(disasm)
		end,
		-- Extended 48-bit Instruction (Not Supported)
		function ()
			return RV.ILLEGAL_INSTRUCTION
		end,
		-- Extended 64-bit Instruction (Not Supported)
		function ()
			return RV.ILLEGAL_INSTRUCTION
		end,
	}

	return optab[bit.rshift(self.size, 1)]()
end

return Instruction
