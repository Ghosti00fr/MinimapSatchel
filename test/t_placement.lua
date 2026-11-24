local M = dofile("test/mock.lua")

local layouts
local function setup()
    M.reset(); local MS = M.load({ "Core", "Collector", "Placement" }); MS.Config:Init()
    layouts = 0
    MS.Satchel = { grid = CreateFrame("Frame", "StubGrid", UIParent), button = CreateFrame("Button", "StubBtn", Minimap),
                   Layout = function() layouts = layouts + 1 end }
    MS.Satchel.grid.shown = false
    return MS
end
local function entry(MS, name)
    M.button(name)
    return MS.Collector:Scan()[name]
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- géométrie
local MS = setup()
local x, y = MS.Placement.EdgePoint(0, 140)
ok(near(x, 80) and near(y, 0), "EdgePoint(0) = 80,0")
x, y = MS.Placement.EdgePoint(90, 140)
ok(near(x, 0) and near(y, 80), "EdgePoint(90) = 0,80")
ok(near(MS.Placement.AngleFrom(100, 200, 100, 100), 90), "AngleFrom au-dessus = 90")
local a = MS.Placement.AngleFrom(2000, 0, 100, 100)
ok(type(a) == "number" and a == a and a > -90 and a < 0, "AngleFrom loin de la minimap : angle fini")
ok(MS.Placement.AngleFrom(100, 100, 100, 100) == 0, "AngleFrom au centre exact = 0")

-- Store : rangé, verrouillé
MS = setup()
local e = entry(MS, "FooButton")
MS.Placement:Store(e)
ok(e.frame:GetParent() == MS.Satchel.grid, "Store : parent = grille")
ok(e.state == "in" and layouts == 1, "Store : état in + Layout")
local before = e.frame.point
e.frame:SetPoint("TOP", UIParent, "TOP", 0, 0)
e.frame:ClearAllPoints()
e.frame:SetParent(UIParent)
ok(e.frame.point == before and e.frame:GetParent() == MS.Satchel.grid, "SetPoint externe ignoré après Store")
MS.Placement:Anchor(e.frame, MS.Satchel.grid, "TOPLEFT", MS.Satchel.grid, "TOPLEFT", 7, -7)
ok(e.frame.point[1] == "TOPLEFT" and e.frame.point[4] == 7, "Anchor passe malgré le verrou")

-- Release : sorti au bord, sauvé
e.frame:Hide()
MS.Placement:Release(e, 45)
ok(MS.Config:Get("out").FooButton == 45, "Release : angle sauvé")
ok(e.frame:GetParent() == Minimap and e.state == "out", "Release : parent Minimap, état out")
ok(e.frame:IsShown(), "Release : bouton affiché")
local px, py = MS.Placement.EdgePoint(45, 140)
ok(near(e.frame.point[4], px) and near(e.frame.point[5], py), "Release : posé au bord")

-- Drop
MS.Placement:Drop(e, true, 0, 0)
ok(MS.Config:Get("out").FooButton == nil and e.state == "in", "Drop sur le sac : rangé")
MS.Placement:Drop(e, false, 100, 300)
ok(near(MS.Config:Get("out").FooButton, 90), "Drop ailleurs : sorti à l'angle du lâcher")

-- Restore
MS = setup()
MS.Config:Get("out").BarButton = 120
e = entry(MS, "BarButton")
MS.Placement:Restore(e)
ok(e.state == "out" and e.frame:GetParent() == Minimap, "Restore : out[id] -> sorti")
local e2 = entry(MS, "BazButton")
MS.Placement:Restore(e2)
ok(e2.state == "in", "Restore : sinon rangé")

-- combat
MS = setup()
e = entry(MS, "CombatButton")
M.combat = true
MS.Placement:Store(e)
ok(e.state == nil and e.frame:GetParent() == Minimap, "en combat : rien n'est fait")
M.combat = false
M.fire("PLAYER_REGEN_ENABLED")
ok(e.state == "in" and e.frame:GetParent() == MS.Satchel.grid, "fin de combat : Store appliqué")

-- Unlock
MS = setup()
e = entry(MS, "FreeButton")
MS.Placement:Store(e)
MS.Placement:Unlock(e)
e.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 1, 2)
ok(e.frame.point[1] == "BOTTOM", "Unlock rend le SetPoint d'origine")
ok(e.frame:GetParent() == Minimap, "Unlock rend le parent d'origine")

-- veille : override écrasé par l'addon -> re-verrouillé
MS = setup()
e = entry(MS, "SneakyButton")
MS.Placement:Release(e, 10)
e.frame.SetPoint = function(self, ...) self.point = { ... } end   -- l'addon réécrase la méthode
e.frame:SetPoint("TOP", UIParent, "TOP", 0, 0)
M.advance(2.1)
ok(e.frame.point[2] == Minimap, "veille : ancrage rétabli")
e.frame:SetPoint("TOP", UIParent, "TOP", 0, 0)
ok(e.frame.point[2] == Minimap, "veille : verrou réinstallé")

-- glisser une icône sortie : tourne autour de la minimap, lâcher sur le sac = rangée
MS = setup()
e = entry(MS, "DragButton")
MS.Placement:Release(e, 0)
e.frame.scripts.OnDragStart(e.frame)
M.cx, M.cy = 100, 300
M.advance(0.1)
ok(near(MS.Config:Get("out").DragButton, 90), "drag dehors : angle suit le curseur")
M.mouseOver[MS.Satchel.button] = true
e.frame.scripts.OnDragStop(e.frame)
ok(e.state == "in", "drag lâché sur le sac : rangée")
