-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Locales/frFR.lua
--  Textes en français.
-- ============================================================

if GetLocale() ~= "frFR" then return end
local L = MinimapSatchel.L
for k, v in pairs({
    tip_satchel   = "Clic : ouvrir / fermer\nClic droit : options\nGlisser : déplacer autour de la minimap",
    tip_icon      = "Glisse-la sur le sac pour la ranger",
    bg            = "Fond",
    bg_dark       = "Sombre",
    bg_class      = "Couleur de classe",
    group         = "Regrouper les icônes par addon",
    columns       = "Colonnes",
    fade          = "Afficher le sac seulement quand la souris est sur la minimap",
    mail          = "Alerte courrier",
    anim_bounce   = "Rebond + halo",
    anim_fly      = "Lettre qui vole",
    anim_shake    = "Secousse + étincelles",
    anim_none     = "Aucune",
    sound         = "Son",
    sound_default = "Carillon",
    sound_tell    = "Chuchotement",
    sound_ping    = "Signal de carte",
    sound_auction = "Cloche d'enchères",
    sound_none    = "Aucun",
    test          = "Tester",
    mail_off      = "Alerte courrier indisponible sur ce client.",
    blizzard      = "Boutons Blizzard dans le sac",
    icons         = "Icônes détectées",
    icon_out      = "Autour de la minimap",
    icon_in       = "Dans le sac",
    icon_ignore   = "Ignorer",
    help          = "/satchel : options · /satchel reset : tout ranger · /satchel test : alerte courrier",
    reset_done    = "Toutes les icônes sont de retour dans le sac.",
}) do L[k] = v end
