local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Riftbound")
local Rules = require(shared:WaitForChild("SpellRules"))
local remote = shared:WaitForChild("SpellEvent")
local camera = workspace.CurrentCamera
local queue = {}
local held = {}
local yaw, pitch, stride, castKick = 0, 0, 0, 0
local character, humanoid, root, head
local lastLocalCast = 0
local fx = Instance.new("Folder")
fx.Name = "RiftboundLocalFX"
fx.Parent = workspace

local gui = Instance.new("ScreenGui")
gui.Name = "RiftboundHUD"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(name, text, size, position, anchor, color, font)
	local t = Instance.new("TextLabel")
	t.Name, t.Text, t.Size, t.Position, t.AnchorPoint = name, text, size, position, anchor
	t.BackgroundTransparency = 1
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.55
	t.TextStrokeColor3 = Color3.new(0, 0, 0)
	t.Font = font or Enum.Font.Code
	t.TextScaled = true
	t.Parent = gui
	return t
end

local white = Color3.fromRGB(229, 236, 234)
local title = label("Bodycam", "RIFTBOUND // VILLAGE 01", UDim2.fromOffset(270, 20), UDim2.fromOffset(205, 22), Vector2.new(0, 0), white)
title.TextXAlignment = Enum.TextXAlignment.Left
local clock = label("Clock", "● REC", UDim2.fromOffset(310, 26), UDim2.new(1, -25, 0, 18), Vector2.new(1, 0), white)
clock.TextXAlignment = Enum.TextXAlignment.Right
local crosshair = label("Crosshair", "+", UDim2.fromOffset(18, 18), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), white)
crosshair.TextTransparency = 0.25
local spellName = label("Spell", "ЗАКЛИНАНИЕ НЕ СОБРАНО", UDim2.fromOffset(350, 28), UDim2.new(0.5, 0, 1, -82), Vector2.new(0.5, 1), white)
local controls = label("Controls", "WASD — ДВИЖЕНИЕ   SHIFT — БЕГ   Q — ОГОНЬ   E — МОЛНИЯ   ЛКМ/F — КАСТ   C — ОЧИСТИТЬ", UDim2.new(0.75, 0, 0, 23), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1), white)
controls.TextTransparency = 0.2
local hitFlash = Instance.new("Frame")
hitFlash.Size = UDim2.fromScale(1, 1)
hitFlash.BackgroundColor3 = Color3.fromRGB(255, 111, 46)
hitFlash.BackgroundTransparency = 1
hitFlash.BorderSizePixel = 0
hitFlash.Parent = gui
hitFlash.ZIndex = 0
local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundTransparency = 1
vignette.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(0.2, 1), NumberSequenceKeypoint.new(0.8, 1), NumberSequenceKeypoint.new(1, 0.55)})
gradient.Parent = vignette
vignette.BackgroundColor3 = Color3.fromRGB(9, 10, 10)
vignette.BackgroundTransparency = 0.65

local function makeViewPart(name, size, material, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Material, p.Color = name, size, material, color
	p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
	p.Parent = camera
	return p
end
local leftArm = makeViewPart("Left sleeve", Vector3.new(0.48, 1.1, 0.5), Enum.Material.Fabric, Color3.fromRGB(38, 65, 105))
local rightArm = makeViewPart("Right sleeve", Vector3.new(0.48, 1.1, 0.5), Enum.Material.Fabric, Color3.fromRGB(38, 65, 105))
local leftHand = makeViewPart("Left hand", Vector3.new(0.4, 0.55, 0.4), Enum.Material.SmoothPlastic, Color3.fromRGB(174, 137, 111))
local rightHand = makeViewPart("Right hand", Vector3.new(0.4, 0.55, 0.4), Enum.Material.SmoothPlastic, Color3.fromRGB(174, 137, 111))
local staff = makeViewPart("Charred staff", Vector3.new(0.17, 0.17, 2.3), Enum.Material.Wood, Color3.fromRGB(54, 41, 32))
local staffTip = makeViewPart("Staff ember", Vector3.new(0.32, 0.32, 0.32), Enum.Material.Neon, Color3.fromRGB(243, 110, 53))
staffTip.Shape = Enum.PartType.Ball

local function refreshSpell()
	local spell = Rules.compile(queue)
	if spell == "fire" then spellName.Text = "ОГНЕННЫЙ ПОТОК  ·  ЛКМ"; spellName.TextColor3 = Color3.fromRGB(255, 158, 91)
	elseif spell == "lightning" then spellName.Text = "ЦЕПНАЯ МОЛНИЯ  ·  ЛКМ"; spellName.TextColor3 = Color3.fromRGB(177, 151, 255)
	elseif spell == "stormfire" then spellName.Text = "ГРОЗОВОЙ ОГОНЬ  ·  ЛКМ"; spellName.TextColor3 = Color3.fromRGB(255, 207, 143)
	else spellName.Text = "Q ОГОНЬ    E МОЛНИЯ    Q + E КОМБИНАЦИЯ"; spellName.TextColor3 = white end
end
refreshSpell()

local function castSelection()
	if not root then return end
	local spell = Rules.compile(queue)
	local now = os.clock()
	if spell and now - lastLocalCast >= Rules.Cooldown[spell] then
		lastLocalCast = now
		remote:FireServer("cast", table.clone(queue), {x = camera.CFrame.LookVector.X, y = camera.CFrame.LookVector.Y, z = camera.CFrame.LookVector.Z})
		table.clear(queue)
		refreshSpell()
	end
end

local function beam(a, b, color, width, life)
	local delta = b - a
	if delta.Magnitude < 0.05 then return end
	local p = Instance.new("Part")
	p.Name = "Spell trail"
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Material, p.Color = Enum.Material.Neon, color
	p.Size = Vector3.new(width, width, delta.Magnitude)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = fx
	TweenService:Create(p, TweenInfo.new(life), {Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, delta.Magnitude)}):Play()
	Debris:AddItem(p, life + 0.1)
