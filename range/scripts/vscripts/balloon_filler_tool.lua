
local FILL_INTERVAL = 0.02
local FILL_SPEED = 0.02
local MAX_SCALE = 4

local COLOR_VALUES = 
{
	0,
	64,
	128,
	192,
	255
}

local balloon = nil
local scale = 0

local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local parentAngle = QAngle(0,0,0)

local isUsing = false

local balloonKeyvals = {
	classname = "prop_destinations_physics";
	targetname = "balloon";
	--model = "models/props/toys/balloonicorn.vmdl";
	model = "models/props_gameplay/balloon001.vmdl";
	scales = "0.2 0.2 0.2";
	vscripts = "balloon_float";
	health = 5;
	angles = Vector(0, 180, 0);
	skin = "colorable";
}

function Precache(context)
	PrecacheEntityFromTable(balloonKeyvals.classname, ballonKeyvals, context)
	PrecacheModel(balloonKeyvals.model, context)
end



function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	parentAngle = thisEntity:GetMoveParent():GetAngles()
	
	handAttachment:AddEffects(32)
	isUsing = true
	
	scale = 0.2
	
	balloonKeyvals.origin = thisEntity:GetCenter() + Vector(-1.68, 0, 0.5)
	balloonKeyvals.targetname = DoUniqueString("balloon")
	balloonKeyvals.rendercolor = COLOR_VALUES[RandomInt(1, 5)] .. " " .. COLOR_VALUES[RandomInt(1, 5)] .. 
		" " .. COLOR_VALUES[RandomInt(1, 5)] .. " 255"
	balloon = SpawnEntityFromTableSynchronous(balloonKeyvals.classname, balloonKeyvals)
	balloon:DisableMotion()
	StartSoundEvent("Balloon.Inflate", balloon)
	thisEntity:SetThink(FillThink, "fill", FILL_INTERVAL)
	
	return true
end

function SetUnequipped()
	handAttachment = nil
	
	isUsing = false
	thisEntity:SetThink(Release, "release_delay", 0.1)
	thisEntity:SetAbsOrigin(Vector(-10000, -10000, -10000))
	thisEntity:SetLocalAngles(parentAngle.x, parentAngle.y, parentAngle.z)

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

	return input;
end

function Release()
	thisEntity:SetLocalOrigin(Vector(0,0,0))
	thisEntity:SetLocalAngles(parentAngle.x, parentAngle.y, parentAngle.z)
end




function FillThink()

	if isUsing
	then
		scale = scale + FILL_SPEED
	
		balloon:SetModelScale(scale)
		
		if scale < MAX_SCALE
		then
			return FILL_INTERVAL
		end
	end
		StopSoundEvent("Balloon.Inflate", balloon)
		balloon:GetPrivateScriptScope():EnableThink()
		balloon:EnableMotion()
		return nil

end