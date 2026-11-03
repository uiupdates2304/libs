--AutoScaleLibrary V4.0
local AutoScaleLibrary = {}
AutoScaleLibrary.__index = AutoScaleLibrary
local ChangeHistoryService = {SetWaypoint = function() end}

local script = {
	Parent = {
		WaitForChild = function() end
	}
}

--Functions
local function PropertyExists(obj, prop)
	return ({pcall(function()if(typeof(obj[prop])=="Instance")then error()end end)})[1]
end

function AutoScaleLibrary.CustomPrint(msg, gui)
	--[[
	game:GetService("ContentProvider"):Preload("rbxassetid://2790389767")
	local newgui = gui:Clone()
	newgui.Parent = game:GetService("CoreGui")

	newgui:WaitForChild("BG"):WaitForChild("Msg").Text = msg
	newgui.BG:TweenPosition(UDim2.new(0.104, 0,0.938, 0), "Out", "Quint", .1)
	task.wait(1)
	newgui.BG:TweenPosition(UDim2.new(0.104, 0,1.2, 0), "Out", "Quint", .2)
	]]
end

-- Helper: returns the per-axis scale denominator for a direct parent.
-- ScrollingFrame children use visible width but canvas height for Y scale.
local function GetParentScaleRef(parent)
	if not parent then
		return workspace.CurrentCamera.ViewportSize
	end
	if parent:IsA("ScreenGui") or parent:IsA("PlayerGui") then
		return workspace.CurrentCamera.ViewportSize
	end
	if not parent:IsA("GuiBase2d") then
		local ancestor = parent:IsA("GuiObject") and parent or parent:FindFirstAncestorWhichIsA("GuiObject")
		return ancestor and ancestor.AbsoluteSize or workspace.CurrentCamera.ViewportSize
	end
	local visible = parent.AbsoluteSize
	if parent:IsA("ScrollingFrame") then
		return Vector2.new(visible.X, parent.AbsoluteCanvasSize.Y)
	end
	return visible
end

local function measureAutomaticParentRef(parent)
	local ref = GetParentScaleRef(parent)
	if not (parent and parent:IsA("GuiObject")) then
		return ref
	end
	if parent.AutomaticSize == Enum.AutomaticSize.None then
		return ref
	end
	local sumX, sumY, count = 0, 0, 0
	for _, child in parent:GetChildren() do
		if child:IsA("GuiBase2d") then
			sumX += child.AbsoluteSize.X
			sumY += child.AbsoluteSize.Y
			count += 1
		end
	end
	local layout = parent:FindFirstChildWhichIsA("UIListLayout")
	if layout and count > 1 then
		local pad = layout.Padding.Offset
		if layout.FillDirection == Enum.FillDirection.Horizontal then
			sumX += pad * (count - 1)
		else
			sumY += pad * (count - 1)
		end
	end
	local x, y = ref.X, ref.Y
	local auto = parent.AutomaticSize
	if auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY then x = math.max(x, sumX) end
	if auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY then y = math.max(y, sumY) end
	return Vector2.new(x, y)
end

local function GetFrozenParentScaleRef(parent, cache)
	if not cache[parent] then
		cache[parent] = measureAutomaticParentRef(parent)
	end
	return cache[parent]
end

local preparedAutomaticParents = setmetatable({}, { __mode = "k" })

function AutoScaleLibrary.PrepareAutomaticSizeParent(parent)
	if not (parent and parent:IsA("GuiObject")) then return end
	if parent.AutomaticSize == Enum.AutomaticSize.None then return end
	if preparedAutomaticParents[parent] then return end
	preparedAutomaticParents[parent] = true

	local grandRef
	if parent.Parent and parent.Parent:IsA("GuiBase2d") then
		grandRef = GetParentScaleRef(parent.Parent)
	elseif parent:FindFirstAncestorWhichIsA("GuiObject") then
		grandRef = parent:FindFirstAncestorWhichIsA("GuiObject").AbsoluteSize
	else
		grandRef = workspace.CurrentCamera.ViewportSize
	end

	local abs = parent.AbsoluteSize
	if abs.X == 0 or abs.Y == 0 then return end

	local auto = parent.AutomaticSize
	local size = parent.Size
	local xScale, yScale = size.X.Scale, size.Y.Scale

	if auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY then
		xScale = abs.X / grandRef.X
	else
		xScale = (size.X.Scale * grandRef.X + size.X.Offset) / grandRef.X
	end

	if auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY then
		yScale = abs.Y / grandRef.Y
	else
		yScale = (size.Y.Scale * grandRef.Y + size.Y.Offset) / grandRef.Y
	end

	parent.AutomaticSize = Enum.AutomaticSize.None
	parent.Size = UDim2.new(xScale, 0, yScale, 0)
