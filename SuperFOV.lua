-- SuperFOV by Superpowers04
-- A script that allows you to have custom FOVs for first person and third person along with velocity based speed, all smoothly lerped to
-- Also provides a zoom function. If you have Extura, then it'll properly adjust sensitivity too

if not host:isHost() then return {} end -- This is only needed on the host side
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


local m = {
	--Callbacks that can be changed 
	onZoomStart=function(self,zoom) end,
	onZoomEnd=function(self) end,
	onZoomChange=function(self,zoom) end,
	onToggle=function(self,state) end,


	FOVS=FOVS,
	FOVspeed = FOVspeed,
	endFOV = 1,
	nextTickFOV = 1,
	lastTickFOV = 0.,
	zoom = 0.5,
	isZooming = false,
	oldSensitivity = 1,
	toggleFOVKeybind = keybinds:newKeybind("Toggle FOV",defaultToggleKey),
	zoomKeybind = keybinds:newKeybind("Zoom",defaultZoomKey),
	useFOV = true,

}

local floor,lerp,abs,min,max = math.floor, math.lerp, math.abs, math.min, math.max

m.zoomKeybind.press = function() 
	if(host.getSensitivity) then
		m.oldSensitivity = host:getSensitivity()
		host:setSensitivity(m.oldSensitivity * m.zoom)
	end
	events.MOUSE_SCROLL:register(function(direction)
		m.zoom = m.zoom + (direction * -0.01)
		if(m.zoom < 0.01) then m.zoom = 0.01 end
		if(host.getSensitivity) then 
			host:setSensitivity(m.oldSensitivity * m.zoom)
		end
		host:setActionbar(tostring(m.zoom))
		m:onZoomChange(m.zoom)
		return true
	end,"FOV.mouse")
	m.isZooming = true
	m:onZoomStart(m.zoom)
end
m.zoomKeybind.release = function()
	m.isZooming = false;
	if(host.getSensitivity) then
		host:setSensitivity(m.oldSensitivity)
	end
	events.MOUSE_SCROLL:remove("FOV.mouse")
	m:onZoomEnd()
end

-- I register and deregister functions here so the script is practically disabled when you toggle it off
m.toggleFOV = function(bool)
	renderer:setFOV()
	m.useFOV = bool
	host:setActionbar((m.useFOV and "Enabled" or "Disabled") .. " SuperFOV")
	m:onToggle(bool)
	m.lastTickFOV = 0
	if(bool) then
		events.TICK:register(function()
			m.endFOV = m.isZooming and m.zoom or (renderer:isFirstPerson() and FOVS.FP or renderer:isCameraBackwards() and FOVS.TPBW or FOVS.TP) 
				+(player:getVelocity():length() * 0.2) 
			-- Change and uncomment the line above to 
			--  +(player:isSprinting() and 0.2 or 0)
			-- for only if you're sprinting

			-- No reason to lerp unless FOV has changed
			if(m.lastTickFOV == m.endFOV) then return end
			-- If difference is under 0.01, lock it. Else the fov will rapidly swap back and fourth
			if(abs(m.lastTickFOV-m.endFOV) < 0.01) then 
				m.lastTickFOV = m.endFOV
				m.nextTickFOV = m.endFOV
				return
			end

			m.lastTickFOV = m.nextTickFOV 
			m.nextTickFOV = lerp(m.lastTickFOV,m.endFOV,m.FOVspeed)
			renderer:setFOV(max(min(m.lastTickFOV,10),0))
		end,'FOV.TICK')
		events.POST_RENDER:register(function(delta,context)
			if(m.lastTickFOV == m.nextTickFOV) then return end
			renderer:setFOV(lerp(m.lastTickFOV,m.nextTickFOV,delta))
		end,'FOV.RENDER')
	else
		events.TICK:remove('FOV.TICK')
		events.POST_RENDER:remove('FOV.RENDER')
	end
end
m.toggleFOV(true)

m.toggleFOVKeybind.release = function()
	if(m.isZooming) then
		local type = (renderer:isFirstPerson() and "FP" or renderer:isCameraBackwards() and "TPBW" or "TP")
		m.FOVS[type] = m.zoom
		config:save('FOV.'..type,m.zoom)
		local friendlyName = ({FP="First Person",TP="Third Person",TPBW="Third Person Reverse"})[type]
		host:setActionbar('Set fov of ' .. friendlyName .. ' to ' .. tostring(m.zoom))
		return
	end
	m.toggleFOV(not useFOV)
end


return m




