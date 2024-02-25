local RVREGISTER = elements.allocate(RV.MOD_IDENTIFIER, "DMA")
elements.element(RVREGISTER, elements.element(elements.DEFAULT_PT_ARAY))
elements.property(RVREGISTER, "Name", "DMA")
elements.property(RVREGISTER, "Description", "Direct Memory Access, can transfer data to the FILT and operate it as a PSCN, NSCN.")
elements.property(RVREGISTER, "Colour", 0xDF3FBF)
elements.property(RVREGISTER, "MenuSection", elem.SC_ELEC)
elements.property(RVREGISTER, "Gravity", 0)
elements.property(RVREGISTER, "Flammable", 1)
elements.property(RVREGISTER, "Explosive", 0)
elements.property(RVREGISTER, "Loss", 0)
elements.property(RVREGISTER, "AirLoss", 1)
elements.property(RVREGISTER, "AirDrag", 0)
elements.property(RVREGISTER, "Advection", 1)
elements.property(RVREGISTER, "Weight", 0)
elements.property(RVREGISTER, "Diffusion", 0)
elements.property(RVREGISTER, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT + elem.PROP_HOT_GLOW)

elements.property(RVREGISTER, "Update", function (_, x, y, _, _)
	local function getter (propertyName) return tpt.get_property(propertyName, x, y) end
--	local function setter (propertyName, val) tpt.set_property(propertyName, val, x, y) end

	local instance = Rv.instance[getter('ctype')]
	if instance == nil then return end
	local mem = instance.mem

	local ptr = getter('life')
	local detectedPscn
	local detectedNscn

	for ry = -2, 2 do
		for rx = -2, 2 do
			local el = tpt.get_property('type', x + rx, y + ry)

			if el == elements.DEFAULT_PT_SPRK and tpt.get_property('life', x + rx, y + ry) == 3 then
				if tpt.get_property('ctype', x + rx, y + ry) == elements.DEFAULT_PT_PSCN then
					detectedPscn = true
				elseif tpt.get_property('ctype', x + rx, y + ry) then
					detectedNscn = true
				end
			end
		end
	end

	if detectedPscn then
		for ry = -2, 2 do
			for rx = -2, 2 do
				local found = tpt.get_property('type', x + rx, y + ry)

				if found == elements.DEFAULT_PT_FILT then
					local serialized = mem:readU32(ptr) + 0x10000000 -- serialization
					tpt.set_property('ctype', serialized, x + rx, y + ry)
				end
			end
		end
	elseif detectedNscn then
		for ry = -2, 2 do
			for rx = -2, 2 do
				local found = tpt.get_property('type', x + rx, y + ry)

				if found == elements.DEFAULT_PT_FILT then
					local deserialized = tpt.get_property('ctype', x + rx, y + ry) - 0x10000000 -- deserialization
					mem:writeU32(ptr, deserialized)
				end
			end
		end
	end

	return
end)
