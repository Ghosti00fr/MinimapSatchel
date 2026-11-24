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

-- ---- Verrou ----
-- Boutons d'addons : méthodes remplacées par instance (dur). Cadres Blizzard :
-- jamais d'override (taint), on réancre après coup via hooksecurefunc (doux).
local blocked = function() end
local LOCKED = { "SetPoint", "ClearAllPoints", "SetParent" }

local function savePoints(frame)
    local pts = {}
    local n = frame.GetNumPoints and frame:GetNumPoints() or 1
    for i = 1, n do
        local p = { frame:GetPoint(i) }
        if p[1] then pts[#pts + 1] = p end
    end
    return pts
end

function P:Lock(frame, soft)
    if not frame.__msOrig then
        local o = { inst = {}, soft = soft, points = savePoints(frame),
                    strata = frame:GetFrameStrata(), level = frame:GetFrameLevel(),
                    fixedStrata = frame.IsFrameStrataFixed and frame:IsFrameStrataFixed() or false,
                    fixedLevel = frame.IsFrameLevelFixed and frame:IsFrameLevelFixed() or false }
        for _, m in ipairs(LOCKED) do
            o.inst[m] = rawget(frame, m)   -- méthode propre à l'instance, s'il y en avait une
            o[m] = frame[m]
        end
        frame.__msOrig = o
        -- LibDBIcon fige sa strate (MEDIUM/8) : sans ça, l'icône passe sous la grille
        if frame.SetFixedFrameStrata then frame:SetFixedFrameStrata(false) end
        if frame.SetFixedFrameLevel then frame:SetFixedFrameLevel(false) end
        if soft and not frame.__msHooked then
            frame.__msHooked = true
            hooksecurefunc(frame, "SetPoint", function(f)
                if f.__msApplying or not f.__msAnchor then return end
                C_Timer.After(0, function()
                    local a = f.__msAnchor
                    if a then later(function() P:Anchor(f, unpack(a, 1, 6)) end) end
                end)
            end)
        end
    end
    if not frame.__msOrig.soft then
        for _, m in ipairs(LOCKED) do frame[m] = blocked end
    end
    self.managed[frame] = true
    self:Watch()
end

function P:Unlock(entry)
    local frame = entry.frame
    local o = frame.__msOrig
    if not o then return end
    later(function()
        self.managed[frame] = nil
        frame.__msAnchor = nil
        if not o.soft then for _, m in ipairs(LOCKED) do frame[m] = o.inst[m] end end
        frame.__msOrig = nil
        frame:SetParent(entry.origParent or Minimap)
        frame:SetFrameStrata(o.strata)
        frame:SetFrameLevel(o.level)
        if frame.SetFixedFrameStrata then frame:SetFixedFrameStrata(o.fixedStrata) end
        if frame.SetFixedFrameLevel then frame:SetFixedFrameLevel(o.fixedLevel) end
        frame:ClearAllPoints()
        for _, p in ipairs(o.points) do frame:SetPoint(unpack(p)) end
        local lib = entry.ldb and LibStub and LibStub("LibDBIcon-1.0", true)
        if lib and lib.Refresh then lib:Refresh(entry.ldb) end
        self:UnhookDrag(frame)
        entry.state = nil
    end)
end

function P:Anchor(frame, parent, point, rel, relPoint, x, y)
    local o = frame.__msOrig
    local setParent = o and o.SetParent or frame.SetParent
    local clear = o and o.ClearAllPoints or frame.ClearAllPoints
    local setPoint = o and o.SetPoint or frame.SetPoint
    frame.__msApplying = true
    setParent(frame, parent)
    clear(frame)
    setPoint(frame, point, rel, relPoint, x, y)
    frame.__msApplying = nil
    frame.__msAnchor = { parent, point, rel, relPoint, x, y }
    -- strate : au-dessus de la grille une fois rangé, d'origine une fois sorti
    if o then
        if MS.Satchel and parent == MS.Satchel.grid then
            frame:SetFrameStrata(parent:GetFrameStrata())
            frame:SetFrameLevel(parent:GetFrameLevel() + 2)
        else
            frame:SetFrameStrata(o.strata)
            frame:SetFrameLevel(o.level)
        end
    end
end

-- Veille (2 s) : override de méthode réécrasé, ou scripts de drag remis par
-- l'addon (LibDBIcon:Refresh) -> on reprend la main.
local watching = false
function P:Watch()
    if watching then return end
    watching = true
    local function tick()
        for frame in pairs(P.managed) do
            local o = frame.__msOrig
            if o and not o.soft and (frame.SetPoint ~= blocked or frame.SetParent ~= blocked
                                     or frame.ClearAllPoints ~= blocked) then
                for _, m in ipairs(LOCKED) do frame[m] = blocked end
                local a = frame.__msAnchor
                if a then later(function() P:Anchor(frame, unpack(a, 1, 6)) end) end
            end
            local d = frame.__msDrag
            if d then
                local cs, ce = frame:GetScript("OnDragStart"), frame:GetScript("OnDragStop")
                if cs ~= d.ours.start then d.start = cs; frame:SetScript("OnDragStart", d.ours.start) end
                if ce ~= d.ours.stop then d.stop = ce; frame:SetScript("OnDragStop", d.ours.stop) end
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
        self:Lock(entry.frame, entry.blizzard)
        self:HookDrag(entry)
        local grid = MS.Satchel.grid
        self:Anchor(entry.frame, grid, "CENTER", grid, "CENTER", 0, 0)
        entry.state = "in"
        layout()
    end)
end

-- Pas de Show() : un bouton caché par son addon (ou le courrier sans lettre) le reste.
function P:Release(entry, angleDeg)
    later(function()
        Config:Get("out")[entry.id] = angleDeg
        self:Lock(entry.frame, entry.blizzard)
        self:HookDrag(entry)
        local x, y = P.EdgePoint(angleDeg, Minimap:GetWidth())
        self:Anchor(entry.frame, Minimap, "CENTER", Minimap, "CENTER", x, y)
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
    local ours = { start = function() P:BeginDrag(entry) end, stop = function() P:EndDrag(entry) end }
    f.__msDrag = { start = f:GetScript("OnDragStart"), stop = f:GetScript("OnDragStop"), ours = ours }
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", ours.start)
    f:SetScript("OnDragStop", ours.stop)
end

function P:UnhookDrag(frame)
    local d = frame.__msDrag
    if not d then return end
    frame:SetScript("OnDragStart", d.start)
    frame:SetScript("OnDragStop", d.stop)
    frame.__msDrag = nil
end
