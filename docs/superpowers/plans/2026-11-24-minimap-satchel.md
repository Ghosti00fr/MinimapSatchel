# Minimap Satchel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Addon WoW Forever qui range toutes les icônes d'addons de la minimap dans un bouton-sac ▦, permet d'en sortir par glisser, colore le fond (sombre / classe) et anime l'icône courrier à l'arrivée du courrier.

**Architecture:** Espace de noms global `MinimapSatchel` (alias local `MS`), un fichier par rôle, modèle Cursor Aura (`C:\Users\klass\Projets\CursorAura`). Logique pure (calculs, état, filtres) séparée des appels d'API pour être testée hors jeu en LuaJIT avec un mock.

**Tech Stack:** Lua 5.1 (WoW), LuaJIT `C:\Users\klass\AppData\Local\Programs\LuaJIT\bin\luajit.exe` pour les tests, Python 3 pour pipeline (textures TGA, release).

**Spec:** `docs/superpowers/specs/2026-11-24-minimap-satchel-design.md`

## Global Constraints

- Racine projet : `C:\Users\klass\Projets\MinimapSatchel`. Dossier addon : `MinimapSatchel/`.
- `.toc` : `## Interface: 16001`, `## Title: Minimap Satchel`, `## Author: Ghosti`, `## Version: 0.0.1`, `## X-License: All Rights Reserved`, `## SavedVariables: MinimapSatchelDB`. Notes en enUS + frFR + esES + esMX.
- En-tête de chaque fichier : `-- Minimap Satchel © 2026 Ghosti. All Rights Reserved.` + `LICENSE.txt` (copie du texte de Cursor Aura, nom changé).
- Aucune dépendance externe. LibDBIcon seulement via `LibStub and LibStub("LibDBIcon-1.0", true)`.
- Toute API non confirmée sur Forever : testée avant appel, avec repli (`HasNewMail`, cadre courrier, `C_ClassColor`).
- Textures maison uniquement. Copier `soft.tga`, `ring.tga`, `star.tga` depuis `CursorAura/CursorAura/textures/`.
- Langues : `Locales/enUS.lua` (base), `frFR.lua`, `esES.lua` (esMX = esES). Aucune chaîne visible en dur hors locales.
- Aucune action de placement sur cadre protégé pendant `InCombatLockdown()` : file d'attente vidée à `PLAYER_REGEN_ENABLED`.
- Commits fréquents dans le dépôt local (`git init` à la tâche 1). `.gitignore` : `build/ dist/ *.zip .superpowers/ HANDOFF.md`.

## Review Focus

