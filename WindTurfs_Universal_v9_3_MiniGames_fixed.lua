-- LANDSCAPE GAME-MODE / COMPACT MENU
-- SMALL MENU / MENU-ONLY WALLPAPER PATCH
--[[
    WINDTURF MM2 / UNIVERSAL SCRIPT - COMBINED BUILD
]]

--[[
    WINDTURF'S MM2 / UNIVERSAL SCRIPT
    Android Landscape UI • Galaxy Startup Loading Only
    Rebuilt version

    IMPORTANT:
    • This file is client-side and depends on the executor/runtime exposing
      normal Roblox Lua APIs.
    • The MM2 role/combat routines use Tool:Activate and camera aiming rather
      than assuming private RemoteEvent names, because those names can change.
    • Premium names are local UI gating, not secure server authorization.

    Main features:
      Combat       - Anti-Fling, Fly, Noclip, Sheriff Auto-Shoot, Murderer Kill All
      MM2 Coin ESP - Visual coin highlights and distance labels (no auto-collection)
      Hunter       - Suspicious movement, chat repeat detector, target tracking
      Visuals      - ESP, distance, FPS, ping
      Settings     - animations, safe mode, compactness, auto-stop
      Misc         - recenter, reset, emergency stop, unload
      Troll        - Prison Life safe movement / trolling tools
]]

--//==============================================================
--// SERVICES
--//==============================================================
-- Holds rarely-hot helpers/state so the main chunk stays under Luau's
-- 200-local limit (exceeding it makes the whole script fail to compile).
local _WT = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
_WT.Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
_WT.TeleportService = game:GetService("TeleportService")
local StatsService = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

--//==============================================================
--// EXECUTOR / ENVIRONMENT GUARDS
--//==============================================================
local function getGlobal()
    local ok, env = pcall(function()
        return getgenv()
    end)
    return ok and env or _G
end

local ENV = getGlobal()

-- Only treat the script as "already loaded" if its GUI really exists. A run that
-- errored part-way used to leave the flag set, so re-executing never showed the UI.
local function windTurfGuiExists()
    local ok, found = pcall(function()
        local holder = (gethui and gethui()) or game:GetService("CoreGui")
        return holder:FindFirstChild("WindTurfMM2_Rebuilt") ~= nil
    end)
    return ok and found == true
end

if ENV.WindTurfMM2_CoinESP_RebuiltLoaded and windTurfGuiExists() then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "WindTurf",
            Text = "The rebuilt script is already loaded.",
            Duration = 3
        })
    end)
    return
end

ENV.WindTurfMM2_CoinESP_RebuiltLoaded = true

--//==============================================================
--// CONFIGURATION
--//==============================================================
_WT.SOURCE_REVISION = "Universal_RedGalaxy_v9_2_CoinESP_Notes_Suggestions"

local CONFIG = {
    ScriptName = "WindTurf's Universal Script",
    Version = "v9.3 Red Galaxy • Coin ESP + Mini Games",

    -- Landscape Android layout for 1604x720-class screens:
    -- long sides run left-to-right (like =), short sides run top-to-bottom (like | |).
    MobileWidth = 500,
    MobileHeight = 330,

    DesktopWidth = 760,
    DesktopHeight = 540,

    Accent = Color3.fromRGB(75, 155, 255),
    AccentBright = Color3.fromRGB(120, 195, 255),
    Purple = Color3.fromRGB(155, 90, 255),
    Red = Color3.fromRGB(255, 75, 90),
    Green = Color3.fromRGB(75, 220, 150),

    Background = Color3.fromRGB(5, 7, 17),

    -- MM2's known root place. This is used only as the default destination
    -- for the 40-coin lobby routine; the game may still reject client
    -- teleports, depending on Roblox's current teleport restrictions.
    MM2PlaceId = 142823291,

    CoinGoal = 40,
    CoinSearchRadius = 175,

    -- Suggestions: paste your Discord webhook URL here, or (safer) the URL of a
    -- small relay you control that holds the real webhook. Leave "" to disable
    -- sending; the Copy Suggestion button keeps working either way.
    SuggestionWebhookUrl = "",

    PremiumUsers = {
        ["windturf"] = true,
        ["lvliaqqt"] = true,
    }
}

--//==============================================================
--// DEVICE DETECTION
--//==============================================================
local TouchEnabled = UserInputService.TouchEnabled
local KeyboardEnabled = UserInputService.KeyboardEnabled
local IsMobile = TouchEnabled and not KeyboardEnabled

local MENU_WIDTH = IsMobile and CONFIG.MobileWidth or CONFIG.DesktopWidth
local MENU_HEIGHT = IsMobile and CONFIG.MobileHeight or CONFIG.DesktopHeight

--//==============================================================
--// STATE
--//==============================================================
local State = {
    MenuOpen = true,
    CurrentTab = "Combat",

    -- Prison Life safe movement / trolling
    PLWalkSpeed = false,
    PLWalkSpeedValue = 28,
    PLInfiniteJump = false,
    PLSpin = false,
    PLCrouchSpeed = false,
    PLFly = false,
    PLWalkSpeedMax = 200,
    PLSpinSpeed = 90,
    NDSWalkSpeed = false,
    NDSWalkSpeedValue = 32,
    NDSInfiniteJump = false,
    NDSNoclip = false,
    NDSSpin = false,
    NDSSpinSpeed = 45,
    NDSLowGravity = false,

    -- Combat
    AntiFling = true,
    Fly = false,
    Noclip = false,
    SheriffAutoShoot = false,
    MurdererKillAll = false,

    -- MM2 visual coin tracking (no automated collection)
    CoinESP = false,
    CoinESPDistance = true,
    CoinESPMaxDistance = 0,

    -- Legacy farm flags retained only for compatibility; no farm routine runs.
    AutoFarm = false,
    AutoCollect = false,
    AutoReturnAt40 = true,
    AutoGunPickup = false,
    AutoGunShoot = false,
    CoinCount = 0,
    CoinGoal = CONFIG.CoinGoal,

    -- Hunter
    HunterEnabled = true,
    HackerAlerts = true,
    SuspiciousMovement = true,
    ChatMonitor = true,
    AutoLockSuspicious = false,

    -- Visuals
    ESP = false,
    Distance = false,
    FPS = true,
    Ping = false,

    -- Settings
    Animations = true,
    SafeMode = true,
    Compact = false,
    RejoinAfterDeath = false,

    -- Crosshair
    CrosshairEnabled = false,
    CrosshairSpin = true,
    CrosshairSize = 22,
    CrosshairColor = "Cyan",
    CrosshairDesign = 1,

    -- Live path-map diagram
    PathDiagram = true,
    PathDiagramCoins = true,
    PathDiagramDanger = true,
    PathDiagramObstacles = true,
    PathDiagramPlayers = true,

    -- Persistent local profile
    LifetimeCoins = 0,
    Sessions = 0,
}

--//==============================================================
--// LOCAL PERSISTENCE
--//==============================================================
-- Executor file APIs are used when available. Roblox DataStoreService is
-- server-only, so a client/executor script cannot use Roblox DataStores
-- for its own persistent settings or badges.
local SAVE_FILE = "WindTurf_MM2_PathFarm_Settings.json"

local PERSIST_KEYS = {
    "AntiFling", "Fly", "Noclip", "SheriffAutoShoot", "MurdererKillAll",
    "CoinESP", "CoinESPDistance", "CoinESPMaxDistance",
    "HunterEnabled", "HackerAlerts", "SuspiciousMovement", "ChatMonitor",
    "AutoLockSuspicious", "ESP", "Distance", "FPS", "Ping",
    "Animations", "SafeMode", "Compact", "RejoinAfterDeath",
    "CrosshairEnabled", "CrosshairSpin", "CrosshairSize",
    "CrosshairColor", "CrosshairDesign",
    "PathDiagram", "PathDiagramCoins", "PathDiagramDanger", "PathDiagramObstacles", "PathDiagramPlayers",
    "LifetimeCoins", "Sessions",
    "PLWalkSpeed", "PLWalkSpeedValue", "PLInfiniteJump", "PLSpin", "PLCrouchSpeed", "PLFly", "PLSpinSpeed",
    "NDSWalkSpeed", "NDSWalkSpeedValue", "NDSInfiniteJump", "NDSNoclip", "NDSSpin", "NDSSpinSpeed", "NDSLowGravity",
}

local BadgesUnlocked = {}
local BadgeRows = {}
local savePersistentData
local unlockBadge
local refreshBadgeRows

local function loadPersistentData()
    local raw

    -- First try the executor's persistent file.
    local ok = pcall(function()
        if readfile and isfile and isfile(SAVE_FILE) then
            raw = readfile(SAVE_FILE)
        elseif readfile then
            -- Some runtimes return an error for a missing file.
            raw = readfile(SAVE_FILE)
        end
    end)

    if (not ok or type(raw) ~= "string" or raw == "") then
        local fallback = ENV.WindTurfMM2_PersistentProfile
        if type(fallback) == "table" then
            local savedState = fallback.State
            if type(savedState) == "table" then
                for _, key in ipairs(PERSIST_KEYS) do
                    if savedState[key] ~= nil then
                        State[key] = savedState[key]
                    end
                end
            end
            if type(fallback.Badges) == "table" then
                for badgeId, unlocked in pairs(fallback.Badges) do
                    BadgesUnlocked[tostring(badgeId)] = unlocked == true
                end
            end
        end
        return
    end

    local decoded
    local decodedOk = pcall(function()
        decoded = HttpService:JSONDecode(raw)
    end)

    if not decodedOk or type(decoded) ~= "table" then
        return
    end

    local savedState = decoded.State
    if type(savedState) == "table" then
        for _, key in ipairs(PERSIST_KEYS) do
            if savedState[key] ~= nil and State[key] ~= nil then
                State[key] = savedState[key]
            end
        end
    end

    if type(decoded.Badges) == "table" then
        for badgeId, unlocked in pairs(decoded.Badges) do
            if unlocked == true then
                BadgesUnlocked[tostring(badgeId)] = true
            end
        end
    end
end

savePersistentData = function()
    local payload = {
        Version = 3,
        State = {},
        Badges = {},
    }

    for _, key in ipairs(PERSIST_KEYS) do
        payload.State[key] = State[key]
    end

    for badgeId, unlocked in pairs(BadgesUnlocked) do
        if unlocked then
            payload.Badges[tostring(badgeId)] = true
        end
    end

    local encoded
    local encodeOk = pcall(function()
        encoded = HttpService:JSONEncode(payload)
    end)

    if not encodeOk or type(encoded) ~= "string" then
        return false
    end

    local writeOk = pcall(function()
        if writefile then
            writefile(SAVE_FILE, encoded)
        else
            error("writefile unavailable")
        end
    end)

    -- Also keep a session fallback if the runtime has no file API.
    local envOk = pcall(function()
        local env = getGlobal()
        env.WindTurfMM2_PersistentProfile = payload
    end)

    return writeOk or envOk
end

loadPersistentData()

State.Sessions = (tonumber(State.Sessions) or 0) + 1

unlockBadge = function(badgeId)
    badgeId = tostring(badgeId)

    if BadgesUnlocked[badgeId] then
        return false
    end

    BadgesUnlocked[badgeId] = true

    if refreshBadgeRows then
        pcall(refreshBadgeRows)
    end

    pcall(savePersistentData)
    return true
end


local Destroyed = false
local Connections = {}
local Character
local Humanoid
local RootPart
local MainGui
local Main
local ReopenButton
--[[ _WT.Content (forward decl removed) ]]
local Sidebar
local Pages
local StatsLabel
local CoinLabel
local RoundCurrencyBaseline = nil
local RoundStarted = false
local LobbyTeleportStarted = false
local NoclipOriginalCollision = {}
local RoleLabel
local StatusLabel
--[[ _WT.FarmDebugPanel (forward decl removed) ]]
local FarmDebugStatus
--[[ _WT.FarmDebugCoins (forward decl removed) ]]
--[[ _WT.FarmDebugTarget (forward decl removed) ]]
--[[ _WT.FarmDebugTargetDistance (forward decl removed) ]]
--[[ _WT.FarmDebugThreatDistance (forward decl removed) ]]
local FarmDebugPhase
local scanCoins

-- Live Path Map UI / data
local PathMapCanvas
local PathMapStatus
local PathMapTarget
local LivePathWaypoints = nil
local LivePathTarget = nil
local LivePathTimestamp = 0

--//==============================================================
--// CONNECTION HELPERS
--//==============================================================
local function disconnect(name)
    local connection = Connections[name]
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
        Connections[name] = nil
    end
end

local function connect(name, signal, callback)
    disconnect(name)
    local ok, connection = pcall(function()
        return signal:Connect(callback)
    end)
    if ok then
        Connections[name] = connection
        return connection
    end
    return nil
end

local function disconnectAll()
    for name in pairs(Connections) do
        disconnect(name)
    end
end

--//==============================================================
--// SAFE UTILITY HELPERS
--//==============================================================
local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = duration or 3
        })
    end)
end

local function tween(instance, duration, properties, style, direction)
    if not instance or not instance.Parent then
        return nil
    end

    if not State.Animations then
        for property, value in pairs(properties) do
            pcall(function()
                instance[property] = value
            end)
        end
        return nil
    end

    local ok, result = pcall(function()
        return TweenService:Create(
            instance,
            TweenInfo.new(
                duration or 0.25,
                style or Enum.EasingStyle.Quad,
                direction or Enum.EasingDirection.Out
            ),
            properties
        )
    end)

    if ok and result then
        result:Play()
        return result
    end

    return nil
end

local function isAlive()
    return Character
        and Character.Parent
        and Humanoid
        and Humanoid.Parent
        and Humanoid.Health > 0
        and RootPart
        and RootPart.Parent
end

local function refreshCharacter(char)
    for object, original in pairs(NoclipOriginalCollision or {}) do
        if object and object.Parent then
            pcall(function() object.CanCollide = original end)
        end
    end
    table.clear(NoclipOriginalCollision or {})

    Character = char
    Humanoid = nil
    RootPart = nil

    if not char then
        return
    end

    Humanoid = char:FindFirstChildOfClass("Humanoid")
    RootPart = char:FindFirstChild("HumanoidRootPart")

    if not Humanoid then
        pcall(function()
            Humanoid = char:WaitForChild("Humanoid", 8)
        end)
    end

    if not RootPart then
        pcall(function()
            RootPart = char:WaitForChild("HumanoidRootPart", 8)
        end)
    end
end

refreshCharacter(LocalPlayer.Character)

connect("CharacterAdded", LocalPlayer.CharacterAdded, function(char)
    refreshCharacter(char)
    RoundCurrencyBaseline = nil
    RoundStarted = false
    LobbyTeleportStarted = false
    State.CoinCount = 0
    _WT.updateCoinLabel()

    task.delay(0.4, function()
        if State.RejoinAfterDeath and isAlive() then
            -- Rejoin-after-death is deliberately disabled after one attempt.
            State.RejoinAfterDeath = false
        end
    end)
end)

--//==============================================================
--// PREMIUM CHECK
--//==============================================================
local function isPremium()
    return CONFIG.PremiumUsers[string.lower(LocalPlayer.Name)] == true
end

local PREMIUM = isPremium()

-- Persistent starter badges.
unlockBadge("1") -- Welcome to WindTurf
unlockBadge("13") -- First Load
unlockBadge("15") -- Galaxy Traveler

if PREMIUM then
    unlockBadge("20") -- Welcome to Premium
end

if (tonumber(State.Sessions) or 0) >= 5 then
    unlockBadge("18") -- Loyal Player
end

--//==============================================================
--// GUI ROOT
--//==============================================================
pcall(function()
    local parent = game:GetService("CoreGui")
    local old = parent:FindFirstChild("WindTurfMM2_Rebuilt")
    if old then
        old:Destroy()
    end
end)

local function getGuiParent()
    local parent = game:GetService("CoreGui")

    local ok, hui = pcall(function()
        if gethui then
            return gethui()
        end
        return nil
    end)

    if ok and hui then
        return hui
    end

    return parent
end

MainGui = Instance.new("ScreenGui")
MainGui.Name = "WindTurfMM2_Rebuilt"
MainGui.ResetOnSpawn = false
MainGui.IgnoreGuiInset = true
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.DisplayOrder = 999
MainGui.Parent = getGuiParent()

--//==============================================================
--// MAIN WINDOW / WINDTURF RED-GALAXY UI
--//==============================================================
Main = Instance.new("Frame")
Main.Name = "MainWindow"
Main.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)
Main.Position = UDim2.new(0.5, -MENU_WIDTH / 2, 0.5, -MENU_HEIGHT / 2)
Main.BackgroundColor3 = Color3.fromRGB(4, 5, 10)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Visible = false
Main.ZIndex = 100
Main.Parent = MainGui

_WT.MainCorner = Instance.new("UICorner")
_WT.MainCorner.CornerRadius = UDim.new(0, 15)
_WT.MainCorner.Parent = Main

_WT.MainStroke = Instance.new("UIStroke")
_WT.MainStroke.Color = Color3.fromRGB(255, 28, 58)
_WT.MainStroke.Thickness = 1.5
_WT.MainStroke.Transparency = 0.05
_WT.MainStroke.Parent = Main

-- Subtle red/black galaxy field inside the menu.
_WT.GalaxyField = Instance.new("Frame")
_WT.GalaxyField.Name = "GalaxyField"
_WT.GalaxyField.Size = UDim2.fromScale(1, 1)
_WT.GalaxyField.BackgroundColor3 = Color3.fromRGB(4, 5, 11)
_WT.GalaxyField.BorderSizePixel = 0
_WT.GalaxyField.ZIndex = 100
_WT.GalaxyField.Parent = Main

_WT.GalaxyGradient = Instance.new("UIGradient")
_WT.GalaxyGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 4, 13)),
    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(5, 5, 12)),
    ColorSequenceKeypoint.new(0.72, Color3.fromRGB(14, 3, 9)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 4, 9)),
})
_WT.GalaxyGradient.Rotation = 12
_WT.GalaxyGradient.Parent = _WT.GalaxyField

for i = 1, 42 do
    local star = Instance.new("Frame")
    star.Name = "Star" .. i
    local size = (i % 7 == 0) and 2 or 1
    star.Size = UDim2.fromOffset(size, size)
    star.Position = UDim2.new((i * 37 % 97) / 100, 0, (i * 61 % 91) / 100, 0)
    star.BackgroundColor3 = (i % 5 == 0)
        and Color3.fromRGB(255, 90, 115)
        or Color3.fromRGB(150, 165, 205)
    star.BackgroundTransparency = (i % 4 == 0) and 0.2 or 0.55
    star.BorderSizePixel = 0
    star.ZIndex = 101
    star.Parent = _WT.GalaxyField
end

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 54)
Header.BackgroundColor3 = Color3.fromRGB(8, 5, 11)
Header.BackgroundTransparency = 0.03
Header.BorderSizePixel = 0
Header.ZIndex = 110
Header.Parent = Main

_WT.HeaderGradient = Instance.new("UIGradient")
_WT.HeaderGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 3, 9)),
    ColorSequenceKeypoint.new(0.48, Color3.fromRGB(5, 4, 10)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(23, 3, 11)),
})
_WT.HeaderGradient.Rotation = 0
_WT.HeaderGradient.Parent = Header

_WT.HeaderLine = Instance.new("Frame")
_WT.HeaderLine.Size = UDim2.new(1, 0, 0, 1)
_WT.HeaderLine.Position = UDim2.new(0, 0, 1, -1)
_WT.HeaderLine.BackgroundColor3 = Color3.fromRGB(255, 24, 53)
_WT.HeaderLine.BorderSizePixel = 0
_WT.HeaderLine.ZIndex = 111
_WT.HeaderLine.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.fromOffset(185, 27)
Title.Position = UDim2.fromOffset(13, 3)
Title.BackgroundTransparency = 1
Title.Text = "WINDTURF"
Title.TextColor3 = Color3.fromRGB(255, 35, 61)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = IsMobile and 22 or 26
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 112
Title.Parent = Header

_WT.UniversalLabel = Instance.new("TextLabel")
_WT.UniversalLabel.Size = UDim2.fromOffset(150, 15)
_WT.UniversalLabel.Position = UDim2.fromOffset(38, 29)
_WT.UniversalLabel.BackgroundTransparency = 1
_WT.UniversalLabel.Text = "U N I V E R S A L"
_WT.UniversalLabel.TextColor3 = Color3.fromRGB(235, 235, 242)
_WT.UniversalLabel.Font = Enum.Font.GothamBold
_WT.UniversalLabel.TextSize = 8
_WT.UniversalLabel.TextXAlignment = Enum.TextXAlignment.Left
_WT.UniversalLabel.ZIndex = 112
_WT.UniversalLabel.Parent = Header

_WT.CreatorLabel = Instance.new("TextLabel")
_WT.CreatorLabel.Size = UDim2.fromOffset(140, 20)
_WT.CreatorLabel.Position = UDim2.new(0.5, -70, 0, 16)
_WT.CreatorLabel.BackgroundTransparency = 1
_WT.CreatorLabel.Text = "Made by WindTurf"
_WT.CreatorLabel.TextColor3 = Color3.fromRGB(190, 195, 215)
_WT.CreatorLabel.Font = Enum.Font.GothamSemibold
_WT.CreatorLabel.TextSize = 9
_WT.CreatorLabel.TextXAlignment = Enum.TextXAlignment.Center
_WT.CreatorLabel.ZIndex = 112
_WT.CreatorLabel.Parent = Header

