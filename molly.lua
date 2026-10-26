--[[
=====================================================================
   STEAL A BRAINROT  |  CLEAN AUTO-STEAL HUB
   Works on: Delta / Madium / Solara / Wave / Arceus / Xeno / Fluxus
   Keyless - no external UI library - no dependencies
=====================================================================
]]

if _G.SAB_HUB and _G.SAB_HUB.Unload then
	pcall(_G.SAB_HUB.Unload)
end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local LP = Players.LocalPlayer

local Hub = {
	Running = true,
	Config = {
		AutoSteal  = false,
		AutoLock   = false,
		ESP        = false,
		Speed      = false,
		Noclip     = false,
		StealDelay = 0.35,
		SpeedValue = 60,
	},
	ESP    = {},
	Status = "Loaded",
	Gui    = nil,
}
_G.SAB_HUB = Hub

--=============================================================
--  UTILITIES
--=============================================================
local function getChar()
	local char = LP.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		return char, hrp, hum
	end
	return nil
end

local function getPosition(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local ok, cf = pcall(function() return inst:GetBoundingBox() end)
		if ok and cf then return cf.Position end
	end
	local part = inst:FindFirstChildWhichIsA("BasePart", true)
	if part then return part.Position end
	return nil
end

local function teleportTo(pos)
	if not pos then return end
	local _, hrp = getChar()
	if hrp then
		hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
	end
end

local function parseMoney(text)
	if type(text) ~= "string" then return nil end
	local clean = text:gsub("[%$,%s]", "")
	clean = clean:gsub(",", "")
	local num, suffix = clean:match("(%d+%.?%d*)(%a*)")
	if not num then return nil end
	local n = tonumber(num)
	if not n then return nil end
	suffix = (suffix or ""):lower()
	local mult = 1
	if suffix == "k" then mult = 1e3
	elseif suffix == "m" then mult = 1e6
	elseif suffix == "b" then mult = 1e9
	elseif suffix == "t" then mult = 1e12
	elseif suffix == "q" or suffix == "qa" then mult = 1e15
	elseif suffix == "qi" then mult = 1e18
	end
	return n * mult
end

local function activate(object)
	if not object then return false end
	local fired = false

	local cd
	if object:IsA("ClickDetector") then
		cd = object
	else
		cd = object:FindFirstChildWhichIsA("ClickDetector", true)
	end
	if cd then
		pcall(function() cd.MaxActivationDistance = 1e6 end)
		if type(fireclickdetector) == "function" then
			pcall(fireclickdetector, cd)
			fired = true
		end
	end

	local pp
	if object:IsA("ProximityPrompt") then
		pp = object
	else
		pp = object:FindFirstChildWhichIsA("ProximityPrompt", true)
	end
	if pp then
		pcall(function()
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 1e6
		end)
		if type(fireproximityprompt) == "function" then
			pcall(fireproximityprompt, pp)
			fired = true
		end
	end

	return fired
end

--=============================================================
--  WORLD SCANNING
--=============================================================
local CONTAINER_NAMES = {
	"Bases", "Plots", "BasePlots", "PlayerBases",
	"BasesFolder", "PlotsFolder", "BaseFolder", "Plot",
}

local function getBases()
	local list      = {}
	local container = nil

	for _, n in ipairs(CONTAINER_NAMES) do
		local f = Workspace:FindFirstChild(n)
		if f then
			container = f
			break
		end
	end

	local source = container or Workspace
	for _, c in ipairs(source:GetChildren()) do
		if c ~= LP.Character and (c:IsA("Model") or c:IsA("Folder")) then
			local hasCD = c:FindFirstChildWhichIsA("ClickDetector", true) ~= nil
			local hasPP = c:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
			if hasCD or hasPP then
				local lower = c.Name:lower()
				local skip  = (not container) and (lower:find("conveyor") or lower:find("map"))
				if not skip then
					table.insert(list, c)
				end
			end
		end
	end
	return list
end

local cachedBase = nil

local function getMyBase()
	if cachedBase and cachedBase.Parent then return cachedBase end

	local bases  = getBases()
	local myName = LP.Name:lower()

	for _, base in ipairs(bases) do
		for _, attr in ipairs({"Owner", "OwnerName", "Player", "Username", "PlayerName", "Plr"}) do
			local v = base:GetAttribute(attr)
			if type(v) == "string" and v:lower() == myName then
				cachedBase = base
				return base
			end
		end
		for _, attr in ipairs({"OwnerId", "UserId", "PlayerId", "OwnerUserId"}) do
			local v = base:GetAttribute(attr)
			if tonumber(v) == LP.UserId then
				cachedBase = base
				return base
			end
		end
	end

	for _, base in ipairs(bases) do
		if base.Name:lower():find(myName, 1, true) then
			cachedBase = base
			return base
		end
	end

	for _, base in ipairs(bases) do
		for _, d in ipairs(base:GetDescendants()) do
			if d:IsA("ObjectValue") and d.Value == LP then
				cachedBase = base
				return base
			end
			if d:IsA("StringValue") and d.Name:lower():find("owner")
				and tostring(d.Value):lower() == myName then
				cachedBase = base
				return base
			end
		end
	end

	for _, base in ipairs(bases) do
		for _, d in ipairs(base:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text and d.Text ~= ""
				and d.Text:lower():find(myName, 1, true) then
				cachedBase = base
				return base
			end
		end
	end

	local _, hrp = getChar()
	if hrp then
		local best, bestDist
		for _, base in ipairs(bases) do
			local pos = getPosition(base)
			if pos then
				local dist = (pos - hrp.Position).Magnitude
				if not best or dist < bestDist then
					best = base
					bestDist = dist
				end
			end
		end
		if best then
			cachedBase = best
			return best
		end
	end

	return nil
end

local function getBaseDropPos(base)
	if not base then return nil end
	for _, d in ipairs(base:GetDescendants()) do
		if d:IsA("BasePart") then
			local n = d.Name:lower()
			if n:find("drop") or n:find("place") or n:find("pad") or n:find("center") then
				return d.Position
			end
		end
	end
	return getPosition(base)
end

local function getPlacedBrainrots()
	local out   = {}
	local bases = getBases()

	if #bases == 0 then
		for _, d in ipairs(Workspace:GetChildren()) do
			if d:IsA("Model") and d:FindFirstChildWhichIsA("ClickDetector", true) then
				table.insert(out, {brainrot = d, base = d.Parent})
			end
		end
		return out
	end

	local isBase = {}
	for _, b in ipairs(bases) do isBase[b] = true end

	for _, base in ipairs(bases) do
		for _, d in ipairs(base:GetDescendants()) do
			if d:IsA("Model") and not isBase[d] then
				local hasCD = d:FindFirstChildWhichIsA("ClickDetector", true) ~= nil
				local hasPP = d:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
				if hasCD or hasPP then
					local nested = false
					for _, ch in ipairs(d:GetChildren()) do
						if ch:IsA("Model") and
							(ch:FindFirstChildWhichIsA("ClickDetector", true) or
							 ch:FindFirstChildWhichIsA("ProximityPrompt", true)) then
							nested = true
							break
						end
					end
					if not nested then
						table.insert(out, {brainrot = d, base = base})
					end
				end
			end
		end
	end
	return out
end

local function getValue(brainrot)
	for _, attrName in ipairs({"Value", "Cost", "Price", "Income", "Worth"}) do
		local v = brainrot:GetAttribute(attrName)
		if type(v) == "number" then return v end
		if type(v) == "string" then
			local n = parseMoney(v)
			if n then return n end
		end
	end

	local best = 0
	for _, d in ipairs(brainrot:GetDescendants()) do
		if d:IsA("TextLabel") and d.Text and d.Text ~= "" then
			local n = parseMoney(d.Text)
			if n and n > best then best = n end
		end
	end
	return best
end

local function pickStealTarget()
	local _, hrp = getChar()
	if not hrp then return nil end

	local myBase = getMyBase()
	local myPos  = hrp.Position
	local best, bestVal, bestDist

	for _, entry in ipairs(getPlacedBrainrots()) do
		if entry.base ~= myBase then
			local pos = getPosition(entry.brainrot)
			if pos then
				local val  = getValue(entry.brainrot)
				local dist = (pos - myPos).Magnitude
				if not best or val > bestVal or (val == bestVal and dist < bestDist) then
					best     = entry.brainrot
					bestVal  = val
					bestDist = dist
				end
			end
		end
	end

	return best
end

--=============================================================
--  GUI
--=============================================================
local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name             = "SAB_Hub"
	gui.ResetOnSpawn     = false
	gui.IgnoreGuiInset   = true
	gui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling

	local ok = pcall(function() gui.Parent = gethui() end)
	if not ok then
		gui.Parent = LP:WaitForChild("PlayerGui")
	end

	local main = Instance.new("Frame")
	main.Name             = "Main"
	main.Size             = UDim2.new(0, 232, 0, 322)
	main.Position         = UDim2.new(0, 24, 0.5, -161)
	main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	main.BorderSizePixel  = 0
	main.Active           = true
	main.Parent           = gui

	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(0, 10)
	mc.Parent = main

	local ms = Instance.new("UIStroke")
	ms.Color        = Color3.fromRGB(0, 190, 140)
	ms.Thickness    = 1
	ms.Transparency = 0.35
	ms.Parent = main

	local bar = Instance.new("Frame")
	bar.Name             = "TitleBar"
	bar.Size             = UDim2.new(1, 0, 0, 34)
	bar.BackgroundColor3 = Color3.fromRGB(27, 27, 33)
	bar.BorderSizePixel  = 0
	bar.Active           = true
	bar.Parent           = main

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 10)
	bc.Parent = bar

	local title = Instance.new("TextLabel")
	title.Size             = UDim2.new(1, -40, 1, 0)
	title.Position         = UDim2.new(0, 12, 0, 0)
	title.BackgroundTransparency = 1
	title.Text             = "STEAL A BRAINROT"
	title.Font             = Enum.Font.GothamBold
	title.TextSize         = 13
	title.TextColor3       = Color3.fromRGB(0, 220, 160)
	title.TextXAlignment   = Enum.TextXAlignment.Left
	title.Parent           = bar

	local minBtn = Instance.new("TextButton")
	minBtn.Size             = UDim2.new(0, 24, 0, 24)
	minBtn.Position         = UDim2.new(1, -30, 0, 5)
	minBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	minBtn.Text             = "-"
	minBtn.Font             = Enum.Font.GothamBold
	minBtn.TextSize         = 16
	minBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	minBtn.BorderSizePixel  = 0
	minBtn.AutoButtonColor  = false
	minBtn.Parent           = bar

	local minC = Instance.new("UICorner")
	minC.CornerRadius = UDim.new(0, 6)
	minC.Parent = minBtn

	local list = Instance.new("ScrollingFrame")
	list.Name                = "List"
	list.Size                = UDim2.new(1, -16, 1, -60)
	list.Position            = UDim2.new(0, 8, 0, 38)
	list.BackgroundTransparency = 1
	list.BorderSizePixel     = 0
	list.ScrollBarThickness  = 4
	list.ScrollBarImageColor3 = Color3.fromRGB(0, 190, 140)
	list.CanvasSize          = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent              = main

	local layout = Instance.new("UIListLayout")
	layout.Padding   = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent    = list

	local status = Instance.new("TextLabel")
	status.Size             = UDim2.new(1, -16, 0, 18)
	status.Position         = UDim2.new(0, 8, 1, -22)
	status.BackgroundTransparency = 1
	status.Text             = "Loaded"
	status.Font             = Enum.Font.Gotham
	status.TextSize         = 11
	status.TextColor3       = Color3.fromRGB(130, 200, 175)
	status.TextXAlignment   = Enum.TextXAlignment.Left
	status.Parent           = main

	Hub.SetStatus = function(text)
		Hub.Status  = text
		status.Text = text
	end

	local order = 0

	local function addToggle(label, key)
		order += 1
		local btn = Instance.new("TextButton")
		btn.Size             = UDim2.new(1, -8, 0, 32)
		btn.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
		btn.Text             = label .. "  [ OFF ]"
		btn.Font             = Enum.Font.Gotham
		btn.TextSize         = 13
		btn.TextColor3       = Color3.fromRGB(220, 220, 230)
		btn.BorderSizePixel  = 0
		btn.AutoButtonColor  = false
		btn.LayoutOrder      = order
		btn.Parent           = list

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn

		local state = false
		btn.MouseButton1Click:Connect(function()
			state = not state
			Hub.Config[key]      = state
			btn.Text             = label .. (state and "  [ ON ]" or "  [ OFF ]")
			btn.BackgroundColor3 = state and Color3.fromRGB(0, 118, 92) or Color3.fromRGB(38, 38, 46)
		end)
		return btn
	end

	local function addButton(label, onClick)
		order += 1
		local btn = Instance.new("TextButton")
		btn.Size             = UDim2.new(1, -8, 0, 32)
		btn.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
		btn.Text             = label
		btn.Font             = Enum.Font.Gotham
		btn.TextSize         = 13
		btn.TextColor3       = Color3.fromRGB(220, 220, 230)
		btn.BorderSizePixel  = 0
		btn.AutoButtonColor  = false
		btn.LayoutOrder      = order
		btn.Parent           = list

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn

		btn.MouseButton1Click:Connect(function()
			pcall(onClick, btn)
		end)
		return btn
	end

	addToggle("Auto Steal", "AutoSteal")
	addToggle("Auto Lock Base", "AutoLock")
	addToggle("Brainrot ESP", "ESP")
	addToggle("Speed Boost", "Speed")
	addToggle("Noclip", "Noclip")

	addButton("Teleport to Base", function()
		local base = getMyBase()
		if base then
			teleportTo(getBaseDropPos(base))
			Hub.SetStatus("Teleported to base")
		else
			Hub.SetStatus("Base not found")
		end
	end)

	local delays  = {0.15, 0.25, 0.35, 0.5, 0.75}
	local delayIx = 3
	addButton("Steal Delay: " .. delays[delayIx] .. "s", function(btn)
		delayIx += 1
		if delayIx > #delays then delayIx = 1 end
		Hub.Config.StealDelay = delays[delayIx]
		btn.Text = "Steal Delay: " .. delays[delayIx] .. "s"
	end)

	local speeds  = {40, 60, 100, 150, 250}
	local speedIx = 2
	addButton("Speed: " .. speeds[speedIx], function(btn)
		speedIx += 1
		if speedIx > #speeds then speedIx = 1 end
		Hub.Config.SpeedValue = speeds[speedIx]
		btn.Text = "Speed: " .. speeds[speedIx]
	end)

	-- Dragging
	local dragging, dragStart, startPos
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = input.Position
			startPos  = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	-- Minimize
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized    = not minimized
		list.Visible = not minimized
		status.Visible = not minimized
		main.Size    = minimized and UDim2.new(0, 232, 0, 34) or UDim2.new(0, 232, 0, 322)
		minBtn.Text  = minimized and "+" or "-"
	end)

	-- Hide / show with RightShift
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.RightShift then
			main.Visible = not main.Visible
		end
	end)

	Hub.Gui = gui
