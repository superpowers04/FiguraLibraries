-- Ping/packet handler
--  Handles some utilities like automatically syncing things spread across multiple ticks and such
-- Made by Superpowers04
-- NOTE: CALLBACKS DO NOT PING ANYTHING, THEY CALL FUNCTIONS FOR YOU TO PING STUFF IN
-- Example:
-- local PacketHandler = require('PacketHandler')
-- PacketHandler.callbacks.onSync = function() pings.clothing(Clothing) end


local packetHandler = {
	callbacks = {
		-- onNewPlayer={ },  -- NOT IMPLEMENTED YET, onSync DOES THE SAME THING
		onSync={ } 
	},
	syncWaitTicks = 60, -- The amount of ticks to wait to allow players to load avatar before syncing
	triggerSync = function() end, -- This is the client side variant. This will do nothing on the client
	indexToValues = function(tbl)
		local ret = {}
		for i in pairs(tbl) do ret[#ret+1]=i end
		table.sort(ret,function(a,b) return a > b end)
		return ret
	end
}

if not host:isHost() then return packetHandler end 
-- Everything else is host-side

packetHandler.triggerSync = function()
	local syncedPackets = 0
	events.TICK:remove('packetHandler.syncPings')
	local callbackToID = {}
	-- Convert indexes of all callbacks to numbers
	--  This is to allow for things like packetHandler.callbacks.onSync.clothingSync without breaking
	for i,v in pairs(packetHandler.callbacks.onSync) do 
		callbackToID[#callbackToID + 1] = v
	end
	if(#callbackToID < 1) then return end
	events.TICK:register(function()
		syncedPackets = syncedPackets + 1
		callbackToID[syncedPackets]()
		if(syncedPackets < #callbackToID ) then return end

		events.TICK:remove('packetHandler.syncPings')
	end,'packetHandler.syncPings')
end
local registeredPlayers = {}
local sync = 0
local wait = 40
events.TICK:register(function()
	if(not host:isAvatarUploaded()) then return end
	if(wait > packetHandler.syncWaitTicks ) then
		wait = wait-1
		return
	end
	events.TICK:register(function()
		local newPlayers = world:getPlayers()
		for i,v in pairs(newPlayers) do
			if not registeredPlayers[i] then
				registeredPlayers = newPlayers
				packetHandler.triggerSync()
				events.TICK:remove('packetHandler.awaitSync')
				events.TICK:remove('packetHandler.syncPings')
				sync = 0
				looped = false

				events.TICK:register(function()
					sync = sync + 1
					-- Wait a few ticks before syncing to allow other player to load avatar
					if(sync < packetHandler.syncWaitTicks) then return end 
					packetHandler.triggerSync()
					if(looped) then
						looped = false
						sync = 0
						return
					end

					events.TICK:remove('packetHandler.awaitSync')
				end,'packetHandler.awaitSync')
				break;
			end
		end
	end,'packetHandler.awaitNewPlayers')
	events.TICK:remove('packetHandler.awaitUpload')
end,'packetHandler.awaitUpload')


return packetHandler
