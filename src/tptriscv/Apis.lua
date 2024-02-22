local Instance = require("tptriscv.classes.Instance")
local Reg = require("tptriscv.classes.Reg")
local Apis = {}

local function getter (i, field)
	return sim.partProperty(i, sim[field])
end

local function setter (i, field, val)
	sim.partProperty(i, sim[field], val)
end

local function set_tmparg (i, tmp, tmp2, tmp3, tmp4)
	tmp  = tmp  or 0
	tmp2 = tmp2 or 0
	tmp3 = tmp3 or 0
	tmp4 = tmp4 or 0

	sim.partProperty(i, sim.FIELD_TMP,  tmp)
	sim.partProperty(i, sim.FIELD_TMP2, tmp2)
	sim.partProperty(i, sim.FIELD_TMP3, tmp3)
	sim.partProperty(i, sim.FIELD_TMP4, tmp4)
end

local function set_return (i, err_number)
	err_number = err_number or 0
	if err_number < 0 then err_number = -err_number end
	setter(i, 'FIELD_LIFE', -err_number)

	return err_number == 0
end



function Apis:new_instance (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	if Rv.instance[id] ~= nil then
		Rv.UI.print_error("Apis:new_instance: Instance id already in use.")
		return false
	end

	local instance = Instance:new{id = id}

	if instance == nil then
		set_tmparg(i)
		return set_return(i, 1)
	end

	Rv.instance[id] = instance
	return set_return(i)
end

function Apis:del_instance (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	if Rv.instance[id] == nil then
		print("Apis:del_instance: Delete failed. please restart the game.")
		return set_return(i, 1)
	end

	Instance:del()

	return set_return(i)
end

function Apis:load_memory (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local base = getter(i, 'FIELD_TMP3')
	local size = getter(i, 'FIELD_TMP4')
	local instance = Rv.instance[id]
	local mem = instance.mem

	local filename = tpt.input("File Load", "Which file do you want to open?")

	mem:load_memory(base, size, filename)
	return set_return(i)
end

function Apis:dump_memory (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local base = getter(i, 'FIELD_TMP3')
	local size = getter(i, 'FIELD_TMP4')
	local instance = Rv.instance[id]
	local mem = instance.mem

	local filename = tpt.input("File Dump", "What file do you want to print?")

	mem:dump_memory(base, size, filename)
	return true
end

function Apis:get_register_value (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local cpu_number = getter(args.i, 'FIELD_TMP3')
	local reg_number = getter(args.i, 'FIELD_TMP4')

	local cpu = Rv.instance[id].cpu[cpu_number]
	if cpu == nil then
		return set_return(i, 1)
	end

	local reg = cpu.regs

	local retval

	if reg_number == 0 then
		retval = reg:get_pc()
	else
		retval = reg:get_gp(reg_number - 1)
	end


	set_tmparg(i, retval)
	return 	set_return(i)
end

function Apis:set_register_value (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local cpu_number = getter('FIELD_TMP3')
	local reg_number = getter('FIELD_TMP4')

	local cpu = Rv.instance[id].cpu[cpu_number]
	if cpu == nil then
		return set_return(i, 1)
	end

	if reg_number == 0 then
		cpu:set_pc(getter(i, 'FIELD_TMP'))
	else
		cpu:set_gp(reg_number, getter(i, 'FIELD_TMP'))
	end

	return set_return(i)
end

function Apis:print_register_dump (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local cpu_number = getter(i, 'FIELD_TMP3')
	local reg_format = getter(i, 'FIELD_TMP4')

	local cpu = Rv.instance[id].cpu[cpu_number+1]
	local reg = cpu.regs

	if cpu == nil then
		tpt.message_box("Error", "Invalid instance ID.")
		set_tmparg(i)
		return set_return(i, 1)
	end

	local msg = ""

	for i = 0, 31 do
		local value = reg:get_gp(i)
		if value == nil then value = "nil" end

		if reg_format == 0 then
			msg = string.format("%sR%d:\t0x%X\n", msg, i, value)
		else
			msg = string.format("%s%s:\t0x%X\n", msg, Reg:getname(i), value)
		end
	end
	msg = string.format("%sPC:\t0x%X", msg, reg:get_pc())

	tpt.message_box("RISC-V Register Dump", msg)

	return true
end

function Apis:print_memory_dump (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local beg = getter(i, 'FIELD_TMP3')
	local max = getter(i, 'FIELD_TMP4')
	local msg = ""

	local mem = Rv.instance[id].mem

	if beg > max then
		tpt.message_box("Error", "Invalid range.")
		set_tmparg(i)
		return set_return(i, 1)
	end

	if max - beg > 16 then
		tpt.message_box("Error", "Range too big.")
		set_tmparg(i)
		return set_return(i, 2)
	end

	for j = beg, max, 16 do
		local data

		for k = 0, 12, 4 do
			data = mem:raw_access(j + k, 3)
			msg = msg .. string.format("0x%X ", data)
		end

		msg = msg .. "\n"
	end

	tpt.message_box("RISC-V Memory Dump", "beg: " .. tostring(beg) .. ", max: " .. tostring(max) .. "\n" .. msg)
	return true
end

function Apis:get_env_var (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local key = tpt.input("Get Mod Environment Variable", "Input Variable Name:")

	return set_return(i, RV[key])
end

function Apis:set_env_var (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local key = tpt.input("Get Mod Environment Variable", "Input Variable Name:")
	local val = tpt.input("Set Mod Environment Variable", "Input Variable Value:")

	RV[key] = val
	return set_return(i)
end

function Apis:get_config (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local cpu_number = getter(i, 'FIELD_TMP3') + 1
	local cpu = Rv.instance[id].cpu[cpu_number]
	if cpu == nil then
		set_tmparg(i)
		return set_return(i, 1)
	end

	local key = tpt.input("Get CPU Configuration", "Input Configuration Name:")

	return set_return(i, cpu.conf:get_config(key))
end

function Apis:set_config (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local cpu_number = getter(i, 'FIELD_TMP3') + 1
	local cpu = Rv.instance[id].cpu[cpu_number]
	if cpu == nil then
		set_tmparg(i)
		return set_return(i, 1)
	end

	local key = tpt.input("Set CPU Configuration", "Input Configuration Name:")
	local val = tpt.input("Set CPU Configuration", "Input Configuration Value:")

	return set_return(i, cpu.conf:set_config(key, val))
end

function Apis:get_status (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local cpu_number = getter(i, 'FIELD_TMP3') + 1
	local cpu = Rv.instance[id].cpu[cpu_number]
	if cpu == nil then
		set_tmparg(i)
		return set_return(i, 1)
	end

	local key = tpt.input("Get CPU Status", "Input Status Name:")

	return set_return(i, cpu.stat:get_status(key))
end

function Apis:set_status (args)
	local i = args.i
	local id = getter(i, 'FIELD_CTYPE')

	local cpu_number = getter(i, 'FIELD_TMP3') + 1
	local cpu = Rv.instance[id].cpu[cpu_number]
	if cpu == nil then
		set_tmparg(i)
		return set_return(i, 1)
	end

	local key = tpt.input("Set Status", "Input Status Name:")
	local val = tpt.input("Set CPU Status", "Input Status Value:")

	return set_return(i, cpu.conf:set_status(key, val))
end

	local cfgOpTab = {
		-- (1) get the register value
		function ()

		end,
		-- (2) set the register value
		function ()

		end,
		-- (3) get the current frequency
		function ()

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

		end,
		-- (6) delete instance
		function ()

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
		-- (15) register dump
		function ()

		end,
		-- (16) memory dump
		-- tmp3: start of memory
		-- tmp4: end of memory
		function ()

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

		end,
		-- (19) write file and dump memory
		function ()

		end,
	}

return Apis
