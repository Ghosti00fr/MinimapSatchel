# Minimap Satchel — design

Date : 2026-11-24 · Auteur : Ghosti · Cible : WoW Forever (Interface 16001, base Retail modifiée)

## Intention

Les icônes d'addons encombrent le tour de la minimap. Minimap Satchel les range toutes, toutes seules, dans un sac (un bouton ▦ sur le bord de la minimap). Le joueur garde la main : il sort du sac, par glisser-déposer, les icônes qu'il veut voir en permanence autour de la minimap. Deux plus qui le distinguent des collecteurs existants (MBB Reborn, Minimap Button Stash, MinimapOrganizer…) : une animation + un son à l'arrivée du courrier, et un fond couleur de classe.

Destiné à CurseForge (règles : [[Addon WoW - Règles CurseForge]]). Nom choisi pour toucher le plus de monde : « Minimap » est le mot que les joueurs cherchent.

## Objectifs

1. Au chargement, ranger dans le sac toutes les icônes d'addons accrochées à la minimap, y compris celles d'addons chargés plus tard.
2. Bouton-sac ▦ sur le bord de la minimap, toujours visible, déplaçable par glisser le long du bord (angle sauvegardé).
3. Clic sur ▦ : la grille s'ouvre à côté. Re-clic ou clic ailleurs : elle se ferme.
4. Glisser une icône hors de la grille : elle se colle au bord de la minimap à l'angle du lâcher. Choix et angle retenus d'une session à l'autre.
5. Glisser une icône sortie sur ▦ : elle retourne dans le sac.
6. Fond sombre/noir par défaut (grille + bouton). Option : fond couleur de classe.
7. Option « regrouper par addon » : la grille trie les icônes par addon d'origine, pour repérer un addon qui pose deux icônes.
8. Courrier : à l'arrivée du courrier, animation **une seule fois** + son. Trois animations au choix dans les options (A par défaut) :
   - A. rebond + halo doré ;
   - B. lettre qui vole et entre dans l'icône, qui grossit d'un coup ;
   - C. secousse + étincelles.
   Maquettes validées : `.superpowers/brainstorm/…/mail-anim-v2.html` (scratchpad de la session du 2026-11-24).
9. L'animation se joue sur l'icône courrier de Blizzard (enveloppe au sceau rouge, en haut de la minimap). Si le courrier est rangé dans le sac, ou si son cadre est introuvable, elle se joue sur ▦.
10. Son au choix dans une petite liste de sons du jeu, avec « aucun ».

## Non-objectifs (v1)

- Boutons Blizzard (courrier, calendrier, suivi, zoom +/−, horloge…) : **pas rangés par défaut**. Une option par bouton permet de les mettre dans le sac pour qui le veut.
- Détecter les addons « qui font la même chose » : impossible de façon fiable, écarté.
- Animations courrier par classe (portail du mage, nuage de fumée du voleur, etc.) : **évolution prévue**, pas en v1. Le système d'animations est conçu pour les ajouter (voir Architecture).
- Pas de barre déroulante, pas de box libre à l'écran (formes B et C des maquettes écartées).

## Anti-objectifs (échec même si ça « marche »)

