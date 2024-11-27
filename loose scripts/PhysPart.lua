local module = {
	hasInitted = false,
	physTypes={

	},
	colliders={

	},
	debug=true,
}
local defaults = {
	name="default",
	disabled = false,
	bounciness=0.5,

	horizontalMultiplier=2,
	verticalMultiplier=1,
	rotMultiplier=vec(20,20,20),
	scaleMultiplier=vec(0.1,0.1,0.1),

	changeScale=true,
	changeRot=true,
	collidable=true,
	colliderSize=3,

	-- clampMax=vec(3,3,3),
	-- clampMin=vec(-3,-3,-3),
	clampMax=3,
	clampMin=-3,
	clampRotMax=0.5,
	clampRotMin=-0.5,
	clampScaleMax=0.5,
	clampScaleMin=-0.5,


	lookedForBones=false,
	parts=nil
}
local partDefaults = {
	lastPos=vec(0,0,0),
	nextPos=vec(0,0,0),
	baseRot=vec(0,0,0),
	currentDiff=0,
	lastDiff=0,
	part = nil,
	partEnd = nil,
	disabled = false,
}


function module.fillPhys(phys)
	assert(phys,'attempt to add nil value as phys part')
	assert(phys.name,'attempt to add phys part without name')
	for i,v in pairs(defaults) do
		if(phys[i] == nil) then
			phys[i] = v
		end
	end
	local oldParts = phys.parts
	phys.parts = {}
	if(oldParts ~= nil) then 
		for i,part in pairs(oldParts) do
			self.addPartToPhys(phys,part)
		end
	end
