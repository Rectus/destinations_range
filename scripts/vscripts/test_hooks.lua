
require "utils.deepprint"

function Activate(arg)
	print("Activate()")
	DeepPrintTable(arg)
end

function UpdateOnRemove(arg)
	print("UpdateOnRemove()")
	DeepPrintTable(arg)
end

function Spawn(arg)
	print("Spawn()")
	--print(arg:GetDebugName())
	print(arg:GetValue("model"))
	print(CNativeOutputs())
end

function OnEntText(arg)
	print("OnEntText()")
	return "ent text!"
end

function OnBreak(arg)
	print("OnBreak()")
	DeepPrintTable(arg)
end

function OnPickedUp(arg)
	print("OnPickedUp()")
	DeepPrintTable(arg)
end

function OnDropped(arg)
	print("OnDropped()")
	DeepPrintTable(arg)
end

function InputBreak(arg)
	print("InputBreak()")
	DeepPrintTable(arg)
end

function Inputbreak(arg)
	print("Inputbreak()")
	DeepPrintTable(arg)
end