
--[[
	Paper plane prop script.
	
	Copyright (c) 2019 Rectus
	
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


local INTERVAL = 0.022
local LIFT_FACTOR = 10
local LIFT_TORQUE_FACTOR = 0.4
local YAW_AXIS = Vector(0,0,1)
local PITCH_AXIS = Vector(0,-1,0)
local ROLL_AXIS = Vector(1,0,0)
local handVel = nil

function Precache(context)

	PrecacheParticle("particles/paper_plane_disintegrate.vpcf", context)
end

function Activate()
	thisEntity:SetThink(Think, "think", INTERVAL)
end

function OnTakeDamage()
	local particle = ParticleManager:CreateParticle("particles/paper_plane_disintegrate.vpcf", 
		PATTACH_ABSORIGIN, thisEntity)
	ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0))
	ParticleManager:SetParticleControlEnt(particle, 0, thisEntity, PATTACH_ABSORIGIN, nil, Vector(0,0,0), false)
	StartSoundEvent("Paper_Plane_Explode", thisEntity)
	thisEntity:Destroy()
	
end


function Think()
	
	local angleVecs = thisEntity:GetAttachmentAngles(thisEntity:ScriptLookupAttachment("lift_directions")) 
	local angles = QAngle(angleVecs.x, angleVecs.y, angleVecs.z)

	-- For lift
	local sideDir = angles:Left()
	local liftDir = angles:Up()
	local forwardDir = angles:Forward()
	
	-- For air resistance
	local aeroUp = thisEntity:GetAngles():Up() 
	local aeroFwd = thisEntity:GetAngles():Forward() 
	

	local inAngVel = GetPhysAngularVelocity(thisEntity)
	local inVel = GetPhysVelocity(thisEntity)
	local normAngVel = inAngVel:Normalized()
	local normVel = inVel:Normalized()
	local speed = inVel:Length()
	
	local angleOfAttack = normVel:Cross(sideDir):Cross(sideDir):Dot(liftDir)
	
	local impulseMagnitude = angleOfAttack * speed * LIFT_FACTOR * INTERVAL -- This is signed
	local dragLossVec = (normVel - (forwardDir * normVel:Dot(forwardDir)) ) * abs(impulseMagnitude)
	
	local slowDampingFactor = 0.01 --Lerp(abs(normAngVel:Dot(PITCH_AXIS)), Lerp(abs(normAngVel:Dot(YAW_AXIS)), 0.01, 0.015), 0.1)
	local fastDampingFactor = Lerp(abs(normAngVel:Dot(PITCH_AXIS)), Lerp(abs(normAngVel:Dot(YAW_AXIS)), 0.02, 0.1), 0.05)	
	local dampingFactor = Lerp(Clamp(speed / 200, 0, 1), slowDampingFactor, fastDampingFactor)
	
	SetPhysAngularVelocity(thisEntity, VectorLerp(dampingFactor, inAngVel,  Vector(0,0,0)))
	
	thisEntity:ApplyAbsVelocityImpulse(liftDir * impulseMagnitude - dragLossVec) 
	thisEntity:ApplyLocalAngularVelocityImpulse(PITCH_AXIS * abs(impulseMagnitude) * LIFT_TORQUE_FACTOR)
	
	--DebugDrawLine(thisEntity:GetOrigin(), thisEntity:GetOrigin() + dragLossVec * 10, 0, 255, 0, false, INTERVAL) 
	--DebugDrawLine(thisEntity:GetOrigin(), thisEntity:GetOrigin() + liftDir * speed * angleOfAttack * LIFT_FACTOR, 0, 255, 0, false, INTERVAL) 
	return INTERVAL
end

function OnDropped(this, hand)
	handVel = hand:GetVelocity()  
	thisEntity:SetThink(Boost, "boost", 0.05)
	
end

function Boost()
	local forwardDir = thisEntity:GetAngles():Forward()
	thisEntity:ApplyAbsVelocityImpulse(forwardDir * 3 * handVel:Dot(forwardDir)) 
end

