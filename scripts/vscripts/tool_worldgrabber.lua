--[[
	World grabber script.
	
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

local IS_WORLD_GRABBER = true
local GRAB_MAX_DISTANCE = 2
local GRAB_PULL_MIN_DISTANCE = 0.1
local GRAB_MOVE_INTERVAL = 0.02
local MUZZLE_OFFSET = Vector(0, 0, -0.2)
local MUZZLE_ANGLES_OFFSET = QAngle(90, 0, 0) 

local GRAB_PULL_PLAYER_SPEED = 8
local GRAB_PULL_PLAYER_EASE_DISTANCE = 16
local GRAB_TRACE_INTERVAL = 0.02
local ROATATION_ANGLE_MAX_RATE = 10
local MIN_ROTATE_DISTANCE = 4


local isCarried = false
local playerEnt = nil
local handEnt = nil
local otherHandObj = nil
local handID = 0
local handAttachment = nil

local grabEndpoint = nil
local playerMoved = false


local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0


local isGrabbing = false
local grabAngles = nil
local startRotateVec = nil
local startAngles = nil

local originEnt = nil




function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	otherHandObj = nil
	
	if not originEnt
	then
		
		-- Parenting an entity to the hand gives a less janky position than using the tool or attachment. 
		originEnt = SpawnEntityFromTableSynchronous("info_target", {origin = thisEntity:GetOrigin()})
		originEnt:SetParent(handEnt, "")
	end
	
	return true
end

function SetUnequipped()
	if isGrabbing
	then
		ReleaseHold(self)
		isGrabbing = false
	end
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	
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
		OnTriggerPressed(self)
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
		OnTriggerUnpressed(self)
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool();
	end


	return input;
end


function OnTriggerPressed(self)
	grabEndpoint = GetMuzzlePos()
	isGrabbing = true
	g_VRScript.playerPhysController:AddConstraint(playerEnt, thisEntity, true)
	thisEntity:SetThink(GrabMoveFrame, "grab_move")
	
	
end


function OnTriggerUnpressed(self)

	if isGrabbing
	then
		ReleaseHold(self)
		isGrabbing = false
	end
end




function ReleaseHold(self)
	startRotateVec = nil
	startAngles = nil
	RumbleController(thisEntity, 2, 0.4, 20)
	
	g_VRScript.playerPhysController:RemoveConstraint(playerEnt, thisEntity)
	
end

function GetPlayerEnt()
	return playerEnt
end

function GetOriginEnt()
	return originEnt
end


function GetGrabStatus(self)
	return isGrabbing
end

function FindTool(handID)
	local tool = Entities:FindByClassname(nil, "prop_destinations_tool")
	while tool 
	do
		if tool ~= thisEntity
		then
			local scope = tool:GetPrivateScriptScope()
			if scope.GetPlayerEnt and scope.GetPlayerEnt() == playerEnt
			then
				return tool
			end		
		end
		tool = Entities:FindByClassname(tool, "prop_destinations_tool")
	end
	
	return nil	 
end


function GrabMoveFrame(self)
	if not isGrabbing
	then
		return nil
	end
	
	if not g_VRScript.playerPhysController:IsActive(playerEnt, thisEntity)
	then
		return GRAB_MOVE_INTERVAL
	end
	
	if not otherHandObj or otherHandObj:IsNull() or otherHandObj:GetPrivateScriptScope():GetPlayerEnt() ~= playerEnt
	then
		otherHandObj = FindTool((handID == 0 and 1 or 0))
	end
	
	if otherHandObj ~= nil
	then
		local otherHandScope = otherHandObj:GetPrivateScriptScope()
	
		if otherHandScope ~= nil and otherHandScope.GetGrabStatus and otherHandScope:GetGrabStatus()
		then
			local origin2D = Vector(originEnt:GetOrigin().x, originEnt:GetOrigin().y, 0)
			local otherOrigin2D = Vector(otherHandScope:GetOriginEnt():GetOrigin().x, otherHandScope:GetOriginEnt():GetOrigin().y, 0)
			--DebugDrawLine(originEnt:GetOrigin(), otherHandScope:GetOriginEnt():GetOrigin(), 255, 0, 0, false, 0.02)
			
			local rotateVector = otherOrigin2D - origin2D 
			
			if rotateVector:Length() > MIN_ROTATE_DISTANCE
			then
				if not startRotateVec
				then
					startRotateVec = rotateVector
					startAngles = playerEnt:GetHMDAnchor():GetAngles()
				end
					
				local rotateOrigin = origin2D + rotateVector * 0.5
	
				local rotAng = NormalizeAngle((VectorToAngles(startRotateVec).y - VectorToAngles(rotateVector).y)) / 5
				
				if abs(rotAng) < 0.1
				then
					rotAng = 0
				elseif rotAng > ROATATION_ANGLE_MAX_RATE
				then
					rotAng = ROATATION_ANGLE_MAX_RATE
				elseif rotAng < -ROATATION_ANGLE_MAX_RATE
				then
					rotAng = -ROATATION_ANGLE_MAX_RATE
				end
				
				if abs(rotAng) > 0.5
				then
					handEnt:FireHapticPulse(0)
					playerEnt:GetHMDAvatar():GetVRHand((handID == 0 and 1 or 0)):FireHapticPulse(0)
				end
				
				local rotation = QAngle(0, rotAng, 0)
	
				local playerAng = playerEnt:GetHMDAnchor():GetAngles()
				local endRot = RotateOrientation(playerAng, rotation)
				playerEnt:GetHMDAnchor():SetAngles(endRot.x, endRot.y, endRot.z)
				local moveVector = RotatePosition(rotateOrigin, rotation, playerEnt:GetHMDAnchor():GetOrigin())
				playerEnt:GetHMDAnchor():SetOrigin(moveVector)
			end
			
		else
			startRotateVec = nil
		end
	end
	
	local pullVector = nil
	local pullPos = GetMuzzlePos()
	
	local gunRelativePos = pullPos - playerEnt:GetHMDAnchor():GetOrigin()
	
	
	pullVector = (grabEndpoint - pullPos):Normalized() * GRAB_PULL_PLAYER_SPEED
	 
	local distance = (grabEndpoint - pullPos):Length()

	
	if distance > GRAB_PULL_MIN_DISTANCE
	then
		if distance < GRAB_PULL_PLAYER_EASE_DISTANCE
		then 
			pullVector = pullVector * distance / GRAB_PULL_PLAYER_EASE_DISTANCE
		end
		-- Prevent player from going through floors
		if pullVector.z < 0 and g_VRScript.playerPhysController:TracePlayerHeight(playerEnt) <= 0
		then
			pullVector = pullVector - Vector(0, 0, pullVector.z)
		end
			
		playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + pullVector)
	end
		
	return GRAB_MOVE_INTERVAL
end


function NormalizeAngle(angle)
	if angle > 180
	then 
		return angle - 360
	elseif angle < -180
	then
		return angle + 360
	end
	
	return angle
end


function RumbleController(self, intensity, length, frequency)
	if handEnt
	then
		if rumbleTime == 0
		then
			rumbleTime = length
			rumbleFreq = frequency
			rumbleInt = intensity
		end
		
		handEnt:FireHapticPulse(rumbleInt)
		
		local interval = 1 / rumbleFreq
		
		rumbleTime = rumbleTime - interval
		if rumbleTime < interval
		then
			rumbleTime = 0
			return nil
		end
	
		return interval
	end
	
	rumbleTime = 0
	return nil
end

function GetMuzzlePos()
	local idx = thisEntity:ScriptLookupAttachment("grabpoint")
	return thisEntity:GetAttachmentOrigin(idx)
end
