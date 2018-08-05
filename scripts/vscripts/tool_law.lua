
--[[
	M72 LAW rocket launcer script.
	
	Copyright (c) 2016 Rectus
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
]]--

local FIRE_RUMBLE_INTERVAL = 0.02
local FIRE_RUMBLE_TIME = 0.4
local ROCKET_OFFSET = Vector(30, 0, 0)
local PICKUP_FIRE_DELAY = 0.5

local isCarried = false
local pickupTime = 0
local playerEnt = nil
local controller = nil
local handID = 0
local handAttachment = nil
local alreadyPickedUp = false
local loadedRocket = nil
local rocket = nil
local fired = false
local fireRumbleElapsed = 0

local rocketKeyvals = 
{
	targetname = "rocket";
	model = "models/weapons/law_rocket.vmdl";
	vscripts = "law_rocket"
}

local loadedRocketKeyvals = 
{
	classname = "prop_dynamic";
	model = "models/weapons/law_rocket_packed.vmdl";
}
	

	
function Precache(context)
	PrecacheModel(loadedRocketKeyvals.model, context)
	PrecacheModel(rocketKeyvals.model, context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
	PrecacheParticle("particles/weapons/law_backblast_smoke.vpcf", context)
end


function Activate()
	thisEntity:SetSequence("folded")
	
	loadedRocket = SpawnEntityFromTableSynchronous(loadedRocketKeyvals.classname, loadedRocketKeyvals)
	loadedRocket:SetParent(thisEntity, "rocket_loaded")
	loadedRocket:SetLocalOrigin(Vector(0,0,0))
	loadedRocket:SetLocalAngles(0,0,0)
end


function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	controller = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	pickupTime = Time()

	
	if not alreadyPickedUp and not fired
	then
		handAttachment:SetSequence("extend")
		thisEntity:SetSequence("extended")
		alreadyPickedUp = true
	else
		handAttachment:SetSequence("extended")
	end
	
	if fired
	then
		--handAttachment:SetSingleMeshGroup("fired")
		
	elseif IsValidEntity(loadedRocket) then
		loadedRocket:SetParent(handAttachment, "rocket_loaded")
		loadedRocket:SetLocalOrigin(Vector(0,0,0))
		loadedRocket:SetLocalAngles(0,0,0)
	end
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)

	return true
end

function SetUnequipped()

	if fired
	then
		thisEntity:SetSingleMeshGroup("loaded") -- Fixes issue with model dissappearing if dropped with the fired group set.
		thisEntity:SetContextThink("set_mesh", function () thisEntity:SetSingleMeshGroup("fired") end, 0)
		
	elseif IsValidEntity(loadedRocket) then
		loadedRocket:SetParent(thisEntity, "rocket_loaded")
		loadedRocket:SetLocalOrigin(Vector(0,0,0))
		loadedRocket:SetLocalAngles(0,0,0)
	end
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)

	handID = -1
	controller = nil
	playerEnt = nil
	handAttachment = nil

	return true
end


function OnHandleInput( input )

	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER) and Time() > pickupTime + PICKUP_FIRE_DELAY
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		OnTriggerPressed()
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool()
	end

	return input
end


function OnTriggerPressed()
	
	if not fired
	then
	
		local prop = thisEntity
		
		if isCarried
		then
			prop = handAttachment
		end
	
		fired = true
		StartSoundEvent("Law.Fire", thisEntity)
		
		local backblast = ParticleManager:CreateParticle("particles/weapons/law_backblast.vpcf", 
			PATTACH_POINT, thisEntity)
		ParticleManager:SetParticleControlEnt(backblast, 
			0, handAttachment, PATTACH_POINT, "backblast", Vector(0, 0, 0), true)
	
		local attachment = prop:ScriptLookupAttachment("rocket_spawn")
	
		if IsValidEntity(loadedRocket) then
			loadedRocket:Kill()
		end
	
		rocketKeyvals.origin = prop:GetAttachmentOrigin(attachment)
		rocketKeyvals.angles = prop:GetAttachmentAngles(attachment)
		rocket = SpawnEntityFromTableSynchronous("prop_physics_override", rocketKeyvals)
		
		rocket:GetPrivateScriptScope():Fire(playerEnt)
		
		--prop:SetSingleMeshGroup("fired") --Broken
		prop:SetSequence("extended")

		if controller
		then
			thisEntity:SetThink(FireRumble, "fire_rumble", 0.0)
		end	
	end
end


function FireRumble(self)
	if controller
	then
		controller:FireHapticPulse(2)
	end
	
	fireRumbleElapsed = fireRumbleElapsed + FIRE_RUMBLE_INTERVAL
	if fireRumbleElapsed >= FIRE_RUMBLE_TIME
	then
		fireRumbleElapsed = 0
		return nil
	end
	
	return FIRE_RUMBLE_INTERVAL
end

