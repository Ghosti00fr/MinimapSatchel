-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Locales/esES.lua
--  Textos en español (esES y esMX).
-- ============================================================

local loc = GetLocale()
if loc ~= "esES" and loc ~= "esMX" then return end
local L = MinimapSatchel.L
for k, v in pairs({
    tip_satchel   = "Clic: abrir / cerrar\nClic derecho: opciones\nArrastrar: mover alrededor del minimapa",
    tip_icon      = "Arrástralo sobre la bolsa para guardarlo",
    bg            = "Fondo",
    bg_dark       = "Oscuro",
    bg_class      = "Color de clase",
    group         = "Agrupar iconos por addon",
    columns       = "Columnas",
    fade          = "Mostrar la bolsa solo con el ratón sobre el minimapa",
    mail          = "Aviso de correo",
    anim_bounce   = "Rebote + halo",
    anim_fly      = "Carta voladora",
    anim_shake    = "Sacudida + chispas",
    anim_none     = "Ninguna",
    sound         = "Sonido",
    sound_default = "Campanilla",
    sound_tell    = "Susurro",
    sound_ping    = "Señal de mapa",
    sound_auction = "Campana de subasta",
    sound_none    = "Ninguno",
    test          = "Probar",
    mail_off      = "Aviso de correo no disponible en este cliente.",
    blizzard      = "Botones de Blizzard en la bolsa",
    icons         = "Iconos detectados",
    icon_out      = "Alrededor del minimapa",
    icon_in       = "En la bolsa",
    icon_ignore   = "Ignorar",
    help          = "/satchel: opciones · /satchel reset: guardar todo · /satchel test: aviso de correo",
    reset_done    = "Todos los iconos han vuelto a la bolsa.",
}) do L[k] = v end
