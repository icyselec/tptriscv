--[[
Implement the RISC-V processor on TPT.
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

---@version LuaJIT

-- Global namespace for shared functions
local Rv = require("tptriscv.define.Shared")
local RV = require("tptriscv.define.Config")
-- Global namespace for configuration

local _ = require("tptriscv.elements.CFG")
local _ = require("tptriscv.elements.CPU")
local _ = require("tptriscv.elements.RAM")

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



--[[
-- definition of permissions
rv.permissions = {}
rv.permissions.clipboard_access = nil

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
		answer = tpt.input(title, msg .. failed)
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
]]






-- Also try Legend of Astrum!

