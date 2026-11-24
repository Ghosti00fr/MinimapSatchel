-- Mock de l'API WoW pour les tests hors jeu de Minimap Satchel.
-- Usage : local M = dofile("test/mock.lua") ; M.reset() ; M.load({ "Core" })
local M = { locale = "frFR" }

local rawprint = print
function ok(c, m) rawprint((c and "OK  " or "FAIL") .. "  " .. m); if not c then os.exit(1) end end

-- ---- Cadres -------------------------------------------------
-- Méthode inconnue (nom en majuscule, style API WoW) = no-op. Champ en minuscule
-- absent = nil (évite le piège « stub truthy » noté dans Cursor Aura).
local noop = function() end
local Frame = {}
local mt = { __index = function(t, k)
    local m = Frame[k]
    if m then return m end
    if type(k) == "string" and k:match("^%u") then return noop end
end }

local function stub(kind, name, parent)
    local t = setmetatable({ kind = kind or "Frame", name = name, parent = parent, shown = true,
        scripts = {}, events = {}, w = 0, h = 0, alpha = 1, scale = 1 }, mt)
    M.frames[#M.frames + 1] = t
    return t
end
M.stub = stub

function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown end
function Frame:SetShown(v) self.shown = v and true or false end
function Frame:SetScript(n, fn) self.scripts[n] = fn end
function Frame:GetScript(n) return self.scripts[n] end
function Frame:HookScript(n, fn)
    local old = self.scripts[n]
    self.scripts[n] = function(...) if old then old(...) end fn(...) end
end
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:GetName() return self.name end
function Frame:GetObjectType() return self.kind end
function Frame:IsObjectType(k) return self.kind == k or k == "Frame" end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetWidth(w) self.w = w end
function Frame:SetHeight(h) self.h = h end
function Frame:GetWidth() return self.w end
function Frame:GetHeight() return self.h end
function Frame:GetSize() return self.w, self.h end
function Frame:SetPoint(...) self.point = { ... }; self.setPointCalls = (self.setPointCalls or 0) + 1 end
function Frame:ClearAllPoints() self.point = nil end
function Frame:GetPoint() if self.point then return unpack(self.point) end end
function Frame:SetParent(p) self.parent = p end
function Frame:GetParent() return self.parent end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:GetAlpha() return self.alpha end
function Frame:SetScale(s) self.scale = s end
function Frame:GetScale() return self.scale end
function Frame:GetEffectiveScale() return M.uiScale or 1 end
function Frame:EnableMouse(v) self.mouseEnabled = v and true or false end
function Frame:IsMouseOver() return M.mouseOver[self] and true or false end
function Frame:GetCenter() if self.center then return self.center[1], self.center[2] end end
function Frame:GetChildren() return unpack(self.children or {}) end
-- strate / niveau figés (LibDBIcon fige MEDIUM / 8) : Set* ignorés tant que figés
function Frame:SetFrameStrata(s) if not self.fixedStrata then self.strata = s end end
function Frame:GetFrameStrata() return self.strata or "MEDIUM" end
function Frame:SetFixedFrameStrata(v) self.fixedStrata = v and true or false end
function Frame:IsFrameStrataFixed() return self.fixedStrata or false end
function Frame:SetFixedFrameLevel(v) self.fixedLevel = v and true or false end
function Frame:IsFrameLevelFixed() return self.fixedLevel or false end
function Frame:SetFrameLevel(l) if not self.fixedLevel then self.level = l end end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetText(s) self.txt = s end
function Frame:GetText() return self.txt end
function Frame:SetTexture(p) self.tex = p end
function Frame:GetTexture() return self.tex end
function Frame:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Frame:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
function Frame:SetRotation(r) self.rot = r end
function Frame:SetEnabled(v) self.enabled = v and true or false end
function Frame:SetChecked(v) self.checked = v and true or false end
function Frame:GetChecked() return self.checked end
function Frame:CreateTexture(name) local t = stub("Texture", name, self); return t end
function Frame:CreateFontString(name) local t = stub("FontString", name, self); return t end
function Frame:Click(btn) local f = self.scripts.OnClick; if f then f(self, btn or "LeftButton") end end

UIParent = nil

-- ---- Événements, timers -------------------------------------
function M.fire(event, ...)
    for _, f in ipairs(M.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- Fait avancer l'horloge : timers échus, puis OnUpdate de chaque cadre visible.
function M.advance(dt, step)
    step = step or 0.05
    local left = dt
    while left > 1e-9 do
        local d = math.min(step, left)
        M.now = M.now + d
        left = left - d
        M.runTimers()
        for _, f in ipairs(M.frames) do
            if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, d) end
        end
    end
end

function M.runTimers()
    local due = {}
    for i = #M.timers, 1, -1 do
        local t = M.timers[i]
        if t.at <= M.now + 1e-9 then due[#due + 1] = t; table.remove(M.timers, i) end
    end
    table.sort(due, function(a, b) return a.at < b.at end)
    for _, t in ipairs(due) do t.fn() end
end

-- ---- Chargement de l'addon ----------------------------------
local ORDER = { "Locales/enUS", "Locales/frFR", "Locales/esES", "Core", "Anims", "Collector",
                "Placement", "Satchel", "Mail", "Options", "Commands" }
function M.load(only)
    local want
    if only then want = {}; for _, n in ipairs(only) do want[n] = true end end
    for _, n in ipairs(ORDER) do
        if (not want) or want[n] or n:match("^Locales/") then
            local fn = assert(loadfile("MinimapSatchel/" .. n .. ".lua"))
            fn("MinimapSatchel", {})
        end
    end
    return MinimapSatchel
end

-- ---- Remise à zéro ------------------------------------------
function M.reset()
    M.frames, M.timers, M.printed, M.sounds, M.mouseOver = {}, {}, {}, {}, {}
    M.now, M.combat, M.uiScale, M.cx, M.cy = 0, false, 1, 0, 0
    M.newMail = false
    M.classFile = "MAGE"

    UIParent = stub("Frame", "UIParent")
    UIParent.w, UIParent.h = 1920, 1080
    Minimap = stub("Frame", "Minimap", UIParent)
    Minimap.w, Minimap.h, Minimap.center, Minimap.children = 140, 140, { 100, 100 }, {}
    MinimapBackdrop = stub("Frame", "MinimapBackdrop", Minimap)
    MinimapBackdrop.children = {}
    MinimapCluster = nil
    MiniMapMailFrame, GameTimeFrame, MiniMapTracking, MinimapZoomIn, MinimapZoomOut = nil, nil, nil, nil, nil
    TimeManagerClockButton, MiniMapWorldMapButton = nil, nil

    CreateFrame = function(kind, name, parent, template)
        local f = stub(kind, name, parent)
        f.template = template
        if name then _G[name] = f end
        return f
    end
    GetLocale = function() return M.locale end
    GetTime = function() return M.now end
    GetCursorPosition = function() return M.cx, M.cy end
    InCombatLockdown = function() return M.combat end
    UnitClass = function() return "Class", M.classFile end
    HasNewMail = function() return M.newMail end
    PlaySound = function(kit, ch) M.sounds[#M.sounds + 1] = kit end
    SOUNDKIT = { UI_BNET_TOAST = 18019, TELL_MESSAGE = 3081, MAP_PING = 3175, AUCTION_WINDOW_OPEN = 5274 }
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, ROGUE = { r = 1, g = 0.96, b = 0.41 } }
    C_ClassColor = nil
    C_Timer = { After = function(d, fn) M.timers[#M.timers + 1] = { at = M.now + d, fn = fn } end }
    hooksecurefunc = function(a, b, c)
        local tbl, name, fn = a, b, c
        if type(a) == "string" then tbl, name, fn = _G, a, b end
        local orig = tbl[name]
        tbl[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end
    end
    SlashCmdList, UISpecialFrames = {}, {}
    tinsert = table.insert
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    print = function(...)
        local t = {}
        for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
        M.printed[#M.printed + 1] = table.concat(t, " ")
    end

    -- LibDBIcon : M.ldb = { NomAddon = bouton } ; nil = bibliothèque absente
    M.ldb = nil
    LibStub = function(name, silent)
        if name == "LibDBIcon-1.0" and M.ldb then
            return {
                GetButtonList = function() local l = {}; for k in pairs(M.ldb) do l[#l + 1] = k end; return l end,
                GetMinimapButton = function(_, n) return M.ldb[n] end,
            }
        end
        if not silent then error("lib absente " .. tostring(name)) end
    end

    MinimapSatchelDB = nil
    MinimapSatchel = nil
end

-- Crée un bouton d'icône posé sur la minimap.
function M.button(name, parent, w)
    local b = CreateFrame("Button", name, parent or Minimap)
    b.w, b.h = w or 31, w or 31
    local p = parent or Minimap
    p.children = p.children or {}
    p.children[#p.children + 1] = b
    return b
end

return M
