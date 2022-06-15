--!strict
local packages = script.Parent
local math = require(packages:WaitForChild("math"))
local RunService = game:GetService("RunService")
local Studio = game:GetService("StudioService")

function empty(scale, thickness, entry)
	local model = Instance.new("Model")
	return model
end

local constructors = {
	path = require(script:WaitForChild("Path")),
	svg = empty,
	polygon = require(script:WaitForChild("Polygon")),
	group = empty,
	title = empty,
	image = empty,
	line = require(script:WaitForChild("Line")),
	polyline = require(script:WaitForChild("Polyline")),
	rect = require(script:WaitForChild("Rect")),
	ellipse = require(script:WaitForChild("Ellipse")),
	circle = require(script:WaitForChild("Circle")),
}

function import(scale: number, thickness: number, rawSource: string): Model
	local function parseargs(s: string)
		local arg = {}
		string.gsub(s, "([%-%w]+)=([\"'])(.-)%2",
			function (w, _, a)
				arg[w] = a
			end
		)
		return arg
	end
	local function collect(s: string)
		local stack = {}
		local top = {}
		table.insert(stack, top)
		local ni,c,label,xarg, empty

		local i: number, j:number = 1, 1

		while true do
			ni,j,c,label,xarg,empty = string.find(s, "<(%/?)([%w:]+)(.-)(%/?)>", i)
			if not ni then break end
			local text = string.sub(s, i, ni-1)
			if not string.find(text, "^%s*$") then
				table.insert(top, text)
			end
			if empty == "/" then  -- empty element tag
				table.insert(top, {label=label, xarg=parseargs(xarg), empty=1})
			elseif c == "" then   -- start tag
				top = {label=label, xarg=parseargs(xarg)}
				table.insert(stack, top)   -- new level
			else  -- end tag
				local toclose = table.remove(stack)  -- remove top
				top = stack[#stack]
				if #stack < 1 then
					error("nothing to close with "..label)
				end
				if toclose.label ~= label then
					error("trying to close "..toclose.label.." with "..label)
				end
				table.insert(top, toclose)
			end
			i = j+1
		end
		local text = string.sub(s, i)
		if not string.find(text, "^%s*$") then
			table.insert(stack[#stack], text)
		end
		if #stack > 1 then
			error("unclosed "..stack[#stack].label)
		end
		return stack[1]
	end
	local arrayFormat = collect(rawSource)

	local keyDictionary = {
		d = "steps",
	}

	local classDictionary = {
		g = "group",
	}

	local function translateValue(val: string)
		if string.find(val, "matrix") then
			-- print("Val", val)
			local noMatrix = string.gsub(
				val,
				"matrix",
				""
			)
			local noParenthesis = string.gsub(string.gsub(noMatrix, "%(", ""), "%)", "")
			local noSpace = string.gsub(noParenthesis, "%s", "")
			-- print("NoSpace", noSpace)
			-- print("NoPar", noParenthesis)
			local vals = string.split(noSpace, ",")
			-- print("Vals", vals)
			local nums = {}
			for i, v in ipairs(vals) do
				nums[i] = tonumber(v)
			end
			local a,b,c,d,e,f = nums[1], nums[2], nums[3], nums[4], nums[4], nums[6]
			return CFrame.fromMatrix(
				Vector3.new(0,0,0),
				Vector3.new(a,c,e),
				Vector3.new(b,d,f),
				Vector3.new(0,0,1)
			)
		end
		local spaceSplitVals = string.split(val, " ")
		if #spaceSplitVals == 4 then
			local allNumbers = true
			local nums = {}
			for i, v in ipairs(spaceSplitVals) do
				local num =tonumber(v)
				if num then
					table.insert(nums, num)	
				else
					allNumbers = false
				end
			end
			if allNumbers then
				return {
					x = nums[1],
					y = nums[2],
					width = nums[3],
					height = nums[4],
				}
			end
		end
		return val
	end

	local function translateArray(entry: {[number | string]: string | {any}})
		local final = {}
		final.ClassName = entry["label"]
		final.ClassName = classDictionary[final.ClassName] or final.ClassName
		final.Properties = entry["xarg"]
		final.Children = {}
		-- final.Tags = {}
		for k, v in pairs(entry) do
			if typeof(k) == "number" then
				if typeof(v) == "table" then
					table.insert(final.Children, translateArray(v))
				end
			end
		end
		for k, v in pairs(final.Properties) do
			local key = keyDictionary[k] or k
			final.Properties[key] = translateValue(v)
		end
		return final
	end
	local parsed = translateArray(arrayFormat[2])

	local function construct(entry: {[string]: any})
		local childModels = {}
	
		for i, child in ipairs(entry.Children) do
			table.insert(childModels, construct(child))
		end

		local constructor = constructors[entry.ClassName]
		local model
		if constructor then
			model = constructor(scale, thickness, entry)
		end
		if model == nil then
			-- warn("Constructor fail for", entry)
			model = Instance.new("Model")
			if constructor then
				model.Name = tostring(entry.ClassName).."_TODO"
			else
				model.Name = "_"..tostring(entry.ClassName)
			end
		else
			model.Name = tostring(entry.ClassName)
		end

		for i, childModel in ipairs(childModels) do
			childModel.Parent = model
		end

		return model
	end

	return construct(parsed)
end

return function(scale: number | nil, thickness: number | nil, providedSource: string | nil)
	scale = scale or 1
	thickness = thickness or 1
	if providedSource then
		return import(scale, thickness, providedSource)
	elseif RunService:IsStudio() then
		local files = Studio:PromptImportFiles({"svg"})
		if #files == 0 then return end
		local models = {}
		for i, file in ipairs(files) do
			local rawSource: string = file:GetBinaryContents()
			local model = import(scale, thickness, rawSource)
			if model then
				table.insert(models, model)
			end
		end
		return models
	end
end