end

local function burst(position, color, count, radius)
	local source = Instance.new("Part")
	source.Name = "Spell sparks"
	source.Anchored, source.CanCollide, source.CanQuery = true, false, false
	source.Transparency = 1
	source.Size = Vector3.new(0.2, 0.2, 0.2)
	source.Position = position
	source.Parent = fx
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.7
	emitter.Lifetime = NumberRange.new(0.25, 0.75)
	emitter.Speed = NumberRange.new(radius * 1.5, radius * 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0)})
	emitter.Rate = 0
	emitter.Parent = source
	emitter:Emit(count)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = color, 3, radius * 3
	light.Parent = source
	TweenService:Create(light, TweenInfo.new(0.35), {Brightness = 0}):Play()
	Debris:AddItem(source, 1.1)
end

local function scorch(position, size)
	local mark = Instance.new("Part")
	mark.Name = "Scorched ground"
	mark.Shape = Enum.PartType.Cylinder
	mark.Size = Vector3.new(0.035, size, size)
	mark.CFrame = CFrame.new(position + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	mark.Material = Enum.Material.Slate
	mark.Color = Color3.fromRGB(34, 30, 28)
	mark.Transparency = 0.22
	mark.Anchored, mark.CanCollide, mark.CanQuery = true, false, false
	mark.Parent = fx
	TweenService:Create(mark, TweenInfo.new(15), {Transparency = 1}):Play()
	Debris:AddItem(mark, 15.1)
end

local function showCast(event)
	local origin, target = event.origin, event.position
	if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then return end
	local spell = event.spell
	if spell == "fire" then
		local length = math.min((target - origin).Magnitude, 32)
		local direction = (target - origin).Unit
		for i = 1, 9 do
			local at = origin + direction * (length * i / 9)
			burst(at, i % 2 == 0 and Color3.fromRGB(255, 99, 31) or Color3.fromRGB(255, 183, 62), 3, 2)
		end
		beam(origin, target, Color3.fromRGB(255, 120, 46), 0.3, 0.23)
		scorch(target, 5)
	elseif spell == "lightning" then
		local previous = origin
		for i = 1, 9 do
			local at = origin:Lerp(target, i / 9)
			if i < 9 then at += Vector3.new(math.random(-3, 3) * 0.35, math.random(-3, 3) * 0.35, math.random(-3, 3) * 0.35) end
		beam(previous, at, Color3.fromRGB(176, 155, 255), 0.28, 0.17)
		beam(previous, at, Color3.fromRGB(240, 235, 255), 0.07, 0.12)
		previous = at
		end
		burst(target, Color3.fromRGB(171, 144, 255), 22, 5)
	else
		beam(origin, target, Color3.fromRGB(205, 166, 255), 0.36, 0.28)
		burst(target, Color3.fromRGB(255, 119, 44), 55, 10)
		burst(target, Color3.fromRGB(168, 137, 255), 30, 12)
		scorch(target, 12)
	end
	if event.caster == player.UserId then
		castKick = 1
		hitFlash.BackgroundColor3 = spell == "lightning" and Color3.fromRGB(175, 151, 255) or Color3.fromRGB(255, 111, 46)
		hitFlash.BackgroundTransparency = 0.95
		TweenService:Create(hitFlash, TweenInfo.new(0.28), {BackgroundTransparency = 1}):Play()
	end
end

remote.OnClientEvent:Connect(function(kind, payload)
	if kind == "cast" and type(payload) == "table" then showCast(payload)
	elseif kind == "ignite" and typeof(payload) == "Vector3" then burst(payload + Vector3.new(0, 5, 0), Color3.fromRGB(255, 109, 42), 26, 7)
	elseif kind == "collapse" and typeof(payload) == "Vector3" then burst(payload + Vector3.new(0, 5, 0), Color3.fromRGB(91, 83, 75), 32, 9) end
end)

local function attachCharacter(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
	head = character:WaitForChild("Head")
	yaw = math.rad(root.Orientation.Y)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then descendant.LocalTransparencyModifier = 1 end
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then descendant.LocalTransparencyModifier = 1 end
	end)
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 15
	humanoid.JumpPower = 0
end
if player.Character then task.spawn(attachCharacter, player.Character) end
player.CharacterAdded:Connect(attachCharacter)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local key = input.KeyCode
	if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D or key == Enum.KeyCode.LeftShift then held[key] = true end
	if key == Enum.KeyCode.Q or key == Enum.KeyCode.E then
		if #queue < Rules.MaxQueue then table.insert(queue, key == Enum.KeyCode.Q and "fire" or "lightning") end
		refreshSpell()
	elseif key == Enum.KeyCode.C then table.clear(queue); refreshSpell()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.F then
		castSelection()
	end
end)
UserInputService.InputEnded:Connect(function(input) held[input.KeyCode] = nil end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		yaw -= input.Delta.X * 0.0022
		pitch = math.clamp(pitch - input.Delta.Y * 0.0022, -1.28, 1.28)
	end
end)

