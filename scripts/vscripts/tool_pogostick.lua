--[[
	Pogo stick script.
	
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




local SPRING_FORCE = 150
local BOOST_FORCE = 50
local PUSH_TRACE_INTERVAL = 0.02


local isCarried = false
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local grabEndpoint = nil
local playerMoved = false


local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0
local triggerValue = 0

local isTargeting = false



function Precache(context)

	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end



function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	handAttachment:SetSequence("contract")
	local color = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(color.x, color.y, color.z)
	g_VRScript.playerPhysController:AddConstraint(playerEnt, thisEntity)
	
	thisEntity:SetThink(TracePush, "trace_push", 0.5)
	playerMoved = false
	isTargeting = true
	rotated = false
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	return true
end

function SetUnequipped()
	g_VRScript.playerPhysController:RemoveConstraint(playerEnt, thisEntity)
	isTargeting = false
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	isTargeting = false
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
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

	triggerValue = input.triggerValue
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
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

	return input;
end



function TracePush(self)
	if not isTargeting
	then 
		return nil
	end

	local traceTable =
	{
		startpos = GetSpringStart();
		endpos = GetSpringEnd();
		ignore = playerEnt
	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.01)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.02)
		
		
		if traceTable.enthit 
		then
			if traceTable.enthit == thisEntity
			then
				return PUSH_TRACE_INTERVAL
			end
		
		end 
	
		if not playerMoved
		then
			StartSoundEvent("SkiPole.Hit", thisEntity)
			RumbleController(2, 0.2, 20)
			playerMoved = true
			
		end
	
		local jumpDir = GetSpringDir()
		local distance = (1 - traceTable.fraction)
		handAttachment:SetPoseParameter("spring", distance * 12 * 3.7)
		local impulse = jumpDir * -distance * SPRING_FORCE * -Clamp((jumpDir:Dot(traceTable.normal) + 0.1), -1, 0) 
			- jumpDir * triggerValue * BOOST_FORCE
		
		if g_VRScript.playerPhysController:IsPlayerOnGround(playerEnt)
		then
			impulse = Vector(0, 0, impulse.z)
		end
		
		g_VRScript.playerPhysController:AddVelocity(playerEnt, impulse)		
	
	else
		handAttachment:SetPoseParameter("spring", 0)
		if playerMoved
		then
			RumbleController(2, 0.4, 20)
			playerMoved = false
			--[[if playLifted
			then
				g_VRScript.playerPhysController:RemoveConstraint(playerEnt, thisEntity)
				playLifted = false
			end]]
		end	
	end
	
	return PUSH_TRACE_INTERVAL
end



function RumbleController(intensity, length, frequency)
	if handEnt
	then
		rumbleTime = length
		rumbleFreq = frequency
		rumbleInt = intensity
	end
	thisEntity:SetThink(RumbleThink, "rumble", 1 / rumbleFreq)
end
		
function RumbleThink()
	local interval = 1 / rumbleFreq
	if handEnt
	then
		handEnt:FireHapticPulse(rumbleInt)
		
		rumbleTime = rumbleTime - interval
		if rumbleTime < interval
		then
			rumbleTime = 0
			return nil
		end
	
		return interval
	end
	return nil
end

function Clamp(val, min, max)
	if val > max then return max end
	if val < min then return min end
	return val	
end


function GetSpringStart()
	local idx = handAttachment:ScriptLookupAttachment("spring_start")
	return handAttachment:GetAttachmentOrigin(idx)
end

function GetSpringEnd()
	local idx = handAttachment:ScriptLookupAttachment("spring_end")
	return handAttachment:GetAttachmentOrigin(idx)
end

function GetSpringDir()
	return (GetSpringEnd() - GetSpringStart()):Normalized()
end

