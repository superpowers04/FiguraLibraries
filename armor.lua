local SIMPSKIP
local vec3 = vectors.vec3
local armor = {
	def={}
}

local colors = {
	['netherite'] = vec3(0.4,0.3,0.4),
	['diamond'] = vec3(0,0.7,0.8),
	['leather'] = vec3(0.9,0.6,0.4),
	['gold'] = vec3(0.7,0.6,0.2),
	['iron'] = vec3(1,1,1),
	['chainmail'] = vec3(0.5,0.5,0.5),
	['def'] = vec3(1,1,1),
}
local materialToArmor={
	golden = "gold"
}

local currentArmor = {modelParts={}}
local init = false
local armorParts = {}
local floor = math.floor
local Shared = require('libs.Shared')
armorIntegrity = 0
local function findArmor(bone,level,parentName)
	if(level == nil) then level = 0 end
	for i,v in pairs(bone:getChildren()) do
		if(level > 1 and v.getName and v:getName():lower():match("armor_.+__.+")) then
			local armorType,name = v:getName():lower():match("armor_(.+)__(.+)")
			if(not armorParts[armorType]) then armorParts[armorType] = {} end
			table.insert(armorParts[armorType],v:setVisible(false))
 		elseif(v.getChildren and v.getName) then
 			findArmor(v,level + 1)
		end
	end
end	
findArmor(models.model.root,1)
function updateArmor()
	local armorAtlas = {
		"","","","boots",'leggings','chestplate','helmet'
	}
	for i,v in pairs(currentArmor.modelParts) do
		v:setVisible(false)
	end
	local anyArmorVisible = false
	armorIntegrity = 0
	for i=3,6 do
		local item = player:getItem(i);

		
		local id = item.id
		currentArmor[i] = item:toStackString()

		if(id and id ~= "minecraft:air") then
			if(id:find(':.-_')) then
				-- Color
				local itemColor = vec(1,1,1)
				local tag = item:getTag()
				if(tag and tag.display and tag.display.color) then
					pcall(function()
						local cs = ('%x'):format(tag.display.color)
						itemColor = vec3(
							tonumber(cs:sub(1,2),16) / 256,
							tonumber(cs:sub(3,4),16) / 256,
							tonumber(cs:sub(5,6),16) / 256
						
						)
					end)
				end
				-- Texture
				local namespace,material,_type = id:match('^(.-):(.+)_(.-)$')
				if(materialToArmor[material]) then material = materialToArmor[material] end
				local texture
				local textureLocations = {
					'minecraft:textures/models/armor/%2%_layer_%3%.png','%1%:textures/models/armor/%2%_layer_%3%.png',
					'minecraft:textures/models/armor/%2%_%3%.png','%1%:textures/models/armor/%2%_%3%.png',
					'minecraft:textures/armor/%2%_layer_%3%.png','%1%:textures/armor/%2%_layer_%3%.png',
					'minecraft:textures/armor/%2%_%3%.png','%1%:textures/armor/%2%_%3%.png',
				}
				local yourMother = {namespace,material,(_type == "leggings" and "2" or "1")}
				for i,v in ipairs(textureLocations) do
					local location = v:gsub('%%(%d+)%%',function(a) return yourMother[tonumber(a)] end)
					if(type(location) == "string" and type(_type) == "string") then
						texture = textures:fromVanilla(_type,location)
						if texture and texture:getDimensions().x > 16 then
							break
						end
					end
				end

				if texture and texture:getDimensions().x > 16 then
					
					local material = material and material:lower();
					local itemType = _type and _type:lower();
					local enchanted = item:hasGlint();

					if(armorParts[_type]) then
						if(item:isDamageable() and not LIMITED_MODE) then
							local maxDmg = item:getMaxDamage()
							local damage = item:getDamage()
							local dmg = (item:getDamage()/maxDmg);
							-- damageTexture(texture,{{0,0,64,32}},damage - 0.2)
							if(dmg > 0.1) then
								Shared.textureMask(texture,textures:fromVanilla('DAMAGE',('textures/block/destroy_stage_'..floor(dmg*10))..'.png'),nil,true)
							end
							if(_type == "chestplate") then
								armorIntegrity = material == "chain" and 0 or ((maxDmg - damage) / maxDmg)
							end
						end
						anyArmorVisible = true
						for i,v in pairs(armorParts[_type]) do
							
							table.insert(currentArmor.modelParts,v)
							
							-- print(file)

							v:setVisible(true):setColor(itemColor):setPrimaryTexture('custom',texture):setSecondaryRenderType(enchanted and "GLINT" or "NONE"):setColor(itemColor)
						end
					end
				end
			end
		end
	end
	-- clothing.updateBreasts()
end
events.ENTITY_INIT = updateArmor
function events.TICK()
	for i=3,6 do
		if(currentArmor[i] ~= player:getItem(i):toStackString()) then
			updateArmor()
			break
		end
	end
end