-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Options.lua
--  Petit panneau maison (modèle Cursor Aura, pas d'API Settings).
--  Les actions (Apply, ToggleIcon, IgnoreIcon, SetBlizzard) sont
--  séparées de l'affichage pour être testées hors jeu.
-- ============================================================

local MS = MinimapSatchel
local Config, P, C = MS.Config, MS.Placement, MS.Collector
local L = MS.L

local O = { bgButtons = {}, animButtons = {}, soundButtons = {}, blizzChecks = {}, rows = {} }
MS.Options = O

-- ---- Actions ----
function O:Apply(key, value)
    if not Config:Set(key, value) then return false end
    if key == "bg" then MS.Satchel:ApplyColors() end
    if key == "columns" or key == "group" then MS.Satchel:Layout() end
    self:Update()
    return true
end

function O:ToggleIcon(entry)
    if entry.state == "in" then
        P:Release(entry, ((Config:Get("satchelAngle") or 200) + 40) % 360)
    else
        P:Store(entry)
    end
    self:Update()
end

local function forget(entry)
    P:Unlock(entry)
    Config:Get("out")[entry.id] = nil
    C.known[entry.id] = nil
    MS.Satchel:Layout()
end

function O:IgnoreIcon(entry)
    Config:Get("ignored")[entry.id] = true
    forget(entry)
    self:Update()
end

function O:SetBlizzard(key, on)
    Config:Get("blizzard")[key] = on or nil
    if on then
        C:Scan()
    elseif C.known[key] then
        forget(C.known[key])
    end
    self:Update()
end

-- ---- Affichage ----
local function text(p, s, x, y, font)
    local fs = p:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(s)
    return fs
end

local function button(parent, label, w, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(label)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetColorTexture(1, .82, 0, .7)
    b.sel:SetPoint("TOPLEFT", -3, 3)
    b.sel:SetPoint("BOTTOMRIGHT", 3, -3)
    b.sel:Hide()
    b:SetScript("OnClick", onClick)
    return b
end

local function check(parent, label, x, y, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    c.label = text(parent, label, x + 28, y - 5)
    return c
end

local W = 470

function O:Build()
    local p = CreateFrame("Frame", "MinimapSatchelOptions", UIParent)
    p:SetSize(W, 520)
    p:SetPoint("CENTER")
    p:SetFrameStrata("DIALOG")
    p:EnableMouse(true)
    p:SetMovable(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p.bg = p:CreateTexture(nil, "BACKGROUND")
    p.bg:SetAllPoints()
    p.bg:SetColorTexture(.05, .05, .06, .94)
    text(p, L.title, 16, -12, "GameFontNormalLarge")
    local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local y = -44
    text(p, L.bg, 16, y)
    for i, v in ipairs({ "dark", "class" }) do
        self.bgButtons[v] = button(p, L["bg_" .. v], 140, 120 + (i - 1) * 150, y + 4, function() O:Apply("bg", v) end)
    end
    y = y - 30
    self.groupCheck = check(p, L.group, 14, y, function(v) O:Apply("group", v) end)
    y = y - 26
    self.fadeCheck = check(p, L.fade, 14, y, function(v) O:Apply("fade", v) end)
    y = y - 32
    text(p, L.columns, 16, y)
    button(p, "-", 26, 120, y + 4, function() O:Apply("columns", (Config:Get("columns") or 4) - 1) end)
    self.colText = text(p, "", 156, y)
    button(p, "+", 26, 180, y + 4, function() O:Apply("columns", (Config:Get("columns") or 4) + 1) end)

    y = y - 36
    text(p, L.mail, 16, y, "GameFontNormal")
    y = y - 22
    local anims = {}
    for _, id in ipairs(MS.Anims.order) do anims[#anims + 1] = id end
    anims[#anims + 1] = "none"
    for i, id in ipairs(anims) do
        self.animButtons[id] = button(p, L["anim_" .. id], 106, 16 + (i - 1) * 110, y, function()
            O:Apply("anim", id)
            MS.Anims.play(id, MS.Mail:Target())
        end)
    end
    y = y - 28
    text(p, L.sound, 16, y - 4)
    for i, s in ipairs(MS.Mail.SOUNDS) do
        self.soundButtons[s.key] = button(p, L["sound_" .. s.key], 84, 70 + (i - 1) * 78, y, function()
            O:Apply("sound", s.key)
            MS.Mail:PlaySound()
        end)
    end
    y = y - 28
    self.testButton = button(p, L.test, 100, 16, y, function() MS.Mail:Test() end)
    self.mailOff = text(p, L.mail_off, 126, y - 4, "GameFontDisable")

    y = y - 36
    text(p, L.blizzard, 16, y, "GameFontNormal")
    y = y - 22
    for i, b in ipairs(C:ResolveBlizzard()) do
        local col = (i - 1) % 2
        local key = b.key
        self.blizzChecks[key] = check(p, key:match("([^%.]+)$"), 14 + col * 225, y, function(v) O:SetBlizzard(key, v) end)
        if col == 1 then y = y - 24 end
    end
    if #C:ResolveBlizzard() % 2 == 1 then y = y - 24 end

    y = y - 12
    text(p, L.icons, 16, y, "GameFontNormal")
    self.listTop = y - 22
    tinsert(UISpecialFrames, "MinimapSatchelOptions")
    p:Hide()
    self.panel = p
end

local MAX_ROWS = 12

function O:Row(i)
    local r = self.rows[i]
    if r then return r end
    local p = self.panel
    local y = self.listTop - (i - 1) * 24
    r = {}
    r.name = text(p, "", 16, y - 4)
    r.toggle = button(p, "", 150, 220, y, function() if r.entry then O:ToggleIcon(r.entry) end end)
    r.ignore = button(p, L.icon_ignore, 80, 376, y, function() if r.entry then O:IgnoreIcon(r.entry) end end)
    self.rows[i] = r
    return r
end

function O:Update()
    if not self.panel then return end
    for v, b in pairs(self.bgButtons) do b.sel:SetShown(v == Config:Get("bg")) end
    self.groupCheck:SetChecked(Config:Get("group"))
    self.fadeCheck:SetChecked(Config:Get("fade"))
    self.colText:SetText(tostring(Config:Get("columns")))
    local off = MS.Mail.mode == "off"
    for id, b in pairs(self.animButtons) do b.sel:SetShown(id == Config:Get("anim")); b:SetEnabled(not off) end
    for k, b in pairs(self.soundButtons) do b.sel:SetShown(k == Config:Get("sound")); b:SetEnabled(not off) end
    self.testButton:SetEnabled(not off)
    self.mailOff:SetShown(off)
    local wanted = Config:Get("blizzard")
    for key, c in pairs(self.blizzChecks) do c:SetChecked(wanted[key] and true or false) end

    local list = {}
    for _, e in pairs(C.known) do list[#list + 1] = e end
    list = MS.Satchel.Order(list, true)
    local n = math.min(#list, MAX_ROWS)
    for i = 1, n do
        local r, e = self:Row(i), list[i]
        r.entry = e
        r.name:SetText(e.id); r.name:Show()
        r.toggle:SetText(e.state == "in" and L.icon_in or L.icon_out); r.toggle:Show()
        r.ignore:SetShown(not e.blizzard)
    end
    for i = n + 1, #self.rows do
        local r = self.rows[i]
        r.entry = nil; r.name:Hide(); r.toggle:Hide(); r.ignore:Hide()
    end
    self.panel:SetHeight(-self.listTop + n * 24 + 16)
end

function O:Toggle()
    if not self.panel then self:Build() end
    if self.panel:IsShown() then self.panel:Hide() else self:Update(); self.panel:Show() end
end
