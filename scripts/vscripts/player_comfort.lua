

CPlayerComfort = class(
	{
		player = nil;
		gridSetting = 0;
		gridParticleIndex = -1;
		vignetteEnabled = false;
		vignetteParticleIndex = -1;
		lastMovement = 0;
		lastRotation = 0;
	}, 
	
	{
		IDLE_DELAY = 0.25;
	},
	nil
)


function CPlayerComfort.constructor(self, player)
	self.player = player
	self:SetGrid(g_VRScript.playerSettings:GetPlayerSetting(self.player, "comfort_grid"))
	self:SetVignette(g_VRScript.playerSettings:GetPlayerSetting(self.player, "comfort_vignette"))
	
end


function CPlayerComfort:SetGrid(setting)
	
	self.gridSetting = setting
end

function CPlayerComfort:SetVignette(setting)
	
	self.vignetteEnabled = setting
end




function CPlayerComfort:Think()

	local moving = true
	local rotating = true
	
	if g_VRScript.playerPhysController:IsMoving(self.player)
	then
		self.lastMovement = Time()
	else
		moving = Time() - self.lastMovement < self.IDLE_DELAY
	end
	
	if g_VRScript.playerPhysController:IsRotating(self.player)
	then
		self.lastRotation = Time()
	else
		rotating = Time() - self.lastRotation < self.IDLE_DELAY
	end
	
	local gridOn = self.gridSetting == 3 or (self.gridSetting == 2 and moving) or (self.gridSetting > 0 and rotating)	
	
	if gridOn and self.gridParticleIndex == -1
	then
		self:SpawnGrid()
		
	elseif not gridOn and self.gridParticleIndex ~= -1
	then
		ParticleManager:DestroyParticle(self.gridParticleIndex, false)
		self.gridParticleIndex = -1
	end
	
	local vignetteOn = self.vignetteEnabled and (moving or rotating) 
	
	if vignetteOn and self.vignetteParticleIndex == -1
	then
		self:SpawnVignette()
		
	elseif not vignetteOn and self.vignetteParticleIndex ~= -1
	then
		ParticleManager:DestroyParticle(self.vignetteParticleIndex, false)
		self.vignetteParticleIndex = -1
	end
	
end



function CPlayerComfort:SpawnGrid()
	
	local anchor = self.player:GetHMDAnchor()
	local spawnOrigin = self.player:GetAbsOrigin()
	
	self.gridParticleIndex = ParticleManager:CreateParticleForPlayer("particles/ui/comfort_grid.vpcf", 
		PATTACH_ABSORIGIN_FOLLOW, anchor, self.player)
	
	ParticleManager:SetParticleControlEnt(self.gridParticleIndex, 1, self.player, PATTACH_ABSORIGIN_FOLLOW, nil, Vector(0,0,0), true) 
end


function CPlayerComfort:SpawnVignette()
	
	self.vignetteParticleIndex = ParticleManager:CreateParticleForPlayer("particles/ui/comfort_vignette.vpcf", 
		PATTACH_MAIN_VIEW, self.player, self.player)
end





