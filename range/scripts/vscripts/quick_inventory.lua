

CQuickInventory = class(
	{
		player = nil;
		itemList = nil;
		enabledItems = nil;
		handItems = nil;
		highlighted = nil;
	}, 
	
	{
		SELECT_RADIUS = 4;
	},
	nil
)


function CQuickInventory.constructor(self, player, itemList)
	self.player = player
	self.itemList = itemList
	self.enabledItems = g_VRScript.playerSettings:GetPlayerSetting(self.player, "quick_inv_items") or {}
	self.handItems = {}
	self.highlighted = {}
end


function CQuickInventory:AddItem(itemID)

	for i, id in ipairs(self.enabledItems)
	do
		if id == itemID then return end
	end

	self.enabledItems[#self.enabledItems + 1] = itemID
	g_VRScript.playerSettings:SetPlayerSetting(self.player, "quick_inv_items", self.enabledItems, true)
end


function CQuickInventory:RemoveItem(itemID)

	for i, id in ipairs(self.enabledItems)
	do
		if id == itemID 
		then 
		table.remove(self.enabledItems, i)
		g_VRScript.playerSettings:SetPlayerSetting(self.player, "quick_inv_items", self.enabledItems, true)
		return
		end
	end
end


function CQuickInventory:Think(isQuickInvEnabled)

	local hmd = self.player:GetHMDAvatar()
	if not hmd then return end

	for handID = 0, 1
	do	
		local handEnt = hmd:GetVRHand(handID)
		local actionActive = self.player:IsActionActiveForHand(handEnt:GetLiteralHandType() , DEFAULT_SHOW_INVENTORY) 
			and isQuickInvEnabled
	
		local isMenuOpen = self.handItems[handID] ~= nil
	
		if not isMenuOpen and actionActive
		then	
			self:OpenInventoryMenu(handID, handEnt)
			
		elseif isMenuOpen and not actionActive
		then	
			local selectedItem = self:CloseInventoryMenu(handID, handEnt)
			
			if selectedItem 
			then
				self:SpawnItem(selectedItem, handEnt)
			end		
			
		elseif isMenuOpen and actionActive
		then
			local pickPos = handEnt:GetCenter() - handEnt:GetAngles():Forward() * 5
			for id, ent in pairs(self.handItems[handID])
			do
				if (pickPos - ent:GetOrigin()):Length() <= self.SELECT_RADIUS
				then
					if not self.highlighted[handID]
					then 
						self.highlighted[handID] = id
						DoEntFireByInstanceHandle(ent, "StartGlowing", "", 0, nil, nil)
						EmitSoundOn("inventory_select", ent)	
					end 
					
				elseif self.highlighted[handID] == id
				then
					DoEntFireByInstanceHandle(ent, "StopGlowing", "", 0, nil, nil) 
					self.highlighted[handID] = nil
				end
			end
		end	
	end
end


function CQuickInventory:OpenInventoryMenu(handID, handEnt)
	self.handItems[handID] = {}
			
	local placeAngle = 45
	
	if #self.enabledItems > 18
	then
		placeAngle = 360 / (#self.enabledItems - 1)
	
	elseif #self.enabledItems > 5
	then
		placeAngle =  (180 + (#self.enabledItems - 5) * 15) / (#self.enabledItems - 1)
	end
	
	for i, itemID in ipairs(self.enabledItems)
	do
		local ang = RotateOrientation(handEnt:GetAngles(), QAngle(0, -placeAngle * (i - #self.enabledItems / 2), 0))
		local keyvals = {}
		
		if self.itemList[itemID].quickInvModel
		then
			keyvals.model = self.itemList[itemID].quickInvModel
		else
			keyvals.model = self.itemList[itemID].keyvals.model
		end
		
		if self.itemList[itemID].keyvals.rendercolor
		then
			keyvals.rendercolor = self.itemList[itemID].keyvals.rendercolor
		end
		keyvals.origin = handEnt:GetCenter() + ang:Forward() * 8 - handEnt:GetAngles():Forward() * 5
		keyvals.angles = ang
		keyvals.solid = 0
		keyvals.scales = Vector(0.5, 0.5, 0.5)
		keyvals.glowcolor = "128 128 255 255"
		keyvals.glowstate = 0
			
		local ent = SpawnEntityFromTableSynchronous("prop_dynamic", keyvals)
	
		self.handItems[handID][itemID] = ent
	end
end


function CQuickInventory:CloseInventoryMenu(handID, handEnt)

	local activeItem = nil

	for id, ent in pairs(self.handItems[handID])
	do
		ent:Kill()
	end
	
	if self.highlighted[handID]
	then
		activeItem = self.highlighted[handID]
	end
	
	self.highlighted[handID] = nil
	self.handItems[handID] = nil
	
	return activeItem
end


function CQuickInventory:SpawnItem(itemID, handEnt)
	
	print("Quick inventory spawning item ID: " .. itemID)
	
	local item = self.itemList[itemID]	
	local keyvals = vlua.clone(item.keyvals)

	keyvals.origin = handEnt:GetOrigin()
	keyvals.angles = handEnt:GetAngles()
		
	if item.isTool then
		local ent = SpawnEntityFromTableSynchronous("prop_destinations_tool", keyvals)
	
		self.player:EquipPropTool(ent, handEnt:GetHandID())
		
		EmitSoundOn("default_equip", handEnt)	
	else
		SpawnEntityFromTableSynchronous("prop_destinations_physics", keyvals)
	end	
end

