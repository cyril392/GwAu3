# Zaishen â€” avancement

Fichier de reprise : Ã  lire avant de continuer le dÃ©veloppement (avec le `CAHIER_DES_CHARGES.md`
et les skills `.claude/skills/gwau3-*`). Ã€ mettre Ã  jour Ã  la fin de chaque sÃ©ance.

DerniÃ¨re mise Ã  jour : 14/11/2026 â€” P0/P1 en essai en jeu (Follower Zaishen) ; coÃ»ts rÃ©els, esprits,
bundles et enchantements entretenus ajoutÃ©s et vÃ©rifiÃ©s hors jeu.

## Ã‰tat par phase

| Phase | Ã‰tat | DÃ©tail |
|---|---|---|
| P0 squelette, perception, exÃ©cution, familles, journal | fait | premiers essais en jeu concluants (14/11) |
| P1 score, vetos, bandes, rÃ©serve d'Ã©nergie, banc d'essai | fait | buffs recalÃ©s aprÃ¨s retour en jeu (14/11) |
| P2 timing (interrupts fins, combos, adrÃ©naline, dangerositÃ©) | amorcÃ© | interruption selon le temps restant, chaÃ®ne d'assassin |
| P3 armes notÃ©es, StoC | Ã  faire | l'exigence d'arme est pour l'instant un veto |
| P4 mÃ©moire partagÃ©e | Ã  faire | |
| P5 leader / suiveurs, dÃ©placement tactique | Ã  faire | |
| P6 descriptions dÃ©diÃ©es, extraction UtilityAI | extraction faite | 446 skills enrichis depuis UtilityAI, 37 dÃ©finitions dÃ©diÃ©es ; reste la relecture profession par profession |
| P7 faÃ§ade de compatibilitÃ© `UAI_Fight` | Ã  faire | |

## Ce qui existe

```
_Zaishen.au3                 point d'entrÃ©e, inclus par API/Plugins/_Plugins.au3 (aprÃ¨s UtilityAI)
ZS_Const.au3                 rÃ©glages ($g_*_ZS_*), enums (colonnes, familles, bandes, Ã©tats)
ZS_Core.au3                  ZS_Tick, ZS_Fight, ZS_Reset, ZS_Stats, journal (ZS_Describe, ZS_Log_*)
Perception/ZS_Snapshot.au3   ZS_Perceive (seule lecture mÃ©moire, via les lecteurs groupÃ©s de UtilityAI),
                             suivi entre ticks (incantations, dÃ©gÃ¢ts reÃ§us, esprits posÃ©s),
                             accesseurs purs (ZS_IsFoe, ZS_FxRemain, ZS_Threat, ZS_AimOf, ZS_CountAround...)
Perception/ZS_SnapshotIO.au3 ZS_Snapshot_Save / ZS_Snapshot_Load (format texte, dÃ©crit en tÃªte de fichier)
Knowledge/ZS_Knowledge.au3   ZS_Knowledge_Classify (famille par rÃ¨gles), ZS_DefineSkill, rÃ©solution de la barre
                             (lit aussi coÃ»t en vie et overcast dans le jeu), ZS_Knowledge_Band, rÃ©serve d'Ã©nergie
Knowledge/ZS_SkillDefs.au3   dÃ©finitions dÃ©diÃ©es (couche 3), dont les rÃ¨gles de lÃ¢cher des bundles et les
                             conditions d'UtilityAI que l'outil ne sait pas lire
Knowledge/Generated/ZS_SkillDefs_UAI.au3   GÃ‰NÃ‰RÃ‰ par Tools/ZS_ExtractUAI.ps1 : conditions extraites des
                             CanUse_*/BestTarget_* d'UtilityAI (ZS_DefineParams), Ã©crasÃ©es clÃ© par clÃ© par la couche 3
Evaluation/ZS_Requirements.au3   lecture des conditions (Need/Prefer/Avoid sur la cible, SelfNeed/SelfNot,
                             seuils de vie et d'Ã©nergie, ennemis au contact...) et qualificatifs (ZS_Qualifies)
Knowledge/ZS_Costs.au3       coÃ»t rÃ©el : table des effets qui changent le coÃ»t en Ã©nergie, Expertise,
                             sacrifice (Masochism, Awaken the Blood, Scourge Sacrifice), overcast
Knowledge/ZS_Vetos.au3       ressources, enchantements entretenus, arme, hexes qui punissent, chaÃ®ne d'assassin
Evaluation/ZS_Evaluate.au3   ZS_Evaluate : candidats, utilitÃ© par famille, bundles, modificateurs, classement
Execution/ZS_Execute.au3     machine Ã  Ã©tats Idle -> WaitCast -> Casting -> Aftercast, commandes
Tests/ZS_TestBench.au3       banc d'essai hors jeu + Tests/Scenarios/*.zs (78 scÃ©narios)
Tools/ZS_CoverageReport.au3  classe tous les skills -> Tools/coverage.tsv et coverage_summary.txt
Tools/ZS_ExtractUAI.ps1      extraction du savoir d'UtilityAI -> Knowledge/Generated/ + Tools/uai_review.md
                             (Ã  relancer si UtilityAI change ; enregistrÃ© en UTF-8 avec BOM pour PowerShell 5.1)
```

