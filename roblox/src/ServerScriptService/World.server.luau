-- Everything needed for a walkable scene is embedded in the place. The optional
-- Kenney FBX kit can replace these models after import in Roblox Studio.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local old = Workspace:FindFirstChild("RiftboundWorld")
if old then old:Destroy() end
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

local mud = Color3.fromRGB(62, 55, 46)
local timber = Color3.fromRGB(83, 64, 47)
local plaster = Color3.fromRGB(169, 153, 126)
local straw = Color3.fromRGB(117, 93, 57)
local stone = Color3.fromRGB(90, 87, 78)

part(world, "Ground", Vector3.new(280, 2, 260), CFrame.new(0, -1, 0), Enum.Material.Ground, Color3.fromRGB(51, 57, 44))
part(world, "Village road", Vector3.new(20, 0.12, 180), CFrame.new(0, 0.07, -25), Enum.Material.Mud, mud)
for i = 1, 45 do
	local z = 55 - i * 3.5
	local x = math.sin(i * 12.4) * 8
	local puddle = part(world, "Puddle", Vector3.new(1 + (i % 4), 0.02, 1.5 + (i % 3)), CFrame.new(x, 0.15, z), Enum.Material.Glass, Color3.fromRGB(72, 83, 79))
	puddle.Transparency, puddle.Reflectance, puddle.CanCollide = 0.34, 0.12, false
end

local flammables = Instance.new("Folder")
flammables.Name = "Flammables"
flammables.Parent = world
local targets = Instance.new("Folder")
targets.Name = "Targets"
targets.Parent = world
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
	part(model, "Rear wall", Vector3.new(w, 9, 1), CFrame.new(x, 5.5, z - d / 2), Enum.Material.Concrete, plaster)
	part(model, "Front wall", Vector3.new(w, 9, 1), CFrame.new(x, 5.5, z + d / 2), Enum.Material.Concrete, plaster)
	for _, dx in ipairs({-w / 2, w / 2}) do
		part(model, "Side wall", Vector3.new(1, 9, d), CFrame.new(x + dx, 5.5, z), Enum.Material.Concrete, plaster)
	end
	for _, dx in ipairs({-w / 2 + 0.7, w / 2 - 0.7}) do
		for _, dz in ipairs({-d / 2 + 0.7, d / 2 - 0.7}) do
			part(model, "Wood post", Vector3.new(0.9, 10.5, 0.9), CFrame.new(x + dx, 5.8, z + dz), Enum.Material.Wood, timber)
		end
	end
	for _, ridgeSide in ipairs({-1, 1}) do
		local edge = Vector3.new(x + ridgeSide * (w / 2 + 1), 9.6, z)
		local ridge = Vector3.new(x, 14.8, z)
		local center = (edge + ridge) / 2
		local roof = part(model, "Thatch roof", Vector3.new(12, 0.8, d + 3), CFrame.new(center) * CFrame.Angles(0, 0, -ridgeSide * math.rad(30)), Enum.Material.Grass, straw)
		roof:SetAttribute("Roof", true)
	end
	local door = part(model, "Door", Vector3.new(3.8, 6, 0.3), CFrame.new(x - side * 4, 4, z + d / 2 + 0.4), Enum.Material.WoodPlanks, timber)
	door.CanCollide = false
	for j = 1, 3 do
		part(model, "Window", Vector3.new(1.7, 2, 0.2), CFrame.new(x + j * 3 - 7, 6, z + d / 2 + 0.6), Enum.Material.Glass, Color3.fromRGB(41, 37, 28)).Transparency = 0.25
	end
	model.PrimaryPart = model:FindFirstChild("Stone foundation")
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
	for level = 1, 3 do
		local cone = part(tree, "Needles", Vector3.new(9 - level * 1.2, 4.2, 9 - level * 1.2), CFrame.new(x, 6 + level * 2.7, z), Enum.Material.Grass, Color3.fromRGB(38 + level * 3, 60 + level * 4, 45))
		cone.Shape = Enum.PartType.Ball
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
	part(target, "Body", Vector3.new(2.6, 3.2, 1.7), CFrame.new(x, 3.1, z), Enum.Material.Fabric, Color3.fromRGB(91, 69, 58))
	part(target, "Head", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, 5.4, z), Enum.Material.SmoothPlastic, Color3.fromRGB(124, 104, 85)).Shape = Enum.PartType.Ball
	part(target, "Helmet", Vector3.new(1.8, 0.7, 1.8), CFrame.new(x, 6.1, z), Enum.Material.Metal, stone)
	for _, side in ipairs({-1, 1}) do
		part(target, "Arm", Vector3.new(0.8, 2.8, 0.8), CFrame.new(x + side * 1.7, 3.2, z), Enum.Material.Fabric, Color3.fromRGB(75, 65, 52))
		part(target, "Leg", Vector3.new(0.8, 2.7, 0.8), CFrame.new(x + side * 0.65, 1.4, z), Enum.Material.Fabric, Color3.fromRGB(55, 51, 43))
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

Lighting.Ambient = Color3.fromRGB(112, 117, 116)
Lighting.OutdoorAmbient = Color3.fromRGB(118, 124, 128)
Lighting.FogColor = Color3.fromRGB(128, 135, 137)
Lighting.FogStart = 65
Lighting.FogEnd = 240
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.38
atmosphere.Haze = 1.7
atmosphere.Color = Color3.fromRGB(175, 181, 178)
atmosphere.Decay = Color3.fromRGB(113, 122, 128)
atmosphere.Parent = Lighting
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
