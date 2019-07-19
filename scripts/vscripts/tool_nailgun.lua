--[[
	Nailgun script.
	
	Copyright (c) 2016-2019 Rectus
	
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
local BEAM_TRACE_INTERVAL = 0.01
local FIRE_RUMBLE_TIME = 0.2
local SHOT_TRACE_DISTANCE = 2048
local FIRE_INTERVAL = 0.5

local MODE_ROPE = 0
local MODE_BALLJOINT = 1
local MODE_RIGID = 2
local MODE_REMOVE = 3
local MODE_MAX = 4
local mode = 0

local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local isCarried = false
local fired = false
local fireRumbleElapsed = 0
local beamParticle = nil

local gotFirstEndpoint = false
local firstEnt = nil
local firstEntTarget = nil
local screen = nil

local pickupTime = 0
local PICKUP_TRIGGER_DELAY = 0.5

local jointArray = {}

local physicsEntities = {
	prop_physics = true;
	prop_physics_override = true;
	simple_physics_prop = true;
	func_physbox = true;
	prop_destinations_physics = true;
	prop_destinations_tool = true
}

local ROPE_KEYVALUES = {
	classname = "phys_lengthconstraint";
	targetname = "rope_constraint";
	attach1 = "";
	attach2 = "";
	addlength = 0;
	attachpoint = Vector(0,0,0)
}
ROPE_KEYVALUES["spawnflags#0"] = "0"

local BALLJOINT_KEYVALUES = {
	classname = "phys_ballsocket";
	targetname = "ballsocket_constraint";
	attach1 = "";
	attach2 = ""
}
BALLJOINT_KEYVALUES["spawnflags#0"] = "0"

local RIGID_KEYVALUES = {
	classname = "phys_constraint";
	targetname = "rigid_constraint";
	attach1 = "";
	attach2 = "";
	enablelinearconstraint = 1;
	enableangularconstraint = 1
}
RIGID_KEYVALUES["spawnflags#0"] = "0"

local TARGET_KEYVALUES = {
	classname = "info_target";	
}

TARGET_KEYVALUES["spawnflags#0"] = "1"
TARGET_KEYVALUES["spawnflags#1"] = "1"


local SCREEN_KEYVALS = {
	classname = "point_clientui_world_panel";
	targetname = "nailgun_panel";
	dialog_layout_name = "file://{resources}/layout/custom_destination/scanner_display.xml";
	panel_dpi = 40;
	width = 5;
	height = 2;
	ignore_input = 1;
	horizontal_align = 0;
	vertical_align = 0;
	orientation = 0;
}


function Precache(context)
	PrecacheParticle("particles/nailgun_rope.vpcf", context)
	PrecacheParticle("particles/item_laser_pointer.vpcf", context)
	PrecacheParticle("particles/entity/rope_segment.vpcf", context)
	PrecacheParticle("particles/generic_fx/fx_dust.vpcf", context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function SetEquipped(this, pHand, nHandID, pHandAttachment, pPlayer)

	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	pickupTime = Time()
	
	
	if not screen or not IsValidEntity(screen)
	then
		screen = SpawnEntityFromTableSynchronous(SCREEN_KEYVALS.classname, SCREEN_KEYVALS)
		screen:SetParent(handAttachment, "screen")
		screen:SetLocalOrigin(Vector(0,0,0))
		screen:SetLocalAngles(0, 0, 0)
		
		SetPanelText(mode)
	end
	
	
	local muzzle = GetAttachment("muzzle")
	
	beamParticle = ParticleManager:CreateParticle("particles/item_laser_pointer.vpcf", 
		PATTACH_CUSTOMORIGIN, handAttachment)
	ParticleManager:SetParticleControlEnt(beamParticle, 0, handAttachment,
		PATTACH_POINT_FOLLOW, "muzzle", Vector(0,0,0), true)
	ParticleManager:SetParticleControl(beamParticle, 1, muzzle.origin)
		
	-- Control point 3 sets the color of the beam.
	ParticleManager:SetParticleControl(beamParticle, 3, Vector(0.4, 0.4, 0.6))
	
	thisEntity:SetThink(TraceBeam, "trace_beam", 0.1)
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	playerEnt:AllowTeleportFromHand(handID, false)
	
	return true
end


function SetUnequipped()

	playerEnt:AllowTeleportFromHand(handID, true)

	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	handAttachment = nil
	
	if screen and IsValidEntity(screen)
	then	
		screen:Kill()
	end
	
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
			OnTriggerPressed()
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
	
	
	if input.buttonsPressed:IsBitSet(IN_PAD)
	then	
		if input.trackpadY < 0
		then
			CycleMode(-1)
		else
			CycleMode(1)
		end
	end

	-- Needed to disable teleports
	if input.buttonsDown:IsBitSet(IN_PAD) 
	then
		input.buttonsDown:ClearBit(IN_PAD)
	
	end	
	if input.buttonsDown:IsBitSet(IN_PAD_TOUCH) 
	then
		input.buttonsDown:ClearBit(IN_PAD_TOUCH)
	end

	return input
end


function CycleMode(value)

	mode = mode + value

	if mode >= MODE_MAX
	then
		mode = mode - MODE_MAX
	elseif mode < 0
	then 
		mode = MODE_MAX + mode
	end

	StartSoundEvent("multitool_click", thisEntity)
	SetPanelText(mode)
end

function SetPanelText(mode)
	local text = ""
	
	if mode == MODE_ROPE
	then
		text = "Rope"
	elseif mode == MODE_BALLJOINT
	then
		text = "Jointed pole"
	elseif mode == MODE_RIGID
	then
		text = "Welded pole"
	elseif mode == MODE_REMOVE
	then
		text = "Remove joints"
	else
		text = "ERROR"
	end

	
	CustomGameEventManager:Send_ServerToAllClients("scanner_update_display", 
		{id = screen:GetEntityIndex(); displayText = text})
end


function OnTriggerPressed()

	if not fired
	then
		Fire()	
	end
end


function Fire()
	fired = true
	
	TraceShot()
	
	if handAttachment
	then
		thisEntity:SetThink(FireRumble, "fire_rumble", 0.1)
	end

	thisEntity:SetThink(EnableFire, "enable_fire", FIRE_INTERVAL)
end


function EnableFire()
	fired = false
end


function TraceBeam()
	if not isCarried
	then 
		return nil
	end
	
	local muzzle = GetAttachment("muzzle")

	local traceTable =
	{
		startpos = muzzle.origin;
		endpos = muzzle.origin + muzzle.angles:Forward() * SHOT_TRACE_DISTANCE;
		ignore = playerEnt

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				--RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(TONGUE_MAX_DISTANCE * traceTable.fraction, 0, 0)), 0, 255, 255, false, 0.5)
		
			
		local hitPhysProp = false
		if traceTable.enthit and physicsEntities[traceTable.enthit:GetClassname()] ~= nil 
		then	
			hitPhysProp = true
		end
		
		if hitPhysProp
		then
			ParticleManager:SetParticleControl(beamParticle, 3, Vector(0.8, 0.8, 0.5))
		else
			ParticleManager:SetParticleControl(beamParticle, 3, Vector(0.5, 0.8, 0.5))
		end
				
		ParticleManager:SetParticleControl(beamParticle, 1, traceTable.pos)

	else
		ParticleManager:SetParticleControl(beamParticle, 3, Vector(0.4, 0.4, 0.6))
		ParticleManager:SetParticleControl(beamParticle, 1, traceTable.endpos)
	end
	
	return BEAM_TRACE_INTERVAL
end


function TraceShot()
	local muzzle = GetAttachment("muzzle")
	local hitPhysEnt = false
	local traceTable =
	{
		startpos = muzzle.origin ;
		endpos = muzzle.origin + muzzle.angles:Forward() * SHOT_TRACE_DISTANCE;
		ignore = playerEnt

	}
	
	local traceEndPos = traceTable.endpos
	
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 0, 255, false, 2)
		
		if traceTable.enthit and IsValidEntity(traceTable.enthit) and traceTable.enthit:GetEntityIndex() > 0
		then
			if mode ~= MODE_REMOVE
			then
				StartSoundEvent("Suctioncup.Attach", thisEntity)
				SetupConstraint(traceTable.enthit, traceTable.pos)
			else
				StartSoundEvent("multitool_delete_complete", thisEntity)		
				RemoveJoints(traceTable.enthit)
			end
		else
			if mode ~= MODE_REMOVE
			then
				StartSoundEvent("Suctioncup.Attach", thisEntity)
				SetupConstraint(nil, traceTable.pos)
			end
		end
	else
		StartSoundEvent("multitool_switch", thisEntity)
	end
	
	--[[traceEndPos = traceTable.pos
	
	local impactParticle = ParticleManager:CreateParticle("particles/generic_fx/fx_dust.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl(impactParticle, 0, traceTable.pos)
	ParticleManager:SetParticleControlForward(impactParticle, 0, traceTable.normal)
	
	local tracer = ParticleManager:CreateParticle("particles/weapon_tracers.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl(tracer, 0, traceTable.startpos)
	ParticleManager:SetParticleControl(tracer, 1, traceEndPos)
	
	local muzzleFlash = ParticleManager:CreateParticle("particles/generic_fx/fx_dust.vpcf", PATTACH_POINT_FOLLOW, gunAnim)
	ParticleManager:SetParticleControlEnt(muzzleFlash, 0, gunAnim, PATTACH_POINT_FOLLOW, "muzzle", Vector(0, 0, 0), true)
	]]
	
end


function RemoveJoints(entity)

	for i, joint in ipairs(jointArray)
	do
		if joint.firstEnt == entity or joint.secondEnt == entity
		then
			if IsValidEntity(joint.firstTarget) then joint.firstTarget:Kill() end
			if IsValidEntity(joint.secondTarget) then joint.secondTarget: Kill() end
			if IsValidEntity(joint.jointEnt) then joint.jointEnt:Kill() end
			
			table.remove(jointArray, i)
			print("Removed joint " .. i)
		end	
	end
	
end
	
	
function SetupConstraint(hitEntity, hitPosition)
		
	local hitPhysEnt = false
	
	local firstEntIsPhys = false
		
	if firstEnt and physicsEntities[firstEnt:GetClassname()] ~= nil
	then
		firstEntIsPhys = true
	end
	
	if hitEntity and IsValidEntity(hitEntity)
	then
		-- Walk down to parent entity.
		local originalEnt = hitEntity
		
		while hitEntity:GetMoveParent() ~= nil
		do
			hitEntity = hitEntity:GetMoveParent()
		end
	
		if physicsEntities[hitEntity:GetClassname()] ~= nil
		then			
			hitPhysEnt = true
		else		
			hitEntity = originalEnt
		end
	
	end
	
	-- First hit or both entities are non-physics
	if not gotFirstEndpoint or (firstEnt and not IsValidEntity(firstEnt)) or not (hitPhysEnt or firstEntIsPhys)
	then
		
		gotFirstEndpoint = true
		firstEntTarget = SpawnEntityFromTableSynchronous("info_particle_target", {origin = hitPosition})
		
		if hitEntity and IsValidEntity(hitEntity)
		then
			firstEntTarget:SetParent(hitEntity, "")
			firstEnt = hitEntity
		else
			firstEnt = nil
		end
		
	else -- Got two objects, with at least one physics object.
		
		DebugDrawLine(hitPosition, firstEntTarget:GetOrigin(), 128, 255, 128, false, 2)
		
		local baseEnt = nil
		local attachEnt = nil
		local baseEntPos = nil
		local attachEntPos = nil
		local baseEntTarget = nil
		local attachEntTarget = nil
		
		if firstEnt and firstEntIsPhys
		then
			baseEnt = hitEntity
			attachEnt = firstEnt
			baseEntPos = hitPosition
			attachEntPos = firstEntTarget:GetOrigin()
			baseEntTarget = SpawnEntityFromTableSynchronous("info_particle_target", {origin = baseEntPos})
			
			if baseEnt
			then
				baseEntTarget:SetParent(baseEnt, "")
			end
			
			attachEntTarget = firstEntTarget
		else
			attachEnt = hitEntity
			baseEntPos = firstEntTarget:GetOrigin()
			attachEntPos = hitPosition
			
			attachEntTarget = SpawnEntityFromTableSynchronous("info_particle_target", {origin = attachEntPos})
			
			if attachEnt
			then
				attachEntTarget:SetParent(attachEnt, "")
			end
			
			baseEntTarget = firstEntTarget
		end
		
		local baseKeyvals = ROPE_KEYVALUES
		
		if mode == MODE_ROPE
		then
			baseKeyvals = ROPE_KEYVALUES
		elseif mode == MODE_BALLJOINT
		then
			baseKeyvals = BALLJOINT_KEYVALUES
		elseif mode == MODE_RIGID
		then
			baseKeyvals = RIGID_KEYVALUES
		end
		

		local constraintKeyvals = vlua.clone(baseKeyvals)
		
		constraintKeyvals.origin = baseEntPos
		constraintKeyvals.attachpoint = attachEntPos
		
		if attachEnt
		then
			if attachEnt:GetName() == ""
			then
				attachEnt:SetEntityName(DoUniqueString("nailgun_attach"))
			end
			constraintKeyvals.attach2 = attachEnt:GetName()

		end	
		
		if baseEnt
		then
			if baseEnt:GetName() == ""
			then
				baseEnt:SetEntityName(DoUniqueString("nailgun_base"))
			end		

			constraintKeyvals.attach1 = baseEnt:GetName()

		end
		
		local constraint = SpawnEntityFromTableSynchronous(constraintKeyvals.classname, constraintKeyvals)
		
		local ropeParticle = ParticleManager:CreateParticle("particles/nailgun_rope.vpcf", 
			PATTACH_ABSORIGIN, baseEntTarget)
		
		if baseEnt
		then
			ParticleManager:SetParticleControlEnt(ropeParticle, 1, baseEntTarget,
				PATTACH_CUSTOMORIGIN_FOLLOW, nil, Vector(0,0,0), false)
		else
			ParticleManager:SetParticleControl(ropeParticle, 1, baseEntPos)		
		end
		
		local ropeLength = (baseEntPos - attachEntPos):Length()
		

		ParticleManager:SetParticleControlEnt(ropeParticle, 0, attachEntTarget,
			PATTACH_CUSTOMORIGIN_FOLLOW, nil, Vector(0,0,0), false)

		if mode == MODE_ROPE
		then
			ParticleManager:SetParticleControl(ropeParticle, 2, Vector(ropeLength, 0, 0))
			ParticleManager:SetParticleControl(ropeParticle, 3, Vector(60, 50, 45))	
		elseif mode == MODE_BALLJOINT
		then
			ParticleManager:SetParticleControl(ropeParticle, 2, Vector(0, 0, 0))
			ParticleManager:SetParticleControl(ropeParticle, 3, Vector(40, 40, 40))	
		elseif mode == MODE_RIGID
		then
			ParticleManager:SetParticleControl(ropeParticle, 2, Vector(0, 0, 0))
			ParticleManager:SetParticleControl(ropeParticle, 3, Vector(20, 20, 20))	
		end

		
			local scope = baseEntTarget:GetOrCreatePrivateScriptScope()
			if not scope["UpdateOnRemove"]
			then		
				scope["UpdateOnRemove"] = function() return ParticleManager:DestroyParticle(thisEntity:Attribute_GetIntValue("ropeParticle", -1), true) end
				baseEntTarget:Attribute_SetIntValue("ropeParticle", ropeParticle)
			end

		if attachEntTarget then
			
			scope = attachEntTarget:GetOrCreatePrivateScriptScope()
			if not scope["UpdateOnRemove"]
			then	
				scope["UpdateOnRemove"] = function() return ParticleManager:DestroyParticle(thisEntity:Attribute_GetIntValue("ropeParticle", -1), true) end
				attachEntTarget:Attribute_SetIntValue("ropeParticle", ropeParticle)
			end
		end
		
		table.insert(jointArray, {firstEnt = baseEnt, secondEnt = attachEnt, firstTarget = attachEntTarget, secondTarget = baseEntTarget, jointEnt = constraint})
		
		gotFirstEndpoint = false
		firstEntTarget = nil
		firstEnt = nil
	end
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


function GetAttachment(name)

	local ent = thisEntity
	
	if IsValidEntity(handAttachment)
	then
		ent = handAttachment
	end

	local idx = ent:ScriptLookupAttachment(name)
	
	local table = {}
	table.origin = ent:GetAttachmentOrigin(idx)
	local angVec = ent:GetAttachmentAngles(idx)
	table.angles = QAngle(angVec.x, angVec.y, angVec.z)
	
	return table
end
