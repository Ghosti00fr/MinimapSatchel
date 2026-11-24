local M = dofile("test/mock.lua")

local plays
local function setup(opts)
    M.reset()
    opts = opts or {}
    if opts.noApi then HasNewMail = nil end
    if opts.frame then
        MiniMapMailFrame = CreateFrame("Frame", "MiniMapMailFrame", Minimap); MiniMapMailFrame.w, MiniMapMailFrame.h = 33, 33
        MiniMapMailFrame.shown = opts.frameShown or false
    end
    local MS = M.load({ "Core", "Anims", "Collector", "Placement", "Satchel", "Mail" })
    plays = {}
    local real = MS.Anims.play
    MS.Anims.play = function(id, target) plays[#plays + 1] = { id = id, target = target }; return real(id, target) end
    M.fire("ADDON_LOADED", "MinimapSatchel")
    M.fire("PLAYER_ENTERING_WORLD", true, false)   -- connexion
    return MS
end

-- connexion avec courrier déjà non lu : rien
local MS = setup({ frame = true })
ok(MS.Mail.mode == "api", "mode api si HasNewMail existe")
M.newMail = true
M.advance(1); M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 0, "état initial vrai ne déclenche pas")
M.advance(10); M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 0, "toujours vrai après la fenêtre : rien")

-- arrivée après la fenêtre
MS = setup({ frame = true })
M.advance(10); M.fire("UPDATE_PENDING_MAIL")
M.newMail = true; M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 1 and plays[1].id == "bounce", "false -> true : une alerte, animation par défaut")
ok(plays[1].target == MiniMapMailFrame, "cible : cadre courrier Blizzard")
ok(#M.sounds == 1 and M.sounds[1] == SOUNDKIT.UI_BNET_TOAST, "son par défaut joué")
M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 1, "2e UPDATE_PENDING_MAIL avec true : pas de nouvelle alerte")
M.newMail = false; M.fire("UPDATE_PENDING_MAIL")
M.newMail = true; M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 2, "true -> false -> true : 2e alerte")

-- changement de zone avec courrier déjà non lu : rien
M.fire("PLAYER_ENTERING_WORLD", false, false); M.advance(1); M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 2, "changement de zone, courrier déjà là : rien")
-- changement de zone puis vraie arrivée : alerte tout de suite (pas de fenêtre muette)
M.newMail = false; M.fire("UPDATE_PENDING_MAIL")
M.fire("PLAYER_ENTERING_WORLD", false, false); M.advance(1)
M.newMail = true; M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 3, "changement de zone puis arrivée : alerte")

-- connexion lente : 1er UPDATE_PENDING_MAIL après 8 s avec du courrier = muet
MS = setup({ frame = true })
M.advance(8); M.newMail = true; M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 0, "connexion lente : 1re mise à jour muette")
M.newMail = false; M.fire("UPDATE_PENDING_MAIL"); M.newMail = true; M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 1, "connexion lente : arrivée suivante alertée")

-- options
MS = setup({ frame = true })
MS.Config:Set("anim", "shake"); MS.Config:Set("sound", "none")
M.advance(10); M.fire("UPDATE_PENDING_MAIL"); M.newMail = true; M.fire("UPDATE_PENDING_MAIL")
ok(plays[1].id == "shake", "animation choisie utilisée")
ok(#M.sounds == 0, "sound=none : PlaySound non appelé")
MS = setup({ frame = true })
MS.Config:Set("anim", "none")
M.advance(10); M.fire("UPDATE_PENDING_MAIL"); M.newMail = true; M.fire("UPDATE_PENDING_MAIL")
ok(#plays == 1 and plays[1].id == "none" and #M.sounds == 1, "anim none : son seul")

-- cible = sac quand le courrier est rangé
MS = setup({ frame = true })
MS.Config:Get("blizzard").MiniMapMailFrame = true
MS.Collector:Scan()
ok(MS.Collector.known.MiniMapMailFrame.state == "in", "courrier rangé dans le sac")
ok(MS.Mail:Target() == MS.Satchel.button, "cible = bouton-sac quand le courrier est rangé")
MS = setup()
ok(MS.Mail:Target() == MS.Satchel.button, "cible = bouton-sac sans cadre courrier")

-- repli sans HasNewMail : visibilité du cadre courrier
MS = setup({ noApi = true, frame = true })
ok(MS.Mail.mode == "frame", "mode frame sans HasNewMail")
M.advance(10); M.fire("UPDATE_PENDING_MAIL")
MiniMapMailFrame:Show()
ok(#plays == 1, "mode frame : affichage du cadre = alerte")
MiniMapMailFrame:Hide(); MiniMapMailFrame:Show()
ok(#plays == 2, "mode frame : caché puis affiché = 2e alerte")

-- rien du tout
MS = setup({ noApi = true })
ok(MS.Mail.mode == "off", "mode off sans API ni cadre")
ok(pcall(function() M.advance(10); M.fire("UPDATE_PENDING_MAIL") end) and #plays == 0, "mode off : aucune erreur, aucune alerte")

-- test manuel
MS = setup({ frame = true })
MS.Mail:Test()
ok(#plays == 1, "Test : alerte sans condition")
