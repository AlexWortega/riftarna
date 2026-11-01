-- Everything needed for a walkable scene is embedded in the place. The optional
-- Kenney FBX kit can replace these models after import in Roblox Studio.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local old = Workspace:FindFirstChild("RiftboundWorld")
if old then old:Destroy() end
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then baseplate:Destroy() end
local defaultSpawn = Workspace:FindFirstChild("SpawnLocation")
if defaultSpawn then defaultSpawn:Destroy() end
local world = Instance.new("Folder")
world.Name = "RiftboundWorld"
world.Parent = Workspace

local function part(parent, name, size, cf, material, color, anchored)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Material, p.Color = material, color
	p.Anchored = anchored ~= false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local timber = Color3.fromRGB(83, 64, 47)
local plaster = Color3.fromRGB(169, 153, 126)
local straw = Color3.fromRGB(164, 137, 91)
local stone = Color3.fromRGB(90, 87, 78)

part(world, "Ground", Vector3.new(280, 2, 260), CFrame.new(0, -1, 0), Enum.Material.Ground, Color3.fromRGB(51, 57, 44))
part(world, "Village road", Vector3.new(20, 0.12, 180), CFrame.new(0, 0.07, -25), Enum.Material.Ground, Color3.fromRGB(105, 86, 60))
local strawRandom = Random.new(417)
for i = 1, 620 do
	local x = strawRandom:NextNumber(-10, 10)
	local z = strawRandom:NextNumber(-112, 63)
	local length = strawRandom:NextNumber(0.45, 1.6)
	local tint = strawRandom:NextInteger(-17, 17)
	local strand = part(world, "Loose straw", Vector3.new(0.055, 0.025, length), CFrame.new(x, 0.151, z) * CFrame.Angles(0, strawRandom:NextNumber(-math.pi, math.pi), 0), Enum.Material.Grass, Color3.fromRGB(153 + tint, 127 + tint, 75 + tint))
	strand.CanCollide, strand.CanTouch, strand.CanQuery = false, false, false
end
for i = 1, 105 do
	local z = 70 - i * 2.1
	local side = i % 2 == 0 and -1 or 1
	local x = side * (9.5 + (i % 6) * 1.1)
	local verge = part(world, "Straw and mud verge", Vector3.new(0.6 + (i % 4) * 0.3, 0.04, 0.8 + (i % 5) * 0.5), CFrame.new(x, 0.12, z) * CFrame.Angles(0, i * 2.4, 0), Enum.Material.Grass, Color3.fromRGB(85 + (i % 3) * 8, 79 + (i % 4) * 5, 52))
	verge.CanCollide = false
end
local flammables = Instance.new("Folder")
flammables.Name = "Flammables"
flammables.Parent = world
local targets = Instance.new("Folder")
targets.Name = "Targets"
targets.Parent = world

-- Winter silhouettes beyond the huts keep the misty village from looking like a flat tree line.
local function bareBranch(parent, from, to, width)
	local span = to - from
	local branch = part(parent, "Bare branch", Vector3.new(width, span.Magnitude, width), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(math.rad(90), 0, 0), Enum.Material.Wood, Color3.fromRGB(68, 65, 59))
	branch.CanCollide = false
end
for i = 1, 14 do
	local z = 82 - i * 13
	local x = (i % 2 == 0 and 1 or -1) * (46 + (i % 4) * 6)
	local deadTree = Instance.new("Model")
	deadTree.Name = "Bare tree " .. i
	deadTree:SetAttribute("Flammable", true)
	deadTree:SetAttribute("Health", 55)
	deadTree.Parent = flammables
	local trunk = part(deadTree, "Trunk", Vector3.new(1.1, 14, 1.1), CFrame.new(x, 7, z), Enum.Material.Wood, Color3.fromRGB(68, 65, 59))
	deadTree.PrimaryPart = trunk
	for level = 1, 5 do
		for side = -1, 1, 2 do
			local start = Vector3.new(x, 4 + level * 2.1, z)
			local tip = start + Vector3.new(side * (4.8 - level * 0.35), 3.3 + level * 0.15, ((i + level) % 3 - 1) * 2.2)
			bareBranch(deadTree, start, tip, 0.5 - level * 0.055)
			bareBranch(deadTree, tip, tip + Vector3.new(side * 1.4, 2.2, 0.8), 0.15)
		end
	end
