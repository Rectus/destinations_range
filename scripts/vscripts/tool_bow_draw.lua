
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil

local isPulling = false



function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	
	handAttachment:AddEffects(32)
	isPulling = true
	
	return true
end

function SetUnequipped()
	handAttachment = nil
	
	isPulling = false
	thisEntity:SetThink(Release, "release_delay", 0.1)
	thisEntity:SetAbsOrigin(Vector(-100000, -100000, -100000))
	thisEntity:SetLocalAngles(0, 0, 0)

	return true
end

function OnHandleInput(input)

	local nIN_TRIGGER = IN_USE_HAND1; if (handID == 0) then nIN_TRIGGER = IN_USE_HAND0 end;
	local nIN_GRIP = IN_GRIP_HAND1; if (handID == 0) then nIN_GRIP = IN_GRIP_HAND0 end;
	
	if input.buttonsPressed:IsBitSet(nIN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(nIN_TRIGGER)

	end
	
	-- Catch the unpress event, so you don't drop the tool.
	if input.buttonsReleased:IsBitSet(nIN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(nIN_TRIGGER)
		thisEntity:ForceDropTool();
		
	end
	
	--[[if input.buttonsReleased:IsBitSet(nIN_GRIP)
	then
		input.buttonsReleased:ClearBit(nIN_GRIP)
		thisEntity:ForceDropTool();
	end]]

	return input;
end

function Release()
	thisEntity:SetLocalOrigin(Vector(0,0,0))
	thisEntity:SetLocalAngles(0, 0, 0)
end


function GetToolOrigin()
	if handAttachment
	then
		return handAttachment:GetAbsOrigin()
	end
	return thisEntity:GetAbsOrigin()
end


function IsPulling()
	return isPulling
end