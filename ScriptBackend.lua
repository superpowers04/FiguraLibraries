--[[ Script Backend, a script by Superpowers04 that handles scripts as modules.
Expects the script to return a table like
{
	init=function() print("SCRIPT ENABLED!") end,
	deinit=function() print("SCRIPT DISABLED!") end,
	events = {
		tick=function()
			print("TICK")
		end
	}
}
Any scripts under a folder named exactly "ToggleScripts" will automatically load and be toggled from a config 

]]
-- CONFIG

-- This disables pinging toggles of any scripts. PINGING REQUIRES PacketHandler
local no_networking = false 
-- This disables scripts under the ToggleScripts directory from being auto registered
local ignore_toggle_scripts = false 

-- Libraries
local PacketHandler,CommandPalette
-- if PacketHandler and CommandPalette aren't under libs, edit their paths here
if(not no_networking) then
	pcall(function()
		PacketHandler = require('libs.PacketHandler')
	end)
end
pcall(function()
	CommandPalette = require('libs.CommandPalette')
end)
if not PacketHandler and not no_networking then
	error("PacketHandler is required for ScriptBackend! By default, this should be under a folder named 'libs', named 'PacketHandler.lua'.\nCHECK ScriptBackend.lua FOR MORE INFO!")
end
local isHost = host:isHost()

