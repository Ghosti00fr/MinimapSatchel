local M = dofile("test/mock.lua")

local plays
local function setup()
    M.reset()
    MiniMapMailFrame = CreateFrame("Frame", "MiniMapMailFrame", Minimap); MiniMapMailFrame.w, MiniMapMailFrame.h = 33, 33
    local MS = M.load()
    plays = 0
    local real = MS.Anims.play
    MS.Anims.play = function(...) plays = plays + 1; return real(...) end
    M.fire("ADDON_LOADED", "MinimapSatchel")
    M.fire("PLAYER_LOGIN")
    return MS
end
local function slash(s) SlashCmdList.MINIMAPSATCHEL(s) end

-- /satchel reset
local MS = setup()
M.button("AlphaButton"); M.button("BetaButton")
MS.Collector:Scan()
MS.Placement:Release(MS.Collector.known.AlphaButton, 10)
MS.Config:Set("satchelAngle", 33)
slash("reset")
ok(next(MS.Config:Get("out")) == nil, "/satchel reset vide out")
ok(MS.Collector.known.AlphaButton.state == "in", "/satchel reset range les icônes sorties")
ok(MS.Config:Get("satchelAngle") == 200, "/satchel reset remet l'angle du sac")
ok(M.printed[#M.printed]:find(MS.L.reset_done, 1, true), "/satchel reset confirme")

-- /satchel test
MS = setup()
slash("test")
ok(plays == 1, "/satchel test lance une animation")

-- aide / panneau
MS = setup()
slash("blabla")
ok(M.printed[#M.printed]:find("/satchel", 1, true), "commande inconnue : aide")
slash("")
ok(MinimapSatchelOptions and MinimapSatchelOptions:IsShown(), "/satchel ouvre le panneau")
slash("")
ok(not MinimapSatchelOptions:IsShown(), "/satchel referme le panneau")
MS.Satchel.button:Click("RightButton")
ok(MinimapSatchelOptions:IsShown(), "clic droit sur le sac ouvre les options")

-- actions du panneau
MS = setup()
M.button("GammaButton")
MS.Collector:Scan()
local g = MS.Collector.known.GammaButton
MS.Options:Apply("bg", "class")
ok(MS.Satchel.grid.bg.color[1] == 0.25, "Apply bg : couleurs appliquées")
MS.Options:Apply("columns", 99)
ok(MS.Config:Get("columns") == 4, "Apply : valeur invalide refusée")
MS.Options:ToggleIcon(g)
ok(g.state == "out" and MS.Config:Get("out").GammaButton ~= nil, "ToggleIcon : sortie")
MS.Options:ToggleIcon(g)
ok(g.state == "in", "ToggleIcon : rangée")
MS.Options:IgnoreIcon(g)
ok(MS.Config:Get("ignored").GammaButton and MS.Collector.known.GammaButton == nil, "IgnoreIcon : ignorée et oubliée")
ok(GammaButton:GetParent() == Minimap, "IgnoreIcon : rendue à son parent")
MS.Collector:Scan()
ok(MS.Collector.known.GammaButton == nil, "IgnoreIcon : pas reprise au scan suivant")

MS.Options:SetBlizzard("MiniMapMailFrame", true)
ok(MS.Collector.known.MiniMapMailFrame and MS.Collector.known.MiniMapMailFrame.state == "in", "SetBlizzard on : courrier dans le sac")
MS.Options:SetBlizzard("MiniMapMailFrame", false)
ok(MS.Collector.known.MiniMapMailFrame == nil and MiniMapMailFrame:GetParent() == Minimap, "SetBlizzard off : courrier rendu")

-- panneau : construit sans erreur, mail_off affiché si alerte indisponible
M.reset(); HasNewMail = nil
MS = M.load(); M.fire("ADDON_LOADED", "MinimapSatchel")
ok(MS.Mail.mode == "off", "mode off")
ok(pcall(function() MS.Options:Toggle() end), "panneau construit sans erreur en mode off")
ok(MS.Options.mailOff:IsShown(), "ligne mail_off affichée")
