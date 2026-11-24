local M = dofile("test/mock.lua")

local function setup()
    M.reset(); local MS = M.load({ "Core", "Anims" }); M.fire("ADDON_LOADED", "MinimapSatchel"); return MS
end

local MS = setup()
ok(table.concat(MS.Anims.order, ",") == "bounce,fly,shake", "3 animations enregistrées dans l'ordre")
ok(MS.Anims.defs.fly.label == "anim_fly", "libellé = clé de locale")
ok(MS.Config:Set("anim", "fly") == true, "Config accepte un id enregistré")
ok(MS.Config:Set("anim", "portal") == false, "Config refuse un id inconnu")
ok(MS.Config:Set("anim", "none") == true, "Config accepte none")

local target = CreateFrame("Button", "MailTarget", Minimap); target.w, target.h = 33, 33; target.center = { 160, 170 }
ok(MS.Anims.play("nope", target) == false, "play : id inconnu = false")
ok(MS.Anims.play("none", target) == false, "play : none = false")
ok(MS.Anims.play("bounce", nil) == false, "play : cible nil = false")

for _, id in ipairs(MS.Anims.order) do
    MS = setup()
    target = CreateFrame("Button", "MailTarget", Minimap); target.w, target.h = 33, 33; target.center = { 160, 170 }
    ok(MS.Anims.play(id, target) == true, id .. " : play = true")
    M.advance(0.3)
    local fx = MS.Anims.fx
    ok(fx:IsShown() and target:GetAlpha() == 0, id .. " : effet affiché, cible masquée pendant l'animation")
    M.advance(2)
    ok(fx:IsShown(), id .. " : toujours visible après 2,3 s (jouée 3 fois)")
    M.advance(4)
    ok(not fx:IsShown() and target:GetAlpha() == 1, id .. " : fin propre, cible rendue")
end

-- relancer pendant une animation ne casse rien, cible précédente rendue
MS = setup()
local t1 = CreateFrame("Button", "T1", Minimap); t1.w, t1.h = 30, 30; t1.center = { 0, 0 }
local t2 = CreateFrame("Button", "T2", Minimap); t2.w, t2.h = 30, 30; t2.center = { 0, 0 }
MS.Anims.play("shake", t1); M.advance(0.2)
MS.Anims.play("bounce", t2); M.advance(0.1)
ok(t1:GetAlpha() == 1 and t2:GetAlpha() == 0, "relance : ancienne cible rendue")
M.advance(6)
ok(t2:GetAlpha() == 1, "relance : nouvelle cible rendue à la fin")

-- icône : sac pour le bouton-sac, enveloppe sinon
MS = setup()
MS.Satchel = { button = t1 }
ok(MS.Anims.IconFor(t1):find("satchel"), "icône du sac pour le bouton-sac")
ok(MS.Anims.IconFor(t2):find("envelope"), "enveloppe pour le cadre courrier")

-- alpha d'origine rendu (bouton en fondu)
MS = setup()
local faded = CreateFrame("Button", "Faded", Minimap); faded.w, faded.h = 30, 30; faded.center = { 0, 0 }
faded:SetAlpha(0.4)
MS.Anims.play("bounce", faded); M.advance(6)
ok(faded:GetAlpha() == 0.4, "alpha d'origine rendu après l'animation")

-- durée totale = 3 cycles
MS = setup()
ok(MS.Anims.Total("bounce") == 3 * 1.6 and MS.Anims.Total("shake") == 3 * 1.0, "durée totale = 3 cycles")
