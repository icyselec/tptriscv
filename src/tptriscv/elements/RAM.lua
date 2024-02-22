local RV = require("tptriscv.define.Config")

local RVREGISTER = elements.allocate(RV.MOD_IDENTIFIER, "RAM")
elements.element(RVREGISTER, elements.element(elements.DEFAULT_PT_ARAY))
elements.property(RVREGISTER, "Name", "RAM")
elements.property(RVREGISTER, "Description", "Random-Access Memory, can transfer data to the FILT and operate it as a PSCN, NSCN.")
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
elements.property(RVREGISTER, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + PROP_NOAMBHEAT + PROP_HOT_GLOW)

elements.property(RVREGISTER, "Update", function (_, x, y, _, _)
	local function getter (prop_name) return tpt.get_property(prop_name, x, y) end
--	local function setter (prop_name, val) tpt.set_property(prop_name, val, x, y) end

	local instance = Rv.instance[getter('ctype')]
	if instance == nil then return end
	local mem = instance.mem

	local ptr = getter('life')
	local detected_pscn
	local detected_nscn

	for ry = -2, 2 do
		for rx = -2, 2 do
			local el = tpt.get_property('type', x + rx, y + ry)

			if el == elements.DEFAULT_PT_SPRK and tpt.get_property('life', x + rx, y + ry) == 3 then
				if tpt.get_property('ctype', x + rx, y + ry) == elements.DEFAULT_PT_PSCN then
					detected_pscn = true
				elseif tpt.get_property('ctype', x + rx, y + ry) then
					detected_nscn = true
				end
			end
		end
	end

	if detected_pscn then
		for ry = -2, 2 do
			for rx = -2, 2 do
				local found = tpt.get_property('type', x + rx, y + ry)

				if found == elements.DEFAULT_PT_FILT then
					local value = mem:read_u32(ptr)
					value = value + 0x10000000 -- serialization
					tpt.set_property('ctype', value, x + rx, y + ry)
				end
			end
		end
	elseif detected_nscn then
		for ry = -2, 2 do
			for rx = -2, 2 do
				local found = tpt.get_property('type', x + rx, y + ry)

				if found == elements.DEFAULT_PT_FILT then
					local value = tpt.get_property('ctype', x + rx, y + ry)
					value = value - 0x10000000 -- deserialization
					mem:write_u32(ptr, value)
				end
			end
		end
	end

	return
end)