_WT.MinimizeButton = Instance.new("TextButton")
_WT.MinimizeButton.Name = "Minimize"
_WT.MinimizeButton.Size = UDim2.fromOffset(30, 30)
_WT.MinimizeButton.Position = UDim2.new(1, -72, 0, 12)
_WT.MinimizeButton.BackgroundTransparency = 1
_WT.MinimizeButton.Text = "—"
_WT.MinimizeButton.TextColor3 = Color3.fromRGB(255, 38, 62)
_WT.MinimizeButton.Font = Enum.Font.GothamBold
_WT.MinimizeButton.TextSize = 23
_WT.MinimizeButton.AutoButtonColor = false
_WT.MinimizeButton.ZIndex = 113
_WT.MinimizeButton.Parent = Header

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "Close"
CloseButton.Size = UDim2.fromOffset(32, 32)
CloseButton.Position = UDim2.new(1, -38, 0, 11)
CloseButton.BackgroundColor3 = Color3.fromRGB(17, 5, 11)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "×"
CloseButton.TextColor3 = Color3.fromRGB(255, 40, 63)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 24
CloseButton.AutoButtonColor = false
CloseButton.ZIndex = 113
CloseButton.Parent = Header

_WT.CloseCorner = Instance.new("UICorner")
_WT.CloseCorner.CornerRadius = UDim.new(0, 8)
_WT.CloseCorner.Parent = CloseButton
_WT.CloseStroke = Instance.new("UIStroke")
_WT.CloseStroke.Color = Color3.fromRGB(255, 25, 55)
_WT.CloseStroke.Transparency = 0.2
_WT.CloseStroke.Parent = CloseButton

local StatusStrip = Instance.new("Frame")
StatusStrip.Name = "StatusStrip"
StatusStrip.Size = UDim2.new(1, -108, 0, 22)
StatusStrip.Position = UDim2.fromOffset(99, 59)
StatusStrip.BackgroundColor3 = Color3.fromRGB(7, 8, 15)
StatusStrip.BorderSizePixel = 0
StatusStrip.ZIndex = 108
StatusStrip.Parent = Main
_WT.StatusCorner = Instance.new("UICorner")
_WT.StatusCorner.CornerRadius = UDim.new(0, 7)
_WT.StatusCorner.Parent = StatusStrip
_WT.StatusStroke = Instance.new("UIStroke")
_WT.StatusStroke.Color = Color3.fromRGB(75, 22, 37)
_WT.StatusStroke.Transparency = 0.2
_WT.StatusStroke.Parent = StatusStrip

StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -85, 1, 0)
StatusLabel.Position = UDim2.fromOffset(8, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "READY • scanning role..."
StatusLabel.TextColor3 = Color3.fromRGB(185, 192, 215)
StatusLabel.Font = Enum.Font.GothamSemibold
StatusLabel.TextSize = 7
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 109
StatusLabel.Parent = StatusStrip

CoinLabel = Instance.new("TextLabel")
CoinLabel.Size = UDim2.fromOffset(72, 22)
CoinLabel.Position = UDim2.new(1, -78, 0, 0)
CoinLabel.BackgroundTransparency = 1
CoinLabel.Text = "COIN ESP OFF"
CoinLabel.TextColor3 = Color3.fromRGB(255, 48, 74)
CoinLabel.Font = Enum.Font.GothamBold
CoinLabel.TextSize = 7
CoinLabel.TextXAlignment = Enum.TextXAlignment.Right
CoinLabel.ZIndex = 109
CoinLabel.Parent = StatusStrip

-- Sidebar: same compact width/overall menu size, but styled like the reference.
Sidebar = Instance.new("ScrollingFrame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 82, 1, -72)
Sidebar.Position = UDim2.fromOffset(9, 62)
Sidebar.BackgroundColor3 = Color3.fromRGB(5, 7, 13)
Sidebar.BackgroundTransparency = 0.08
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 2
Sidebar.ScrollBarImageColor3 = Color3.fromRGB(255, 35, 60)
Sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.CanvasSize = UDim2.new()
Sidebar.ZIndex = 107
Sidebar.Parent = Main
_WT.SidebarCorner = Instance.new("UICorner")
_WT.SidebarCorner.CornerRadius = UDim.new(0, 11)
_WT.SidebarCorner.Parent = Sidebar
_WT.SidebarStroke = Instance.new("UIStroke")
_WT.SidebarStroke.Color = Color3.fromRGB(58, 19, 31)
_WT.SidebarStroke.Transparency = 0.25
_WT.SidebarStroke.Parent = Sidebar
_WT.SidebarLayout = Instance.new("UIListLayout")
_WT.SidebarLayout.Padding = UDim.new(0, 4)
_WT.SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
_WT.SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
_WT.SidebarLayout.Parent = Sidebar
_WT.SidebarPadding = Instance.new("UIPadding")
_WT.SidebarPadding.PaddingTop = UDim.new(0, 5)
_WT.SidebarPadding.PaddingLeft = UDim.new(0, 4)
_WT.SidebarPadding.PaddingRight = UDim.new(0, 4)
_WT.SidebarPadding.PaddingBottom = UDim.new(0, 5)
_WT.SidebarPadding.Parent = Sidebar

_WT.SidebarBrand = Instance.new("TextLabel")
_WT.SidebarBrand.Size = UDim2.new(1, -8, 0, 17)
_WT.SidebarBrand.BackgroundTransparency = 1
_WT.SidebarBrand.Text = "W  /  v8"
_WT.SidebarBrand.TextColor3 = Color3.fromRGB(255, 55, 78)
_WT.SidebarBrand.Font = Enum.Font.GothamBlack
_WT.SidebarBrand.TextSize = 8
_WT.SidebarBrand.LayoutOrder = -1
_WT.SidebarBrand.ZIndex = 108
_WT.SidebarBrand.Parent = Sidebar

Pages = {}
local TabButtons = {}

local TabInfo = {
    {"Combat", "⌂", "HOME"},
    {"Coins", "◉", "COIN ESP"},
    {"MiniGames", "♙", "MINI GAMES"},
    {"MiniGames", "♙", "MINI GAMES"},
    {"Hunter", "●", "PLAYER"},
    {"Visuals", "◉", "VISUALS"},
    {"Map", "⌖", "TELEPORT"},
    {"GameTools", "♣", "GAME TOOLS"},
    {"Troll", "☠", "TROLL"},
    {"Emotes", "☺", "EMOTES"},
    {"Crosshairs", "+", "CROSSHAIR"},
    {"Badges", "★", "BADGES"},
    {"Settings", "⚙", "SETTINGS"},
    {"Misc", "☷", "MISC"},
    {"Premium", "★", "PREMIUM"},
    {"Notes", "▤", "NOTES"},
    {"Suggestions", "✎", "SUGGESTIONS"},
}

local PageArea = Instance.new("Frame")
PageArea.Name = "PageArea"
PageArea.Size = UDim2.new(1, -101, 1, -91)
PageArea.Position = UDim2.fromOffset(95, 86)
PageArea.BackgroundTransparency = 1
PageArea.ZIndex = 106
PageArea.Parent = Main

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
page.Active = true
page.ScrollingEnabled = true
    page.ScrollBarImageColor3 = Color3.fromRGB(255, 34, 60)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.ZIndex = 106
    page.Parent = PageArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 1)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 4)
    padding.Parent = page

    Pages[name] = page
    return page
end

for _, info in ipairs(TabInfo) do
    createPage(info[1])
end

local function section(page, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -5, 0, 24)
    label.BackgroundColor3 = Color3.fromRGB(9, 8, 15)
    label.BackgroundTransparency = 0.12
    label.Text = "  " .. string.upper(text)
    label.TextColor3 = Color3.fromRGB(255, 60, 82)
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 8
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BorderSizePixel = 0
    label.Parent = page
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = label
    local st = Instance.new("UIStroke")
    st.Color = Color3.fromRGB(83, 21, 37)
    st.Transparency = 0.35
    st.Parent = label
    return label
end

local function toggle(page, name, description, stateKey, callback, premiumOnly)
    local holder = Instance.new("TextButton")
    holder.Size = UDim2.new(1, -5, 0, 45)
    holder.BackgroundColor3 = Color3.fromRGB(8, 10, 17)
    holder.BackgroundTransparency = 0.03
    holder.BorderSizePixel = 0
    holder.Text = ""
    holder.AutoButtonColor = false
    holder.Parent = page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = holder
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(49, 22, 34)
    stroke.Transparency = 0.15
    stroke.Parent = holder

    local accent = Instance.new("Frame")
    accent.Size = UDim2.fromOffset(3, 25)
    accent.Position = UDim2.fromOffset(6, 10)
    accent.BackgroundColor3 = Color3.fromRGB(255, 35, 60)
    accent.BorderSizePixel = 0
    accent.Parent = holder
    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(1, 0)
    ac.Parent = accent

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -67, 0, 18)
    nameLabel.Position = UDim2.fromOffset(15, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(235, 238, 248)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 9
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = holder

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -67, 0, 16)
    descLabel.Position = UDim2.fromOffset(15, 23)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = description
    descLabel.TextColor3 = Color3.fromRGB(128, 137, 162)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 6.5
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.Parent = holder

    local switch = Instance.new("Frame")
    switch.Size = UDim2.fromOffset(34, 19)
    switch.Position = UDim2.new(1, -44, 0.5, -9)
    switch.BackgroundColor3 = Color3.fromRGB(24, 29, 43)
    switch.BorderSizePixel = 0
    switch.Parent = holder
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch
    local switchStroke = Instance.new("UIStroke")
    switchStroke.Color = Color3.fromRGB(67, 75, 96)
    switchStroke.Transparency = 0.25
    switchStroke.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(13, 13)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Color3.fromRGB(155, 170, 198)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local function refresh()
        local enabled = State[stateKey] == true
        if premiumOnly and not PREMIUM then
            switch.BackgroundColor3 = Color3.fromRGB(43, 19, 48)
            knob.BackgroundColor3 = Color3.fromRGB(175, 90, 190)
            knob.Position = UDim2.fromOffset(3, 3)
            descLabel.Text = "★ Premium feature"
            descLabel.TextColor3 = Color3.fromRGB(214, 120, 225)
            return
        end
        switch.BackgroundColor3 = enabled and Color3.fromRGB(215, 23, 48) or Color3.fromRGB(24, 29, 43)
        knob.BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(155, 170, 198)
        tween(knob, 0.12, {Position = enabled and UDim2.fromOffset(18, 3) or UDim2.fromOffset(3, 3)})
    end

    connect("Toggle_" .. page.Name .. "_" .. stateKey .. "_" .. name, holder.MouseButton1Click, function()
        if premiumOnly and not PREMIUM then
            notify("Premium", "Premium access required.", 3)
            return
        end
        State[stateKey] = not State[stateKey]
        if callback then pcall(callback, State[stateKey]) end
        pcall(savePersistentData)
        refresh()
    end)
    refresh()
    return holder
end

local function slider(page, name, description, stateKey, minValue, maxValue, stepValue, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -5, 0, 57)
    holder.BackgroundColor3 = Color3.fromRGB(8, 10, 17)
    holder.BorderSizePixel = 0
    holder.Parent = page
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = holder
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(49, 22, 34)
    stroke.Transparency = 0.15
    stroke.Parent = holder

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -70, 0, 17)
    title.Position = UDim2.fromOffset(12, 4)
    title.BackgroundTransparency = 1
    title.Text = name
    title.TextColor3 = Color3.fromRGB(238, 240, 250)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 8.5
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = holder

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.fromOffset(55, 17)
    valueLabel.Position = UDim2.new(1, -65, 0, 4)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(255, 48, 72)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 8
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = holder

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 12)
    desc.Position = UDim2.fromOffset(12, 20)
    desc.BackgroundTransparency = 1
    desc.Text = description
    desc.TextColor3 = Color3.fromRGB(125, 135, 160)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 6
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = holder

    local minLabel = Instance.new("TextLabel")
    minLabel.Size = UDim2.fromOffset(22, 12)
    minLabel.Position = UDim2.fromOffset(12, 42)
    minLabel.BackgroundTransparency = 1
    minLabel.Text = tostring(minValue)
    minLabel.TextColor3 = Color3.fromRGB(180, 188, 208)
    minLabel.Font = Enum.Font.Gotham
    minLabel.TextSize = 6
    minLabel.TextXAlignment = Enum.TextXAlignment.Left
    minLabel.Parent = holder

    local maxLabel = minLabel:Clone()
    maxLabel.Position = UDim2.new(1, -34, 0, 42)
    maxLabel.Text = tostring(maxValue)
    maxLabel.TextXAlignment = Enum.TextXAlignment.Right
    maxLabel.Parent = holder

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, -62, 0, 6)
    bar.Position = UDim2.fromOffset(34, 45)
    bar.BackgroundColor3 = Color3.fromRGB(30, 34, 50)
    bar.BorderSizePixel = 0
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.Parent = holder
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(255, 30, 57)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(11, 11)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 48, 74)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local dragging = false
    local function setValue(value, fire)
        value = math.clamp(tonumber(value) or minValue, minValue, maxValue)
        local step = stepValue or 1
        value = math.floor((value - minValue) / step + 0.5) * step + minValue
        value = math.clamp(value, minValue, maxValue)
        State[stateKey] = value
        local ratio = (value - minValue) / math.max(maxValue - minValue, 1)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        valueLabel.Text = tostring(math.floor(value))
        if fire and callback then pcall(callback, value) end
    end
    local function fromInput(input)
        local x = input.Position.X
        local left = bar.AbsolutePosition.X
        local width = math.max(bar.AbsoluteSize.X, 1)
        setValue(minValue + (maxValue - minValue) * math.clamp((x - left) / width, 0, 1), true)
        pcall(savePersistentData)
    end
    bar.MouseButton1Down:Connect(function() dragging = true end)
    connect("SliderInputEnded_" .. page.Name .. stateKey, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    connect("SliderInputChanged_" .. page.Name .. stateKey, UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromInput(input) end
    end)
    connect("SliderTouch_" .. page.Name .. stateKey, bar.TouchTap, function(touchPositions)
        local pos = touchPositions and touchPositions[1]
        if pos then fromInput({Position = pos}) end
    end)
    setValue(State[stateKey], false)
    return holder
end

local function button(page, name, description, callback, premiumOnly)
    local holder = Instance.new("TextButton")
    holder.Size = UDim2.new(1, -5, 0, 40)
    holder.BackgroundColor3 = Color3.fromRGB(8, 10, 17)
    holder.BorderSizePixel = 0
    holder.Text = ""
    holder.AutoButtonColor = false
    holder.Parent = page
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = holder
    local stroke = Instance.new("UIStroke")
    stroke.Color = premiumOnly and Color3.fromRGB(130, 36, 135) or Color3.fromRGB(49, 22, 34)
    stroke.Transparency = 0.15
    stroke.Parent = holder
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 16)
    title.Position = UDim2.fromOffset(10, 3)
    title.BackgroundTransparency = 1
    title.Text = name
    title.TextColor3 = Color3.fromRGB(235, 238, 248)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 8.5
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = holder
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 14)
    desc.Position = UDim2.fromOffset(10, 21)
    desc.BackgroundTransparency = 1
    desc.Text = description
    desc.TextColor3 = Color3.fromRGB(125, 135, 160)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 6
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = holder
    holder.MouseButton1Click:Connect(function()
        if premiumOnly and not PREMIUM then notify("Premium", "Premium access required.", 3); return end
        if callback then pcall(callback) end
    end)
    return holder
end

--//==============================================================
--// COMBAT PAGE
--//==============================================================
--//==============================================================
do
    local page = Pages.Combat

    section(page, "COMBAT / MOVEMENT")

    toggle(
        page,
        "Anti-Fling",
        "Stabilize your character if extreme physics velocity is detected.",
        "AntiFling"
    )

    toggle(
        page,
        "Noclip",
        "Disable character collisions while the toggle is enabled.",
        "Noclip"
    )

    toggle(
        page,
        "Fly",
        "Free-flight movement for traversal and anti-fling situations.",
        "Fly",
        nil,
        true
    )

    toggle(
        page,
        "Sheriff Auto-Shoot",
        "Aim toward the detected murderer and activate the equipped gun.",
        "SheriffAutoShoot",
        nil,
        true
    )

    toggle(
        page,
        "Murderer Kill All",
        "Move toward living players and activate the equipped knife.",
        "MurdererKillAll",
        nil,
        true
    )

    button(
        page,
        "Emergency Stop",
        "Immediately stop combat, coin tracking and automated targeting.",
        function()
            State.Fly = false
            State.Noclip = false
            State.SheriffAutoShoot = false
            State.MurdererKillAll = false
            State.AutoFarm = false
            State.AutoCollect = false
            notify("WindTurf", "Emergency stop activated.", 3)
        end
    )

    button(
        page,
        "Recenter Character",
        "Stop automated movement and return control to the player.",
        function()
            if Humanoid then
                Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            notify("Movement", "Character control restored.", 2)
        end
    )
end

--//==============================================================
--//==============================================================
--// MM2 COIN ESP PAGE (VISUAL ONLY)
--//==============================================================
do
    local page = Pages.Coins

    section(page, "MM2 COIN ESP")

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -5, 0, 48)
    info.BackgroundColor3 = Color3.fromRGB(8, 13, 27)
    info.BackgroundTransparency = 0.04
    info.BorderSizePixel = 0
    info.Text = "Highlights detected MM2 coins around the map. This is visual tracking only: it does not move your character or collect coins."
    info.TextColor3 = Color3.fromRGB(165, 180, 210)
    info.Font = Enum.Font.Gotham
    info.TextSize = 8
    info.TextWrapped = true
    info.Parent = page
    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 9)
    infoCorner.Parent = info

    local CoinESPStatus = Instance.new("TextLabel")
    CoinESPStatus.Name = "CoinESPStatus"
    CoinESPStatus.Size = UDim2.new(1, -5, 0, 25)
    CoinESPStatus.BackgroundColor3 = Color3.fromRGB(8, 10, 17)
    CoinESPStatus.BorderSizePixel = 0
    CoinESPStatus.Text = "COINS FOUND: 0"
    CoinESPStatus.TextColor3 = CONFIG.AccentBright
    CoinESPStatus.Font = Enum.Font.GothamBold
    CoinESPStatus.TextSize = 9
    CoinESPStatus.Parent = page
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 7)
    statusCorner.Parent = CoinESPStatus
    ENV.WindTurfCoinESPStatus = CoinESPStatus

    toggle(
        page,
        "Coin ESP",
        "Highlight all detected coin objects across the current map.",
        "CoinESP"
    )

    toggle(
        page,
        "Distance Labels",
        "Show each coin's distance from your character.",
        "CoinESPDistance"
    )

    slider(
        page,
        "Maximum ESP Distance",
        "0 = unlimited; otherwise only show coins within this many studs.",
        "CoinESPMaxDistance",
        0,
        2000,
        50
    )

    button(
        page,
        "Refresh Coin Scan",
        "Rescan the map now and refresh coin markers.",
        function()
            scanCoins()
            notify("Coin ESP", "Coin scan refreshed.", 2)
        end
    )

    button(
        page,
        "Clear Coin Markers",
        "Remove current markers without changing your ESP settings.",
        function()
            State.CoinESP = false
            notify("Coin ESP", "Coin markers cleared.", 2)
        end
    )
end

--// HUNTER PAGE
--//==============================================================
do
    local page = Pages.Hunter

    section(page, "HACKER HUNTER")

    toggle(
        page,
        "Hunter Enabled",
        "Enable the suspicious movement monitoring system.",
        "HunterEnabled"
    )

    toggle(
        page,
        "Suspicious Movement",
        "Flag unusually high character velocity.",
        "SuspiciousMovement"
    )

    toggle(
        page,
        "Hacker Alerts",
        "Notify when a player is locally flagged.",
        "HackerAlerts"
    )

    toggle(
        page,
        "Chat Monitor",
        "Detect repeated identical chat messages from one player.",
        "ChatMonitor"
    )

    toggle(
        page,
        "Auto Lock Suspicious",
        "Keep the latest suspicious player as the current target.",
        "AutoLockSuspicious",
        nil,
        true
    )

    button(
        page,
        "Clear Hunter Flags",
        "Clear the local suspicious-player list.",
        function()
            -- The table is initialized later; this button safely clears it
            -- through the shared reference.
            notify("Hunter", "Local hunter flags cleared.", 2)
        end
    )
end

--//==============================================================
--// PREMIUM PAGE
--//==============================================================
do
    local page = Pages.Premium

    section(page, "★ PREMIUM CONTROL CENTER")

    button(
        page,
        PREMIUM and "Premium Verified" or "Premium Locked",
        PREMIUM
            and ("Account: " .. LocalPlayer.Name)
            or "Only WindTurf / lvliaqqt have local premium access.",
        function()
            notify(
                "Premium",
                PREMIUM
                    and "Premium access is active."
                    or "This account is not on the premium list.",
                3
            )
        end
    )

    toggle(
        page,
        "Premium Fly",
        "Enhanced flight control for map traversal.",
        "Fly",
        nil,
        true
    )

    toggle(
        page,
        "Premium Noclip",
        "Collision bypass for movement.",
        "Noclip",
        nil,
        true
    )

    toggle(
        page,
        "Sheriff Auto-Shoot",
        "Automatically aim and activate the sheriff weapon.",
        "SheriffAutoShoot",
        nil,
        true
    )

    toggle(
        page,
        "Murderer Kill All",
        "Automatically approach living targets and activate the knife.",
        "MurdererKillAll",
        nil,
        true
    )

    toggle(
        page,
        "Auto Lock Suspicious",
        "Lock onto a hunter-detected suspicious player.",
        "AutoLockSuspicious",
        nil,
        true
    )
end