RunService:BindToRenderStep("RiftboundBodycam", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not character or not root or not head or humanoid.Health <= 0 then return end
	-- Roblox's default transparency controller can restore avatar parts during play.
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then descendant.LocalTransparencyModifier = 1 end
	end
	if workspace.CurrentCamera ~= camera then camera = workspace.CurrentCamera; for _, p in ipairs({leftArm, rightArm, leftHand, rightHand, staff, staffTip}) do p.Parent = camera end end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	camera.CameraType = Enum.CameraType.Scriptable
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	local movement = forward * ((held[Enum.KeyCode.W] and 1 or 0) - (held[Enum.KeyCode.S] and 1 or 0)) + right * ((held[Enum.KeyCode.D] and 1 or 0) - (held[Enum.KeyCode.A] and 1 or 0))
	if movement.Magnitude > 1 then movement = movement.Unit end
	humanoid.WalkSpeed = held[Enum.KeyCode.LeftShift] and 23 or 15
	humanoid:Move(movement, false)
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	local moving = movement.Magnitude > 0.1
	stride += dt * (moving and (held[Enum.KeyCode.LeftShift] and 13 or 9) or 2)
	castKick = math.max(0, castKick - dt * 4.5)
	local bob = moving and math.sin(stride) * 0.08 or 0
	local sway = moving and math.sin(stride * 0.5) * 0.012 or 0
	local headPosition = head.Position + Vector3.new(0, 0.08 + bob, 0)
	camera.CFrame = CFrame.new(headPosition) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch - castKick * 0.055, 0, sway)
	camera.Focus = camera.CFrame * CFrame.new(0, 0, -20)
	camera.FieldOfView += ((held[Enum.KeyCode.LeftShift] and 86 or 79) - camera.FieldOfView) * math.min(1, dt * 7)
	local cf = camera.CFrame
	local armSwing = math.sin(stride) * (moving and 0.15 or 0.025)
	leftArm.CFrame = cf * CFrame.new(-0.96, -1.4 + armSwing + castKick * 0.25, -2.15) * CFrame.Angles(-0.75 - castKick * 0.45, 0, -0.24)
	rightArm.CFrame = cf * CFrame.new(0.96, -1.46 - armSwing, -2.05) * CFrame.Angles(-0.6, 0, 0.21)
	leftHand.CFrame = leftArm.CFrame * CFrame.new(0, 0.7, 0)
	rightHand.CFrame = rightArm.CFrame * CFrame.new(0, 0.7, 0)
	staff.CFrame = cf * CFrame.new(1.08, -1.22 - armSwing, -3.05) * CFrame.Angles(math.rad(14), 0, math.rad(12))
	staffTip.CFrame = staff.CFrame * CFrame.new(0, 0, -1.15)
	clock.Text = string.format("● REC  %02d:%02d", math.floor(workspace.DistributedGameTime / 60), math.floor(workspace.DistributedGameTime % 60))
end)
