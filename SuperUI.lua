if not host:isHost() then return {} end
local SuperUI = {
	hud = models:newPart('SUPERUI','HUD')
}
if not models.hud then
	models:newPart('hud','HUD')
end



return SuperUI