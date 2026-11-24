-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Satchel.lua
--  Le bouton-sac sur le bord de la minimap et sa grille d'icônes.
--  Fond sombre ou couleur de classe. Glisser le bouton = le déplacer.
-- ============================================================

local MS = MinimapSatchel
local Config, P = MS.Config, MS.Placement
local L = MS.L

local S = { labels = {} }
MS.Satchel = S

local CELL, GAP, PAD, LABEL_H = 32, 4, 7, 12
local DARK = { 0.04, 0.04, 0.05, 0.92 }

-- ---- Couleurs ----
function S.BgColor(bg, classFile)
    if bg == "class" and classFile then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if not c and C_ClassColor and C_ClassColor.GetClassColor then c = C_ClassColor.GetClassColor(classFile) end
        if c then return c.r, c.g, c.b, 0.85 end
    end
    return DARK[1], DARK[2], DARK[3], DARK[4]
end

-- ---- Ordre ----
function S.Order(entries, group)
    local list = {}
    for i, e in ipairs(entries) do list[i] = e end
    table.sort(list, function(a, b)
        if group and a.addon ~= b.addon then return a.addon:lower() < b.addon:lower() end
        return a.id:lower() < b.id:lower()
    end)
    return list
end

-- ---- Cadres ----
local button = CreateFrame("Button", "MinimapSatchelButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(9)
button:RegisterForClicks("AnyUp")
button:RegisterForDrag("LeftButton")
button.bg = button:CreateTexture(nil, "BACKGROUND")
button.bg:SetTexture(MS.TEX .. "disc")
button.bg:SetSize(21, 21)
button.bg:SetPoint("CENTER")
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetTexture(MS.TEX .. "satchel")
button.icon:SetSize(19, 19)
button.icon:SetPoint("CENTER")
button.border = button:CreateTexture(nil, "OVERLAY")
button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
button.border:SetSize(53, 53)
button.border:SetPoint("TOPLEFT")
button.dragging, button.placed, button.fadeAlpha = false, false, 1
S.button = button

local grid = CreateFrame("Frame", "MinimapSatchelGrid", UIParent)
grid:SetFrameStrata("HIGH")
grid:EnableMouse(true)
grid:Hide()
grid.bg = grid:CreateTexture(nil, "BACKGROUND")
grid.bg:SetAllPoints()
grid.edge = {}
for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                       { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local t = grid:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0.2, 0.2, 0.22, 1)
    t:SetPoint(pts[1]); t:SetPoint(pts[2])
    if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
    grid.edge[i] = t
end
grid:SetPoint("TOPRIGHT", button, "BOTTOMLEFT", 4, 4)
S.grid = grid
tinsert(UISpecialFrames, "MinimapSatchelGrid")

function S:IsOpen() return grid:IsShown() end
function S:Open() self:Layout(); grid:Show() end
function S:Close() grid:Hide() end
function S:Toggle() if grid:IsShown() then self:Close() else self:Open() end end

function S:ApplyColors()
    local r, g, b, a = S.BgColor(Config:Get("bg"), select(2, UnitClass("player")))
    grid.bg:SetColorTexture(r, g, b, a)
    button.bg:SetVertexColor(r, g, b, 1)
end

-- ---- Mise en grille ----
local function label(i)
    local fs = S.labels[i]
    if not fs then
        fs = grid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        S.labels[i] = fs
    end
    return fs
end

function S:Layout()
    local cols = Config:Get("columns") or 4
    local group = Config:Get("group")
    local stored = {}
    for _, e in pairs(MS.Collector.known) do
        if e.state == "in" then stored[#stored + 1] = e end
    end
    stored = S.Order(stored, group)

    -- addons à plusieurs icônes : rangée à part avec étiquette (mode groupé)
    local count = {}
    if group then for _, e in ipairs(stored) do count[e.addon] = (count[e.addon] or 0) + 1 end end

    local col, y, nLabel, rowUsed = 0, PAD, 0, false
    local function newRow()
        if rowUsed then y = y + CELL + GAP end
        col, rowUsed = 0, false
    end
    local current
    for _, e in ipairs(stored) do
        local dup = group and count[e.addon] > 1
        if dup and current ~= e.addon then
            newRow()
            nLabel = nLabel + 1
            local fs = label(nLabel)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", grid, "TOPLEFT", PAD, -y)
            fs:SetText(e.addon)
            fs:Show()
            y = y + LABEL_H
        elseif not dup and current and count[current] and count[current] > 1 then
            newRow()
        end
        current = e.addon
        if col >= cols then newRow() end
        P:Anchor(e.frame, grid, "CENTER", grid, "TOPLEFT",
                 PAD + col * (CELL + GAP) + CELL / 2, -(y + CELL / 2))
        col, rowUsed = col + 1, true
    end
    for i = nLabel + 1, #S.labels do S.labels[i]:Hide() end

    local h = rowUsed and (y + CELL + PAD) or (y - GAP + PAD)
    if #stored == 0 then h = PAD * 2 + CELL end
    grid:SetSize(PAD * 2 + cols * CELL + (cols - 1) * GAP, h)
end

-- ---- Bouton : clics, glisser, fondu ----
function S:Place()
    local x, y = P.EdgePoint(Config:Get("satchelAngle") or 200, Minimap:GetWidth())
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

button:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" and MS.Options then MS.Options:Toggle() else S:Toggle() end
end)
button:SetScript("OnDragStart", function(self) self.dragging = true end)
button:SetScript("OnDragStop", function(self) self.dragging = false; S:Place() end)
button:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.title)
    GameTooltip:AddLine(L.tip_satchel, 1, 1, 1)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