end

local function ensureAutomaticParentPrepared(guiObject)
	local parent = guiObject and guiObject.Parent
	if parent and parent:IsA("GuiObject") and parent.AutomaticSize ~= Enum.AutomaticSize.None then
		AutoScaleLibrary.PrepareAutomaticSizeParent(parent)
	end
end

--Text
function AutoScaleLibrary.ScaleText()
	for _, v in ipairs(game.Selection:Get()) do
		if not PropertyExists(v, "TextScaled") then continue end

		-- Get or create the UITextSizeConstraint
		local tconstraint = v:FindFirstChildWhichIsA("UITextSizeConstraint")
		if not tconstraint then
			tconstraint = Instance.new("UITextSizeConstraint")
			tconstraint.Parent = v
		end

		if v.TextScaled == false then
			-- Enabling TextScaled: cap at current TextSize so layout doesn't blow up
			tconstraint.MaxTextSize = v.TextSize
			v.TextScaled = true
		else
			-- Already scaled: recalibrate the cap to match the current rendered size
			if v.TextBounds.Y > 0 then
				tconstraint.MaxTextSize = math.floor(v.TextBounds.Y)
			end
		end

		AutoScaleLibrary.CustomPrint("AutoScaled Text", script.Parent:WaitForChild("CustomPrint"))
	end
	ChangeHistoryService:SetWaypoint("AutoScaled Text")
end

--Position
function AutoScaleLibrary.SetPos(params, v)
	--SCALE
	if params == "Scale" then
		local parentRefs = {}
		for _, v in ipairs(v) do
			if v:isA("GuiBase2d") and v.Parent and PropertyExists(v, "Position") then
				if PropertyExists(v.Parent, "AbsoluteSize") then
					local parentRef = GetFrozenParentScaleRef(v.Parent, parentRefs)
					if parentRef.X > 0 and parentRef.Y > 0 then
						local ScaleXPos = v.Position.X.Offset/parentRef.X + v.Position.X.Scale
						local ScaleYPos = v.Position.Y.Offset/parentRef.Y + v.Position.Y.Scale
						v.Position = UDim2.new(ScaleXPos, 0, ScaleYPos, 0)
					end
				end
			end
		end

		AutoScaleLibrary.CustomPrint("Converted to Scale Pos", script.Parent:WaitForChild("CustomPrint"))
		ChangeHistoryService:SetWaypoint("Converted UI element to Scale Position")
		--OFFSET	
	elseif params == "Offset" then
		local parentRefs = {}
		for _, v in ipairs(v) do
			if v:isA("GuiBase2d") and v.Parent and PropertyExists(v, "Position") then
				if PropertyExists(v.Parent, "AbsoluteSize") then
					local parentRef = GetFrozenParentScaleRef(v.Parent, parentRefs)
					local OffsetXPos = v.Position.X.Scale*parentRef.X + v.Position.X.Offset
					local OffsetYPos = v.Position.Y.Scale*parentRef.Y + v.Position.Y.Offset
					v.Position = UDim2.new(0, OffsetXPos, 0, OffsetYPos)
				end
			end
		end

		AutoScaleLibrary.CustomPrint("Converted to Offset Pos", script.Parent:WaitForChild("CustomPrint"))
		ChangeHistoryService:SetWaypoint("Converted UI element to Offset Position")	
	end
end

--Size
function AutoScaleLibrary.SetSize(params, v)
	--SCALE
	if params == "Scale" then
		local parentRefs = {}
		preparedAutomaticParents = setmetatable({}, { __mode = "k" })
		for _, v in ipairs(v) do
			if v:isA("GuiBase2d") and PropertyExists(v, "Size") then
				ensureAutomaticParentPrepared(v)
				local Viewport_Size

				if v.Parent and PropertyExists(v.Parent, "AbsoluteSize") then
					Viewport_Size = GetFrozenParentScaleRef(v.Parent, parentRefs)
				elseif v:FindFirstAncestorWhichIsA("GuiObject") and PropertyExists(v:FindFirstAncestorWhichIsA("GuiObject"), "AbsoluteSize") then
					Viewport_Size = v:FindFirstAncestorWhichIsA("GuiObject").AbsoluteSize
				else
					Viewport_Size = workspace.CurrentCamera.ViewportSize
				end

				local LB_Size = v.AbsoluteSize
				if Viewport_Size.X > 0 and Viewport_Size.Y > 0 then
					v.Size = UDim2.new(LB_Size.X/Viewport_Size.X, 0, LB_Size.Y/Viewport_Size.Y, 0)
				end
			end
		end

		AutoScaleLibrary.CustomPrint("Converted to Scale Size", script.Parent:WaitForChild("CustomPrint"))
		ChangeHistoryService:SetWaypoint("Converted UI element to Scale Size")
		--OFFSET
	elseif params == "Offset" then	
		for _, v in ipairs(v) do
			if v:isA("GuiBase2d") and PropertyExists(v, "Size")then
				local LB_Size = v.AbsoluteSize
				v.Size = UDim2.new(0, LB_Size.X, 0, LB_Size.Y)
			end
		end

		AutoScaleLibrary.CustomPrint("Converted to Offset Size", script.Parent:WaitForChild("CustomPrint"))
		ChangeHistoryService:SetWaypoint("Converted UI element to Offset Size")
	end
