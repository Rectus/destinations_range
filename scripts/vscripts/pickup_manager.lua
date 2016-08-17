--[[
	Class that manages carryable items.
	
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

PickupManager = class(
	{
		entities = {};
		players = {}; 
		--player.buttons = {};
		--player.carrySlots = {};
		initialized = false
	}, 
	
	{
		PICKUP_RANGE = 4;
		
		-- Controller buttons.
		IN_USE_HAND0 = 24;
		IN_USE_HAND1 = 25;
		IN_PAD_LEFT_HAND0 = 26;
		IN_PAD_RIGHT_HAND0 = 27;
		IN_PAD_UP_HAND0 = 28;
		IN_PAD_DOWN_HAND0 = 29;
		IN_PAD_LEFT_HAND1 = 30;
		IN_PAD_RIGHT_HAND1 = 31;
		IN_PAD_UP_HAND1 = 32;
		IN_PAD_DOWN_HAND1 = 33;
		IN_MENU_HAND0 = 34;
		IN_MENU_HAND1 = 35;
		IN_GRIP_HAND0 = 36;
		IN_GRIP_HAND1 = 37;
		IN_PAD_HAND0 = 38;
		IN_PAD_HAND1 = 39;
		IN_PAD_TOUCH_HAND0 = 40;
		IN_PAD_TOUCH_HAND1 = 41
	},
	nil
)

-- Registers a new entity to be tracked by the system.
function PickupManager:RegisterEntity(entity)
	self.entities[entity] = entity:GetPrivateScriptScope()
	print(" Pickup manager: " .. entity:GetClassname() .. ": " .. entity:GetName() .. " registered.")
	
	if self.initialized
	then
		if entity and entity:GetPrivateScriptScope().Init
		then
			entity:GetPrivateScriptScope():Init()
		end
	end
end


-- Polls the motion controller buttons.
function  PickupManager:OnThink()

	for playerEnt, properties in pairs(self.players)
	do
		for i = 24, 41, 1
		do
			local oldval = properties.buttons[i]
			properties.buttons[i] = playerEnt:IsVRControllerButtonPressed(i)
			
			if properties.buttons[i] ~= oldval
			then
				if properties.buttons[i] == true
				then
					self:ButtonPressed(i, playerEnt, properties)
				else
					self:ButtonUnpressed(i, playerEnt, properties)
				end
			end
		end
	end
	
end


function PickupManager:ButtonPressed(button, player, playerProps)
	--print("PickupManager:ButtonPressed(".. button ..")")

	if button == self.IN_GRIP_HAND0
	then
	   self:CheckPickup(player:GetHMDAvatar():GetVRHand(0), 0, player, playerProps)
	   
	elseif button == self.IN_GRIP_HAND1
	then
	   self:CheckPickup(player:GetHMDAvatar():GetVRHand(1), 1, player, playerProps)
	   
	elseif button == self.IN_USE_HAND0
	then
		if playerProps.carrySlots[0] and playerProps.carrySlots[0]:GetPrivateScriptScope().OnTriggerPressed
		then
			playerProps.carrySlots[0]:GetPrivateScriptScope():OnTriggerPressed()
		end
		
	elseif button == self.IN_USE_HAND1
	then
		if playerProps.carrySlots[1] and playerProps.carrySlots[1]:GetPrivateScriptScope().OnTriggerPressed
		then
			playerProps.carrySlots[1]:GetPrivateScriptScope():OnTriggerPressed()
		end
		
	elseif button == self.IN_PAD_HAND0
	then
		if playerProps.carrySlots[0] and playerProps.carrySlots[0]:GetPrivateScriptScope().OnPadPressed
		then
			playerProps.carrySlots[0]:GetPrivateScriptScope():OnPadPressed()
		end
		
	elseif button == self.IN_PAD_HAND1
	then
		if playerProps.carrySlots[1] and playerProps.carrySlots[1]:GetPrivateScriptScope().OnPadPressed
		then
			playerProps.carrySlots[1]:GetPrivateScriptScope():OnPadPressed()
		end
	end
	
end


function PickupManager:CheckPickup(hand, slot, player, playerProps)

  local closestEnt = nil
  local closestDist = 0
  local entDropped = false

  for entity, scope in pairs(self.entities)
  do
  	if entity:IsNull()
  	then
  		self.entities[entity] = nil
  	else
	    --print(entity:GetClassname())
	    local distance = CalcDistanceBetweenEntityOBB(entity, hand)
	    
	    if scope.isCarried and playerProps.carrySlots[slot] == entity
	    then 
	      entDropped = true
	      self.entities[entity].isCarried = false
	      playerProps.carrySlots[slot] = nil
	      
	      if entity:GetPrivateScriptScope().OnDropped
	      then
				entity:GetPrivateScriptScope():OnDropped(hand, player)
		  end
	      
	    elseif distance < PickupManager.PICKUP_RANGE and entDropped == false and not scope.isCarried
	    then
	      if closestEnt == nil or distance < closestDist
	      then
	        closestEnt = entity
	        closestDist = distance
	      end
	    end
	end
  end
  
  if closestEnt
  then
    
    self.entities[closestEnt].isCarried = true
    playerProps.carrySlots[slot] = closestEnt
    
    if closestEnt:GetPrivateScriptScope().OnPickedUp
	then
		closestEnt:GetPrivateScriptScope():OnPickedUp(hand, player)
	end
  end
end


function PickupManager:ButtonUnpressed(button, player, playerProps)
	--print("PickupManager:ButtonUnpressed(".. button ..")")
	
	if button == self.IN_USE_HAND0
	then
		if playerProps.carrySlots[0] and playerProps.carrySlots[0]:GetPrivateScriptScope().OnTriggerUnpressed
		then
			playerProps.carrySlots[0]:GetPrivateScriptScope():OnTriggerUnpressed()
		end
	elseif button == self.IN_USE_HAND1
	then
		if playerProps.carrySlots[1] and playerProps.carrySlots[1]:GetPrivateScriptScope().OnTriggerUnpressed
		then
			playerProps.carrySlots[1]:GetPrivateScriptScope():OnTriggerUnpressed()
		end
	elseif button == self.IN_PAD_HAND0
	then
		if playerProps.carrySlots[0] and playerProps.carrySlots[0]:GetPrivateScriptScope().OnPadUnpressed
		then
			playerProps.carrySlots[0]:GetPrivateScriptScope():OnPadUnpressed()
		end
		
	elseif button == self.IN_PAD_HAND1
	then
		if playerProps.carrySlots[1] and playerProps.carrySlots[1]:GetPrivateScriptScope().OnPadUnpressed
		then
			playerProps.carrySlots[1]:GetPrivateScriptScope():OnPadUnpressed()
		end
	
	end
end

--Call to set up everything.
function PickupManager:Initialize()
	
	self.initialized = false
	playerEnt = Entities:FindByClassname(nil, "player")
	
	while playerEnt
	do
		print("Found player: " .. playerEnt:GetDebugName())
		
		self.players[playerEnt] = {}
		self.players[playerEnt].carrySlots = {}
		self.players[playerEnt].buttons = {}
		
		for i = 24, 41, 1
		do	
			self.players[playerEnt].buttons[i] = false
		end
		
		playerEnt = Entities:FindByClassname(playerEnt, "player")
	end
	
		
	if self:GetTableSize(self.players) > 0
	then
		for entity, carried in pairs(self.entities)
		  do
		  	if entity:IsNull()
		  	then
		  		self.entities[entity] = nil
		  		
		  	else
				if entity and entity:GetPrivateScriptScope().Init
				then
					entity:GetPrivateScriptScope():Init()
				end
			end
		end
		ListenToGameEvent("player_spawn", EventPlayerSpawn, self)
		
		self.initialized = true
	end
	
	return self.initialized
end


function PickupManager:EventPlayerSpawn(params)

	local player = PlayerInstanceFromIndex(params.userid)

	self:AddPlayer(player)
end

-- register a new player.
function PickupManager:AddPlayer(player)
	if not players[player]
	then
		print(self.player:GetDebugName())
		
		self.players[playerEnt] = {}
		self.players[playerEnt].carrySlots = {}
		self.players[playerEnt].buttons = {}
		
		for i = 24, 41, 1
		do	
			self.players[playerEnt].buttons[i] = false
		end
	end
end

-- Utility function to read the number of elements in a table.
function PickupManager:GetTableSize(table)
	local size = 0
	for key in pairs(table)
	do
		size = size + 1
	end
	
	return size
end


