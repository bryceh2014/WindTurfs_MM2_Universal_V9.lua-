-- WindTurf Universal Ragdoll
-- Client-side ragdoll utility for Roblox experiences / executor environments.
-- Note: client-side physics changes may not replicate to the server or other players.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then return end

local ENV = (getgenv and getgenv()) or _G
if ENV.WindTurfRagdollLoaded then
    pcall(function() ENV.WindTurfRagdollLoaded:Destroy() end)
end

local connections = {}
local characterConnections = {}
local ragdollData = {}
local ragdollAttachments = {}
local ragdollConstraints = {}
local currentCharacter
local isRagdolled = false
local autoRestore = false
local duration = 5
local destroyed = false

local function track(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end

local function clearRagdoll()
    for _, item in ipairs(ragdollConstraints) do pcall(function() item:Destroy() end) end
    for _, item in ipairs(ragdollAttachments) do pcall(function() item:Destroy() end) end
    for motor, wasEnabled in pairs(ragdollData) do
        if motor and motor.Parent then
            pcall(function() motor.Enabled = wasEnabled end)
        end
    end
    table.clear(ragdollConstraints)
    table.clear(ragdollAttachments)
    table.clear(ragdollData)
    isRagdolled = false
end

local function restore()
    autoRestore = false
    clearRagdoll()
end

local function ragdoll()
    local character = LocalPlayer.Character
    if not character or isRagdolled then return end
    currentCharacter = character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local motors = {}
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 then
            table.insert(motors, descendant)
        end
    end

    if #motors == 0 then return end
    for _, motor in ipairs(motors) do
        local ok = pcall(function()
            local a0 = Instance.new("Attachment")
            local a1 = Instance.new("Attachment")
            a0.Name = "WindTurfRagdollA0"
            a1.Name = "WindTurfRagdollA1"
            a0.CFrame = motor.C0
            a1.CFrame = motor.C1
            a0.Parent = motor.Part0
            a1.Parent = motor.Part1

            local socket = Instance.new("BallSocketConstraint")
            socket.Name = "WindTurfRagdollSocket"
            socket.Attachment0 = a0
            socket.Attachment1 = a1
            socket.LimitsEnabled = true
            socket.UpperAngle = 45
            socket.TwistLimitsEnabled = true
            socket.TwistLowerAngle = -45
            socket.TwistUpperAngle = 45
            socket.Parent = motor.Parent

            table.insert(ragdollAttachments, a0)
            table.insert(ragdollAttachments, a1)
            table.insert(ragdollConstraints, socket)
            ragdollData[motor] = motor.Enabled
            motor.Enabled = false
        end)
        if not ok then
            -- Continue with other joints; restore button cleans up partial setups.
        end
    end

    isRagdolled = next(ragdollData) ~= nil
    if isRagdolled then
        autoRestore = true
        task.delay(duration, function()
            if autoRestore and isRagdolled and currentCharacter == LocalPlayer.Character then
                restore()
            end
        end)
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "WindTurfRagdollUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
ENV.WindTurfRagdollLoaded = gui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(500, 330)
main.Position = UDim2.new(0.5, -250, 0.5, -165)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
local outline = Instance.new("UIStroke", main)
outline.Color = Color3.fromRGB(190, 35, 45)
outline.Thickness = 1.5

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 38)
header.BackgroundColor3 = Color3.fromRGB(125, 20, 30)
header.BorderSizePixel = 0
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 0)
title.Size = UDim2.new(1, -110, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "WINDTURF  /  RAGDOLL"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local function makeButton(parent, text, pos, size)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(48, 48, 55)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 12
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local close = makeButton(header, "X", UDim2.new(1, -34, 0, 5), UDim2.fromOffset(27, 27))
close.BackgroundColor3 = Color3.fromRGB(170, 30, 40)
local minimize = makeButton(header, "–", UDim2.new(1, -66, 0, 5), UDim2.fromOffset(27, 27))

local sidebar = Instance.new("ScrollingFrame")
sidebar.Position = UDim2.fromOffset(8, 47)
sidebar.Size = UDim2.fromOffset(142, 274)
sidebar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
sidebar.BorderSizePixel = 0
sidebar.ScrollBarThickness = 3
sidebar.CanvasSize = UDim2.fromOffset(0, 0)
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 5)
local sideLayout = Instance.new("UIListLayout", sidebar)
sideLayout.Padding = UDim.new(0, 4)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
local sidePad = Instance.new("UIPadding", sidebar)
sidePad.PaddingTop = UDim.new(0, 6)
sidePad.PaddingLeft = UDim.new(0, 5)
sidePad.PaddingRight = UDim.new(0, 5)

local tabs = {
    {"Combat", "HOME"}, {"Coins", "COIN ESP"}, {"MiniGames", "MINI GAMES"},
    {"Hunter", "PLAYER"}, {"Visuals", "VISUALS"}, {"Map", "TELEPORT"},
    {"GameTools", "GAME TOOLS"}, {"Troll", "TROLL"}, {"Emotes", "EMOTES"},
    {"Crosshairs", "CROSSHAIR"}, {"Badges", "BADGES"}, {"Settings", "SETTINGS"},
    {"Misc", "MISC"}, {"Premium", "PREMIUM"}, {"Notes", "NOTES"},
    {"Suggestions", "SUGGESTIONS"}
}
for i, tab in ipairs(tabs) do
    local b = makeButton(sidebar, tab[1] .. "   " .. tab[2], UDim2.new(), UDim2.new(1, 0, 0, 27))
    b.LayoutOrder = i
    b.TextSize = 9
    b.BackgroundColor3 = i == 1 and Color3.fromRGB(115, 25, 35) or Color3.fromRGB(39, 39, 46)
