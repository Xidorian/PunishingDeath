-- ============================================================================
--  Punishing Death  v2.1.0  --  Palworld UE4SS Lua mod  (single-player / client)
--
--  Fires on RESPAWN (not the death instant): a real death->respawn broadcasts
--  PalPlayerCharacter:CallRespawnDelegate, while a Herbil-style second-life / MP ally-revive
--  takes the SEPARATE CallReviveDelegate path -- so a revived player is exempt, and load-in /
--  fast travel / statue warp (which fire neither) never penalize. See the trigger below.
--
--  On respawn you lose a flat fraction of your TOTAL earned EXP (default 10%).
--  In mid/late game that is roughly one level, so you naturally DE-LEVEL -- and
--  when you do, that level's rewards are stripped too:
--    * techs whose LevelCap is now above your level are re-locked
--    * that level's tech points are removed (with the stripped techs' cost refunded,
--      so re-buying them nets to zero -- no farm)
--    * one status point per level lost is removed (unused first, else a random
--      allocated stat is docked)
--  A natural re-level re-grants everything, so death -> recover nets to zero.
--  At low levels (10% < one level) it's just an EXP scratch, no de-level.
--
--  Exploit-free: the strip exactly offsets the re-level grant.
-- ============================================================================

local CONFIG = {
    -- Fraction of your TOTAL earned EXP lost per death (0.10 = 10%).
    total_loss_fraction = 0.10,

    -- Broadcast "<name> died and lost N EXP" as a [SYSTEM] line.
    --   NOTE: on a dedicated server this system-announce is visible to ALL players.
    show_message = true,

    enable_test_keys = false, -- F9 = run penalty now, F1 = force -1 level, F3 = dry-run. OFF for release.
    verbose = false,
}

local function log(m) print("[PD] " .. m .. "\n") end
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
    local t = {}
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

-- highest level whose cumulative-EXP threshold <= exp
local function levelForExp(exp)
    local best = 1
    for L, thr in pairs(THRESH or {}) do
        if thr <= exp and L > best then best = L end
    end
    return best
end

-- thousands separator ("12345" -> "12,345")
local function commas(n)
    local s = tostring(math.floor(n)); local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

-- Show a blue "[SYSTEM]" line. Confirmed: PalUtility:SendSystemAnnounce(worldContext, msg).
local PALUTIL = nil
local function announce(msg)
    if not CONFIG.show_message then return end
    pcall(function()
        if not isValid(PALUTIL) then PALUTIL = StaticFindObject("/Script/Pal.Default__PalUtility") end
        local p = getPlayer()
        if not (isValid(PALUTIL) and isValid(p)) then return end
        PALUTIL:SendSystemAnnounce(p:GetWorld(), msg)
    end)
end

-- player's display name. Confirmed: PalPlayerState:GetPlayerName() -> FString, :ToString().
local function playerName()
    local p = getPlayer()
    local nm
    if isValid(p) then
        local ps
        pcall(function() ps = p.PlayerState end)
        if not isValid(ps) then pcall(function() ps = p.Controller.PlayerState end) end
        if isValid(ps) then
            pcall(function()
                local v = ps:GetPlayerName()
                if type(v) == "userdata" and v.ToString then nm = v:ToString() end
            end)
        end
    end
    if not nm or nm == "" then nm = "Someone" end
    return nm
end

-- player's technology data (holds UnlockedTechnologyNameArray + tech points)
local function getTechData()
    local p = getPlayer(); if not isValid(p) then return nil end
    local ps
    if not (pcall(function() ps = p.PlayerState end) and isValid(ps)) then
        pcall(function() ps = p.Controller.PlayerState end)
    end
    if not isValid(ps) then return nil end
    local td; pcall(function() td = ps.TechnologyData end)
    if isValid(td) then return td end
    return nil
end

