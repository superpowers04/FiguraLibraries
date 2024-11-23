local cmd = require('CommandPalette')

cmd.commands.gamemode = {
	desc = "Change your gamemode",
	suggests = {
		creative=true,
		survival=true,
		spectator=true,
		adventure=true,
	},
	execute=function(self,args)
		local gm = (args[2] or ""):lower()
		if(gm:sub(0,2) == "sp") then
			host:sendChatCommand('/gamemode spectator')
			return
		end
		if(gm:sub(0,1) == "c") then
			host:sendChatCommand('/gamemode creative')
			return
		end
		if(gm:sub(0,1) == "s") then
			host:sendChatCommand('/gamemode survival')
			return
		end
		if(gm:sub(0,1) == "a") then
			host:sendChatCommand('/gamemode adventure')
			return
		end

		return false, "Invalid gamemode!"
	end
}
cmd.commands.tp = {
	desc = "Teleport to a player",
	suggests = {type="player"
	},
	execute=function(self,args)
		host:sendChatCommand('/tp '..args[2])
		return

	end
}
-- avatar:forcePings(table.unpack(config:load('forcePingBackend') or {}))
cmd.commands.forceping = {
	desc = "Force pings",
	suggests = {type="bool",name="backend",
		suggests={type="bool",name="FSB"}
	},
	execute=function(self,args)
		local backend,fsb = args[2] and args[2]:sub(1,1)=="t" or false,args[3] and args[3]:sub(1,1)=="t" or false
		avatar:forcePings(backend,fsb)
		config:save('forcePingBackend',{backend,fsb})

		return ('Force pings set to %s and %s'):format(tostring(backend),tostring(fsb))

	end



cmd.commands.copy = {
	funcs = {
		['held item'] = function() return player:getHeldItem():toStackString() end,
		['targeted block'] = function() return ('%d %d %d'):format(player:getTargetedBlock():getPos():unpack()) end,
	},
	desc = "Copy something",
	suggests = {
		"'targeted block'","'held item'",
	},
	execute=function(self,args)
		local copy = args[2]
		if not copy then return false,"Missing argument 1" end
		if not self.funcs[copy] then return false,("%s is not a valid thing to copy!"):format(copy) end
		local ret = self.funcs[copy]()
		host:setClipboard(ret)
		return ('Copied %q to clipboard'):format(ret)

	end
}