end

local artKit = ServerStorage:FindFirstChild("RiftboundArt")
local function placeArt(name, cf, parent)
	local template = artKit and artKit:FindFirstChild(name)
	if not template then return nil end
	local clone = template:Clone()
	if clone:IsA("BasePart") then
		clone.CFrame = cf
		clone.Anchored = true
	elseif clone:IsA("Model") then
		clone:PivotTo(cf)
		if not clone.PrimaryPart then clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true) end
		for _, item in ipairs(clone:GetDescendants()) do
			if item:IsA("BasePart") then item.Anchored = true end
		end
	else
		clone:Destroy()
		return nil
	end
	clone.Name = name
	clone.Parent = parent
	return clone
end

local function hut(x, z, side, index)
	local model = Instance.new("Model")
	model.Name = "Hut " .. index
	model:SetAttribute("Flammable", true)
	model:SetAttribute("Health", 140)
	model.Parent = flammables
	local w, d = 18, 16
	part(model, "Stone foundation", Vector3.new(w + 1, 1.2, d + 1), CFrame.new(x, 0.6, z), Enum.Material.Cobblestone, stone)
	part(model, "Rear wall", Vector3.new(w, 9, 1), CFrame.new(x, 5.5, z - d / 2), Enum.Material.Sandstone, plaster)
	part(model, "Front wall", Vector3.new(w, 9, 1), CFrame.new(x, 5.5, z + d / 2), Enum.Material.Sandstone, plaster)
	for _, dx in ipairs({-w / 2, w / 2}) do
		part(model, "Side wall", Vector3.new(1, 9, d), CFrame.new(x + dx, 5.5, z), Enum.Material.Sandstone, plaster)
	end
	for _, dx in ipairs({-w / 2 + 0.7, w / 2 - 0.7}) do
		for _, dz in ipairs({-d / 2 + 0.7, d / 2 - 0.7}) do
			part(model, "Wood post", Vector3.new(0.9, 10.5, 0.9), CFrame.new(x + dx, 5.8, z + dz), Enum.Material.Wood, timber)
		end
	end
	for _, dx in ipairs({-6, 0, 6}) do
		part(model, "Timber frame", Vector3.new(0.55, 8.5, 0.48), CFrame.new(x + dx, 5.4, z + d / 2 + 0.55), Enum.Material.Wood, timber)
	end
	for _, dy in ipairs({2.6, 8.8}) do
		part(model, "Timber beam", Vector3.new(w, 0.55, 0.5), CFrame.new(x, dy, z + d / 2 + 0.55), Enum.Material.Wood, timber)
	end
	for _, dx in ipairs({-4.5, 4.5}) do
		part(model, "Cross brace", Vector3.new(0.44, 5.2, 0.5), CFrame.new(x + dx, 5.7, z + d / 2 + 0.72) * CFrame.Angles(0, 0, math.rad(dx > 0 and 30 or -30)), Enum.Material.Wood, timber)
	end
	for _, ridgeSide in ipairs({-1, 1}) do
		local edge = Vector3.new(x + ridgeSide * (w / 2 + 1), 9.6, z)
		local ridge = Vector3.new(x, 14.8, z)
		local center = (edge + ridge) / 2
		local roof = part(model, "Thatch roof", Vector3.new(12, 0.8, d + 3), CFrame.new(center) * CFrame.Angles(0, 0, -ridgeSide * math.rad(30)), Enum.Material.Ground, straw)
		roof:SetAttribute("Roof", true)
		for j = 1, 12 do
			local fringe = part(model, "Hanging thatch", Vector3.new(0.22, 0.7 + (j % 3) * 0.18, 0.9), CFrame.new(x + ridgeSide * (w / 2 + 1.5), 9.25, z - d / 2 - 1 + j * 1.45), Enum.Material.Grass, Color3.fromRGB(132 + j % 3 * 6, 113 + j % 4 * 4, 68))
			fringe.CanCollide = false
		end
	end
	local door = part(model, "Door", Vector3.new(3.8, 6, 0.3), CFrame.new(x - side * 4, 4, z + d / 2 + 0.4), Enum.Material.WoodPlanks, timber)
	door.CanCollide = false
	part(model, "Door iron", Vector3.new(3.9, 0.2, 0.15), CFrame.new(x - side * 4, 5.2, z + d / 2 + 0.65), Enum.Material.Metal, Color3.fromRGB(48, 47, 43))
	part(model, "Door handle", Vector3.new(0.25, 0.35, 0.25), CFrame.new(x - side * 4 + 1.15, 3.7, z + d / 2 + 0.72), Enum.Material.Metal, Color3.fromRGB(89, 77, 54))
	for j = 1, 3 do
		part(model, "Window", Vector3.new(1.7, 2, 0.2), CFrame.new(x + j * 3 - 7, 6, z + d / 2 + 0.6), Enum.Material.Glass, Color3.fromRGB(41, 37, 28)).Transparency = 0.25
	end
	model.PrimaryPart = model:FindFirstChild("Stone foundation")
	for j = 1, 5 do
		local stack = part(model, "Firewood", Vector3.new(0.8, 0.8, 4.2), CFrame.new(x + (j - 3) * 0.85, 1.1 + (j % 2) * 0.45, z + d / 2 + 1.6), Enum.Material.Wood, Color3.fromRGB(75 + j * 3, 54 + j * 2, 39))
		stack.Shape = Enum.PartType.Cylinder
	end
	for j = 1, 2 do
		local barrel = part(model, "Barrel", Vector3.new(2.3, 2.8, 2.3), CFrame.new(x + (j == 1 and -7 or 7), 1.4, z + d / 2 + 3.6), Enum.Material.WoodPlanks, Color3.fromRGB(83, 62, 42))
		barrel.Shape = Enum.PartType.Cylinder
	end
	return model
