
--[[
-- Unit test framework.
]]



function RunTests(scriptname)

	testScope = require(scriptname)

	print("Testing " .. scriptname .. "\n")
	
	local numTests = 0
	local failedTests = 0
	
	for key, val in pairs(testScope)
	do
	
		if type(val) == "function"
		then
			local output = "Running test - " .. key .. ": "
			numTests = numTests + 1
			
			local pass = nil
			local exp = nil
			
			pass, exp = pcall(testScope[key])

			if pass
			then
				print(output .. "PASS")
			else
				failedTests = failedTests + 1
				print(output .. "FAIL - " .. exp)
			end
		
		end
	end
	
	print("\n" .. (numTests - failedTests) .. "/" .. numTests .. " Tests passed.\n")
	ResetScope(scriptname)
end


function ResetScope(scriptname)

	testScope = {}
	package.loaded[scriptname] = nil
end