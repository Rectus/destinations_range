
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
	thisEntity:Kill()

	return true
end

function OnHandleInput(input)

	local nIN_TRIGGER = IN_USE_HAND1; if (handID == 0) then nIN_TRIGGER = IN_USE_HAND0 end;
	local nIN_GRIP = IN_GRIP_HAND1; if (handID == 0) then nIN_GRIP = IN_GRIP_HAND0 end;
	
	if input.buttonsPressed:IsBitSet(nIN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(nIN_TRIGGER)

	end
	
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