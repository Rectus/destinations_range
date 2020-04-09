function DumpScope(scope)
{
	$.Msg("\nKeys\n")
	var keys = Object.keys(scope), value;

	for(var i = 0; i < keys.length; i++) 
	{
		try
		{
			value = scope[keys[ i ]];
			$.Msg(keys[ i ] + ": " + value );
		}
		catch(error)
		{
			$.Msg(keys[ i ] + " (error): " + error.message);
		}
	}

	$.Msg("\nProperties\n")
	var keys = Object.getOwnPropertyNames(scope), value;

	for(var i = 0; i < keys.length; i++) 
	{
		try
		{
			value = scope[keys[ i ]];
			$.Msg(keys[ i ] + ": " + value );
		}
		catch(error)
		{
			$.Msg(keys[ i ] + " (error): " + error.message);
		}
	}
}

(function()
{
	DumpScope(this)
	DumpScope($)
	//$.GetContextPanel();
	for(var i = 1; i < 2; i++) 
	{
		$("#testclass"+i);
	}
	//SteamFriends.RequestPersonaName(1, DumpScope)
})();