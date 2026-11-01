-- A small Luau port of the browser prototype's elemental queue and spell selection.
local Rules = {}
Rules.MaxQueue = 2
Rules.Cooldown = {fire = 0.35, lightning = 0.85, stormfire = 1.25}
Rules.Range = {fire = 32, lightning = 58, stormfire = 47}
Rules.Damage = {fire = 32, lightning = 65, stormfire = 110}

function Rules.compile(queue)
	if type(queue) ~= "table" or #queue < 1 or #queue > Rules.MaxQueue then return nil end
	local fire, lightning = 0, 0
	for _, element in ipairs(queue) do
		if element == "fire" then fire += 1
		elseif element == "lightning" then lightning += 1
		else return nil end
	end
	if fire > 0 and lightning > 0 then return "stormfire" end
	if fire > 0 then return "fire" end
	return "lightning"
end

return Rules
