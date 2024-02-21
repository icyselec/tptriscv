--[[
Implement the RISC-V instruction set on TPT.
Copyright (C) 2024  icyselec

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
]]

-- RISC-V 32-Bit Emulator for 'The Powder Toy'


-- created new namespace for code re-factoring
rv = {}
-- created new namespace for constants
RV = {}

-- It prevents access to undeclared or uninitialized variables and print the name of variable.
-- source by LBPHacker
-- License: Do Whatever You Want With It 42.0™
do
	local old_env = getfenv(1)
	local env = setmetatable({}, { __index = function(_, key)
		error("__index on env: " .. tostring(key), 2)
	end, __newindex = function(_, key)
		error("__newindex on env: " .. tostring(key), 2)
	end })
	for key, value in pairs(old_env) do
		rawset(env, key, value)
	end
	setfenv(1, env)
end

rv.decode = {}
rv.permissions = {}

-- definition constants
RV.MAX_MEMORY_WORD = 65536 -- 256 kiB limit
RV.MAX_MEMORY_SIZE = RV.MAX_MEMORY_WORD * 4
RV.MAX_FREQ_MULTIPLIER = 1667
RV.MAX_TEMPERATURE = 120.0
RV.MOD_IDENTIFIER = "FREECOMPUTER"
RV.EXTENSIONS = {"RV32I"}

-- definition of permissions
rv.permissions.clipboard_access = nil

function rv.panic ()

end

function rv.throw (msg)
	print(msg)
end

function rv.get_permission (perm_name)
	if rv.permissions[perm_name] == false then
		return false
	end

	local title = "Grant Permission"
	local failed = ""
	local answer = ""
	local msg = "Approve the following permissions with y (or Y), deny n (or N). (Note: This message will never appear again once you deny it until you restart the game.)"
	msg = msg .. "\n" .. perm_name

	while answer == "y" or answer == "Y" do
		answer = tpt.input(msg .. failed)
		if failed == "" and (answer ~= "n" or answer ~= "N") then
			failed = "\n\nPlease answer correctly."
		elseif answer == "n" or answer == "N" then
			rv.permissions[perm_name] = false
			return false
		end
	end

	return true
end

function rv.try_permission (perm_name)
	if rv.permissions[perm_name] == nil then
		return rv.get_permission(perm_name)
	elseif rv.permissions[perm_name] == false then
		return false
	else return true end
end

function rv.print_debug_info(instance)
	local mem = instance.mem
	if mem == nil then
		return false
	end

	print("segmentation: " .. tostring(mem.debug.segmentation))
	print("segment_size: " .. tostring(mem.debug.segment_size))
	print("panic_when_fault: " .. tostring(mem.debug.panic_when_fault))
	print("segment_map: " .. tostring(mem.debug.segment_map))

	return true
end






-- Also try Legend of Astrum!
