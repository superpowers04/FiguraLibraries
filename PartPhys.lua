--[[ PartPhys, A really bad physics library made by Superpowers04 because I couldn't find any other physics libraries with scaling
	Example usage:
	```lua
	PHYS = {
	    boobs={verticalMultiplier=0.7,horizontalMultiplier=1},
	    hair={scaleMultiplier=vec(0.01,0.01,0.01),bounciness=0.25},
	    haircube={horizontalMultiplier=-0.2,verticalMultiplier=0.2},
	}

	PartPhys = require('libs.PartPhys')
	PartPhys:addPhysType(PHYS,false)

	local rootBody = models.model.root.rootBody

	PartPhys.addPartToPhys(PHYS.boobs,rootBody.Body.boob,rootBody.Body.boob._end)
	PartPhys.addPartToPhys(PHYS.hair,rootBody.Head.HairFront,rootBody.Head.HairFront._end)
	```
	* All parts registered need an `_end` part at the tip of the part
	* If you require or run PartPhys AFTER entity_init, you will need to run `PartPhys:init()`
	* You can run `events.event_init:remove('partphys.init')` if you don't want it to immediately initialise itself in entity_init
	* Check the `defaults` table inside of the script for a list of default values that can be changed per Phys
	*  addPartToPhys expects the "Phys", the root bone and the end of the root bone, The root bone should have a pivot from where you want the part to rotate from and the end of the bone should be the tip of the bone. Note you need to edit the pivot points using the pivot tool, NOT the placement of the bone itself. You will probably need to play around with it a little for it to work properly
	* Before adding a part to a phys, you HAVE to run addPhysType as it initialises some important variables
	Ex:
	```lua
	local hair_phys = PartPhys:addPhysType({bounciness=0.25}) -- This modifies the table but also returns it so you can either run the function on the table seperately or run it like this
	local hair_part = models.model.root.head.hair
	hair_phys:addPartToPhys(hair_part,hair_part._end) -- If you have the end part named `end`, you have to use ["end"] due to lua thinking that you're trying to end a `for`, `if`, etc block

	hair_phys.scaleMultiplier=vec(0.01,0.01,0.01) -- Also you can modify multipliers and the such after you register a phys or add a part to it
	```
	



--]] 