1. **Addon qui recrée / repositionne son bouton en boucle** (OnUpdate, rafraîchissement LibDBIcon) → l'icône reste dans le sac. Test : `t_placement` « SetPoint externe ignoré après Store ».
2. **`/reload` avec courrier déjà non lu** → aucune animation. Test : `t_mail` « état initial vrai ne déclenche pas ».
3. **Icône sortie, puis addon désinstallé** → l'entrée `out[id]` reste, aucune erreur au chargement. Test : `t_core` « out avec id inconnu ignoré sans erreur ».
4. **Glisser lâché ni sur ▦ ni près de la minimap** (au milieu de l'écran) → l'icône sort quand même à l'angle du lâcher (angle toujours défini). Test : `t_placement` « AngleFrom loin de la minimap ».
5. **Classe inconnue / `RAID_CLASS_COLORS` sans entrée** → repli fond sombre, pas d'erreur. Test : `t_satchel` « couleur classe inconnue = sombre ».

---

### Task 1: Squelette, Core, mock, tests

**Files:**
- Create: `MinimapSatchel/MinimapSatchel.toc`, `MinimapSatchel/LICENSE.txt`, `MinimapSatchel/Core.lua`, `MinimapSatchel/Locales/enUS.lua`, `frFR.lua`, `esES.lua`
- Create: `test/mock.lua` (partir de `CursorAura/test/mock.lua`, retirer spec/mouselook, ajouter ce qui suit), `test/run_all.sh` (copie adaptée), `test/t_core.lua`, `.gitignore`

**Interfaces:**
- Produces:
  - `MS.VERSION = "0.0.1"`, `MS.DB_VERSION = 1`, `MS.TEX = "Interface\\AddOns\\MinimapSatchel\\textures\\"`, `MS.L` (table locale, repli enUS).
  - `MS.Config:Init()` → crée/migre `MinimapSatchelDB`. `MS.Config:Get(key)`, `MS.Config:Set(key, value) -> bool` (refuse une valeur invalide, garde l'ancienne).
  - Défauts : `bg="dark"`, `group=false`, `columns=4`, `anim="bounce"`, `sound="default"`, `fade=false`, `satchelAngle=200`, `out={}` (id → angle), `ignored={}` (id → true), `blizzard={}` (nom → true).
  - Validateurs : `bg ∈ {dark,class}`, `columns ∈ 1..12` entier, `anim` = id enregistré ou `"none"` (vérifié via `MS.Anims` si présent, sinon accepté), angles nombres finis dans [-360, 360].
  - `MS.On(event, fn)` : un cadre d'événements partagé, plusieurs abonnés par événement.
  - Mock : `M.reset()`, `M.fire(event, ...)`, `M.combat` (pour `InCombatLockdown`), `M.newMail` (pour `HasNewMail`, `nil` = fonction absente), `M.minimapChildren` (liste pour `Minimap:GetChildren()`), `M.ldb` (table nom → bouton pour LibStub mock), `RAID_CLASS_COLORS` mock.

- [ ] **Step 1: Write failing tests `test/t_core.lua`**
  - `Init` sans DB → `Get("bg") == "dark"`, `Get("columns") == 4`, `Get("satchelAngle") == 200`.
  - `Set("bg","pink") == false` et `Get("bg") == "dark"`.
  - `Set("columns", 0) == false`, `Set("columns", 6) == true`.
  - DB existante `{version=1, out={Foo=90}}` → `Get("out").Foo == 90`, autres défauts complétés.
  - « out avec id inconnu ignoré sans erreur » : `out={Ghost=10}`, `Init()` ne lève rien.
  - Locale `frFR` → `MS.L.title == "Minimap Satchel"` et une clé présente seulement en enUS se replie.
- [ ] **Step 2: Run** `sh test/run_all.sh` → FAIL (Core absent).
- [ ] **Step 3: Implement** `.toc` (ordre : Locales, Core, Anims, Collector, Placement, Satchel, Mail, Options, Commands), `Core.lua`, locales (titre + libellés des options des tâches suivantes, ajoutés au fil des tâches).
- [ ] **Step 4: Run** `sh test/run_all.sh` → `TOUS LES TESTS OK`.
- [ ] **Step 5: Commit** `git init` puis `git add -A && git commit -m "feat: squelette Minimap Satchel, Core et tests"`.

### Task 2: Collector (détection)

**Files:** Create `MinimapSatchel/Collector.lua`, `test/t_collector.lua`

**Interfaces:**
- Consumes: `MS.Config`, `MS.On`.
- Produces:
  - `MS.Collector:IdFor(frame) -> string|nil` : nom LibDBIcon si le bouton vient de LibDBIcon, sinon `frame:GetName()` ; suffixe `%d+$` retiré si le nom sans suffixe est unique parmi les candidats ; `nil` si pas de nom.
  - `MS.Collector:IsCandidate(frame) -> bool` : `Button`, nommé, `IsShown()`, taille 16–40 px, pas exclu, pas `MS.Satchel.button`.
  - `MS.Collector:AddonFor(frame, id) -> string` : nom LibDBIcon, sinon préfixe du nom avant `_`, `MinimapButton`, `Minimap`, `Button` (le premier trouvé), sinon l'id.
  - `MS.Collector:Scan() -> { [id] = entry }` avec `entry = { id, frame, addon, origParent, blizzard=bool }` ; met à jour `MS.Collector.known` ; appelle `MS.Collector.onNew(entry)` pour chaque id nouveau ; ignore `Config.ignored[id]`.
  - `MS.Collector.EXCLUDE` (table nom → true) + `EXCLUDE_PATTERNS` (`"^HandyNotes"`, `"Pin"`, `"^GatherMate"`, `"^Minimap[A-Z]"` sauf les Blizzard optionnels).
  - `MS.Collector.BLIZZARD` : liste ordonnée de chemins candidats (`"MinimapCluster.IndicatorFrame.MailFrame"`, `"MiniMapMailFrame"`, `"GameTimeFrame"`, `"MinimapCluster.Tracking"`, `"MiniMapTracking"`, `"MinimapZoomIn"`, `"MinimapZoomOut"`, `"MinimapCluster.ZoomIn"`, `"MinimapCluster.ZoomOut"`, `"TimeManagerClockButton"`, `"MiniMapWorldMapButton"`) ; `MS.Collector:ResolveBlizzard() -> { {key, frame} }` seulement ceux qui existent. Pris par `Scan` seulement si `Config.blizzard[key]`.
  - Rescan : `PLAYER_LOGIN`, puis à +1 s, +3 s, +8 s (`C_Timer.After`), et à chaque `ADDON_LOADED` (débouncé 0,5 s).
- [ ] **Step 1: Write failing tests** : bouton LibDBIcon `LibDBIcon10_Auctionator` sous id `Auctionator` ; bouton maison `LedgerMinimapButton` pris, addon `Ledger` ; bouton sans nom ignoré ; `HandyNotesPin12` exclu ; `FooButton3` seul → id `FooButton` ; `FooButton1` + `FooButton2` → ids gardés tels quels ; id dans `ignored` absent du résultat ; `onNew` appelé une seule fois sur deux `Scan()` ; `MiniMapMailFrame` pris seulement si `blizzard["MiniMapMailFrame"]`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `Collector.lua`.
- [ ] **Step 4: Run** → OK.
- [ ] **Step 5: Commit** `feat: détection des icônes (LibDBIcon + scan)`.

### Task 3: Placement (ranger / sortir / verrou)

**Files:** Create `MinimapSatchel/Placement.lua`, `test/t_placement.lua`

**Interfaces:**
- Consumes: `entry` de Collector, `MS.Config`, `MS.Satchel.grid` et `MS.Satchel:Layout()` (produits par la tâche 4 ; bouchonnés dans `t_placement` en attendant).
- Produces:
  - `MS.Placement.EdgePoint(angleDeg, minimapWidth) -> x, y` : rayon `width/2 + 10`, même formule que `CursorAura/Minimap.lua` `Place()`.
  - `MS.Placement.AngleFrom(cx, cy, mx, my) -> deg` (`math.deg(math.atan2(cy-my, cx-mx))`, toujours défini).
  - `MS.Placement:Lock(frame)` : sauve `frame.SetPoint`/`ClearAllPoints`/`SetParent` d'origine dans `frame.__msOrig`, les remplace par des no-op par instance ; filet `hooksecurefunc(frame, "SetPoint", ...)` qui ré-applique notre ancrage via `C_Timer.After(0, ...)` si l'override a été écrasé. `MS.Placement:Unlock(frame)` rend les originaux.
  - `MS.Placement:Anchor(frame, parent, point, rel, relPoint, x, y)` : passe toujours par `__msOrig`.
  - `MS.Placement:Store(entry)` : `out[id]=nil`, re-parent vers `MS.Satchel.grid`, verrou, puis `MS.Satchel:Layout()`.
  - `MS.Placement:Release(entry, angleDeg)` : `out[id]=angle`, re-parent `Minimap`, ancrage `EdgePoint`, verrou (on garde la main sur la position).
  - `MS.Placement:Restore(entry)` : au chargement, `out[id]` → `Release`, sinon `Store`.
  - `MS.Placement:Drop(entry, overSatchel, cx, cy)` : `overSatchel` → `Store`, sinon `Release(entry, AngleFrom(cx, cy, Minimap:GetCenter()))`.
  - Combat : si `InCombatLockdown()`, l'appel est mis en file et rejoué à `PLAYER_REGEN_ENABLED`.
  - Glisser des icônes sorties : `OnDragStart`/`OnDragStop` remplacés pendant la gestion (rotation au bord pendant le drag, `Drop` au lâcher) ; originaux rendus à `Unlock`.
- [ ] **Step 1: Write failing tests** : `EdgePoint(0,140) == 80,0` ; `EdgePoint(90,140)` ≈ `0,80` ; `AngleFrom` loin de la minimap (cx=2000,cy=0 vs 100,100) renvoie un nombre fini ; « SetPoint externe ignoré après Store » (appel `frame:SetPoint("TOP")` après `Store` ne change pas `frame.point`) ; `Release(e, 45)` → `Config:Get("out")[id] == 45` et parent `Minimap` ; `Drop(e, true)` après `Release` → `out[id] == nil` ; en combat `Store` ne fait rien puis s'applique après `M.fire("PLAYER_REGEN_ENABLED")` ; `Unlock` rend le `SetPoint` d'origine.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → OK.
- [ ] **Step 5: Commit** `feat: placement, verrou SetPoint, file combat`.

### Task 4: Satchel (bouton ▦, grille, couleurs)

**Files:** Create `MinimapSatchel/Satchel.lua`, `test/t_satchel.lua`, `pipeline/draw_icons.py` (bouton ▦ 64×64 + logo 400×400, style de `CursorAura/pipeline/draw_logo.py`), `MinimapSatchel/textures/satchel.tga`

**Interfaces:**
- Consumes: Collector, Placement, Config.
- Produces:
  - `MS.Satchel.button` (`Button` nommé `MinimapSatchelButton`, parent `Minimap`, 31×31, angle `satchelAngle`, glisser = rotation au bord, clic = `Toggle`), `MS.Satchel.grid` (`Frame` `MinimapSatchelGrid`, ancré à côté du bouton, caché par défaut, fermé par clic ailleurs via `GLOBAL_MOUSE_DOWN` hors grille/bouton si l'événement existe, sinon Échap via `UISpecialFrames`).
  - `MS.Satchel:Toggle()`, `:Open()`, `:Close()`, `:IsOpen() -> bool`.
  - `MS.Satchel.Order(entries, group) -> array` : tri par `id` (insensible à la casse) ; si `group`, tri par `addon` puis `id`.
  - `MS.Satchel:Layout()` : icônes rangées (celles sans `out[id]`) en grille `columns` colonnes, cases 30 px, espacement 4, marge 7 ; taille de la grille ajustée ; si `group`, une petite étiquette d'addon quand ≥2 icônes ont le même addon.
  - `MS.Satchel.BgColor(bg, classFile) -> r, g, b, a` : `dark` → `0.04, 0.04, 0.05, 0.92` ; `class` → couleur `RAID_CLASS_COLORS[classFile]` (ou `C_ClassColor.GetClassColor`), alpha `0.85` ; classe inconnue → valeurs `dark`. `MS.Satchel:ApplyColors()` sur grille + fond du bouton.
  - Drag depuis la grille : `OnDragStart` → fantôme (texture de l'icône) suit le curseur ; `OnDragStop` → `MS.Placement:Drop(entry, MS.Satchel.button:IsMouseOver(), GetCursorPosition()/scale)`.
  - Fondu (`fade=true`) : alpha du bouton suit `Minimap:IsMouseOver()` comme Cursor Aura ; `fade=false` → alpha 1.
- [ ] **Step 1: Write failing tests** : `Order` sans groupe `{b,A,c}` → `A,b,c` ; avec groupe, addon d'abord ; `Toggle` deux fois → fermé ; `Layout` avec 6 icônes et 4 colonnes → hauteur de 2 rangées ; `BgColor("dark")` ; `BgColor("class","MAGE")` = couleur mock MAGE ; « couleur classe inconnue = sombre » `BgColor("class","NOPE")`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (+ `python pipeline/draw_icons.py`). **Step 4: Run** → OK.
- [ ] **Step 5: Commit** `feat: bouton-sac, grille, couleurs`.

### Task 5: Anims (registre + A/B/C)

**Files:** Create `MinimapSatchel/Anims.lua`, `test/t_anims.lua`, `pipeline/draw_envelope.py`, `MinimapSatchel/textures/envelope.tga`, copier `soft.tga`, `ring.tga`, `star.tga`

**Interfaces:**
- Produces:
  - `MS.Anims.register(id, def)` avec `def = { label = "anim_<id>" (clé locale), play = function(target) end }`, `MS.Anims.order` (ids dans l'ordre d'ajout), `MS.Anims.play(id, target) -> bool` (`false` si id inconnu, `"none"` ou target nil).
  - Ids v1 : `bounce`, `fly`, `shake`. Un cadre d'effet réutilisé par animation (pas de création à chaque courrier).
  - Timings (maquette `mail-anim-v2.html`) : `bounce` 0,9 s, sauts 18 px puis 8 px, halo `soft` doré `#FFD76A` 1,6 s ; `fly` enveloppe depuis le bas-gauche de l'écran vers la cible en 1,2 s, rotation -20°→10°, échelle 1,4→0,6, puis pop de la cible ×1,4 en 0,4 s ; `shake` 0,7 s, angles -18/15/-12/8/-4°, 5 étincelles `star` `#FFE9A0` sur 1 s.
  - Implémentation via un `OnUpdate` piloté par le temps (pas d'`AnimationGroup`, rotation de `Button` non garantie sur Forever : appliquer la rotation à une texture superposée).
- [ ] **Step 1: Write failing tests** : les 3 ids enregistrés dans l'ordre ; `play("nope", f) == false` ; `play("none", f) == false` ; `play("bounce", nil) == false` ; `play("bounce", f) == true` et, après simulation d'1 s d'`OnUpdate`, la cible est revenue à sa position d'origine.
- [ ] **Step 2–4:** Run FAIL → Implement → Run OK.
- [ ] **Step 5: Commit** `feat: animations courrier A/B/C`.

### Task 6: Mail (détection + cible + son)

**Files:** Create `MinimapSatchel/Mail.lua`, `test/t_mail.lua`

**Interfaces:**
- Consumes: `MS.Anims.play`, `MS.Collector:ResolveBlizzard()`, `MS.Config`.
- Produces:
  - `MS.Mail.mode` : `"api"` si `type(HasNewMail)=="function"`, sinon `"frame"` si cadre courrier trouvé, sinon `"off"`.
  - `MS.Mail:Check()` : lit l'état (`HasNewMail()` ou `mailFrame:IsShown()`), déclenche `MS.Mail:Alert()` seulement sur `false → true` et seulement si `GetTime() > armedAt`.
  - Armement : `armedAt = GetTime() + 5` à chaque `PLAYER_ENTERING_WORLD` ; l'état est lu sans déclencher pendant la fenêtre.
  - Événements : `UPDATE_PENDING_MAIL` → `Check()` ; en mode `frame`, `hooksecurefunc(mailFrame, "Show", Check)`.
  - `MS.Mail:Target() -> frame` : cadre courrier si présent, visible et pas dans le sac ; sinon `MS.Satchel.button`.
  - `MS.Mail:Alert()` : `MS.Anims.play(Config anim, Target())` + son.
  - `MS.Mail.SOUNDS` : `{ {key="default", kit=<id SoundKit>}, ... , {key="none"} }`, 4 sons du jeu (ids à valider en jeu, utiliser `SOUNDKIT.<NOM>` si la constante existe, sinon l'id numérique). `PlaySound(kit, "Master")`.
  - `MS.Mail:Test()` : `Alert()` sans condition (bouton « Tester »).
- [ ] **Step 1: Write failing tests** : « état initial vrai ne déclenche pas » (PEW puis newMail=true, Check à t=1) ; passage false→true à t=10 → 1 alerte ; 2ᵉ `UPDATE_PENDING_MAIL` avec true → toujours 1 ; true→false→true → 2 ; `HasNewMail` absent + pas de cadre → `mode=="off"` et aucune erreur ; `Target()` = bouton ▦ quand le cadre courrier est dans le sac ; `sound="none"` → `PlaySound` non appelé.
- [ ] **Step 2–4:** Run FAIL → Implement → Run OK.
- [ ] **Step 5: Commit** `feat: alerte courrier`.

### Task 7: Options + commandes

**Files:** Create `MinimapSatchel/Options.lua`, `MinimapSatchel/Commands.lua`, `test/t_commands.lua`

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces:
  - Panneau `MinimapSatchelOptions` maison (modèle `CursorAura/Options.lua`, Échap ferme), sections : Fond (Sombre / Couleur de classe) · Regrouper par addon · Colonnes (− / +, 1–12) · Fondu du bouton · Animation courrier (A/B/C/Aucune) + Son (liste) + « Tester » (grisés avec la ligne `L.mail_off` si `Mail.mode=="off"`) · Boutons Blizzard (une case par entrée de `ResolveBlizzard()`) · Liste des icônes détectées : état sortie/rangée (bouton bascule) et « ignorer ».
  - Clic droit sur ▦ = ouvrir le panneau.
  - `/satchel` → panneau ; `/satchel reset` → tout rangé (`out={}`), angle ▦ par défaut ; `/satchel test` → `Mail:Test()`.
  - Tout changement d'option → `Config:Set` puis `Satchel:ApplyColors()` / `Layout()` / rescan selon le cas.
- [ ] **Step 1: Write failing tests** : `/satchel reset` vide `out` ; `/satchel test` appelle `Anims.play` une fois ; commande inconnue imprime l'aide (`L.help`).
- [ ] **Step 2–4:** Run FAIL → Implement → Run OK.
- [ ] **Step 5: Commit** `feat: options et commandes`.

### Task 8: Livraison 0.0.1 + vault

**Files:** Create `pipeline/release.py` (copie de `CursorAura/pipeline/release.py`, `A = "MinimapSatchel"`, regex version sur `MS.VERSION    = "..."`), note vault `C:\Users\klass\vault claudi\03-Projets\Addon WoW - Minimap Satchel.md`

- [ ] **Step 1:** `python pipeline/release.py 0.0.1` → affiche `dist/MinimapSatchel-0.0.1.zip … -> D:\World of Warcraft\_forever_\Interface`. Ghosti installe lui-même.
- [ ] **Step 2:** Vérifier le zip : racine `MinimapSatchel/`, séparateurs `/`, contient `.toc`, `LICENSE.txt`, textures.
- [ ] **Step 3:** Note vault (date, liens `[[Addon WoW - Cursor Aura]]` `[[Addon WoW - Règles CurseForge]]`, décisions du design, preuves API, limites courrier, liste des vérifications en jeu du spec).
- [ ] **Step 4: Commit** `chore: release 0.0.1`.