## Utilisation dans un bot

```autoit
#include "API/_GwAu3.au3"
; rien Ã  appeler au changement de zone ou de barre : la perception s'en charge
$g_s_ZS_LogFile = @ScriptDir & "\zaishen.log"   ; facultatif : journal des dÃ©cisions
$g_b_ZS_Explain = True                           ; facultatif : dÃ©tail des raisons dans le journal
ZS_Fight(Agent_GetAgentInfo(-2, "X"), Agent_GetAgentInfo(-2, "Y"), 1320, 3500)
; ou, dans une boucle Ã  soi :  If ZS_Tick(1320) = $GC_ZS_TICK_NOFOE Then ...
```

Script de test : `Scripts/FollowerZaishen/Follower.au3` (copie du Follower qui appelle
`ZS_Fight` au lieu de `UAI_Fight`, onglet Â« Zaishen Â» : dry run, journal, sauvegarde d'un
instantanÃ©). Le `FollowerManager.au3` du mÃªme dossier lance cette version.

## VÃ©rifier

```powershell
# banc d'essai (112 vÃ©rifications, code de sortie = nombre d'Ã©checs, rapport dans Tests\last_report.txt)
D:\AutoIt3\AutoIt3.exe /ErrorStdOut "API\Plugins\Zaishen\Tests\ZS_TestBench.au3"
# couverture
D:\AutoIt3\AutoIt3.exe /ErrorStdOut "API\Plugins\Zaishen\Tools\ZS_CoverageReport.au3"
# contrÃ´le statique : doit rester Ã  la rÃ©fÃ©rence Â« 10 error(s), 2 warning(s) Â», aucune ligne Zaishen
D:\AutoIt3\Au3Check.exe -q "API\Plugins\Zaishen\Tests\ZS_TestBench.au3"
```

RÃ©sultats au 15/11/2026 : 210/210 ; Ã©valuation â‰ˆ 18 ms pour 40 agents et une barre pleine ;
2 398 skills Ã©quipables, tous avec une famille (0 sans comportement).

## Historique des retours en jeu

- 14/11 â€” interrupts : marge rÃ©duite (250 â†’ 60 ms), un sort de 1/2 s est dÃ©sormais interrompu.
- 14/11 â€” buffs lancÃ©s pour rien : les buffs sont comparÃ©s aux dÃ©gÃ¢ts (mÃªme bande) ; les buffs
  dÃ©fensifs ne partent que sous pression ; les esprits attendent des ennemis Ã  moins de 1000 ;
  un buff utile qui expire garde la prioritÃ© (renouvellement).
