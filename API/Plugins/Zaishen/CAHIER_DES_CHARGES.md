# Zaishen — cahier des charges

IA de combat autonome pour GwAu3, successeur de UtilityAI.
Version 0.2 — 13/11/2026 — statut : validé pour démarrer le développement (nom retenu : Zaishen).

> **Zaishen** : l'ordre qui entraîne les combattants de la Tyrie, de Cantha et d'Elona.
> Préfixe du code : `ZS_`. Dossier : `API/Plugins/Zaishen/`.

---

## 1. Objectif

Chaque compte doit **jouer seul, au moins aussi bien qu'un héros du jeu** : connaître sa barre,
lancer le bon sort sur la bonne cible, avec la bonne arme, au bon moment, et réagir à ce que font
les ennemis et les alliés.

Concrètement, pour un compte donné, Zaishen doit à chaque instant répondre à :
**« quelle action rapporte le plus maintenant ? »** — lancer un skill (lequel, sur qui, avec quel
set d'armes), attaquer, se déplacer, ou attendre.

### Ce que « aussi bien qu'un héros » veut dire

| Capacité | Héros du jeu | Exigence Zaishen |
|---|---|---|
| Soigner l'allié le plus en danger | oui | oui, en tenant compte des soins déjà en route |
| Interrompre un sort ennemi | oui, souvent tard | oui, en visant la fenêtre d'incantation réelle |
| Retirer hexes et conditions | oui | oui, en priorisant les hexes dangereux |
| Entretenir enchantements et esprits | oui | oui, renouvellement juste avant expiration |
| Ressusciter | oui | oui, hors danger immédiat si possible |
| Enchaîner les combos (assassin, adrénaline) | moyen | oui, chaîne lead → off-hand → dual |
| Gérer l'énergie | moyen | oui, réserve pour les skills d'urgence |
| Changer d'arme selon le skill | non | oui (déjà présent dans UtilityAI, à fiabiliser) |
| Éviter de doubler un interrupt ou un soin avec un autre compte | non | oui (coordination multi-comptes) |

---

## 2. Périmètre

**Dans le périmètre**
- PvE, mode normal et difficile, toutes campagnes.
- Le personnage joueur de chaque compte (les héros du jeu restent gérés par le jeu).
- Combat : choix et lancement des skills, auto-attaque, choix de la cible, sets d'armes.
- Déplacement **tactique** pendant le combat (portée, sortie d'AoE, rapprochement d'un allié à
  soigner ou d'un cadavre à exploiter).
- Coordination entre les comptes d'un même groupe tournant sur la même machine.
- Compatibilité avec les bots existants (GwFarmer, Follower, Pathfinder).

**Hors périmètre**
- PvP.
- Navigation entre zones, loot, vente, quêtes (restent dans les bots).
- Construction automatique de builds.
- Modification de UtilityAI : il reste en place jusqu'à la migration (seuls ses bugs bloquants
  peuvent être corrigés à part).

---

## 3. Constat sur l'existant (UtilityAI)

Détail et références : `.claude/skills/gwau3-utilityai/references/refactor-notes.md`.

| # | Problème | Conséquence | Réponse dans Zaishen |
|---|---|---|---|
| 1 | Aucun score : le premier slot dont la condition est vraie part | une bonne action en slot 6 perd contre une action médiocre en slot 2 | décision par score (§5.4) |
| 2 | ~4 600 fonctions `BestTarget_` / `CanUse_` écrites à la main, deux `Switch` de 2 300 cas | maintenance lourde, 46 skills ignorés en silence, bugs copiés-collés dans 9 fichiers | skills décrits par des données, comportements par famille (§5.2) |
| 3 | Les caches sont relus jusqu'à 8 fois par passe | lenteur, réactions tardives | une seule perception par tick (§5.1) |
| 4 | Le cast est bloquant (attente jusqu'à 5 s) | aucune réaction pendant une incantation | exécution par machine à états (§5.6) |
| 5 | État global implicite (`$g_i_BestTarget` lu par toutes les conditions) | impossible de comparer plusieurs cibles | évaluation sans état global, cible passée en paramètre |
| 6 | Règles qui lisent la mémoire, bougent ou dorment elles-mêmes | non testable hors jeu, effets de bord | règles pures sur un instantané (§6) |
| 7 | Aucun test, aucun journal des décisions | impossible de savoir pourquoi le bot a fait un choix | journal des décisions et banc d'essai hors jeu (§5.12, §8) |
| 8 | Aucune coordination entre comptes | deux comptes interrompent la même cible ou soignent le même allié | tableau partagé (§5.8) |

**À conserver** (éprouvé) : la lecture groupée des agents et effets (`UtilityAI_AgentCache`,
`UtilityAI_EffectsCache`), le calcul du coût réel en énergie de `UAI_CanUse`, la lecture des mods
d'armes (`UtilityAI_WeaponSets`), le savoir métier contenu dans les `CanUse_*` / `BestTarget_*`
(à transformer en données, pas à recopier).

---

## 4. Principes

1. **Percevoir une fois, décider, agir** : un tick = un instantané figé → une décision → une action.
2. **Noter, pas filtrer** : chaque action candidate reçoit un score ; on prend le meilleur.
3. **Données plutôt que code** : un skill est décrit par des données (famille, cibles, conditions,
   poids). Le code ne contient que les comportements génériques et les quelques cas vraiment
   particuliers.
4. **Rien ne bloque** : aucune fonction de décision ne dort ni n'attend ; l'exécution avance d'un
   pas par tick.
5. **Tout skill de la barre a un comportement** : à défaut de description dédiée, un comportement
   par famille s'applique, et c'est signalé dans le rapport de couverture.
6. **Expliquer chaque décision** : on doit pouvoir lire pourquoi une action a gagné.
7. **Respecter GwAu3** : AutoIt 3.3.16.1 32 bits, conventions de nommage de la librairie
   (`$g_`, `$l_`, `$a_`, types), pas de nouvelle DLL.

---

## 5. Exigences fonctionnelles

### 5.1 Perception

- **F1.1** — Un instantané (`snapshot`) par tick : joueur, agents dans un rayon configurable
  (défaut 2 500), effets / bonds / effets visibles, barre de skills (recharges, adrénaline),
  sets d'armes, groupe (membres, héros, cible appelée), carte (type, ID).
- **F1.2** — Lecture groupée (`Memory_ReadArrayStruct` & co.) ; aucune lecture mémoire en dehors
  de la phase de perception.
- **F1.3** — Données dérivées calculées une fois par tick : distances, alliés/ennemis vivants et
  morts, menace par ennemi (incantation en cours, attaque en cours, cible visée), vie manquante
  par allié, nombre d'ennemis autour de chaque agent (pour les AoE).
- **F1.4** — Suivi entre ticks de ce que la mémoire ne donne pas directement : début d'incantation
  des ennemis (pour estimer le temps restant), derniers dégâts reçus, skill récemment lancé par
  nous (pour ne pas le relancer pendant la latence).
- **F1.5** — Option : utiliser le plugin **StoC** pour capter les messages serveur
  d'activation de skill ennemi (timing d'interruption précis) et de fin d'effet. À évaluer en
  phase 3 (contrainte : un seul lecteur de l'anneau StoC).

### 5.2 Connaissance des skills

- **F2.1** — Chaque skill est rattaché à une **famille de comportement** (ex. : soin ciblé, soin
  de groupe, protection, interruption, retrait d'hex, retrait de condition, dégâts ciblés,
  dégâts de zone, hex offensif, maintien d'enchantement, posture, esprit, invocation de minion,
  résurrection, gain d'énergie, attaque d'adrénaline, chaîne d'assassin, cri de groupe,
  arme/sort d'arme, ward, well, piège, bundle).
- **F2.2** — La famille par défaut est **déduite des données du jeu** (`$GC_AMX2_SKILL_DATA` :
  type, cible, flags spéciaux, effets, conditions, combo, AoE) ; une description manuelle la
  remplace quand c'est nécessaire.
- **F2.3** — Une description de skill contient au plus : famille, cibles admises, conditions
  d'usage (prérequis : cible hexée, en train d'attaquer, sous 50 % de vie, condition requise…),
  paramètres de la famille (seuils, rayon d'AoE), poids, et un éventuel *hook* AutoIt pour les
  cas impossibles à décrire.
- **F2.4** — **Couverture** : un rapport liste, pour chaque skill, s'il a une description dédiée,
  seulement sa famille par défaut, ou rien. Objectif : 100 % des skills ont au moins une famille.
- **F2.5** — Réutiliser le savoir des `CanUse_*` / `BestTarget_*` existants : un script
  d'extraction propose une description pour chaque skill à partir du code UtilityAI, relue à la main.
- **F2.6** — Valeurs dépendant des attributs (durée, soin, dégâts) calculées avec le niveau
  d'attribut réel (`Skill_GetSkillArg`, `Effect_GetEffectArg`).

#### Stockage et classement des skills : 4 couches

Chaque couche ne fait que compléter ou remplacer la précédente ; aucune n'est écrite à la main
pour les ~3 400 skills.

| Couche | Fichier | Écrit par | Contenu |
|---|---|---|---|
| 1. Données du jeu | `API/Constants/GwAu3_Const_Skill.au3` (`$GC_AMX2_SKILL_DATA`, existant) | GwAu3 | type, cible, coûts, temps, flags, combo, AoE |
| 2. Classement généré | `Knowledge/Generated/ZS_SkillTable.au3` | script `Tools/ZS_GenerateSkillTable` | une ligne par skill : famille, cibles admises, paramètres par défaut, origine du classement (règle ou extraction UtilityAI) |
| 3. Descriptions dédiées | `Knowledge/ZS_SkillDefs_<Profession>.au3` | à la main (relu) | seulement les skills dont la famille ne suffit pas : prérequis, seuils, poids, *hook* éventuel |
| 4. Surcharges par compte | `<config du compte>.ini`, section `[Skills]` | l'utilisateur | ajustement d'un skill pour un build précis |

Exemple de ligne générée (couche 2) :

```autoit
; ID    Famille                 Cibles          Paramètres                     Origine
[  5,   $GC_ZS_FAM_INTERRUPT,   "Enemy",        "Interrupt=Spell|Chant",        "uai:CanUse_PowerBlock"], _
[ 281,  $GC_ZS_FAM_HEAL_SINGLE, "Ally|Self",    "",                             "rule:Healing+Target=Ally"], _
```

Exemple de description dédiée (couche 3) :

```autoit
ZS_DefineSkill($GC_I_SKILL_ID_PROTECTIVE_SPIRIT, $GC_ZS_FAM_PROTECT, "Ally|Self", _
	"Threat>=0.6|NotIfEffect=Protective Spirit", 1.2)
```

Au chargement d'une zone, seules les 8 lignes de la barre sont résolues (couche 4 > 3 > 2 > 1) et
mises en cache : le coût en combat est nul. Le générateur et le rapport de couverture lisent les
mêmes fichiers, donc un skill ne peut plus être référencé sans exister.

### 5.3 Ciblage

- **F3.1** — Pour chaque skill utilisable, générer les **cibles candidates** admises par sa
  famille (soi, allié, ennemi, cadavre, position au sol pour les AoE/wards).
- **F3.2** — Chaque couple (skill, cible) est noté séparément : un même skill peut viser
  plusieurs cibles et la meilleure gagne.
- **F3.3** — Respect de la cible appelée par le groupe ou le leader (mode *suivre*) et des
  priorités / exclusions passées par le bot (équivalent de `$a_v_PlayerNumber` actuel).
- **F3.4** — AoE : choisir le centre qui maximise les ennemis touchés en minimisant les alliés
  touchés (pour les sorts qui blessent tout le monde).
- **F3.5** — Portée : une cible hors de portée reste candidate si le déplacement nécessaire est
  court ; le coût du déplacement entre dans le score.

### 5.4 Décision (cœur « utility AI »)

- **F4.1** — Score d'une action = **produit de considérations** normalisées entre 0 et 1, chacune
  passée par une **courbe de réponse** (linéaire, quadratique, logistique, seuil…), multiplié par
  le poids de la famille et du skill. Exemple pour un soin ciblé : vie manquante de la cible
  (courbe forte), menace sur la cible, énergie après cast (pénalité si sous la réserve), soins
  déjà en route vers elle.
- **F4.2** — **Vetos** avant le score : pas assez d'énergie / adrénaline / vie, en recharge,
  cible invalide, hex ou condition qui interdit l'action (équivalents des `Anti_*` : Backfire,
  Spiteful Spirit, Empathy, Diversion…, regroupés en une table).
- **F4.3** — **Bandes de priorité** : survie du groupe > résurrection > interruption critique >
  soin d'urgence > retrait d'hex/condition dangereux > maintien des buffs > dégâts et contrôle.
  Une action d'une bande supérieure au-dessus de son seuil gagne toujours.
- **F4.4** — **Réserve d'énergie** : garder assez d'énergie pour le skill d'urgence le plus
  cher de la barre (soin, rez), sauf si l'action courante est elle-même une urgence.
- **F4.5** — **Inertie** : bonus léger à l'action en cours et à la cible actuelle pour éviter
  d'osciller d'un tick à l'autre.
- **F4.6** — Auto-attaque : action candidate comme les autres (score faible mais non nul),
  interdite par les vetos (Ineptitude, Empathy, Spirit Shackles…).
- **F4.7** — Le style de combat (finisher / pressure de UtilityAI) devient un jeu de poids,
  pas un branchement dans le code.

### 5.5 Timing

- **F5.1** — **Interruption** : lancer seulement si l'incantation ennemie restante est supérieure
  à notre temps d'activation + latence (ping) + marge ; prioriser selon la dangerosité du skill
  ennemi (table : rez, soins, hexes majeurs…).
- **F5.2** — **Renouvellement** : relancer un enchantement, une posture, un esprit ou un glyphe
  juste avant son expiration (temps restant < activation + latence + marge), jamais avant.
- **F5.3** — **Combos** : respecter les chaînes lead → off-hand → dual et les prérequis
  (cible renversée, en train de saigner, hexée…). Préparer la condition requise si un autre skill
  de la barre peut la poser.
- **F5.4** — **Adrénaline** : ne pas gaspiller une barre pleine ; ordre de dépense configurable.
- **F5.5** — **Aftercast et file** : ne pas envoyer d'action pendant l'aftercast ; tenir compte
  du skill déjà en file côté jeu (`Queued`).

### 5.6 Exécution non bloquante

- **F6.1** — Machine à états par compte : `Idle → (Weapon swap) → (Approach) → Casting →
  Aftercast → Idle`, avancée d'un pas par tick.
- **F6.2** — Confirmation par l'état réel (skill en incantation, recharge démarrée) et non par
  une attente fixe ; nouvel essai limité si la commande est perdue.
- **F6.3** — Annulation : cible morte (sauf rez), cible hors de portée, action devenue
  nettement moins bonne (seuil configurable), danger immédiat (fuir une AoE).
- **F6.4** — Un tick ne dure jamais plus que son budget (§7) ; aucune `Sleep` hors de la boucle
  principale.

### 5.7 Armes

- **F7.1** — Reprendre la lecture des 4 sets et de leurs mods (UtilityAI_WeaponSets).
- **F7.2** — Le changement de set est une **action notée** : gain du set pour le skill choisi
  (exigence d'arme, +20 % enchant, HCT/HSR, 40/40, bouclier, vampirique/zealous…) moins le coût
  du changement.
- **F7.3** — Hystérésis : pas de va-et-vient entre deux sets sur deux ticks consécutifs.
- **F7.4** — Set par défaut configurable (défensif hors action, offensif en attaque).

### 5.8 Coordination multi-comptes (mémoire partagée)

Rien de tel n'existe aujourd'hui (le Follower ne reçoit que des commandes `WM_COPYDATA` à sens
unique du FollowerManager). La mémoire partagée Windows est disponible dans la bibliothèque
standard d'AutoIt (`WinAPIFiles.au3`, `WinAPIProc.au3`) : **aucune DLL à ajouter**.

- **F8.1** — Un bloc nommé par groupe : `Local\Zaishen_<CléDeGroupe>` (la clé est le nom du
  personnage leader, connu de tous les suiveurs). Le premier compte qui arrive le crée
  (`_WinAPI_CreateFileMapping`), les suivants l'ouvrent (`_WinAPI_OpenFileMapping`) ; Windows le
  libère quand le dernier compte le ferme. Lu et écrit via `_WinAPI_MapViewOfFile` +
  `DllStructCreate(tag, pointeur)`.
- **F8.2** — Disposition (~16 Ko, versionnée) :

  | Zone | Contenu | Qui écrit |
  |---|---|---|
  | En-tête | signature, version du format, compteur de séquence | créateur |
  | Canal leader | phase, point de destination, cible appelée, position de regroupement, ordres (§5.11) | leader uniquement |
  | 8 slots compte | PID, agent ID, nom, rôle, vie, énergie, action et cible en cours, battement de cœur | chaque compte dans **son** slot |
  | Réservations (32) | type (interrupt, soin, rez, retrait d'hex…), cible, propriétaire, expiration | tous, sous verrou |

- **F8.3** — Concurrence : chaque compte n'écrit que dans son slot (pas de conflit) ; le canal
  leader n'a qu'un écrivain ; seules les réservations passent par un mutex nommé
  `Local\Zaishen_<Clé>_Lock` tenu quelques microsecondes. Les lectures se font sans verrou avec un
  compteur de séquence (relire si le compteur a changé pendant la lecture).
- **F8.4** — Battement de cœur : un slot non mis à jour depuis 2 s est considéré comme absent ;
  ses réservations expirent d'elles-mêmes (durée de vie ≤ 1,5 s).
- **F8.5** — Une réservation active d'un autre compte baisse fortement le score de la même action
  sur la même cible.
- **F8.6** — Fonctionnement dégradé : si le bloc est absent ou si un compte n'utilise pas
  Zaishen, chaque compte joue seul.
- **F8.7** — Limite : même machine et même session Windows. Plusieurs machines (TCP) : hors
  périmètre de cette version.

### 5.9 Rôles, comportements et configuration

- **F9.1** — **Rôle** déduit de la barre (soigneur, protecteur, dégâts, soutien, invocateur,
  hybride) et modifiable : il ajuste les poids.
- **F9.2** — **Comportement** comme les héros : *Combattre* / *Garder* (ne pas engager, réagir
  si attaqué ou si un allié l'est) / *Éviter* (ne jamais engager, soins et soutien seulement).
- **F9.3** — Configuration par compte et par build dans un fichier INI (poids, réserve
  d'énergie, rayon d'engagement, comportement, cibles prioritaires/évitées), avec valeurs par
  défaut sensées : aucun réglage n'est obligatoire.
- **F9.4** — Description d'un skill surchargeable par compte (cas d'un build particulier).

### 5.10 Déplacement tactique (pendant le combat)

- **F10.1** — Se placer à portée de la meilleure action (lanceur : rester à portée de sort en
  évitant le contact ; mêlée : coller la cible).
- **F10.2** — Sortir des zones dangereuses connues (wells, AoE persistantes, Meteor Shower…)
  d'après les effets visibles et les skills ennemis en cours.
- **F10.3** — Rester groupé : ne pas s'éloigner au-delà d'une distance du leader ou du centre du
  groupe (paramètre).
- **F10.4** — Ne pas déclencher de nouveaux groupes ennemis (rayon d'aggro des groupes non engagés).

### 5.11 Leader et suiveurs

Usage actuel : l'utilisateur joue le leader, les autres comptes le suivent (`Follower.au3`).
Usage visé : **le leader est lui-même un bot** (ex. bot de donjon qui gère le trajet et les
pulls) et les suiveurs jouent en conséquence.

- **F11.1** — Deux modes de leader, choisis automatiquement :
  - *leader humain* : rien n'est publié dans le canal leader ; les suiveurs déduisent tout de ce
    qu'ils voient dans leur propre client (position du leader, cible appelée, combat en cours),
    comme le Follower aujourd'hui ;
  - *leader bot* : le bot leader publie son **intention** dans le canal leader (§5.8).
- **F11.2** — Intention publiée par un leader bot :

  | Champ | Exemples |
  |---|---|
  | Phase | `Travel` (déplacement), `Pull` (j'attire un groupe), `Fight`, `Hold` (attendre ici), `Regroup`, `Rest`, `Loot` |
  | Destination | prochain point du trajet (x, y) |
  | Cible appelée | agent ID |
  | Point de repli | (x, y) où se regrouper si ça tourne mal |
  | Ordres ponctuels | « derrière moi », « ne pas engager », « tout donner » (consommables, élites) |

- **F11.3** — Réaction des suiveurs selon la phase :
  - `Travel` : suivre en formation (angle et distance par compte, repris du Follower), ne pas
    engager sauf s'ils sont attaqués ; entretenir les buffs.
  - `Pull` : rester en retrait derrière le leader, préparer (esprits, wards, préparations),
    n'engager qu'à l'arrivée des ennemis.
  - `Fight` : Zaishen à plein régime, cible appelée prioritaire, rester groupés.
  - `Hold` / `Regroup` : rejoindre le point, soigner et rez, ne pas engager.
  - `Rest` : récupérer l'énergie, relancer les buffs longs.
- **F11.4** — Le leader bot utilise aussi Zaishen pour son propre combat ; c'est son script de
  donjon qui décide des phases et du trajet.
- **F11.5** — API côté bot leader : `ZS_Leader_SetPhase($phase)`, `ZS_Leader_SetDestination($x, $y)`,
  `ZS_Leader_CallTarget($id)`, `ZS_Leader_Order($ordre)`. Côté suiveur : `ZS_FollowLoop($nomLeader)`
  remplace la boucle principale de `Follower.au3` (suivi + combat + phases).
- **F11.6** — Le pilotage existant par le FollowerManager (`pause` / `resume` / `stop` /
  `cfg:` via `WM_COPYDATA`) reste accepté.

### 5.12 Observabilité

- **F12.1** — **Journal des décisions** (activable) : par tick, les N meilleures actions avec
  leur score et le détail des considérations, et l'action retenue.
- **F12.2** — Compteurs de session : skills lancés, interrupts réussis/ratés, soins, morts,
  temps de tick moyen et max.
- **F12.3** — Export d'un instantané (perception) dans un fichier pour le rejouer hors jeu.

---

## 6. Architecture cible

```
API/Plugins/Zaishen/
  _Zaishen.au3                  point d'entrée (#include de tout le reste)
  ZS_Const.au3                  constantes, enums, réglages par défaut
  Perception/                   instantané par tick (reprend les lectures groupées de UtilityAI)
  Knowledge/                    familles, descriptions de skills, table des vetos,
                                table de dangerosité des skills ennemis, rapport de couverture
    Generated/                  données générées (familles déduites des données du jeu)
  Evaluation/                   candidats, considérations, courbes, score, bandes de priorité
  Execution/                    machine à états, armes, déplacement tactique
  Coordination/                 tableau partagé multi-comptes
  Compat/                       façade compatible UtilityAI (UAI_Fight, Cache_SkillBar)
  Tools/                        extraction depuis UtilityAI, rapport de couverture, banc d'essai
  Tests/                        instantanés de référence et décisions attendues
  CAHIER_DES_CHARGES.md
```

**Boucle d'un tick** : `ZS_Perceive()` → `ZS_Evaluate()` (fonctions pures sur l'instantané,
aucune lecture mémoire, aucune attente) → `ZS_Execute()` (un pas de la machine à états) →
journal.

**Points d'entrée publics**
- `ZS_Fight(...)` : boucle de combat jusqu'à la fin du combat (équivalent de `UAI_Fight`).
- `ZS_Tick(...)` : un seul tick, pour les bots qui ont leur propre boucle.
- `ZS_OnZoneChange()` : à l'entrée d'une zone (équivalent de `Cache_SkillBar`).
- `Compat/` : `UAI_Fight` et `Cache_SkillBar` redirigés vers Zaishen, activable par un
  interrupteur, pour basculer GwFarmer, Follower et Pathfinder sans les réécrire.

---

## 7. Exigences non fonctionnelles

| Domaine | Exigence |
|---|---|
| Performance | tick complet ≤ 50 ms en moyenne et ≤ 100 ms au pire avec 40 agents à portée ; perception ≤ 60 % du budget |
| Réactivité | une nouvelle menace (incantation ennemie, allié sous 30 %) est prise en compte au tick suivant |
| Robustesse | aucune boucle sans sortie ; sortie propre sur mort, changement de carte, chargement, déconnexion |
| Compatibilité | AutoIt 3.3.16.1 32 bits ; aucune DLL nouvelle ; aucune modification obligatoire du Core |
| Qualité | `Au3Check` sans nouvelle erreur par rapport à la référence (cf. skill `gwau3-overview`) ; conventions de nommage GwAu3 ; pas de fichier écrit à la main de plus de 1 500 lignes ; code généré séparé et régénérable |
| Coexistence | UtilityAI et Zaishen chargés ensemble sans collision de noms (`ZS_` partout) |

---

## 8. Tests et validation

- **T1 — Banc d'essai hors jeu** : charger un instantané sérialisé, lancer `ZS_Evaluate`, comparer
  l'action choisie à l'attendu. Un jeu de scénarios de référence couvre au minimum : allié bas en
  vie, ennemi qui incante un sort à interrompre, hex dangereux sur un allié, enchantement qui
  expire, cible déjà réservée par un autre compte, veto (Backfire, Empathy), AoE sur un groupe.
- **T2 — Contrôle statique** : `Au3Check` à chaque modification.
- **T3 — Couverture** : rapport des familles et descriptions ; aucune régression.
- **T4 — En jeu** (avec l'accord de l'utilisateur) : comparaison UtilityAI / Zaishen sur les mêmes
  farms GwFarmer — temps par run, morts, interrupts réussis, énergie gaspillée.

---

## 9. Jalons proposés

| Phase | Contenu | Livrable vérifiable |
|---|---|---|
| P0 | Squelette, perception par tick, machine d'exécution, familles par défaut déduites des données, journal | un compte combat avec n'importe quelle barre, sans blocage, journal lisible |
| P1 | Score par considérations, vetos, bandes de priorité, réserve d'énergie, banc d'essai T1 | scénarios T1 de base passants |
| P2 | Timing : interrupts, renouvellement, combos, adrénaline ; table de dangerosité | scénarios d'interrupt et de combo passants |
| P3 | Armes notées ; option StoC pour les incantations ennemies | changement de set justifié dans le journal |
| P4 | Mémoire partagée : slots, réservations, canal leader | deux comptes ne doublent plus interrupts ni soins |
| P5 | Leader et suiveurs : `ZS_FollowLoop`, phases, API leader ; déplacement tactique, comportements Combattre/Garder/Éviter | un bot leader de test enchaîne Travel → Pull → Fight → Regroup et les suiveurs réagissent à chaque phase |
| P6 | Extraction du savoir UtilityAI, descriptions dédiées profession par profession (tous les skills, aucun build privilégié) | rapport de couverture : 100 % des skills avec une famille, descriptions dédiées pour tous les skills dont la famille ne suffit pas |
| P7 | Façade de compatibilité, bascule de GwFarmer / Follower / Pathfinder, comparaison T4 | Zaishen par défaut, UtilityAI déprécié |

---

## 10. Questions ouvertes

1. ~~Builds réellement joués~~ — **tranché** : les builds changent selon les zones et ne sont pas
   connus à l'avance, donc **tous les skills doivent être couverts**. Conséquences : la
   couverture par famille (couche 2) est prioritaire dès P0, aucune hypothèse de build dans le
   code ni dans les poids par défaut, et les scénarios de test T1 couvrent chaque famille plutôt
   que des builds.
2. **Organisation des comptes** : combien de comptes par groupe, avec des héros du jeu en plus ?
   (Réponse partielle : aujourd'hui leader humain + suiveurs ; cible : leader bot de donjon.)
3. **Coordination** : tous les comptes d'un groupe tournent-ils sur la même machine (condition
   de la mémoire partagée) ?
4. **Ambition du déplacement tactique** (P5) : esquive des AoE seulement, ou aussi le *kiting*
   des lanceurs face aux mêlées ?
5. **Dépôt** : Zaishen vit dans le fork GwAu3 ; faut-il prévoir une proposition au dépôt
   d'origine (GwAu3-Projects) à terme, ce qui impose l'anglais dans le code et les commentaires ?
6. **Premier bot leader** : terrain d'essai de P5 — reporté, à choisir quand l'outil existera.