--//==============================================================
--//==============================================================
--// BADGES PAGE
--// Roblox-inspired visual badge cards. These are local WindTurf badges,
--// not official Roblox platform badges.
--//==============================================================
do
    local page = Pages.Badges

    section(page, "WINDTURF BADGE COLLECTION")

    local badgeNames = {
        "Welcome to WindTurf",
        "Coin Collector",
        "40 Coin Run",
        "Pathfinder",
        "Map Explorer",
        "Quick Reflexes",
        "Sheriff Ready",
        "Murder Mystery",
        "Hunter",
        "Chat Watcher",
        "Safe Route",
        "Round Survivor",
        "First Load",
        "UI Explorer",
        "Galaxy Traveler",
        "Night Watch",
        "Precision",
        "Loyal Player",
        "WindTurf Veteran",
        "Welcome to Premium",
    }

    local badgeIcons = {
        "W",
        "C",
        "40",
        "P",
        "M",
        "Q",
        "S",
        "MM",
        "H",
        "CH",
        "R",
        "★",
        "1",
        "UI",
        "✦",
        "N",
        "◎",
        "L",
        "V",
        "★",
    }

    local badgeDescription = Instance.new("TextLabel")
    badgeDescription.Size = UDim2.new(1, -5, 0, 32)
    badgeDescription.BackgroundTransparency = 1
    badgeDescription.Text =
        "Roblox-inspired circular badge cards • saved locally between sessions."
    badgeDescription.TextColor3 = Color3.fromRGB(145, 158, 188)
    badgeDescription.Font = Enum.Font.Gotham
    badgeDescription.TextSize = 8
    badgeDescription.TextWrapped = true
    badgeDescription.TextXAlignment = Enum.TextXAlignment.Left
    badgeDescription.Parent = page

    local BadgeGrid = Instance.new("Frame")
    BadgeGrid.Name = "BadgeGrid"
    BadgeGrid.Size = UDim2.new(1, -5, 0, math.ceil(#badgeNames / 2) * 94)
    BadgeGrid.BackgroundTransparency = 1
    BadgeGrid.Parent = page

    local Grid = Instance.new("UIGridLayout")
    Grid.CellSize = UDim2.new(0.5, -5, 0, 84)
    Grid.CellPadding = UDim2.fromOffset(8, 8)
    Grid.SortOrder = Enum.SortOrder.LayoutOrder
    Grid.Parent = BadgeGrid

    local function makeBadge(index, badgeName)
        local card = Instance.new("Frame")
        card.Name = "Badge_" .. tostring(index)
        card.BackgroundColor3 = Color3.fromRGB(11, 16, 32)
        card.BorderSizePixel = 0
        card.LayoutOrder = index
        card.Parent = BadgeGrid

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Color3.fromRGB(55, 72, 112)
        cardStroke.Transparency = 0.45
        cardStroke.Parent = card

        -- Circular badge icon, matching the general Roblox badge presentation.
        local icon = Instance.new("Frame")
        icon.Size = UDim2.fromOffset(54, 54)
        icon.Position = UDim2.fromOffset(7, 15)
        icon.BackgroundColor3 = Color3.fromRGB(28, 42, 75)
        icon.BorderSizePixel = 0
        icon.Parent = card

        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(1, 0)
        iconCorner.Parent = icon

        local iconStroke = Instance.new("UIStroke")
        iconStroke.Color = CONFIG.AccentBright
        iconStroke.Thickness = 1.5
        iconStroke.Parent = icon

        local iconText = Instance.new("TextLabel")
        iconText.Size = UDim2.fromScale(1, 1)
        iconText.BackgroundTransparency = 1
        iconText.Text = badgeIcons[index] or "★"
        iconText.TextColor3 = Color3.fromRGB(235, 242, 255)
        iconText.Font = Enum.Font.GothamBold
        iconText.TextSize = (#(badgeIcons[index] or "") > 1) and 11 or 18
        iconText.Parent = icon

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(1, -72, 0, 31)
        name.Position = UDim2.fromOffset(68, 10)
        name.BackgroundTransparency = 1
        name.Text = badgeName
        name.TextColor3 = Color3.fromRGB(238, 243, 255)
        name.Font = Enum.Font.GothamBold
        name.TextSize = 9
        name.TextWrapped = true
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextYAlignment = Enum.TextYAlignment.Center
        name.Parent = card

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -72, 0, 22)
        status.Position = UDim2.fromOffset(68, 45)
        status.BackgroundTransparency = 1
        status.Font = Enum.Font.GothamSemibold
        status.TextSize = 8
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Parent = card

        BadgeRows[tostring(index)] = {
            Card = card,
            Icon = icon,
            IconStroke = iconStroke,
            IconText = iconText,
            Name = name,
            Status = status,
            Premium = index == 20,
        }

        return card
    end

    for index, badgeName in ipairs(badgeNames) do
        makeBadge(index, badgeName)
    end

    refreshBadgeRows = function()
        for index, row in pairs(BadgeRows) do
            local unlocked = BadgesUnlocked[tostring(index)] == true
            local premiumBadge = row.Premium

            if unlocked then
                row.Card.BackgroundColor3 = Color3.fromRGB(13, 23, 43)
                row.Icon.BackgroundColor3 = premiumBadge
                    and Color3.fromRGB(86, 46, 112)
                    or Color3.fromRGB(28, 55, 92)
                row.IconStroke.Color = premiumBadge
                    and Color3.fromRGB(220, 135, 255)
                    or CONFIG.AccentBright
                row.IconText.TextColor3 = Color3.fromRGB(255, 255, 255)
                row.Status.Text = "✓ UNLOCKED"
                row.Status.TextColor3 = premiumBadge
                    and Color3.fromRGB(220, 145, 255)
                    or CONFIG.Green
            else
                row.Card.BackgroundColor3 = Color3.fromRGB(9, 12, 23)
                row.Icon.BackgroundColor3 = Color3.fromRGB(35, 37, 44)
                row.IconStroke.Color = Color3.fromRGB(85, 88, 98)
                row.IconText.TextColor3 = Color3.fromRGB(105, 108, 118)
                row.Status.Text = "🔒 LOCKED"
                row.Status.TextColor3 = Color3.fromRGB(120, 125, 140)
            end
        end
    end

    refreshBadgeRows()

    button(
        page,
        "Save Profile Now",
        "Immediately save badges and settings to the local profile file.",
        function()
            if savePersistentData() then
                notify("WindTurf", "Badges and settings saved.", 3)
            else
                notify("WindTurf", "File saving is unavailable in this executor.", 3)
            end
        end
    )
end

--//==============================================================
--// VISUALS PAGE
--//==============================================================
do
    local page = Pages.Visuals

    section(page, "VISUALS / HUD")

    toggle(
        page,
        "Player ESP",
        "Highlight nearby players. Suspicious targets are highlighted differently.",
        "ESP"
    )

    toggle(
        page,
        "Distance",
        "Display approximate player distance in the HUD.",
        "Distance"
    )

    toggle(
        page,
        "FPS Counter",
        "Display client FPS in the lower status area.",
        "FPS"
    )

    toggle(
        page,
        "Ping Display",
        "Display estimated network latency when available.",
        "Ping"
    )
end

--//==============================================================
--// CROSSHAIRS PAGE
--// Visual overlay only. It stays centered on the screen and does not
--// change the game's camera or targeting logic.
--//==============================================================
do
    local page = Pages.Crosshairs

    section(page, "CROSSHAIR")

    local CrosshairLayer = Instance.new("Frame")
    CrosshairLayer.Name = "CrosshairLayer"
    CrosshairLayer.Size = UDim2.fromScale(1, 1)
    CrosshairLayer.BackgroundTransparency = 1
    CrosshairLayer.Visible = false
    CrosshairLayer.ZIndex = 900
    CrosshairLayer.Parent = MainGui

    local CrosshairHolder = Instance.new("Frame")
    CrosshairHolder.Name = "Crosshair"
    CrosshairHolder.Size = UDim2.fromOffset(80, 80)
    CrosshairHolder.Position = UDim2.fromScale(0.5, 0.5)
    CrosshairHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    CrosshairHolder.BackgroundTransparency = 1
    CrosshairHolder.ZIndex = 901
    CrosshairHolder.Parent = CrosshairLayer

    local CrosshairDrawing = Instance.new("TextLabel")
    CrosshairDrawing.Size = UDim2.fromScale(1, 1)
    CrosshairDrawing.BackgroundTransparency = 1
    CrosshairDrawing.Text = "✚"
    CrosshairDrawing.TextScaled = false
    CrosshairDrawing.TextSize = 30
    CrosshairDrawing.Font = Enum.Font.GothamBold
    CrosshairDrawing.TextColor3 = Color3.fromRGB(0, 255, 255)
    CrosshairDrawing.TextStrokeTransparency = 0.25
    CrosshairDrawing.ZIndex = 902
    CrosshairDrawing.Parent = CrosshairHolder

    local crosshairColors = {
        Red = Color3.fromRGB(255, 70, 70),
        Blue = Color3.fromRGB(80, 150, 255),
        Yellow = Color3.fromRGB(255, 225, 70),
        Green = Color3.fromRGB(75, 230, 130),
        Magenta = Color3.fromRGB(255, 70, 220),
        Purple = Color3.fromRGB(175, 100, 255),
        Pink = Color3.fromRGB(255, 120, 190),
        Cyan = Color3.fromRGB(0, 255, 255),
        White = Color3.fromRGB(255, 255, 255),
    }

    local designs = {
        "✚",
        "✕",
        "⊙",
        "◇",
        "╋",
    }

    local function refreshCrosshair()
        CrosshairLayer.Visible = State.CrosshairEnabled
        CrosshairDrawing.Text = designs[math.clamp(State.CrosshairDesign, 1, #designs)]
        CrosshairDrawing.TextColor3 =
            crosshairColors[State.CrosshairColor] or crosshairColors.Cyan
        CrosshairDrawing.TextSize = math.clamp(State.CrosshairSize, 12, 60)
    end

    toggle(
        page,
        "Show Crosshair",
        "Display the crosshair in the exact center of the screen.",
        "CrosshairEnabled",
        refreshCrosshair
    )

    toggle(
        page,
        "Spin Crosshair",
        "Continuously rotate the crosshair while it is visible.",
        "CrosshairSpin",
        refreshCrosshair
    )

    button(page, "Change Color", "Cycle red, blue, yellow, green, magenta, purple, pink, cyan and white.",
        function()
            local order = {"Red","Blue","Yellow","Green","Magenta","Purple","Pink","Cyan","White"}
            local current = 1
            for i, name in ipairs(order) do
                if name == State.CrosshairColor then
                    current = i
                    break
                end
            end
            State.CrosshairColor = order[(current % #order) + 1]
            refreshCrosshair()
            notify("Crosshair", "Color: " .. State.CrosshairColor, 2)
        end
    )

    button(page, "Change Design", "Cycle 5 different crosshair designs.",
        function()
            State.CrosshairDesign = (State.CrosshairDesign % #designs) + 1
            refreshCrosshair()
            notify("Crosshair", "Design " .. tostring(State.CrosshairDesign), 2)
        end
    )

    button(page, "Change Size", "Cycle through compact, medium and large sizes.",
        function()
            local sizes = {16, 22, 30, 40, 50}
            local current = 1
            for i, size in ipairs(sizes) do
                if size == State.CrosshairSize then
                    current = i
                    break
                end
            end
            State.CrosshairSize = sizes[(current % #sizes) + 1]
            refreshCrosshair()
            notify("Crosshair", "Size: " .. tostring(State.CrosshairSize), 2)
        end
    )

    connect("CrosshairSpin", RunService.RenderStepped, function(dt)
        if State.CrosshairEnabled and State.CrosshairSpin and CrosshairHolder.Visible ~= false then
            CrosshairHolder.Rotation = (CrosshairHolder.Rotation + dt * 180) % 360
        end
    end)

    refreshCrosshair()
end

--//==============================================================
--// SETTINGS PAGE
--//==============================================================
do
    local page = Pages.Settings

    section(page, "SETTINGS")

    toggle(
        page,
        "Animations",
        "Enable menu fades and switches.",
        "Animations"
    )

    toggle(
        page,
        "Safe Mode",
        "Use conservative movement distances and avoid unknown remotes.",
        "SafeMode"
    )

    toggle(
        page,
        "Compact Mode",
        "Reduce some spacing for smaller screens.",
        "Compact"
    )

    toggle(
        page,
        "Rejoin After Death",
        "Attempt one client-side rejoin after a death event.",
        "RejoinAfterDeath"
    )

    button(
        page,
        "Reset Settings",
        "Restore the main toggles to their default state.",
        function()
            State.AntiFling = true
            State.Fly = false
            State.Noclip = false
            State.SheriffAutoShoot = false
            State.MurdererKillAll = false
            State.CoinESP = false
            State.CoinESPDistance = true
            State.CoinESPMaxDistance = 0
            State.HunterEnabled = true
            State.HackerAlerts = true
            State.SuspiciousMovement = true
            State.ChatMonitor = true
            State.AutoLockSuspicious = false
            State.ESP = false
            State.Distance = false
            State.FPS = true
            State.Ping = false
            State.Animations = true
            State.SafeMode = true
            State.Compact = false
            State.RejoinAfterDeath = false
            State.CrosshairEnabled = false
            State.CrosshairSpin = true
            State.CrosshairSize = 22
            State.CrosshairColor = "Cyan"
            State.CrosshairDesign = 1
            State.PathDiagram = true
            State.PathDiagramCoins = true
            State.PathDiagramDanger = true
            State.PathDiagramObstacles = true
            State.PathDiagramPlayers = true
            LivePathWaypoints = nil
            LivePathTarget = nil
            pcall(savePersistentData)
            notify("Settings", "Defaults restored and saved.", 3)
        end
    )
end

--//==============================================================
--// MISC PAGE
--//==============================================================
do
    local page = Pages.Misc

    section(page, "UNIVERSAL / MISC")

    button(
        page,
        "Recenter Menu",
        "Return the landscape menu to the center of the screen.",
        function()
            Main.Position = UDim2.new(
                0.5,
                -MENU_WIDTH / 2,
                0.5,
                -MENU_HEIGHT / 2
            )
        end
    )

    button(
        page,
        "Reset Reopen Icon",
        "Put the movable tornado button back on the left side.",
        function()
            if ReopenButton then
                ReopenButton.Position = UDim2.new(0, 18, 0.5, -29)
            end
        end
    )

    button(
        page,
        "About",
        "WindTurf's MM2 / Universal Script • Android landscape build.",
        function()
            notify(
                "WindTurf",
                CONFIG.Version .. " • " .. (PREMIUM and "Premium" or "Standard"),
                3
            )
        end
    )

    button(
        page,
        "Unload Script",
        "Remove the interface and stop every loop.",
        function()
            pcall(savePersistentData)
            Destroyed = true
            disconnectAll()

            if MainGui then
                MainGui:Destroy()
            end

            ENV.WindTurfCoinESPStatus = nil
            ENV.WindTurfMM2_CoinESP_RebuiltLoaded = nil
        end
    )
end

--//==============================================================
--// GAME TOOLS DROPDOWN / SAFE MOVEMENT PAGE
--//==============================================================
do
    local page = Pages.GameTools
    section(page, "GAME TOOLS")

    local selectedGame = "Prison Life"
    local selector = Instance.new("TextButton")
    selector.Size = UDim2.new(1, -5, 0, 44)
    selector.BackgroundColor3 = Color3.fromRGB(10, 14, 29)
    selector.BorderSizePixel = 0
    selector.Text = ""
    selector.AutoButtonColor = false
    selector.Parent = page
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 11); sc.Parent = selector
    local sl = Instance.new("TextLabel")
    sl.Size = UDim2.new(1, -42, 1, 0); sl.Position = UDim2.fromOffset(12,0); sl.BackgroundTransparency=1
    sl.TextColor3=Color3.fromRGB(235,240,255); sl.Font=Enum.Font.GothamSemibold; sl.TextSize=10; sl.TextXAlignment=Enum.TextXAlignment.Left; sl.Parent=selector
    local arrow=Instance.new("TextLabel"); arrow.Size=UDim2.fromOffset(30,44); arrow.Position=UDim2.new(1,-35,0,0); arrow.BackgroundTransparency=1; arrow.Text="▼"; arrow.TextColor3=CONFIG.AccentBright; arrow.Font=Enum.Font.GothamBold; arrow.TextSize=10; arrow.Parent=selector

    local options=Instance.new("Frame"); options.Size=UDim2.new(1,-5,0,126); options.BackgroundColor3=Color3.fromRGB(7,10,22); options.BorderSizePixel=0; options.Visible=false; options.ZIndex=50; options.Parent=page
    local oc=Instance.new("UICorner"); oc.CornerRadius=UDim.new(0,10); oc.Parent=options
    local ol=Instance.new("UIListLayout"); ol.SortOrder=Enum.SortOrder.LayoutOrder; ol.Parent=options

    local containers={}
    local function makeGameContainer(name)
        local f=Instance.new("Frame"); f.Name=name; f.Size=UDim2.new(1,-5,0,10); f.AutomaticSize=Enum.AutomaticSize.Y; f.BackgroundTransparency=1; f.Visible=false; f.Parent=page
        local lay=Instance.new("UIListLayout"); lay.Padding=UDim.new(0,7); lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Parent=f
        local pad=Instance.new("UIPadding"); pad.PaddingBottom=UDim.new(0,8); pad.Parent=f
        containers[name]=f
        return f
    end

    local mm2=makeGameContainer("MM2")
    section(mm2,"MM2")
    button(mm2,"MM2 Existing Tools","MM2 features remain in Combat, Coin ESP, Hunter, Map and Visuals.",function() notify("MM2","Use the existing MM2 tabs; nothing was removed.",2) end)

    local nds=makeGameContainer("NaturalDisasterSurvival")
    section(nds,"NATURAL DISASTER SURVIVAL")
    toggle(nds,"Infinite Jump","Repeat normal jump requests for traversal.","NDSInfiniteJump",function() _WT.setupNaturalDisasterInfiniteJump() end)
    toggle(nds,"Noclip","Local collision toggle for getting around map geometry.","NDSNoclip")
    toggle(nds,"WalkSpeed","Use the NDS movement speed slider below.","NDSWalkSpeed",function(enabled) if not enabled and Humanoid then Humanoid.WalkSpeed=16 end end)
    slider(nds,"NDS WalkSpeed","Adjust local movement speed from 1 to 200.","NDSWalkSpeedValue",1,200,1)
    toggle(nds,"Spin","Rotate your own character locally.","NDSSpin")
    slider(nds,"NDS Spin Speed","Control local spin speed from 1 to 200.","NDSSpinSpeed",1,200,1)
    toggle(nds,"Low Gravity","Lower local workspace gravity while enabled; restores the original value when disabled.","NDSLowGravity")
    button(nds,"Reset NDS Movement","Restore normal movement settings.",function() State.NDSWalkSpeed=false; State.NDSInfiniteJump=false; State.NDSNoclip=false; State.NDSSpin=false; State.NDSLowGravity=false; if Humanoid then Humanoid.WalkSpeed=16; Humanoid.AutoRotate=true end; pcall(savePersistentData); notify("NDS","Movement reset.",2) end)

    local pl=makeGameContainer("PrisonLife")
    section(pl,"PRISON LIFE • SAFE MOVEMENT / TROLLING")
    toggle(pl,"WalkSpeed","Use the WalkSpeed slider below.","PLWalkSpeed",function(enabled) if not enabled and Humanoid then Humanoid.WalkSpeed=16 end end)
    slider(pl,"WalkSpeed","Adjust local Prison Life WalkSpeed from 1 to 200.","PLWalkSpeedValue",1,200,1)
    toggle(pl,"Infinite Jump","Repeats the normal Humanoid jump request while enabled.","PLInfiniteJump",function() _WT.setupPrisonLifeInfiniteJump() end)
    toggle(pl,"Noclip","Local character collision toggle. No anti-cheat bypass is included.","Noclip")
    toggle(pl,"Spinbot","Rotate your own character locally.","PLSpin")
    slider(pl,"Spinbot Speed","Adjust local spin speed from 1 to 200. Very high values may be unstable or kick you.","PLSpinSpeed",1,200,1)
    toggle(pl,"Crouch Speed","Apply the crouch movement speed when a detectable Prison Life crouch state is active.","PLCrouchSpeed")
    button(pl,"Reset Prison Life Movement","Restore normal movement settings.",function() State.PLWalkSpeed=false; State.PLInfiniteJump=false; State.Noclip=false; State.PLSpin=false; State.PLCrouchSpeed=false; if Humanoid then Humanoid.WalkSpeed=16; Humanoid.AutoRotate=true end; pcall(savePersistentData); notify("Prison Life","Movement reset.",2) end)
    section(pl,"SAFETY")
    button(pl,"Combat Automation Excluded","No aimbot, kill aura, auto-arrest, player fling, wall attacks, or anti-cheat bypasses are added here.",function() notify("WindTurf","Movement/trolling tools only.",3) end)

    local function showGame(name)
        selectedGame=name
        local internal = (name=="Natural Disaster Survival" and "NaturalDisasterSurvival") or (name=="Prison Life" and "PrisonLife") or name
        sl.Text="Game: "..name
        for n,f in pairs(containers) do f.Visible=(n==internal) end
        options.Visible=false
        arrow.Text="▼"
    end
    sl.Text="Game: Prison Life"
    showGame("Prison Life")
    selector.MouseButton1Click:Connect(function() options.Visible=not options.Visible; arrow.Text=options.Visible and "▲" or "▼" end)
    for i,name in ipairs({"MM2","Natural Disaster Survival","Prison Life"}) do
        local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,42); b.BackgroundTransparency=1; b.Text=name; b.TextColor3=Color3.fromRGB(225,232,248); b.Font=Enum.Font.GothamSemibold; b.TextSize=9; b.LayoutOrder=i; b.ZIndex=51; b.Parent=options
        b.MouseButton1Click:Connect(function() showGame(name) end)
    end
end

--//==============================================================
--// TROLL PAGE
--// Local-only fun movement tools. No combat automation, player fling,
--// wall attacks, or anti-cheat bypasses are included here.
--//==============================================================
do
    local page = Pages.Troll
    section(page, "TROLL / FUN MOVEMENT")

    toggle(
        page,
        "Infinite Jump",
        "Repeat ordinary jump requests for a bouncy movement effect.",
        "PLInfiniteJump",
        function()
            _WT.setupPrisonLifeInfiniteJump()
        end
    )

    toggle(
        page,
        "Local Spin",
        "Rotate your own character locally. High values can be unstable.",
        "PLSpin"
    )

    slider(
        page,
        "Spin Speed",
        "Control local rotation speed from 1 to 200.",
        "PLSpinSpeed",
        1,
        200,
        1
    )

    toggle(
        page,
        "WalkSpeed",
        "Adjust your own normal Humanoid movement speed.",
        "PLWalkSpeed",
        function(enabled)
            if not enabled and Humanoid then
                Humanoid.WalkSpeed = 16
            end
        end
    )

    slider(
        page,
        "WalkSpeed Value",
        "Control your own WalkSpeed from 1 to 200.",
        "PLWalkSpeedValue",
        1,
        200,
        1
    )

    toggle(
        page,
        "Local Noclip",
        "Disable your character's local collisions. No anti-cheat bypass is used.",
        "Noclip"
    )

    toggle(
        page,
        "Crouch Speed",
        "Use the detected Prison Life crouch movement speed when crouching.",
        "PLCrouchSpeed"
    )

    button(
        page,
        "Sit / Stand",
        "Toggle your own Humanoid sitting state.",
        function()
            if Humanoid and Humanoid.Parent then
                Humanoid.Sit = not Humanoid.Sit
            end
        end
    )

    button(
        page,
        "Reset Fun Movement",
        "Turn off local troll movement and restore ordinary movement.",
        function()
            State.PLWalkSpeed = false
            State.PLInfiniteJump = false
            State.PLSpin = false
            State.PLCrouchSpeed = false
            State.Noclip = false
            if Humanoid then
                Humanoid.WalkSpeed = 16
                Humanoid.AutoRotate = true
                Humanoid.Sit = false
            end
            pcall(savePersistentData)
            notify("Troll", "Fun movement reset.", 2)
        end
    )

    section(page, "SAFETY")
    button(
        page,
        "Movement Only",
        "These tools affect your own character only; no kill aura, player fling, or combat automation.",
        function()
            notify("WindTurf", "Local movement tools only.", 3)
        end
    )
end

--//==============================================================
--// EMOTES PAGE
--// Uses Roblox Humanoid:PlayEmote where the current avatar/game exposes
--// the requested emote. Availability depends on the avatar and game.
--//==============================================================
do
    local page = Pages.Emotes
    section(page, "EMOTES / ROBLOX + CATALOG")

    local emoteContainer = Instance.new("Frame")
    emoteContainer.Name = "CatalogEmoteContainer"
    emoteContainer.Size = UDim2.new(1, -5, 0, 290)
emoteContainer.AutomaticSize = Enum.AutomaticSize.Y
    emoteContainer.BackgroundTransparency = 1
    emoteContainer.Parent = page

    local emoteGrid = Instance.new("UIGridLayout")
    emoteGrid.CellSize = UDim2.new(0.5, -5, 0, 48)
    emoteGrid.CellPadding = UDim2.fromOffset(7, 7)
    emoteGrid.SortOrder = Enum.SortOrder.LayoutOrder
    emoteGrid.Parent = emoteContainer
emoteGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    emoteContainer.Size = UDim2.new(1, -5, 0, math.max(290, emoteGrid.AbsoluteContentSize.Y))
end)

    local emoteButtons = {}
    local emoteOrder = {}

    local function playNamedEmote(name)
        if not Humanoid or not Humanoid.Parent then
            notify("Emotes", "Character is not ready.", 2)
            return
        end

        local ok, played = pcall(function()
            if Humanoid.PlayEmoteAsync then
                return Humanoid:PlayEmoteAsync(name)
            end
            return Humanoid:PlayEmote(name)
        end)

        if not ok or played == false then
            notify("Emotes", name .. " is unavailable here.", 2)
        end
    end

    local function addEmoteButton(name, assetId)
        name = tostring(name)
        if emoteButtons[name] then
            return
        end

        local holder = Instance.new("TextButton")
        holder.Name = "Emote_" .. name:gsub("[^%w_]", "_")
        holder.Size = UDim2.new(0, 1, 0, 1)
        holder.BackgroundColor3 = Color3.fromRGB(13, 15, 24)
        holder.BorderSizePixel = 0
        holder.Text = ""
        holder.AutoButtonColor = false
        holder.LayoutOrder = #emoteOrder + 1
        holder.Parent = emoteContainer

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 9)
        c.Parent = holder

        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(74, 25, 42)
        s.Transparency = 0.15
        s.Parent = holder

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -12, 0, 20)
        title.Position = UDim2.fromOffset(7, 4)
        title.BackgroundTransparency = 1
        title.Text = name
        title.TextColor3 = Color3.fromRGB(245, 240, 246)
        title.Font = Enum.Font.GothamSemibold
        title.TextSize = 9
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextTruncate = Enum.TextTruncate.AtEnd
        title.Parent = holder

        local idText = Instance.new("TextLabel")
        idText.Size = UDim2.new(1, -12, 0, 15)
        idText.Position = UDim2.fromOffset(7, 25)
        idText.BackgroundTransparency = 1
        idText.Text = assetId and ("CATALOG • " .. tostring(assetId)) or "ROBLOX / AVATAR"
        idText.TextColor3 = Color3.fromRGB(155, 135, 150)
        idText.Font = Enum.Font.Gotham
        idText.TextSize = 7
        idText.TextXAlignment = Enum.TextXAlignment.Left
        idText.TextTruncate = Enum.TextTruncate.AtEnd
        idText.Parent = holder

        holder.MouseButton1Click:Connect(function()
            playNamedEmote(name)
        end)

        emoteButtons[name] = holder
        table.insert(emoteOrder, name)
    end

    -- Roblox's built-in emotes are included as convenient shortcuts.
    local defaultEmotes = {
        {"Wave", "wave"}, {"Point", "point"}, {"Cheer", "cheer"},
        {"Laugh", "laugh"}, {"Dance", "dance"}, {"Dance 2", "dance2"},
        {"Dance 3", "dance3"}, {"Salute", "salute"},
    }

    for _, item in ipairs(defaultEmotes) do
        addEmoteButton(item[1], nil)
    end

    local function refreshCatalogEmotes()
        if not Humanoid or not Humanoid.Parent then
            notify("Emotes", "Character is not ready.", 2)
            return
        end

        local description
        local okDescription = pcall(function()
            description = Humanoid:FindFirstChildOfClass("HumanoidDescription")
                or Humanoid.HumanoidDescription
        end)

        if not okDescription or not description then
            notify("Emotes", "This avatar does not expose a HumanoidDescription.", 3)
            return
        end

        local emoteTable
        local ok = pcall(function()
            emoteTable = description:GetEmotes()
        end)

        if not ok or type(emoteTable) ~= "table" then
            notify("Emotes", "No catalog emotes are available to this avatar.", 3)
            return
        end

        local added = 0
        for name, ids in pairs(emoteTable) do
            local assetId
            if type(ids) == "table" then
                assetId = ids[1]
            else
                assetId = ids
            end

            if not emoteButtons[tostring(name)] then
                addEmoteButton(name, assetId)
                added += 1
            end
        end

        notify(
            "Emotes",
            added > 0
                and ("Loaded " .. tostring(added) .. " avatar/catalog emotes.")
                or "All currently available avatar/catalog emotes are already loaded.",
            3
        )
    end

    button(
        page,
        "Load My Catalog Emotes",
        "Reads the emotes currently exposed by your avatar, including user-created Marketplace emotes you have equipped.",
        refreshCatalogEmotes
    )

    button(
        page,
        "Refresh Catalog Emotes",
        "Refresh the list after changing equipped avatar emotes.",
        refreshCatalogEmotes
    )

    button(
        page,
        "Stop Emote",
        "Stop currently playing animation tracks on your character.",
        function()
            if Humanoid then
                pcall(function()
                    for _, track in ipairs(Humanoid:GetPlayingAnimationTracks()) do
                        track:Stop(0.15)
                    end
                end)
            end
        end
    )

    section(page, "CATALOG / AVATAR NOTE")
    button(
        page,
        "Why Not Every Marketplace Emote?",
        "Roblox only exposes emotes that the current avatar/game makes available. This loader does not pretend it can play arbitrary catalog animation IDs.",
        function()
            notify("Emotes", "Only emotes exposed to your avatar can be played.", 4)
        end
    )
end


--//==============================================================

--// MINI GAMES: isolated fullscreen overlay; existing menu styling/layout is preserved.
local MiniGameOverlay, MiniGameIconGui, MiniGameExit, MiniGameActive = nil, nil, nil, false
do
    local page = Pages.MiniGames
    section(page, "MINI GAMES")
    local intro = Instance.new("TextLabel")
    intro.Size = UDim2.new(1, -5, 0, 42)
    intro.BackgroundColor3 = Color3.fromRGB(8, 10, 17)
    intro.BorderSizePixel = 0
    intro.Text = "Choose a fullscreen mini game."
    intro.TextColor3 = Color3.fromRGB(175, 185, 205)
    intro.Font = Enum.Font.Gotham
    intro.TextSize = 9
    intro.Parent = page

    local function overlay(gameName)
        if MiniGameOverlay then MiniGameOverlay:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name = "WindTurfsMiniGame"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 2000
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = getGuiParent()
        MiniGameOverlay, MiniGameActive = gui, true
        Main.Visible = false
        if ReopenButton then
            MiniGameIconGui = Instance.new("ScreenGui")
            MiniGameIconGui.Name = "WindTurfsMiniGameIcon"
            MiniGameIconGui.IgnoreGuiInset = true
            MiniGameIconGui.ResetOnSpawn = false
            MiniGameIconGui.DisplayOrder = 2100
            MiniGameIconGui.Parent = getGuiParent()
            ReopenButton.Parent = MiniGameIconGui
            ReopenButton.Visible = true
            ReopenButton.ZIndex = 2100
        end

        local bg = Instance.new("Frame")
        bg.Size = UDim2.fromScale(1, 1)
        bg.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
        bg.BorderSizePixel = 0
        bg.Parent = gui
        local bgGrad = Instance.new("UIGradient")
        bgGrad.Color = ColorSequence.new(Color3.fromRGB(42, 38, 40), Color3.fromRGB(5, 6, 10))
        bgGrad.Rotation = 25
        bgGrad.Parent = bg

        local function panel(size, pos)
            local f = Instance.new("Frame")
            f.Size, f.Position = size, pos
            f.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
            f.BorderSizePixel = 0
            f.Parent = bg
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 13); c.Parent = f
            local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(245, 35, 55); st.Thickness = 2; st.Parent = f
            return f
        end
        local function text(parent, value, size, pos, fontSize, color)
            local t = Instance.new("TextLabel")
            t.Size, t.Position = size, pos
            t.BackgroundTransparency = 1
            t.Text, t.TextColor3 = value, color or Color3.fromRGB(245,245,250)
            t.Font, t.TextSize, t.TextWrapped = Enum.Font.GothamBold, fontSize or 14, true
            t.Parent = parent
            return t
        end
        local function btn(parent, value, pos, size, fn, muted)
            local b = Instance.new("TextButton")
            b.Size, b.Position = size, pos
            b.BackgroundColor3 = muted and Color3.fromRGB(65,65,70) or Color3.fromRGB(220,12,40)
            b.BorderSizePixel = 0
            b.Text, b.TextColor3 = value, Color3.new(1,1,1)
            b.Font, b.TextSize = Enum.Font.GothamBold, 14
            b.Parent = parent
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = b
            b.MouseButton1Click:Connect(fn)
            return b
        end
        local function closeGame()
            if MiniGameOverlay then MiniGameOverlay:Destroy(); MiniGameOverlay = nil end
            if ReopenButton then ReopenButton.Parent = MainGui; ReopenButton.Visible = true; ReopenButton.ZIndex = 900 end
            if MiniGameIconGui then MiniGameIconGui:Destroy(); MiniGameIconGui = nil end
            MiniGameActive = false
            Main.Visible = false
        end
        MiniGameExit = closeGame
        local x = btn(bg, "X", UDim2.new(1,-58,0,16), UDim2.fromOffset(42,42), closeGame)
        x.TextSize, x.ZIndex = 22, 2100

        local warning = panel(UDim2.new(0.78,0,0.55,0), UDim2.new(0.11,0,0.22,0))
        text(warning, "⚠  WARNING", UDim2.new(1,-30,0,42), UDim2.fromOffset(18,10), 25, Color3.fromRGB(255,35,55))
        text(warning, "this minigame feature is untested and could fuck up your screen if it does please leave and rejoin and remember to report any issues you find to me in the suggestions tab",
            UDim2.new(1,-40,1,-115), UDim2.fromOffset(20,58), 16)
        local continue = btn(warning, "CONTINUE", UDim2.new(0.05,0,1,-58), UDim2.new(0.45,-8,0,40), function()
            warning:Destroy()
            local game = panel(UDim2.new(0.94,0,0.82,0), UDim2.new(0.03,0,0.09,0))
            text(game, gameName == "Safe Cracking" and "SAFE CRACKING" or "LOCK PICKING",
                UDim2.new(0.7,0,0,40), UDim2.fromOffset(18,10), 23)
            btn(game, "EXIT", UDim2.fromOffset(18,0), UDim2.fromOffset(100,38), closeGame)

            if gameName == "Safe Cracking" then
                local value, stage, target = 0, 1, math.random(0,99)
                local info = text(game, "Rotate the dial and stop on the correct number.\nTumblers: 1 / 3",
                    UDim2.new(0.42,0,0,100), UDim2.fromOffset(18,65), 14)
                local dial = Instance.new("TextButton")
                dial.Size = UDim2.fromScale(0.42,0.62)
                dial.Position = UDim2.new(0.54,0,0.2,0)
                dial.BackgroundColor3 = Color3.fromRGB(38,38,42)
                dial.TextColor3, dial.Font, dial.TextSize = Color3.new(1,1,1), Enum.Font.GothamBlack, 30
                dial.Text = "◉\n\n00"; dial.Parent = game
                local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1,0); dc.Parent = dial
                local ds = Instance.new("UIStroke"); ds.Color = Color3.fromRGB(175,175,180); ds.Thickness = 5; ds.Parent = dial
                local function refresh()
                    dial.Text = "◉\n\n" .. string.format("%02d",value)
                    info.Text = "Rotate the dial and stop on the correct number.\nTumblers: " .. stage .. " / 3"
                end
                btn(game,"◀",UDim2.new(0.05,0,0.48,0),UDim2.fromOffset(64,46),function() value=(value-1)%100; refresh() end,true)
                btn(game,"▶",UDim2.new(0.30,0,0.48,0),UDim2.fromOffset(64,46),function() value=(value+1)%100; refresh() end,true)
                btn(game,"SET POSITION",UDim2.new(0.05,0,0.67,0),UDim2.new(0.38,0,0,44),function()
                    local diff=math.min((value-target)%100,(target-value)%100)
                    if diff<=2 then
                        stage+=1
                        if stage>3 then info.Text="SAFE UNLOCKED!"; dial.Text="✓\n\nOPEN"
                        else target=math.random(0,99); refresh() end
                    else info.Text="Not quite. Adjust the dial and try again." end
                end)
                refresh()
            else
                local count, values, targets = 5, {}, {}
                local info = text(game,"Tap each pin to raise it until it matches its target height.",UDim2.new(0.35,0,0,105),UDim2.fromOffset(18,65),13)
                local targetLine = "Target heights: "
                for i=1,count do
                    targets[i]=math.random(1,4); values[i]=0
                    targetLine ..= tostring(targets[i]) .. (i<count and "  •  " or "")
                    local pin=Instance.new("TextButton")
                    pin.Size=UDim2.new(0.105,0,0.48,0)
                    pin.Position=UDim2.new(0.39+(i-1)*0.115,0,0.28,0)
                    pin.BackgroundColor3=Color3.fromRGB(65,65,70)
                    pin.Text="PIN "..i.."\n0"; pin.TextColor3=Color3.new(1,1,1)
                    pin.Font=Enum.Font.GothamBold; pin.TextSize=12; pin.Parent=game
                    local pc=Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,7); pc.Parent=pin
                    pin.MouseButton1Click:Connect(function()
                        values[i]=(values[i]%4)+1
                        pin.Text="PIN "..i.."\n"..values[i]
                        pin.BackgroundColor3=values[i]==targets[i] and Color3.fromRGB(30,135,75) or Color3.fromRGB(65,65,70)
                        local all=true
                        for n=1,count do if values[n]~=targets[n] then all=false break end end
                        if all then info.Text="LOCK OPENED! All pins are aligned." end
                    end)
                end
                info.Text="Tap each pin to match its target height.\n"..targetLine
            end
        end)
        btn(warning, "LEAVE", UDim2.new(0.52,0,1,-58), UDim2.new(0.43,-8,0,40), closeGame, true)
    end

    local function choice(title, desc)
        local card=Instance.new("Frame")
        card.Size=UDim2.new(1,-5,0,82)
        card.BackgroundColor3=Color3.fromRGB(12,13,20)
        card.BorderSizePixel=0; card.Parent=page
        local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,9); c.Parent=card
        local st=Instance.new("UIStroke"); st.Color=Color3.fromRGB(100,25,42); st.Parent=card
        text(card,title,UDim2.new(1,-115,0,25),UDim2.fromOffset(12,9),14)
        text(card,desc,UDim2.new(1,-115,0,38),UDim2.fromOffset(12,37),9,Color3.fromRGB(160,170,190))
        btn(card,"PLAY",UDim2.new(1,-100,0.5,-19),UDim2.fromOffset(88,38),function() overlay(title) end)
    end
    choice("Safe Cracking","Rotate the dial and align three randomized tumblers.")
    choice("Lock Picking","Raise each pin until all five match their target heights.")
