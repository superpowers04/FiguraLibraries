local SIMPSKIP


local module = {
	hasInitted = false,
	physTypes={},
	colliders={},
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
	posMultiplier=0,
	customMultiplierFunc=nil, -- (phys, part) -> nil, Useful if you want to have a variable rot multiplier

	-- changeScale=true, -- Deprecated, set scaleMultiplier to 0
	-- changeRot=true, -- Deprecated, set rotMultiplier to 0
	collidable=true,
	colliderSize=3,

	-- clampMax=vec(3,3,3),
	-- clampMin=vec(-3,-3,-3),
	clampMax=3,
	clampMin=-3,
	clampRotMax=50,
	clampRotMin=-50,
	clampScaleMax=0.5,
	clampScaleMin=-0.5,
	clampPosMax=1,
	clampPosMin=-1,


	lookedForBones=false,
	parts=nil
}
local partDefaults = {
	lastPos=vec(0,-1000,0),
	nextPos=vec(0,-1000,0),
	baseRot=vec(0,0,0),
	currentDiff=0,
	lastDiff=0,
	phys = nil,
	part = nil,
	partEnd = nil,
	disabled = false,
	mt={}
}
partDefaults.mt.__index=partDefaults
local _v = vec(0,0,0)
local vec3 = vectors.vec3
local clamp,lerp,abs,emptyVec,m,cos,sin = math.clamp, math.lerp, math.abs, _v, models, math.cos, math.sin
local c = clamp

local _XONLY,_YONLY,_ZONLY = vec3(1, 0, 0),vec3(0, 1, 0),vec3(0, 0, 1)

-- Change these to change which property gets edited for a part
local get_rot,get_pos,get_scale = m.getOffsetRot, m.getOffsetPivot, m.getOffsetScale
local set_rot,set_pos,set_scale = m.setOffsetRot, m.setOffsetPivot, m.setOffsetScale



-- I swear this is for speed and not obfuscation
local vset,vadd,vsub,vmul,vlen,vcopy,vclamp,pvis = _v.set,_v.add,_v.sub,_v.mul,_v.length,_v.copy,_v.clamped,m.getVisible
local function lerpv(a,b,t)
	return (b - a):mul(t):add(a)
end
local pab = function(...) 
	local a = {}
	for i,v in pairs({...}) do
		a[i] = tostring(v)
	end
	host:setActionbar(table.concat(a,'    '))
end

local ptwm,mapp = m.partToWorldMatrix,m:partToWorldMatrix().apply

function module.fillPhys(phys)
	assert(phys,'attempt to add nil value as phys part')
	assert(phys.name,'attempt to add phys part without name')
	for i,v in pairs(defaults) do
		if(phys[i] == nil) then
			phys[i] = v
		end
	end
	phys.addPartToPhys = module.addPartToPhys
	local oldParts = phys.parts
	phys.parts = {}
	phys.cached_parts = {n=0}
	if(oldParts ~= nil) then 
		for i,part in pairs(oldParts) do
			self.addPartToPhys(phys,part)
		end
	end
end
function partDefaults.toggle(phys,bool)
	assert(type(phys) == 'table' and phys.part,'attempt to toggle '..type(phys)..' value(expected physPart)')
	if(bool ~= nil) then
		phys.disabled = bool
	else
		phys.disabled = not phys.disabled
	end
	if(phys.disabled) then
		set_scale(set_rot(phys.part))
		-- (phys.useOffset and phys.part:setOffsetRot() or phys.part:setOffsetRot()):setScale()
	else
		phys.lastPos=vcopy(partDefaults.lastPos)
		phys.currentPos=vcopy(partDefaults.nextPos)
		phys.currentDiff=partDefaults.currentDiff
		phys.lastDiff=partDefaults.lastDiff
	end
end


-- local function profile(a,b)
-- 	local inst = avatar:getCurrentInstructions()
-- 	a()
-- 	a=avatar:getCurrentInstructions()-inst-3
-- 	local inst = avatar:getCurrentInstructions()
-- 	b()
-- 	b=avatar:getCurrentInstructions()-inst-3
-- 	pab(a,b,a-b)
-- end

