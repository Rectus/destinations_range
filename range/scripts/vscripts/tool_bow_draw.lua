
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil

local isPulling = false



function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
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
	local nIN_PAD_TOUCH = IN_PAD_TOUCH_HAND1; if (handID == 0) then nIN_GRIP = IN_PAD_TOUCH_HAND0 end;
	
	
	if input.buttonsReleased:IsBitSet(nIN_TRIGGER) 
	then
		thisEntity:ForceDropTool();
		
	end
	
	if input.buttonsReleased:IsBitSet(nIN_GRIP)
	then
		thisEntity:ForceDropTool();
	end

	if playerEnt:GetVRControllerType() == VR_CONTROLLER_TYPE_KNUCKLES
	then
	
		if input.buttonsReleased:IsBitSet(nIN_PAD_TOUCH)
		then
			thisEntity:ForceDropTool();
		end
	
	end

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