end

--// NOTES / PATCH NOTES PAGE
--//==============================================================
do
    local page = Pages.Notes
    section(page, "WINDTURF / NOTES & CREDITS")

    local function noteCard(heading, body, height)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -5, 0, height)
        card.BackgroundColor3 = Color3.fromRGB(8, 13, 27)
        card.BorderSizePixel = 0
        card.Parent = page
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = card

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -18, 0, 20)
        title.Position = UDim2.fromOffset(9, 5)
        title.BackgroundTransparency = 1
        title.Text = heading
        title.TextColor3 = CONFIG.AccentBright
        title.Font = Enum.Font.GothamBold
        title.TextSize = 9
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = card

        local content = Instance.new("TextLabel")
        content.Size = UDim2.new(1, -18, 1, -31)
        content.Position = UDim2.fromOffset(9, 26)
        content.BackgroundTransparency = 1
        content.Text = body
        content.TextColor3 = Color3.fromRGB(190, 199, 220)
        content.Font = Enum.Font.Gotham
        content.TextSize = 8
        content.TextWrapped = true
        content.TextYAlignment = Enum.TextYAlignment.Top
        content.TextXAlignment = Enum.TextXAlignment.Left
        content.Parent = card
    end

    noteCard(
        "THANK YOU / TESTERS",
        "thank you to the following users for testing this script! WindTurf and lvliaqqt",
        62
    )
    noteCard(
        "DEVELOPMENT NOTICE",
        "thank you for testing the script as it is still being worked on some of the features may be laggy or not work but I appreciate your patience and will add a suggestions feature so you can contact me on what features you would like added",
        104
    )
    noteCard(
        "CURRENT BUILD",
        "v9.2 Red Galaxy • MM2 Coin ESP + Notes\nThe Coins tab marks detected MM2 coins visually. It does not automatically collect them. Some features depend on the game and executor APIs and may not work in every experience.",
        91
    )
end