end

local function fence(x, z, length, index)
	local imported = placeArt("Fence", CFrame.new(x, 0, z + length * 1.5), flammables)
	if imported then
		local model = imported
		if imported:IsA("BasePart") then
			model = Instance.new("Model")
			model.Name = "Fence " .. index
			imported.Parent = model
			model.PrimaryPart = imported
			model.Parent = flammables
		else model.Name = "Fence " .. index end
		model:SetAttribute("Flammable", true)
		model:SetAttribute("Health", 55)
		return model
	end
	local model = Instance.new("Model")
	model.Name = "Fence " .. index
	model:SetAttribute("Flammable", true)
	model:SetAttribute("Health", 55)
	model.Parent = flammables
	for j = 0, length do
		part(model, "Fence post", Vector3.new(0.8, 3.5, 0.8), CFrame.new(x, 1.75, z + j * 3), Enum.Material.Wood, timber)
	end
	for _, y in ipairs({1.3, 2.7}) do
		part(model, "Fence rail", Vector3.new(0.35, 0.35, length * 3), CFrame.new(x, y, z + length * 1.5), Enum.Material.Wood, timber)
	end
	model.PrimaryPart = model:FindFirstChild("Fence post")
	return model
end

for i = 1, 8 do
	local z = 46 - (i - 1) * 23
	hut(i % 2 == 0 and 23 or -23, z, i % 2 == 0 and 1 or -1, i)
	fence(i % 2 == 0 and 12 or -12, z - 6, 4, i)
end
for i, z in ipairs({35, -12, -64}) do
	placeArt("Cart", CFrame.new(i % 2 == 0 and 14 or -14, 0, z) * CFrame.Angles(0, math.rad(i * 31), 0), world)
end
for _, z in ipairs({46, -23, -92}) do
	placeArt("Lantern", CFrame.new(8, 4, z), world)
end

