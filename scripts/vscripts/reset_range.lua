
local barrels = {} 

function Store()
	local barrelEnt = Entities:FindByName(nil, "barrel")
	
	while barrelEnt
	do
		barrels[barrelEnt] = {origin = barrelEnt:GetOrigin(); angles = barrelEnt:GetAngles()} 
		
		barrelEnt = Entities:FindByName(barrelEnt, "barrel")
	end
end


function Reset()
	local barrelEnt = Entities:FindByName(nil, "barrel")
	while barrelEnt
	do
		barrelEnt:SetOrigin(barrels[barrelEnt].origin)
		local angles = barrels[barrelEnt].angles
		barrelEnt:SetAngles(angles.x, angles.y, angles.z)
		
		barrelEnt = Entities:FindByName(barrelEnt, "barrel")
	end
	
	DoEntFire("target", "SetAnimation", "reset", 0, nil, nil)
	DoEntFire("target", "SetDefaultAnimation", "idle", 0, nil, nil)
end