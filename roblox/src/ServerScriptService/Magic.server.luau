local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Riftbound")
local Rules = require(shared:WaitForChild("SpellRules"))
local world = Workspace:WaitForChild("RiftboundWorld")
local flammables = world:WaitForChild("Flammables")
local targets = world:WaitForChild("Targets")
local remote = Instance.new("RemoteEvent")
remote.Name = "SpellEvent"
remote.Parent = shared

local lastCast = {}
local burning = {}

local function rootOfHit(instance)
	local current = instance
	while current and current ~= world do
		if current:IsA("Model") and (current.Parent == flammables or current.Parent == targets) then return current end
		current = current.Parent
	end
	return nil
end

local function center(model)
	if model.PrimaryPart then return model.PrimaryPart.Position end
	return model:GetPivot().Position
end

local function addFire(model)
	if burning[model] or model:GetAttribute("Destroyed") then return end
	if not model.PrimaryPart then return end
	local anchor = Instance.new("Part")
	anchor.Name = "Burning source"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery = true, false, false
	anchor.Position = center(model) + Vector3.new(0, model.Name:match("Hut") and 10 or model.Name:match("Pine") and 6 or 2, 0)
	anchor.Parent = model
	local flame = Instance.new("Fire")
	flame.Name = "RiftboundFire"
	flame.Color = Color3.fromRGB(255, 108, 34)
	flame.SecondaryColor = Color3.fromRGB(255, 197, 71)
	flame.Heat = 6
	flame.Size = model.Name:match("Hut") and 11 or 5
	flame.Parent = anchor
	local smoke = Instance.new("Smoke")
	smoke.Name = "RiftboundSmoke"
	smoke.Color = Color3.fromRGB(33, 31, 30)
	smoke.Opacity = 0.42
	smoke.RiseVelocity = 7
	smoke.Size = 9
	smoke.Parent = anchor
	burning[model] = {age = 0, anchor = anchor}
	remote:FireAllClients("ignite", center(model))
end

local function destroyModel(model)
	if model:GetAttribute("Destroyed") then return end
	model:SetAttribute("Destroyed", true)
	local state = burning[model]
	if state then state.anchor:Destroy(); burning[model] = nil end
	local pos = center(model)
	remote:FireAllClients("collapse", pos)
	local count = 0
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			if child:GetAttribute("Roof") or model.Parent == targets or model.Name:match("Fence") then
				child.Anchored = false
				child.CanCollide = true
				child.AssemblyLinearVelocity = Vector3.new(math.random(-15, 15), math.random(7, 19), math.random(-15, 15))
				Debris:AddItem(child, 7)
				count += 1
			elseif child.Name ~= "Stone foundation" then
				child.Color = Color3.fromRGB(43, 38, 35)
				child.Material = Enum.Material.Slate
			end
		end
		if count >= 14 then break end
	end
	if model.Parent == targets or model.Name:match("Fence") then Debris:AddItem(model, 8) end
end

local function damage(model, amount, element)
	if not model or model:GetAttribute("Destroyed") then return end
	local hp = (model:GetAttribute("Health") or 100) - amount
	model:SetAttribute("Health", hp)
	if element == "fire" or element == "stormfire" then
		if model.Parent == flammables then addFire(model) end
	end
	if hp <= 0 then destroyModel(model) end
end

local function withinBlast(position, radius, callback)
	for _, folder in ipairs({flammables, targets}) do
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") and not model:GetAttribute("Destroyed") and (center(model) - position).Magnitude <= radius then callback(model) end
		end
	end
end

remote.OnServerEvent:Connect(function(player, action, queue, aim)
	if action ~= "cast" or type(aim) ~= "table" or typeof(aim.x) ~= "number" or typeof(aim.y) ~= "number" or typeof(aim.z) ~= "number" then return end
	if aim.x ~= aim.x or aim.y ~= aim.y or aim.z ~= aim.z then return end
	local spell = Rules.compile(queue)
	if not spell then return end
	local now = os.clock()
	if now - (lastCast[player] or -100) < Rules.Cooldown[spell] then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not head or not humanoid or humanoid.Health <= 0 then return end
	local direction = Vector3.new(aim.x, aim.y, aim.z)
	if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then return end
	direction = direction.Unit
	lastCast[player] = now
	local origin = head.Position + direction * 1.2
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	local hit = Workspace:Raycast(origin, direction * Rules.Range[spell], rayParams)
	local position = hit and hit.Position or origin + direction * Rules.Range[spell]
	local directModel = hit and rootOfHit(hit.Instance) or nil
	if spell == "fire" then
		if directModel then damage(directModel, Rules.Damage.fire, "fire") end
		withinBlast(position, 8, function(model)
			if model ~= directModel then damage(model, Rules.Damage.fire, "fire") end
		end)
	elseif spell == "lightning" then
		if directModel then damage(directModel, Rules.Damage.lightning, "lightning") end
	else
		if directModel then damage(directModel, Rules.Damage.stormfire, "stormfire") end
		withinBlast(position, 13, function(model)
			if model ~= directModel then damage(model, Rules.Damage.stormfire, "stormfire") end
		end)
	end
	remote:FireAllClients("cast", {spell = spell, origin = origin, position = position, caster = player.UserId})
end)

Players.PlayerRemoving:Connect(function(player) lastCast[player] = nil end)

task.spawn(function()
	while true do
		task.wait(0.5)
		for model, state in pairs(burning) do
			if model.Parent and not model:GetAttribute("Destroyed") then
				state.age += 0.5
				local scorch = math.clamp(state.age / 11, 0, 0.75)
				for _, p in ipairs(model:GetDescendants()) do
					if p:IsA("BasePart") and p.Name ~= "Stone foundation" then p.Color = p.Color:Lerp(Color3.fromRGB(38, 34, 31), scorch * 0.07) end
				end
				if state.age > 2 then
					withinBlast(center(model), 15, function(other)
						if other ~= model and other.Parent == flammables and not burning[other] and math.random() < 0.13 then addFire(other) end
					end)
				end
				if state.age >= 11 then destroyModel(model) end
			else burning[model] = nil end
		end
	end
end)