- Une icône qui ressort toute seule du sac, ou qui saute de position à chaque `/reload`.
- Une alerte courrier qui sonne à chaque connexion ou changement de zone.
- Casser l'icône d'un addon (clic, clic droit, infobulle, glisser propre à l'addon quand elle est dehors).
- Dépendre de Cursor Aura ou d'une bibliothèque à installer.

## Contraintes

- Forever, Interface `16001`. Toute API Retail non confirmée sur Forever est détectée à l'exécution, avec repli.
- Preuves API (2026-11-24, index wow-addon-dev, Forever 1.60.1.70707) :
  - `UPDATE_PENDING_MAIL` : déclaré (C_Mail). OK.
  - `HasNewMail()` : absent de l'index généré (global hors documentation), mais utilisé par 2 addons installés sur Forever → probablement présent. Vérifier en jeu (`/dump HasNewMail()`).
  - Cadre de l'icône courrier : nom inconnu sur Forever. Candidats : `MinimapCluster.IndicatorFrame.MailFrame` (Retail), `MiniMapMailFrame` (ancien client). Résolu à l'exécution ; repli sur ▦.
- All Rights Reserved (`.toc` `X-License` + `LICENSE.txt`), comme les autres addons de Ghosti.
- Langues : enUS, frFR, esES (modèle Cursor Aura).
- Textures maison uniquement (reprises de Cursor Aura, qui sont à Ghosti, + nouvelles via pipeline Python).

## Approches considérées

| Approche | Pour | Contre |
|---|---|---|
| 1. LibDBIcon seul | Fiable, liste propre | Rate les icônes maison (Ledger, Cursor Aura…) → contraire à « tous les addons » |
| 2. Scan des enfants de la minimap seul | Attrape tout | Addons qui se repositionnent, faux positifs (épingles de carte) |
| **3. Mélange (choisi par Ghosti)** | Couvre tout, cas fréquent propre | Un peu plus de code ; un addon exotique pourra demander un correctif |

Choix : **3**. LibDBIcon (via `LibStub`, si présent) pour ses boutons ; puis scan de `Minimap` et `MinimapBackdrop` pour les autres boutons non Blizzard, avec liste d'exclusion. Pour une icône prise en charge (rangée ou sortie), Minimap Satchel gère sa position et neutralise les repositionnements de l'addon d'origine.

## Architecture (fichiers)

Modèle Cursor Aura (un fichier = un rôle, tests LuaJIT hors jeu avec `test/mock.lua`).

```
MinimapSatchel/
  MinimapSatchel.toc
  LICENSE.txt
  Locales/enUS.lua frFR.lua esES.lua
  Core.lua        -- espace de noms, config (SavedVariables), migration
  Collector.lua   -- détection : LibDBIcon + scan, exclusions, nouveaux addons
  Satchel.lua     -- bouton ▦ + grille, ouverture/fermeture, couleurs
  Placement.lua   -- glisser dedans/dehors, angle, blocage des SetPoint d'origine
  Mail.lua        -- détection courrier, choix de la cible, lancement anim + son
  Anims.lua       -- registre d'animations : A, B, C (fiches de données)
  Options.lua     -- panneau maison (comme Cursor Aura), /satchel
  textures/       -- soft, ring, star (Cursor Aura), envelope (nouvelle), logo
pipeline/ draw_envelope.py, draw_logo.py, release.py, cf_upload.py
test/ mock.lua, t_*.lua, run_all.sh
```

### Détection (Collector)

- Candidats : boutons LibDBIcon (`LibStub("LibDBIcon-1.0", true)`, liste de ses boutons) + enfants de `Minimap` / `MinimapBackdrop` qui sont des `Button` nommés, visibles, de taille d'icône, non Blizzard.
- Exclusions : liste fixe (cadres Blizzard connus, épingles de carte, ▦ lui-même) + motifs de nom.
- Rescan : à `PLAYER_LOGIN`, puis quelques passes différées (addons qui créent leur icône tard), puis à `ADDON_LOADED`.
- Addon d'origine d'un bouton : nom LibDBIcon, sinon préfixe du nom du cadre (sert au regroupement).
- Identifiant stable : nom LibDBIcon si présent, sinon nom global du cadre. Un nom qui se termine par un compteur (`…%d+$`) est normalisé sans le compteur s'il est unique. Un bouton sans nom global n'est **pas** pris : on le laisse en place plutôt que de risquer qu'il saute à chaque `/reload`.

### Placement

- Rangée : le bouton est re-parenté dans la grille, taille uniforme, ordre stable (alphabétique ou par addon).
- Sortie : re-parenté sur `Minimap`, posé sur le bord à l'angle sauvegardé (formule de `CursorAura/Minimap.lua`).
- Re-parentage : pratique standard des collecteurs (MBB & co.). Les boutons de minimap ne sont pas des cadres protégés. Le parent d'origine est mémorisé ; on le rend quand le bouton sort.
- Blocage : après notre `SetPoint`, les appels `SetPoint`/`ClearAllPoints` de l'addon d'origine sont ignorés tant que nous gérons le bouton. Override **par instance** (champ du bouton, pas la métatable globale), nos appels passent par les originaux sauvegardés. Si un addon réécrase l'override, filet : `hooksecurefunc` sur `SetPoint` du bouton → réancrage au cadre suivant. Jamais appliqué en combat sur un cadre protégé (`InCombatLockdown`, file d'attente jusqu'à `PLAYER_REGEN_ENABLED`).
- Glisser dehors : depuis la grille, drag → fantôme suit la souris → lâcher hors de la grille = sortie à l'angle du lâcher ; lâcher sur ▦ = retour au sac.
- Une icône sortie garde son propre comportement de clic ; son glisser natif est remplacé par le nôtre (rotation autour de la minimap + retour au sac).

### Courrier (Mail)

- Écoute `UPDATE_PENDING_MAIL`. Garde l'état précédent de `HasNewMail()`.
- Déclenche **seulement** au passage `false → true`.
- Connexion / `/reload` / changement de zone : l'état initial est lu sans déclencher (fenêtre de quelques secondes après `PLAYER_ENTERING_WORLD`).
- Limite connue : une 2ᵉ lettre alors qu'il y a déjà du courrier non lu ne déclenche rien (l'API ne le signale pas).
- Cible : cadre courrier Blizzard s'il est trouvé et hors du sac, sinon ▦.
- Repli si `HasNewMail` est absent : passage caché → affiché du cadre courrier Blizzard (Blizzard l'affiche quand du courrier attend). Si ni l'un ni l'autre n'existe : fonction courrier désactivée, option grisée avec une ligne d'explication. Le reste de l'addon marche.

### Animations (Anims)

- Registre : `Anims.register(id, { name, play(target) })`. v1 : `bounce` (A), `fly` (B), `shake` (C).
- Option « animation » = id. Ajouter une animation de classe plus tard = un fichier qui appelle `register` + une entrée « Selon ma classe ».
- Textures : halo `soft`/`ring`, étincelles `star`, enveloppe `envelope`.

### Couleurs

- Fond sombre : noir ~92 % d'opacité, liseré gris.
- Couleur de classe : `RAID_CLASS_COLORS[classe]` (repli `C_ClassColor` si présent), même opacité.

### Options (panneau maison + `/satchel`)

- Fond : Sombre / Couleur de classe.
- Regrouper par addon : oui/non.
- Colonnes de la grille (défaut 4).
- Animation courrier : A / B / C / aucune. Son : liste / aucun. Bouton « Tester ».
- Boutons Blizzard : une case par bouton (off par défaut).
- Fondu du bouton ▦ (visible seulement souris sur la minimap) : off par défaut.
- Liste des icônes détectées, avec « sortie / rangée » et « ignorer » (pour un faux positif).

### Données sauvegardées

`MinimapSatchelDB` (compte, `SavedVariables`) : `out[nomBouton] = angle`, `ignored[nomBouton] = true`, `satchelAngle`, options. Version de schéma pour migrer sans casser.

## Décidé par Ghosti

- Rangement auto de tout + sortie manuelle par glisser (2026-11-24).
- Forme A, bouton-sac.
- Fond sombre par défaut, option couleur de classe.
- Pas de boutons Blizzard par défaut, option pour ceux qui veulent.
- Courrier : animation une seule fois + son, les 3 animations au choix.
- Détection : approche 3 (mélange).
- Nom : Minimap Satchel.
- Plus tard : animations par classe.

## Choix de Claude (à valider)

- ▦ toujours visible, fondu en option.
- Animation A par défaut.
- Données au niveau du compte, pas du personnage (mêmes addons sur tous les persos).
- Option « regrouper par addon » = sens retenu pour « options en double ».
- Panneau d'options maison, pas l'API Settings (cohérent avec Cursor Aura, API Settings incertaine sur Forever).
- Courrier sans `HasNewMail` : repli sur l'affichage du cadre courrier, sinon fonction désactivée.
- Re-parentage dans la grille + override de `SetPoint` par instance, filet `hooksecurefunc`.
- Bouton sans nom global : laissé autour de la minimap, pas rangé.

## Laissé au builder

- Liste exacte des exclusions Blizzard, à établir en jeu.
- Sons du jeu proposés (ids SoundKit à valider en jeu sur Forever).
- Rendu des animations (timings des maquettes comme point de départ).
- Logo / avatar 400×400.

## Vérifications en jeu (Ghosti)

1. `/dump HasNewMail()` renvoie un booléen.
2. Toutes les icônes d'addons vont dans le sac ; Ledger et Cursor Aura compris.
3. Sortir / ranger une icône, `/reload` : l'état et l'angle tiennent.
4. Se faire envoyer un courrier : une animation + son, pas à la reconnexion suivante.
5. Couleur de classe sur 2 classes.
