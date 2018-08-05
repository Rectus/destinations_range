--[[
	Boxing sword script.
	
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




local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local isCarried = false
local physSword = nil
local toolTarget = nil
local physConstraint = nil
local lastFireTime = 0

local DAMAGE_FACTOR = 0.1
local STUCK_SPEED = 5
local THINK_INTERVAL = 0.011
local user = nil
local tracing = false
local lastSoundTime = 0

local pickupTime = 0
local PICKUP_TRIGGER_DELAY = 0.5


local constraintKeyvals = {
	--classname = "phys_constraint";
	--classname = "phys_ballsocket";
	classname = "phys_genericconstraint";
	targetname = "";
	attach1 = "";
	attach2 = "";
	--friction = 1;
	--linearfrequency = 5;
	--lineardampingratio = 0.8;
	--enablelinearconstraint = 1;
	--enableangularconstraint = 1;
	
	linear_motion_x = "JOINT_MOTION_LOCKED";
	linear_frequency_x = 10;
	linear_damping_ratio_x = 0.8;
	
	linear_motion_y = "JOINT_MOTION_LOCKED";
	linear_frequency_y = 10;
	linear_damping_ratio_y = 0.8;
	
	linear_motion_z = "JOINT_MOTION_LOCKED";
	linear_frequency_z = 10;
	linear_damping_ratio_z = 0.8;
	
	angular_motion_x = "JOINT_MOTION_LOCKED";
	angular_frequency_x = 20;
	angular_damping_ratio_x = 10;
	
	angular_motion_y = "JOINT_MOTION_LOCKED";
	angular_frequency_y = 20;
	angular_damping_ratio_y = 10;
	
	angular_motion_z = "JOINT_MOTION_LOCKED";
	angular_frequency_z = 20;
	angular_damping_ratio_z = 10;
}
constraintKeyvals["spawnflags#0"] = "1"

local swordKeyvals = {
	classname = "prop_destinations_physics";
	--physdamagescale = 100	
}


function Activate()
	--thisEntity:SetRenderColor(240, 240, 150)
	
	swordKeyvals.model = thisEntity:GetModelName()
	swordKeyvals.angles = thisEntity:GetAngles()
	swordKeyvals.origin = thisEntity:GetAbsOrigin()
	
	physSword = SpawnEntityFromTableSynchronous(swordKeyvals.classname, swordKeyvals)
	physSword:EnableUse(false)
	local paintColor = thisEntity:GetRenderColor()
	physSword:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	
	thisEntity:SetEntityName(DoUniqueString("sword_ent"))	
	physSword:SetEntityName(DoUniqueString("sword_phys"))
	
	constraintKeyvals.origin = thisEntity:GetAbsOrigin()
	constraintKeyvals.attach2 = thisEntity:GetName()
	constraintKeyvals.attach1 = physSword:GetName()

	physConstraint = SpawnEntityFromTableSynchronous(constraintKeyvals.classname, constraintKeyvals)
	physConstraint:SetEntityName(DoUniqueString("sword_const"))
	physSword:SetParent(thisEntity, "")
	physSword:AddEffects(32)
end



function SetEquipped(self, pHand, nHandID, pHandAttachment, pPlayer)

	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	pickupTime = Time()
	
	handAttachment:AddEffects(32)
	
	physSword:SetParent(nil, "")
	physSword:RemoveEffects(32)
	DoEntFireByInstanceHandle(physConstraint, "TurnOn", "", 0, nil, nil)
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	physSword:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	thisEntity:SetThink(SwordThink, "sword", 0)
	
	tracing = false
	thisEntity:SetParent(nil, "")
	DoEntFireByInstanceHandle(thisEntity, "enablemotion", "", 0 , thisEntity, thisEntity)
	
	StartSoundEvent("Sword.Draw", thisEntity)
	return true
end




function SetUnequipped()

	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	
	physSword:AddEffects(32)
	DoEntFireByInstanceHandle(physConstraint, "TurnOff", "", 0, nil, nil)
	physSword:SetParent(thisEntity, "")
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	handAttachment = nil
	
	return true
end


function OnHandleInput( input )
	if not playerEnt
	then 
		return
	end

	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	local IN_PAD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
	local IN_PAD_TOUCH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)
	

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		if Time() > pickupTime + PICKUP_TRIGGER_DELAY
		then
			OnTriggerPressed(self)
		end
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
	


	-- Needed to disable teleports
	--[[if input.buttonsDown:IsBitSet(IN_PAD) 
	then
		input.buttonsDown:ClearBit(IN_PAD)
	
	end	
	if input.buttonsDown:IsBitSet(IN_PAD_TOUCH) 
	then
		input.buttonsDown:ClearBit(IN_PAD_TOUCH)
	end]]

	return input
end



function SwordThink()
	
	if not isCarried then
		return nil
	end
	
	local idx = physSword:ScriptLookupAttachment("tip")	
	local tipOrigin = physSword:GetAttachmentOrigin(idx)

	idx = physSword:ScriptLookupAttachment("blade1")	
	local blade1Origin = physSword:GetAttachmentOrigin(idx)
	
	idx = physSword:ScriptLookupAttachment("blade2")	
	local blade2Origin = physSword:GetAttachmentOrigin(idx)
	
	local velocity = GetPhysVelocity(physSword)


	
	local traceTable =
	{
		startpos = tipOrigin ;
		endpos = blade1Origin;
		ignore = physSword

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 255, 0, false, 0.22)
	
	TraceLine(traceTable)
	
	if not traceTable.hit then
		traceTable.endpos = blade2Origin
		TraceLine(traceTable)
	end
	
	if traceTable.hit
	then
	
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0 and traceTable.enthit:GetClassname() ~= "player" 			
		then
			
			local hitVelocity = velocity - GetPhysVelocity(traceTable.enthit)
			
			local dmg = CreateDamageInfo(thisEntity, user, hitVelocity, 
				traceTable.pos, hitVelocity:Length() * DAMAGE_FACTOR, DMG_SLASH)
				
			traceTable.enthit:TakeDamage(dmg)
			DestroyDamageInfo(dmg)
			
			if hitVelocity:Length() > 100 and IsValidEntity(traceTable.enthit) and traceTable.enthit:IsAlive() then
				local sparks = ParticleManager:CreateParticle("particles/tools/sword_sparks.vpcf", 
					PATTACH_CUSTOMORIGIN, physSword)
				ParticleManager:SetParticleControl(sparks, 0, traceTable.pos)
				
				if Time() > lastSoundTime + 1.0 then
					lastSoundTime = Time()
					StartSoundEvent("Sword.Hit", thisEntity)
				end
			end	
			
		end

	end
	

	return THINK_INTERVAL
end



function OnTriggerPressed()
	if Time() > lastFireTime + 0.3 then
		lastFireTime = Time()
		physSword:ApplyAbsVelocityImpulse(thisEntity:GetAngles():Forward():Normalized() * 500)
	end
end


-- For arrow effects
function EnableDamage(usingPlayer)
	user = usingPlayer
	tracing = true
	thisEntity:SetThink(ArrowThink, "think", THINK_INTERVAL)
	ArrowThink(true)
end

function ArrowThink(ignoreSpeed)
	if not tracing
	then 
		return
	end
	
	local idx = thisEntity:ScriptLookupAttachment("tip")	
	local tipOrigin = thisEntity:GetAttachmentOrigin(idx)
	local dir = thisEntity:GetAngles()
	
	local vel = GetPhysVelocity(thisEntity)
	local speed = vel:Length()
	local distanceInterval = speed  * THINK_INTERVAL
	
	if not ignoreSpeed and speed < 20
	then
		tracing = false
		return nil
	end
	
	local traceTable =
	{
		startpos = tipOrigin ;
		endpos = tipOrigin + vel:Normalized() * distanceInterval * 1.1;
		ignore = thisEntity

	}
	--DebugDrawLine(traceTable.startpos, t5raceTable.endpos, 0, 255, 0, false, 10)
	
	TraceLine(traceTable)
	
	if traceTable.hit and thisEntity:GetAngles():Forward():Dot(-traceTable.normal) > 0.5
	then
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
			
			local dmg = CreateDamageInfo(thisEntity, user, vel * thisEntity:GetMass(), traceTable.pos, speed, DMG_SLASH)
			traceTable.enthit:TakeDamage(dmg)
			DestroyDamageInfo(dmg)
			if IsValidEntity(traceTable.enthit) and traceTable.enthit:IsAlive()
			then
				thisEntity:SetParent(traceTable.enthit, CheckParentAttachment(traceTable.enthit))
			else
				thisEntity:ApplyAbsVelocityImpulse(-vel)
				tracing = false

				return nil
			end
		else
			DoEntFireByInstanceHandle(thisEntity, "disablemotion", "", 0 , thisEntity, thisEntity)		
		end
		thisEntity:SetOrigin(traceTable.pos - (tipOrigin - thisEntity:GetOrigin()) * (1 - speed * 0.0001))
		
		StartSoundEvent("Sword.Hit", thisEntity)
		tracing = false

		return nil
	end
	
	return THINK_INTERVAL
end


function CheckParentAttachment(ent)
	if ent:GetName() == "Target"
	then
		return "target"
	end
	return ""
end




