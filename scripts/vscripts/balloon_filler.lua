
local IN_USE_HAND0 = 24
local IN_USE_HAND1 = 25
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

local button = nil
local usingPlayer = nil
local balloon = nil
local scale = 0

local balloonKeyvals = {
	classname = "prop_destinations_physics";
	targetname = "balloon";
	--model = "models/props/toys/balloonicorn.vmdl";
	model = "models/props_gameplay/balloon001.vmdl";
	scales = "0.2 0.2 0.2";
	vscripts = "balloon_float";
	health = 5;
	angles = Vector(0, 180, 0);
	skin = "colorable"
}

function Precache(context)
	PrecacheEntityFromTable(balloonKeyvals.classname, ballonKeyvals, context)
	PrecacheModel(balloonKeyvals.model, context)
end

function OnPressed(params)

	if params.activator 
	then
		usingPlayer = params.activator
		scale = 0.2
				
		--[[for i = 0,63 do
			print(i .. ": " .. tostring(usingPlayer:IsVRControllerButtonPressed(i)))
		end ]]
				
		if usingPlayer:IsVRControllerButtonPressed(IN_USE_HAND0) 
			and usingPlayer:IsVRControllerButtonPressed(IN_USE_HAND1)
		then
			local hand0 = usingPlayer:GetHMDAvatar():GetVRHand(0)
			local hand1 = usingPlayer:GetHMDAvatar():GetVRHand(1)
			
			-- get the closest hand
			if (hand0:GetCenter() - thisEntity:GetCenter()):Length() <
				(hand0:GetCenter() - thisEntity:GetCenter()):Length()
			then
				button = IN_USE_HAND0
				
			else
				button = IN_USE_HAND1
			
			end
		
		elseif usingPlayer:IsVRControllerButtonPressed(IN_USE_HAND0) 
		then
			button = IN_USE_HAND0
		else 
			button = IN_USE_HAND1
		end
		
		balloonKeyvals.origin = thisEntity:GetCenter() + Vector(-3, 0, 6)
		balloonKeyvals.targetname = DoUniqueString("balloon")
		balloonKeyvals.rendercolor = COLOR_VALUES[RandomInt(1, 5)] .. " " .. COLOR_VALUES[RandomInt(1, 5)] .. 
			" " .. COLOR_VALUES[RandomInt(1, 5)] .. " 255"
		balloon = SpawnEntityFromTableSynchronous(balloonKeyvals.classname, balloonKeyvals)
		balloon:DisableMotion()
		StartSoundEvent("Balloon.Inflate", thisEntity)
		thisEntity:SetThink(FillThink, "fill", FILL_INTERVAL)
	end
end

function OnUnpressed(params)
	print("unpressed")
end

function FillThink()

	if usingPlayer:IsVRControllerButtonPressed(button) 
	then
		scale = scale + FILL_SPEED
	
		balloon:SetModelScale(scale)
		
		if scale < MAX_SCALE
		then
			return FILL_INTERVAL
		end
	end
		StopSoundEvent("Balloon.Inflate", thisEntity)
		balloon:GetPrivateScriptScope():EnableThink()
		balloon:EnableMotion()
		return nil

end