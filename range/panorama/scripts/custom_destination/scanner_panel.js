"use strict";

function UpdateDisplay(data)
{
	if(data.id == $.GetContextPanel().GetOwnerEntityID())
	{
		$("#TextDisplay").text = data.displayText;
	}
}

(function()
{
	GameEvents.Subscribe("scanner_update_display", UpdateDisplay);
})();