-- SuperFOV by Superpowers04
-- A script that allows you to have custom FOVs for first person and third person along with velocity based speed, all smoothly lerped to
-- Also provides a zoom function. If you have Extura, then it'll properly adjust sensitivity too

if not host:isHost() then return end -- This is only needed on the host side
-- CONFIG
-- Note, these values are multiplicative, so for example 1 FOV would be 100 FOV at 100 FOV,  0.8 would be 80 FOV, etc
local FOVS = {
	FP = config:load('FOV.FP') or 1, -- FOV for first person
	TP = config:load('FOV.TP') or 0.8, -- FOV for third person
	TPBW = config:load('FOV.TPBW') or 0.6, -- FOV for third person backwards

}
local FOVspeed=1 -- The speed that your FOV is lerped to

-- Keybinds. If you have a script that auto-saves keybinds for you then ignore this.
--  Otherwise look at https://applejuiceyy.github.io/figs/latest/Keybinds/ for key ids
local defaultToggleKey = "key.keyboard.l" -- The default key used for toggling
local defaultZoomKey = "key.keyboard.c" -- The default key used for zooming
-- Pressing both of these together will save your FOV as your current zoom level

-- ACTUAL SCRIPT

local endFOV = 1
local nextTickFOV = 1
local lastTickFOV = 0.9

local floor = math.floor
local lerp = math.lerp
local abs = math.abs

local zoom = 0.5
local isZooming = false
local oldSensitivity = 1
local toggleFOVKeybind = keybinds:newKeybind("Toggle FOV",defaultToggleKey)
local zoomKeybind = keybinds:newKeybind("Zoom",defaultZoomKey)
local useFOV = true
zoomKeybind.press = function() 
	if(renderer.getSensitivity) then
		oldSensitivity = renderer:getSensitivity()
		renderer:setSensitivity(oldSensitivity * zoom)
	end
	events.MOUSE_SCROLL:register(function(direction)
		zoom = zoom + (direction * -0.01)
		if(zoom < 0.01) then zoom = 0.01 end
		if(renderer.getSensitivity) then 
			renderer:setSensitivity(oldSensitivity * zoom)
		end
		host:setActionbar(tostring(zoom))
		return true
	end,"FOV.mouse")
	isZooming = true
end
zoomKeybind.release = function()
	isZooming = false;
	if(renderer.getSensitivity) then
		renderer:setSensitivity(oldSensitivity)
	end
	events.MOUSE_SCROLL:remove("FOV.mouse")
end

-- I register and deregister functions here so the script is practically disabled when you toggle it off
function toggleFOV(bool)
	renderer:setFOV()
	useFOV = bool
	host:setActionbar((useFOV and "Enabled" or "Disabled") .. " SuperFOV")
	if(bool) then
		events.TICK:register(function()
			endFOV = isZooming and zoom or (renderer:isFirstPerson() and FOVS.FP or renderer:isCameraBackwards() and FOVS.TPBW or FOVS.TP) 
				+(player:getVelocity():length() * 0.2) 
			-- Change and uncomment the line above to 
			--  +(player:isSprinting() and 0.2 or 0)
			-- for only if you're sprinting

			-- No reason to lerp unless FOV has changed
			if(lastTickFOV == endFOV) then return end
			-- If difference is under 0.01, lock it. Else the fov will rapidly swap back and fourth
			if(abs(lastTickFOV-endFOV) < 0.01) then 
				lastTickFOV = endFOV
				nextTickFOV = endFOV
				return
			end

			lastTickFOV = nextTickFOV 
			nextTickFOV = lerp(lastTickFOV,endFOV,FOVspeed)
			renderer:setFOV(lastTickFOV)
		end,'FOV.TICK')
		events.POST_RENDER:register(function(delta,context)
			if(lastTickFOV == nextTickFOV) then return end
			renderer:setFOV(lerp(lastTickFOV,nextTickFOV,delta))
		end,'FOV.RENDER')
	else
		events.TICK:remove('FOV.TICK')
		events.POST_RENDER:remove('FOV.RENDER')
	end
end
toggleFOV(true)

toggleFOVKeybind.release = function()
	if(isZooming) then
		local type = (renderer:isFirstPerson() and "FP" or renderer:isCameraBackwards() and "TPBW" or "TP")
		FOVS[type] = zoom
		config:save('FOV.'..type,zoom)
		local friendlyName = ({FP="First Person",TP="Third Person",TPBW="Third Person Reverse"})[type]
		host:setActionbar('Set fov of ' .. friendlyName .. ' to ' .. tostring(zoom))
		return
	end
	toggleFOV(not useFOV)
end






