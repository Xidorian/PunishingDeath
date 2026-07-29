-- ============================================================================
--  Punishing Death  v1.0.0  --  Palworld UE4SS Lua mod  (single-player / client)
--
--  On death you lose part of your progress toward the next level. Your LEVEL
--  NUMBER never changes -- only the EXP within the current level is drained,
--  down to (at most) the start of your current level.
--
--  Exploit-free by design: no level change means the game never re-grants
--  status/technology points, so death can never be farmed for gain.
--  See DESIGN_NOTES.md for the de-leveling approach we tried and rejected.
-- ============================================================================

local CONFIG = {
    -- Fraction of your CURRENT-LEVEL progress lost per death.
    --   0.25 = lose a quarter of your progress toward the next level
    --   0.50 = lose half (default)
    --   1.00 = every death throws you back to the START of your current level
    progress_loss_fraction = 0.50,

    poll_ms = 2000,           -- death-check interval (death lingers seconds, so 2s is plenty)
    enable_test_keys = false, -- set true to re-enable F9 (apply) / F7 (restore) / F10 (report)
    verbose = false,          -- set true for chatty logs while debugging
}

local function log(m) print("[PD] " .. m .. "\n") end
local function vlog(m) if CONFIG.verbose then log(m) end end
local function isValid(o) return o ~= nil and type(o) == "userdata" and o.IsValid and o:IsValid() end
local function num(x) return tonumber(tostring(x)) end

local function getPlayer()
    local p = FindFirstOf("PalPlayerCharacter")
    if isValid(p) then return p end
    return nil
end

-- player, individualParameter, saveParameter, component
local function getAll()
    local p = getPlayer(); if not isValid(p) then return nil end
    local ok, comp = pcall(function() return p.CharacterParameterComponent end)
    if not (ok and isValid(comp)) then return p end
    local ip; pcall(function() ip = comp.IndividualParameter end)
    if not isValid(ip) then pcall(function() ip = comp:GetIndividualParameter() end) end
    local sp; if isValid(ip) then pcall(function() sp = ip.SaveParameter end) end
    return p, ip, sp, comp
end

-- Level curve: THRESH[level] = cumulative EXP to reach that level (read live).
local THRESH = nil
local function loadCurve()
    if THRESH ~= nil then return true end
    local dt = StaticFindObject("/Game/Pal/DataTable/Exp/DT_PalExpTable.DT_PalExpTable")
    if not isValid(dt) then return false end
    local t, maxl = {}, 1
    local ok = pcall(function()
        dt:ForEachRow(function(rowName, rowData)
            local lvl = num(rowName); local total; pcall(function() total = rowData.TotalEXP end); total = num(total)
            if lvl and total then t[lvl] = total end
        end)
    end)
    if not ok then return false end
    THRESH = t
    return true
end

-- Penalty: drain current-level progress; never touch the level number.
local function applyPenalty(reason)
    if not loadCurve() then log("penalty aborted: no curve"); return end
    local _, ip, sp = getAll()
    if not (isValid(ip) and sp ~= nil) then return end
    local L   = num(ip:GetLevel()) or 1
    local exp = num(ip:GetExp())   or 0
    local floorExp = THRESH[L] or 0
    local progress = exp - floorExp
    if progress <= 0 then return end
    local newExp = floorExp + math.floor(progress * (1.0 - CONFIG.progress_loss_fraction))
    sp.Exp = newExp
    log(string.format("death penalty (%s): L%d kept, Exp %d->%d (lost %d of %d in-level progress)",
        reason or "death", L, exp, newExp, exp - newExp, progress))
end

-- Death detection: poll IsDead, apply once per death, re-arm when alive again.
local wasDead, seenAlive = false, false
LoopAsync(CONFIG.poll_ms, function()
    pcall(function()
        local _, _, _, comp = getAll()
        if not isValid(comp) then return end
        local dead = false; pcall(function() dead = comp:IsDead() end)
        if not dead then
            seenAlive = true
            if wasDead then wasDead = false end
        elseif seenAlive and not wasDead then
            wasDead = true
            ExecuteInGameThread(function() local ok,e=pcall(function() applyPenalty("death") end); if not ok then log("penalty err "..tostring(e)) end end)
        end
    end)
    return false
end)

if CONFIG.enable_test_keys then
    local snap
    RegisterKeyBind(Key.F9, function() pcall(function() applyPenalty("manual test") end) end)
    RegisterKeyBind(Key.F7, function() pcall(function()
        local _, ip, sp = getAll(); if isValid(ip) and sp then if not snap then snap = num(sp.Exp) else sp.Exp = snap end end
    end) end)
    RegisterKeyBind(Key.F10, function() pcall(function()
        local _, ip = getAll(); if isValid(ip) then log("L="..tostring(ip:GetLevel()).." Exp="..tostring(ip:GetExp())) end
    end) end)
end

loadCurve()
log(string.format("Punishing Death v1.0.0 loaded -- lose %.0f%% of current-level progress on death.", CONFIG.progress_loss_fraction * 100))