- 14/11 â€” menace Ã  distance : ennemis orientÃ©s vers la cible + vie perdue par seconde.
- 14/11 â€” l'Ã©lÃ©mentaliste ne relanÃ§ait plus ses attunements : nouvelle famille `EnergyBuff`
  (enchantement sur soi qui rend de l'Ã©nergie : attunements, Ether Renewal...), bande Upkeep.
- 14/11 â€” le Ritualist ne lÃ¢chait jamais ses urnes : l'urne tenue est maintenant connue par l'objet
  en main (`Item_GetInventoryInfo("BundleItemID")`) + le dernier item spell lancÃ© (un objet de quÃªte
  n'est jamais lÃ¢chÃ©) ; rÃ¨gle gÃ©nÃ©rale Â« recyclage Â» : une urne Ã  effet de lÃ¢cher est lÃ¢chÃ©e dÃ¨s que
  son sort est rechargÃ© ; pas de nouvelle urne tant qu'on en tient une.
- 14/11 â€” le moine Unyielding Aura ne l'interrompait pas pour rez : dÃ©finition dÃ©diÃ©e (`Upkeep=1`,
  `EndFor=DeadAlly`) et nouvelle action Â« mettre fin Ã  un enchantement entretenu Â»
  (`Effect_DropBond`). Les enchantements entretenus sont maintenant lus dans les **bonds** du joueur
  (liste du jeu), plus fiable que l'ancienne dÃ©duction par les effets.
- 14/11 â€” reprise des conditions d'UtilityAI (P6) : 2 115 des 2 274 `CanUse_*` Ã©taient vides ; le
  savoir Ã©tait surtout dans les filtres de ciblage des `BestTarget_*`. `Tools/ZS_ExtractUAI.ps1` les
  traduit en paramÃ¨tres (446 skills) ; 31 cas non lisibles relus Ã  la main (14 reportÃ©s dans
  `ZS_SkillDefs.au3`, le reste listÃ© dans `Tools/uai_review.md`). Power Drain n'est plus rÃ©servÃ© Ã 
  l'Ã©nergie basse. Bugs d'UtilityAI trouvÃ©s : 4 filtres jamais dÃ©finis (`IsAlly`, `IsWeakened`,
  `HasCondition`, un vide), les skills concernÃ©s (Remove Hex, Shatter Hex, Smite Condition...) ne
  trouvaient jamais de cible.
- 14/11 â€” soins : les seuils d'UtilityAI (TargetBelow, MyHPBelow...) sont ignorÃ©s pour les familles de
  soin, les paliers de Zaishen dÃ©cident ; seul un soin qui gagne un bonus sous un seuil l'indique
  (`BonusBelow=`, Word of Healing et Zealous Benediction Ã  50 %) et attend ce seuil sauf urgence (< 30 %).
- 14/11 â€” derviche refait (`Evaluation/ZS_Dervish.au3`), sans liste Ã  maintenir : les enchantements
  flash (indicateur du jeu `ENCHANT_FLASH`) et les skills qui retirent un de nos enchantements
  (`SELF_ENCHANT_REMOVAL`) viennent des donnÃ©es. Un tel skill ne retire que l'enchantement le plus
  rÃ©cent s'il est flash (bonus Â« kick Â») ou sur le point de finir, jamais un enchantement long ; un
  enchantement flash passe en premier quand un de ces skills est prÃªt (Â« feed then kick Â»). L'Ã¢ge des
  effets est maintenant lu (`$GC_ZS_FX_Age`) pour savoir lequel est le plus rÃ©cent. ConfirmÃ© par
  l'utilisateur : c'est bien l'enchantement le plus rÃ©cent que le jeu retire.
- 14/11 â€” Glowing Gaze ne visait pas les cibles en feu : les **effets visibles** sont maintenant lus
  sur tous les agents (`UAI_CacheAgentVisibleEffects`, rÃ©glage `$g_b_ZS_ReadVisibleEffects`) â†’
  nouveaux drapeaux Burning, Blind, Dazed, Weakness (= Cracked Armor, mÃªme icÃ´ne), Diseased, utilisÃ©s
  par les qualificatifs et les exigences du jeu (`ZS_Eval_ReqMet`). Nouveau paramÃ¨tre `BonusIf=` :
  le skill fait plus sur une cible dans cet Ã©tat (+0.15). Extrait des descriptions d'UtilityAI
  (Â« if target foe is Burning / casting / moving... Â», ~85 skills) + dÃ©fini Ã  la main pour Glowing
  Gaze (Burning), Glowing Ice (Hexed), Glowing Signet (`Need=Burning`). Un sort d'Ã©nergie avec
  `BonusIf` : sur une cible qui donne l'Ã©nergie, prioritaire (bande Upkeep) quand l'Ã©nergie baisse,
  simple nuke sinon ; sur une autre cible, seulement ses dÃ©gÃ¢ts (bande Damage, rÃ©serve d'Ã©nergie).
- 14/11 â€” malÃ©fices anti-attaque (Clumsiness, Ineptitude, Wandering Eye, Empathy) : `Prefer=NotCaster,Attacking`,
  jamais interdits sur un caster (il attaque Ã  la baguette quand il n'y a pas de corps-Ã -corps).
  `Prefer=` compte dÃ©sormais chaque qualificatif montrÃ©, les premiers de la liste pesant plus :
  combattant qui attaque > combattant > caster qui attaque > caster inactif.
- 14/11 â€” malÃ©fices anti-caster revus d'aprÃ¨s les descriptions : Guilt et Mistrust (sort lancÃ© sur
  NOS alliÃ©s) sur les casters offensifs, pas les moines ; Shame (sort lancÃ© sur SES alliÃ©s) sur
  moine/ritualiste d'abord ; Diversion et Migraine ne sont plus interdits sur un combattant ;
  Overload bonus si la cible incante ; Visions of Regret / Spiteful Spirit sur un groupe ;
  Wastrel's Worry/Demise Ã©vitent la cible qui incante (le malÃ©fice finirait sans effet).
  Classement : un skill marquÃ© Â« interrupt Â» par le jeu mais qui s'active en 1 s ou plus (Guilt,
  Shame : 2 s) n'est plus une interruption mais un malÃ©fice prÃ©ventif.
- 14/11 â€” **sets d'armes** (`Equipment/ZS_Weapons.au3`, P3) : les 4 sets et leurs mods sont lus une
  fois par instance (Ã©nergie, Ã©nergie conditionnelle, % d'enchantement, HCT/HSR). Set Â« maison Â» = celui
  de l'arme des attaques de la barre (sinon le plus d'Ã©nergie). On ne le quitte que si l'action le
  demande : attaque qui exige une autre arme ; Ã©nergie empruntÃ©e Ã  un set plus riche (le jeu donne la
  diffÃ©rence tout de suite et la reprend au retour) seulement pour soin/rez/interrupt/cleanse/survie,
  ou entretien avec â‰¤ 5 de dette, jamais pour un sort de dÃ©gÃ¢ts ; enchantement long avec â‰¥ 15 % de
  mieux, seulement si aucune attaque n'est prÃªte. Retour au set maison dÃ¨s qu'une attaque est choisie.
  Garde-fous : jamais de switch de confort pendant une chaÃ®ne d'assassin ni moins de 4 s aprÃ¨s le
  prÃ©cÃ©dent ; 4 switches en 10 s gÃ¨lent les switches 5 s. Option Â« Switch weapon sets Â» dans le
  Follower ; Â« Save snapshot Â» Ã©crit aussi les sets lus (pour vÃ©rifier les mods).
- 15/11 â€” idÃ©es reprises de la branche LogicCast (rÃ©Ã©crites, pas de code copiÃ©) : **Fast Casting**
  raccourcit nos sorts et signets (tous ceux de mesmer, les autres dÃ¨s 2 s) ; le **vol de la flÃ¨che ou
  de la lance** compte dans le dÃ©lai d'un interrupt Ã  l'arc/lance ; Â« Interrupts a spell Â» extrait des
  descriptions â†’ `Only=Spell` sur tous ces interrupts (Power Leech, Concussion Shot, Broad Head Arrow...),
  `AnyIf=Hexed` pour Signet of Disruption ; un interrupt qui rend de l'Ã©nergie vaut plus quand on en manque.
- 15/11 â€” P2 : **chaÃ®ne d'assassin** : une attaque d'ouverture est retenue si sa suite revient avant
  elle (sinon l'ouverture manquerait au moment de la chaÃ®ne) ou s'il ne reste pas l'Ã©nergie pour la
  suite ; une chaÃ®ne commencÃ©e n'est jamais retenue. **AdrÃ©naline** (rÃ¨gle du jeu : utiliser un skill
  Ã  adrÃ©naline retire 1 coup Ã  tous les autres) : le plus gros skill prÃªt passe en premier ; un petit
  attend quand un plus gros est Ã  un coup d'Ãªtre prÃªt. **Sorts ennemis** : la valeur d'une interruption
  vient de la famille du sort ennemi, avec le mÃªme classement que nos skills (rez +0,4, soin +0,3,
  protection +0,25, retrait de malÃ©fice/condition +0,15, zone et malÃ©fice +0,1).
- 15/11 â€” **audit de couverture** (5 relectures, une par groupe de professions, croisÃ©es avec les
  donnÃ©es du jeu et le code ; ~200 skills corrigÃ©s dans `ZS_LoadDefs_Audit`). Moteur :
  - **durÃ©e rÃ©elle** des effets au rang d'attribut du joueur (avant : rang 0), la barre est relue Ã 
    chaque instance ;
  - **familier** lu dans le jeu (`ZS_Read_MyPet`) : distinguÃ© des esprits ; attaques de familier
    seulement s'il vit ; Comfort Animal / Revive Animal le soignent ou le relÃ¨vent (`OnPet=1`,
    `PetRez=`) ; Charm Animal n'est plus lancÃ© sur lui ;
  - piÃ¨ges et esprits plus bloquÃ©s pendant toute leur durÃ©e aprÃ¨s un lancer ;
  - soins en enchantement (Mending, Healing Breeze, Reversal of Fortune...) jamais lancÃ©s deux fois ;
  - skills Ã  cadavre (Soul Feast, Consume Corpse...) seulement s'il y a un cadavre ;
  - derviche : les skills qui retirent un enchantement ne prennent qu'un enchantement de derviche ;
  - **une posture (une forme) Ã  la fois** : pas de remplacement, sauf une posture dÃ©fensive sous forte
    pression ; `Defensive=0` force un skill entretenu (Shadow Form) ;
  - **glyphes** seulement si le sort qu'ils prÃ©parent est prÃªt (`Before=Cost:10` / `Cast:2000`), et ce
    sort passe ensuite en premier ;
  - **wards** : dÃ©fensives selon la pression sur ceux qui sont dedans, offensives (`Ward=Foes`) selon
    les ennemis dedans, de soutien quand des ennemis approchent ;
  - interrupt au corps Ã  corps : la marche jusqu'Ã  la cible compte ; un interrupt-attaque sert d'attaque
    quand aucun ennemi n'incante ; aucune attaque quand le joueur est aveuglÃ© ;
  - nettoyage de groupe lancÃ© sur soi (Song of Purification...) comptÃ© sur les alliÃ©s de la zone ;
    soins et rÃ©surrections de zone limitÃ©s Ã  leur zone (Heal Area, Light of Dwayna) ;
  - weapon spells dÃ©fensifs donnÃ©s Ã  l'alliÃ© frappÃ© ; piÃ¨ges pas posÃ©s sous le feu ;
  - nouveaux paramÃ¨tres : `MaxTargets=1` (Strength of Honor, Life Bond), `EndsOn=` (Battle Rage,
    Charging Strike...), `MinionsNear=`, `Spread=1` (malÃ©fices qui s'Ã©tendent), `EndFor=LowHealth`
    (Aura of Displacement), qualificatifs `PetAlive/PetDead/PetHurt`, `NotEnchanted`, `NotBlind` ;
    `Need=/Avoid=` jugent aussi le joueur pour un buff qui peut viser un alliÃ©.
- 15/11 â€” **positionnement en combat** (`Evaluation/ZS_Position.au3`) : un dÃ©placement est un candidat
  comme les skills (action `MOVE`), il ne part que s'il vaut plus que le reste :
  - **zones de dÃ©gÃ¢ts au sol** (Fire Storm, Meteor Shower, Maelstrom, Chaos Storm, Searing Heat, Bed of
    Coals, Eruption, Savannah Heat, Sandstorm, Lightning Storm, Churning Earth, versions de monstres
    comprises) : un ennemi vu en train de les lancer vers l'un de nous laisse, quand le sort aboutit, une
    zone lÃ  oÃ¹ se tenait la cible ; si le joueur y est pour encore plus d'1 s, il en sort (bande Survie),
    du cÃ´tÃ© du groupe, sans entrer dans une autre zone ;
  - **recul** d'un joueur Ã  distance (arc, lance, baguette, bÃ¢ton) frappÃ© au corps Ã  corps : un pas de 400
    vers le groupe, en gardant un ennemi Ã  portÃ©e de sort, au plus toutes les 4 s ; un soin urgent passe avant ;
  - **urne qui ressuscite** : aller jusqu'Ã  l'alliÃ© mort hors de sa zone ;
  - un dÃ©placement commencÃ© continue jusqu'au bout (une action moins importante ne l'arrÃªte pas) ;
  - case Â« Move in fights Â» dans le Follower (`$g_b_ZS_Positioning`) ; ligne `H|` des snapshots.
