local M = dofile("test/mock.lua")

-- défauts sur DB vide
M.reset(); local MS = M.load({ "Core" })
MS.Config:Init()
ok(MS.Config:Get("bg") == "dark", "défaut bg = dark")
ok(MS.Config:Get("columns") == 4, "défaut columns = 4")
ok(MS.Config:Get("satchelAngle") == 200, "défaut satchelAngle = 200")
ok(MS.Config:Get("anim") == "bounce", "défaut anim = bounce")
ok(type(MS.Config:Get("out")) == "table", "défaut out = table")
ok(MinimapSatchelDB.version == 1, "version de schéma écrite")

-- validation
ok(MS.Config:Set("bg", "pink") == false, "bg invalide refusé")
ok(MS.Config:Get("bg") == "dark", "bg inchangé après refus")
ok(MS.Config:Set("bg", "class") == true, "bg class accepté")
ok(MS.Config:Set("columns", 0) == false, "columns 0 refusé")
ok(MS.Config:Set("columns", 2.5) == false, "columns non entier refusé")
ok(MS.Config:Set("columns", 6) == true and MS.Config:Get("columns") == 6, "columns 6 accepté")
ok(MS.Config:Set("satchelAngle", 0 / 0) == false, "angle NaN refusé")

-- DB existante complétée
M.reset(); MinimapSatchelDB = { version = 1, out = { Foo = 90 } }
MS = M.load({ "Core" }); MS.Config:Init()
ok(MS.Config:Get("out").Foo == 90, "out existant conservé")
ok(MS.Config:Get("bg") == "dark", "défaut ajouté à une DB existante")

-- out avec id inconnu ignoré sans erreur
M.reset(); MinimapSatchelDB = { version = 1, out = { Ghost = 10 } }
MS = M.load({ "Core" })
ok(pcall(function() MS.Config:Init() end), "out avec id inconnu ignoré sans erreur")

-- DB corrompue (type faux) remplacée par le défaut
M.reset(); MinimapSatchelDB = { version = 1, bg = 42, out = "x" }
MS = M.load({ "Core" }); MS.Config:Init()
ok(MS.Config:Get("bg") == "dark" and type(MS.Config:Get("out")) == "table", "valeurs corrompues remplacées")

-- locales
M.reset(); M.locale = "frFR"; MS = M.load({ "Core" })
ok(MS.L.title == "Minimap Satchel", "titre en frFR")
ok(MS.L.bg_class == "Couleur de classe", "libellé traduit frFR")
M.reset(); M.locale = "deDE"; MS = M.load({ "Core" })
ok(MS.L.bg_class == "Class color", "repli enUS pour une langue absente")
M.locale = "frFR"

-- bus d'événements
M.reset(); MS = M.load({ "Core" })
local a, b = 0, 0
MS.On("FOO", function() a = a + 1 end)
MS.On("FOO", function(_, x) b = x end)
M.fire("FOO", 7)
ok(a == 1 and b == 7, "MS.On : plusieurs abonnés, arguments transmis")

-- OnReady : après Config:Init, seulement pour notre addon
M.reset(); MS = M.load({ "Core" })
local seen
MS.OnReady(function() seen = MS.Config:Get("bg") end)
M.fire("ADDON_LOADED", "OtherAddon")
ok(seen == nil, "OnReady : pas déclenché pour un autre addon")
M.fire("ADDON_LOADED", "MinimapSatchel")
ok(seen == "dark", "OnReady : déclenché après Config:Init")
