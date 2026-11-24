-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Commands.lua
--  /satchel : panneau · /satchel reset : tout ranger · /satchel test
-- ============================================================

local MS = MinimapSatchel
local L = MS.L

local function say(s) print("|cffe8be5aMinimap Satchel|r : " .. s) end

function MS.Reset()
    for _, e in pairs(MS.Collector.known) do
        if e.state ~= "in" then MS.Placement:Store(e) end
    end
    wipe(MS.Config:Get("out"))
    MS.Config:Set("satchelAngle", MS.Config.defaults.satchelAngle)
    MS.Satchel:Place()
    MS.Options:Update()
end

SLASH_MINIMAPSATCHEL1 = "/satchel"
SlashCmdList.MINIMAPSATCHEL = function(msg)
    local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
    if cmd == "" then MS.Options:Toggle()
    elseif cmd == "reset" then MS.Reset(); say(L.reset_done)
    elseif cmd == "test" then MS.Mail:Test()
    else say(L.help) end
end
