-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Mail.lua
--  Alerte à l'arrivée du courrier : une animation + un son, une fois.
--  Se déclenche au passage « pas de courrier » -> « courrier », jamais
--  dans les 5 s qui suivent une connexion / un changement de zone.
--  Limite : une 2e lettre avec du courrier déjà non lu ne se voit pas.
--  Sans HasNewMail : on suit l'affichage du cadre courrier Blizzard.
-- ============================================================

local MS = MinimapSatchel
local Config = MS.Config

local Mail = { mode = "off", armedAt = 0 }
MS.Mail = Mail

-- Sons du jeu proposés (constante SOUNDKIT si présente, sinon id numérique).
Mail.SOUNDS = {
    { key = "default", kit = "UI_BNET_TOAST", id = 18019 },
    { key = "tell",    kit = "TELL_MESSAGE", id = 3081 },
    { key = "ping",    kit = "MAP_PING", id = 3175 },
    { key = "auction", kit = "AUCTION_WINDOW_OPEN", id = 5274 },
    { key = "none" },
}

local function mailFrame()
    for _, b in ipairs(MS.Collector:ResolveBlizzard()) do
        if b.key:find("Mail") then return b.frame, b.key end
    end
end

local function state()
    if Mail.mode == "api" then return HasNewMail() and true or false end
    if Mail.mode == "frame" then return Mail.frame:IsShown() and true or false end
    return false
end

function Mail:Target()
    local f, key = mailFrame()
    local e = key and MS.Collector.known[key]
    if f and not (e and e.state == "in") then return f end
    return MS.Satchel.button
end

function Mail:PlaySound()
    local want = Config:Get("sound")
    for _, s in ipairs(self.SOUNDS) do
        if s.key == want then
            if s.kit then PlaySound((SOUNDKIT and SOUNDKIT[s.kit]) or s.id, "Master") end
            return
        end
    end
end

function Mail:Alert()
    MS.Anims.play(Config:Get("anim"), self:Target())
    self:PlaySound()
end

function Mail:Test() self:Alert() end

function Mail:Check()
    if self.mode == "off" then return end
    local now = state()
    local prev = self.last
    self.last = now
    if prev == false and now and GetTime() > self.armedAt then self:Alert() end
end

MS.OnReady(function()
    local f = mailFrame()
    Mail.frame = f
    if type(HasNewMail) == "function" then Mail.mode = "api"
    elseif f then Mail.mode = "frame"
    else Mail.mode = "off" end

    MS.On("PLAYER_ENTERING_WORLD", function()
        Mail.armedAt = GetTime() + 5
        if Mail.mode ~= "off" then Mail.last = state() end   -- pas « and state() or nil » : false deviendrait nil
    end)
    MS.On("UPDATE_PENDING_MAIL", function() Mail:Check() end)
    if Mail.mode == "frame" then
        hooksecurefunc(f, "Show", function() Mail:Check() end)
        hooksecurefunc(f, "Hide", function() Mail:Check() end)
    end
end)