button:SetScript("OnUpdate", function(self, dt)
    if not Config.db then return end
    if self.dragging then
        local mx, my = Minimap:GetCenter()
        local s = Minimap:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        Config:Set("satchelAngle", P.AngleFrom(cx / s, cy / s, mx, my))
        S:Place()
    elseif not self.placed then
        S:Place(); self.placed = true
    end
    local target = 1
    if Config:Get("fade") then
        local over = Minimap:IsMouseOver() or self:IsMouseOver() or grid:IsShown() or self.dragging
        target = over and 1 or 0
    end
    local a = self.fadeAlpha
    if a ~= target then
        a = math.max(0, math.min(1, a + (target > a and 5 or -5) * dt))
        self.fadeAlpha = a
        self:SetAlpha(a)
    end
end)

-- clic ailleurs : fermer (événement absent sur certains clients : Échap reste)
MS.On("GLOBAL_MOUSE_DOWN", function()
    if grid:IsShown() and not grid:IsMouseOver() and not button:IsMouseOver() then S:Close() end
end)

-- ---- Fantôme pendant le glisser hors de la grille ----
local ghost = CreateFrame("Frame", nil, UIParent)
ghost:SetSize(28, 28)
ghost:SetFrameStrata("TOOLTIP")
ghost:Hide()
ghost.tex = ghost:CreateTexture(nil, "ARTWORK")
ghost.tex:SetAllPoints()
ghost:SetScript("OnUpdate", function(self)
    local s = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / s, cy / s)
end)

local function iconOf(frame)
    local t = rawget(frame, "icon")
    if t and t.GetTexture then return t:GetTexture() end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function S:BeginGhost(entry)
    ghost.tex:SetTexture(iconOf(entry.frame))
    entry.frame:SetAlpha(0.3)
    ghost:Show()
end

function S:EndGhost(entry)
    ghost:Hide()
    entry.frame:SetAlpha(1)
end

-- ---- Démarrage ----
MS.OnReady(function()
    S:ApplyColors()
    MS.Collector.onNew = function(e) P:Restore(e) end
    MS.Collector:Start()
end)