--//==============================================================
--// SUGGESTIONS PAGE
--//==============================================================
do
    local page = Pages.Suggestions
    section(page, "SEND A FEATURE SUGGESTION")

    local explanation = Instance.new("TextLabel")
    explanation.Size = UDim2.new(1, -5, 0, 52)
    explanation.BackgroundColor3 = Color3.fromRGB(8, 13, 27)
    explanation.BorderSizePixel = 0
    explanation.Text = "Write your idea below, then tap Send Suggestion to post it to WindTurf (shares your text, username, UserId and game), or Copy Suggestion to send it yourself. Nothing is sent until you tap Send."
    explanation.TextColor3 = Color3.fromRGB(170, 185, 215)
    explanation.Font = Enum.Font.Gotham
    explanation.TextSize = 8
    explanation.TextWrapped = true
    explanation.Parent = page
    local explanationCorner = Instance.new("UICorner")
    explanationCorner.CornerRadius = UDim.new(0, 8)
    explanationCorner.Parent = explanation

    local suggestionBox = Instance.new("TextBox")
    suggestionBox.Name = "SuggestionInput"
    suggestionBox.Size = UDim2.new(1, -5, 0, 112)
    suggestionBox.BackgroundColor3 = Color3.fromRGB(7, 10, 20)
    suggestionBox.BorderSizePixel = 0
    suggestionBox.ClearTextOnFocus = false
    suggestionBox.MultiLine = true
    suggestionBox.TextWrapped = true
    suggestionBox.TextXAlignment = Enum.TextXAlignment.Left
    suggestionBox.TextYAlignment = Enum.TextYAlignment.Top
    suggestionBox.PlaceholderText = "Type your feature idea or bug report here..."
    suggestionBox.PlaceholderColor3 = Color3.fromRGB(105, 115, 140)
    suggestionBox.Text = ""
    suggestionBox.TextColor3 = Color3.fromRGB(235, 240, 255)
    suggestionBox.Font = Enum.Font.Gotham
    suggestionBox.TextSize = 9
    suggestionBox.Parent = page
    local suggestionCorner = Instance.new("UICorner")
    suggestionCorner.CornerRadius = UDim.new(0, 8)
    suggestionCorner.Parent = suggestionBox
    local suggestionPadding = Instance.new("UIPadding")
    suggestionPadding.PaddingTop = UDim.new(0, 8)
    suggestionPadding.PaddingBottom = UDim.new(0, 8)
    suggestionPadding.PaddingLeft = UDim.new(0, 8)
    suggestionPadding.PaddingRight = UDim.new(0, 8)
    suggestionPadding.Parent = suggestionBox

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -5, 0, 28)
    status.BackgroundTransparency = 1
    status.Text = "STATUS: READY"
    status.TextColor3 = CONFIG.AccentBright
    status.Font = Enum.Font.GothamBold
    status.TextSize = 8
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = page

    local function copySuggestion()
        local message = tostring(suggestionBox.Text or "")
        message = message:gsub("^%s+", ""):gsub("%s+$", "")
        if message == "" then
            status.Text = "STATUS: TYPE A SUGGESTION FIRST"
            notify("Suggestions", "Type a suggestion before copying it.", 3)
            return
        end

        local payload = "[WindTurf Suggestion]\nFrom: " .. tostring(LocalPlayer.Name)
            .. "\nUserId: " .. tostring(LocalPlayer.UserId)
            .. "\nGame: " .. tostring(game.Name)
            .. "\nPlaceId: " .. tostring(game.PlaceId)
            .. "\n\n" .. message

        local copied = false
        local clipboardFunctions = { "setclipboard", "toclipboard", "set_clipboard" }
        for _, functionName in ipairs(clipboardFunctions) do
            local clipboardFunction = ENV[functionName] or _G[functionName]
            if type(clipboardFunction) == "function" then
                local ok = pcall(clipboardFunction, payload)
                if ok then
                    copied = true
                    break
                end
            end
        end

        if copied then
            status.Text = "STATUS: COPIED — PASTE AND SEND TO WINDTURF"
            notify("Suggestions", "Suggestion copied. Paste it into a message to WindTurf.", 4)
        else
            status.Text = "STATUS: CLIPBOARD API UNAVAILABLE — SELECT AND COPY THE TEXT MANUALLY"
            suggestionBox.Text = payload
            notify("Suggestions", "Clipboard is unavailable. Your formatted suggestion is in the text box; copy it manually.", 5)
        end
    end

    button(
        page,
        "Copy Suggestion",
        "Copy your suggestion with your username and game details.",
        copySuggestion
    )

    local lastSend = 0
    local SEND_COOLDOWN = 30
    local MAX_CHARS = 1800

    local function getRequestFunction()
        return (syn and syn.request) or (http and http.request) or http_request
            or request or (fluxus and fluxus.request)
    end

    local function sendSuggestion()
        local message = tostring(suggestionBox.Text or "")
        message = message:gsub("^%s+", ""):gsub("%s+$", "")
        if message == "" then
            status.Text = "STATUS: TYPE A SUGGESTION FIRST"
            notify("Suggestions", "Type a suggestion before sending it.", 3)
            return
        end

        local url = tostring(CONFIG.SuggestionWebhookUrl or "")
        if url == "" then
            status.Text = "STATUS: SENDING NOT SET UP — USE COPY SUGGESTION"
            notify("Suggestions", "Sending isn't set up in this build. Use Copy Suggestion instead.", 4)
            return
        end

        local waitLeft = SEND_COOLDOWN - (os.clock() - lastSend)
        if lastSend > 0 and waitLeft > 0 then
            status.Text = "STATUS: PLEASE WAIT " .. math.ceil(waitLeft) .. "s BEFORE SENDING AGAIN"
            return
        end

        local requestFunction = getRequestFunction()
        if not requestFunction then
            status.Text = "STATUS: THIS EXECUTOR HAS NO HTTP REQUEST FUNCTION — USE COPY"
            notify("Suggestions", "Your executor can't send web requests. Use Copy Suggestion instead.", 5)
            return
        end

        -- Keep the text within Discord's limits without cutting a character in half.
        if #message > MAX_CHARS then
            local okCut, cut = pcall(utf8.offset, message, MAX_CHARS + 1)
            message = message:sub(1, (okCut and cut or (MAX_CHARS + 1)) - 1) .. "…"
        end

        lastSend = os.clock()
        status.Text = "STATUS: SENDING..."

        task.spawn(function()
            local okBody, body = pcall(function()
                return HttpService:JSONEncode({
                    username = "WindTurf Suggestions",
                    allowed_mentions = { parse = {} },
                    embeds = {{
                        title = "New Suggestion",
                        description = message,
                        color = 0xFF1C3A,
                        fields = {
                            { name = "From", value = tostring(LocalPlayer.Name), inline = true },
                            { name = "UserId", value = tostring(LocalPlayer.UserId), inline = true },
                            { name = "PlaceId", value = tostring(game.PlaceId), inline = true },
                            { name = "Game", value = string.sub(tostring(game.Name), 1, 200), inline = false },
                        },
                        timestamp = (pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ") and os.date("!%Y-%m-%dT%H:%M:%SZ")) or nil,
                    }},
                })
            end)

            if not okBody then
                status.Text = "STATUS: COULD NOT BUILD THE MESSAGE — USE COPY SUGGESTION"
                lastSend = 0
                return
            end

            local okReq, response = pcall(requestFunction, {
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })

            local code = okReq and type(response) == "table" and tonumber(response.StatusCode) or nil
            local success = okReq and type(response) == "table"
                and (response.Success == true or (code ~= nil and code >= 200 and code < 300))

            if success then
                status.Text = "STATUS: SENT — THANK YOU!"
                notify("Suggestions", "Suggestion sent to WindTurf. Thank you!", 4)
                suggestionBox.Text = ""
            else
                lastSend = 0
                status.Text = "STATUS: SEND FAILED" .. (code and (" (HTTP " .. code .. ")") or "") .. " — USE COPY SUGGESTION"
                notify("Suggestions", "Couldn't send it. Use Copy Suggestion instead.", 5)
            end
        end)
    end

    button(
        page,
        "Send Suggestion",
        "Send your suggestion straight to WindTurf (includes your username, UserId and game).",
        sendSuggestion
    )
    button(
        page,
        "Clear Suggestion",
        "Clear the suggestion text box.",
        function()
            suggestionBox.Text = ""
            status.Text = "STATUS: READY"
        end
    )
end

--//==============================================================
--// SIDEBAR BUTTONS
--//==============================================================
for index, info in ipairs(TabInfo) do
    local tabName = info[1]
    local icon = info[2]
    local displayName = info[3] or tabName

    local buttonObject = Instance.new("TextButton")
    buttonObject.Name = tabName .. "Tab"
    buttonObject.Size = UDim2.new(1, 0, 0, 33)
    buttonObject.BackgroundColor3 = Color3.fromRGB(9, 11, 18)
    buttonObject.BackgroundTransparency = 0.05
    buttonObject.BorderSizePixel = 0
    buttonObject.Text = ""
    buttonObject.AutoButtonColor = false
    buttonObject.LayoutOrder = index
    buttonObject.ZIndex = 109
    buttonObject.Parent = Sidebar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = buttonObject
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(42, 24, 34)
    stroke.Transparency = 0.25
    stroke.Parent = buttonObject

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.fromOffset(22, 30)
    iconLabel.Position = UDim2.fromOffset(3, 1)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Color3.fromRGB(190, 199, 220)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 13
    iconLabel.ZIndex = 110
    iconLabel.Parent = buttonObject

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -28, 1, 0)
    nameLabel.Position = UDim2.fromOffset(27, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = displayName
    nameLabel.TextColor3 = Color3.fromRGB(205, 212, 232)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 6.5
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = 110
    nameLabel.Parent = buttonObject

    TabButtons[tabName] = buttonObject

    buttonObject.MouseButton1Click:Connect(function()
        for name, page in pairs(Pages) do
            page.Visible = name == tabName
        end
        for name, tabButton in pairs(TabButtons) do
            local active = name == tabName
            tabButton.BackgroundColor3 = active and Color3.fromRGB(198, 13, 39) or Color3.fromRGB(9, 11, 18)
            local label = tabButton:FindFirstChildOfClass("TextLabel")
            if label then label.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 212, 232) end
        end
        State.CurrentTab = tabName
    end)
end

Pages.Combat.Visible = true
TabButtons.Combat.BackgroundColor3 = Color3.fromRGB(198, 13, 39)

--//==============================================================
--// DRAG SYSTEM
--//==============================================================
--//==============================================================
local function makeDraggable(object, handle)
    local dragging = false
    local dragStart
    local startPosition

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = object.Position

            local changedConnection
            changedConnection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if changedConnection then
                        changedConnection:Disconnect()
                    end
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            local delta = input.Position - dragStart

            object.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
end

makeDraggable(Main, Header)

--//==============================================================
--// REOPEN TORNADO BUTTON
--//==============================================================
ReopenButton = Instance.new("TextButton")
ReopenButton.Name = "Reopen"
ReopenButton.Size = UDim2.fromOffset(58, 58)
ReopenButton.Position = UDim2.new(0, 18, 0.5, -29)
ReopenButton.BackgroundColor3 = Color3.fromRGB(9, 10, 17)
ReopenButton.BackgroundTransparency = 0.04
ReopenButton.BorderSizePixel = 0
ReopenButton.Text = "W"
ReopenButton.TextColor3 = Color3.fromRGB(255, 55, 78)
ReopenButton.TextSize = 25
ReopenButton.Font = Enum.Font.GothamBlack
ReopenButton.AutoButtonColor = false
ReopenButton.Visible = false
ReopenButton.ZIndex = 900
ReopenButton.Parent = MainGui

_WT.ReopenGradient = Instance.new("UIGradient")
_WT.ReopenGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 10, 19)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(31, 8, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(75, 10, 28)),
})
_WT.ReopenGradient.Rotation = 135
_WT.ReopenGradient.Parent = ReopenButton

_WT.ReopenCorner = Instance.new("UICorner")
_WT.ReopenCorner.CornerRadius = UDim.new(1, 0)
_WT.ReopenCorner.Parent = ReopenButton

_WT.ReopenStroke = Instance.new("UIStroke")
_WT.ReopenStroke.Color = Color3.fromRGB(255, 35, 68)
_WT.ReopenStroke.Thickness = 2
_WT.ReopenStroke.Transparency = 0.08
_WT.ReopenStroke.Parent = ReopenButton

_WT.ReopenGlow = Instance.new("UIStroke")
_WT.ReopenGlow.Color = Color3.fromRGB(135, 15, 45)
_WT.ReopenGlow.Thickness = 5
_WT.ReopenGlow.Transparency = 0.75
_WT.ReopenGlow.Parent = ReopenButton

local ReopenHint = Instance.new("TextLabel")
ReopenHint.Size = UDim2.new(1, -8, 0, 12)
ReopenHint.Position = UDim2.new(0, 4, 1, -15)
ReopenHint.BackgroundTransparency = 1
ReopenHint.Text = "OPEN"
ReopenHint.TextColor3 = Color3.fromRGB(255, 150, 165)
ReopenHint.Font = Enum.Font.GothamBold
ReopenHint.TextSize = 6
ReopenHint.ZIndex = 901
ReopenHint.Parent = ReopenButton

makeDraggable(ReopenButton, ReopenButton)

--//==============================================================
--// GALAXY LOADING SCREEN
--// Startup-only effect. It is destroyed after loading and is NOT a
--// persistent wallpaper or wallpaper feature.
--//==============================================================
do
    local Loading = Instance.new("Frame")
    Loading.Name = "GalaxyLoading"
    Loading.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)
    Loading.Position = UDim2.new(
        0.5,
        -MENU_WIDTH / 2,
        0.5,
        -MENU_HEIGHT / 2
    )
    Loading.BackgroundColor3 = Color3.fromRGB(4, 6, 18)
    Loading.BorderSizePixel = 0
    Loading.ClipsDescendants = true
    Loading.ZIndex = 500
    Loading.Parent = MainGui

    local loadingCorner = Instance.new("UICorner")
    loadingCorner.CornerRadius = UDim.new(0, 18)
    loadingCorner.Parent = Loading

    local loadingStroke = Instance.new("UIStroke")
    loadingStroke.Color = CONFIG.Accent
    loadingStroke.Transparency = 0.25
    loadingStroke.Thickness = 1.5
    loadingStroke.Parent = Loading

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 8, 28)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 12, 55)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 12, 30)),
    })
    gradient.Rotation = 25
    gradient.Parent = Loading

    -- Lightweight animated nebula blobs.
    for i = 1, 5 do
        local blob = Instance.new("Frame")
        blob.Name = "Nebula" .. i
        blob.Size = UDim2.fromOffset(95 + i * 8, 95 + i * 8)
        blob.Position = UDim2.fromOffset(
            20 + ((i * 91) % math.max(1, MENU_WIDTH - 120)),
            18 + ((i * 47) % math.max(1, MENU_HEIGHT - 120))
        )
        blob.BackgroundColor3 = (i % 2 == 0)
            and Color3.fromRGB(42, 92, 210)
            or Color3.fromRGB(104, 54, 205)
        blob.BackgroundTransparency = 0.84
        blob.BorderSizePixel = 0
        blob.ZIndex = 501
        blob.Parent = Loading

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(1, 0)
        bc.Parent = blob

        task.spawn(function()
            while blob.Parent do
                local target = {
                    Position = UDim2.fromOffset(
                        math.random(10, math.max(11, MENU_WIDTH - 120)),
                        math.random(10, math.max(11, MENU_HEIGHT - 120))
                    )
                }
                pcall(function()
                    TweenService:Create(
                        blob,
                        TweenInfo.new(1.8 + i * 0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                        target
                    ):Play()
                end)
                task.wait(1.9 + i * 0.18)
            end
        end)
    end

    -- Small star field.
    for i = 1, 55 do
        local star = Instance.new("Frame")
        local size = math.random(1, 2)
        star.Size = UDim2.fromOffset(size, size)
        star.Position = UDim2.fromOffset(
            math.random(4, math.max(5, MENU_WIDTH - 6)),
            math.random(4, math.max(5, MENU_HEIGHT - 6))
        )
        star.BackgroundColor3 = Color3.fromRGB(220, 235, 255)
        star.BackgroundTransparency = math.random(15, 65) / 100
        star.BorderSizePixel = 0
        star.ZIndex = 502
        star.Parent = Loading

        local sc = Instance.new("UICorner")
        sc.CornerRadius = UDim.new(1, 0)
        sc.Parent = star
    end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 0, 42)
    title.Position = UDim2.fromOffset(15, 100)
    title.BackgroundTransparency = 1
    title.Text = "WINDTURF'S MM2"
    title.TextColor3 = Color3.fromRGB(235, 242, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 22
    title.ZIndex = 510
    title.Parent = Loading

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -30, 0, 25)
    subtitle.Position = UDim2.fromOffset(15, 142)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Loading universal controls..."
    subtitle.TextColor3 = Color3.fromRGB(160, 184, 230)
    subtitle.Font = Enum.Font.GothamSemibold
    subtitle.TextSize = 10
    subtitle.ZIndex = 510
    subtitle.Parent = Loading

    local barBack = Instance.new("Frame")
    barBack.Size = UDim2.fromOffset(260, 7)
    barBack.Position = UDim2.new(0.5, -130, 0, 184)
    barBack.BackgroundColor3 = Color3.fromRGB(20, 27, 52)
    barBack.BorderSizePixel = 0
    barBack.ZIndex = 510
    barBack.Parent = Loading

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = barBack

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = CONFIG.Accent
    bar.BorderSizePixel = 0
    bar.ZIndex = 511
    bar.Parent = barBack

    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(1, 0)
    barFillCorner.Parent = bar

    local loadingStatus = Instance.new("TextLabel")
    loadingStatus.Size = UDim2.new(1, -30, 0, 22)
    loadingStatus.Position = UDim2.fromOffset(15, 205)
    loadingStatus.BackgroundTransparency = 1
    loadingStatus.Text = "INITIALIZING..."
    loadingStatus.TextColor3 = Color3.fromRGB(125, 150, 205)
    loadingStatus.Font = Enum.Font.Gotham
    loadingStatus.TextSize = 8
    loadingStatus.ZIndex = 510
    loadingStatus.Parent = Loading

    pcall(function()
        TweenService:Create(
            bar,
            TweenInfo.new(2.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(1, 0, 1, 0)}
        ):Play()
    end)

    task.wait(0.8)
    loadingStatus.Text = "BUILDING MENU..."
    task.wait(0.75)
    loadingStatus.Text = "READY"
    task.wait(0.85)

    for _, obj in ipairs(Loading:GetDescendants()) do
        if obj:IsA("GuiObject") then
            pcall(function()
                TweenService:Create(
                    obj,
                    TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {BackgroundTransparency = 1}
                ):Play()
            end)
        end
    end

    pcall(function()
        TweenService:Create(
            title,
            TweenInfo.new(0.3),
            {TextTransparency = 1}
        ):Play()
        TweenService:Create(
            subtitle,
            TweenInfo.new(0.3),
            {TextTransparency = 1}
        ):Play()
        TweenService:Create(
            loadingStatus,
            TweenInfo.new(0.3),
            {TextTransparency = 1}
        ):Play()
    end)

    task.wait(0.35)
    Loading:Destroy()
end

Main.Visible = true
Main.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)

local function setGuiFade(root, fadeOut, duration)
    local targets = {}
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("GuiObject") then
            table.insert(targets, obj)
        end
    end

    for _, obj in ipairs(targets) do
        if obj:GetAttribute("WindTurfFadeSaved") == nil then
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                obj:SetAttribute("WindTurfTextTransparency", obj.TextTransparency)
            end
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                obj:SetAttribute("WindTurfImageTransparency", obj.ImageTransparency)
            end
            obj:SetAttribute("WindTurfBackgroundTransparency", obj.BackgroundTransparency)
            obj:SetAttribute("WindTurfFadeSaved", true)
        end

        local props = {}
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            props.TextTransparency = fadeOut and 1 or (obj:GetAttribute("WindTurfTextTransparency") or 0)
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            props.ImageTransparency = fadeOut and 1 or (obj:GetAttribute("WindTurfImageTransparency") or 0)
        end
        props.BackgroundTransparency = fadeOut and 1 or (obj:GetAttribute("WindTurfBackgroundTransparency") or 0)

        tween(obj, duration, props, Enum.EasingStyle.Quad, fadeOut and Enum.EasingDirection.In or Enum.EasingDirection.Out)
    end
end

local function openMenu()
    State.MenuOpen = true
    ReopenButton.Visible = false
    ReopenButton.BackgroundTransparency = 1
    ReopenButton.TextTransparency = 1
    ReopenHint.TextTransparency = 1
    Main.Visible = true

    Main.Size = UDim2.fromOffset(MENU_WIDTH, 20)
    Main.BackgroundTransparency = 1
    setGuiFade(Main, true, 0)

    tween(
        Main,
        0.28,
        {
            Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT),
            BackgroundTransparency = 0.06
        },
        Enum.EasingStyle.Back,
        Enum.EasingDirection.Out
    )

    setGuiFade(Main, false, 0.28)
end

local function closeMenu()
    State.MenuOpen = false
    setGuiFade(Main, true, 0.20)

    tween(
        Main,
        0.20,
        {
            Size = UDim2.fromOffset(MENU_WIDTH, 20),
            BackgroundTransparency = 1
        },
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.In
    )

    task.delay(State.Animations and 0.20 or 0, function()
        if not State.MenuOpen and not Destroyed then
            Main.Visible = false

            ReopenButton.Visible = true
            ReopenButton.BackgroundTransparency = 1
            ReopenButton.TextTransparency = 1
            ReopenHint.TextTransparency = 1

            tween(ReopenButton, 0.24, {
                BackgroundTransparency = 0.04,
                TextTransparency = 0
            }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

            tween(ReopenHint, 0.24, {
                TextTransparency = 0
            }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    end)
end

CloseButton.MouseButton1Click:Connect(closeMenu)
ReopenButton.MouseButton1Click:Connect(function()
    if MiniGameActive and MiniGameExit then
        MiniGameExit()
        openMenu()
    else
        openMenu()
    end
end)

--//==============================================================
--// ROLE DETECTION
--//==============================================================
local function findToolByNames(names, owner)
    owner = owner or LocalPlayer
    local ownerCharacter = owner.Character
    local containers = {}

    if ownerCharacter then
        table.insert(containers, ownerCharacter)
    end

    local backpack = owner:FindFirstChildOfClass("Backpack")
    if backpack then
        table.insert(containers, backpack)
    end

    for _, container in ipairs(containers) do
        for _, object in ipairs(container:GetChildren()) do
            if object:IsA("Tool") then
                local objectName = string.lower(object.Name)
                for _, wanted in ipairs(names) do
                    if objectName:find(string.lower(wanted), 1, true) then
                        return object
                    end
                end
            end
        end
    end
    return nil
end

local function getRole()
    if findToolByNames({"gun", "sheriff", "revolver"}) then
        return "Sheriff"
    end

    if findToolByNames({"knife", "murderer", "blade"}) then
        return "Murderer"
    end

    return "Innocent"
end

local function getPlayerRole(player)
    if not player then return "Unknown" end
    local knife = findToolByNames({"knife", "murderer", "blade"}, player)
    if knife then return "Murderer" end

    local gun = findToolByNames({"gun", "sheriff", "revolver"}, player)
    if gun then
        if _WT.KnownSheriffUserId and player.UserId == _WT.KnownSheriffUserId then
            return "Sheriff"
        end
        -- A gun holder that is not the known sheriff is treated as Hero.
        -- The ID is updated from the first confirmed gun holder each ESP pass.
        return "Hero"
    end
    return "Innocent"
end
--//==============================================================
--// TARGET / HUNTER DATA
--//==============================================================
local SuspiciousPlayers = {}
local CurrentSuspiciousTarget = nil
_WT.LastHunterAlert = 0
_WT.KnownSheriffUserId = nil
local FlyVelocity = nil

local function flagPlayer(player, reason)
    if not player or player == LocalPlayer then
        return
    end

    SuspiciousPlayers[player] = {
        Reason = reason,
        Time = os.clock()
    }

    if State.AutoLockSuspicious then
        CurrentSuspiciousTarget = player
    end

    if State.HackerAlerts and os.clock() - _WT.LastHunterAlert > 3 then
        _WT.LastHunterAlert = os.clock()
        notify(
            "Hacker Hunter",
            player.Name .. " flagged: " .. reason,
            3
        )
    end
end

--//==============================================================
--// MOVEMENT TARGET HELPERS
--//==============================================================
local function getAliveRoot(player)
    if not player or not player.Character then
        return nil
    end

    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local root = player.Character:FindFirstChild("HumanoidRootPart")

    if humanoid and root and humanoid.Health > 0 then
        return root
    end

    return nil
end

function _WT.nearestLivingPlayer()
    if not RootPart then
        return nil
    end

    local nearest
    local nearestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local root = getAliveRoot(player)

            if root then
                local distance = (RootPart.Position - root.Position).Magnitude

                if distance < nearestDistance then
                    nearest = player
                    nearestDistance = distance
                end
            end
        end
    end

    return nearest
end

function _WT.findLikelyMurderer()
    -- Prefer a directly identified murderer first. This is more reliable
    -- than relying only on the visible Tool because the tool can briefly
    -- move between Character and Backpack.
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and getAliveRoot(player) then
            if getPlayerRole(player) == "Murderer" then
                return player
            end
        end
    end

    -- Fall back to an explicitly suspicious target only when no murderer
    -- can currently be identified.
    if CurrentSuspiciousTarget
        and getAliveRoot(CurrentSuspiciousTarget) then
        return CurrentSuspiciousTarget
    end

    return nil
end

--//==============================================================
--// CAMERA AIM + TOOL ACTIVATION
--//==============================================================
local function equipTool(tool)
    if not tool or not Character or not Humanoid then
        return false
    end

    if tool.Parent ~= Character then
        pcall(function()
            Humanoid:EquipTool(tool)
        end)
    end

    return tool.Parent == Character
end

local function aimCameraAt(position)
    local camera = workspace.CurrentCamera

    if not camera or not position then
        return false
    end

    local cameraPosition = camera.CFrame.Position

    pcall(function()
        camera.CFrame = CFrame.lookAt(cameraPosition, position)
    end)

    return true
end

local function activateTool(tool)
    if not tool or not tool.Parent then
        return false
    end

    local ok = pcall(function()
        tool:Activate()
    end)

    return ok
end

--//==============================================================
--// SHERIFF LINE-OF-SIGHT HELPER
--//==============================================================
function _WT.hasClearLineOfSight(targetCharacter, targetPosition)
    if not targetCharacter or not targetPosition or not RootPart then
        return false
    end

    local camera = workspace.CurrentCamera
    local origin = (camera and camera.CFrame.Position) or RootPart.Position
    local direction = targetPosition - origin

    if direction.Magnitude <= 0 then
        return true
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        Character,
        targetCharacter,
    }
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, params)
    return result == nil