end
function module.addPartToPhys(phys, part, partEnd)
	assert(type(phys) == 'table','attempt to add part to '..type(phys)..' value(expected phys)')
	assert(type(part):lower():find('part') or type(part):lower():find('task'),'attempt to add '..type(part)..' to phys value(expected ModelPart)')
	-- assert(phys,'attempt to add nil value to phys(expected model part)')

	if(partEnd == nil) then
		local recurse
		function recurse(part)
			for i,v in pairs(part:getChildren()) do
				if(v:getName():sub(0,3) == "end") then
					partEnd = v
					return true
				end
				if(recurse(v)) then return true end
			end
		end
		recurse(part)
	end
	local partInfo = {
		lastPos=vec(0,0,0),
		currentPos=vec(0,0,0),
		currentDiff=vec(0,0,0),
		lastDiff=vec(0,0,0),
		phys=phys,
		part=part,
		partEnd=partEnd
	}
	phys.parts[#phys.parts+1] = partInfo
	return partInfo
end
function module:addPhysType(physes, checkForBones)
	if(physes ~= nil) then
		if(physes.name == nil) then
			for i,v in pairs(physes) do
				if(v.name == nil) then v.name = i end
				self.fillPhys(v)
				self.physTypes[v.name] = v
			end
		else
			self.fillPhys(physes)
			self.physTypes[physes.name] = physes
		end
	end
	if(not checkForBones) then return physes end
		-- if(not v.lookedForBones) then
	local recurse,getPartEnd
	function getPartEnd(part)
		for i,v in pairs(part:getChildren()) do
			if(v:getName():sub(0,3) == "end") then
				return v
			end
		end
	end
	function recurse(part)
		for i,v in pairs(part:getChildren()) do
			local name = v:getName()

			if(name:sub(0,5) == "phys_") then
				local phys = self.physTypes[name:sub(6)]
				if(phys) then
					if(not phys.lookedForBones) then
						self.addPartToPhys(phys,v)
					end
				-- else
				-- 	-- print(name.. ' has no physpart!')
				end
			end
			recurse(v)
			
		end
	end
	recurse(models)
	for physID,phys in pairs(self.physTypes) do
		phys.lookedForBones = true
	end
	return physes
end

local clamp = math.clamp
local lerp = math.lerp
local abs=math.abs
local c = clamp
local emptyVec=vec(0,0,0)
-- local particle = particles:newParticle("minecraft:end_rod")
events.entity_init:register(function()
	function recurse(part)
		for i,v in pairs(part:getChildren()) do
			local name = v:getName()

			if(name:sub(0,5) == "col_") then
				local type,num = name:match('_(.-)(%d+)')
				modules.colliders[#modules.colliders+1] = {
					part=v,
					size=num,type=type
				}
			end
			recurse(v)
			
		end
	end
	recurse(models)
	module:addPhysType(nil,true)
	local ret = true
	module.tick = function()
		-- for i,v in ipairs(module.colliders) do
		-- 	v.pos = v.part:partToWorldMatrix():apply()
		-- end
		for physID,phys in pairs(module.physTypes) do
			-- if(type(phys.clampMin) == "number") then
			-- 	phys.clampMin = vec(phys.clampMin,phys.clampMin,phys.clampMin)
			-- end
			-- if(type(phys.clampMax) == "number") then
			-- 	phys.clampMax = vec(phys.clampMax,phys.clampMax,phys.clampMax)
			-- end
			if(not phys.disabled) then
				for pID,part in ipairs(phys.parts) do
					if(not part.disabled) then
						-- if(part.collidable) then
						-- 	local b,cast = raycast:block(part.lastPos,part.currentPos,'COLLIDER')
						-- 	if(cast) then
						-- 		particles:newParticle("minecraft:end_rod",part.currentPos)
						-- 		part.lastPos:sub(part.currentPos-cast)
						-- 		part.currentPos:sub(part.currentPos-cast)
						-- 	end
						-- 	for i,v in ipairs(module.colliders) do
						-- 		if(abs(part.currentPos:copy():sub(v.pos):length())) then
						-- 			part.currentPos:sub(part.currentPos-v.pos)
						-- 			particles:newParticle("minecraft:end_rod",part.currentPos)
						-- 		end
						-- 	end

						-- end

						part.lastPos:set(part.currentPos)
						part.currentPos:set(part.partEnd:partToWorldMatrix():apply())
						if(part.part:getVisible()) then
							local amm = (part.lastDiff-part.currentDiff)*phys.bounciness
							part.lastDiff = part.currentDiff
							local diff = part.lastPos - part.currentPos
							diff:set(math.round(diff.x*100)*0.01,math.round(diff.y*100)*0.01,math.round(diff.z*100)*0.01)
							part.currentDiff = vectors.rotateAroundAxis(player:getBodyYaw(delta)+90, diff, vec(0, 1, 0))
								:mul(phys.horizontalMultiplier,0,phys.horizontalMultiplier)
							part.currentDiff:add(diff.y*phys.verticalMultiplier,part.currentDiff.z)
								:sub(amm)
							if(part.currentDiff:length() > 100 or part.currentDiff ~= part.currentDiff) then
								part.currentDiff = 0
							end
						end
						-- particles:newParticle("minecraft:end_rod",part.currentPos+part.currentDiff):lifetime(1)

					end
				end
			end
		end
	end
	module.render = function(dt)
		for physID,phys in pairs(module.physTypes) do
			if(not phys.disabled) then
				for pID,part in ipairs(phys.parts) do
					if(part.part:getVisible() and not part.disabled) then
						local x,y,z = part.part:getRot():unpack();
						if(x~=x or y~=y or z~=z) then
							part.part:setRot(0,0,0)
							part.lastDiff = vec(0,0,0)
							part.currentDiff = vec(0,0,0)
							part.currentPos:set(part.lastPos:set(part.partEnd:partToWorldMatrix():apply()):copy())
						end
						local physics = lerp(part.lastDiff,part.currentDiff,dt)
						part.part:setRot(emptyVec:set(physics):mul(phys.rotMultiplier):clamped(phys.clampRotMin,phys.clampRotMax):add(phys.baseRot))
						local scale = physics and type(physics) ~= "number" and physics:length() or 0
						part.part:setScale(emptyVec:set(1,1,1):add(vec(scale,-scale,scale):mul(phys.scaleMultiplier):clamped(phys.clampScaleMin,phys.clampScaleMax)))
					end
				end
			end
		end
	end
	events.world_render:register(function()
		if(ret) then ret = false return end
		for physID,phys in pairs(module.physTypes) do
			for pID,part in ipairs(phys.parts) do
				part.currentPos:set(part.partEnd:partToWorldMatrix():apply())
				part.lastPos:set(part.currentPos)
			end
		end
		events.world_render:remove('partphys.waitTick')
		events.tick:register(module.tick,'partphys.tick')
		events.post_render:register(module.render,'partphys.render')
	end,'partphys.waitTick')
end,'partphys.init')
_G.PARTPHYS = module

return module
