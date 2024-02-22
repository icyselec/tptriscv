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



function Apis:new_instance (i, x, y, s, n)
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

function Apis:del_instance (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	if Rv.instance[id] == nil then
		print("Apis:del_instance: Delete failed. please restart the game.")
		return set_return(i, 1)
	end

	Instance:del()

	return set_return(i)
end

function Apis:load_memory (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local base = getter(i, 'FIELD_TMP3')
	local size = getter(i, 'FIELD_TMP4')
	local instance = Rv.instance[id]
	local mem = instance.mem

	local filename = tpt.input("File Load", "Which file do you want to open?")

	if not mem:load_memory(base, size, filename) then
		tpt.message_box("Error", "Memory load failed.")
		return set_return(i, 1)
	end

	return set_return(i)
end

function Apis:dump_memory (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local base = getter(i, 'FIELD_TMP3')
	local size = getter(i, 'FIELD_TMP4')
	local instance = Rv.instance[id]
	local mem = instance.mem

	local filename = tpt.input("File Dump", "What file do you want to print?")

	if not mem:dump_memory(base, size, filename) then
		tpt.message_box("Error", "Memory dump failed.")
		return set_return(i, 1)
	end

	return set_return(i)
end

function Apis:get_register_value (i, x, y, s, n)
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

function Apis:set_register_value (i, x, y, s, n)
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

function Apis:print_register_dump (i, x, y, s, n)
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

function Apis:print_memory_dump (i, x, y, s, n)
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

function Apis:get_env_var (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local key = tpt.input("Get Mod Environment Variable", "Input Variable Name:")

	return set_return(i, RV[key])
end

function Apis:set_env_var (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local key = tpt.input("Get Mod Environment Variable", "Input Variable Name:")
	local val = tpt.input("Set Mod Environment Variable", "Input Variable Value:")

	RV[key] = val
	return set_return(i)
end

function Apis:get_config (i, x, y, s, n)
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

function Apis:set_config (i, x, y, s, n)
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

function Apis:get_status (i, x, y, s, n)
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

function Apis:set_status (i, x, y, s, n)
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

return Apis
