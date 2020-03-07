
--[[
	MAC-10 weapon script.
	
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

 


local FIRE_RUMBLE_INTERVAL = 0.01
local FIRE_RUMBLE_TIME = 0.2


local SHOT_TRACE_DISTANCE = 16384
local DAMAGE = 0
local DAMAGE_FORCE = 500
local FIRE_INTERVAL = 0.05
local SPREAD_RADIUS_DEGREES = 2

local STATE_READY = 1
local STATE_FIRED = 2

local state = STATE_READY

local isCarried = false
local controller = nil
local currentPlayer = nil
local handID = 0
local handAttachment = nil
local isFireButtonPressed = false
local lastFireTime = 0
local fireRumbleElapsed = 0

local splatterParticle = -1
local beanParticle = -1
local strap


local strapKeyvals = 
{
	classname = "prop_dynamic";
	model = "models/weapons/mac10/mac10_strap.vmdl";
	targetname = "strap";
	DefaultAnim = "strap_bones";
	Collisions = "Not Solid"
}


function Precache(context)
	PrecacheParticle("particles/weapons/bean_tracer.vpcf", context)
	PrecacheParticle("particles/weapons/bean_splatter.vpcf", context)
	PrecacheParticle("particles/weapons/bean_splatter_dynamic.vpcf", context)
	PrecacheParticle("particles/weapons/mean_muzzle_flash.vpcf", context)
	PrecacheModel(strapKeyvals.model, context)
end

function Activate()
	thisEntity:SetSequence("loaded")
	if activateType == ACTIVATE_TYPE_ONRESTORE -- on game load
	then			
		-- Hack to properly handle restoration from saves, 
		-- since variables written by Activate() on restore don't end up in the script scope.
		EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "RestoreState")

	else	
		strap = SpawnEntityFromTableSynchronous(strapKeyvals.classname, strapKeyvals)
		strap:SetParent(thisEntity, "")
		strap:SetLocalOrigin(Vector(0,0,0))
		strap:SetLocalAngles(0,0,0)
	end
end

function RestoreState()

	thisEntity:GetOrCreatePrivateScriptScope() -- Script scopes do not seem to be properly created on restore

	local children = thisEntity:GetChildren()
	for idx, child in pairs(children)
	do
		if child:GetName() == strapKeyvals.targetname
		then
			strap = child
		end
	end
end


function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	controller = pHand
	currentPlayer = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	state = STATE_READY
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	if not IsValidEntity(strap) then
		strap = SpawnEntityFromTableSynchronous(strapKeyvals.classname, strapKeyvals)
	end
	strap:SetParent(handAttachment, "")
	strap:SetLocalOrigin(Vector(0,0,0))
	strap:SetLocalAngles(0,0,0)
	handAttachment:SetSequence("loaded")


	return true
end

function SetUnequipped()
	isCarried = false
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	EndFire()
	
	if IsValidEntity(strap) then
		strap:SetParent(thisEntity, "")
		strap:SetLocalOrigin(Vector(0,0,0))
		strap:SetLocalAngles(0,0,0)
	end
	
	return true
end


function OnHandleInput(input)

	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		isFireButtonPressed = true
		
		thisEntity:SetThink(CheckFire, "check_fire")
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		--handAttachment:SetSequence("loaded")
		isFireButtonPressed = false
		EndFire()
	end

	handAttachment:SetPoseParameter("trigger", input.triggerValue * 0.5 + (isFireButtonPressed and 0.5 or 0))
	return input
end


function CheckFire()

	if not isFireButtonPressed
	then
		if state == STATE_FIRED and Time() >= lastFireTime + FIRE_INTERVAL
		then
			state = STATE_READY 
		end
		
		return nil
	end

	if state == STATE_READY
	then		
		Fire()
		lastFireTime = Time()
		state = STATE_FIRED
		return FIRE_INTERVAL
	
	elseif state == STATE_FIRED
	then
		if Time() >= lastFireTime + FIRE_INTERVAL
		then
			Fire()
			lastFireTime = Time()
			state = STATE_FIRED
			return FIRE_INTERVAL
		else
			return lastFireTime + FIRE_INTERVAL - Time()
		end
	end	
	
	return nil
end


function Fire()
	handAttachment:ResetSequence("fire_beans")
	StartSoundEventFromPosition("toy_gun_impact", GetAttachment(handAttachment, "muzzle").origin)
	
	local muzzleFlash = ParticleManager:CreateParticle("particles/weapons/bean_muzzle_flash.vpcf", 
		PATTACH_POINT_FOLLOW, handAttachment)
	ParticleManager:SetParticleControlEnt(muzzleFlash, 0, handAttachment, PATTACH_POINT_FOLLOW, 
		"muzzle", Vector(0, 0, 0), true)
	ParticleManager:ReleaseParticleIndex(muzzleFlash) 
	
	TraceShot()
	
	if controller
	then
		controller:FireHapticPulse(2)
	end

end


function EndFire()
	if splatterParticle ~= -1
	then
		ParticleManager:DestroyParticle(splatterParticle, false) 
		splatterParticle = -1
	end
	
	if beanParticle ~= -1
	then
		ParticleManager:DestroyParticle(beanParticle, false) 
		beanParticle = -1
	end
end


function TraceShot()

	local muzzle = GetAttachment(handAttachment, "muzzle")
	
	local ang = RandomFloat(0, 360)
	local radius = SPREAD_RADIUS_DEGREES * math.sqrt(RandomFloat(0, 1))
	local spreadAngle = RotateOrientation(muzzle.angles, QAngle(radius * math.sin(ang), radius * math.cos(ang)) )
	
	local traceTable =
	{
		startpos = muzzle.origin + muzzle.angles:Forward() * 1;
		endpos = muzzle.origin + spreadAngle:Forward() * SHOT_TRACE_DISTANCE;
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

			local impactParticle = ParticleManager:CreateParticle("particles/weapons/bean_splatter_dynamic.vpcf", PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(impactParticle, 0, traceTable.pos)
			ParticleManager:SetParticleControlForward(impactParticle, 0, traceTable.normal)
			ParticleManager:ReleaseParticleIndex(impactParticle) 
		else
		
			if beanParticle ~= -1
			then
				ParticleManager:DestroyParticle(beanParticle, false)
			end
		
			beanParticle = ParticleManager:CreateParticle("particles/weapons/bean_hit.vpcf", PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(beanParticle, 0, traceTable.pos)
			ParticleManager:SetParticleControlForward(beanParticle, 0, traceTable.normal)
			
			if splatterParticle ~= -1
			then
				ParticleManager:DestroyParticle(splatterParticle, false)
			end
			splatterParticle = ParticleManager:CreateParticle("particles/weapons/bean_splatter.vpcf", PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(splatterParticle, 0, traceTable.pos)
			ParticleManager:SetParticleControlForward(splatterParticle, 0, traceTable.normal)

		end
		
		tracerEndPos = traceTable.pos
		
	end
	
	local tracer = ParticleManager:CreateParticle("particles/weapons/bean_tracer.vpcf", PATTACH_CUSTOMORIGIN, thisEntity)
	ParticleManager:SetParticleControl(tracer, 0, traceTable.startpos)
	ParticleManager:SetParticleControl(tracer, 1, tracerEndPos)
	ParticleManager:ReleaseParticleIndex(tracer) 
	
end


function FireRumble()
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


function GetAttachment(ent, name)
	local idx = ent:ScriptLookupAttachment(name)
	
	local table = {}
	table.origin = ent:GetAttachmentOrigin(idx)
	local ang = ent:GetAttachmentAngles(idx)
	table.angles = QAngle(ang.x, ang.y, ang.z)
	
	return table
end

