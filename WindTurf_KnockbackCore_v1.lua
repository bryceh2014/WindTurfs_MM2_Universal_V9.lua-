-- WindTurf Controlled Knockback Core v1
-- Server-side ModuleScript for NPCs in experiences you own or control.
-- Intentionally refuses player characters. This module has no player-targeting logic.

local Players = game:GetService("Players")

local Knockback = {}

Knockback.Settings = {
    NormalStrength = 65,
    MiniStrength = 130,
    MiniHeightThreshold = 3.5,
    MaxHorizontalSpeed = 90,
    MaxVerticalSpeed = 35,
    VerticalLift = 12,
    Cooldown = 0.8,
}

local lastHit = setmetatable({}, { __mode = "k" })

local function clampVectorMagnitude(vector, maxMagnitude)
    if vector.Magnitude > maxMagnitude then
        return vector.Unit * maxMagnitude
    end
    return vector
end

local function isValidNPC(model)
    if typeof(model) ~= "Instance" or not model:IsA("Model") then
        return false
    end

    -- Do not apply this mechanic to any real player's character.
    if Players:GetPlayerFromCharacter(model) ~= nil then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")

    if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
        return false
    end

    return humanoid, root
end

function Knockback.IsMini(model)
    if typeof(model) ~= "Instance" or not model:IsA("Model") then
        return false
    end

    local ok, extents = pcall(function()
        return model:GetExtentsSize()
    end)

    return ok and extents.Y <= Knockback.Settings.MiniHeightThreshold
end

function Knockback.Apply(npc, direction)
    local humanoid, root = isValidNPC(npc)
    if not humanoid then
        return false, "Target must be a living NPC, not a player character"
    end

    if typeof(direction) ~= "Vector3" then
        return false, "Direction must be a Vector3"
    end

    local horizontal = Vector3.new(direction.X, 0, direction.Z)
    if horizontal.Magnitude < 0.001 then
        return false, "Direction is too small"
    end
    horizontal = horizontal.Unit

    local now = os.clock()
    local previous = lastHit[npc]
    if previous and now - previous < Knockback.Settings.Cooldown then
        return false, "Cooldown"
    end
    lastHit[npc] = now

    local mini = Knockback.IsMini(npc)
    local strength = mini and Knockback.Settings.MiniStrength
        or Knockback.Settings.NormalStrength

    local desired = horizontal * strength
    desired = clampVectorMagnitude(desired, Knockback.Settings.MaxHorizontalSpeed)
    desired += Vector3.new(0, math.clamp(
        Knockback.Settings.VerticalLift,
        0,
        Knockback.Settings.MaxVerticalSpeed
    ), 0)

    -- Apply only the velocity change needed to reach the capped target velocity.
    -- This prevents repeated hits from adding unlimited speed.
    local current = root.AssemblyLinearVelocity
    local currentHorizontal = clampVectorMagnitude(
        Vector3.new(current.X, 0, current.Z),
        Knockback.Settings.MaxHorizontalSpeed
    )
    local currentVertical = math.clamp(
        current.Y,
        -Knockback.Settings.MaxVerticalSpeed,
        Knockback.Settings.MaxVerticalSpeed
    )

    local cappedCurrent = Vector3.new(
        currentHorizontal.X,
        currentVertical,
        currentHorizontal.Z
    )
    local targetVelocity = cappedCurrent + desired
    local targetHorizontal = clampVectorMagnitude(
        Vector3.new(targetVelocity.X, 0, targetVelocity.Z),
        Knockback.Settings.MaxHorizontalSpeed
    )
    targetVelocity = Vector3.new(
        targetHorizontal.X,
        math.clamp(targetVelocity.Y, -Knockback.Settings.MaxVerticalSpeed,
            Knockback.Settings.MaxVerticalSpeed),
        targetHorizontal.Z
    )

    local deltaVelocity = targetVelocity - current
    root:ApplyImpulse(deltaVelocity * root.AssemblyMass)

    return true, mini and "Mini NPC knockback applied" or "Normal NPC knockback applied"
end

function Knockback.SetStrength(normalStrength, miniStrength)
    if typeof(normalStrength) == "number" then
        Knockback.Settings.NormalStrength = math.clamp(normalStrength, 0, 90)
    end
    if typeof(miniStrength) == "number" then
        Knockback.Settings.MiniStrength = math.clamp(miniStrength, 0, 130)
    end
end

return Knockback