end

--Add Constraint
function AutoScaleLibrary.AddConstraint(v)
	for _, v in ipairs(v) do 
		if v:isA("GuiBase2d") then
			local parentLayout = v.Parent and v.Parent:FindFirstChildWhichIsA("UIGridStyleLayout")
			if parentLayout and (parentLayout:IsA("UIGridLayout") or parentLayout:IsA("UITableLayout")) then
				AutoScaleLibrary.CustomPrint("Skipped constraint — parent uses " .. parentLayout.ClassName, script.Parent:WaitForChild("CustomPrint"))
				continue
			end

			local x = v.AbsoluteSize.X
			local y = v.AbsoluteSize.Y
			if y == 0 then continue end  -- guard against zero-division
			local ratio = x/y

			-- Warn if a UIListLayout sibling exists: the constraint will override it
			if v.Parent and v.Parent:FindFirstChildWhichIsA("UIListLayout") then
				AutoScaleLibrary.CustomPrint("Warning: UIListLayout sibling detected - constraint overrides layout", script.Parent:WaitForChild("CustomPrint"))
			end

			-- DominantAxis: Width for landscape/square, Height for portrait
			local dominantAxis = (x >= y) and Enum.DominantAxis.Width or Enum.DominantAxis.Height
			-- AspectType: ScaleWithParentSize for scale-based sizing, FitWithinMaxSize for offset
			local sizeIsScale = (v.Size.X.Scale ~= 0 or v.Size.Y.Scale ~= 0)
			local aspectType = sizeIsScale and Enum.AspectType.ScaleWithParentSize or Enum.AspectType.FitWithinMaxSize

			local constraint = v:FindFirstChildWhichIsA("UIAspectRatioConstraint")
			if constraint then
				constraint.AspectRatio = ratio
				constraint.DominantAxis = dominantAxis
				constraint.AspectType = aspectType
				AutoScaleLibrary.CustomPrint("Edited UIAspectRatio constraint", script.Parent:WaitForChild("CustomPrint"))
			else
				constraint = Instance.new("UIAspectRatioConstraint")
				constraint.AspectRatio = ratio
				constraint.DominantAxis = dominantAxis
				constraint.AspectType = aspectType
				constraint.Parent = v
				AutoScaleLibrary.CustomPrint("Added UIAspectRatio constraint", script.Parent:WaitForChild("CustomPrint"))
			end
		end
	end
	ChangeHistoryService:SetWaypoint("Added Constraints to UI elements")
end

-- Modern alternative to ScaleText: uses AutomaticSize instead of TextScaled + UITextSizeConstraint.
-- Lets the container grow to fit text rather than shrinking text to fit the container.
function AutoScaleLibrary.AutoSizeText()
	for _, v in ipairs(game.Selection:Get()) do
		if not PropertyExists(v, "TextScaled") then continue end

		-- If TextScaled is on, the stored TextSize is meaningless — text is being scaled to fit.
		-- Capture the current rendered size from TextBounds before disabling TextScaled,
		-- so the text stays visually the same size after the switch.
		if v.TextScaled and v.TextBounds.Y > 0 then
			v.TextSize = math.max(9, math.floor(v.TextBounds.Y))
		end

		-- Disable TextScaled and remove any UITextSizeConstraint (conflicts with AutomaticSize)
		v.TextScaled = false
		local existing = v:FindFirstChildWhichIsA("UITextSizeConstraint")
		if existing then existing:Destroy() end

		-- Enforce Roblox's minimum readable TextSize of 9
		if v.TextSize < 9 then
			v.TextSize = 14
		end

		-- Let the element grow vertically to fit its text content
		v.AutomaticSize = Enum.AutomaticSize.Y
		AutoScaleLibrary.CustomPrint("Auto Size Text Applied", script.Parent:WaitForChild("CustomPrint"))
	end
	ChangeHistoryService:SetWaypoint("Auto Sized Text")
end

return AutoScaleLibrary
