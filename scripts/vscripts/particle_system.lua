--[[
	Wrapper class for particle systems.
	
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

ParticleSystem = class(
	{
		entity = nil;
		name = "";
		controlPoints = {}
	}, 
	
	{},
	nil
)


function ParticleSystem:constructor(particleName, startActive)

	self.controlPoints = {}; 
	self.name = DoUniqueString("script_particle");

	local keyvals = {
	classname = "info_particle_system";
	targetname = self.name;
	effect_name = particleName;
	start_active = startActive;
	cpoint1 = self.name .. "_cp1";
	cpoint2 = self.name .. "_cp2";
	cpoint3 = self.name .. "_cp3";
	cpoint4 = self.name .. "_cp4";
	cpoint5 = self.name .. "_cp5";
	cpoint6 = self.name .. "_cp6";
	cpoint7 = self.name .. "_cp7";
	cpoint8 = self.name .. "_cp8"
	
	}
	
	self.entity = SpawnEntityFromTableSynchronous(keyvals.classname, keyvals)
	
	if self.entity and startActive
	then
		DoEntFireByInstanceHandle(self.entity, "Start", "", 0, nil, nil)
	end
end


function ParticleSystem:GetEntity()
	return self.entity
end


function ParticleSystem:SetOrigin(origin)
	self.entity:SetOrigin(origin)
end

function ParticleSystem:SetAngles(x, y, z)
	self.entity:SetAngles(x, y, z)
end


function ParticleSystem:SetParent(parent, attachment)
	self.entity:SetParent(parent, attachment)
end


function ParticleSystem:Start()
	DoEntFireByInstanceHandle(self.entity, "Start", "", 0, nil, nil)
end


function ParticleSystem:Stop(delay)
	delay = delay or 0
	DoEntFireByInstanceHandle(self.entity, "Stop", "", delay, nil, nil)
end


function ParticleSystem:StopPlayEndcap()
	DoEntFireByInstanceHandle(self.entity, "StopPlayEndcap", "", 0, nil, nil)
end


function ParticleSystem:DestroyImmediately()
	DoEntFireByInstanceHandle(self.entity, "DestroyImmediately", "", 0, nil, nil)
end


function ParticleSystem:CreateControlPoint(num, origin, parent, parentAttachment)

	local cp = SpawnEntityFromTableSynchronous("info_particle_target", {targetname = self.name .. "_cp" .. tostring(num)})
	
	if not cp
	then
		return nil
	end
	
	if parent
	then
		cp:SetParent(parent, parentAttachment)
	end
	
	if origin
	then
		cp:SetOrigin(origin)
	end
	
	self.controlPoints[num] = cp
	
	return cp
end


function ParticleSystem:GetControlPoint(num)
	return self.controlPoints[num]
end


function ParticleSystem:Kill()
	for _, cp in pairs(self.controlPoints)
	do
		UTIL_Remove(cp)
	end
	DoEntFireByInstanceHandle(self.entity, "DestroyImmediately", "", 0, nil, nil)
	UTIL_Remove(self.entity)
	self.entity = nil
	self.controlPoints = {}
end


function ParticleSystem:KillDelayed(time)
	entity:SetThink("kill", entity.Kill, time)
end