function module.addPartToPhys(phys, part, part_end)
	assert(type(phys) == 'table','attempt to add part to '..type(phys)..' value(expected phys)')
	assert(type(part):lower():find('part') or type(part):lower():find('task'),'attempt to add '..type(part)..' to phys value(expected ModelPart)')
	-- assert(phys,'attempt to add nil value to phys(expected model part)')

	if(part_end == nil) then
		local recurse
		function recurse(part)
			for i,v in ipairs(part:getChildren()) do
				if(v:getName():sub(0,3) == "end") then
					part_end = v
					return true
				end
				if(recurse(v)) then return true end
			end
		end
		recurse(part)
	end
	local part_info = setmetatable({
		lastPos=partDefaults.lastPos:copy(),
		currentPos=vec3(0,-1000,0),
		currentDiff=vec3(0,0,0),
		lastDiff=vec3(0,0,0),
		phys=phys,
		part=part,
		partEnd=part_end
	},partDefaults.mt)
	phys.parts[#phys.parts+1] = part_info
	return part_info
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
	local function getPartEnd(part)
		for i,v in ipairs(part:getChildren()) do
			if(v:getName():sub(0,3) == "end") then
				return v
			end
		end
	end
	local function recurse(part)
		for i,v in ipairs(part:getChildren()) do
			local name = v:getName()
			local type = name:sub(0,5)

			if(type == "phys_") then
				local phys = self.physTypes[name:sub(6)]
				if(phys) then
					if(not phys.lookedForBones) then
						self.addPartToPhys(phys,v)
					end
				-- else
				-- 	-- print(name.. ' has no physpart!')
				end
			elseif(type == "col_") then
				local type,num = name:match('_(.-)(%d+)')
				module.colliders[#modules.colliders+1] = {
					part=v,
					size=num,type=type
				}
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

-- local particle = particles:newParticle("minecraft:end_rod")

module.init = function()
	-- function recurse(part)
	-- 	for i,v in pairs(part:getChildren()) do
	-- 		local name = v:getName()

	-- 		if(name:sub(0,5) == "col_") then
	-- 			local type,num = name:match('_(.-)(%d+)')
	-- 			module.colliders[#modules.colliders+1] = {
	-- 				part=v,
	-- 				size=num,type=type
	-- 			}
	-- 		end
	-- 		recurse(v)
			
	-- 	end
	-- end
	-- recurse(models)
	module:addPhysType(nil,true)
	local ret = true
	local player = player
	local next = next
	module.tick = function()
		local bodyYaw = player:getBodyYaw()+90
		for physID,phys in next, module.physTypes do
			if(not phys.disabled) then
				local horimult = phys.horizontalMultiplier
				local i = 0
				local cache = {}
				phys.cached_parts = cache
				for pID=1,#phys.parts do
					local part = phys.parts[pID]
					if(not part.disabled) then
						part.lastPos:set(part.currentPos)
						part.currentPos:set(mapp(ptwm(part.partEnd)))
						if(part.part:getVisible()) then
							local amm = (part.lastDiff-part.currentDiff):mul(phys.bounciness)
							local diff = (part.lastPos - part.currentPos)
							part.lastDiff = part.currentDiff
							-- diff:set(dx * sby - dz * cby,diff.y,dx * cby + dz * sby) -- leaving this here because this uses more instructions but should be faster
							local cdiff = vectors.rotateAroundAxis(bodyYaw, diff, _YONLY):mul(phys.horizontalMultiplier,0,phys.horizontalMultiplier):sub(amm)
							part.currentDiff = cdiff:add(diff.y*phys.verticalMultiplier,cdiff.z)
							if(cdiff:length() > 40 or cdiff.x ~= cdiff.x) then
								part.currentDiff:set(0,0,0)
							end
							-- This is a bit jank but we don't need to lerp anything if the part hasn't moved
							if(part.lastDiff~=part.currentDiff) then
								i=i+1
								cache[i]=part
							end
						end

					end
				end
				cache.n=i
			end
		end
	end
	module.render = function(dt)
		for physID,phys in next, module.physTypes do
			if(not phys.disabled) then
				for pID=1,phys.cached_parts.n do
					local part = phys.cached_parts[pID]
					local physics = lerp(part.lastDiff,part.currentDiff,dt)
					local scale = physics:length()
					if(phys.customMultFunc) then
						phys:customMultFunc(part)
					end
					if(phys.rotMultiplier ~= 0) then
						set_rot(part.part,physics:mul(phys.rotMultiplier):clamped(phys.clampRotMin,phys.clampRotMax):add(phys.baseRot))
					end
					if(phys.scaleMultiplier ~= 0) then
						set_scale(part.part,emptyVec
								:set(scale,-scale,scale)
								:mul(phys.scaleMultiplier)
								:clamped(phys.clampScaleMin,phys.clampScaleMax)
								:add(1,1,1)
						)
					end
					if(phys.posMultiplier ~= 0) then
						set_pos(part.part,emptyVec
								:set(scale,scale,scale)
								:mul(phys.posMultiplier)
								:clamped(phys.clampPosMin,phys.clampPosMax)
						)

					end
				end
			end
		end
	end
	events.world_render:register(function()
		if(ret) then -- Buffer for a frame
			ret = false 
			return
		end
		for physID,phys in pairs(module.physTypes) do
			for pID,part in ipairs(phys.parts) do
				part.currentPos:set(mapp(ptwm(part.partEnd)))
				part.lastPos:set(part.currentPos)
			end
		end
		events.world_render:remove('partphys.waitTick')
		events.tick:register(module.tick,'partphys.tick')
		-- events.post_render:register(module.render,'partphys.render')
		events.render:register(module.render,'partphys.render')
		events.world_render:register(module.render,'partphys.render')
	end,'partphys.waitTick')
end
events.entity_init:register(module.init,'partphys.init')
_G.PARTPHYS = module

return module