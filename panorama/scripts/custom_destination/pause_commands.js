"use strict";

var registerEventID = 0;
var playerID = 0;
var panelID = 0;

function RegisterPanel(data)
{
	if(data.panel == $.GetContextPanel().GetOwnerEntityID())
	{
		playerID = data.id;
		panelID = data.panel;
		//$("#PausePanel").AddClass("Activated");
		
		GameEvents.Unsubscribe(registerEventID);
	}
}

function AddItem(data)
{
	if(data.panel == panelID)
	{
		var spawnPane = $("#SpawnPane");
		
		var itemPanel = $.CreatePanel("Panel", spawnPane, "Item" + parseInt(data.item));
		itemPanel.SetAttributeInt("itemID", parseInt(data.item));
		itemPanel.BLoadLayoutSnippet("ItemButton");
		
		if(data.img.length > 0)
		{
			itemPanel.FindChildInLayoutFile("ItemSpawnButtonImage").SetImage(data.img);
		}
		
		itemPanel.FindChildInLayoutFile("ItemSpawnButtonLabel").text = data.name;
		
		//var itemButton = itemPanel.FindChildInLayoutFile("ItemSpawnButton")
		
		var spawnItem = function(panel) 
		{
			return function() 
			{
				var itemID = panel.GetAttributeInt("itemID", 0);
				
				GameEvents.SendCustomGameEventToServer("pause_panel_spawn_item", {id: playerID, panel: panelID, itemID: itemID});
			}
		}( itemPanel );
		itemPanel.SetPanelEvent("onactivate", spawnItem);
	}
}

function TeleportPlayer()
{
	GameEvents.SendCustomGameEventToServer("pause_panel_teleport", {id: playerID, panel: panelID});
}

function ToggleDebug()
{
	GameEvents.SendCustomGameEventToServer("toggle_debug_draw", {id: playerID, panel: panelID});
}

function ToggleSkis()
{
	GameEvents.SendCustomGameEventToServer("pause_panel_toggle_skis", {id: playerID, panel: panelID});
}


(function()
{
	registerEventID = GameEvents.Subscribe("pause_panel_register", RegisterPanel);
	GameEvents.Subscribe("pause_panel_add_item", AddItem);
})();