local tpt = require("tpt")
local elements = require("elements")
local RV = require("src/constants/config")
local Instance = require("src/classes/Instance")

local RVREGISTER = elements.allocate(RV.MOD_IDENTIFIER, "CFG")
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

elements.property(RVREGISTER, "Update", function (_, x, y, _, _)
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
--	local function setter (prop_name, val) tpt.set_property(prop_name, val, x, y) end

	-- Caution! : API is unstable
	local id = tpt.get_property('ctype', x, y)

	local cfgOpTab = {
		-- (1) get the register value
		function ()
			local cpu_number = getter('tmp3')
			local reg_number = getter('tmp4')

			local cpu = Rv.instance[id].cpu[cpu_number]
			if cpu == nil then
				setErrorLevel(1)
				return
			end

			local reg = cpu.regs

			local retval

			if reg_number == 0 then
				retval = reg:get_pc()
			else
				retval = reg:get_gp(reg_number - 1)
			end

			setReturn(retval, 0)

			return true
		end,
		-- (2) set the register value
		function ()
			local cpu_number = getter('tmp3')
			local reg_number = getter('tmp4')

			local cpu = Rv.instance[id].cpu[cpu_number]
			if cpu == nil then
				setErrorLevel(1)
				return
			end

			if reg_number == 0 then
				cpu:set_pc(getter('tmp'))
			else
				cpu:set_gp(reg_number, getter('tmp'))
			end

			setReturn(0, 0)

			return true
		end,
		-- (3) get the current frequency
		function ()
			local cpu_number = getter('tmp3') + 1
			local cpu = Rv.instance[id].cpu[cpu_number]
			if cpu == nil then
				setErrorLevel(1)
				return
			end

			setReturn(cpu.conf:get_config("frequency"), 0)

			return true
		end,
		-- (4) set the current frequency
		function ()
			local cpu_number = getter('tmp3')
			local cpu = Rv.instance[id].cpu[cpu_number]
			if cpu == nil then
				setErrorLevel(1)
				return
			end

			local newFreq = tpt.get_property('tmp4', x, y)
			if newFreq > RV.MAX_FREQ_MULTIPLIER then
				setErrorLevel(1)
				return
			end

			cpu.conf:set_config("frequency", newFreq)
			setReturn(0, 0)

			return true
		end,
		-- (5) create instance
		function ()
			if Rv.instance[id] ~= nil then
				Rv.throw("Rv.new_instance: Instance id already in use.")
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

			Rv.instance[id] = instance

			return true
		end,
		-- (6) delete instance
		function ()
			if Rv.instance[id] == nil then
				print("Configuration: API 6, delete failed. please restart the game.")
				return
			end

			Instance:del()

			return true
		end,
		-- (7) read memory
		function ()
--			local cpu_number = getter('tmp3')
			local adr = getter('tmp4')
			local instance = Rv.instance[id]
			local mem = instance.mem
			local val = mem:raw_access(adr, 3)

			if val == nil then
				Rv.throw("Configuration: Rv.access_memory is failed to read.")
				return false
			end

			setReturn(val, 0)
			return true
		end,
		-- (8) write memory
		function ()
--			local cpu_number = getter('tmp3')
			local adr = getter('tmp4')
			local val = getter('tmp')
			local instance = Rv.instance[id]
			local mem = instance.mem

			mem:raw_access(adr, 3, val)

			setReturn(0, 0)
			return true
		end,
		-- (9) load test program
		function ()
			-- deprecated, do not use!
			--[[
			Rv.load_test_code(id)

			setReturn(0, 0)
			return true
			]]
		end,
		-- (10) get debug info
		function ()
			local cpu_number = getter('tmp3')
			local instance = Rv.instance[id]
			local cpu = instance.cpu[cpu_number]
			if not Rv.print_debug_info(cpu) then
				setErrorLevel(1)
			end

			setReturn(0, 0)
		end,
		-- (11) toggle debugging segmentation
		function ()
--			local cpu_number = getter('tmp3')
			Rv.instance[id].mem.debug.segmentation = bit.bxor(Rv.instance[id].mem.debug.segmentation, 1)
			setReturn(0, 0)
			return true
		end,
		-- (12) set or unset write protection on selected segment
		function ()
			local mem = Rv.instance[id].mem
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
			-- deprecated
			--[[
			if not Rv.new_mem(id) then
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
			-- deprecated
			--[[
			if not Rv.del_mem(id) then
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
			local cpu = Rv.instance[id].cpu[cpu_number+1]

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

			local mem = Rv.instance[id].mem

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
			local perm = Rv.try_permission("clipboard_access")
			if perm == false then
				setReturn(-1, -1)
				setErrorLevel(2)
				return false
			end

			local beg = getter('tmp3')

			local str = tpt.get_clipboard()
			Rv.string_to_memory(id, beg, str)

			setReturn(0, 0)
			setErrorLevel(0)
			]]
			return false
		end,
		-- (18) read file and load memory
		function ()
			local base = getter('tmp3')
			local size = getter('tmp4')
			local instance = Rv.instance[id]
			local mem = instance.mem

			local filename = tpt.input("File Load", "Which file do you want to open?")

			mem:load_memory(base, size, filename)
			return true
		end,
		-- (19) write file and dump memory
		function ()
			local base = getter('tmp3')
			local size = getter('tmp4')
			local instance = Rv.instance[id]
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
end)
