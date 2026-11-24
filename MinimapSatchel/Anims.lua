-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Anims.lua
--  Animations de l'alerte courrier. Chaque animation est une fiche
--  { label, duration, update(fx, t) } : en ajouter une (par classe,
--  plus tard) = un appel à register. Timings : maquette mail-anim-v2.
--  La cible est masquée le temps de l'effet ; une copie de son icône
--  est animée par-dessus (on ne déplace jamais le cadre Blizzard).
-- ============================================================

local MS = MinimapSatchel

local A = { defs = {}, order = {} }
MS.Anims = A

function A.register(id, def)
    if not A.defs[id] then A.order[#A.order + 1] = id end
    def.label = def.label or ("anim_" .. id)
    A.defs[id] = def
end

-- ---- Outils ----
local function hex(s)
    local r, g, b = s:match("#?(%x%x)(%x%x)(%x%x)")
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- keys = { {t, v}, ... } triés ; interpolation linéaire, bornée.
local function key(keys, t)
    if t <= keys[1][1] then return keys[1][2] end
    for i = 2, #keys do
        local a, b = keys[i - 1], keys[i]
        if t <= b[1] then return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1]) end
    end
    return keys[#keys][2]
end
A.key = key

local function rotate(tex, deg) if tex.SetRotation then tex:SetRotation(math.rad(deg)) end end

function A.IconFor(target)
    if MS.Satchel and target == MS.Satchel.button then return MS.TEX .. "satchel" end
    return MS.TEX .. "envelope"
end

-- ---- Cadre d'effet unique (réutilisé) ----
local fx = CreateFrame("Frame", nil, UIParent)
fx:SetFrameStrata("TOOLTIP")
fx:SetSize(32, 32)
fx:Hide()
local function tex(layer, file, blend)
    local t = fx:CreateTexture(nil, layer)
    t:SetTexture(MS.TEX .. file)
    if blend then t:SetBlendMode(blend) end
    return t
end
fx.halo = tex("BACKGROUND", "soft", "ADD")
fx.icon = fx:CreateTexture(nil, "ARTWORK")
fx.letter = tex("OVERLAY", "envelope")
fx.sparks = {}
for i = 1, 5 do fx.sparks[i] = tex("OVERLAY", "star", "ADD") end
A.fx = fx

local function reset(target)
    local size = math.max(target:GetWidth() or 32, 24)
    fx.size = size
    fx:ClearAllPoints()
    fx:SetPoint("CENTER", target, "CENTER", 0, 0)
    fx:SetSize(size, size)
    fx.icon:SetTexture(A.IconFor(target))
    fx.icon:ClearAllPoints(); fx.icon:SetPoint("CENTER", fx, "CENTER", 0, 0)
    fx.icon:SetSize(size * 0.8, size * 0.8); fx.icon:SetAlpha(1); rotate(fx.icon, 0)
    fx.halo:Hide(); fx.letter:Hide()
    for _, s in ipairs(fx.sparks) do s:Hide() end
end

local current
local function finish()
    if current then current.target:SetAlpha(current.alpha or 1) end
    current = nil
    fx:Hide()
end

fx:SetScript("OnUpdate", function(_, dt)
    if not current then fx:Hide(); return end
    current.t = current.t + dt
    local def = current.def
    if current.t >= def.duration then finish(); return end
    def.update(fx, current.t)
end)

function A.play(id, target)
    local def = A.defs[id]
    if not def or not target then return false end
    finish()
    reset(target)
    current = { def = def, target = target, t = 0, alpha = 1 }
    target:SetAlpha(0)
    if def.start then def.start(fx, target) end
    fx:Show()
    def.update(fx, 0)
    return true
end

-- ---- A. Rebond + halo doré ----
A.register("bounce", {
    duration = 1.6,
    start = function(f)
        f.halo:SetVertexColor(hex("#FFD76A")); f.halo:SetSize(f.size * 2.2, f.size * 2.2)
        f.halo:ClearAllPoints(); f.halo:SetPoint("CENTER", f, "CENTER", 0, 0); f.halo:Show()
    end,
    update = function(f, t)
        local p = t / 0.9
        local y = key({ { 0, 0 }, { .2, 18 }, { .4, 0 }, { .55, 8 }, { .7, 0 }, { 1, 0 } }, p)
        f.icon:ClearAllPoints(); f.icon:SetPoint("CENTER", f, "CENTER", 0, y)
        f.halo:SetAlpha(key({ { 0, 0 }, { .32, 1 }, { 1.6, 0 } }, t))
    end,
})

-- ---- B. Lettre qui vole puis entre dans l'icône ----
A.register("fly", {
    duration = 1.6,
    start = function(f, target)
        local cx, cy = target:GetCenter()
        f.fromX, f.fromY = -(cx or 0) + 40, -(cy or 0) + 40   -- depuis le bas-gauche de l'écran
        f.letter:SetSize(f.size * 0.9, f.size * 0.65); f.letter:Show()
    end,
    update = function(f, t)
        local p = math.min(t / 1.2, 1)
        local e = p * p                                          -- accélère en arrivant
        f.letter:ClearAllPoints()
        f.letter:SetPoint("CENTER", f, "CENTER", f.fromX * (1 - e), f.fromY * (1 - e))
        local s = key({ { 0, 1.4 }, { 1, 0.6 } }, p)
        f.letter:SetSize(f.size * 0.9 * s, f.size * 0.65 * s)
        rotate(f.letter, key({ { 0, -20 }, { 1, 10 } }, p))
        f.letter:SetAlpha(key({ { 0, 1 }, { .8, 1 }, { 1, 0 } }, p))
        local pop = key({ { 0, 1 }, { 1.1, 1 }, { 1.3, 1.4 }, { 1.5, 1 } }, t)
        f.icon:SetSize(f.size * 0.8 * pop, f.size * 0.8 * pop)
    end,
})

-- ---- C. Secousse + étincelles ----
local SPARKS = { { -28, 22 }, { 26, 26 }, { 30, -18 }, { -26, -22 }, { 0, 34 } }
A.register("shake", {
    duration = 1.0,
    start = function(f)
        for _, s in ipairs(f.sparks) do
            s:SetVertexColor(hex("#FFE9A0")); s:SetSize(7, 7); s:Show()
        end
    end,
    update = function(f, t)
        local p = t / 0.7
        rotate(f.icon, key({ { 0, 0 }, { .15, -18 }, { .3, 15 }, { .45, -12 }, { .6, 8 }, { .75, -4 }, { 1, 0 } }, p))
        local k = math.min(t / 1.0, 1)
        for i, s in ipairs(f.sparks) do
            s:ClearAllPoints()
            s:SetPoint("CENTER", f, "CENTER", SPARKS[i][1] * k, SPARKS[i][2] * k)
            s:SetAlpha(1 - k)
        end
    end,
})
