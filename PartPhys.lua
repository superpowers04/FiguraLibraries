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

	changeScale=true,
	changeRot=true,
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
local get_rot,get_pos,get_scale = m.getOffsetRot, m.getOffsetPos, m.getOffsetScale
local set_rot,set_pos,set_scale = m.setOffsetRot, m.setOffsetPos, m.setOffsetScale



-- I swear this is for speed and not obfuscation
local vset,vadd,vsub,vmul,vlen,vcopy,vclamp,pvis = _v.set,_v.add,_v.sub,_v.mul,_v.length,_v.copy,_v.clamped,m.getVisible
local function vset(v1,v2,y,z) -- This should be faster than normal Figura because no vectors are created
	if(type(v2) == "Vector3") then
		v1.x,v1.y,v1.z=v2.x,v2.y,v2.z
		return vec
	end
	v1.x, v1.y, v1.z=v2,y,z
	return vec
end
local function vreset(v1) -- reset a vector
	v1.x, v1.y, v1.z=0,0,0
end
local function vnset(v1,x,y,z) -- set v1 to x,y,z
	v1.x, v1.y, v1.z=x,y,z
end
local function vvset(v1,v2) -- set v1 to v2
	v1.x, v1.y, v1.z=v2:unpack()
end
local function lerpv(a,b,t)
	return vadd(vmul((b - a),t),a)
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
	local recurse,getPartEnd
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

			if(name:sub(0,5) == "phys_") then
				local phys = self.physTypes[name:sub(6)]
				if(phys) then
					if(not phys.lookedForBones) then
						self.addPartToPhys(phys,v)
					end
				-- else
				-- 	-- print(name.. ' has no physpart!')
				end
			elseif(name:sub(0,5) == "col_") then
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
		for i,v in ipairs(module.colliders) do
			v.pos = v.part:partToWorldMatrix():apply()
		end
		local bodyYaw = player:getBodyYaw(delta)+90
		local sby,cby=sin(bodyYaw),cos(bodyYaw)
		for physID,phys in next, module.physTypes do
			if(not phys.disabled) then
				local horimult = phys.horizontalMultiplier
				local i = 0
				local cache = {}
				phys.cached_parts = cache
				for pID=1,#phys.parts do
					local part = phys.parts[pID]
					if(not part.disabled) then
						vvset(part.lastPos,part.currentPos)
						vvset(part.currentPos,mapp(ptwm(part.partEnd)))
						if(part.part:getVisible()) then
							local amm = (part.lastDiff-part.currentDiff)*phys.bounciness
							local diff = part.lastPos - part.currentPos
							part.lastDiff = part.currentDiff
							local cdiff = 
								vsub(
									vmul(vectors.rotateAroundAxis(bodyYaw, diff, _YONLY)
									,phys.horizontalMultiplier,0,phys.horizontalMultiplier)
								,amm)
							part.currentDiff = vadd(cdiff,diff.y*phys.verticalMultiplier,cdiff.z)
							if(vlen(cdiff) > 40 or cdiff.x ~= cdiff.x) then
								vset(part.currentDiff,0,0,0)
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
	local lastDT = 0
	module.render = function(dt)

		lastDT = dt
		for physID,phys in next, module.physTypes do
			if(not phys.disabled) then
				for pID=1,phys.cached_parts.n do
					local part = phys.cached_parts[pID]
					local physics = lerpv(part.lastDiff,part.currentDiff,dt)
					local scale = vlen(physics)
					
					set_rot(part.part,vadd(vclamp(vmul(physics,phys.rotMultiplier),phys.clampRotMin,phys.clampRotMax),phys.baseRot))

					vnset(physics,1,1,1)
					vnset(emptyVec,scale,-scale,scale)
					set_scale(part.part,vadd(physics,vclamp(vmul(emptyVec,phys.scaleMultiplier),phys.clampScaleMin,phys.clampScaleMax)))
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
		-- events.post_render:register(module.render,'partphys.render')
		events.render:register(module.render,'partphys.render')
		events.world_render:register(module.render,'partphys.render')
	end,'partphys.waitTick')
end
events.entity_init:register(module.init,'partphys.init')
_G.PARTPHYS = module

return module