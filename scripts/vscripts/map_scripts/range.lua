
print("Range map script")

-- What scripts to load for the player physics and pause menu.
require("player_physics")
require("pause_manager")

-- List of items spawnable from the spawn menu.
local SPAWN_ITEMS = 
{
	{
		name = "Locomotion tool",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/locomotion_tool_base.vmdl";
			vscripts = "tool_locomotion";
			HasCollisionInHand = 0;
		},
		modelPrecache = 
		{
			"models/tools/locomotion_tool_grapple.vmdl",
			"models/tools/locomotion_tool_strap.vmdl"
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

-- Enables player physics - required by all locomotion using tools.
g_VRScript.playerPhysController = CPlayerPhysics()
g_VRScript.playerPhysController:Init()


-- Enables pauisng player movement and the spawn menu.
g_VRScript.pauseManager = CPauseManager(SPAWN_ITEMS)

-- Precache all the assets used by the spawn menu. 
function OnPrecache(context)
	g_VRScript.pauseManager:DoPrecache(context)
end

function OnActivate()
	g_VRScript.pauseManager:Init()
	CustomGameEventManager:RegisterListener("toggle_debug_draw", ToggleDebugDraw)
end


function ToggleDebugDraw()
	g_VRScript.playerPhysController:ToggleDebugDraw()
end



-- Utility function for printing large scopes
function PrintTable(table, level, maxlevel)

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