for i = 1, 38 do
	local z = 85 - i * 5.5
	local x = (i % 2 == 0 and 1 or -1) * (36 + (i % 7) * 4)
	local tree = Instance.new("Model")
	tree.Name = "Pine " .. i
	tree:SetAttribute("Flammable", true)
	tree:SetAttribute("Health", 65)
	tree.Parent = flammables
	part(tree, "Trunk", Vector3.new(1.4, 9, 1.4), CFrame.new(x, 4.5, z), Enum.Material.Wood, timber)
	for level = 1, 4 do
		for branch = 1, 5 do
			local angle = branch * math.pi * 2 / 5 + level * 0.4
			local radius = (5 - level) * 0.8
			local leaf = part(tree, "Needles", Vector3.new(3.8, 3.6, 5.4), CFrame.new(x + math.cos(angle) * radius, 5 + level * 2.4, z + math.sin(angle) * radius) * CFrame.Angles(0, angle, math.rad(18)), Enum.Material.LeafyGrass, Color3.fromRGB(38 + level * 2, 55 + level * 3, 43))
			leaf.Shape = Enum.PartType.Ball
		end
	end
	tree.PrimaryPart = tree:FindFirstChild("Trunk")
end

for i = 1, 4 do
	local z = 18 - i * 34
	local target = Instance.new("Model")
	target.Name = "Training raider " .. i
	target:SetAttribute("Health", 220)
	target.Parent = targets
	local x = i % 2 == 0 and 4 or -4
	part(target, "Body", Vector3.new(2.6, 3.6, 1.7), CFrame.new(x, 3.1, z), Enum.Material.Fabric, Color3.fromRGB(104, 28, 39))
	part(target, "Head", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, 5.4, z), Enum.Material.SmoothPlastic, Color3.fromRGB(124, 104, 85)).Shape = Enum.PartType.Ball
	local hood = part(target, "Red hood", Vector3.new(2.3, 2.2, 2.3), CFrame.new(x, 6.1, z), Enum.Material.Fabric, Color3.fromRGB(112, 28, 39))
	hood.Shape = Enum.PartType.Ball
	local point = part(target, "Hood tip", Vector3.new(1.2, 1.8, 1.2), CFrame.new(x, 7.25, z - 0.35), Enum.Material.Fabric, Color3.fromRGB(112, 28, 39))
	point.Shape = Enum.PartType.Ball
	for _, side in ipairs({-1, 1}) do
		part(target, "Arm", Vector3.new(0.8, 2.8, 0.8), CFrame.new(x + side * 1.7, 3.2, z), Enum.Material.Fabric, Color3.fromRGB(88, 29, 39))
		part(target, "Leg", Vector3.new(0.8, 2.7, 0.8), CFrame.new(x + side * 0.65, 1.4, z), Enum.Material.Fabric, Color3.fromRGB(55, 43, 43))
	end
	target.PrimaryPart = target:FindFirstChild("Body")
end

local spawn = Instance.new("SpawnLocation")
spawn.Name = "VillageSpawn"
spawn.Size = Vector3.new(7, 0.5, 7)
spawn.CFrame = CFrame.new(0, 0.3, 66)
spawn.Transparency = 1
spawn.Anchored = true
spawn.Neutral = true
spawn.Parent = world

Lighting.Ambient = Color3.fromRGB(158, 165, 166)
Lighting.OutdoorAmbient = Color3.fromRGB(176, 180, 181)
Lighting.ClockTime = 11.2
Lighting.Brightness = 1.75
Lighting.ExposureCompensation = 0.12
Lighting.ShadowSoftness = 0.72
Lighting.FogColor = Color3.fromRGB(128, 135, 137)
Lighting.FogStart = 45
Lighting.FogEnd = 205
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.48
atmosphere.Haze = 2.5
atmosphere.Color = Color3.fromRGB(186, 190, 187)
atmosphere.Decay = Color3.fromRGB(113, 122, 128)
atmosphere.Parent = Lighting
local clouds = Instance.new("Clouds")
clouds.Cover = 0.9
clouds.Density = 0.85
clouds.Color = Color3.fromRGB(170, 175, 172)
clouds.Parent = Workspace.Terrain
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Contrast = 0.13
colorCorrection.Saturation = -0.19
colorCorrection.TintColor = Color3.fromRGB(227, 232, 228)
colorCorrection.Parent = Lighting

local function preparePlayer(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = 15
		humanoid.JumpPower = 0
		character:WaitForChild("HumanoidRootPart").CFrame = CFrame.new(0, 4, 66)
	end)
end
Players.PlayerAdded:Connect(preparePlayer)
for _, player in ipairs(Players:GetPlayers()) do preparePlayer(player) end
