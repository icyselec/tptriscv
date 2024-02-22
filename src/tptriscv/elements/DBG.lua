local Instance = require("tptriscv.classes.Instance")
local Apis = require("tptriscv.Apis")
local Cpu = require("tptriscv.classes.Cpu")

local RVREGISTER = elements.allocate(RV.MOD_IDENTIFIER, "DBG")
elements.element(RVREGISTER, elements.element(elements.DEFAULT_PT_ARAY))
elements.property(RVREGISTER, "Name", "DBG")
elements.property(RVREGISTER, "Description", "Debugging the mod, You can test the functionality of the mod easily and quickly.")
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
elements.property(RVREGISTER, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT + elem.PROP_HOT_GLOW)

local enabled = false
local self_id = 0
local before_pc = -1
local cpu

elements.property(RVREGISTER, "Create", function (i, x, y, s, n)
	if not enabled then
		enabled = true

		Rv.instance[1] = Instance:new{id = 1}
		Rv.instance[1].cpu[1].conf:set_config("disasm", true)
		cpu = Rv.instance[1].cpu[1]

		cpu.refs.mem:load_memory(0, 255, tpt.input("File Load", "Which file do you want to open?"))
	end
end)

elements.property(RVREGISTER, "Update", function(...)
	if enabled then
		for _ = 1, cpu.conf:get_config("frequency") do
			cpu:run(true)
		end
	else
		return
	end

	if Rv.instance[1].cpu[1].regs:get_pc() == before_pc then
		Rv.instance[1].mem:dump_memory(0, 255, tpt.input("File Dump", "What file do you want to print?"))
		enabled = false
		before_pc = -1
		Rv.instance[1]:del()
	else
		before_pc = Rv.instance[1].cpu[1].regs:get_pc()
	end
end)
