--[[ Command Palette by Superpowers04. An UNFINISHED Figura library that gives you an extensible command bar like Sublime Text's Command Palette
	Check the provided commands for how to add your own. 
	Example for directly adding a command:
	require('CommandPalette').commands.meow = {
		desc="send meow",
		execute=function(self,split,full_command)
			host:sendChatMessage('meow')
			return "meow" -- Shows a message on CommandPalette, return `false, "MESSAGE"` to throw an error
		end
	}
]]

--[[ TODO
 - Proper mouse selection
 - More argument types

]]

if not host:isHost() then return {commands={}} end
local CommandPalette = {
	--[[CONFIG]]
	spaceComplete=true, -- Whether pressing space should autocomplete. Will not autocomplete in the middle of strings
	defaultTo=false, -- expects function, if true instead of function, will just send to chat
	prefix=">", -- Only used for defaultTo
	keybind = keybinds:newKeybind('Command Palette',"key.keyboard.y"),
	folderIcon = " >",
	-- string.char(240,159,151,128), -- 🗀
	selectedFolderIcon=" ->",
	-- string.char(240,159,151,129), -- 🗁


	--[[NO MORE CONFIG]]
	toggled=false,
	buffer = "",
	part=models:newPart('CommandPalette','HUD'):setVisible(false),
	caretPos = 1,
	needsUpdate = true,
	autofillIndex=1,
	autofill={},
	selection={},
	onOpen = nil, -- Custom functions
	onClose = nil,
	preventHide= false,
	suggestTypes = {
		string="<string>",
		number="<number>",
		float="<float>",
		int="<integer>",
		eger="<integer>",
		boolean={["true"]=true,["false"]=true},
		bool={["true"]=true,["false"]=true},
		player=function()
				local list = {}
				for _,i in pairs(client:getTabList().players) do
					list[i] = true
				end
				return list
			end,
		loaded_player=function()
				local list = {}
				for i in pairs(world:getPlayers()) do
					list[i] = true
				end
				return list
			end
	},
	commands = {
		send={
			desc="Send a chat message",
			execute=function(self,_,stuff)
				stuff = stuff:sub(6)
				host:appendChatHistory(stuff)
				if(stuff:sub(1,1) == '/') then
					host:sendChatCommand(stuff)
				else
					host:sendChatMessage(stuff)
				end
			end
		},
		['lua']={
			desc="Run lua code and print the result in chat",
			suggests = {
				type="string"
			},
			execute=function(self,_,stuff)
				local succ,err = pcall(function()
					local c,e = load('return tostring('..stuff:sub(4)..')')
					if e then error(e) end
					return c()
				end)
				return succ,('%q'):format(err or "nil")
			end
		},
		['luasug']={
			desc="Run lua code and as you're typing, print to chat",
			suggests=function(self,_,stuff)
				ret = table.pack(pcall(function()
					local c,e = load('return tostring('..stuff:sub(6)..')')
					if e then error(e) end
					return c()
				end))
				return ('%s, '):rep(#ret):format(table.unpack(ret))
			end,
			execute=function()
				return false
			end
		},
		['example']={
			desc="An example command",
			suggests={
				error = true,
				print = {
					option=true,
					option2={
						['option2.2']=true
					},
					player={
						type="player"
					}
				},
				donothing = true
			},
			execute=function(self,args,command)
				if args[1] == "error" then
					return false,'"A totally real error"' -- This is injected directly into a formatted message, so the quotes like this are required
				elseif(args[1] == "print") then
					print(args[2],args[3])
					return ('%q,%q'):format(args[2] or "null",args[3] or "null")
				elseif(args[1] == "donothing") then
					return
				end
				return false,('{"text":"Invalid argument!","color":"red"}')
			end
		},
	}
}
self = CommandPalette
if(CommandPalette.defaultTo) then
	self.commands.send=nil
	self.commands['>']=nil
end
CommandPalette.selectionText = CommandPalette.part:newText('CMDPALSELECTION')
	:setOutline(false)
	:setPos(0,0,-0.1)
	:setAlignment('CENTER')
	-- :setBackgroundColor(vec(0,0,0,0.3))
	:setScale(1.25)
CommandPalette.text = CommandPalette.part:newText('CMDPALBUFFER')
	:setOutline(true)
	:setBackground(true)
	:setBackgroundColor(vec(0,0,0,0.6))
	:setAlignment('CENTER')
	:setScale(1.25)
CommandPalette.keybind:onRelease(function()
	if not CommandPalette.toggled then CommandPalette:show() end
	return true
end)
function CommandPalette.show(self)
	host:setUnlockCursor(true)
	CommandPalette.text:setText('initializing')
	self.toggled=true
	self.needsUpdate=true
	events.tick:register(function()
		local succ,err = pcall(CommandPalette.tick)
		if not succ then
			CommandPalette:showError(err)
		end
	end,"CommandPalette.tick")
	if(CommandPalette.AnimUtils == nil) then
		CommandPalette.AnimUtils = false
		pcall(function() CommandPalette.AnimUtils = require('libs.AnimUtils') end) -- Without this, some animations won't play
	end
	self.part:setVisible(true)
	local windowSize = client:getScaledWindowSize()
	self.part:setPos(windowSize.x*-0.5,windowSize.y*-0.5,-1000)
	if(CommandPalette.AnimUtils and CommandPalette.AnimUtils.tweenValue) then
		CommandPalette.AnimUtils.tweenValue(0,1,2,function(a)
			self.part:setScale(a,1,1)
		end,"CommandPalette",function() 
			local windowSize = client:getScaledWindowSize()
			self.part:setScale(1)
		end)
	end
end
function CommandPalette.hide(self)
	if(self.preventHide) then return end
	host:setUnlockCursor(false)

	self.toggled=false
	events.tick:remove('CommandPalette.tick')
	if(CommandPalette.AnimUtils and CommandPalette.AnimUtils.tweenValue) then
		CommandPalette.AnimUtils.tweenValue(1,0,2,function(a)
			self.part:setScale(a,1,1)
		end,"CommandPalette",function() 
			self.part:setVisible(false):setScale(1)
		end)
	else
		self.part:setVisible(false)
	end
	self.buffer=""
end
function CommandPalette.accept(self)
	-- host:sendChatMessage(self.buffer)
	if(self.buffer == "") then return self:hide() end
	if(self.defaultTo) then
		if(self.buffer:sub(0,#self.prefix) ~= self.prefix) then
			if(type(self.defaultTo) == 'function') then
				self.defaultTo(self.buffer)
			else
				host:appendChatHistory(self.buffer)
				if(self.buffer:sub(1,1) == '/') then
					host:sendChatCommand(self.buffer)
				else
					host:sendChatMessage(self.buffer)
				end
			end
			self:hide()
			return
		end
	end
	local split = self.splitCommand(self.buffer)
	local cmd = self.commands[(split[1] or ""):sub(self.defaultTo and #self.prefix+1 or 0)]
	if not cmd then
		CommandPalette:error()
		return
	end
	if not cmd.execute then
		CommandPalette:showError(("%s is missing an execute function!"):format(cmd.name or split[1] or "UNSPECIFIED?!?!"))
		return
	end
	local ret,str = cmd:execute(split,self.buffer:sub(self.defaultTo and #self.prefix+1 or 0))
	if(type(ret) == "string") then
		self.statusMessage = ret
		self.needsUpdate = true
		return
	end
	if(ret == false) then
		if(str) then
			self.statusMessage = str
			self.needsUpdate = true
		end
		CommandPalette:error()
		return
	end
	self:hide()
end
function CommandPalette.autocomplete(self,addSpace)
	local txt = self.autofill[self.autofillIndex]
	if not txt then
		return CommandPalette:addText(" ")
	end
	local split = CommandPalette.splitCommand(self.buffer)
	CommandPalette.caretPos = #self.buffer
	CommandPalette:backspace(#split[#split])
	return CommandPalette:addText(txt.. (addSpace and " " or ""))

end
function CommandPalette.error(self)
	local t = 10
	self.preventHide = true

	events.tick:remove('CMDPALANIM')
	sounds:playSound('minecraft:block.note_block.bit',player:getPos(),1,0.5)
	events.tick:register(function()
		if t == 0 then return events.tick:remove('CMDPALANIM') end
		t = t - 1
		local windowSize = client:getScaledWindowSize()
		self.part:setPos((windowSize.x*-0.5)+(t*(t%2==1 and 1 or -1)),windowSize.y*-0.5)

	end,'CMDPALANIM')
end
function CommandPalette.backspace(self,count)
	self.autofillIndex = 1
	count = count or 1
	local pos = self.caretPos
	local buffer = self.buffer
	if(pos == #buffer) then 
		self.buffer = buffer:sub(0,-(count+1))
		self:cursor(-count)
		return 
	end
	self.buffer = buffer:sub(0,pos-count) .. buffer:sub(pos+1)
	self:cursor(-count)
end
function CommandPalette.addText(self,a)
	self.autofillIndex = 1
	local pos = self.caretPos
	local buffer = self.buffer
	if(pos == #buffer) then 
		self.buffer = buffer .. a
		self:cursor(#a)
		return 
	end
	self.buffer = buffer:sub(0,pos) .. a .. buffer:sub(pos+1)
	self:cursor(#a)
end
function CommandPalette.cursor(self,direction) -- TODO ADD SELECTIONS
	self.autofillIndex = 1
	self.needsUpdate=true
	direction = math.floor(direction)
	self.caretPos = self.caretPos + direction
	if(self.caretPos > #self.buffer) then self.caretPos=#self.buffer end
	if(self.caretPos < 1) then self.caretPos=1 end
end
function CommandPalette.autofillMove(self,direction)
	self.needsUpdate=true
	direction = math.floor(direction)
	self.autofillIndex = self.autofillIndex + direction
	if(self.autofillIndex > #self.autofill) then self.autofillIndex=#self.autofill end
	if(self.autofillIndex < 1) then self.autofillIndex=1 end
end
function CommandPalette.key_press(key,event,mod)
	if(not CommandPalette.toggled) then return end
	
	if(event == 0) then return true end
	-- CommandPalette.text:setText(key)
	if(key == 256) then CommandPalette:hide() 
	elseif(key == 258) then CommandPalette:autocomplete() 
	elseif(key == 257) then 
		CommandPalette:accept()
		if(mod == 2) then CommandPalette.toggled = true end
	elseif(key == 259) then 
		if(mod == 2) then
			local length = 0
			for i=self.caretPos,1,-1 do
				if(self.buffer:sub(i,i) == " ") then
					break
				end
				length = length+1
			end
			CommandPalette:backspace(length > 0 and length or 1)
		else
			CommandPalette:backspace() 
		end
	elseif(key == 262 or key == 263) then CommandPalette:cursor(key==262 and 1 or -1,mod==1)
	elseif(key == 264 or key == 265) then CommandPalette:autofillMove(key==264 and 1 or -1)
	elseif(key == 86 and mod == 2) then CommandPalette:addText(host:getClipboard())
	end
	return true
end
function CommandPalette.showError(self,txt)
	if not txt then txt = self end
	if not txt then txt = "UNSPECIFIED ERROR!" end
	CommandPalette.statusMessage = ('{"text":"AN ERROR OCCURRED!\n","color":"red"},{"text":"%s","color":"red"}'):format(txt)
	CommandPalette:error()
	CommandPalette.needsUpdate = true
	CommandPalette.toggled = true
end
function CommandPalette.char_typed(key,mod)
	if(not CommandPalette.toggled) then return end
	-- CommandPalette.text:setText(key)
	local succ,err
	if(key == " " and self.spaceComplete and #self.autofill > 0) then
		local _,doesntend = self.splitCommand(self.buffer)
		if(doesntend) then
			succ,err = pcall(CommandPalette.addText,CommandPalette,key)
		else
			succ,err = pcall(CommandPalette.autocomplete,CommandPalette,key,true)
		end
	else
		succ,err = pcall(CommandPalette.addText,CommandPalette,key)
	end
	if(not succ) then
		CommandPalette:showError(err)
		return
	end
	return true
end
function CommandPalette.mouse_move()
	local mousePos = client:getMousePos()
	local pos = (mousePos.y - (client:getWindowSize().y*0.5))*(client:getWindowSize().y/720)
	-- self.needsUpdate = true
	if(pos > 44) then

		local offset = math.floor((pos/(client:getTextDimensions('|').y*2))-2)
		
		if(CommandPalette.autofill[offset]) then
			CommandPalette.autofillIndex = offset
			self.needsUpdate = true
			-- print(offset .. "," .. (CommandPalette.autofill[offset] or ""))
		end
	end
end

events.key_press:register(function(...)
	if(not CommandPalette.toggled) then return end
	local succ,err = pcall(CommandPalette.key_press,...)
	if(not succ) then
		CommandPalette:showError(err)
		return
	end
	return err
end,"CommandPalette.key_press")
events.char_typed:register(function(...)
	if(not CommandPalette.toggled) then return end
	local succ,err = pcall(CommandPalette.char_typed,...)
	if(not succ) then
		CommandPalette:showError(err)
		return
	end
	return err
end,"CommandPalette.char_typed")
events.mouse_scroll:register(function(direction)
	if(not CommandPalette.toggled) then return end
	local succ,err = pcall(CommandPalette.autofillMove,CommandPalette,-direction)
	if(not succ) then
		CommandPalette:showError(err)
		return
	end
	return true
end,"CommandPalette.mouse_scroll")
events.mouse_move:register(function()
	if(not CommandPalette.toggled) then return end
	local succ,err = pcall(CommandPalette.mouse_move,CommandPalette)
	if(not succ) then
		events.mouse_move:remove("CommandPalette.mouse_move")
		CommandPalette:showError(err)
		return
	end
	return true
end,"CommandPalette.mouse_move")

events.mouse_press:register(function(button,action)
	if(not CommandPalette.toggled) then return end
	if(action ~= 1) then return true end
	
	local succ,err = false,"Invalid button!"
	if(button == 0) then
		succ,err = pcall(#CommandPalette.autofill == 0 and CommandPalette.accept or CommandPalette.autocomplete,CommandPalette)
		pcall(CommandPalette.addText,CommandPalette," ")
	else
		succ,err = pcall(function()
			if(#self.buffer == 0) then
				return CommandPalette:hide()
			end
			local length = 0
			for i=self.caretPos,1,-1 do
				length = length+1
				if(length > 1 and self.buffer:sub(i,i) == " ") then
					break
				end
			end
			CommandPalette:backspace(length > 0 and length or 1)
			
		end,CommandPalette)

	end

	if(not succ) then
		CommandPalette:showError(err)
		return
	end
	return true
end,"CommandPalette.mouse_press")
local function string_it(a,i)
	local i = i + 1
	if(i > #a) then return end
	local v = a:sub(i,i)
	if not v then return end
	return i, v
end
local function string_iterator(a)
	return string_it,a,0
end
function CommandPalette.splitCommand(cmd)
	local ret,cs,in_quote,ignore_next = {}, {}
	for i,v in string_iterator(cmd) do
		if(ignore_next) then 
			ignore_next = false
			if v ~= " " then cs[#cs+1] = "\\"..v end
		else
			if(v == "\\") then 
				ignore_next = true
			elseif(v == in_quote) then
				in_quote = false
			elseif(v == " " and not in_quote) then
				ret[#ret+1] = table.concat(cs,'')
				cs = {}
			elseif(v == "\"" or v == "'") then
				in_quote = v
			else
				cs[#cs+1] = v
			end
		end
	end
	ret[#ret+1] = table.concat(cs,'')
	return ret,not not in_quote
end
function CommandPalette.showSuggests(text,suggests,part)
	part = part:lower():gsub('.','%1.-')
	local list = {}
	local isAList = {}
	for i,v in pairs(suggests) do
		if(type(i) ~= "string") then i = v end
		if(type(i) == "string" and i:lower():find(part)) then
			list[#list+1]=i
			if(type(v) == "table") then isAList[i] = true end
			found = true
		end
	end
	if(#list == 0 ) then return text,false end
	table.sort(list)
	local afindex = math.clamp(self.autofillIndex,4,math.max(4,#list-4))
	if(afindex > 5) then
		text = ('%s,{"text":"\n...","color":"gray"}'):format(text)
	end
	for index,i in pairs(list) do
		self.autofill[#self.autofill+1] = i
		if(afindex-index < 4 and afindex-index > -5 ) then
			local start,_end = i:lower():find(part)
			if(#self.autofill == self.autofillIndex) then
				text = ('%s,"\n> ",{"text":%q,"color":"gray"},{"text":%q,"color":"yellow"},{"text":%q,"color":"gray"}%s," <"'):format(
					text,i:sub(0,start-1),i:sub(start,_end),i:sub(_end+1),(isAList[i] and (',{"text":%q,"color":"blue"}'):format(self.selectedFolderIcon) or ""))
			else
				text = ('%s,"\n  ",{"text":%q,"color":"gray"},{"text":%q,"color":"yellow"},{"text":%q,"color":"gray"}%s,"  "'):format(
					text,i:sub(0,start-1),i:sub(start,_end),i:sub(_end+1),(isAList[i] and (',{"text":%q,"color":"blue"}'):format(self.folderIcon) or ""))
			end
		end
	end
	if(afindex+4 < #list) then
		text = ('%s,{"text":"\n...","color":"gray"}'):format(text)
	end
	return text,true
end
function CommandPalette.update(self,text)
	self.autofill = {}
	if(self.statusMessage) then
		local msg = self.statusMessage
		-- if(not msg:find('"')) then msg = ("%q"):format(msg) end
		-- local s = pcall(toJson(msg))
		if not msg:find('^["{%[]') then msg = ("%q"):format(msg) end
		self.statusMessage = nil
		-- if(msg:sub(1) ~= '"' and msg:sub(1) ~= '{' and msg:sub(1) ~= "'") then
		-- 	msg = ('%q'):format(msg)
		-- end
		return text..',"\n",'..msg
	end
	if(self.defaultTo) then
		if(self.buffer:sub(0,#self.prefix) ~= self.prefix) then
			return ('%s,{"text":"Send a chat message...\nUse %s for commands","color":"yellow"}'):format(text,self.prefix)
		end
	end
	local split = self.splitCommand(self.buffer)
	-- text = ('%s,"\n",%q'):format(text,table.concat(split,', '))
	local cmd = split[1] or ""
	if(self.defaultTo) then
		cmd = cmd:sub(#self.prefix+1)
	end
	table.remove(split,1)
	local command = self.commands[cmd]
	local foundCommand = false
	if(command) then
		foundCommand =true
		if(command.populateSuggests) then
			command:populateSuggests(split,self.buffer)
		end
		if(#split == 0) then
			if(command.descjson) then
				return ('%s,"\n",s'):format(text,command.descjson)
			elseif(command.desc) then
				return ('%s,"\n  ",{"text":%q,"color":"yellow"},"  "'):format(text,command.desc)
			else
				return ('%s,{"text":"\nThis command has nothing to say for itself...","color":"yellow"}'):format(text)
			end
		else
			local suggests = command.suggests
			if suggests then
				if(type(suggests) == "function") then
					suggests = suggests(split,self.buffer)
					if(type(suggests) == "string") then
						return ('%s,%s'):format(text,suggests)
					end
				end
				for i,part in pairs(split) do
					::SUGGESTSSTART::
					local s = suggests[part] or i < #split and suggests.suggests
					if(s) then
						if(type(s) == "table") then
							suggests = s
						elseif(type(s) == "function") then
							suggests = s(part,split,self.buffer)
							if(type(suggests) == "string") then
								text = ('%s,%s'):format(text,suggests)
								break
							elseif(type(suggests) == "table") then
								goto SUGGESTSSTART
							end
						elseif(type(s) == "table" and s.suggests) then
							s = suggests.suggests
						else
							suggests = {}
							break;
						end
					elseif i >= #split then 
						if(not suggests.type) then
							return CommandPalette.showSuggests(text,suggests,part)
						end
						local t = suggests.type
						local _t = self.suggestTypes[t]
						if(_t) then
							if(type(_t) == "function") then
								return CommandPalette.showSuggests(text,_t(part,split,self.buffer),part,suggests.name)
							elseif(type(_t) == "table") then
								return CommandPalette.showSuggests(text,_t,part,suggests.name)
							end
							if(suggests.name) then
								_t = suggests.name .. " : " .. _t
							end
							if not _t then error(("Suggest type %s gave a nil value"):format(t)) end
							return ('%s,"\n",{"text":%q,"color":"yellow"}'):format(text,_t)
						end
						if(t == "function") then
							local ret = suggests:func(part,split,self.buffer)
							if(type(ret) == "table") then
								return CommandPalette.showSuggests(text,ret,part)
							end
							if not ret then error("Suggests function returned nil") end
							return ('%s,"\n",{"text":%q,"color":"yellow"}'):format(text,tostring(ret))
							
						end
						if not ret then 
							if(t) then
								error(("%q is an invalid type!"):format(t))

							end
							error("No suggestions to show")
						end
						return ('%s,"\n",{"text":%q,"color":"yellow"}'):format(text,ret)
						-- break
					else
						break
					end
				end
				return text
			else
				return ('%s,{"text":"\n N/A","color":"yellow"}'):format(text)
			end
		end
	elseif(#split == 0) then
		text,found = CommandPalette.showSuggests(text,self.commands,cmd)
		if(found) then
			return text
		end
	end
	return ('%s,{"text":"\n  COMMAND NOT FOUND  ","color":"red"}'):format(text)
end
function CommandPalette.tick()
	if(not self.toggled or host:isChatOpen() or host:getScreen() ~= nil ) then return CommandPalette:hide() end
	self.preventHide = false
	if(not self.needsUpdate) then return end
	self.needsUpdate = false
	
	local txt = ('["  ",{"text":%q},{"text":"|","color":%q},%q,"  \n--------------"')
		:format(self.buffer:sub(0,self.caretPos),--[[time%2==1 and ]]"yellow" --[[or "black"]],self.buffer:sub(self.caretPos+1))
	local succ,err = pcall(function()
		txt = self:update(
			txt
		)
	end)
	if(self.autofillIndex > #self.autofill) then
		self.autofillIndex = 1
	end
	if(not succ) then
		txt = ('%s,"\n",{"text":"AN ERROR OCCURRED!\n","color":"red"},{"text":"%s","color":"red"}'):format(txt,err:gsub('"','\\"'))
			:gsub('%[Java%]: .-pcall.-\n','')
		
		self:error()
	end
	-- self.selectionText:setText(('[{"text":%q,"color":"gray"},]'):format(self.buffer,self.autofill[self.autofillIndex] or ""))
	-- if(selection) then
	-- 	self.selectionText:setText((" "):rep(selection.offset),("▮"):rep(selection.length))
	-- else
	-- 	self.selectionText:setText('')
	-- end
	-- :gsub(',("  \n--------------"',(',{"text":%q,"color":"#aa1177","italic":true},"  \n--------------"'):format(self.autofill[self.autofillIndex] or ""))
	self.text:setText(txt:gsub('	',"")..',"\n----------------"]')
end
-- events.render:register(function()
-- 	if(not CommandPalette.toggled) then return end
-- end)


-- EXTRA UTILTIES

-- CommandPalette.commands.findblock = {
-- 	execute=function(self,sep)
-- 		local list = ""
-- 		for i,v in pairs(world.getBlocks(player:getPos()-vec(20,20,20),player:getPos()+vec(20,20,20))) do
-- 			if(v.id:find(sep[2])) then
-- 				list = list .. v:getPos():toString()
-- 			end
-- 		end
-- 		print(list)
-- 	end
-- }


return CommandPalette