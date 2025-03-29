local Shared = {
	root = models.model.root,

}
_G.Shared = Shared


Shared.nameplate = {
	outline_color = vec(0.2,0,0.3),
	background_color = vec(0.4,0.05,0,0.1),
	text={
		text="Steph",color="#AA44BB",
		hoverEvent={action="show_text",contents={
				{text="superpowers04\n"},
				{text="- She/Her\n",color="#ffaaff"},
			}
		}
	}
}
function Shared.updateNameplate(self)
	nameplate.ALL:setText(toJson(self.nameplate.text))
	nameplate.entity:setOutline(true):setOutlineColor(self.nameplate.outline_color):setBackgroundColor(self.nameplate.background_color)
end
function Shared.intToBools(...)
	local bits = table.pack(...)
	local returnBools = {}
	for index,number in ipairs(bits) do
		for i = 0,31 do
			returnBools[#returnBools+1] = (bit32.extract(number,i) == 1)
		end
	end
	return returnBools
end
function Shared.boolsToInt(...)
	local ints = table.pack(...)
	local bits = {0}
	for i,v in ipairs(ints) do
		local index = math.floor(i / 31) + 1;
		bits[index] = bit32.replace(bits[index] or 0,v and 1 or 0,i - 1)
	end
	return bits
end
function Shared.textureMask(text,text2,section,opague)
	local left,top,right,bottom
	if(section) then
		left,right = section[1],section[3] - 1
		top,bottom=section[2],section[4] - 1

	else
		left,top,right,bottom = 0,0,text:getDimensions():sub(1,1):unpack()
	end
	local w,h = text2:getDimensions():unpack()

	local lerp = math.lerp
	if(opague) then
		if(opague ~= true) then

			-- for x=left,left+right do
			-- 	for y=top,top+bottom do
			-- 		-- print(x,y)
			-- 		local pixel, pixel2 = text:getPixel(x,y), text2:getPixel(x%w,y%h);
			-- 		if(pixel.a > 0 and pixel2.a > 0.1) then
			-- 			-- pixel:set(pixel2)
			-- 			-- pixel.a=0 
			-- 			text:setPixel(x,y,math.lerp(pixel,opaque,pixel2.a))
			-- 		end
			-- 	end
			-- end
			text:applyFunc(left,top,right,bottom,function(pixel,x,y)
				local pixel2 = text2:getPixel(x%w,y%h)
				if(pixel.a > 0 and pixel2.a > 0.1) then
						-- pixel:set(pixel2)
						-- pixel.a=0 
					return math.lerp(pixel,opaque,pixel2.a)
				end
			end)

		else

			text:applyFunc(left,top,right,bottom,function(pixel,x,y)
				local pixel2 = text2:getPixel(x%w,y%h)
				if(pixel.a > 0 and pixel2.a > 0.5) then
						-- pixel:set(pixel2)
					pixel.a=0 
					return pixel
				end
			end)

		end
	else
		text:applyFunc(left,top,right,bottom,function(pixel,x,y)
			local pixel2 = text2:getPixel(x%w,y%h);
			if(pixel.a > 0 and pixel2.a > 0.1) then
				-- pixel:set(pixel2)
				pixel.a=pixel2:length() 
				return pixel
			end
		end)
	end
	text:update()
end
return Shared