- 15/11 â€” **hors combat** : le Follower appelle `ZS_Fight` Ã  chaque tour de boucle (un tick puis retour
  quand il n'y a pas d'ennemi). RÃ©surrections, soins et retraits de malÃ©fice/condition marchaient dÃ©jÃ  hors
  combat ; ajoutÃ©s : les **skills de vitesse** (`Speed=1` : Sprint, Dash, Storm Djinn's Haste, Zojun's
  Haste, Burning Speed, Pious Haste, Charge!, Fall Back!, Incoming!, Make Haste!, Windborne Speed... ;
  `Speed=2` : Escape, Dark Escape gardent leur usage en combat) quand le joueur marche, et `OutOfCombat=1`
  pour tout skill qu'on veut entretenir entre les combats. Les autres buffs attendent le combat.
  `ZS_Fight` ne rend plus la main pendant une action en cours : une rÃ©surrection n'est plus coupÃ©e par le
  dÃ©placement du Follower.
  **Vitesse de groupe** : un skill de vitesse de zone (Incoming!, Fall Back!...) passe avant un skill
  personnel, d'autant plus qu'il y a d'alliÃ©s autour ; aucun skill de vitesse quand un autre effet de
  vitesse est dÃ©jÃ  sur le joueur (les vitesses ne s'additionnent pas) : quand un bot du groupe a criÃ©
  Incoming!, les autres ne relancent rien (les effets du groupe sont visibles).

## Ã‰carts par rapport au cahier des charges

- **Couche 2 calculÃ©e Ã  l'exÃ©cution**, pas gÃ©nÃ©rÃ©e dans `Knowledge/Generated/` : la famille est
  dÃ©duite par `ZS_Knowledge_Classify` quand la barre change (8 skills). Le fichier gÃ©nÃ©rÃ© ne
  deviendra utile qu'avec l'extraction du savoir UtilityAI (P6).
- **Couche 4 (INI par compte) non faite.**
- **`ZS_OnZoneChange` n'existe pas** : inutile, la perception dÃ©tecte le changement d'instance et
  de barre (`ZS_Reset` existe pour un redÃ©marrage propre).
- **Zaishen ne dÃ©pend plus d'UtilityAI** (15/11) : ses propres lecteurs (`Perception/ZS_Read.au3`,
  sur le cÅ“ur GwAu3 seulement) lisent agents, effets, bonds, effets visibles, barre de skills et cible
  appelÃ©e. VÃ©rifiÃ© en compilant Zaishen sans le plugin UtilityAI. Seul le savoir sur les skills vient
  encore d'UtilityAI, mais hors ligne : `Knowledge/Generated/ZS_SkillDefs_UAI.au3` est un fichier figÃ©.
  Le plugin **Pathfinder** appelle encore `UAI_Fight` (Ã  rediriger vers Zaishen le jour oÃ¹ on retire UtilityAI).
