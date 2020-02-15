
print("Range map script")

-- What scripts to load for the player physics and pause menu.
require("player_physics")
require("pause_manager")

-- List of items spawnable from the spawn menu.
local SPAWN_ITEMS = 
{
	{
		name = "Locomotion tool",
		img = "file://{resources}/images/tool_locomotion.png",
		isTool = true,
		quickInvModel = "models/tools/locomotion_tool.vmdl",
		keyvals =
		{
			targetname = "",
			model = "models/tools/locomotion_tool_base.vmdl";
			vscripts = "tool_locomotion";
			HasCollisionInHand = 0;
		},
		modelPrecache = 
		{
			"models/tools/locomotion_tool.vmdl",
			"models/tools/locomotion_tool_grapple.vmdl",
			"models/tools/locomotion_tool_strap.vmdl"
		}
	},
	{
		name = "MAC-10 'n Beans",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/mac10/mac10.vmdl";
			vscripts = "tool_mac10";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Laser pistol",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/laser_pistol.vmdl";
			vscripts = "tool_laser_pistol";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Paper plane",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "",
			model = "models/props_toys/paper_plane1.vmdl";
			vscripts = "prop_paper_plane";
		}
	},
	{
		name = "Round bomb",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "",
			model = "models/props_toys/bomb.vmdl";
			vscripts = "prop_bomb";
			rendercolor = "40 39 39";
		},
		modelPrecache = 
		{
			"models/props_toys/bomb_fuse.vmdl"
		}
	},
	{
		name = "Longsword",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/longsword.vmdl";
			vscripts = "tool_sword";
			rendercolor = "240 240 160";
			HasCollisionInHand = 0;
		}
	},
	{
		name = "Spraypaint can",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/spraycan.vmdl";
			vscripts = "tool_spraycan";
			health = 100;
			HasCollisionInHand = 1;
			--physdamagescale = 1;
			
		},
		modelPrecache = 
		{
			"models/tools/spraycan_colorwheel.vmdl";
			"models/development/invisiblebox.vmdl"
		}
	},
	{
		name = "Recurve bow",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/bow.vmdl";
			vscripts = "tool_bow";
			HasCollisionInHand = 0;
		},
		modelPrecache = 
		{
			"models/weapons/bow_drawguide.vmdl",
			"models/weapons/arrow.vmdl"
		}
	},
	{
		name = "Ski pole",
		img = "file://{resources}/images/tool_skipole.png",
		isTool = true,
		keyvals =
		{
			targetname = "ski_pole_spawned",
			model = "models/props_slope/ski_pole_tool.vmdl";
			vscripts = "tool_ski_pole";
			HasCollisionInHand = 0;
		},
		modelPrecache = 
		{
			"models/props_slope/ski_pole_tool_animated.vmdl",
			"models/props_slope/ski_pole_tool_compass.vmdl",
			"models/props_slope/ski.vmdl"
		}
	},
	{
		name = "Boxing glove (left)",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/props_gameplay/boxing_gloves001_left.vmdl";
			vscripts = "tool_glove";
			HasCollisionInHand = 0;
		}
	},
	{
		name = "Boxing glove (right)",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/props_gameplay/boxing_gloves001_right.vmdl";
			vscripts = "tool_glove";
			HasCollisionInHand = 0;
		}
	},
	{
		name = "Jetpack",
		img = "file://{resources}/images/tool_jetpack.png",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/jetpack.vmdl";
			vscripts = "tool_jetpack";
			massScale = 0.2;
			HasCollisionInHand = 0;
		},
		modelPrecache = 
		{
			"models/tools/jetpack_equipped.vmdl",
			"models/tools/jetpack_navsphere.vmdl"
		}
	},
	{
		name = "Gravity Gun",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/hl2/w_physics_reference.vmdl";
			vscripts = "tool_gravity_gun";
			massScale = 0.2;
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Suction cup",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/suction_cup.vmdl";
			vscripts = "tool_suction_cup";
			HasCollisionInHand = 0;
		}
	},
	{
		name = "M72 LAW Rocket launcher",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/law_weapon.vmdl";
			vscripts = "tool_law";
			HasCollisionInHand = 1;
		},
		modelPrecache = 
		{
			"models/weapons/law_rocket.vmdl",
			"models/weapons/law_rocket_packed.vmdl"
		}
	},
	{
		name = "Barnacle Grapple",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/barnacle_gun.vmdl";
			vscripts = "tool_barnacle_gun";
			HasCollisionInHand = 0;
			scales = "0.8 0.8 0.8"
		}
	},
	{
		name = "Nailgun",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/nailgun.vmdl";
			vscripts = "tool_nailgun";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Mare's leg",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/mares_leg.vmdl";
			vscripts = "tool_mares_leg";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Pogo stick",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/pogostick.vmdl";
			vscripts = "tool_pogostick";
			HasCollisionInHand = 0;
			rendercolor = "250 0 0";
		}
	},
	{
		name = "Entity scanner",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/scanner.vmdl";
			vscripts = "tool_scanner";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Flashlight (Valve)",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/props_gameplay/flashlight001.vmdl";
			vscripts = "fl_test";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Flashlight (rusty)",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/props_beach/flashlight.vmdl";
			vscripts = "tool_flashlight";
			skin = "unlit";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Sunlight adjustment tool",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/sun_tool.vmdl";
			vscripts = "sun_tool";
			HasCollisionInHand = 1;
		},
		modelPrecache = 
		{
			"models/tools/sun_tool_sun.vmdl"
		}
	},
	{
		name = "Fireworks",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "",
			model = "models/props_toys/fireworks_rocket.vmdl";
			vscripts = "prop_fireworks_rocket";
		},
		modelPrecache = 
		{
			"models/props_toys/fireworks_rocket_fuse.vmdl"
		}
	},
	{
		name = "LAW Rocket (deployed)",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "rocket",
			vscripts = "law_rocket";
			model = "models/weapons/law_rocket.vmdl";	
		}
	},
	{
		name = "Gold bar",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "",
			model = "models/props_range/gold_bar.vmdl";
		}
	},
}