end

--=============================================================
--  UNLOAD
--=============================================================
function Hub.Unload()
	Hub.Running = false

	if Hub.Gui and Hub.Gui.Parent then
		Hub.Gui:Destroy()
	end

	for _, hl in pairs(Hub.ESP) do
		if hl and hl.Parent then hl:Destroy() end
	end
	Hub.ESP = {}

	local _, _, hum = getChar()
	if hum then hum.WalkSpeed = 16 end

	local char = LP.Character
	if char then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				p.CanCollide = true
			end
		end
	end

	_G.SAB_HUB = nil
end

--=============================================================
--  LOOPS
--=============================================================
local function stealLoop()
	while Hub.Running do
		local ok, err = pcall(function()
			if Hub.Config.AutoSteal and getChar() then
				local target = pickStealTarget()
				if target then
					teleportTo(getPosition(target))
					Hub.SetStatus("Stealing: " .. target.Name)
					task.wait(0.1)
					activate(target)
					task.wait(Hub.Config.StealDelay)
				else
					Hub.SetStatus("No brainrot found")
				end

				local base = getMyBase()
				if base then
					teleportTo(getBaseDropPos(base))
				end
				task.wait(0.12)
			else
				if not Hub.Config.AutoSteal then Hub.SetStatus("Idle") end
				task.wait(0.1)
			end
		end)
		if not ok then
			warn("[SAB] steal:", err)
			task.wait(0.5)
		end
	end
