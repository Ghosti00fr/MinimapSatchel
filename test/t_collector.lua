local M = dofile("test/mock.lua")

local function setup()
    M.reset(); local MS = M.load({ "Core", "Collector" }); MS.Config:Init(); return MS
end

-- LibDBIcon : id = nom LibDBIcon
local MS = setup()
local auc = M.button("LibDBIcon10_Auctionator")
M.ldb = { Auctionator = auc }
local r = MS.Collector:Scan()
ok(r.Auctionator and r.Auctionator.frame == auc, "bouton LibDBIcon pris sous son nom LibDBIcon")
ok(r.Auctionator.addon == "Auctionator", "addon d'origine LibDBIcon")
ok(r.LibDBIcon10_Auctionator == nil, "pas de doublon par le scan de la minimap")
ok(r.Auctionator.origParent == Minimap, "parent d'origine mémorisé")

-- bouton maison
MS = setup()
local led = M.button("LedgerMinimapButton")
r = MS.Collector:Scan()
ok(r.LedgerMinimapButton and r.LedgerMinimapButton.addon == "Ledger", "bouton maison pris, addon Ledger")
local ca = M.button("CursorAuraMinimapButton")
r = MS.Collector:Scan()
ok(r.CursorAuraMinimapButton.addon == "CursorAura", "addon CursorAura déduit du nom")
local under = M.button("TSM_MinimapButton")
r = MS.Collector:Scan()
ok(r.TSM_MinimapButton.addon == "TSM", "préfixe avant _ = addon")

-- bouton sous MinimapBackdrop
MS = setup()
M.button("FooIcon", MinimapBackdrop)
ok(MS.Collector:Scan().FooIcon ~= nil, "enfant de MinimapBackdrop pris")

-- refus
MS = setup()
M.button(nil)
M.button("HandyNotesPin12")
M.button("GatherMateNode1")
M.button("BigThing", Minimap, 120)
local hidden = M.button("HiddenIcon"); hidden.shown = false
local f = CreateFrame("Frame", "NotAButton", Minimap); f.w, f.h = 31, 31; Minimap.children[#Minimap.children + 1] = f
M.button("MinimapZoomIn"); M.button("QueueStatusMinimapButton")
M.button("MinimapButton_Foo")
r = MS.Collector:Scan()
local n = 0; for _ in pairs(r) do n = n + 1 end
ok(r.HandyNotesPin12 == nil, "épingle HandyNotes exclue")
ok(r.GatherMateNode1 == nil, "nœud GatherMate exclu")
ok(r.BigThing == nil, "cadre trop grand exclu")
ok(r.HiddenIcon == nil, "bouton caché exclu")
ok(r.NotAButton == nil, "Frame non Button exclu")
ok(r.MinimapZoomIn == nil and r.QueueStatusMinimapButton == nil, "boutons Blizzard exclus par défaut")
ok(r.MinimapButton_Foo ~= nil, "nom d'addon commençant par Minimap accepté")
ok(n == 1, "bouton sans nom ignoré (seul MinimapButton_Foo pris)")

-- suffixe compteur
MS = setup()
M.button("FooButton3")
r = MS.Collector:Scan()
ok(r.FooButton and r.FooButton3 == nil, "compteur retiré si nom de base unique")
MS = setup()
M.button("BarButton1"); M.button("BarButton2")
r = MS.Collector:Scan()
ok(r.BarButton1 and r.BarButton2 and r.BarButton == nil, "compteurs gardés si plusieurs")

-- ignorés, onNew une seule fois
MS = setup()
M.button("SkipMe"); M.button("KeepMe")
MS.Config:Get("ignored").SkipMe = true
local news = 0
MS.Collector.onNew = function() news = news + 1 end
r = MS.Collector:Scan()
ok(r.SkipMe == nil and r.KeepMe ~= nil, "id ignoré absent")
MS.Collector:Scan()
ok(news == 1, "onNew appelé une seule fois sur deux Scan")
ok(MS.Collector.known.KeepMe ~= nil, "known tenu à jour")
-- un bouton connu reste connu même caché ensuite (rangé dans le sac)
KeepMe.shown = false
ok(MS.Collector:Scan().KeepMe ~= nil, "bouton connu gardé même caché")

-- boutons Blizzard en option
MS = setup()
MiniMapMailFrame = CreateFrame("Frame", "MiniMapMailFrame", Minimap); MiniMapMailFrame.w, MiniMapMailFrame.h = 33, 33
MinimapCluster = { IndicatorFrame = { MailFrame = nil } }
local res = MS.Collector:ResolveBlizzard()
ok(#res == 1 and res[1].key == "MiniMapMailFrame", "ResolveBlizzard : seulement les cadres existants")
ok(MS.Collector:Scan().MiniMapMailFrame == nil, "courrier Blizzard non pris par défaut")
MS.Config:Get("blizzard").MiniMapMailFrame = true
local e = MS.Collector:Scan().MiniMapMailFrame
ok(e and e.blizzard == true and e.addon == "Blizzard", "courrier Blizzard pris si l'option est cochée")
local mf = CreateFrame("Frame", nil, Minimap)
MinimapCluster.IndicatorFrame.MailFrame = mf
res = MS.Collector:ResolveBlizzard()
ok(res[1].key == "MinimapCluster.IndicatorFrame.MailFrame" and res[1].frame == mf, "chemin Retail résolu en premier")

-- rescans programmés
MS = setup()
MS.Collector:Start()
M.fire("PLAYER_LOGIN")
M.button("LateIcon")
M.advance(1.1)
ok(MS.Collector.known.LateIcon ~= nil, "rescan différé après PLAYER_LOGIN")
M.button("AfterLoad")
M.fire("ADDON_LOADED", "Other")
ok(MS.Collector.known.AfterLoad == nil, "ADDON_LOADED débouncé")
M.advance(0.6)
ok(MS.Collector.known.AfterLoad ~= nil, "rescan après ADDON_LOADED")
