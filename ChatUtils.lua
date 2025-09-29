if not host:isHost() then return end


local conf = {
	autoWhisper = false,
	blockPrints = false,
	msgErrors = true,


	lastwhisper = "",
	lastMsg = "",
	lastMsgCount = 0
}
setmetatable(_ENV,{__index=conf})
local player_name = "NUH UHHHHHHHHHHHHHHH"
function events.entity_init()
	player_name = player:getName()
end
function events.CHAT_RECEIVE_MESSAGE(msg,json)
	if not msg or msg == "" then return "" end
	local lowermsg = msg:lower()
	if(msg:sub(0,5) ~= "[lua]") then


		if(lowermsg:sub(0,7) == "[error]" and msgErrors) then
			local name,error = msg:match('%[error%] (.-) : (.-)\n')
			if name and error and name ~= player_name then
				host:sendChatCommand(('/msg %s [AUTOMATIC MSG] FIGURA ERROR: %s'):format(name,error))
			end
		end
		if(lowermsg:find('%[%s?party%s?%]') or lowermsg:find('%[%s?team%s?%]') or lowermsg:find(" "..player_name) ) then
			sounds:playSound('block.note_block.bit',player:getPos(),2,2)
		end
		if(lowermsg:find('whispers to you:')) then
			conf.lastwhisper = lowermsg:match('([^ ]+) whispers to you:')
			sounds:playSound('block.note_block.bit',player:getPos(),2,2)
			return json
				:gsub('commands.message.display.incoming','[%%s ->] %%s')
				:gsub('"color":"gray","translate"','"color":"#ffaaff","translate"')
		elseif(lowermsg:find('you whisper to .-:')) then
			conf.lastwhisper = lowermsg:match('you whisper to (.-):')

			return json
				:gsub('commands.message.display.outgoing','[%%s <-] %%s')
				:gsub('"color":"gray","translate"','"color":"#ffaaff","translate"')
		end
	end

	local _lastMsg = lowermsg
	if(_lastMsg ~= lastMsg) then
		conf.lastMsg = _lastMsg
		conf.lastMsgCount = 0
	else
		conf.lastMsgCount = lastMsgCount + 1
		host:setChatMessage(1,nil)
		local cmd = ('{"text":"","extra":[%s,{"text":" (%d)",color:"#ff5555"}]}'):format(json,lastMsgCount + 1)
		return cmd
	end
	return json
end
local queuedWhisper = ""
function CHATUTILSCOMMAND(msg)
	if(msg == "/figcat") then
		local t = player:getTargetedEntity()
		if not t then return "Invalid entity!" end
		local u = t:getUUID()
		host:sendChatCommand(("/figura set_avatar %s %s"):format(u,player:getUUID()))
		return true
	elseif(msg == "/figcaf") then
		local t = player:getTargetedEntity()
		if not t then return "Invalid entity!" end
		local u = t:getUUID()
		host:sendChatCommand(("/figura set_avatar %s %s"):format(player:getUUID(),u))
		return true
	elseif(msg:sub(0,7) == "/fprint") then
		local succ,err = pcall(function()
			print(load('return '..msg:sub(8))())

		end)
		if not succ then print(err) end
		return true
	elseif(msg:sub(0,11) == "/fruntarget") then
		local func,rest = msg:match('target (.-) (.+)')
		local succ,err = pcall(function()
			local func = player:getTargetedEntity():getVariable(func)
			if(rest:sub(1,1) == "{") then
				func(load('return '..msg:sub(8))())
			else
				func(rest)
			end
		end)
		if not succ then print(err) end
		return true
	end
end


function events.CHAT_SEND_MESSAGE(msg)
	if not msg then return "" end
	if(CHATUTILSCOMMAND(msg)) then return "" end
	if(msg:find(';')) then
		host:appendChatHistory(msg)
		for i in msg:gmatch('[^;]+') do
			if(i:sub(1,1) == "/") then
				host:sendChatCommand(i)
			else
				host:sendChatMessage(i)
			end
		end
		return ""
	end
	if(host:getChatText():sub(0,3) == "/r ") then

		if(not queuedWhisper) then
			print('Nobody to respond to!')
			return ""
		end
		return ('/w %s %s'):format(queuedWhisper,msg)
	end
	local cmd,reciever = msg:match('($autow)(.+)')
	if not cmd then
		if(not autoWhisper) then return msg end
		return ('/w %s %s'):format(autoWhisper ~= true and autoWhisper or lastWhisper,msg)
	end
	if(not reciever) then
		conf.autoWhisper=false;
		print('autoWhisper disabled')
		return ""
	end
	conf.autoWhisper = reciever:sub(2)
	if(autoWhisper == "true" or autoWhisper=="on") then 
		
		conf.autoWhisper = true
	end
	if(autoWhisper == "false" or autoWhisper == "off") then 
		conf.autoWhisper = false
		print('autoWhisper disabled')
		return ""
	end

	print('Autowhisper set to '..tostring(autoWhisper))
	return ""

end
function events.CHAR_TYPED(c)
	if(not host:isChatOpen()) then 
		return
	end
	if(autoWhisper and host:getChatText():sub(1,1) ~= "/") then
		if(autoWhisper ~= true) then
			host:setActionbar(('[{"text":"Whispering to %s.",color:"#ffaaff"},{"text":" Use $autow to change","color":"#FFFF00"}]'):format(autoWhisper))
		elseif(lastwhisper == "" or not lastwhisper) then
			host:setActionbar(('[{"text":"(Autowhisper enabled)Chatting to ",color:"#FF00ff"},{"text":"public chat!",color:"#FFFF55"},{"text":" Use $autow to disable","color":"#FFFF00"}]'):format(lastwhisper))
		else
			host:setActionbar(('[{"text":"Whispering to %s(Last reply).",color:"#ffaaff"},{"text":" Use $autow to change","color":"#FFFF00"}]'):format(lastwhisper))
		end
	end
	if(host:isChatOpen() and host:getChatText() == "/r") then
		queuedWhisper = false
		if(lastwhisper == "") then 
			local i = 1
			local msg = host:getChatMessage(i)
			while(msg ~= nil) do
				i = i+1;
				msg = msg.message:lower() 
				if(msg:find('whispers? to')) then
					conf.lastwhisper = msg:match('([^ ]+) whispers to you:') or msg:match('you whisper to (.-):') or msg:match('$%[(.-) [%-<][%->]%]')
					if(lastwhisper) then
						queuedWhisper = lastwhisper
						-- host:setChatText(('/w %s'):format(lastwhisper))
						host:setActionbar(('[{"text":"Whispering to %s(Last reply).",color:"#ffaaff"}]'):format(queuedWhisper))
						return
					end
					conf.lastwhisper = false;
				end
				msg = host:getChatMessage(i)
			end

			print('Nobody to respond to!')
			return
		end
		host:setChatText(('/w %s'):format(lastwhisper))
	elseif(host:isChatOpen() and host:getChatText():sub(0,3) == "/r " and queuedWhisper) then
		host:setActionbar(('[{"text":"Whispering to %s(Last reply).",color:"#ffaaff"}]'):format(queuedWhisper))
	end
end
return conf

