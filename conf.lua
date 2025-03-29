local SIMPSKIP
-- Config to table 
--  Returns a table that you can easily load and save config stuff using normal access like conf.key = "meow"
--  Also caches config stuff so you don't have to constantly load config stuff. Also also allows config to be used as a normal table on other clients
-- Made by superpowers04


local config = config -- Import main config api to prevent overwriting it from breaking and to speed up access time


local configCache = {} -- The actual table holding all of the stuff
local confLoad, confSave, setName, getName
if(host:isHost()) then -- Only use actual config library on host, otherwise reference the cache
	confLoad = function(_,key,...) -- The __index function
		local val = configCache[key]; 
		if(val ~= nil) then -- If the value is set, return it
			-- print('CACHE',key,val) -- Debug prints
			return val
		end
		val = config:load(key) -- Otherwise, try to load it
		configCache[key] = val -- Set table key
		-- print('LOAD',key,val) -- Debug prints
		return val
	end
	confSave = function(_,key,value,...)
		configCache[key] = value -- Sets the table's value
		config:save(key,value) -- Saves it
		-- print('SAVE',key,value) -- Debug prints
	end
	setName = function(_,...)
		config:setName(...)
	end
	getName = function(_,...)
		return config:getName(...)
	end
else
	confLoad = function(_,key,...) -- The __index function
		return rawget(configCache,key); -- Grab from cache
	end
	confSave = function(_,key,value,...)
		rawset(configCache,key,value) -- Set on cache
	end
	setName = function() end
	getName = function() end
end

local conf = {__cache=configCache,load=confLoad,save=confSave,setName=setName,getName=getName,explode=function(self) _G.config = self end,__FIGURA_CONFIG=config} -- Table with base functions for compatibility
local confMT = {__index=confLoad,__newindex=confSave} -- The metatable
setmetatable(conf,confMT) -- set conf to use the metatable
return conf