-- Rebuild UnlockedTechnologyNameArray keeping only techs with LevelCap <= keepFloor.
-- Returns before-count, after-count, stripped-name-list, total refundable point cost.
local function stripTechsAboveLevel(td, keepFloor)
    local arr = td.UnlockedTechnologyNameArray
    local n = arr:GetArrayNum()
    local keepers, stripped, stripCost = {}, {}, 0
    for i = 1, n do
        local nm = arr[i]:ToString()
        local bd; pcall(function() bd = td:GetTechlonogyBaseData(FName(nm)) end)
        local cap = bd and num(bd.LevelCap)
        if cap and cap > keepFloor then
            stripped[#stripped + 1] = nm
            stripCost = stripCost + (bd and num(bd.Cost) or 0)
        else keepers[#keepers + 1] = nm end
    end
    if #stripped == 0 then return n, n, stripped, 0 end
    arr:Empty()
    for i, nm in ipairs(keepers) do arr[i] = FName(nm) end
    return n, arr:GetArrayNum(), stripped, stripCost
end

-- Remove one unit of status-point capacity: unused first, else dock a random
-- allocated stat. Status points are keyed by (Japanese) FName StatusName, read
-- dynamically from GetStatusPointList so we never hardcode the names.
local statDockCounter = 0   -- advances every dock so the pick varies within a multi-level drop
local function removeOneStatPoint(ip)
    local unused = num(ip:GetUnusedStatusPoint()) or 0
    if unused > 0 then
        return pcall(function() ip:DecrementUnusedStatusPoint() end) and "unused-1" or "unused-FAIL"
    end
    local out = {}
    pcall(function() ip:GetStatusPointList(out) end)
    local spent = {}
    for i = 1, 8 do
        local e = out[i]
        if e ~= nil then
            local g; pcall(function() g = e:get() end)
            local sn; if g ~= nil then pcall(function() sn = g.StatusName end) end
            local pt; if sn ~= nil then pcall(function() pt = num(ip:GetStatusPoint(sn)) end) end
            if sn ~= nil and pt and pt > 0 then spent[#spent + 1] = { sn = sn, pt = pt } end
        end
    end
    if #spent == 0 then return "none-to-dock" end
    -- vary the pick from live state (EXP differs every death) + a per-call counter,
    -- so it's not always the first stat and doesn't depend on math.random being seeded.
    statDockCounter = statDockCounter + 1
    local seed = (num(ip:GetExp()) or 0) + statDockCounter * 7919
    local pick = spent[(seed % #spent) + 1]
    local nm = "?"; pcall(function() nm = pick.sn:ToString() end)
    return pcall(function() ip:SetStatusPoint(pick.sn, pick.pt - 1) end) and ("spent-dock:" .. nm) or "spent-FAIL"
end

-- The de-level penalty. newExp = target TOTAL exp after the loss.
local function applyDeLevel(newExp, reason)
    if not loadCurve() then log("penalty aborted: no curve"); return end
    local _, ip, sp = getAll()
    if not (isValid(ip) and sp ~= nil) then return end
    local oldLevel = num(ip:GetLevel()) or 1
    local oldExp   = num(ip:GetExp())   or 0
    newExp = math.max(0, math.min(newExp, oldExp))          -- never increase exp
    local newLevel   = levelForExp(newExp)
    local levelsLost = oldLevel - newLevel
    log(string.format("=== DE-LEVEL (%s): L%d->L%d  exp %d->%d  (levelsLost=%d) ===",
        reason or "death", oldLevel, newLevel, oldExp, newExp, levelsLost))
    if levelsLost > 0 then
        local td = getTechData()
        if isValid(td) then
            local b, a, stripped, stripCost = stripTechsAboveLevel(td, newLevel)
            pcall(function() td:OnRep_UnlockedTechnologyNameArray() end)   -- re-apply (re-locks recipes)
            log(string.format("   techs %d->%d (%d stripped, cost %d)", b, a, #stripped, stripCost))
            local tp = num(td.TechnologyPoint) or 0
            local newTp = math.max(0, tp + stripCost - 6 * levelsLost)     -- refund cost, remove grant
            pcall(function() td.TechnologyPoint = newTp end)
            log(string.format("   tech points %d->%d (stripCost %d - grant %d)", tp, newTp, stripCost, 6 * levelsLost))
        end
        for k = 1, levelsLost do log("   stat point: " .. removeOneStatPoint(ip)) end
    end
    pcall(function() sp.Exp = newExp end)
    pcall(function() sp.Level = newLevel end)
    pcall(function() local td2 = getTechData(); if isValid(td2) then td2:OnUpdateLocalPlayerLevel() end end)
    local lost = oldExp - newExp
    if lost > 0 then
        announce(playerName() .. " died and lost " .. commas(lost) .. " EXP" ..
            (levelsLost > 0 and (" and dropped to L" .. newLevel .. ".") or "."))
    end
    log("=== DE-LEVEL done ===")
end

-- Death handler: lose CONFIG.total_loss_fraction of total earned EXP.
local function onDeath(reason)
    if not loadCurve() then return end
    local _, ip = getAll(); if not isValid(ip) then return end
    local exp = num(ip:GetExp()) or 0
    applyDeLevel(math.floor(exp * (1.0 - CONFIG.total_loss_fraction)), reason or "death")
end

-- Penalty trigger: fire on the player's RESPAWN, not on the death instant.
-- Probe-confirmed: a real death->respawn broadcasts PalPlayerCharacter:CallRespawnDelegate,
-- while a Herbil-style second-life (and MP ally-revive) takes the SEPARATE CallReviveDelegate
-- path, and load-in / fast travel / statue warp fire neither. So hooking respawn penalizes
-- ONLY real deaths and structurally ignores revives -- we never have to detect Herbil at all.
-- Because we no longer drain EXP at the death instant, a revived player keeps everything.
-- (Debounce: one respawn may broadcast the delegate more than once -- apply at most once per window.)
local lastPenalty = -1e9
local RESPAWN_DEBOUNCE_S = 3
local function onRespawn()
    local t; pcall(function() t = os.clock() end); t = t or 0
    if (t - lastPenalty) < RESPAWN_DEBOUNCE_S then return end
    lastPenalty = t
    ExecuteInGameThread(function()
        local ok, e = pcall(function() onDeath("respawn") end)
        if not ok then log("penalty err " .. tostring(e)) end
    end)
end
local hookOk = pcall(function()
    RegisterHook("/Script/Pal.PalPlayerCharacter:CallRespawnDelegate", function() onRespawn() end)
end)
log("respawn-penalty hook: " .. (hookOk and "registered (CallRespawnDelegate)" or "FAILED to register"))

if CONFIG.enable_test_keys then
    pcall(function() math.randomseed(os.time()) end)

    -- F9: run the real death penalty right now.
    RegisterKeyBind(Key.F9, function() ExecuteInGameThread(function()
        local ok, e = pcall(function() onDeath("F9 test") end); if not ok then log("F9 err " .. tostring(e)) end
    end) end)

    -- F1: force exactly one level down (tests the de-level path at any level).
    RegisterKeyBind(Key.F1, function() ExecuteInGameThread(function() pcall(function()
        if not loadCurve() then return end
        local _, ip = getAll(); if not isValid(ip) then return end
        local L = num(ip:GetLevel()) or 1
        if L <= 1 then log("F1: already L1"); return end
        applyDeLevel((THRESH[L] or 0) - 1, "F1 forced -1 level")
    end) end) end)

    -- F3: dry-run (read-only preview of what a death would strip).
    RegisterKeyBind(Key.F3, function() pcall(function()
        log("######## F3 DRY-RUN ########")
        if not loadCurve() then log("no curve"); return end
        local _, ip = getAll(); if not isValid(ip) then return end
        local oldLevel = num(ip:GetLevel()) or 1
        local oldExp   = num(ip:GetExp())   or 0
        local newExp   = math.floor(oldExp * (1.0 - CONFIG.total_loss_fraction))
        local newLevel = levelForExp(newExp)
        local levelsLost = oldLevel - newLevel
        log(string.format("death: L%d exp=%d -> exp=%d = L%d (levelsLost=%d)", oldLevel, oldExp, newExp, newLevel, levelsLost))
        local td = getTechData()
        if isValid(td) then
            local arr = td.UnlockedTechnologyNameArray
            local n = arr:GetArrayNum()
            local strip, cost = 0, 0
            for i = 1, n do
                local nm = arr[i]:ToString()
                local bd; pcall(function() bd = td:GetTechlonogyBaseData(FName(nm)) end)
                local cap = bd and num(bd.LevelCap)
                if cap and cap > newLevel then strip = strip + 1; cost = cost + (bd and num(bd.Cost) or 0) end
            end
            local tp = num(td.TechnologyPoint) or 0
            log(string.format("   techs would strip: %d (cost %d); tech points %d -> %d", strip, cost, tp, math.max(0, tp + cost - 6 * math.max(levelsLost, 0))))
        end
        local un; pcall(function() un = ip:GetUnusedStatusPoint() end)
        log(string.format("   stat points to remove: %d (unused=%s)", math.max(levelsLost, 0), tostring(un)))
        log("######## DRY-RUN END ########")
    end) end)

    log("TEST KEYS ON: F9 = death penalty now, F1 = force -1 level, F3 = dry-run")
end

loadCurve()
log(string.format("Punishing Death v2.1.0 loaded -- lose %.0f%% of total EXP on respawn (de-levels + strips rewards; revives exempt).", CONFIG.total_loss_fraction * 100))