end
sideLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    sidebar.CanvasSize = UDim2.fromOffset(0, sideLayout.AbsoluteContentSize.Y + 12)
end)

local content = Instance.new("Frame")
content.Position = UDim2.fromOffset(160, 47)
content.Size = UDim2.new(1, -168, 1, -55)
content.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
content.BorderSizePixel = 0
content.Parent = main
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 5)
local heading = Instance.new("TextLabel")
heading.BackgroundTransparency = 1
heading.Position = UDim2.fromOffset(14, 10)
heading.Size = UDim2.new(1, -28, 0, 26)
heading.Font = Enum.Font.GothamBold
heading.Text = "CHARACTER RAGDOLL"
heading.TextColor3 = Color3.fromRGB(235, 65, 75)
heading.TextSize = 15
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Parent = content
local info = Instance.new("TextLabel")
info.BackgroundTransparency = 1
info.Position = UDim2.fromOffset(14, 39)
info.Size = UDim2.new(1, -28, 0, 32)
info.Font = Enum.Font.Gotham
info.Text = "Toggle ragdoll on your character or restore normal joints."
info.TextColor3 = Color3.fromRGB(185, 185, 195)
info.TextSize = 11
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.Parent = content

local rag = makeButton(content, "RAGDOLL", UDim2.fromOffset(14, 82), UDim2.new(1, -28, 0, 36))
rag.BackgroundColor3 = Color3.fromRGB(145, 28, 40)
local unrag = makeButton(content, "RESTORE / UNRAGDOLL", UDim2.fromOffset(14, 126), UDim2.new(1, -28, 0, 36))
local durationLabel = Instance.new("TextLabel")
durationLabel.BackgroundTransparency = 1
durationLabel.Position = UDim2.fromOffset(14, 174)
durationLabel.Size = UDim2.new(1, -28, 0, 22)
durationLabel.Font = Enum.Font.GothamSemibold
durationLabel.Text = "AUTO RESTORE: 5 SECONDS"
durationLabel.TextColor3 = Color3.fromRGB(225, 225, 230)
durationLabel.TextSize = 11
durationLabel.TextXAlignment = Enum.TextXAlignment.Left
durationLabel.Parent = content

local slider = Instance.new("Frame")
slider.Position = UDim2.fromOffset(14, 202)
slider.Size = UDim2.new(1, -28, 0, 8)
slider.BackgroundColor3 = Color3.fromRGB(65, 65, 72)
slider.BorderSizePixel = 0
slider.Parent = content
Instance.new("UICorner", slider).CornerRadius = UDim.new(1, 0)
local fill = Instance.new("Frame")
fill.Size = UDim2.new((duration - 1) / 29, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(190, 35, 48)
fill.BorderSizePixel = 0
fill.Parent = slider
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
local knob = Instance.new("TextButton")
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Position = UDim2.new((duration - 1) / 29, 0, 0.5, 0)
knob.Size = UDim2.fromOffset(18, 18)
knob.Text = ""
knob.BackgroundColor3 = Color3.new(1, 1, 1)
knob.Parent = slider
Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
local draggingSlider = false
local function setDurationFromX(x)
    local alpha = math.clamp((x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
    duration = math.clamp(math.floor(1 + alpha * 29 + 0.5), 1, 30)
    fill.Size = UDim2.new((duration - 1) / 29, 0, 1, 0)
    knob.Position = UDim2.new((duration - 1) / 29, 0, 0.5, 0)
    durationLabel.Text = "AUTO RESTORE: " .. duration .. " SECONDS"
end
knob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSlider = true end
end)
slider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
        setDurationFromX(input.Position.X)
    end
end)
track(UserInputService.InputChanged, function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setDurationFromX(input.Position.X) end
end)
track(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSlider = false end
end)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(14, 226)
status.Size = UDim2.new(1, -28, 0, 28)
status.Font = Enum.Font.Gotham
status.Text = "STATUS: READY"
status.TextColor3 = Color3.fromRGB(140, 220, 155)
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = content

rag.MouseButton1Click:Connect(function()
    ragdoll()
    status.Text = isRagdolled and "STATUS: RAGDOLLED" or "STATUS: UNAVAILABLE"
    status.TextColor3 = isRagdolled and Color3.fromRGB(235, 175, 90) or Color3.fromRGB(230, 90, 90)
end)
unrag.MouseButton1Click:Connect(function()
    restore()
    status.Text = "STATUS: RESTORED"
    status.TextColor3 = Color3.fromRGB(140, 220, 155)
end)

local reopen = makeButton(gui, "W", UDim2.new(0, 16, 0.5, -20), UDim2.fromOffset(40, 40))
reopen.Visible = false
reopen.BackgroundColor3 = Color3.fromRGB(145, 25, 38)
Instance.new("UICorner", reopen).CornerRadius = UDim.new(1, 0)
minimize.MouseButton1Click:Connect(function() main.Visible = false; reopen.Visible = true end)
reopen.MouseButton1Click:Connect(function() main.Visible = true; reopen.Visible = false end)

local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = main.Position
    end
end)
track(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
track(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

local function cleanup()
    if destroyed then return end
    destroyed = true
    restore()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(characterConnections) do pcall(function() c:Disconnect() end) end
    if ENV.WindTurfRagdollLoaded == gui then ENV.WindTurfRagdollLoaded = nil end
    pcall(function() gui:Destroy() end)
end
close.MouseButton1Click:Connect(cleanup)
table.insert(characterConnections, LocalPlayer.CharacterAdded:Connect(function(character)
    currentCharacter = character
    restore()
    status.Text = "STATUS: NEW CHARACTER"
    status.TextColor3 = Color3.fromRGB(185, 185, 195)
end))

print("WindTurf Universal Ragdoll loaded")