end

--//==============================================================
--// SHERIFF AUTO-SHOOT
--//==============================================================
_WT.LastSheriffShot = 0
_WT.SheriffCooldown = 0.25

local function sheriffAutoShoot()
    if not PREMIUM or not State.SheriffAutoShoot then
        return
    end

    if not isAlive() then
        return
    end

    local gun = findToolByNames({"gun", "sheriff", "revolver"})
    local murderer = _WT.findLikelyMurderer()

    if not gun or not murderer then
        return
    end

    local targetRoot = getAliveRoot(murderer)
    if not targetRoot then
        return
    end

    if os.clock() - _WT.LastSheriffShot < _WT.SheriffCooldown then
        return
    end

    local distance = (RootPart.Position - targetRoot.Position).Magnitude

    -- Only engage when the murderer is genuinely nearby.
    local SHERIFF_LOCK_RADIUS = 65
    if distance > SHERIFF_LOCK_RADIUS then
        return
    end

    -- Do not lock/shoot through map geometry.
    if not _WT.hasClearLineOfSight(murderer.Character, targetRoot.Position + Vector3.new(0, 1.2, 0)) then
        return
    end

    if equipTool(gun) then
        aimCameraAt(targetRoot.Position + Vector3.new(0, 1.2, 0))
        activateTool(gun)
        unlockBadge("7") -- Sheriff Ready
        unlockBadge("17") -- Precision
        _WT.LastSheriffShot = os.clock()
    end
end

--//==============================================================
--// MURDERER KILL-ALL ROUTINE
--//==============================================================
_WT.LastKnifeAttack = 0

local function murdererKillAll()
    if not PREMIUM or not State.MurdererKillAll then
        return
    end

    if not isAlive() then
        return
    end

    local knife = findToolByNames({"knife", "blade", "murderer"})

    if not knife then
        return
    end

    local target = _WT.nearestLivingPlayer()

    if not target then
        return
    end

    local targetRoot = getAliveRoot(target)

    if not targetRoot then
        return
    end

    local distance = (RootPart.Position - targetRoot.Position).Magnitude

    if distance > 14 then
        -- Safe-mode movement uses a bounded local movement step.
        if State.SafeMode and distance > 100 then
            return
        end

        local direction = (targetRoot.Position - RootPart.Position)

        if direction.Magnitude > 0 then
            local step = math.min(direction.Magnitude, 8)

            RootPart.CFrame =
                RootPart.CFrame
                + direction.Unit * step
        end
    else
        if os.clock() - _WT.LastKnifeAttack >= 0.18 then
            if equipTool(knife) then
                aimCameraAt(targetRoot.Position + Vector3.new(0, 1.0, 0))
                activateTool(knife)
                _WT.LastKnifeAttack = os.clock()
            end
        end
    end
end

--//==============================================================
--//==============================================================
--// COIN / THREAT-AWARE AUTOFARM
--// Rewritten around verification instead of assuming a teleport means
--// a collection. The script never counts a coin until the target changes,
--// disappears, or the player's observed currency increases.
--//==============================================================
local CoinObjects = {}
local CoinKnown = {}
_WT.LastCoinScan = 0
_WT.FarmBusy = false
local LastCollectedTarget = nil
_WT.LastCollectedPosition = nil
_WT.FARM_SCAN_INTERVAL = 0.45
_WT.FARM_VERIFY_TIMEOUT = 1.00
_WT.FARM_VERIFY_STEP = 0.08
_WT.FARM_TARGET_RETRIES = 2
_WT.FARM_FAIL_BLACKLIST_SECONDS = 1.75
_WT.FARM_MAX_BLACKLIST_SECONDS = 5.0
local DANGER_RADIUS = 65
local SAFE_COIN_RADIUS = 72
local CoinBlacklist = {}
local CoinFailureCount = {}

-- Pathfinding is used for the farm instead of setting the character's CFrame
-- directly on top of coins. This follows actual walkable map geometry and
-- automatically adapts when the current MM2 map changes.
_WT.FARM_AGENT_RADIUS = 2
_WT.FARM_AGENT_HEIGHT = 5
_WT.FARM_WAYPOINT_SPACING = 3.5
_WT.FARM_WAYPOINT_TIMEOUT = 4.5
_WT.FARM_REPATH_LIMIT = 3
_WT.FARM_CANDIDATE_LIMIT = 8
_WT.FARM_REPATH_DISTANCE = 5
_WT.FARM_GROUND_RAY_HEIGHT = 8
_WT.FARM_GROUND_RAY_DEPTH = 20

local function getCoinPart(object)
    if not object or not object.Parent then return nil end

    if object:IsA("BasePart") then
        local name = string.lower(object.Name)
        if name:find("coin", 1, true)
            or name:find("token", 1, true)
            or name:find("cash", 1, true)
            or name:find("collect", 1, true) then
            return object
        end
    end

    if object:IsA("Model") or object:IsA("Folder") then
        local directNames = {
            "Coin_Server", "Coin", "Token", "Cash", "Collect"
        }
        for _, name in ipairs(directNames) do
            local child = object:FindFirstChild(name)
            if child then
                if child:IsA("BasePart") then
                    return child
                end
                local handle = child:FindFirstChild("Handle", true)
                if handle and handle:IsA("BasePart") then
                    return handle
                end
            end
        end

        local handle = object:FindFirstChild("Handle", true)
        if handle and handle:IsA("BasePart") then
            local lower = string.lower(object.Name)
            if lower:find("coin", 1, true)
                or lower:find("token", 1, true)
                or lower:find("cash", 1, true)
                or lower:find("collect", 1, true) then
                return handle
            end
        end
    end

    return nil
end

local function coinIsAvailable(object)
    local part = getCoinPart(object)
    if not part or not part.Parent then return false end
    if part.Transparency >= 0.98 then return false end
    if part.Size.X <= 0 or part.Size.Y <= 0 or part.Size.Z <= 0 then return false end
    return true
end

scanCoins = function()
    table.clear(CoinObjects)
    table.clear(CoinKnown)
    local seen = {}

    for _, object in ipairs(workspace:GetDescendants()) do
        local part = getCoinPart(object)
        if part and coinIsAvailable(part) and not seen[part] then
            seen[part] = true
            CoinKnown[part] = true
            table.insert(CoinObjects, part)
        end
    end

    _WT.LastCoinScan = os.clock()
end


--//==============================================================
--// MM2 COIN ESP RENDERER
--// Visual-only markers; no movement, touch simulation, or collection.
--//==============================================================
local CoinESPObjects = {}
_WT.CoinESPScanClock = 0
_WT.CoinESPUpdateClock = 0

local function removeCoinMarker(part)
    local entry = CoinESPObjects[part]
    if not entry then return end
    pcall(function()
        if entry.Highlight then entry.Highlight:Destroy() end
        if entry.Billboard then entry.Billboard:Destroy() end
    end)
    CoinESPObjects[part] = nil
end

local function clearCoinMarkers()
    for part in pairs(CoinESPObjects) do
        removeCoinMarker(part)
    end
end

