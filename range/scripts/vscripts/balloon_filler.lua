
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

local hand = nil
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

		if not g_VRScript.pauseManager:IsPlayerAllowedToSpawnItems(params.activator) then
			return
		end

		usingPlayer = params.activator
		scale = 0.2
				
		--[[for i = 0,63 do
			print(i .. ": " .. tostring(usingPlayer:IsVRControllerButtonPressed(i)))
		end ]]

		if usingPlayer:IsActionActiveForHand(0, DEFAULT_USE)
			and usingPlayer:IsActionActiveForHand(1, DEFAULT_USE)
		then
			local hand0 = usingPlayer:GetHMDAvatar():GetVRHand(0)
			local hand1 = usingPlayer:GetHMDAvatar():GetVRHand(1)
			
			-- get the closest hand
			if (hand0:GetCenter() - thisEntity:GetAbsOrigin()):Length() <
				(hand0:GetCenter() - thisEntity:GetAbsOrigin()):Length()
			then
				hand = 0
				
			else
				hand = 1		
			end
		
		elseif usingPlayer:IsActionActiveForHand(0, DEFAULT_USE) 
		then
			hand = 0
		else 
			hand = 1
		end
		
		balloonKeyvals.origin = thisEntity:GetCenter() + Vector(-3, 0, 5.5)
		balloonKeyvals.targetname = DoUniqueString("balloon")
		balloonKeyvals.rendercolor = COLOR_VALUES[RandomInt(1, 5)] .. " " .. COLOR_VALUES[RandomInt(1, 5)] .. 
			" " .. COLOR_VALUES[RandomInt(1, 5)] .. " 255"
		balloon = SpawnEntityFromTableSynchronous(balloonKeyvals.classname, balloonKeyvals)
		balloon:DisableMotion()
		StartSoundEvent("Balloon.Inflate", thisEntity)
		thisEntity:SetThink(FillThink, "fill", FILL_INTERVAL)
	end
end

-- This does not track whether the player is still actually pressing the button.
function OnUnpressed(params)
	
end

function FillThink()

	if usingPlayer:IsActionActiveForHand(hand, DEFAULT_USE) 
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