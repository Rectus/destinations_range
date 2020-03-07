"use strict";

var UI_COMMANDS = 
{
	UP : 1,
	DOWN : 2,
	LEFT : 4,
	RIGHT : 8,
	ENTER : 16
};

var Pages =
{
	MainMenu: {panel: $("#MenuPage"), toolMode: 0},
	MenuEntInfo: {panel: $("#EntInfoPage"), toolMode: 1},
	MenuPropManip: {panel: $("#PropManipPage"), toolMode: 2},
	MenuPropUtil: {panel: $("#PropUtilPage"), toolMode: 3},
};

var currentPage = null;
var isActive = false;
var syncInactiveEvent = -1;
var activeMenuItem = null;

var bootCounter = 0;


function UICommand(data)
{
	if(isActive && data.id == $.GetContextPanel().GetOwnerEntityID())
	{
		if(data.command & UI_COMMANDS.ENTER)
		{	
			if(IsInMenu())
			{
				SetPage(Pages[activeMenuItem.id], true);
			}
		}
		else
		{
			if(data.command & UI_COMMANDS.UP)
			{
				UpdateFocus(-1);
			}
			else if(data.command & UI_COMMANDS.DOWN)
			{
				UpdateFocus(1);
			}
			else if(data.command & UI_COMMANDS.LEFT)
			{
				
			}
			else if(data.command & UI_COMMANDS.RIGHT)
			{
				if(IsInMenu())
				{
					SetPage(Pages[activeMenuItem.id], true);
				}			
			}
		}
	}
}

function UpdateFocus(value)
{
	var tab = activeMenuItem.tabindex;
	var items = activeMenuItem.GetParent().Children();
	
	var newTab = tab + value;
	
	if(newTab >= items.length) {newTab = 0;}
	else if(newTab < 0) {newTab = items.length - 1;}
	
	for(var itemID in items)
	{
		if(items[itemID].tabindex == newTab)
		{
			items[itemID].SetFocus();
			activeMenuItem = items[itemID];
			return;
		}
	}
}

// Sets this client-side instance of the panel as authoritative of the menu.
function SetActiveInstance(data)
{
	if(data.id == $.GetContextPanel().GetOwnerEntityID())
	{
		$.Msg(data);
		isActive = true;
		GameEvents.Unsubscribe(syncInactiveEvent);
	}
}

function SyncInactive(data)
{
	if(!isActive && data.id == $.GetContextPanel().GetOwnerEntityID())
	{
		var panel = $(data.pageID);
		
		if(panel != null && panel != currentPage)
		{
			currentPage.RemoveClass("Visible");
			panel.AddClass("Visible");		
			currentPage = panel;
		}
	}
}

function IsInMenu()
{
	return currentPage == $("#MenuPage");
}

function SetPage(page, propagate)
{
	if(page.panel != null && page.panel != currentPage)
	{
		currentPage.panel.RemoveClass("Visible");
		page.panel.AddClass("Visible");
		
		currentPage = page.panel;
	}
	
	if(isActive && propagate === true)
	{
		var data = {id: $.GetContextPanel().GetOwnerEntityID(), mode: page.toolMode};
		GameEvents.SendCustomGameEventToServer("ent_tool_set_mode", data);
		
		data = {id: $.GetContextPanel().GetOwnerEntityID(), pageID: page.panel.id};
		GameEvents.SendCustomGameEventToAllClients("ent_tool_sync_inactive", data);
	}
}

function ReturnToMenu(data)
{
	if(data.id == $.GetContextPanel().GetOwnerEntityID())
	{
		SetPage(Pages.MainMenu, true);			
	}
}

function UpdateBoot()
{
	if(bootCounter < 6)
	{
		bootCounter++;
		$("#BootText").text += "\n" + $.Localize("EntTool_Boot" + bootCounter);
		$.Schedule(0.1, UpdateBoot);
	}
	else
	{
		$.Schedule(0.3, function() { SetPage(Pages.MainMenu, true); } );
	}
	
}

function SetEntInfo(data)
{
	if(data.id == $.GetContextPanel().GetOwnerEntityID())
	{
		$("#EntInfoText").text = data.text
	}
}

(function()
{
	currentPage = $("#BootPage");
	//$.DispatchEvent("SetPanelSelected", $("#MenuEntInfo"), true);
	$("#MenuEntInfo").SetFocus();
	activeMenuItem = $("#MenuEntInfo");
	GameEvents.Subscribe("ent_tool_ui_command", UICommand);
	GameEvents.Subscribe("ent_tool_set_active", SetActiveInstance);
	GameEvents.Subscribe("ent_tool_get_ent_info", SetEntInfo);
	syncInactiveEvent = GameEvents.Subscribe("ent_tool_sync_inactive", SyncInactive);
	UpdateBoot();
})();


