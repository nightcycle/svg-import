local package = script.Parent.Parent
local packages = package.Parent

return function (coreGui)
	local importer = require(script.Parent)

	local sourceValue = workspace:FindFirstChild("SVG")
	local importResult: Model | {Model} | nil
	if sourceValue then
		local rawSource = workspace:WaitForChild("SVG").Value
		importResult = importer(nil, nil, rawSource)
		if typeof(importResult) == "Instance" then
			importResult.Parent = workspace
		elseif typeof(importResult) == "table" then
			for i, model in ipairs(importResult) do
				model.Parent = workspace
			end
		end
	else
		error("SVG is not a member of workspace")
	end
	return function()
		if importResult then
			if typeof(importResult) == "table" then
				for i, model in ipairs(importResult) do
					model:Destroy()
				end
			else
				importResult:Destroy()
			end
		end
	end
end