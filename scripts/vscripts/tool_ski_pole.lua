--[[
	Ski pole script.
	
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


local GRAB_MAX_DISTANCE = 38
local GRAB_PULL_MIN_DISTANCE = 0

local MUZZLE_OFFSET = Vector(8, 0, 1.5)
local MUZZLE_ANGLES_OFFSET = QAngle(90, 0, 0) 

--local PUSH_LIFT_DISTANCE = 6
local GRAB_PULL_PLAYER_SPEED = 64
local GRAB_PULL_PLAYER_EASE_DISTANCE = 0.1
local PUSH_TRACE_INTERVAL = 0.02

local CARRY_OFFSET = Vector(28, 0, -0.5)
local CARRY_ANGLES = QAngle(-90, 0, 0)

local isCarried = false
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local grabEndpoint = nil
local playerMoved = false
--local playLifted = false
local rotated = false

local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0

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
	
	thisEntity:SetThink(TracePush, "trace_push", 0.5)
	playerMoved = false
	isTargeting = true
	rotated = false
	return true
end

function SetUnequipped()
	
	isTargeting = false
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	isTargeting = false
	
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




function OnDropped(self, hand, player)
	hand:RemoveHandModelOverride("models/weapons/hand_dummy.vmdl")
	
	playerEnt = nil
	handEnt = nil
	isTargeting = false

	thisEntity:SetParent(nil, "")
end



function TracePush(self)
	if not isTargeting
	then 
		return nil
	end

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(GRAB_MAX_DISTANCE, 0, 0));
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
		
			if traceTable.enthit:GetPrivateScriptScope() and 
				traceTable.enthit:GetPrivateScriptScope().OnHurt
			then
				traceTable.enthit:GetPrivateScriptScope().OnHurt()
			end
		end 
	
		if not playerMoved
		then
			StartSoundEvent("SkiPole.Hit", thisEntity)
			RumbleController(2, 0.2, 20)
			grabEndpoint = traceTable.pos
			playerMoved = true
			
		end
	
		local distanceVector = (grabEndpoint - traceTable.pos)
		distanceVector = distanceVector - Vector(0, 0, distanceVector.z)
		
		local pullVector = distanceVector:Normalized()
		pullVector = pullVector - Vector(0, 0, pullVector.z)
		
		local depth = GRAB_MAX_DISTANCE - (traceTable.pos - traceTable.startpos):Length()
		
		local distance = distanceVector:Length()
		--DebugDrawLine(traceTable.pos, grabEndpoint, 0, 255, 0, false, 0.02)
		
		local vec = (traceTable.startpos - traceTable.pos):Normalized()
		local coDirection = pullVector:Normalized():Dot(Vector(vec.x, vec.y, 0))
		
		-- If the pole is dragging along the ground in the opposite direction of the staking.
		if coDirection < 0
		then
			coDirection = 0
			
			grabEndpoint = traceTable.pos
			
		else
			pullVector = pullVector * coDirection
		
			if distance > GRAB_PULL_MIN_DISTANCE
			then
				if distance < GRAB_PULL_PLAYER_SPEED
				then 
					pullVector = pullVector * distance
				else
					pullVector = pullVector * GRAB_PULL_PLAYER_SPEED
				end
	
				--pullVector = pullVector - Vector(0, 0, pullVector.z)
	
				--[[if depth < PUSH_LIFT_DISTANCE
				then
					if playLifted
					then
						g_VRScript.fallController:RemoveConstraint(playerEnt, thisEntity)
						playLifted = false
					end
				else
					pullVector = pullVector + Vector(0, 0, GRAB_PULL_PLAYER_SPEED * (depth - PUSH_LIFT_DISTANCE) / GRAB_MAX_DISTANCE)
					if not playLifted
					then
						playLifted = true
						g_VRScript.fallController:AddConstraint(playerEnt, thisEntity, true)
					end
				end]]
				
				pullVector = pullVector - Vector(0, 0, pullVector.z)
	
				g_VRScript.fallController:AddVelocity(playerEnt, pullVector)
				--playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + pullVector)
			end
		end
	
	else
		if playerMoved
		then
			RumbleController(2, 0.4, 20)
			playerMoved = false
			--[[if playLifted
			then
				g_VRScript.fallController:RemoveConstraint(playerEnt, thisEntity)
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

function GetMuzzlePos()
	return thisEntity:GetAbsOrigin() + RotatePosition(Vector(0,0,0), 
			RotateOrientation(thisEntity:GetAngles(), CARRY_ANGLES), MUZZLE_OFFSET)
end

