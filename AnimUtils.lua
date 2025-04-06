-- BLOCKING MOVEMENT KEYS REQUIRES EXTURA OR BLOCKKEYS
local keys
pcall(function()
	keys = require('libs.BlockKeys')
end)
local utils = {}
utils.allowedKeys={
	[256]=true,
	[257]=true
}
utils.callbacks = {}
utils.activeAnimations = {}

function utils.finishAnim(name)
	local anims = utils.activeAnimations[name]
	utils.activeAnimations[name] = nil
	if(anims == nil) then return end
	for _,animation in ipairs(anims) do
		animation:stop()
	end
end
utils.finAnim = utils.finishAnim
function utils.nextAnim(name,anim,index)
	if(type(anim) == "string") then anim = animations.model[anim] end
	local anims = utils.activeAnimations[name]
	index = index or 1
	if not anims then
		anims = {}
		utils.activeAnimations[name] = anims
	end
	if(anims[index]) then anims[index]:stop() end
	anims[index] = anim
end
function utils.remAnim(name,index)
	local anims = utils.activeAnimations[name]
	if not anims then return end
	index = index or 1
	if(anims[index]) then anims[index]:stop() end
end
function utils.addAnim(name,anim,index)
	if(type(anim) == "string") then anim = animations.model[anim] end
	local anims = utils.activeAnimations[name]
	if not anims then
		anims = {}
		utils.activeAnimations[name] = anims
	end
	anims[index or #anims + 1] = anim

end
function utils.canMove(bool,onlyAccept)
	if(not host:isHost()) then return end
	-- events.KEY_PRESS:remove('pressCallback')
	-- print(bool)
	if(host.overridePlayerMovement) then
		host:setPlayerMovement(bool)
	elseif keys then
		keys:toggle(bool)
	else
		error('THIS FEATURE REQUIRES EXTURA OR BLOCKKEYS')
	end

	-- return events.KEY_PRESS:register(function(code,act)
	-- 	if(code ~= onlyAccept and (code > 250 or code == 96 or host:getScreen() or utils.allowedKeys[code])) then return end
	-- 	if(act ~= 1) then return end
	-- 	return true
	-- end,'pressCallback')
end


function utils.waitTilCondition(func,event)
	local event = event or events.tick
	local ID = "EVENT_"..tostring(tostring(client:getSystemTime())..tostring(math.random()))
	event:register(function()
		if(not func()) then return end
		event:remove(ID)
	end,ID)
end
function utils.tweenValue(from,to,tickLength,func,ID,onComplete)
	if(from == to) then 
		events.tick:remove(ID)
		events.render:remove(ID)
		return
	end
	local ID = ID and "TWEEN_"..ID or "Tween_"..tostring(tostring(client:getSystemTime())..tostring(math.random()))
	local ticks = 0
	local tickLength = tickLength or 10
	local lerp = math.lerp
	if onComplete == true then
		onComplete = func
	end
	events.tick:remove(ID)
	events.render:remove(ID)
	events.world_render:remove(ID)
	events.tick:register(function()
		ticks = ticks+1
		if(ticks < tickLength) then 
			func(lerp(from,to,ticks/tickLength))
			return
		end
		if(onComplete) then onComplete(to) end
		events.tick:remove(ID)
		events.render:remove(ID)
		utils.callbacks[ID]=nil
	end,ID)
	events.render:register(function(dt)
		local nextTick = ticks+dt
		if(nextTick >= tickLength) then
			func(to)
			if(onComplete) then onComplete(to) end
			events.tick:remove(ID)
			events.render:remove(ID)
			utils.callbacks[ID]=nil
			return
		end
		func(lerp(from,to,nextTick/tickLength))
	end,ID)
	return ID
end
function utils.blendOutAnim(anim,tickLength)
	local ID = ("blend_out_"..anim:getName())
	local IDCancel = ("blend_in_"..anim:getName())
	events.tick:remove(IDCancel)
	events.render:remove(IDCancel)
	events.tick:remove(ID)
	events.render:remove(ID)
	local ticks = 0
	local tickLength = tickLength or 10
	events.tick:register(function()
		ticks = ticks+1
		if(ticks < tickLength) then 
			anim:setBlend(1 - (ticks/tickLength))
			return
		end
		anim:setBlend(1):stop()
		-- print("blend out",anim,ID)
		events.tick:remove(ID)
		events.render:remove(ID)
	end,ID)
	events.render:register(function(dt)
		local nextTick = ticks+dt
		anim:setBlend(1 - (nextTick/tickLength))
	end,ID)
end
function utils.blendInAnim(anim,tickLength)
	local ID = ("blend_in_"..anim:getName())
	local IDCancel = ("blend_out_"..anim:getName())
	events.tick:remove(IDCancel)
	events.render:remove(IDCancel)
	events.tick:remove(ID)
	events.render:remove(ID)
	local ticks = 0
	local tickLength = tickLength or 5
	-- print("blend in",anim,ID)
	events.tick:register(function()
		ticks = ticks+1
		if(ticks < tickLength) then 
			anim:setBlend(ticks/tickLength)
			return
		end
		anim:setBlend(1)
		-- print("blendt",anim,ID)
		events.tick:remove(ID)
		events.render:remove(ID)
	end,ID)
	events.render:register(function(dt)
		local nextTick = ticks+dt
		anim:setBlend(nextTick/tickLength)
	end,ID)
end
utils.BOA = utils.blendOutAnim
utils.blendAnimations = function(from,to,length)
	if(from ~= nil) then
		utils.blendOutAnim(from,length)
	end
	if(to ~= nil) then
		utils.blendInAnim(to:play(),length)
	end
end
utils.blendOutAnimAuto = function(anim)
	local time = (anim:getLength()-anim:getTime())
	-- print(time)
	return utils.blendOutAnim(anim,time)
end
utils.BIA = utils.blendInAnim
function utils.blendAnim(from,to,tickLength,anim,ID,onComplete)
	if(from == to) then 
		events.tick:remove(ID)
		events.render:remove(ID)
		return
	end
	local ID = ID and ("TWEEN_"..ID) or ("Tween_"..anim:getName())
	local ticks = 0
	local tickLength = tickLength or 10
	local lerp = math.lerp
	events.tick:remove(ID)
	events.render:remove(ID)
	utils.callbacks[ID]=onComplete
	events.tick:register(function()
		ticks = ticks+1
		if(ticks < tickLength) then 
			func(lerp(from,to,ticks/tickLength))
			return
		end
		if(onComplete) then onComplete() end
		events.tick:remove(ID)
		events.render:remove(ID)
		utils.callbacks[ID]=nil
	end,ID)
	events.render:register(function(dt)
		local nextTick = ticks+dt
		if(nextTick >= tickLength) then
			func(to)
			if(onComplete) then onComplete() end
			events.tick:remove(ID)
			events.render:remove(ID)
			utils.callbacks[ID]=nil
			return
		end
		func(lerp(from,to,nextTick/tickLength))
	end,ID)
	return ID
end
function utils.cancelTween(ID,runComplete)
	events.tick:remove(ID)
	events.render:remove(ID)
	events.world_render:remove(ID)
	if(runComplete and utils.callbacks[ID]) then
		utils.callbacks[ID]()
	end
	utils.callbacks[ID]=nil
end
function utils.pressCallback(func,onlyAccept,...)
	if(not host:isHost()) then return end
	local args = {...}
	-- keys:toggle(false,function()
	-- 	func(table.unpack(args))
	-- 	print('h')
	-- 	keys:toggle(true,false)
	-- 	return true
	-- end)
	events.KEY_PRESS:remove('pressCallback')
	events.KEY_PRESS:register(function(code,act)
		if(code ~= onlyAccept and (code > 250 or host:getScreen() or utils.allowedKeys[code])) then return end
		if(act ~= 1) then return 1 end
		-- print(code)
		func(table.unpack(args))
		events.KEY_PRESS:remove('pressCallback')
		return true
	end,'pressCallback')
end

local animIDList = {}
for i,v in pairs(animations:getAnimations()) do
	if(not v:getName():find('%!hide')) then
		animIDList[#animIDList+1] = v
	end
end
table.sort(animIDList,function(a,b) return a:getName() > b:getName() end)
local animToIDList = {}
for i,v in ipairs(animIDList) do
	animToIDList[v:getName():lower():gsub(' ',"_")] = i
	animToIDList[v] = i
end
function pings.playAnim(a)
	animIDList[a]:play()
end
function pings.stopAnim(a)
	animIDList[a]:stop()
end
function pings.value(a,b,...)
	local anim = animIDList[a]
	anim[b](anim,...)
end

function utils.getAnimID(a)
	local anim,retID = animIDList[tonumber(a)],tonumber(a)
	if not anim then
		anim,retID = animIDList[animToIDList[a]],animToIDList[a]
	end
	if not anim and type(a) == "string" then
		anim,retID = animIDList[animToIDList[a:lower()]],animToIDList[a:lower()]
	end
	if not anim then return end
	return retID,anim
end

function utils.animState(a,s)
	local anim = utils.getAnimID(a)
	if not anim then error("Invalid ANIM!") end
	pings[s and "playAnim" or "stopAnim"](anim)
end
function utils.animValue(a,key,...)
	local anim = utils.getAnimID(a)
	if not anim then error("Invalid ANIM!") end
	pings.value(anim,key,...)
end


utils.animList = animIDList
utils.animToIDList = animToIDList
if(host:isHost()) then
	pcall(function()
		local CommandPalette = require('libs.CommandPalette')
		CommandPalette.commands.anim = {
			desc="Animations",
			suggests={
				play=utils.animToIDList,
				stop=utils.animToIDList,
				value=utils.animToIDList,
			},
			execute = function(self,sep,all)
				table.remove(sep,1)
				local cmd = (sep[1] or ""):lower()
				local anim = (sep[2] or ""):lower()
				if(cmd == "play" or cmd == "stop") then
					utils.animState(anim,cmd=="play")
					return
				end

			end

		}
	end)
end

local animGroup = {
	play = function(self)
		for i,v in pairs(self) do
			v:play()
		end
		return self
	end,
	stop = function(self)
		for i,v in pairs(self) do
			v:stop()
		end
		return self
	end,
	setPlaying = function(self,b)
		for i,v in pairs(self) do
			v:setPlaying(b)
		end
		return self
	end,
	setBlend = function(self,b)
		for i,v in pairs(self) do
			v:setBlend(b)
		end
		return self
	end,
	runAll = function(self,k,...)
		if(k:sub(0,3) == "get") then
			for i,v in pairs(self) do
				return v[k](v,...)
			end
			return nil
		end
		for i,v in pairs(self) do
			v[k](v,...)
		end
		return self
	end,
	__mt={}
}
animGroup.__mt.__index = function(s,k) 
	return animGroup[k] or function(s,...) return animGroup.runAll(s,k,...) end

end
function utils.newAnimGroup(animations)
	return setmetatable(animations,animGroup.__mt)
end



_G.animUtils = utils
return utils