local ScriptBackend = {}
ScriptBackend.scripts = {}
local scripts = ScriptBackend.scripts
ScriptBackend.requiredScripts = {}
function ScriptBackend.init()
	ScriptBackend.init = function() end
	local scripts = ScriptBackend.scripts
	for i in pairs(avatar:getNBT().scripts) do
		if(i:sub(0,14) == 'ToggleScripts.') then
			ScriptBackend.registerTogglableScript(i)
		end
	end
	table.sort(ScriptBackend.scripts,function(a,b) return a.name < b.name end)
	ScriptBackend.loadConfig()
	-- print(('Inited ScriptBackend with %i scripts'):format(#ScriptBackend.scripts))
end
function ScriptBackend.registerTogglableScript(i)
	local scr = {
		name=i:gsub('^ToggleScripts%.',''),
		script=require(i) or {},
	}
	if(scr.script.keybinds and isHost) then
		for _,v in pairs(scr.script.keybinds) do v:setEnabled(false) end
	end
	scripts[#scripts+1] = scr
	ScriptBackend.requiredScripts[i] = scr
end
function ScriptBackend.loadScripts(bools)
	for i,v in ipairs(ScriptBackend.scripts) do
		ScriptBackend.toggleScript(v,bools[i])
	end
end
function ScriptBackend.toggleScriptsFromBools(a,...)
	local bools = type(a) == "table" and a or {a,...}
	for i,v in ipairs(ScriptBackend.scripts) do
		ScriptBackend.toggleScript(v,bools[i])
	end
end
function ScriptBackend.updateScripts()
	for i,v in ipairs(ScriptBackend.scripts) do
		local en = v.enabled
		if(v.queuedEnable ~= nil) then
			en = v.queuedEnable
			v.queuedEnable = nil
		end
		ScriptBackend.toggleScript(v,en)
	end
end
function ScriptBackend.toggleScriptFromID(id,value)
	local scr= ScriptBackend.requiredScripts[id]
	if(scr) then
		ScriptBackend.toggleScript(scr,value)
		return
	end
	for i,v in ipairs(ScriptBackend.scripts) do
		if(v.name == id) then
			ScriptBackend.toggleScript(v,value)
			return
		end
	end
	print(('%s is NOT a valid script!'):format(tostring(id)))
end
function ScriptBackend.toggleScript(scr,value)
	if not scr or not scr.script  then 
		print(('%s is NOT a valid script!'):format(tostring(scr)))
		return
	end
	if(scr.enabled == value) then return end
	local script = scr.script
	scr.queuedEnable = nil

	if(value) then
		scr.enabled = true
		script.toggled = true
		if(script.init) then script:init() end
		if(script.toggle) then script:toggle(value) end
		if(script.keybinds and isHost) then
			for _,bind in pairs(script.keybinds) do bind:setEnabled(true) end
		end
		if(script.events) then 
			for i,v in pairs(script.events) do
				if events[i] then
					if(type(v) == 'table') then
						for id,func in pairs(v) do
							events[i]:register(func,scr.name..'.'..i..'.'..id)
						end
					else
						events[i]:register(v,scr.name..'.'..i)
					end
				elseif(host:isHost()) then
					print(('[SCRIPT WARNING] %s:Event with id %q does not exist!'):format(tostring(script.name or scr.name),tostring(i)))
				end
			end
		end
		return
	elseif(scr.enabled == nil) then 
		return
	end
	scr.enabled = false
	script.toggled = false
	if(script.deinit) then script:deinit() end
	if(script.toggle) then script:toggle(value) end
	if(script.events) then 
		for i,v in pairs(script.events) do
			if events[i] then
				if(type(v) == 'table') then
					for id,func in pairs(v) do
						events[i]:remove(scr.name..'.'..i..'.'..id)
					end
				else
					events[i]:remove(scr.name..'.'..i)
				end
			elseif(host:isHost()) then
				print(('[SCRIPT WARNING] %s:Event with id %q does not exist!'):format(tostring(script.name or scr.name),tostring(i)))
				-- error(('SCRIPT %s:Event with id %q does not exist!'):format(tostring(script.name),tostring(i)))
			end
		end
	end
	-- print(script.name,value)
end
function ScriptBackend.requireScript(id,index)
	if(ScriptBackend.requiredScripts[id]) then return ScriptBackend.requiredScripts[id] end
	local scr = {
		name=id,
		script=require(id)
	}
	ScriptBackend.toggleScript(scr,true)
	ScriptBackend.requiredScripts[id] = scr;
end
function ScriptBackend.saveConfig()
	local enabled = config.enabledScripts or require('config.enabledScripts')
	local n = {}
	for i,v in ipairs(ScriptBackend.scripts) do
		enabled[v.name:lower()] = v.enabled and 1 or nil
		if(v.enabled) then
			n[#n+1]=('[%q]=1'):format(v.name:lower())
		end
	end
	config.enabledScripts = enabled
	if(host:isHost() and add_script) then
		add_script('config.enabledScripts',('return {%s}'):format(table.concat(n,',')))
	end
end
function ScriptBackend.loadConfig()
	local c = config.enabledScripts or require('config.enabledScripts')
	local n = {}
	for i,v in ipairs(ScriptBackend.scripts) do
		local toggle = c[v.name:lower()]
		ScriptBackend.toggleScript(v,toggle)
		if(toggle) then
			n[#n+1]=('[%q]=1'):format(v.name:lower())
		end
	end
	if(host:isHost() and add_script) then
		add_script('config.enabledScripts',('return {%s}'):format(table.concat(n,',')))
	end
end
function pings.toggleScriptArray(...)
	ScriptBackend.toggleScriptsFromBools(table.unpack(PacketHandler.intToBools(...)))
end
function ScriptBackend.pingScripts()
	if not PacketHandler then print('Unable to ping state of scripts, PacketHandler is required for this!') return end
	local bools = {}
	for i,v in pairs(ScriptBackend.scripts) do
		if(v.queuedEnable ~= nil) then 
			bools[i]=v.queuedEnable
		else
			bools[i]=v.enabled or false
		end
	end
	pings.toggleScriptArray(table.unpack(PacketHandler.boolsToInt(table.unpack(bools))))
end
if(packetHandler) then
	packetHandler.callbacks.onSync.ToggleScripts = ScriptBackend.pingScripts
end
pcall(function()
	if not CommandPalette then error() end
	local script_sugg = {}
	local name_to_id = {}
	-- local sugClothing = {toggle=true,['true']=true,['false']=true}

	CommandPalette.commands.script = {
		desc="Manage scripts",
		populateSuggests = function(self,cmd)
			script_sugg = {}
			name_to_id = {}
			for i,v in pairs(ScriptBackend.scripts) do
				script_sugg[v.name] = true
				name_to_id[v.name:lower()]=i
			end
			self.suggests = {
				toggle=script_sugg,
				enable=script_sugg,
				disable=script_sugg,
				ping=true,
				save=true
			}
		end,
		suggests={},
		execute = function(self,sep,all)
			table.remove(sep,1)
			local cmd = (sep[1] or ""):lower()
			if(cmd == 'sync' or cmd == "ping") then
				ScriptBackend.pingScripts()
				return
			elseif (cmd == 'save') then
				ScriptBackend.saveConfig()
				return
			end
			if (cmd ~= "disable" and cmd ~="enable" and cmd~="toggle") then
				return false,('{"text":"%s is not a valid command!","color":"light_red"}'):format(cmd)
			end
			local script = ScriptBackend.scripts[name_to_id[(sep[2] or ""):lower()]]
			if(not script) then return false,('{"text":"Script with ID %s does not exist!","color":"light_red"}'):format(sep[2] or "NONE") end
			if(cmd == 'toggle') then
				script.queuedEnable = not script.enabled
			else
				script.queuedEnable = cmd == "enable"
			end
			-- ScriptBackend.toggleScript(scr,script.queuedEnable)
			ScriptBackend.pingScripts()
			return ('{"text":"Set state of %s to %s!","color":"green"}'):format(script.name,script.enabled and "enabled" or "disabled")
		end

	}
end)

return ScriptBackend