-- Any map specific player settings to load into the settigns manager 
local MAP_PLAYER_DEFAULT_SETTINGS =
{
	-- What custom quick inventory items to use by default, indexed from the above array.
	quick_inv_items = {1, 7, 8, 22, 2};
}


local MAP_COMMANDS =
{
	{cmd = "range_teleport_start", type = 0, text = "#Pause_Button_TeleportToStart"},
	{cmd = "range_reset", type = 0, text = "Reset Range"},
	{cmd = "range_spawn_law", type = 0, text = "Spawn LAW"},
	{cmd = "range_spawn_melon", type = 0, text = "Spawn Melon"},
	{cmd = "range_fire_laws", type = 0, text = "Fire ALL LAWS!"},
}

-- Enables player physics - required by all locomotion using tools and features.
g_VRScript.playerPhysController = CPlayerPhysics()
g_VRScript.playerPhysController:Init()


-- Enables pausing player movement and the spawn menu.
g_VRScript.pauseManager = CPauseManager(SPAWN_ITEMS, MAP_PLAYER_DEFAULT_SETTINGS, MAP_COMMANDS)

-- If uncommented, enables the pause menu to store player data when they connect.
--g_VRScript.pauseManager:ListenPlayerConnect()

-- Enables quick locomotion options.
require("quick_locomotion")
g_VRScript.pauseManager:EnableQuickLocomotion()

-- Precache all the assets used by the spawn menu. 
function OnPrecache(context)
	g_VRScript.pauseManager:DoPrecache(context)
end


function OnActivate()
	g_VRScript.pauseManager:Init()
	CustomGameEventManager:RegisterListener("pause_panel_command", OnMapCommand)
	g_VRScript.debugEnabled = false
end


function OnMapCommand(this, data)

	if data.cmd == "range_teleport_start"
	then
		local player = GetPlayerFromUserID(data.id)
		local destination = Entities:FindByName(nil, "teleport_dest")
		if destination then
			g_VRScript.pauseManager:TeleportPlayer(player, destination, true)
		end	
	elseif data.cmd == "range_reset"
	then
		local player = GetPlayerFromUserID(data.id)
		DoEntFire("range_control", "CallScriptFunction", "Reset", 0, player, player) 
		
	elseif data.cmd == "range_spawn_law"
	then
		local player = GetPlayerFromUserID(data.id)
		DoEntFire("spawn_panel", "CallScriptFunction", "SpawnLaw", 0, player, player) 
		
	elseif data.cmd == "range_spawn_melon"
	then
		local player = GetPlayerFromUserID(data.id)
		DoEntFire("melon_spawner", "ForceSpawn", "", 0, player, player) 
		
	elseif data.cmd == "range_fire_laws"
	then
		local player = GetPlayerFromUserID(data.id)
		DoEntFire("fire_laws", "CallScriptFunction", "Fire", 0, player, player) 
	end
end


-- Utility function for passing call through to functions if debug mode is enabled.
-- Note that arguments are evaluated regardless of if the function gets called.
function _G.DebugCall(func, ...)
	if g_VRScript.debugEnabled
	then
		return func(...)
	end
	return nil
end


-- Utility function for printing large scopes
function _G.PrintTable(table, level, maxlevel)
	level = level or 0
	maxlevel = maxlevel or 8

	local indent = ""
	
	for i = 0, level - 1, 1
	do
		indent = indent .. " "
	end

	for key, value in pairs(table)
	do
		if value == _G
		then
			print(indent .. type(value) .. ": " .. tostring(key))
			print(indent .. "Global table reference!")
			
		elseif value == table
		then
			print(indent .. type(value) .. ": " .. tostring(key))
			print(indent .. "Self reference!")
			
		elseif type(value) == "table"	
		then
			print(indent .. type(value) .. ": " .. tostring(key))
			if level < maxlevel
			then
				PrintTable(value, level + 1, maxlevel)
			else
				print("Max recursion!")
			end
			
		elseif type(value) == "function"
		then
			print(indent .. type(value) .. ": " .. key)
						
		elseif type(value) == "userdata"
		then
			print(indent .. type(value) .. ": " .. key)
			
		else
			print(indent .. key .. " = " .. tostring(value))
		end
	end
end

 