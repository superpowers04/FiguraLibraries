
local timers
local tmrList = {}
timers = {
	list=tmrList,
	timer={
		start=function(self,ticks)
			self.ticks = ticks or 0
			tmrList[self.name] = self
		end,
		unpause=function(self)
			tmrList[self.name] = self
		end,
		pause=function(self,ticks)
			self.ticks = ticks
			tmrList[self.name] = nil
		end,
		cancel=function(self,runFinishFunc)
			if(runFinishFunc and self.finishFunc) then
				self:finishFunc()
			end
			self.ticks = self.ticks or self.length
			tmrList[self.name] = nil
		end,
	}
}
local tmrMetatable = {__index=timers.timer}
function timers.new(tmr)
	if tmr.length then 
		tmr.ticks = 0
	else 
		tmr.length = tmr.ticks;
		tmr.ticks = 0
	end
	if not tmr.name then tmr.name = "TIMER-" .. world:getTime() .. tostring(math.random(0,1000)) end
	setmetatable(tmr,tmrMetatable)
	tmrList[tmr.name] = tmr 
	return tmr
end
events.WORLD_TICK:register(function()
	if(#tmrList < 0) then return end
	for i,tmr in pairs(tmrList) do
		tmr.ticks = tmr.ticks + 1
		if(tmr.tickFunc) then tmr:tickFunc() end
		if tmr.ticks > tmr.length then 
			tmr:cancel(true)
		end
	end
end,"TIMERLOOP")
events.WORLD_RENDER:register(function(delta)
	if(#tmrList < 0) then return end
	for i,tmr in pairs(tmrList) do
		if(tmr.renderFunc) then tmr:renderFunc(delta) end
	end
end,"TIMERLOOP")

return timers