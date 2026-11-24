-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Collector.lua
--  Trouve les icônes d'addons : boutons LibDBIcon d'abord, puis scan
--  des enfants de la minimap. Boutons Blizzard seulement sur option.
-- ============================================================

local MS = MinimapSatchel
local Config = MS.Config

local C = { known = {} }
MS.Collector = C

-- Boutons Blizzard optionnels, dans l'ordre de résolution (Retail d'abord).
C.BLIZZARD = {
    "MinimapCluster.IndicatorFrame.MailFrame", "MiniMapMailFrame",
    "GameTimeFrame",
    "MinimapCluster.Tracking", "MiniMapTracking",
    "MinimapCluster.ZoomIn", "MinimapZoomIn",
    "MinimapCluster.ZoomOut", "MinimapZoomOut",
    "TimeManagerClockButton", "MiniMapWorldMapButton",
}

-- Cadres Blizzard jamais pris par le scan (hors option ci-dessus).
C.EXCLUDE = {}
for _, n in ipairs({ "MiniMapMailFrame", "GameTimeFrame", "MiniMapTracking", "MiniMapTrackingButton",
    "MinimapZoomIn", "MinimapZoomOut", "TimeManagerClockButton", "MiniMapWorldMapButton",
    "MiniMapBattlefieldFrame", "MiniMapLFGFrame", "QueueStatusMinimapButton", "QueueStatusButton",
    "GarrisonLandingPageMinimapButton", "ExpansionLandingPageMinimapButton", "MinimapToggleButton",
    "MiniMapVoiceChatFrame", "MiniMapInstanceDifficulty", "GuildInstanceDifficulty",
    "MiniMapChallengeMode", "MinimapZoneTextButton", "MinimapBackdrop", "MiniMapRecordingButton",
    "MinimapSatchelButton" }) do
    C.EXCLUDE[n] = true
end
C.EXCLUDE_PATTERNS = { "^HandyNotes", "Pin", "^GatherMate", "^TomTom", "^Questie" }

local function resolve(path)
    local t = _G
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end

function C:ResolveBlizzard()
    local out, seen = {}, {}
    for _, key in ipairs(self.BLIZZARD) do
        local f = resolve(key)
        if type(f) == "table" and f.GetObjectType and not seen[f] then
            seen[f] = true
            out[#out + 1] = { key = key, frame = f }
        end
    end
    return out
end

local function excluded(name)
    if C.EXCLUDE[name] then return true end
    for _, p in ipairs(C.EXCLUDE_PATTERNS) do
        if name:find(p) then return true end
    end
    return false
end

function C:IsCandidate(frame)
    if frame.GetObjectType == nil or frame:GetObjectType() ~= "Button" then return false end
    local name = frame:GetName()
    if not name or excluded(name) then return false end
    if MS.Satchel and frame == MS.Satchel.button then return false end
    if not frame:IsShown() then return false end
    local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
    return w >= 16 and w <= 40 and h >= 16 and h <= 40
end

-- Id stable : nom LibDBIcon, sinon nom global (compteur final retiré si la base est unique).
function C:IdFor(frame, ldbName, baseCount)
    if ldbName then return ldbName end
    local name = frame:GetName()
    if not name then return nil end
    local base = name:match("^(.-)%d+$")
    if base and base ~= "" and baseCount and baseCount[base] == 1 then return base end
    return name
end

function C:AddonFor(frame, id, ldbName)
    if ldbName then return ldbName end
    local name = frame:GetName() or id
    local p = name:match("^([^_]+)_")
    if p then return p end
    for _, key in ipairs({ "MinimapButton", "Minimap", "Button" }) do
        local s = name:find(key, 2, true)
        if s then return name:sub(1, s - 1) end
    end
    return id
end

local function add(found, frame, ldbName, blizzKey)
    found[#found + 1] = { frame = frame, ldb = ldbName, blizz = blizzKey }
end

function C:Scan()
    local found, seen = {}, {}
    for _, e in pairs(self.known) do seen[e.frame] = true end

    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.GetButtonList then
        for _, n in ipairs(lib:GetButtonList()) do
            local b = lib:GetMinimapButton(n)
            if b and not seen[b] and b:IsShown() then seen[b] = true; add(found, b, n) end
        end
    end
    for _, parent in ipairs({ Minimap, MinimapBackdrop }) do
        if parent and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                if not seen[child] and self:IsCandidate(child) then seen[child] = true; add(found, child) end
            end
        end
    end
    local wanted = Config:Get("blizzard") or {}
    for _, b in ipairs(self:ResolveBlizzard()) do
        if wanted[b.key] and not seen[b.frame] then seen[b.frame] = true; add(found, b.frame, nil, b.key) end
    end

    local baseCount = {}
    for _, c in ipairs(found) do
        local name = (not c.ldb and not c.blizz) and c.frame:GetName()
        local base = name and name:match("^(.-)%d+$")
        if base and base ~= "" then baseCount[base] = (baseCount[base] or 0) + 1 end
    end

    local ignored = Config:Get("ignored") or {}
    for _, c in ipairs(found) do
        local id = c.blizz or self:IdFor(c.frame, c.ldb, baseCount)
        if id and not ignored[id] and not self.known[id] then
            local e = { id = id, frame = c.frame, origParent = c.frame:GetParent(),
                        addon = c.blizz and "Blizzard" or self:AddonFor(c.frame, id, c.ldb),
                        blizzard = c.blizz ~= nil }
            self.known[id] = e
            if self.onNew then self.onNew(e) end
        end
    end
    return self.known
end

-- Rescans : connexion (+1, +3, +8 s), puis chaque ADDON_LOADED (regroupés sur 0,5 s).
function C:Start()
    local pending = false
    MS.On("PLAYER_LOGIN", function()
        C:Scan()
        for _, d in ipairs({ 1, 3, 8 }) do C_Timer.After(d, function() C:Scan() end) end
    end)
    MS.On("ADDON_LOADED", function()
        if pending then return end
        pending = true
        C_Timer.After(0.5, function() pending = false; C:Scan() end)
    end)
end
