local RVREGISTER = elements.allocate(RV.MOD_IDENTIFIER, "CPU")
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
elements.property(RVREGISTER, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT + elem.PROP_HOT_GLOW)

elements.property(RVREGISTER, "Create", function (_, x, y, _, _)
	tpt.set_property('ctype', 0, x, y)
end)

-- temp  : not allocated
-- ctype : instance id, if any negative value, cpu is halted.
-- life  : not allocated
-- tmp   : not allocated
-- tmp2  : not allocated
-- tmp3  : not allocated
-- tmp4  : not allocated

elements.property(RVREGISTER, "Update", function (_, x, y, _, _)
	local instanceId = tpt.get_property('ctype', x, y)

	if instanceId <= 0 then -- When processor is not active
		return
	elseif Rv.instance[instanceId].cpu[1] == nil then
		tpt.set_property('ctype', -1, x, y) -- this instance id is not initialized or invalid.
		return
	end

	local instance = Rv.instance[instanceId]
	local cpu = instance.cpu[1]
	local frequency = cpu.conf:getConfig("frequency") -- multiprocessing not yet

	if cpu.stat:getStatus("online") then
		for _ = 1, frequency do
			cpu:run(nil) -- dbgarg is nil
			if not cpu.stat:getStatus("online") then break end
		end
	end

	--[[ What the fscking that?
	local temp = tpt.get_property('temp', x, y)
	tpt.set_property('temp', temp + ctx.conf.freq * 1.41, x, y)
	]]
end)
