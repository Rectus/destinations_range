--[[
	Bow entity script
	
	Copyright (c) 2017-2019 Rectus
	
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

local FIRE_RUMBLE_INTERVAL = 0.02
local FIRE_RUMBLE_TIME = 0.1
local THINK_INTERVAL = 0.02
local DRAW_FIRE_DELAY = 0.1
local FIRE_THINK_DELAY = 0.2

local bowView = nil
local drawTool = nil
local arrowNocked = false
local arrow = nil
local drawFrac = 0
local drawTime = 0
local otherHandProp = nil
local nockGuideParticle = -1
local rumbleDrawLength = 0
local fireRumbleElapsed = 0

local PHYS_ENTITIES = {
	"prop_destinations_physics";
	"prop_destinations_tool";
	"prop_destinations_game_trophy"
}

local BOW_VIEW_KEYVALS = {
	classname = "prop_dynamic"; 
	targetname = "bow_view";
	model = "models/weapons/bow.vmdl";
	solid = 0
}

local DRAW_TOOL_KEYVALS = {
	classname = "prop_destinations_tool"; 
	targetname = "bow_drawtool";
	model = "models/weapons/bow_drawguide.vmdl";
	vscripts = "tool_bow_draw";
	solid = 0;
	HasCollisionInHand = 0;
}

local ARROW_KEYVALS = {
	classname = "prop_destinations_physics"; 
	targetname = "arrow";
	model = "models/weapons/arrow.vmdl";
	vscripts = "tool_bow_arrow"
}

function Precache(context)
	PrecacheModel(DRAW_TOOL_KEYVALS.model, context)
	PrecacheModel(ARROW_KEYVALS.model, context)
	PrecacheModel(BOW_VIEW_KEYVALS.model, context)
end

function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	arrowNocked = false
	
	bowView = SpawnEntityFromTableSynchronous(BOW_VIEW_KEYVALS.classname, BOW_VIEW_KEYVALS)
	bowView:SetParent(handAttachment, "")
	bowView:SetLocalOrigin(Vector(0,0,0))
	bowView:SetLocalAngles(0, 0, 0)
	bowView:SetSequence("bow_draw")
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	bowView:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	handAttachment:AddEffects(32) --EF_NODRAW
	
	drawTool = SpawnEntityFromTableSynchronous(DRAW_TOOL_KEYVALS.classname, DRAW_TOOL_KEYVALS)
	drawTool:SetParent(bowView, "draw_guide")
	drawTool:SetLocalOrigin(Vector(0,0,0))
	drawTool:SetLocalAngles(0, 0, 0)

	
	thisEntity:SetThink(BowThink, "bow_think", 0)
	
	return true
end

function SetUnequipped()

	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)

	handAttachment = nil
	
	if drawTool and IsValidEntity(drawTool)
	then
		drawTool:ForceDropTool()
		drawTool:Kill()		
	end
	drawTool = nil


	return true
end

function OnHandleInput(input)

	local nIN_TRIGGER = IN_USE_HAND1; if (handID == 0) then nIN_TRIGGER = IN_USE_HAND0 end;
	local nIN_GRIP = IN_GRIP_HAND1; if (handID == 0) then nIN_GRIP = IN_GRIP_HAND0 end;
	
	if input.buttonsReleased:IsBitSet(nIN_GRIP)
	then
		input.buttonsReleased:ClearBit(nIN_GRIP)
		thisEntity:ForceDropTool();
	end

	return input;
end


function BowThink()
	if not handAttachment or not IsValidEntity(handAttachment)
	then
		return nil
	end
	
	local drawPulling = false
	
	if not drawTool or not IsValidEntity(drawTool)
	then
		drawTool = SpawnEntityFromTableSynchronous(DRAW_TOOL_KEYVALS.classname, DRAW_TOOL_KEYVALS)
		drawTool:SetParent(bowView, "draw_guide")
		drawTool:SetLocalOrigin(Vector(0,0,0))
		drawTool:SetLocalAngles(0, 0, 0)
		
	else
		drawPulling = drawTool:GetOrCreatePrivateScriptScope():IsPulling()
	end

	
	local paintColor = handAttachment:GetRenderColor()
	bowView:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	if not arrowNocked and drawPulling
	then		
		SpawnArrow()		
		arrowNocked = true
		drawTime = Time()
	elseif arrowNocked and not drawPulling
	then
		if Time() > drawTime + DRAW_FIRE_DELAY
		then
			FireArrow()
			bowView:SetSequence("release")
			StartSoundEvent("Bow.String", bowView)		
		else
			bowView:SetPoseParameter("draw", 0)
			arrow:Kill()
			arrow = nil
		end	
		arrowNocked = false
		
		bowView:SetLocalOrigin(Vector(0,0,0))	
		bowView:SetLocalAngles(0, 0, 0)
		
		return FIRE_THINK_DELAY
		
	elseif not arrowNocked and not drawPulling then
		CheckArrows()
	end
	
	--DebugDrawLine(pivotOrigin, toolOrigin, 0, 255, 0, false, THINK_INTERVAL)
	if drawPulling
	then
		local idx = handAttachment:ScriptLookupAttachment("pivot")	
		local pivotOrigin = handAttachment:GetAttachmentOrigin(idx)
		local toolOrigin = drawTool:GetOrCreatePrivateScriptScope():GetToolOrigin()
	
		local drawVec = (pivotOrigin - toolOrigin)
		local drawLength = drawVec:Length()
		
		if drawLength < 10
		then
			drawLength = 0
		else
			drawLength = drawLength - 10
		end
	
		drawFrac = abs(drawLength / 20.5)
	
		if drawPulling and drawLength > 0
		then
			bowView:SetSequence("bow_draw")
			bowView:SetPoseParameter("draw", drawLength)
			
		else	
			bowView:SetPoseParameter("draw", 0)
		end
		
		if abs(drawLength - rumbleDrawLength) > 0.5 then
			local otherHand = (handID == 0 and 1 or 0)
			playerEnt:GetHMDAvatar():GetVRHand(otherHand):FireHapticPulse(1)
			handEnt:FireHapticPulse(0)
			rumbleDrawLength = drawLength
		end
		
		local bowAng = handAttachment:GetAngles()	
		local drawAng = VectorToAngles(drawVec)
	
		local viewPos = RotatePosition(pivotOrigin, RotationDelta(bowAng, drawAng), handAttachment:GetAbsOrigin())
		--DebugDrawLine(handAttachment:GetAbsOrigin(), viewPos, 0, 0, 255, false, THINK_INTERVAL)
		
		bowView:SetAbsOrigin(viewPos)	
		bowView:SetAngles(drawAng.x, drawAng.y, bowAng.z)
	else
		bowView:SetLocalOrigin(Vector(0,0,0))	
		bowView:SetLocalAngles(0, 0, 0)
	end
	
	return THINK_INTERVAL
end


function CheckArrows()
	local otherHand = (handID == 0 and 1 or 0)
	
	if otherHandProp then
	
		if not IsValidEntity(otherHandProp) then
		
			ParticleManager:DestroyParticle(nockGuideParticle, true)
			nockGuideParticle = -1
			otherHandProp = nil
			return
		end
		
		local propHand = GetHandHoldingEntity(otherHandProp)
		
		if not propHand or propHand:GetPlayer() ~= playerEnt
			or propHand:GetHandID() ~= otherHand then	
		
			ParticleManager:DestroyParticle(nockGuideParticle, true)
			nockGuideParticle = -1
			otherHandProp = nil
		
			return
		end
		
		-- Hack to move the hidden held tool entity to the correct position
		if otherHandProp:GetClassname() == "prop_destinations_tool" and nockGuideParticle == -1
		then
			otherHandProp:SetAbsOrigin(propHand:GetAbsOrigin())
		end
		
		
		local idx = otherHandProp:ScriptLookupAttachment("arrow_nock")	
		local propNockOrigin = otherHandProp:GetAttachmentOrigin(idx)
		if idx == 0 then
			local nockOffset = otherHandProp:GetBoundingMins().x * otherHandProp:GetAbsScale()
			propNockOrigin = otherHandProp:GetOrigin() +
				RotatePosition(Vector(0,0,0), otherHandProp:GetAngles(), Vector(nockOffset, 0, 0))
		end
		
		local propDist = (drawTool:GetOrigin() - propNockOrigin):Length()
		
		if propDist > 16 then
			ParticleManager:DestroyParticle(nockGuideParticle, true)
			nockGuideParticle = -1
			return
				
		elseif propDist > 2 then
		
			if nockGuideParticle == -1 then
				nockGuideParticle = ParticleManager:CreateParticle("particles/tools/bow_nock_guide.vpcf", 
					PATTACH_CUSTOMORIGIN, handAttachment)
				ParticleManager:SetParticleControlEnt(nockGuideParticle, 0, drawTool,
					PATTACH_CUSTOMORIGIN_FOLLOW, "", Vector(0,0,0), true)
				--ParticleManager:SetParticleControlEnt(nockGuideParticle, 1, otherHandProp,
					--PATTACH_CUSTOMORIGIN_FOLLOW, "", propNockOrigin, true)
				
				ParticleManager:SetParticleControl(nockGuideParticle, 3, Vector(0.75, 0.75, 0.95))
			end
			
			ParticleManager:SetParticleControl(nockGuideParticle, 1, propNockOrigin)
			
			return
		
		end
		
		ParticleManager:DestroyParticle(nockGuideParticle, true)
		nockGuideParticle = -1
		
		arrow = otherHandProp
		
		playerEnt:EquipPropTool(drawTool, otherHand)
		
		arrow:SetParent(bowView, "arrow_back")
		arrow:SetLocalOrigin(Vector(0,0,0))
		arrow:SetLocalAngles(0, 0, 0)
		
		local arrowOrigin = arrow:GetAbsOrigin()
		
		local idx = arrow:ScriptLookupAttachment("arrow_nock")	
		local nockOrigin = arrow:GetAttachmentOrigin(idx)
		
		-- Approximate if no attachment point available
		if idx == 0 then
			local nockOffset = arrow:GetBoundingMins().x * arrow:GetAbsScale()
			nockOrigin = arrowOrigin +
				RotatePosition(Vector(0,0,0), handAttachment:GetAngles(), Vector(nockOffset, 0, 0))
		end
		
		local idx = handAttachment:ScriptLookupAttachment("arrow_back")	
		local stringOrigin = handAttachment:GetAttachmentOrigin(idx)
				
		arrow:SetAbsOrigin(stringOrigin - nockOrigin + arrowOrigin)
		
		local idx = arrow:ScriptLookupAttachment("arrow_nock")	
		local ang = arrow:GetAttachmentAngles(idx)
		local nockAngles = QAngle(ang.x, ang.y, ang.z) 
		arrow:SetAbsAngles(nockAngles.x, nockAngles.y, nockAngles.z)
		
		arrowNocked = true
		drawTime = Time()			
	
		return

	end
	
	for _, entClass in ipairs(PHYS_ENTITIES) do
		
		for _, prop in ipairs(Entities:FindAllByClassname(entClass)) do
		
			local propHand = GetHandHoldingEntity(prop)
			
			if propHand and propHand:GetPlayer() == playerEnt
				and propHand:GetHandID() == otherHand then	
				otherHandProp = prop
				return
			end
		end
	end
end


function SpawnArrow()
	local keyvals = vlua.clone(ARROW_KEYVALS)
	keyvals.targetname = DoUniqueString(keyvals.targetname)
	arrow = SpawnEntityFromTableSynchronous(keyvals.classname, keyvals)
	arrow:SetParent(bowView, "arrow_back")
	arrow:SetLocalOrigin(Vector(0,0,0))
	arrow:SetLocalAngles(0, 0, 0)
	
end


function FireArrow()

	arrow:SetParent(nil, "")
	local massFac = 1
	
	local arrowMass = arrow:GetMass()
	if arrowMass > 1 then
		massFac = (1 - arrowMass * 0.5 / (arrowMass * 0.5 + 1))
	end
	
	local otherHand = (handID == 0 and 1 or 0)
	playerEnt:GetHMDAvatar():GetVRHand(otherHand):FireHapticPulse(2)
	thisEntity:SetThink(FireRumble, "fire_rumble", 0.0)
	
	
	arrow:ApplyAbsVelocityImpulse(arrow:GetAngles():Forward() * 3000  * drawFrac * massFac)
	--arrow:ApplyLocalAngularVelocityImpulse(Vector(10000 * drawFrac, 0, 0))
	local scope = arrow:GetPrivateScriptScope()
	if scope then
		if scope.EnableDamage then
			arrow:GetOrCreatePrivateScriptScope():EnableDamage(playerEnt)
		end
		
		if scope.OnPickedUp and arrow:GetModelName() == "models/third_party/props/toys/neko_plushie.vmdl" then
			-- Faart!
			scope:OnPickedUp(nil, nil)
		end
		
	end
	
	arrow = nil
end


function FireRumble(self)
	if handEnt
	then
		handEnt:FireHapticPulse(2)
	end
	
	fireRumbleElapsed = fireRumbleElapsed + FIRE_RUMBLE_INTERVAL
	if fireRumbleElapsed >= FIRE_RUMBLE_TIME
	then
		fireRumbleElapsed = 0
		return nil
	end
	
	return FIRE_RUMBLE_INTERVAL
end



function sign(x)
	return x > 0 and 1 or x < 0 and -1 or 1
end


