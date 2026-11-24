-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.
-- ============================================================
--  Minimap Satchel — Core.lua
--  Espace de noms, réglages (compte : MinimapSatchelDB), bus d'événements.
-- ============================================================

local MS = MinimapSatchel
MS.VERSION    = "0.0.2"
MS.DB_VERSION = 1
MS.PATH       = "Interface\\AddOns\\MinimapSatchel\\"
MS.TEX        = MS.PATH .. "textures\\"

local function isAngle(v) return type(v) == "number" and v == v and v >= -360 and v <= 360 end
local function isTable(v) return type(v) == "table" end
local function isBool(v) return type(v) == "boolean" end

MS.Config = {
    defaults = { bg = "dark", group = false, columns = 4, anim = "bounce", sound = "default",
                 fade = false, satchelAngle = 200 },
    tables = { "out", "ignored", "blizzard" },   -- out : id -> angle ; ignored / blizzard : clé -> true
    validators = {
        bg = function(v) return v == "dark" or v == "class" end,
        group = isBool,
        fade = isBool,
        columns = function(v) return type(v) == "number" and v % 1 == 0 and v >= 1 and v <= 12 end,
        anim = function(v)
            if type(v) ~= "string" then return false end
            if v == "none" or not MS.Anims then return true end
            return MS.Anims.defs[v] ~= nil
        end,
        sound = function(v) return type(v) == "string" end,
        satchelAngle = isAngle,
        out = isTable, ignored = isTable, blizzard = isTable,
    },
}
local Config = MS.Config

-- migrations futures : une étape par version, jamais de renommage brutal
function Config:Migrate(db)
    db.version = db.version or MS.DB_VERSION
end

function Config:Init()
    if type(MinimapSatchelDB) ~= "table" then MinimapSatchelDB = {} end
    local db = MinimapSatchelDB
    for k, v in pairs(self.defaults) do
        if db[k] == nil or not self.validators[k](db[k]) then db[k] = v end
    end
    for _, k in ipairs(self.tables) do
        if not isTable(db[k]) then db[k] = {} end
    end
    for id, a in pairs(db.out) do
        if not isAngle(a) then db.out[id] = nil end
    end
    self:Migrate(db)
    self.db = db
end

function Config:Get(k) return self.db and self.db[k] end

function Config:Set(k, v)
    if not self.db then return false end
    local check = self.validators[k]
    if check and not check(v) then return false end
    self.db[k] = v
    return true
end

-- ---- Bus d'événements (un seul cadre, plusieurs abonnés) ----
local bus = CreateFrame("Frame")
local subs = {}
bus:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(subs[event]) do fn(event, ...) end
end)
function MS.On(event, fn)
    if not subs[event] then subs[event] = {}; bus:RegisterEvent(event) end
    local list = subs[event]
    list[#list + 1] = fn
end

-- ---- Démarrage : Config:Init puis chaque module, au chargement de l'addon ----
local ready = {}
function MS.OnReady(fn) ready[#ready + 1] = fn end
MS.On("ADDON_LOADED", function(_, name)
    if name ~= "MinimapSatchel" or Config.db then return end
    Config:Init()
    for _, fn in ipairs(ready) do fn() end
end)
