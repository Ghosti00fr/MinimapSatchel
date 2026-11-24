-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Placement.lua
--  Ranger une icône dans le sac, la sortir au bord de la minimap,
--  bloquer les repositionnements de l'addon d'origine, glisser.
--  Rien n'est déplacé en combat : file d'attente jusqu'à la fin.
-- ============================================================

local MS = MinimapSatchel
local Config = MS.Config

local P = { managed = {} }
MS.Placement = P

-- ---- Géométrie (même formule que l'icône de Cursor Aura) ----
function P.EdgePoint(angleDeg, width)
    local a = math.rad(angleDeg)
    local r = (width or 140) / 2 + 10
    return math.cos(a) * r, math.sin(a) * r
end

function P.AngleFrom(cx, cy, mx, my)
    return math.deg(math.atan2(cy - my, cx - mx))
end

-- ---- File d'attente combat ----
local queue, waiting = {}, false
local function later(fn)
    if not InCombatLockdown() then fn(); return end
    queue[#queue + 1] = fn
    if not waiting then
        waiting = true
        MS.On("PLAYER_REGEN_ENABLED", function()
            local q = queue; queue = {}
            for _, f in ipairs(q) do f() end
        end)
    end
end
P.later = later

-- ---- Verrou par instance ----
local blocked = function() end
local LOCKED = { "SetPoint", "ClearAllPoints", "SetParent" }

function P:Lock(frame)
    if not frame.__msOrig then
        local o = { inst = {} }
        for _, m in ipairs(LOCKED) do
            o.inst[m] = rawget(frame, m)   -- méthode propre à l'instance, s'il y en avait une
            o[m] = frame[m]
        end
        frame.__msOrig = o
    end
    for _, m in ipairs(LOCKED) do frame[m] = blocked end
    self.managed[frame] = true
    self:Watch()
end

function P:Unlock(entry)
    local frame = entry.frame
    local o = frame.__msOrig
    if not o then return end
    later(function()
        self.managed[frame] = nil
        for _, m in ipairs(LOCKED) do frame[m] = o.inst[m] end
        frame.__msOrig, frame.__msAnchor = nil, nil
        frame:SetParent(entry.origParent or Minimap)
        self:UnhookDrag(frame)
        entry.state = nil
    end)
end

function P:Anchor(frame, parent, point, rel, relPoint, x, y)
    local o = frame.__msOrig
    local setParent = o and o.SetParent or frame.SetParent
    local clear = o and o.ClearAllPoints or frame.ClearAllPoints
    local setPoint = o and o.SetPoint or frame.SetPoint
    setParent(frame, parent)
    clear(frame)
    setPoint(frame, point, rel, relPoint, x, y)
    frame.__msAnchor = { parent, point, rel, relPoint, x, y }
end

-- Veille : un addon qui réécrase SetPoint sur son bouton perd son override.
local watching = false
function P:Watch()
    if watching then return end
    watching = true
    local function tick()
        for frame in pairs(P.managed) do
            if frame.SetPoint ~= blocked or frame.SetParent ~= blocked or frame.ClearAllPoints ~= blocked then
                for _, m in ipairs(LOCKED) do frame[m] = blocked end
                local a = frame.__msAnchor
                if a then later(function() P:Anchor(frame, unpack(a, 1, 6)) end) end
            end
        end
        C_Timer.After(2, tick)
    end
    C_Timer.After(2, tick)
end

-- ---- Ranger / sortir ----
local function layout() if MS.Satchel and MS.Satchel.Layout then MS.Satchel:Layout() end end

function P:Store(entry)
    later(function()
        Config:Get("out")[entry.id] = nil
        self:Lock(entry.frame)
        self:HookDrag(entry)
        local grid = MS.Satchel.grid
        self:Anchor(entry.frame, grid, "CENTER", grid, "CENTER", 0, 0)
        entry.state = "in"
        layout()
    end)
end

function P:Release(entry, angleDeg)
    later(function()
        Config:Get("out")[entry.id] = angleDeg
        self:Lock(entry.frame)
        self:HookDrag(entry)
        local x, y = P.EdgePoint(angleDeg, Minimap:GetWidth())
        self:Anchor(entry.frame, Minimap, "CENTER", Minimap, "CENTER", x, y)
        entry.frame:Show()
        entry.state = "out"
        layout()
    end)
end

function P:Restore(entry)
    local a = Config:Get("out")[entry.id]
    if a then self:Release(entry, a) else self:Store(entry) end
end

local function cursorAngle()
    local mx, my = Minimap:GetCenter()
    local s = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    return P.AngleFrom(cx / s, cy / s, mx or 0, my or 0)
end

function P:Drop(entry, overSatchel, cx, cy)
    if overSatchel then self:Store(entry); return end
    local mx, my = Minimap:GetCenter()
    self:Release(entry, P.AngleFrom(cx, cy, mx or 0, my or 0))
end

-- ---- Glisser ----
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
    local e = P.dragging
    if not e then driver:Hide(); return end
    if e.state == "out" then
        local a = cursorAngle()
        Config:Get("out")[e.id] = a
        local x, y = P.EdgePoint(a, Minimap:GetWidth())
        P:Anchor(e.frame, Minimap, "CENTER", Minimap, "CENTER", x, y)
    end
end)

function P:BeginDrag(entry)
    if InCombatLockdown() then return end
    self.dragging = entry
    if entry.state == "in" and MS.Satchel.BeginGhost then MS.Satchel:BeginGhost(entry) end
    driver:Show()
end

function P:EndDrag(entry)
    if self.dragging ~= entry then return end
    self.dragging = nil
    driver:Hide()
    if MS.Satchel.EndGhost then MS.Satchel:EndGhost(entry) end
    local S = MS.Satchel
    local over = S.button:IsMouseOver() or (entry.state == "in" and S.grid:IsShown() and S.grid:IsMouseOver())
    local s = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    self:Drop(entry, over, cx / s, cy / s)
end

function P:HookDrag(entry)
    local f = entry.frame
    if f.__msDrag then return end
    f.__msDrag = { start = f:GetScript("OnDragStart"), stop = f:GetScript("OnDragStop") }
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() P:BeginDrag(entry) end)
    f:SetScript("OnDragStop", function() P:EndDrag(entry) end)
end

function P:UnhookDrag(frame)
    local d = frame.__msDrag
    if not d then return end
    frame:SetScript("OnDragStart", d.start)
    frame:SetScript("OnDragStop", d.stop)
    frame.__msDrag = nil
end