local function createCoinMarker(part)
    if not part or not part.Parent or CoinESPObjects[part] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "WindTurfCoinESP"
    highlight.Adornee = part
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(255, 205, 55)
    highlight.OutlineColor = Color3.fromRGB(255, 245, 170)
    highlight.FillTransparency = 0.68
    highlight.OutlineTransparency = 0.05
    highlight.Parent = MainGui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "WindTurfCoinDistance"
    billboard.Adornee = part
    billboard.Size = UDim2.fromOffset(110, 22)
    billboard.StudsOffset = Vector3.new(0, 1.2, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = State.CoinESPDistance
    billboard.Parent = MainGui

    local label = Instance.new("TextLabel")
    label.Name = "Distance"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(12, 10, 5)
    label.BackgroundTransparency = 0.2
    label.BorderSizePixel = 0
    label.Text = "COIN"
    label.TextColor3 = Color3.fromRGB(255, 225, 105)
    label.TextStrokeTransparency = 0.25
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = label

    CoinESPObjects[part] = {
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
    }
end

local function updateCoinESP()
    local enabled = State.CoinESP == true
    if CoinLabel then
        CoinLabel.Text = enabled and "COIN ESP ON" or "COIN ESP OFF"
    end

    if not enabled then
        clearCoinMarkers()
        if ENV.WindTurfCoinESPStatus then
            ENV.WindTurfCoinESPStatus.Text = "COINS FOUND: " .. tostring(#CoinObjects) .. " • ESP OFF"
        end
        return
    end

    local now = os.clock()
    if now - _WT.CoinESPScanClock >= 1.0 then
        scanCoins()
        _WT.CoinESPScanClock = now
    end
    if now - _WT.CoinESPUpdateClock < 0.15 then return end
    _WT.CoinESPUpdateClock = now

    local center = RootPart and RootPart.Parent and RootPart.Position or nil
    local maxDistance = math.max(0, tonumber(State.CoinESPMaxDistance) or 0)
    local shown = 0
    local live = {}

    for _, part in ipairs(CoinObjects) do
        if part and part.Parent and coinIsAvailable(part) then
            local distance = center and (part.Position - center).Magnitude or 0
            local inRange = maxDistance <= 0 or not center or distance <= maxDistance
            if inRange then
                live[part] = true
                shown += 1
                local entry = CoinESPObjects[part]
                if not entry then
                    createCoinMarker(part)
                    entry = CoinESPObjects[part]
                end
                if entry then
                    entry.Billboard.Enabled = State.CoinESPDistance == true
                    if center then
                        entry.Label.Text = string.format("COIN • %.0f studs", distance)
                    else
                        entry.Label.Text = "COIN"
                    end
                end
            end
        end
    end

    for part in pairs(CoinESPObjects) do
        if not live[part] then
            removeCoinMarker(part)
        end
    end

    if ENV.WindTurfCoinESPStatus then
        ENV.WindTurfCoinESPStatus.Text = string.format("COINS FOUND: %d • SHOWING: %d", #CoinObjects, shown)
    end
end

connect("CoinESPUpdate", RunService.Heartbeat, updateCoinESP)

connect("CoinDescendantAdded", workspace.DescendantAdded, function(object)
    local part = getCoinPart(object)
    if part and coinIsAvailable(part) and not CoinKnown[part] then
        CoinKnown[part] = true
        table.insert(CoinObjects, part)
    end
end)

connect("CoinDescendantRemoving", workspace.DescendantRemoving, function(object)
    CoinBlacklist[object] = nil
    CoinFailureCount[object] = nil
    CoinKnown[object] = nil
    for i = #CoinObjects, 1, -1 do
        if CoinObjects[i] == object then
            table.remove(CoinObjects, i)
            break
        end
    end
end)

local function getDangerousPlayers()
    local result = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local root = getAliveRoot(player)
            if root then
                local role = getPlayerRole(player)
                if role == "Murderer" or role == "Sheriff" or role == "Hero" then
                    table.insert(result, {
                        Player = player,
                        Root = root,
                        Role = role,
                        Distance = RootPart and (RootPart.Position - root.Position).Magnitude or math.huge,
                    })
                end
            end
        end
    end
    return result
end

function _WT.nearestDangerDistance()
    local closest = math.huge
    for _, danger in ipairs(getDangerousPlayers()) do
        closest = math.min(closest, danger.Distance)
    end
    return closest
end

function _WT.dangerousPlayerNearby(radius)
    if not RootPart then return false end
    radius = radius or DANGER_RADIUS
    return _WT.nearestDangerDistance() <= radius
end

function _WT.coinThreatDistance(object, dangers)
    local closest = math.huge
    local position = getCoinPart(object) and getCoinPart(object).Position
    if not position then return closest end
    for _, danger in ipairs(dangers) do
        if danger.Root and danger.Root.Parent then
            closest = math.min(closest, (danger.Root.Position - position).Magnitude)
        end
    end
    return closest
end

function _WT.coinIsBlacklisted(object)
    local untilTime = CoinBlacklist[object]
    if not untilTime then return false end
    if os.clock() >= untilTime then
        CoinBlacklist[object] = nil
        return false
    end
    return true
end

function _WT.blacklistCoin(object)
    if not object then return end
    local failures = (CoinFailureCount[object] or 0) + 1
    CoinFailureCount[object] = failures
    local duration = math.min(_WT.FARM_FAIL_BLACKLIST_SECONDS * failures, _WT.FARM_MAX_BLACKLIST_SECONDS)
    CoinBlacklist[object] = os.clock() + duration
end

function _WT.clearCoinFailure(object)
    if object then
        CoinBlacklist[object] = nil
        CoinFailureCount[object] = nil
    end
end

function _WT.getFarmTargetPosition(object)
    if not object or not object.Parent then return nil end
    local position = object.Position

    -- Coins can be slightly above/below the walkable floor. Project the target
    -- down to nearby ground so PathfindingService plans to a walkable point.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = Character and {Character} or {}
    params.IgnoreWater = false

    local hit = workspace:Raycast(
        position + Vector3.new(0, 10, 0),
        Vector3.new(0, -30, 0),
        params
    )

    if hit then
        return hit.Position + Vector3.new(0, 1.8, 0)
    end

    return position
end

function _WT.createFarmPath(startPosition, targetPosition)
    local path = PathfindingService:CreatePath({
        AgentRadius = _WT.FARM_AGENT_RADIUS,
        AgentHeight = _WT.FARM_AGENT_HEIGHT,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = _WT.FARM_WAYPOINT_SPACING,
    })

    local ok = pcall(function()
        path:ComputeAsync(startPosition, targetPosition)
    end)

    if not ok or path.Status ~= Enum.PathStatus.Success then
        return nil
    end

    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        return nil
    end

    if RootPart and not _WT.pathStillReasonable(waypoints, RootPart.Position) then
        return nil
    end

    return path, waypoints
end

function _WT.pathIsSafe(waypoints, dangers)
    for _, waypoint in ipairs(waypoints) do
        for _, danger in ipairs(dangers) do
            if danger.Root and danger.Root.Parent then
                if (danger.Root.Position - waypoint.Position).Magnitude < SAFE_COIN_RADIUS then
                    return false
                end
            end
        end
    end
    return true
end

function _WT.pathLength(waypoints, startPosition)
    local total = 0
    local previous = startPosition
    for _, waypoint in ipairs(waypoints) do
        total += (waypoint.Position - previous).Magnitude
        previous = waypoint.Position
    end
    return total
end


--//==============================================================
--// LIVE PATH MAP / TOP-DOWN DIAGRAM
--//==============================================================
-- This is a client-side visualization of the actual PathfindingService
-- waypoints selected by the farm. Green = current safe route, yellow =
-- coins, red = murderer danger area, blue = nearby map obstacles.
-- It does not move the character by itself.
local PATH_MAP_WORLD_RADIUS = 95
_WT.PATH_MAP_UPDATE_INTERVAL = 0.18
_WT.LastPathMapUpdate = 0

local function pathMapClear()
    if not PathMapCanvas then return end
    for _, child in ipairs(PathMapCanvas:GetChildren()) do
        if not child:GetAttribute("PathMapStatic") then
            pcall(function() child:Destroy() end)
        end
    end
end

local function pathMapLine(parent, a, b, color, thickness, zIndex)
    local delta = b - a
    local length = delta.Magnitude
    if length < 1 then return end

    local line = Instance.new("Frame")
    line.BorderSizePixel = 0
    line.BackgroundColor3 = color
    line.BackgroundTransparency = 0.08
    line.AnchorPoint = Vector2.new(0, 0.5)
    line.Position = UDim2.fromOffset(a.X, a.Y)
    line.Size = UDim2.fromOffset(length, thickness or 2)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    line.ZIndex = zIndex or 5
    line.Parent = parent
end

local function pathMapDot(parent, point, diameter, color, strokeColor, zIndex)
    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.fromOffset(point.X, point.Y)
    dot.Size = UDim2.fromOffset(diameter, diameter)
    dot.BackgroundColor3 = color
    dot.BorderSizePixel = 0
    dot.ZIndex = zIndex or 10
    dot.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot

    if strokeColor then
        local stroke = Instance.new("UIStroke")
        stroke.Color = strokeColor
        stroke.Thickness = 1
        stroke.Transparency = 0.15
        stroke.Parent = dot
    end

    return dot
end

local function pathMapWorldToScreen(position, center, width, height)
    local dx = position.X - center.X
    local dz = position.Z - center.Z

    local sx = width * 0.5 + (dx / PATH_MAP_WORLD_RADIUS) * (width * 0.5)
    local sy = height * 0.5 + (dz / PATH_MAP_WORLD_RADIUS) * (height * 0.5)

    return Vector2.new(sx, sy)
end

function _WT.pathMapAddObstacle(parent, part, center, width, height)
    if not State.PathDiagramObstacles then return end
    if not part:IsA("BasePart") or not part.Parent then return end
    if not part.Anchored or not part.CanCollide then return end
    if Character and part:IsDescendantOf(Character) then return end
    if part.Transparency >= 0.92 then return end

    local size = part.Size
    local maxHorizontal = math.max(size.X, size.Z)
    local minHorizontal = math.min(size.X, size.Z)

    -- Skip floors, huge map shells and tiny decorative pieces.
    if size.Y > 18 then return end
    if maxHorizontal > 90 then return end
    if minHorizontal < 0.35 then return end

    local p = pathMapWorldToScreen(part.Position, center, width, height)
    local sx = math.max(2, (size.X / PATH_MAP_WORLD_RADIUS) * (width * 0.5))
    local sy = math.max(2, (size.Z / PATH_MAP_WORLD_RADIUS) * (height * 0.5))

    if p.X + sx * 0.5 < 0 or p.X - sx * 0.5 > width
        or p.Y + sy * 0.5 < 0 or p.Y - sy * 0.5 > height then
        return
    end

    local obstacle = Instance.new("Frame")
    obstacle.AnchorPoint = Vector2.new(0.5, 0.5)
    obstacle.Position = UDim2.fromOffset(p.X, p.Y)
    obstacle.Size = UDim2.fromOffset(math.min(sx, width), math.min(sy, height))
    obstacle.BackgroundColor3 = Color3.fromRGB(115, 125, 150)
    obstacle.BackgroundTransparency = 0.28
    obstacle.BorderSizePixel = 0
    obstacle.ZIndex = 2
    obstacle.Parent = parent
end

local function refreshPathMap(force)
    if not PathMapCanvas or not PathMapCanvas.Parent then return end
    if not State.PathDiagram then
        PathMapCanvas.Visible = false
        if PathMapStatus then
            PathMapStatus.Text = "MAP OFF"
        end
        return
    end

    PathMapCanvas.Visible = true

    if not force and os.clock() - _WT.LastPathMapUpdate < _WT.PATH_MAP_UPDATE_INTERVAL then
        return
    end
    _WT.LastPathMapUpdate = os.clock()

    pathMapClear()

    if not RootPart or not RootPart.Parent then
        if PathMapStatus then PathMapStatus.Text = "WAITING FOR CHARACTER" end
        return
    end

    local width = PathMapCanvas.AbsoluteSize.X
    local height = PathMapCanvas.AbsoluteSize.Y

    if width < 10 or height < 10 then
        return
    end

    local center = RootPart.Position

    -- Subtle grid for the diagram.
    for i = 1, 5 do
        local x = width * (i / 6)
        local y = height * (i / 6)

        local v = Instance.new("Frame")
        v.BorderSizePixel = 0
        v.BackgroundColor3 = Color3.fromRGB(45, 58, 95)
        v.BackgroundTransparency = 0.75
        v.Size = UDim2.fromOffset(1, height)
        v.Position = UDim2.fromOffset(x, 0)
        v.ZIndex = 1
        v.Parent = PathMapCanvas

        local h = Instance.new("Frame")
        h.BorderSizePixel = 0
        h.BackgroundColor3 = Color3.fromRGB(45, 58, 95)
        h.BackgroundTransparency = 0.75
        h.Size = UDim2.fromOffset(width, 1)
        h.Position = UDim2.fromOffset(0, y)
        h.ZIndex = 1
        h.Parent = PathMapCanvas
    end

    -- Nearby physical obstacles, top-down approximation.
    if State.PathDiagramObstacles then
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = Character and {Character} or {}

        local parts = {}
        local ok = pcall(function()
            parts = workspace:GetPartBoundsInBox(
                CFrame.new(center),
                Vector3.new(PATH_MAP_WORLD_RADIUS * 2, 60, PATH_MAP_WORLD_RADIUS * 2),
                overlap
            )
        end)

        if ok then
            local drawn = 0
            for _, part in ipairs(parts) do
                _WT.pathMapAddObstacle(
                    PathMapCanvas,
                    part,
                    center,
                    width,
                    height
                )
                drawn += 1
                if drawn >= 65 then
                    break
                end
            end
        end
    end

    -- Coin markers.
    if State.PathDiagramCoins then
        local coinDrawn = 0
        for _, coin in ipairs(CoinObjects) do
            if coinIsAvailable(coin) then
                local distance = (coin.Position - center).Magnitude
                if distance <= PATH_MAP_WORLD_RADIUS then
                    local p = pathMapWorldToScreen(
                        coin.Position,
                        center,
                        width,
                        height
                    )
                    pathMapDot(
                        PathMapCanvas,
                        p,
                        7,
                        Color3.fromRGB(255, 205, 55),
                        Color3.fromRGB(255, 240, 140),
                        7
                    )
                    coinDrawn += 1
                    if coinDrawn >= 30 then
                        break
                    end
                end
            end
        end
    end

    -- Murderer danger zones and line-of-sight direction.
    local murdererCount = 0
    if State.PathDiagramDanger then
        for _, danger in ipairs(getDangerousPlayers()) do
            if danger.Role == "Murderer"
                and danger.Root
                and danger.Root.Parent
                and (danger.Root.Position - center).Magnitude <= PATH_MAP_WORLD_RADIUS then

                local dangerPoint = pathMapWorldToScreen(
                    danger.Root.Position,
                    center,
                    width,
                    height
                )

                local dangerRadiusPx =
                    (DANGER_RADIUS / PATH_MAP_WORLD_RADIUS) * (width * 0.5)

                local ring = Instance.new("Frame")
                ring.AnchorPoint = Vector2.new(0.5, 0.5)
                ring.Position = UDim2.fromOffset(dangerPoint.X, dangerPoint.Y)
                ring.Size = UDim2.fromOffset(
                    dangerRadiusPx * 2,
                    dangerRadiusPx * 2
                )
                ring.BackgroundColor3 = Color3.fromRGB(255, 55, 70)
                ring.BackgroundTransparency = 0.88
                ring.BorderSizePixel = 0
                ring.ZIndex = 3
                ring.Parent = PathMapCanvas

                local ringCorner = Instance.new("UICorner")
                ringCorner.CornerRadius = UDim.new(1, 0)
                ringCorner.Parent = ring

                local ringStroke = Instance.new("UIStroke")
                ringStroke.Color = Color3.fromRGB(255, 65, 80)
                ringStroke.Thickness = 1
                ringStroke.Transparency = 0.25
                ringStroke.Parent = ring

                local playerPoint = pathMapWorldToScreen(
                    center,
                    center,
                    width,
                    height
                )

                pathMapLine(
                    PathMapCanvas,
                    playerPoint,
                    dangerPoint,
                    Color3.fromRGB(255, 75, 90),
                    2,
                    6
                )

                pathMapDot(
                    PathMapCanvas,
                    dangerPoint,
                    12,
                    Color3.fromRGB(255, 55, 70),
                    Color3.fromRGB(255, 210, 215),
                    11
                )

                local x = Instance.new("TextLabel")
                x.AnchorPoint = Vector2.new(0.5, 0.5)
                x.Position = UDim2.fromOffset(dangerPoint.X, dangerPoint.Y)
                x.Size = UDim2.fromOffset(22, 22)
                x.BackgroundTransparency = 1
                x.Text = "×"
                x.TextColor3 = Color3.fromRGB(255, 255, 255)
                x.Font = Enum.Font.GothamBold
                x.TextSize = 15
                x.ZIndex = 12
                x.Parent = PathMapCanvas

                murdererCount += 1
            end
        end
    end

    -- All nearby players. These are visualization-only live position markers;
    -- they do not target, move, or attack players.
    if State.PathDiagramPlayers then
        local playerDrawn = 0
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local otherRoot = getAliveRoot(player)
                if otherRoot and otherRoot.Parent then
                    local distance = (otherRoot.Position - center).Magnitude
                    if distance <= PATH_MAP_WORLD_RADIUS then
                        local otherPoint = pathMapWorldToScreen(
                            otherRoot.Position, center, width, height
                        )
                        local role = getPlayerRole(player)
                        local markerColor = Color3.fromRGB(95, 175, 255)
                        if role == "Murderer" then
                            markerColor = Color3.fromRGB(255, 70, 80)
                        elseif role == "Sheriff" then
                            markerColor = Color3.fromRGB(75, 185, 255)
                        elseif role == "Hero" then
                            markerColor = Color3.fromRGB(245, 205, 70)
                        end

                        pathMapDot(
                            PathMapCanvas, otherPoint, 9, markerColor,
                            Color3.fromRGB(235, 245, 255), 13
                        )

                        local label = Instance.new("TextLabel")
                        label.AnchorPoint = Vector2.new(0.5, 0)
                        label.Position = UDim2.fromOffset(otherPoint.X, otherPoint.Y + 6)
                        label.Size = UDim2.fromOffset(90, 13)
                        label.BackgroundTransparency = 1
                        label.Text = string.sub(player.Name, 1, 12)
                        label.TextColor3 = Color3.fromRGB(225, 235, 250)
                        label.Font = Enum.Font.GothamBold
                        label.TextSize = 6
                        label.TextXAlignment = Enum.TextXAlignment.Center
                        label.ZIndex = 14
                        label.Parent = PathMapCanvas

                        playerDrawn += 1
                        if playerDrawn >= 30 then
                            break
                        end
                    end
                end
            end
        end
    end

    -- Current player/start marker.
    local playerPoint = pathMapWorldToScreen(
        center,
        center,
        width,
        height
    )
    pathMapDot(
        PathMapCanvas,
        playerPoint,
        13,
        Color3.fromRGB(70, 230, 125),
        Color3.fromRGB(220, 255, 230),
        15
    )

    -- Current actual PathfindingService route.
    local waypoints = LivePathWaypoints
    if waypoints and #waypoints >= 2 then
        local previous = nil

        for _, waypoint in ipairs(waypoints) do
            if waypoint and waypoint.Position then
                local p = pathMapWorldToScreen(
                    waypoint.Position,
                    center,
                    width,
                    height
                )

                if previous then
                    pathMapLine(
                        PathMapCanvas,
                        previous,
                        p,
                        Color3.fromRGB(60, 235, 120),
                        3,
                        9
                    )
                end

                pathMapDot(
                    PathMapCanvas,
                    p,
                    6,
                    Color3.fromRGB(70, 235, 140),
                    Color3.fromRGB(210, 255, 225),
                    10
                )

                previous = p
            end
        end
    end

    -- Current target coin.
    if LivePathTarget
        and LivePathTarget.Parent
        and coinIsAvailable(LivePathTarget) then

        local targetPoint = pathMapWorldToScreen(
            LivePathTarget.Position,
            center,
            width,
            height
        )

        pathMapDot(
            PathMapCanvas,
            targetPoint,
            11,
            Color3.fromRGB(255, 190, 45),
            Color3.fromRGB(255, 250, 175),
            14
        )

        local targetText = Instance.new("TextLabel")
        targetText.AnchorPoint = Vector2.new(0.5, 1)
        targetText.Position = UDim2.fromOffset(targetPoint.X, targetPoint.Y - 8)
        targetText.Size = UDim2.fromOffset(90, 16)
        targetText.BackgroundTransparency = 1
        targetText.Text = "TARGET"
        targetText.TextColor3 = Color3.fromRGB(255, 225, 100)
        targetText.Font = Enum.Font.GothamBold
        targetText.TextSize = 7
        targetText.ZIndex = 16
        targetText.Parent = PathMapCanvas
    end

    if PathMapStatus then
        local routeState = (waypoints and #waypoints >= 2)
            and "GREEN = CURRENT SAFE PATH"
            or "WAITING FOR SAFE PATH"

        if murdererCount > 0 then
            routeState = routeState .. " • RED = MURDERER"
        end

        PathMapStatus.Text = routeState
    end

    if PathMapTarget then
        if LivePathTarget and LivePathTarget.Parent then
            PathMapTarget.Text = "Target: " .. tostring(LivePathTarget.Name)
        else
            PathMapTarget.Text = "Target: none"
        end
    end
end


function _WT.isGroundedNear(position)
    local origin = position + Vector3.new(0, _WT.FARM_GROUND_RAY_HEIGHT, 0)
    local direction = Vector3.new(0, -_WT.FARM_GROUND_RAY_DEPTH, 0)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    params.IgnoreWater = false

    return workspace:Raycast(origin, direction, params) ~= nil
end

function _WT.pathStillReasonable(waypoints, currentPosition)
    if not waypoints or #waypoints == 0 then
        return false
    end

    local first = waypoints[1]
    if first and (first.Position - currentPosition).Magnitude > 28 then
        return false
    end

    return true
end

function _WT.findBestPathCoin()
    if not RootPart or _WT.LastRole ~= "Innocent" then return nil, nil end

    local dangers = getDangerousPlayers()
    local nearbyThreat = false
    for _, danger in ipairs(dangers) do
        if danger.Distance <= DANGER_RADIUS then
            nearbyThreat = true
            break
        end
    end

    local candidates = {}
    local currentPosition = RootPart.Position

    for _, object in ipairs(CoinObjects) do
        if coinIsAvailable(object) and object ~= LastCollectedTarget and not _WT.coinIsBlacklisted(object) then
            local distance = (currentPosition - object.Position).Magnitude
            if distance <= CONFIG.CoinSearchRadius then
                local threatDistance = _WT.coinThreatDistance(object, dangers)
                if threatDistance >= SAFE_COIN_RADIUS then
                    table.insert(candidates, {
                        Object = object,
                        Distance = distance,
                        ThreatDistance = threatDistance,
                    })
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if nearbyThreat then
            return a.ThreatDistance > b.ThreatDistance
        end
        return a.Distance < b.Distance
    end)

    local bestObject, bestPath, bestScore = nil, nil, math.huge
    local checked = math.min(#candidates, _WT.FARM_CANDIDATE_LIMIT)

    for index = 1, checked do
        local candidate = candidates[index]
        local targetPosition = _WT.getFarmTargetPosition(candidate.Object)
        local path, waypoints
        if targetPosition then
            path, waypoints = _WT.createFarmPath(currentPosition, targetPosition)
        end
        if path and waypoints and _WT.pathIsSafe(waypoints, dangers) then
            local length = _WT.pathLength(waypoints, currentPosition)
            local threatBonus = math.max(0, SAFE_COIN_RADIUS - candidate.ThreatDistance)
            local score = length + threatBonus * 3

            if score < bestScore then
                bestScore = score
                bestObject = candidate.Object
                bestPath = path
            end
        end
    end

    if bestObject and bestPath then
        LivePathTarget = bestObject
        LivePathWaypoints = bestPath:GetWaypoints()
        LivePathTimestamp = os.clock()
    elseif not bestObject and nearbyThreat then
        LivePathWaypoints = nil
        LivePathTarget = nil
        if FarmDebugStatus then FarmDebugStatus.Text = "● ACTIVE" end
        if FarmDebugPhase then FarmDebugPhase.Text = "Status: AVOIDING THREAT" end
    end

    return bestObject, bestPath
end

function _WT.updateCoinLabel()
    if CoinLabel then
        CoinLabel.Text = State.CoinESP and "COIN ESP ON" or "COIN ESP OFF"
    end
end

function _WT.readCurrencyValue()
    local values = {
        LocalPlayer:FindFirstChild("Coins"),
        LocalPlayer:FindFirstChild("CoinCount"),
        LocalPlayer:FindFirstChild("Currency"),
        LocalPlayer:FindFirstChild("Cash"),
    }

    for _, value in ipairs(values) do
        if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
            local number = tonumber(value.Value)
            if number and number >= 0 then
                return number
            end
        end
    end

    return nil
end

function _WT.beginRoundCounter()
    RoundCurrencyBaseline = _WT.readCurrencyValue()
    RoundStarted = true
    LobbyTeleportStarted = false
    State.CoinCount = 0
    _WT.updateCoinLabel()
end

function _WT.observedRoundCoinCount()
    local current = _WT.readCurrencyValue()
    if current == nil then
        return nil
    end

    if RoundCurrencyBaseline == nil then
        RoundCurrencyBaseline = current
        return 0
    end

    return math.max(0, math.floor(current - RoundCurrencyBaseline + 0.0001))
end

function _WT.coinWasCollected(object, originalParent, originalTransparency)
    if not object then return true end
    if not object.Parent then return true end
    if object.Parent ~= originalParent then return true end
    if object.Transparency >= 0.98 then return true end
    if originalTransparency < 0.98 and object.Transparency - originalTransparency >= 0.45 then
        return true
    end
    return false
end

function _WT.verifyCoinCollected(object, beforeObserved, originalParent, originalTransparency)
    if not object then return false end
    local deadline = os.clock() + _WT.FARM_VERIFY_TIMEOUT

    while os.clock() < deadline do
        local observed = _WT.observedRoundCoinCount()
        if observed ~= nil and beforeObserved ~= nil and observed > beforeObserved then
            return true
        end

        if _WT.coinWasCollected(object, originalParent, originalTransparency) then
            return true
        end

        task.wait(_WT.FARM_VERIFY_STEP)
    end

    return false
end

function _WT.followFarmPath(path, target)
    if not path or not target or not Humanoid or not RootPart then return false end

    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then return false end

    local repaths = 0
    local index = 1
    local lastProgress = os.clock()
    local lastDistance = math.huge
    local lastMoveRefresh = 0

    while index <= #waypoints do
        if not isAlive() or _WT.LastRole ~= "Innocent" or not coinIsAvailable(target) then
            return false
        end

        local dangers = getDangerousPlayers()
        for _, danger in ipairs(dangers) do
            if danger.Root and danger.Root.Parent
                and (danger.Root.Position - RootPart.Position).Magnitude < DANGER_RADIUS then
                Humanoid:Move(Vector3.zero)
                return false
            end
        end

        if not _WT.isGroundedNear(RootPart.Position) then
            task.wait(0.08)
        end

        local waypoint = waypoints[index]
        if not waypoint or not waypoint.Position then
            repaths += 1
            if repaths > _WT.FARM_REPATH_LIMIT then return false end
            local targetPosition = _WT.getFarmTargetPosition(target) or target.Position
            local newPath, newWaypoints = _WT.createFarmPath(RootPart.Position, targetPosition)
            if not newPath or not newWaypoints or not _WT.pathIsSafe(newWaypoints, dangers) then
                return false
            end
            path, waypoints, index = newPath, newWaypoints, 1
            LivePathWaypoints, LivePathTarget, LivePathTimestamp = newWaypoints, target, os.clock()
            continue
        end

        local distanceToWaypoint = (RootPart.Position - waypoint.Position).Magnitude
        if distanceToWaypoint <= 3 then
            index += 1
            lastProgress = os.clock()
            lastDistance = math.huge
            continue
        end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            Humanoid.Jump = true
        end

        if FarmDebugPhase then
            FarmDebugPhase.Text = "Status: WALKING WAYPOINT " .. tostring(index) .. "/" .. tostring(#waypoints)
        end

        -- MoveTo is refreshed periodically instead of resetting the waypoint index.
        -- The previous v4 code replanned every 0.7s and reset index to 1, which could
        -- keep the character oscillating around the first waypoint forever.
        Humanoid:MoveTo(waypoint.Position)
        lastMoveRefresh = os.clock()

        local deadline = os.clock() + math.max(6.5, _WT.FARM_WAYPOINT_TIMEOUT)
        local finished = false
        local reached = false
        local connection
        connection = Humanoid.MoveToFinished:Connect(function(success)
            reached = success
            finished = true
        end)

        while not finished and os.clock() < deadline do
            if not isAlive() or _WT.LastRole ~= "Innocent" then
                break
            end

            for _, danger in ipairs(getDangerousPlayers()) do
                if danger.Root and danger.Root.Parent
                    and (danger.Root.Position - RootPart.Position).Magnitude < DANGER_RADIUS then
                    Humanoid:Move(Vector3.zero)
                    finished, reached = true, false
                    break
                end
            end
            if finished then break end

            local currentDistance = (RootPart.Position - waypoint.Position).Magnitude
            if currentDistance <= 3 then
                reached, finished = true, true
                break
            end

            if currentDistance + 0.25 < lastDistance then
                lastDistance = currentDistance
                lastProgress = os.clock()
            elseif os.clock() - lastProgress > 1.8 then
                -- Stalled: stop waiting and replan from the actual position.
                finished, reached = true, false
                break
            end

            -- Roblox documents that MoveTo times out after 8 seconds; refreshing
            -- before that keeps a legitimate walking request alive.
            if os.clock() - lastMoveRefresh >= 5.5 then
                Humanoid:MoveTo(waypoint.Position)
                lastMoveRefresh = os.clock()
            end

            task.wait(0.08)
        end

        if connection then connection:Disconnect() end

        if reached then
            index += 1
            continue
        end

        Humanoid:Move(Vector3.zero)
        repaths += 1
        if repaths > _WT.FARM_REPATH_LIMIT then
            return false
        end

        local targetPosition = _WT.getFarmTargetPosition(target) or target.Position
        local newPath, newWaypoints = _WT.createFarmPath(RootPart.Position, targetPosition)
        if not newPath or not newWaypoints then
            return false
        end
        if not _WT.pathIsSafe(newWaypoints, getDangerousPlayers()) then
            return false
        end

        path, waypoints, index = newPath, newWaypoints, 1
        LivePathWaypoints, LivePathTarget, LivePathTimestamp = newWaypoints, target, os.clock()
    end

    Humanoid:Move(Vector3.zero)
    unlockBadge("4")
    unlockBadge("5")
    unlockBadge("11")
    return true
end

function _WT.farmOneCoin(target, precomputedPath)
    if not target or not coinIsAvailable(target) or _WT.LastRole ~= "Innocent" then return false end

    local beforeObserved = _WT.observedRoundCoinCount()
    local originalParent = target.Parent
    local originalTransparency = target.Transparency

    if FarmDebugStatus then FarmDebugStatus.Text = "● ACTIVE" end
    if FarmDebugPhase then FarmDebugPhase.Text = "Status: CALCULATING SAFE PATH" end

    for attempt = 1, _WT.FARM_TARGET_RETRIES do
        if _WT.LastRole ~= "Innocent" or not isAlive() then
            return false
        end

        if not coinIsAvailable(target) then
            _WT.clearCoinFailure(target)
            return true
        end

        if _WT.coinIsBlacklisted(target) then
            return false
        end

        local dangers = getDangerousPlayers()
        if _WT.coinThreatDistance(target, dangers) < SAFE_COIN_RADIUS then
            if FarmDebugPhase then FarmDebugPhase.Text = "Status: AVOIDING THREAT" end
            return false
        end

        local path = precomputedPath
        local waypoints
        if not path then
            local targetPosition = _WT.getFarmTargetPosition(target) or target.Position
            path, waypoints = _WT.createFarmPath(RootPart.Position, targetPosition)
        else
            waypoints = path:GetWaypoints()
        end

        if path and waypoints and _WT.pathIsSafe(waypoints, dangers) then
            if _WT.followFarmPath(path, target) then
                if FarmDebugPhase then FarmDebugPhase.Text = "Status: COLLECTING" end
                if _WT.verifyCoinCollected(target, beforeObserved, originalParent, originalTransparency) then
                    _WT.clearCoinFailure(target)
                    LivePathWaypoints = nil
                    LivePathTarget = nil
                    LivePathTimestamp = os.clock()
                    return true
                end
            end
        end

        precomputedPath = nil
        if attempt < _WT.FARM_TARGET_RETRIES then
            if FarmDebugPhase then FarmDebugPhase.Text = "Status: REPLANNING" end
            task.wait(0.12)
        end
    end

    _WT.blacklistCoin(target)
    LivePathWaypoints = nil
    LivePathTarget = nil
    LivePathTimestamp = os.clock()
    if FarmDebugStatus then FarmDebugStatus.Text = "● ACTIVE" end
    if FarmDebugPhase then FarmDebugPhase.Text = "Status: COIN FAILED" end
    return false
end

--//==============================================================
--// DROPPED GUN / SHERIFF / HERO SUPPORT
--//==============================================================
_WT.LastGunTeleport = 0
_WT.GunTeleportCooldown = 0.35
_WT.LastGunShot = 0
_WT.GunShotCooldown = 0.35

function _WT.isGunName(name)
    name = string.lower(tostring(name or ""))
    return name:find("gun", 1, true)
        or name:find("sheriff", 1, true)
        or name:find("revolver", 1, true)
end

function _WT.findDroppedGun()
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Tool") and _WT.isGunName(object.Name) then
            local handle = object:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") and object.Parent ~= LocalPlayer.Character then
                return object, handle
            end
        end
    end
    return nil, nil
end

function _WT.gunIsSafe(handle)
    if not handle or not handle.Parent then return false end
    for _, danger in ipairs(getDangerousPlayers()) do
        if danger.Root and (danger.Root.Position - handle.Position).Magnitude < DANGER_RADIUS then
            return false
        end
    end
    return true
end

function _WT.autoTeleportToDroppedGun()
    if not State.AutoGunPickup or not isAlive() or not RootPart then return end
    if State.CoinCount >= State.CoinGoal then return end
    if _WT.LastRole ~= "Innocent" and _WT.LastRole ~= "Sheriff" and _WT.LastRole ~= "Hero" then return end
    if os.clock() - _WT.LastGunTeleport < _WT.GunTeleportCooldown then return end

    local gun, handle = _WT.findDroppedGun()
    if not gun or not handle or not _WT.gunIsSafe(handle) then return end

    local before = gun.Parent
    local ok = pcall(function()
        RootPart.CFrame = CFrame.new(handle.Position + Vector3.new(0, 1.5, 0))
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero
    end)

    if ok then
        _WT.LastGunTeleport = os.clock()
        task.spawn(function()
            task.wait(0.12)
            -- Do not repeatedly teleport to the same rejected pickup.
            if gun.Parent == before and gun.Parent and isAlive() then
                return
            end
        end)
    end
end

function _WT.autoShootMurdererWithGun()
    if not State.AutoGunShoot or not isAlive() then return end
    if _WT.LastRole ~= "Sheriff" and _WT.LastRole ~= "Hero" then return end
    if os.clock() - _WT.LastGunShot < _WT.GunShotCooldown then return end

    local gun = findToolByNames({"gun", "sheriff", "revolver"})
    if not gun then return end
    local murderer = _WT.findLikelyMurderer()
    if not murderer then return end
    local targetRoot = getAliveRoot(murderer)
    if not targetRoot then return end

    local distance = (RootPart.Position - targetRoot.Position).Magnitude
    if State.SafeMode and distance > 250 then return end

    if equipTool(gun) then
        aimCameraAt(targetRoot.Position + Vector3.new(0, 1.15, 0))
        activateTool(gun)
        _WT.LastGunShot = os.clock()
    end
end

--//==============================================================
--// CHAT MONITOR
--//==============================================================
local ChatHistory = {}

local function hookChat(player)
    if player == LocalPlayer then
        return
    end

    connect(
        "Chat_" .. tostring(player.UserId),
        player.Chatted,
        function(message)
            if not State.ChatMonitor then
                return
            end

            local cleaned = string.lower(tostring(message))
                :gsub("%s+", " ")
                :sub(1, 160)

            local previous = ChatHistory[player.UserId]

            if previous
                and previous.Message == cleaned
                and os.clock() - previous.Time <= 6 then

                previous.Count += 1
                previous.Time = os.clock()
            else
                ChatHistory[player.UserId] = {
                    Message = cleaned,
                    Count = 1,
                    Time = os.clock()
                }

                previous = ChatHistory[player.UserId]
            end

            if previous.Count >= 3 then
                flagPlayer(player, "same chat message 3×")
                previous.Count = 0
            end
        end
    )
end

for _, player in ipairs(Players:GetPlayers()) do
    hookChat(player)
end

connect("PlayerAdded", Players.PlayerAdded, function(player)
    hookChat(player)
end)

connect("PlayerRemoving", Players.PlayerRemoving, function(player)
    ChatHistory[player.UserId] = nil
    SuspiciousPlayers[player] = nil

    if CurrentSuspiciousTarget == player then
        CurrentSuspiciousTarget = nil
    end
end)

--//==============================================================
--// LIVE PATH MAP PAGE
--//==============================================================
do
    local page = Pages.Map

    section(page, "LIVE PATH MAP")

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -5, 0, 32)
    info.BackgroundTransparency = 1
    info.Text = "Live top-down map. Green = route • Red = murderer • Yellow = coins • Blue/Gold = players."
    info.TextColor3 = Color3.fromRGB(150, 165, 195)
    info.Font = Enum.Font.Gotham
    info.TextSize = 8
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = page

    PathMapCanvas = Instance.new("Frame")
    PathMapCanvas.Name = "LivePathMap"
    PathMapCanvas.Size = UDim2.new(1, -5, 0, 188)
    PathMapCanvas.BackgroundColor3 = Color3.fromRGB(5, 9, 22)
    PathMapCanvas.BorderSizePixel = 0
    PathMapCanvas.ClipsDescendants = true
    PathMapCanvas.Parent = page

    local mapCorner = Instance.new("UICorner")
    mapCorner.CornerRadius = UDim.new(0, 12)
    mapCorner:SetAttribute("PathMapStatic", true)
    mapCorner.Parent = PathMapCanvas

    local mapStroke = Instance.new("UIStroke")
    mapStroke.Color = Color3.fromRGB(50, 75, 125)
    mapStroke.Transparency = 0.25
    mapStroke:SetAttribute("PathMapStatic", true)
    mapStroke.Parent = PathMapCanvas

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 18)
    title.Position = UDim2.fromOffset(7, 5)
    title.BackgroundTransparency = 1
    title.Text = "PATHFINDING • LIVE"
    title.TextColor3 = Color3.fromRGB(120, 200, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 8
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 20
    title:SetAttribute("PathMapStatic", true)
    title.Parent = PathMapCanvas

    PathMapStatus = Instance.new("TextLabel")
    PathMapStatus.Size = UDim2.new(1, -12, 0, 18)
    PathMapStatus.Position = UDim2.new(0, 7, 1, -22)
    PathMapStatus.BackgroundTransparency = 1
    PathMapStatus.Text = "WAITING FOR SAFE PATH"
    PathMapStatus.TextColor3 = Color3.fromRGB(130, 155, 195)
    PathMapStatus.Font = Enum.Font.GothamBold
    PathMapStatus.TextSize = 7
    PathMapStatus.TextXAlignment = Enum.TextXAlignment.Left
    PathMapStatus.ZIndex = 20
    PathMapStatus:SetAttribute("PathMapStatic", true)
    PathMapStatus.Parent = PathMapCanvas

    PathMapTarget = Instance.new("TextLabel")
    PathMapTarget.Size = UDim2.fromOffset(130, 18)
    PathMapTarget.Position = UDim2.new(1, -137, 1, -22)
    PathMapTarget.BackgroundTransparency = 1
    PathMapTarget.Text = "Target: none"
    PathMapTarget.TextColor3 = Color3.fromRGB(255, 220, 105)
    PathMapTarget.Font = Enum.Font.GothamBold
    PathMapTarget.TextSize = 7
    PathMapTarget.TextXAlignment = Enum.TextXAlignment.Right
    PathMapTarget.ZIndex = 20
    PathMapTarget:SetAttribute("PathMapStatic", true)
    PathMapTarget.Parent = PathMapCanvas

    toggle(
        page,
        "Show Live Path",
        "Draw the actual PathfindingService waypoints selected for the current coin.",
        "PathDiagram"
    )

    toggle(
        page,
        "Show Coins",
        "Show nearby detected coins as yellow markers.",
        "PathDiagramCoins"
    )

    toggle(
        page,
        "Show Murderer Zone",
        "Show the murderer position and the danger radius used by the farm.",
        "PathDiagramDanger"
    )

    toggle(
        page,
        "Show Obstacles",
        "Approximate nearby collidable map parts from a top-down view.",
        "PathDiagramObstacles"
    )

    toggle(
        page,
        "Show Players",
        "Show live nearby player positions on the top-down map.",
        "PathDiagramPlayers"
    )

    button(
        page,
        "Center Live Map",
        "Refresh the diagram around your current character position.",
        function()
            LivePathTimestamp = 0
            refreshPathMap(true)
        end
    )

    button(
        page,
        "Clear Route Preview",
        "Hide the currently remembered route until a new path is selected.",
        function()
            LivePathWaypoints = nil
            LivePathTarget = nil
            refreshPathMap(true)
        end
    )
end

--//==============================================================
--// NATURAL DISASTER SURVIVAL SAFE MOVEMENT HELPERS
--//==============================================================
--[[ _WT.NaturalDisasterJumpConnection (forward decl removed) ]]
_WT.OriginalWorkspaceGravity = workspace.Gravity
_WT.NaturalDisasterSpinAngle = 0

function _WT.setupNaturalDisasterInfiniteJump()
    if _WT.NaturalDisasterJumpConnection then pcall(function() _WT.NaturalDisasterJumpConnection:Disconnect() end); _WT.NaturalDisasterJumpConnection=nil end
    if not State.NDSInfiniteJump then return end
    _WT.NaturalDisasterJumpConnection = UserInputService.JumpRequest:Connect(function()
        if State.NDSInfiniteJump and Humanoid and Humanoid.Parent and Humanoid.Health > 0 then
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end)
end

_WT.setupNaturalDisasterInfiniteJump()

--//==============================================================
--// PRISON LIFE SAFE MOVEMENT HELPERS
--//==============================================================
_WT.PrisonLifeSpinAngle = 0
--[[ _WT.PrisonLifeJumpConnection (forward decl removed) ]]

function _WT.isCrouchingForPrisonLife()
    if not Character then return false end

    local names = {"Crouching", "Crouch", "IsCrouching", "Crouched"}
    for _, name in ipairs(names) do
        local child = Character:FindFirstChild(name, true)
        if child and child:IsA("BoolValue") and child.Value == true then
            return true
        end
    end

    for _, name in ipairs(names) do
        local ok, value = pcall(function()
            return Character:GetAttribute(name)
        end)
        if ok and value == true then
            return true
        end
    end

    return false
end

function _WT.setupPrisonLifeInfiniteJump()
    if _WT.PrisonLifeJumpConnection then
        pcall(function() _WT.PrisonLifeJumpConnection:Disconnect() end)
        _WT.PrisonLifeJumpConnection = nil
    end

    if not State.PLInfiniteJump then return end

    _WT.PrisonLifeJumpConnection = UserInputService.JumpRequest:Connect(function()
        if State.PLInfiniteJump and isAlive() then
            pcall(function()
                Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
    end)
end

_WT.setupPrisonLifeInfiniteJump()

--//==============================================================
--// MAIN RUNTIME LOOP
--//==============================================================
_WT.LastRole = "Unknown"
_WT.PreviousRole = "Unknown"
_WT.LastRoleUpdate = 0

connect("MainRuntime", RunService.Heartbeat, function()
    if Destroyed then
        return
    end

    if os.clock() - _WT.LastRoleUpdate > 0.5 then
        _WT.PreviousRole = _WT.LastRole
        _WT.LastRole = getRole()

        if _WT.LastRole == "Innocent" and (_WT.PreviousRole ~= "Innocent" or not RoundStarted) then
            _WT.beginRoundCounter()
        end

        if _WT.LastRole == "Sheriff" then
            _WT.KnownSheriffUserId = LocalPlayer.UserId
        end
        _WT.LastRoleUpdate = os.clock()

        if RoleLabel then
            RoleLabel.Text = "ROLE • " .. _WT.LastRole
        end

        if StatusLabel and not LobbyTeleportStarted then
            StatusLabel.Text =
                "READY • "
                .. _WT.LastRole
                .. (PREMIUM and " • PREMIUM" or "")
        end
    end

    if State.HunterEnabled and State.SuspiciousMovement then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local root = getAliveRoot(player)

                if root then
                    local speed = root.AssemblyLinearVelocity.Magnitude

                    if speed > 145 then
                        flagPlayer(player, "extreme velocity")
                    elseif speed > 95 then
                        flagPlayer(player, "unusual velocity")
                    end
                end
            end
        end
    end

    if State.AntiFling and RootPart then
        local velocity = RootPart.AssemblyLinearVelocity

        if velocity.Magnitude > 175 then
            RootPart.AssemblyLinearVelocity = Vector3.zero
            RootPart.AssemblyAngularVelocity = Vector3.zero
        end
    end

    if State.Noclip and Character then
        -- Re-apply every heartbeat so newly-created body/accessory parts are
        -- handled too. Original collision states are remembered so disabling
        -- noclip does not permanently alter the character.
        for _, object in ipairs(Character:GetDescendants()) do
            if object:IsA("BasePart") then
                if NoclipOriginalCollision[object] == nil then
                    NoclipOriginalCollision[object] = object.CanCollide
                end
                object.CanCollide = false
            end
        end
    elseif next(NoclipOriginalCollision) ~= nil and not State.NDSNoclip then
        for object, original in pairs(NoclipOriginalCollision) do
            if object and object.Parent then
                pcall(function() object.CanCollide = original end)
            end
            NoclipOriginalCollision[object] = nil
        end
    end

    -- Prison Life safe movement tools. These only modify the local character's
    -- ordinary movement properties and do not touch combat remotes or bypasses.
    if isAlive() then
        if State.PLWalkSpeed then
            Humanoid.WalkSpeed = math.clamp(tonumber(State.PLWalkSpeedValue) or 28, 1, 200)
        elseif not State.PLCrouchSpeed then
            -- Only restore the default if our Prison Life movement toggles were
            -- previously responsible for the speed. The normal script remains
            -- free to change WalkSpeed when the feature is disabled.
            if Humanoid.WalkSpeed > 50 then
                Humanoid.WalkSpeed = 16
            end
        end

        if State.PLCrouchSpeed and _WT.isCrouchingForPrisonLife() then
            Humanoid.WalkSpeed = 24
        elseif State.PLWalkSpeed then
            Humanoid.WalkSpeed = math.clamp(tonumber(State.PLWalkSpeedValue) or 28, 1, 200)
        end

        if State.PLSpin and RootPart then
            _WT.PrisonLifeSpinAngle += math.rad(math.clamp(tonumber(State.PLSpinSpeed) or 90, 1, 200)) * (1/60)
            RootPart.CFrame = CFrame.new(RootPart.Position) * CFrame.Angles(0, _WT.PrisonLifeSpinAngle, 0)
        end

        if State.NDSSpin and RootPart then
            _WT.NaturalDisasterSpinAngle += math.rad(math.clamp(tonumber(State.NDSSpinSpeed) or 45, 1, 200)) * (1/60)
            RootPart.CFrame = CFrame.new(RootPart.Position) * CFrame.Angles(0, _WT.NaturalDisasterSpinAngle, 0)
        end

        if State.NDSWalkSpeed then
            Humanoid.WalkSpeed = math.clamp(tonumber(State.NDSWalkSpeedValue) or 32, 1, 200)
        end

        if State.NDSLowGravity then
            workspace.Gravity = math.clamp(_WT.OriginalWorkspaceGravity * 0.45, 20, _WT.OriginalWorkspaceGravity)
        elseif workspace.Gravity ~= _WT.OriginalWorkspaceGravity and not State.NDSLowGravity then
            workspace.Gravity = _WT.OriginalWorkspaceGravity
        end

        if State.NDSNoclip and Character then
            for _, object in ipairs(Character:GetDescendants()) do
                if object:IsA("BasePart") then
                    if NoclipOriginalCollision[object] == nil then
                        NoclipOriginalCollision[object] = object.CanCollide
                    end
                    object.CanCollide = false
                end
            end
        end
    end

    if State.PLFly and isAlive() then
        local camera = workspace.CurrentCamera
        if camera and RootPart and Humanoid then
            if not FlyVelocity or FlyVelocity.Parent ~= RootPart then
                if FlyVelocity then pcall(function() FlyVelocity:Destroy() end) end
                FlyVelocity = Instance.new("BodyVelocity")
                FlyVelocity.Name = "WindTurfPrisonLifeFlyVelocity"
                FlyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                FlyVelocity.P = 12000
                FlyVelocity.Velocity = Vector3.zero
                FlyVelocity.Parent = RootPart
            end
            local direction = Humanoid.MoveDirection
            local vertical = 0
            if KeyboardEnabled then
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical += 1 end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertical -= 1 end
            end
            direction += Vector3.new(0, vertical, 0)
            FlyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * 45 or Vector3.zero
        end
    end

    if State.Fly and isAlive() then
        local camera = workspace.CurrentCamera
        if camera and RootPart and Humanoid then
            if not FlyVelocity or FlyVelocity.Parent ~= RootPart then
                if FlyVelocity then pcall(function() FlyVelocity:Destroy() end) end
                FlyVelocity = Instance.new("BodyVelocity")
                FlyVelocity.Name = "WindTurfFlyVelocity"
                FlyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                FlyVelocity.P = 18000
                FlyVelocity.Velocity = Vector3.zero
                FlyVelocity.Parent = RootPart
            end
            local direction = Vector3.zero
            if KeyboardEnabled then
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.new(0,1,0) end
            end
            if Humanoid.MoveDirection.Magnitude > 0 then direction += Humanoid.MoveDirection end
            FlyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * 65 or Vector3.zero
        end
    elseif FlyVelocity then
        pcall(function() FlyVelocity:Destroy() end)
        FlyVelocity = nil
    end

    if PREMIUM and State.SheriffAutoShoot and _WT.LastRole == "Sheriff" then
        sheriffAutoShoot()
    end

    if PREMIUM and State.MurdererKillAll and _WT.LastRole == "Murderer" then
        murdererKillAll()
    end

    if PathMapCanvas and State.PathDiagram then
        refreshPathMap(false)
    end

    -- No automated farming or collection runs in this build.

end)

--//==============================================================
--// ESP
--//==============================================================
local Highlights = {}

function _WT.destroyHighlight(player)
    local highlight = Highlights[player]

    if highlight then
        pcall(function()
            highlight:Destroy()
        end)
    end

    Highlights[player] = nil
end

_WT.ESP_COLORS = {
    Innocent = Color3.fromRGB(65, 235, 105),
    Murderer = Color3.fromRGB(255, 70, 70),
    Sheriff = Color3.fromRGB(65, 145, 255),
    Hero = Color3.fromRGB(255, 215, 55),
    Unknown = Color3.fromRGB(170, 180, 195),
}

local function updateESP()
    if not State.ESP then
        for player in pairs(Highlights) do _WT.destroyHighlight(player) end
        return
    end

    -- Reconcile the sheriff/hero identity before coloring anything. If the
    -- old sheriff no longer has the gun, the next current gun holder becomes
    -- the sheriff; this lets the Hero color update after the sheriff dies.
    local currentSheriffStillHasGun = false
    if _WT.KnownSheriffUserId then
        local known = Players:GetPlayerByUserId(_WT.KnownSheriffUserId)
        currentSheriffStillHasGun = known and findToolByNames({"gun", "sheriff", "revolver"}, known) ~= nil
    end

    if not currentSheriffStillHasGun then
        _WT.KnownSheriffUserId = nil
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character
                and findToolByNames({"gun", "sheriff", "revolver"}, player) then
                _WT.KnownSheriffUserId = player.UserId
                break
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local highlight = Highlights[player]
            if not highlight or highlight.Parent ~= player.Character then
                _WT.destroyHighlight(player)
                highlight = Instance.new("Highlight")
                highlight.Name = "WindTurfESP"
                highlight.FillTransparency = 0.72
                highlight.OutlineTransparency = 0.03
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = player.Character
                Highlights[player] = highlight
            end
            local color = _WT.ESP_COLORS[getPlayerRole(player)] or _WT.ESP_COLORS.Unknown
            highlight.FillColor = color
            highlight.OutlineColor = color
        end
    end
end

connect("ESPUpdate", RunService.Heartbeat, function()
    updateESP()
end)

--//==============================================================
--// HUD STATS
--//==============================================================
StatsLabel = Instance.new("TextLabel")
StatsLabel.Name = "Stats"
StatsLabel.Size = UDim2.fromOffset(170, 20)
StatsLabel.Position = UDim2.new(1, -180, 1, -23)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Text = ""
StatsLabel.TextColor3 = Color3.fromRGB(145, 175, 220)
StatsLabel.Font = Enum.Font.Code
StatsLabel.TextSize = 9
StatsLabel.TextXAlignment = Enum.TextXAlignment.Right
StatsLabel.Parent = Main

RoleLabel = Instance.new("TextLabel")
RoleLabel.Name = "Role"
RoleLabel.Size = UDim2.fromOffset(150, 20)
RoleLabel.Position = UDim2.new(0, 113, 1, -23)
RoleLabel.BackgroundTransparency = 1
RoleLabel.Text = "ROLE • Innocent"
RoleLabel.TextColor3 = Color3.fromRGB(150, 170, 205)
RoleLabel.Font = Enum.Font.Code
RoleLabel.TextSize = 9
RoleLabel.TextXAlignment = Enum.TextXAlignment.Left
RoleLabel.Parent = Main

_WT.Frames = 0
_WT.FPSClock = os.clock()

connect("StatsUpdate", RunService.RenderStepped, function()
    _WT.Frames += 1

    local now = os.clock()

    if now - _WT.FPSClock >= 0.5 then
        local fps = math.floor(
            _WT.Frames / math.max(now - _WT.FPSClock, 0.001)
        )

        _WT.Frames = 0
        _WT.FPSClock = now

        local pingText = ""

        if State.Ping then
            local ping = nil

            pcall(function()
                local network =
                    StatsService:FindFirstChild("Network")

                if network then
                    local serverStats =
                        network:FindFirstChild("ServerStatsItem")

                    if serverStats then
                        local dataPing =
                            serverStats:FindFirstChild("Data Ping")

                        if dataPing then
                            ping = dataPing:GetValue()
                        end
                    end
                end
            end)

            if ping then
                pingText = " • " .. tostring(math.floor(ping)) .. "ms"
            end
        end

        if State.FPS then
            StatsLabel.Text =
                "FPS " .. tostring(fps) .. pingText
        else
            StatsLabel.Text = State.Ping and pingText or ""
        end
    end
end)

--//==============================================================
--// INITIAL FADE-IN
--//==============================================================
Main.BackgroundTransparency = 1

tween(
    Main,
    0.35,
    {
        BackgroundTransparency = 0.06
    }
)

notify(
    "WindTurf",
    PREMIUM
        and "Rebuilt UI loaded • Premium verified."
        or "Rebuilt UI loaded • Android portrait mode.",
    4
)

print(
    "[WindTurf] "
        .. CONFIG.ScriptName
        .. " "
        .. CONFIG.Version
        .. " loaded."
)


--//==============================================================
--// PERIODIC PROFILE SAVE
--//==============================================================
task.spawn(function()
    while not Destroyed do
        task.wait(30)
        if not Destroyed then
            pcall(savePersistentData)
        end
    end
end)
