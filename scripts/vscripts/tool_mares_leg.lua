
--[[
	Mare's leg weapon script.
	
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
require "utils.deepprint"
 

local SPIN_CHECK_INTERVAL = 0.05
local SPIN_POSE_INTERVAL = 0.011
local FIRE_RUMBLE_INTERVAL = 0.01
local FIRE_RUMBLE_TIME = 0.2
local PICKUP_FIRE_DELAY = 0.5

local SHOT_TRACE_DISTANCE = 16384
local DAMAGE = 150
local DAMAGE_FORCE = 500

local STATE_READY = 1
local STATE_FIRED = 2
local STATE_CYCLING = 3
local STATE_CYCLING_COCKED = 4

local state = STATE_READY

local isCarried = false
local pickupTime = 0
local controller = nil
local currentPlayer = nil
local handID = 0
local handAttachment = nil
local isFireButtonPressed = false
local alreadyPickedUp = false
local prevRotSpeed = 0
local spinMomentum = 0
local spinAngle = 0
local leverPos = 0
local lastVel = Vector(0,0,0)

local rumbleLevelPos = 0
local rumbleSpinAngle = 0

local spinTimeElapsed = 0
local fireRumbleElapsed = 0
local tracerParticle = nil
local tracerEnd = nil
local muzzleFlash = nil
local impactParticle = nil

local sight = nil


function Precache(context)
	PrecacheParticle("particles/weapons/mares_leg_tracer.vpcf", context)
	PrecacheParticle("particles/weapons/mares_leg_bullet_impact.vpcf", context)
	PrecacheParticle("particles/weapons/mares_leg_bullet_impact_dynamic.vpcf", context)
	PrecacheParticle("particles/weapons/mares_leg_shell_casing.vpcf", context)
	PrecacheParticle("particles/weapons/mares_leg_muzzle_flash.vpcf", context)
	
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end

function Activate()
	thisEntity:SetSequence("idle_uncocked")
	
	
	local child = thisEntity:FirstMoveChild()
	if child and child:GetName() == "rds"
	then
		sight = child
		child:SetParent(thisEntity, "sight")
		child:SetLocalOrigin(Vector(0,0,0))
		child:SetLocalAngles(0,0,0)
	end
end

function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	controller = pHand
	currentPlayer = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	pickupTime = Time()
	
	local child = thisEntity:FirstMoveChild()

	if child and child:GetName() == "rds"
	then
		sight = child
		child:SetParent(handAttachment, "sight")
		child:SetLocalOrigin(Vector(0,0,0))
		child:SetLocalAngles(0,0,0)
	end
	
	if not alreadyPickedUp
	then
		StartSoundEvent("Maresleg.Bolt_Open", handAttachment)
		handAttachment:SetSequence("draw")
		thisEntity:SetThink(SequenceFinished, "sequence", handAttachment:ActiveSequenceDuration())
		alreadyPickedUp = true
	else
		SequenceFinished()
	end
	
	if state == STATE_FIRED
	then
		handAttachment:SetSequence("idle_uncocked")
		thisEntity:SetThink(CheckSpin, "check_spin", SPIN_CHECK_INTERVAL)
	end
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	

	return true
end

function SetUnequipped()
	isCarried = false
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	if sight ~= nil
	then
		sight:SetParent(thisEntity, "sight")
		sight:SetLocalOrigin(Vector(0,0,0))
		sight:SetLocalAngles(0,0,0)
	end
	
	if state == STATE_CYCLING then
		state = STATE_FIRED
	elseif state == STATE_CYCLING_COCKED then
		state = STATE_READY
	end
	
	leverPos = 0
	spinAngle = 0
	lastVel = Vector(0,0,0)
	
	
	if state == STATE_FIRED
	then
		thisEntity:SetSequence("idle_uncocked")
	else
		thisEntity:SetSequence("idle")
	end
	
	return true
end


function OnHandleInput( input )
	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		
		if state == STATE_READY and Time() > pickupTime + PICKUP_FIRE_DELAY
		then
			Fire()	
		end
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool();
	end

	return input
end



function Fire()
	state = STATE_FIRED
	StartSoundEventFromPosition("Maresleg.Fire", handAttachment:GetCenter())
	
	
	local muzzleFlash = ParticleManager:CreateParticle("particles/weapons/mares_leg_muzzle_flash.vpcf", 
		PATTACH_POINT_FOLLOW, handAttachment)
	ParticleManager:SetParticleControlEnt(muzzleFlash, 0, handAttachment, PATTACH_POINT_FOLLOW, 
		"muzzle", Vector(0, 0, 0), true)
	
	TraceShot()
	
	if controller
	then
		thisEntity:SetThink(FireRumble, "fire_rumble", 0.1)
	end
	handAttachment:SetSequence("fire")
	thisEntity:SetThink(SequenceFinished, "sequence", handAttachment:ActiveSequenceDuration())

	thisEntity:SetThink(CheckSpin, "check_spin", SPIN_CHECK_INTERVAL)
end


function TraceShot()

	local muzzle = GetAttachment(handAttachment, "muzzle")
	local traceTable =
	{
		startpos = muzzle.origin;
		endpos = muzzle.origin + muzzle.angles:Forward() * SHOT_TRACE_DISTANCE;
		ignore = currentPlayer

	}
	local tracerEndPos = traceTable.endpos
	if g_VRScript.playerPhysController and g_VRScript.playerPhysController:IsDebugDrawEnabled()
	then
		DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	end
	
	TraceLine(traceTable)
	
	if traceTable.hit
	then
		if g_VRScript.playerPhysController and g_VRScript.playerPhysController:IsDebugDrawEnabled()
		then
			DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.2)
		end
		
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
		
			local dmgInfo = CreateDamageInfo(thisEntity, currentPlayer, thisEntity:GetAngles():Forward() * DAMAGE_FORCE, 
				traceTable.pos,  DAMAGE, DMG_BULLET)
				
			traceTable.enthit:TakeDamage(dmgInfo)		
			DestroyDamageInfo(dmgInfo)
			
			--[[if traceTable.enthit:GetPrivateScriptScope() and 
				traceTable.enthit:GetPrivateScriptScope().OnHurt
			then
				traceTable.enthit:GetPrivateScriptScope().OnHurt()
			end]]
			local impactParticle = ParticleManager:CreateParticle("particles/weapons/mares_leg_bullet_impact_dynamic.vpcf", PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(impactParticle, 0, traceTable.pos)
			ParticleManager:SetParticleControlForward(impactParticle, 0, traceTable.normal)
		else
			local impactParticle = ParticleManager:CreateParticle("particles/weapons/mares_leg_bullet_impact.vpcf", PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(impactParticle, 0, traceTable.pos)
			ParticleManager:SetParticleControlForward(impactParticle, 0, traceTable.normal)
		
		end
		
		tracerEndPos = traceTable.pos
		
	end
	
	local tracer = ParticleManager:CreateParticle("particles/weapons/mares_leg_tracer.vpcf", PATTACH_CUSTOMORIGIN, thisEntity)
	ParticleManager:SetParticleControl(tracer, 0, traceTable.startpos)
	ParticleManager:SetParticleControl(tracer, 1, tracerEndPos)
	
	
	
end


function SequenceFinished()
	if isCarried
	then	
		if state == STATE_FIRED
		then
			handAttachment:SetSequence("idle_uncocked")
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



function CheckSpin(self)
	if not isCarried
	then
		return nil
	end

	local torque = GetLeverTorque()

	if abs(torque) > 200
	then
		spinMomentum = -torque * 2
		
		if torque > 0 then
			leverPos = 0.5
		else
			leverPos = 0.05
		end
		
		handAttachment:SetSequence("spin_posable_uncocked")
		handAttachment:SetPoseParameter("lever_pos", leverPos)
		handAttachment:SetPoseParameter("spin_rot", 1)
		
		spinAngle = 360
		lastVel = GetPhysVelocity(handAttachment) 
		thisEntity:SetThink(SpinPose, "spin_pose", SPIN_POSE_INTERVAL)
		state = STATE_CYCLING
		
		StartSoundEvent("Maresleg.Bolt_Open", handAttachment)
			
		controller:FireHapticPulse(2)
		
		return nil
		
	end
	
	return SPIN_CHECK_INTERVAL
end


function SpinPose()
	if not isCarried then return nil end
	
	if leverPos > 0.85 and state == STATE_CYCLING then
		
		local casing = ParticleManager:CreateParticle("particles/weapons/mares_leg_shell_casing.vpcf", 
		PATTACH_POINT, thisEntity)
		ParticleManager:SetParticleControlEnt(casing, 0, handAttachment, PATTACH_POINT, 
			"shell_casing", Vector(0, 0, 0), true)
		
		StartSoundEvent("Maresleg.Load_Round", handAttachment)
		state = STATE_CYCLING_COCKED
		handAttachment:SetSequence("spin_posable")
		
	elseif leverPos < 0.15 and state == STATE_CYCLING_COCKED then
	
		StartSoundEvent("Maresleg.Bolt_Closed", handAttachment)
		state = STATE_READY
		handAttachment:SetSequence("idle")
		leverPos = 0
		spinAngle = 0
		lastVel = Vector(0,0,0)
		return false
	end


	local torque = GetLeverTorque()
	
	local leverFactor = 0.9
	
	if (leverPos >= 1 and spinMomentum > 0) or (leverPos <= 0 and spinMomentum < 0) then
	
		leverFactor = 0.0
	end
	
	local rotAcc =  torque * 170.0 * (1 -leverFactor) * SPIN_POSE_INTERVAL
	local leverAcc = torque * leverFactor * 10.0 * SPIN_POSE_INTERVAL
	

	spinMomentum = spinMomentum * 0.9990 + rotAcc - sign(spinMomentum) * 0.15
	spinMomentum = Clamp(spinMomentum, -500, 500)

	spinAngle = Clamp((spinAngle - spinMomentum * SPIN_POSE_INTERVAL + 360) % 360, 0, 360) 
		
	local leverMaxMove = 2 * SPIN_POSE_INTERVAL
	local leverMove = Clamp(leverAcc * 0.5, -leverMaxMove, leverMaxMove)
	leverPos = Clamp(leverPos + leverMove, 0, 1)
	
	handAttachment:SetPoseParameter("spin_rot", spinAngle)
	handAttachment:SetPoseParameter("lever_pos", leverPos)
	
	if abs(spinAngle - rumbleSpinAngle) > 10 then
		rumbleSpinAngle = spinAngle
		controller:FireHapticPulse(0)
	end 
	
	if abs(leverPos - rumbleLevelPos) > 0.05 then
		rumbleLevelPos = leverPos
		controller:FireHapticPulse(0)
	end	
	
	return SPIN_POSE_INTERVAL
end


function GetLeverTorque()

	local idx = handAttachment:ScriptLookupAttachment("mass_center")
	local massCenter = handAttachment:GetAttachmentOrigin(idx)
	
	idx = handAttachment:ScriptLookupAttachment("spin_pivot")
	local pivot = handAttachment:GetAttachmentOrigin(idx)
	
	local velocity = currentPlayer:GetHMDAvatar():GetVRHand(handID):GetVelocity()--GetPhysVelocity(handAttachment) 
	local acc = velocity - lastVel
	
	lastVel = velocity
	
	local accSpeed = acc:Length()
	
	if accSpeed < 1 then
		acc = Vector(0,0,0)		
	elseif accSpeed < 4 then
		acc = acc:Normalized() * RemapVal(accSpeed, 1, 4, 0, 4) 
	end
	
	local torqueVector = (pivot - massCenter):Cross(-handAttachment:GetAngles():Left())
	
	
	
	-- Object velocity + gravity
	local gravFactor = torqueVector:Dot(Vector(0,0, 386 * SPIN_POSE_INTERVAL * 0.2))
	local dotVal = torqueVector:Dot(acc) + gravFactor
	
	
	if g_VRScript.playerPhysController and g_VRScript.playerPhysController:IsDebugDrawEnabled() then
		DebugDrawLine(pivot, massCenter, 255, 255, 0, false, SPIN_POSE_INTERVAL)
		DebugDrawLine(pivot, pivot + torqueVector:Normalized() * dotVal, 255, 0, 255, false, SPIN_POSE_INTERVAL)
		DebugDrawLine(pivot, pivot + acc:Normalized() * torqueVector:Dot(acc), 128, 0, 255, false, SPIN_POSE_INTERVAL)
		DebugDrawLine(pivot, pivot + Vector(0,0,-1) * gravFactor, 0, 255, 255, false, SPIN_POSE_INTERVAL)
	end
	
	
	return dotVal
end


function sign(x)
	return x > 0 and 1 or x < 0 and -1 or 1
end



function GetAttachment(ent, name)
	local idx = ent:ScriptLookupAttachment(name)
	
	local table = {}
	table.origin = ent:GetAttachmentOrigin(idx)
	local ang = ent:GetAttachmentAngles(idx)
	table.angles = QAngle(ang.x, ang.y, ang.z)
	
	return table
end