end

local function lockLoop()
	while Hub.Running do
		if Hub.Config.AutoLock then
			local ok = pcall(function()
				local base = getMyBase()
				if not base then return end
				for _, d in ipairs(base:GetDescendants()) do
					if d.Name:lower():find("lock") and
						(d:FindFirstChildWhichIsA("ClickDetector", true) or
						 d:FindFirstChildWhichIsA("ProximityPrompt", true)) then
						activate(d)
						break
					end
				end
			end)
			if not ok then warn("[SAB] lock") end
			task.wait(3)
		else
			task.wait(0.5)
		end
	end
end

local function espLoop()
	while Hub.Running do
		if Hub.Config.ESP then
			local ok = pcall(function()
				local live = {}
				for _, entry in ipairs(getPlacedBrainrots()) do
					local br = entry.brainrot
					live[br] = true

					local hl = Hub.ESP[br]
					if not hl or not hl.Parent then
						hl = Instance.new("Highlight")
						hl.Name              = "SAB_ESP"
						hl.Adornee           = br
						hl.FillTransparency  = 0.55
						hl.OutlineTransparency = 0
						hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
						hl.Parent            = br
						Hub.ESP[br]          = hl
					end

					local v = getValue(br)
					if v >= 1e12 then
						hl.FillColor = Color3.fromRGB(255, 60, 60)
					elseif v >= 1e9 then
						hl.FillColor = Color3.fromRGB(255, 140, 40)
					elseif v >= 1e6 then
						hl.FillColor = Color3.fromRGB(255, 220, 60)
					elseif v >= 1e3 then
						hl.FillColor = Color3.fromRGB(60, 230, 120)
					else
						hl.FillColor = Color3.fromRGB(90, 200, 255)
					end
				end

				for br, hl in pairs(Hub.ESP) do
					if not live[br] or not br.Parent then
						if hl and hl.Parent then hl:Destroy() end
						Hub.ESP[br] = nil
					end
				end
			end)
			if not ok then warn("[SAB] esp") end
			task.wait(0.5)
		else
			for br, hl in pairs(Hub.ESP) do
				if hl and hl.Parent then hl:Destroy() end
				Hub.ESP[br] = nil
			end
			task.wait(0.5)
		end
	end
end

RunService.Heartbeat:Connect(function()
	if not Hub.Running then return end

	if Hub.Config.Speed then
		local _, _, hum = getChar()
		if hum then hum.WalkSpeed = Hub.Config.SpeedValue end
	end
end)

RunService.Stepped:Connect(function()
	if not Hub.Running or not Hub.Config.Noclip then return end
	local char = LP.Character
	if char then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				p.CanCollide = false
			end
		end
	end
end)

--=============================================================
--  START
--=============================================================
buildGui()
task.spawn(stealLoop)
task.spawn(lockLoop)
task.spawn(espLoop)

Hub.SetStatus("Ready - enable Auto Steal")
print("[SAB] Clean hub loaded. RightShift hides the GUI.")