- Les effets visibles sont lus pour tous les agents (un parcours de liste par agent) : Ã  surveiller
  sur le temps de perception ; dÃ©sactivable par `$g_b_ZS_ReadVisibleEffects = False`.

## Ã€ confirmer en jeu

- **Nouveaux lecteurs mÃ©moire** (`ZS_Read.au3`) : mÃªmes offsets et mÃªmes structures que ceux
  d'UtilityAI qui marchaient en jeu, mais rÃ©Ã©crits ; vÃ©rifier au premier essai (journal, Save snapshot)
  que les agents, l'Ã©nergie, les effets et la barre sont bien lus.
- **Familier** (`Party_GetPetInfo` : propriÃ©taire = nous) et **rangs d'attribut** pour les durÃ©es
  (`Attribute_GetPartyAttributeInfo`, aussi pour les attributs PvE qui peuvent revenir Ã  0).
- Comfort Animal ressuscite-t-il bien un familier mort (version actuelle du skill) ?
- **DÃ©placements** (`Map_Move`) : le joueur sort bien des zones et recule sans tourner en rond ; vitesse
  de marche supposÃ©e 0,28 unitÃ©/ms ; rayon des zones = celui de la table (Fire Storm 156).

- **Mods d'armes** : identifiants dÃ©duits des tables d'UtilityAI (`C867` Ã©nergie de base des armes de
  caster, `D822` Ã©nergie +N, `B820` Ã©nergie âˆ’N, `F822`/`2823`/`0823`/`1823` Ã©nergie conditionnelle,
  `B822` % d'enchantement, `0822`/`0828` HCT, `A823`/`2828` HSR) ; vÃ©rifier avec Â« Save snapshot Â»
  que l'Ã©nergie et le % lus correspondent Ã  l'objet. Set en main reconnu par les ID d'objets tenus.
- **Ã‰nergie au changement de set** : supposÃ©e ajoutÃ©e/cachÃ©e immÃ©diatement (wiki Â« Energy hiding Â»).

- **CoÃ»t en vie et overcast** lus par `Skill_GetSkillInfo(id, "HealthCost" | "Overcast")` au
  changement de barre (octets 0x36 et 0x34 de la structure du skill).
- **Niveau d'attribut des effets** (`AttributeLevel` du cache UtilityAI) : il donne la force des
  effets de coÃ»t (Glyph of Lesser Energy, Cultist's Fervor...).
- **Expertise** lue par `Attribute_GetPartyAttributeInfo(EXPERTISE, 0, "CurrentLevel")` Ã  chaque instance.
- **Liaison ritual â†’ esprit** : le premier nouvel esprit alliÃ© Ã  moins de 350 dans les ~3 s aprÃ¨s le
  lancement est considÃ©rÃ© comme le nÃ´tre (le jeu ne dit pas qui l'a crÃ©Ã©). Un esprit d'un autre
  joueur posÃ© au mÃªme moment au mÃªme endroit serait pris pour le nÃ´tre.
- **Urne tenue** : `BundleItemID` non nul juste aprÃ¨s un item spell lancÃ© par Zaishen (repli : effet
  du skill sur le joueur). Une urne prise Ã  la main par le joueur n'est pas reconnue.
- **Enchantements entretenus** : lus dans les bonds du joueur (`$g_amx3_PlayerBonds` d'UtilityAI) ;
  vÃ©rifier la cible enregistrÃ©e pour un enchantement sur soi (0 ou notre ID, les deux sont acceptÃ©s),
  et que `Effect_DropBond(skill, -2, 0)` met bien fin Ã  Unyielding Aura.
- La rÃ©gÃ©nÃ©ration d'Ã©nergie (`EnergyRegen` de l'agent) doit bien passer Ã  0 ou moins quand elle est Ã©puisÃ©e.
- **Orientation des tireurs** (`RotationCos/Sin`) et seuils de la vie perdue par seconde (2 Ã  12 %/s).

## Limites connues (Ã  traiter)

- Les buffs d'alliÃ©s hors groupe ne sont pas visibles : on se fie Ã  la durÃ©e du skill (`$g_m_ZS_Recent`).
- Les donnÃ©es du jeu donnent une zone Ã  des sorts mono-cible (Flare) : classÃ©s `DamageAoE`, sans
  consÃ©quence autre qu'un bonus aux groupes serrÃ©s.
- Un enchantement n'est reconnu comme Â« entretenu Â» qu'aprÃ¨s l'avoir vu entretenu une fois : le
  premier lancement n'est donc pas limitÃ©.
- Unyielding Aura ressuscite un membre **au hasard** : avec plusieurs morts, on ne choisit pas lequel.
- Non repris : Rampage as One / Never Rampage Alone / Heal as One (familier vu, mais pas leur logique),
  Extend Enchantments avant Vow of Strength, jonglage d'adrÃ©naline Brawling.
- **Refrains du parangon** : relancÃ©s quand ils finissent, pas renouvelÃ©s par les cris (coÃ»te plus d'Ã©nergie).
- Puits et Putrid Explosion : on sait qu'un cadavre existe, pas **oÃ¹** il est ni qui l'entoure.
- Sorts Â« Mind Â» (Mind Burn, Mind Shock...) : l'Ã©nergie ennemie n'est pas visible, ce sont de simples nukes.
- Intensity / Signet of Illusions : pas de condition Â« un sort de zone est prÃªt Â» (seuls les glyphes l'ont).
- Descriptions incertaines lors de l'audit, rÃ©glages prudents : Spirit to Flesh, Ether Signet,
  Signet of Removal, Keystone Signet, Arcane Conundrum, Lightbringer Signet (non touchÃ©).
- `AdrenReq` de quelques skills n'est pas un multiple de 25 (Cleave 80...) : unitÃ© Ã  vÃ©rifier en jeu.
- Glowing Ice : le jeu demande un malÃ©fice d'eau, Zaishen ne voit que Â« a un malÃ©fice Â».
- `BonusIf` vient de descriptions rÃ©digÃ©es : quelques correspondances approximatives possibles
  (visibles dans `Knowledge/Generated/ZS_SkillDefs_UAI.au3`, corrigeables dans `ZS_SkillDefs.au3`).
- D'autres enchantements Â« dont la fin fait quelque chose Â» existent peut-Ãªtre : ils s'ajoutent par
  une ligne `EndFor=` dans `ZS_SkillDefs.au3` (une seule rÃ¨gle pour l'instant : `DeadAlly`).
- Bundles : Zaishen ne se dÃ©place pas pour lÃ¢cher une urne au bon endroit (UtilityAI le faisait en
  bloquant jusqu'Ã  3 s) ; il attend que la condition soit remplie lÃ  oÃ¹ il est.
- Effets de coÃ»t portÃ©s tels quels depuis UtilityAI ; Healer's Covenant et Expert Focus utilisent la
  force de l'effet Ã  son niveau d'attribut (Ã  vÃ©rifier sur quelques cas).
- Aucune gestion de la portÃ©e d'aggro des groupes non engagÃ©s ; pas de fuite face Ã  un groupe trop fort
  (demande la carte et un chemin) ; pas de Â« kiting Â».
- Zones de dÃ©gÃ¢ts : seules celles lancÃ©es **pendant que Zaishen regarde** sont connues (pas celles posÃ©es
  avant, ni les puits ennemis dont le cadavre est inconnu) ; centre = l'alliÃ© que l'ennemi regardait.
  Les esprits ennemis ne sont pas Ã©vitÃ©s (ils se tuent).
- La menace (`ZS_Threat`) combine : ennemis au contact (< 300), ennemis Ã  distance qui attaquent ou
  incantent **orientÃ©s** vers la cible (`ZS_AimOf` attribue chaque ennemi Ã  celui d'entre nous qu'il
  vise le mieux), et **vie perdue par seconde** (`ZS_Perception_TrackDamage`, lissÃ©e sur ~1 s).
- Interrupts : le temps d'activation **ennemi** est celui de la table, sans ses accÃ©lÃ©rations
  (Fast Casting ennemi, Mantra...). Le dÃ©but du sort ennemi est le premier tick oÃ¹ on le voit (jusqu'Ã 
  40 ms de retard) : un hook Â« SkillLog Â» (idÃ©e de la branche LogicCast) donnerait l'instant exact et la
  cible du sort, non repris pour l'instant (injection dans le client, casse aux mises Ã  jour).
- Vitesse des flÃ¨ches (0,85 unitÃ©/ms) et des lances (1,05) : mesures de LogicCast, Ã  confirmer.

## Prochaines Ã©tapes proposÃ©es

1. Continuer les essais en jeu et corriger au fil des retours (journal + snapshot).
2. P6 : outil d'extraction du savoir des `CanUse_*` / `BestTarget_*` d'UtilityAI, puis descriptions
   dÃ©diÃ©es profession par profession.
3. P2 : table de dangerositÃ© des skills ennemis, dÃ©pense d'adrÃ©naline, prÃ©paration des conditions requises.
4. P4/P5 : mÃ©moire partagÃ©e puis leader / suiveurs.
5. P7 : faÃ§ade `UAI_Fight` â†’ `ZS_Fight` pour basculer GwFarmer et Pathfinder.
