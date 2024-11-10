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
	events.tick:remove(ID)
	events.render:remove(ID)
	events.tick:register(function()
		ticks = ticks+1
		if(ticks <= tickLength) then return end
		if(onComplete) then onComplete() end
		events.tick:remove(ID)
		events.render:remove(ID)
	end,ID)
	events.render:register(function(dt)
		func(lerp(from,to,(ticks+dt)/tickLength))
	end,ID)
	return ID
end
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
	events.tick:register(function()
		ticks = ticks+1
		if(ticks <= tickLength) then return end
		if(onComplete) then onComplete() end
		events.tick:remove(ID)
		events.render:remove(ID)
	end,ID)
	events.render:register(function(dt)
		func(lerp(from,to,(ticks+dt)/tickLength))
	end,ID)
	return ID
end
function utils.cancelTween(ID)
	events.tick:remove(ID)
	events.render:remove(ID)
end

function utils.pressCallback(func,onlyAccept,...)
	if(not host:isHost()) then return end
	local args = {...}
	events.KEY_PRESS:remove('pressCallback')
	events.KEY_PRESS:register(function(code,act)
		if(code ~= onlyAccept and (code > 250 or host:getScreen() or utils.allowedKeys[code])) then return end
		if(act ~= 1) then return 1 end
		func(table.unpack(args))
		events.KEY_PRESS:remove('pressCallback')
		return true
	end,'pressCallback')
end

_G.animUtils = utils
return utils