local module = {
	use_math_clamp=true, -- If true, this'll basically use math.clamp instead of vec:clampLength. vec:clamped is a shorthand for vec:clampLength

	-- Init variables
	hasInitted = false,
	physTypes={
	},
	-- Do not mess with this!
	__PHYSTYPES_CACHE={},
	__PHYSTYPES_COUNT=0,
	colliders={},
	debug=false,
}
local defaults = {
	-- The name used.
	name="default",
	-- These are the defaults applied to anything passed into addPhysType.
	bounciness=0.5, -- How "bouncy" the phys is

	-- How much horizontal velocity affects the phys
	horizontalMultiplier=2, 
	-- How much vertical velocity affects the phys
	verticalMultiplier=1, 
	-- The multiplier used for rotation. Can be a vector or a number. Supply 0 to disable entirely
	rotMultiplier=vec(20,20,20), 
	-- The multiplier used for scale. Can be a vector or a number. Supply 0 to disable entirely
	scaleMultiplier=vec(0.1,0.1,0.1), 
	-- The multiplier used for position. Can be a vector or a number. Supply 0 to disable entirely. USES SETPOS, WHICH MIGHT BREAK THINGS
	posMultiplier=0,
	customMultiplierFunc=nil, -- (phys, part) -> nil, Useful if you want to have a variable rot multiplier
	customTickFunc=nil, -- (phys, part) -> nil, Useful if you want to do something to every part on tick

	-- changeScale=true, -- Deprecated, set scaleMultiplier to 0
	-- changeRot=true, -- Deprecated, set rotMultiplier to 0
	-- collidable=true, -- Not implemented yet
	-- colliderSize=3,

	-- If use_math_clamp is true then a vector or number can be supplied, else only a number can be supplied. 
	--  If you supply anything other than a vector or number, you will probably get an error and I'm too lazy to sacrifice performance for the 2 of you that supply a string for some reason
	clampMax=3, -- The maximum for a phys per tick. Across rotation, scale and position before multipliers
	clampMin=-3, -- The minimum for a phys per tick. Across rotation, scale and position before multipliers
	clampRotMax=50, -- The maximum for rotation, includes respective multiplier
	clampRotMin=-50, -- The minimum for rotation, includes respective multiplier
	clampScaleMax=0.5, -- The maximum for scale, includes respective multiplier
	clampScaleMin=-0.5, -- The minimum for scale, includes respective multiplier
	clampPosMax=1, -- The maximum for position, includes respective multiplier
	clampPosMin=-1, -- The minimum for position, includes respective multiplier


	disabled = false, -- If true, no physics will be applied

	-- Init variables, should not be tampered with
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
local clamp_vec


local _XONLY,_YONLY,_ZONLY = vec3(1, 0, 0),vec3(0, 1, 0),vec3(0, 0, 1)

-- Change these to change which property gets edited for a part
local get_rot,get_pos,get_scale = m.getOffsetRot, m.getPos, m.getOffsetScale
local set_rot,set_pos,set_scale = m.setOffsetRot, m.setPos, m.setOffsetScale



-- I swear this is for speed and not obfuscation
local vset,vadd,vsub,vmul,vlen,vcopy,vclamp,pvis = _v.set,_v.add,_v.sub,_v.mul,_v.length,_v.copy,_v.clamped,m.getVisible
-- local function lerpv(a,b,t)
-- 	return (b - a):mul(t):add(a)
-- end
-- local pab = function(...) 
-- 	local a = {}
-- 	for i,v in pairs({...}) do
-- 		a[i] = tostring(v)
-- 	end
-- 	host:setActionbar(table.concat(a,'    '))
-- end

local ptwm,mapp = m.partToWorldMatrix,m:partToWorldMatrix().apply

setmetatable(module.physTypes,{__newindex=function(self,key,value)
	local oldValue = self[key]
	rawset(self,key,value)
	local __CACHE,__COUNT = module.__PHYSTYPES_CACHE,module.__PHYSTYPES_COUNT
	if(oldValue ~= nil) then
		for i=0,#__CACHE do
			if(__CACHE[i]==oldValue) then
				table.remove(__CACHE,i)
				if value then 
					module.__PHYSTYPES_COUNT = __COUNT-1
				else 
					__CACHE[__COUNT]=value
				end
				return
			end
		end
		return
	end
	if value==nil then return end
	__COUNT = __COUNT+1
	module.__PHYSTYPES_COUNT = __COUNT
	__CACHE[__COUNT] = value

end})

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

	if(module.use_math_clamp) then
		clamp_vec = function(a,x2,x3) -- This is how I thought clamped worked :c_:
			local x,y,z = a:unpack()
			local y2,z2, y3,z3 = x2,x2, x3,x3

			if(type(x2) ~= "number") then
				x2,y2,z2 = x2:unpack()
			end
			if(type(x3) ~= "number") then
				x3,y3,z3 = x3:unpack()
			end
			return a:set(clamp(x,x2,x3),clamp(y,y2,y3),clamp(z,z2,z3))
		end
	else
		clamp_vec = emptyVec.clampLength
	end
	module:addPhysType(nil,true)
	local ret = true
	local player = player
	local next = next
	module.tick = function()
		local bodyYaw = player:getBodyYaw()+90
		local phystypes = module.__PHYSTYPES_CACHE
		for cid=1,module.__PHYSTYPES_COUNT do
			local phys = phystypes[cid]
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
							if(phys.customTickFunc) then
								phys:customTickFunc(part)
							end
						end

					end
				end
				cache.n=i
			end
		end
	end
	module.render = function(dt)
		local phystypes = module.__PHYSTYPES_CACHE
		for cid=1,module.__PHYSTYPES_COUNT do
			local phys = phystypes[cid]
			if(not phys.disabled) then
				for pID=1,phys.cached_parts.n do
					local part = phys.cached_parts[pID]
					local physics = lerp(part.lastDiff,part.currentDiff,dt)
					local scale = physics:length()
					if(phys.customMultFunc) then
						phys:customMultFunc(part)
					end
					if(phys.rotMultiplier ~= 0) then
						set_rot(part.part,clamp_vec(physics:mul(phys.rotMultiplier),phys.clampRotMin,phys.clampRotMax):add(phys.baseRot))
					end
					if(phys.scaleMultiplier ~= 0) then
						set_scale(part.part,clamp_vec(emptyVec
									:set(scale,-scale,scale)
									:mul(phys.scaleMultiplier),phys.clampScaleMin,phys.clampScaleMax)
								:add(1,1,1)
						)
					end
					if(phys.posMultiplier ~= 0) then
						set_pos(part.part,clamp_vec(emptyVec
								:set(scale,scale,scale)
								:mul(phys.posMultiplier),phys.clampPosMin,phys.clampPosMax)
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
		local phystypes = module.__PHYSTYPES_CACHE
		for cid=1,module.__PHYSTYPES_COUNT do
			local phys = phystypes[cid]
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