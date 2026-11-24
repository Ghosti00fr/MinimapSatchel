local M = dofile("test/mock.lua")

local function setup()
    M.reset(); local MS = M.load({ "Core", "Collector", "Placement", "Satchel" })
    M.fire("ADDON_LOADED", "MinimapSatchel")
    return MS
end
local function e(id, addon) return { id = id, addon = addon or id } end
local function ids(list) local t = {}; for i, x in ipairs(list) do t[i] = x.id end; return table.concat(t, ",") end

-- prêt
local MS = setup()
ok(MS.Config.db ~= nil, "ADDON_LOADED : Config initialisée")
ok(MinimapSatchelButton ~= nil and MinimapSatchelGrid ~= nil, "bouton et grille créés")
ok(MS.Satchel.grid:IsShown() == false, "grille fermée au départ")

-- ordre
ok(ids(MS.Satchel.Order({ e("b"), e("A"), e("c") }, false)) == "A,b,c", "Order : alphabétique sans casse")
ok(ids(MS.Satchel.Order({ e("z1", "Zed"), e("a1", "Alpha"), e("a0", "Alpha") }, true)) == "a0,a1,z1",
   "Order : groupé par addon puis id")

-- ouverture
MS.Satchel:Toggle(); ok(MS.Satchel:IsOpen(), "Toggle ouvre")
MS.Satchel:Toggle(); ok(not MS.Satchel:IsOpen(), "Toggle referme")
MS.Satchel.button:Click("LeftButton"); ok(MS.Satchel:IsOpen(), "clic gauche ouvre")
M.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
ok(not MS.Satchel:IsOpen(), "clic ailleurs ferme")
MS.Satchel:Open(); M.mouseOver[MS.Satchel.grid] = true
M.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
ok(MS.Satchel:IsOpen(), "clic dans la grille ne ferme pas")
M.mouseOver[MS.Satchel.grid] = nil
local inSpecial = false
for _, n in ipairs(UISpecialFrames) do if n == "MinimapSatchelGrid" then inSpecial = true end end
ok(inSpecial, "Échap ferme la grille")

-- layout
MS = setup()
for i = 1, 6 do M.button("Icon" .. string.char(64 + i) .. "Button") end
MS.Collector.onNew = function(x) MS.Placement:Restore(x) end
MS.Collector:Scan()
local g = MS.Satchel.grid
local h2 = g:GetHeight()
ok(g:GetWidth() == 7 * 2 + 4 * 32 + 3 * 4, "Layout : largeur pour 4 colonnes")
ok(h2 == 7 * 2 + 2 * 32 + 4, "Layout : 6 icônes / 4 colonnes = 2 rangées")
local p = IconAButton.point
ok(p[1] == "CENTER" and p[2] == g and p[4] == 7 + 16 and p[5] == -(7 + 16), "1re icône en haut à gauche")
p = IconEButton.point
ok(p[4] == 7 + 16 and p[5] == -(7 + 32 + 4 + 16), "5e icône en début de 2e rangée")
MS.Placement:Release(MS.Collector.known.IconAButton, 30)
MS.Placement:Release(MS.Collector.known.IconBButton, 60)
ok(g:GetHeight() == 7 * 2 + 32, "icônes sorties retirées de la grille (4 restantes = 1 rangée)")
MS.Config:Set("columns", 2); MS.Satchel:Layout()
ok(g:GetHeight() == 7 * 2 + 2 * 32 + 4, "colonnes réglables")

-- groupe : un addon à 2 icônes a sa rangée et son étiquette
MS = setup()
M.button("Dup_One"); M.button("Dup_Two"); M.button("SoloButton")
MS.Collector.onNew = function(x) MS.Placement:Restore(x) end
MS.Config:Set("group", true)
MS.Collector:Scan()
local labels = MS.Satchel.labels
ok(labels[1] and labels[1]:IsShown() and labels[1]:GetText() == "Dup", "groupe : étiquette de l'addon en double")
ok(not (labels[2] and labels[2]:IsShown()), "groupe : pas d'étiquette pour un addon seul")
MS.Config:Set("group", false); MS.Satchel:Layout()
ok(not labels[1]:IsShown(), "sans groupe : étiquettes cachées")

-- couleurs
MS = setup()
local r, gg, b, a = MS.Satchel.BgColor("dark", "MAGE")
ok(r == 0.04 and gg == 0.04 and b == 0.05 and a == 0.92, "BgColor dark")
r, gg, b, a = MS.Satchel.BgColor("class", "MAGE")
ok(r == 0.25 and gg == 0.78 and b == 0.92 and a == 0.85, "BgColor classe MAGE")
r, gg, b, a = MS.Satchel.BgColor("class", "NOPE")
ok(r == 0.04 and a == 0.92, "couleur classe inconnue = sombre")
C_ClassColor = { GetClassColor = function(c) if c == "EVOKER" then return { r = .2, g = .5, b = .4 } end end }
r = MS.Satchel.BgColor("class", "EVOKER")
ok(r == .2, "repli C_ClassColor")
MS.Config:Set("bg", "class"); MS.Satchel:ApplyColors()
ok(MS.Satchel.grid.bg.color[1] == 0.25, "ApplyColors : grille couleur de classe")
ok(MS.Satchel.button.bg.color[1] == 0.25, "ApplyColors : bouton couleur de classe")

-- bouton : position, glisser autour de la minimap
MS = setup()
M.advance(0.05)
local x, y = MS.Placement.EdgePoint(200, 140)
p = MS.Satchel.button.point
ok(math.abs(p[4] - x) < 1e-6 and math.abs(p[5] - y) < 1e-6, "bouton posé à satchelAngle")
MS.Satchel.button.scripts.OnDragStart(MS.Satchel.button)
M.cx, M.cy = 100, 300
M.advance(0.05)
MS.Satchel.button.scripts.OnDragStop(MS.Satchel.button)
ok(math.abs(MS.Config:Get("satchelAngle") - 90) < 1e-6, "glisser le bouton : angle sauvé")

-- fondu
MS = setup()
M.advance(0.5)
ok(MS.Satchel.button:GetAlpha() == 1, "sans fondu : toujours visible")
MS.Config:Set("fade", true)
M.advance(0.5)
ok(MS.Satchel.button:GetAlpha() == 0, "fondu : caché hors minimap")
M.mouseOver[Minimap] = true
M.advance(0.5)
ok(MS.Satchel.button:GetAlpha() == 1, "fondu : visible souris sur la minimap")
