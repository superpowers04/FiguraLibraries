-- Config to table 
--  Returns a table that you can easily load and save config stuff using normal access like conf.key = "meow"
--  Also caches config stuff so you don't have to constantly use config:load
-- Made by superpowers04

local conf = {} -- Empty table
local confLoad = function(this,key) -- The _index function
    local val = rawget(this,key); 
    if(val ~= nil) then -- If the value is set, return it
        return val
    end 
    val = config:load(key) -- Otherwise, try to load it
    if val ~= nil then rawset(this,key,val) end -- Only set table key if something was returned
    return val
end
local confSave = function(this,key,value) 
  rawset(this,key,value) -- Sets the table's value
  config:save(key,value) -- Saves it
end
local confMT = {_index=confLoad,_newindex=confsave} -- The metatable
setmetatable(conf,confMT) -- set conf to use the metatable
return conf
