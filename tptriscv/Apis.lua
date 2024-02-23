local Instance = require("tptriscv.classes.Instance")
local Reg = require("tptriscv.classes.Reg")
local Apis = {}

local function getter (i, field)
	return sim.partProperty(i, sim[field])
end

local function setter (i, field, val)
	sim.partProperty(i, sim[field], val)
end

local function setTmpArg (i, tmp, tmp2, tmp3, tmp4)
	tmp  = tmp  or 0
	tmp2 = tmp2 or 0
	tmp3 = tmp3 or 0
	tmp4 = tmp4 or 0

	sim.partProperty(i, sim.FIELD_TMP,  tmp)
	sim.partProperty(i, sim.FIELD_TMP2, tmp2)
	sim.partProperty(i, sim.FIELD_TMP3, tmp3)
	sim.partProperty(i, sim.FIELD_TMP4, tmp4)
end

local function setReturn (i, err_number)
	err_number = err_number or 0
	if err_number < 0 then err_number = -err_number end
	setter(i, 'FIELD_LIFE', -err_number)

	return err_number == 0
end



function Apis:newInstance (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	if Rv.instance[id] ~= nil then
		Rv.UI.print_error("Apis:newInstance: Instance id already in use.")
		return false
	end

	local instance = Instance:new{id = id}

	if instance == nil then
		setTmpArg(i)
		return setReturn(i, 1)
	end

	Rv.instance[id] = instance
	return setReturn(i)
end

function Apis:delInstance (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	if Rv.instance[id] == nil then
		print("Apis:delInstance: Delete failed. please restart the game.")
		return setReturn(i, 1)
	end

	Instance:del()

	return setReturn(i)
end

function Apis:loadMemory (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local base = getter(i, 'FIELD_TMP3')
	local size = getter(i, 'FIELD_TMP4')
	local instance = Rv.instance[id]
	local mem = instance.mem

	local filename = tpt.input("File Load", "Which file do you want to open?")

	if not mem:loadMemory(base, size, filename) then
		tpt.message_box("Error", "Memory load failed.")
		return setReturn(i, 1)
	end

	return setReturn(i)
end

function Apis:dumpMemory (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local base = getter(i, 'FIELD_TMP3')
	local size = getter(i, 'FIELD_TMP4')
	local instance = Rv.instance[id]
	local mem = instance.mem

	local filename = tpt.input("File Dump", "What file do you want to print?")

	if not mem:dumpMemory(base, size, filename) then
		tpt.message_box("Error", "Memory dump failed.")
		return setReturn(i, 1)
	end

	return setReturn(i)
end

function Apis:getRegisterValue (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local cpuNumber = getter(args.i, 'FIELD_TMP3')
	local regNumber = getter(args.i, 'FIELD_TMP4')

	local cpu = Rv.instance[id].cpu[cpuNumber]
	if cpu == nil then
		return setReturn(i, 1)
	end

	local reg = cpu.regs

	local retVal

	if regNumber == 0 then
		retVal = reg:getPc()
	else
		retVal = reg:getGp(regNumber - 1)
	end


	setTmpArg(i, retVal)
	return 	setReturn(i)
end

function Apis:setRegisterValue (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local cpu_number = getter('FIELD_TMP3')
	local reg_number = getter('FIELD_TMP4')

	local cpu = Rv.instance[id].cpu[cpu_number]
	if cpu == nil then
		return setReturn(i, 1)
	end

	if reg_number == 0 then
		cpu:setPc(getter(i, 'FIELD_TMP'))
	else
		cpu:setGp(reg_number, getter(i, 'FIELD_TMP'))
	end

	return setReturn(i)
end

function Apis:printRegisterDump (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local cpu_number = getter(i, 'FIELD_TMP3')
	local reg_format = getter(i, 'FIELD_TMP4')

	local cpu = Rv.instance[id].cpu[cpu_number+1]
	local reg = cpu.regs

	if cpu == nil then
		tpt.message_box("Error", "Invalid instance ID.")
		setTmpArg(i)
		return setReturn(i, 1)
	end

	local msg = ""

	for i = 0, 31 do
		local value = reg:getGp(i)
		if value == nil then value = "nil" end

		if reg_format == 0 then
			msg = string.format("%sR%d:\t0x%X\n", msg, i, value)
		else
			msg = string.format("%s%s:\t0x%X\n", msg, Reg:getAbiName(i), value)
		end
	end
	msg = string.format("%sPC:\t0x%X", msg, reg:getPc())

	tpt.message_box("RISC-V Register Dump", msg)

	return true
end

function Apis:printMemoryDump (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local beg = getter(i, 'FIELD_TMP3')
	local max = getter(i, 'FIELD_TMP4')
	local msg = ""

	local mem = Rv.instance[id].mem

	if beg > max then
		tpt.message_box("Error", "Invalid range.")
		setTmpArg(i)
		return setReturn(i, 1)
	end

	if max - beg > 16 then
		tpt.message_box("Error", "Range too big.")
		setTmpArg(i)
		return setReturn(i, 2)
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

function Apis:getModEnvironmentVar (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local key = tpt.input("Get Mod Environment Variable", "Input Variable Name:")

	return setReturn(i, RV[key])
end

function Apis:setModEnvironmentVar (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local key = tpt.input("Get Mod Environment Variable", "Input Variable Name:")
	local val = tpt.input("Set Mod Environment Variable", "Input Variable Value:")

	RV[key] = val
	return setReturn(i)
end

function Apis:getConfig (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local cpu = Rv.instance[id].cpu[getter(i, 'FIELD_TMP3') + 1]
	if cpu == nil then
		setTmpArg(i)
		return setReturn(i, 1)
	end

	local key = tpt.input("Get CPU Configuration", "Input Configuration Name:")

	return setReturn(i, cpu.conf:get_config(key))
end

function Apis:setConfig (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local cpu = Rv.instance[id].cpu[getter(i, 'FIELD_TMP3') + 1]
	if cpu == nil then
		setTmpArg(i)
		return setReturn(i, 1)
	end

	local key = tpt.input("Set CPU Configuration", "Input Configuration Name:")
	local val = tpt.input("Set CPU Configuration", "Input Configuration Value:")

	return setReturn(i, cpu.conf:set_config(key, val))
end

function Apis:getStatus (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local cpu = Rv.instance[id].cpu[getter(i, 'FIELD_TMP3') + 1]
	if cpu == nil then
		setTmpArg(i)
		return setReturn(i, 1)
	end

	local key = tpt.input("Get CPU Status", "Input Status Name:")

	return setReturn(i, cpu.stat:get_status(key))
end

function Apis:setStatus (i, x, y, s, n)
	local id = getter(i, 'FIELD_CTYPE')

	local cpu = Rv.instance[id].cpu[getter(i, 'FIELD_TMP3') + 1]
	if cpu == nil then
		setTmpArg(i)
		return setReturn(i, 1)
	end

	local key = tpt.input("Set Status", "Input Status Name:")
	local val = tpt.input("Set CPU Status", "Input Status Value:")

	return setReturn(i, cpu.conf:set_status(key, val))
end

local ApiTab = {
		Apis.newInstance,			-- 1
		Apis.delInstance,			-- 2
		Apis.loadMemory,			-- 3
		Apis.dumpMemory,			-- 4
		Apis.getRegisterValue,		-- 5
		Apis.setRegisterValue,		-- 6
		Apis.printRegisterDump,		-- 7
		Apis.printMemoryDump,		-- 8
		nil,						-- 9
		nil,						-- 10
		Apis.getModEnvironmentVar,	-- 11
		Apis.setModEnvironmentVar,	-- 12
		Apis.getConfig,				-- 13
		Apis.setConfig,				-- 14
		Apis.getStatus,				-- 15
		Apis.setStatus,				-- 16
}

function Apis:getApiTab ()
	return ApiTab
end

return Apis
