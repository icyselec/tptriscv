local Instance = require("tptriscv.classes.Instance")
local Apis = require("tptriscv.Apis")

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
elements.property(RVREGISTER, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT + elem.PROP_HOT_GLOW)

elements.property(RVREGISTER, "Update", function (i, x, y, s, n)
	local current_life = sim.partProperty(i, sim.FIELD_LIFE)

	if current_life <= 0 then -- no operation or error
		return
	end

	local apitab = {
		Apis.new_instance,			 -- 1
		Apis.del_instance,			 -- 2
		Apis.load_memory,			 -- 3
		Apis.dump_memory,			 -- 4
		Apis.get_register_value,	 -- 5
		Apis.set_register_value,	 -- 6
		Apis.print_register_dump,	 -- 7
		Apis.print_memory_dump,		 -- 8
		nil,						 -- 9
		nil,						 -- 10
		Apis.get_env_var,			 -- 11
		Apis.set_env_var,			 -- 12
		Apis.get_config,			 -- 13
		Apis.set_config,			 -- 14
		Apis.get_status,			 -- 15
		Apis.set_status,			 -- 16
	}

	local func = apitab[current_life]
	if func == nil then
		return
	end

	local retval = func{i, x, y, s, n}
end)
