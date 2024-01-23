if not host:isHost() then return end
local endFOV = 1
local nextTickFOV = 1
local lastTickFOV = 0.9
local FOVspeed=0.5
local FPFOV = 1
local TPFOV = 0.8

events.POST_RENDER:register(function(delta,context)
	if(lastTickFOV ~= nextTickFOV) then
		renderer:setFOV(math.lerp(lastTickFOV,nextTickFOV,delta))
	end
end)
events.TICK:register(function()
	if(isFirstPerson ~= renderer:isFirstPerson()) then
		isFirstPerson = renderer:isFirstPerson()
		endFOV = isFirstPerson and FPFOV or TPFOV
	end
	local FOV = endFOV + (player:getVelocity():length() * 0.2) -- Change this to player:isSprinting() for only if you're sprinting
	if(lastTickFOV ~= FOV) then
		lastTickFOV = nextTickFOV 
		nextTickFOV = (math.floor(math.lerp(lastTickFOV,FOV,FOVspeed) * 100)) * 0.01
		renderer:setFOV(lastTickFOV)
	end
end)
