

local turnedOn = false
local lightEnt = nil
local controller = nil
local currentPlayer = nil
local handID = 0
local handAttachment = nil

local lightKeyvals = {
	classname = "light_spot";
	targetname = "flashlight_light";
	enabled = 0;
	color = "209 192 184 255";
	brightness = 3;
	range = 3000;
	indirectlight = 0;
	attenuation1 = 0.3;
	attenuation2 = 0;
	falloff = 10;
	innerconeangle = 10;
	outerconeangle = 20;
	castshadows = 1;
}

function Precache(context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end

function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	controller = pHand
	currentPlayer = pPlayer
	handAttachment = pHandAttachment
	
	print("SetEquipped")
	
	if lightEnt == nil
	then
		lightEnt = SpawnEntityFromTableSynchronous(lightKeyvals.classname, lightKeyvals)
		
	end	
	lightEnt:SetParent(handAttachment, "light")
	lightEnt:SetLocalOrigin(Vector(0,0,0))
	lightEnt:SetLocalAngles(0, 0, 0)
	
	if turnedOn
	then
		DoEntFireByInstanceHandle(handAttachment, "Skin", "1", 0 , nil, nil)
	end
	
	return true
end

function SetUnequipped()
	if lightEnt ~= nil 
	then
		lightEnt:SetParent(thisEntity, "light")
	end

	return true
end

function OnHandleInput(input)

	local nIN_TRIGGER = IN_USE_HAND1; if (handID == 0) then nIN_TRIGGER = IN_USE_HAND0 end;
	local nIN_GRIP = IN_GRIP_HAND1; if (handID == 0) then nIN_GRIP = IN_GRIP_HAND0 end;
	
	if input.buttonsPressed:IsBitSet(nIN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(nIN_TRIGGER)
		OnTriggerPressed(self)
	end
	
	-- Catch the unpress even, so you don't drop the tool.
	if input.buttonsReleased:IsBitSet(nIN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(nIN_TRIGGER)
	end
	
	if input.buttonsReleased:IsBitSet(nIN_GRIP)
	then
		input.buttonsReleased:ClearBit(nIN_GRIP)
		thisEntity:ForceDropTool();
	end

	return input;
end




function OnTriggerPressed(self)
	StartSoundEvent("Flashlight.Button", thisEntity)
	if turnedOn
	then
		turnedOn = false
		DoEntFireByInstanceHandle(handAttachment, "Skin", "0", 0 , nil, nil)
		DoEntFireByInstanceHandle(thisEntity, "Skin", "0", 0 , nil, nil)
		DoEntFireByInstanceHandle(lightEnt, "TurnOff", "", 0 , nil, nil)
	else
		turnedOn = true
		DoEntFireByInstanceHandle(handAttachment, "Skin", "1", 0 , nil, nil)
		DoEntFireByInstanceHandle(thisEntity, "Skin", "1", 0 , nil, nil)
		DoEntFireByInstanceHandle(lightEnt, "TurnOn", "", 0 , nil, nil)
	end
end
