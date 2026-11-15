# Zaishen — avancement

Fichier de reprise : à lire avant de continuer le développement (avec le `CAHIER_DES_CHARGES.md`
et les skills `.claude/skills/gwau3-*`). À mettre à jour à la fin de chaque séance.

Dernière mise à jour : 14/11/2026 — P0/P1 en essai en jeu (Follower Zaishen) ; coûts réels, esprits,
bundles et enchantements entretenus ajoutés et vérifiés hors jeu.

## État par phase

| Phase | État | Détail |
|---|---|---|
| P0 squelette, perception, exécution, familles, journal | fait | premiers essais en jeu concluants (14/11) |
| P1 score, vetos, bandes, réserve d'énergie, banc d'essai | fait | buffs recalés après retour en jeu (14/11) |
| P2 timing (interrupts fins, combos, adrénaline, dangerosité) | amorcé | interruption selon le temps restant, chaîne d'assassin |
| P3 armes notées, StoC | à faire | l'exigence d'arme est pour l'instant un veto |
| P4 mémoire partagée | à faire | |
| P5 leader / suiveurs, déplacement tactique | à faire | |
| P6 descriptions dédiées, extraction UtilityAI | extraction faite | 446 skills enrichis depuis UtilityAI, 37 définitions dédiées ; reste la relecture profession par profession |
| P7 façade de compatibilité `UAI_Fight` | à faire | |

## Ce qui existe

```
_Zaishen.au3                 point d'entrée, inclus par API/Plugins/_Plugins.au3 (après UtilityAI)
ZS_Const.au3                 réglages ($g_*_ZS_*), enums (colonnes, familles, bandes, états)
ZS_Core.au3                  ZS_Tick, ZS_Fight, ZS_Reset, ZS_Stats, journal (ZS_Describe, ZS_Log_*)
Perception/ZS_Snapshot.au3   ZS_Perceive (seule lecture mémoire, via les lecteurs groupés de UtilityAI),
                             suivi entre ticks (incantations, dégâts reçus, esprits posés),
                             accesseurs purs (ZS_IsFoe, ZS_FxRemain, ZS_Threat, ZS_AimOf, ZS_CountAround...)
Perception/ZS_SnapshotIO.au3 ZS_Snapshot_Save / ZS_Snapshot_Load (format texte, décrit en tête de fichier)
Knowledge/ZS_Knowledge.au3   ZS_Knowledge_Classify (famille par règles), ZS_DefineSkill, résolution de la barre
                             (lit aussi coût en vie et overcast dans le jeu), ZS_Knowledge_Band, réserve d'énergie
Knowledge/ZS_SkillDefs.au3   définitions dédiées (couche 3), dont les règles de lâcher des bundles et les
                             conditions d'UtilityAI que l'outil ne sait pas lire
Knowledge/Generated/ZS_SkillDefs_UAI.au3   GÉNÉRÉ par Tools/ZS_ExtractUAI.ps1 : conditions extraites des
                             CanUse_*/BestTarget_* d'UtilityAI (ZS_DefineParams), écrasées clé par clé par la couche 3
Evaluation/ZS_Requirements.au3   lecture des conditions (Need/Prefer/Avoid sur la cible, SelfNeed/SelfNot,
                             seuils de vie et d'énergie, ennemis au contact...) et qualificatifs (ZS_Qualifies)
Knowledge/ZS_Costs.au3       coût réel : table des effets qui changent le coût en énergie, Expertise,
                             sacrifice (Masochism, Awaken the Blood, Scourge Sacrifice), overcast
Knowledge/ZS_Vetos.au3       ressources, enchantements entretenus, arme, hexes qui punissent, chaîne d'assassin
Evaluation/ZS_Evaluate.au3   ZS_Evaluate : candidats, utilité par famille, bundles, modificateurs, classement
Execution/ZS_Execute.au3     machine à états Idle -> WaitCast -> Casting -> Aftercast, commandes
Tests/ZS_TestBench.au3       banc d'essai hors jeu + Tests/Scenarios/*.zs (78 scénarios)
Tools/ZS_CoverageReport.au3  classe tous les skills -> Tools/coverage.tsv et coverage_summary.txt
Tools/ZS_ExtractUAI.ps1      extraction du savoir d'UtilityAI -> Knowledge/Generated/ + Tools/uai_review.md
                             (à relancer si UtilityAI change ; enregistré en UTF-8 avec BOM pour PowerShell 5.1)
```

## Utilisation dans un bot

```autoit
#include "API/_GwAu3.au3"
; rien à appeler au changement de zone ou de barre : la perception s'en charge
$g_s_ZS_LogFile = @ScriptDir & "\zaishen.log"   ; facultatif : journal des décisions
$g_b_ZS_Explain = True                           ; facultatif : détail des raisons dans le journal
ZS_Fight(Agent_GetAgentInfo(-2, "X"), Agent_GetAgentInfo(-2, "Y"), 1320, 3500)
; ou, dans une boucle à soi :  If ZS_Tick(1320) = $GC_ZS_TICK_NOFOE Then ...
```

Script de test : `Scripts/FollowerZaishen/Follower.au3` (copie du Follower qui appelle
`ZS_Fight` au lieu de `UAI_Fight`, onglet « Zaishen » : dry run, journal, sauvegarde d'un
instantané). Le `FollowerManager.au3` du même dossier lance cette version.

## Vérifier

```powershell
# banc d'essai (112 vérifications, code de sortie = nombre d'échecs, rapport dans Tests\last_report.txt)
D:\AutoIt3\AutoIt3.exe /ErrorStdOut "API\Plugins\Zaishen\Tests\ZS_TestBench.au3"
# couverture
D:\AutoIt3\AutoIt3.exe /ErrorStdOut "API\Plugins\Zaishen\Tools\ZS_CoverageReport.au3"
# contrôle statique : doit rester à la référence « 10 error(s), 2 warning(s) », aucune ligne Zaishen
D:\AutoIt3\Au3Check.exe -q "API\Plugins\Zaishen\Tests\ZS_TestBench.au3"
```

Résultats au 15/11/2026 : 194/194 ; évaluation ≈ 18 ms pour 40 agents et une barre pleine ;
2 398 skills équipables, tous avec une famille (0 sans comportement).

## Historique des retours en jeu

- 14/11 — interrupts : marge réduite (250 → 60 ms), un sort de 1/2 s est désormais interrompu.
- 14/11 — buffs lancés pour rien : les buffs sont comparés aux dégâts (même bande) ; les buffs
  défensifs ne partent que sous pression ; les esprits attendent des ennemis à moins de 1000 ;
  un buff utile qui expire garde la priorité (renouvellement).
- 14/11 — menace à distance : ennemis orientés vers la cible + vie perdue par seconde.
- 14/11 — l'élémentaliste ne relançait plus ses attunements : nouvelle famille `EnergyBuff`
  (enchantement sur soi qui rend de l'énergie : attunements, Ether Renewal...), bande Upkeep.
- 14/11 — le Ritualist ne lâchait jamais ses urnes : l'urne tenue est maintenant connue par l'objet
  en main (`Item_GetInventoryInfo("BundleItemID")`) + le dernier item spell lancé (un objet de quête
  n'est jamais lâché) ; règle générale « recyclage » : une urne à effet de lâcher est lâchée dès que
  son sort est rechargé ; pas de nouvelle urne tant qu'on en tient une.
- 14/11 — le moine Unyielding Aura ne l'interrompait pas pour rez : définition dédiée (`Upkeep=1`,
  `EndFor=DeadAlly`) et nouvelle action « mettre fin à un enchantement entretenu »
  (`Effect_DropBond`). Les enchantements entretenus sont maintenant lus dans les **bonds** du joueur
  (liste du jeu), plus fiable que l'ancienne déduction par les effets.
- 14/11 — reprise des conditions d'UtilityAI (P6) : 2 115 des 2 274 `CanUse_*` étaient vides ; le
  savoir était surtout dans les filtres de ciblage des `BestTarget_*`. `Tools/ZS_ExtractUAI.ps1` les
  traduit en paramètres (446 skills) ; 31 cas non lisibles relus à la main (14 reportés dans
  `ZS_SkillDefs.au3`, le reste listé dans `Tools/uai_review.md`). Power Drain n'est plus réservé à
  l'énergie basse. Bugs d'UtilityAI trouvés : 4 filtres jamais définis (`IsAlly`, `IsWeakened`,
  `HasCondition`, un vide), les skills concernés (Remove Hex, Shatter Hex, Smite Condition...) ne
  trouvaient jamais de cible.
- 14/11 — soins : les seuils d'UtilityAI (TargetBelow, MyHPBelow...) sont ignorés pour les familles de
  soin, les paliers de Zaishen décident ; seul un soin qui gagne un bonus sous un seuil l'indique
  (`BonusBelow=`, Word of Healing et Zealous Benediction à 50 %) et attend ce seuil sauf urgence (< 30 %).
- 14/11 — derviche refait (`Evaluation/ZS_Dervish.au3`), sans liste à maintenir : les enchantements
  flash (indicateur du jeu `ENCHANT_FLASH`) et les skills qui retirent un de nos enchantements
  (`SELF_ENCHANT_REMOVAL`) viennent des données. Un tel skill ne retire que l'enchantement le plus
  récent s'il est flash (bonus « kick ») ou sur le point de finir, jamais un enchantement long ; un
  enchantement flash passe en premier quand un de ces skills est prêt (« feed then kick »). L'âge des
  effets est maintenant lu (`$GC_ZS_FX_Age`) pour savoir lequel est le plus récent. Confirmé par
  l'utilisateur : c'est bien l'enchantement le plus récent que le jeu retire.
- 14/11 — Glowing Gaze ne visait pas les cibles en feu : les **effets visibles** sont maintenant lus
  sur tous les agents (`UAI_CacheAgentVisibleEffects`, réglage `$g_b_ZS_ReadVisibleEffects`) →
  nouveaux drapeaux Burning, Blind, Dazed, Weakness (= Cracked Armor, même icône), Diseased, utilisés
  par les qualificatifs et les exigences du jeu (`ZS_Eval_ReqMet`). Nouveau paramètre `BonusIf=` :
  le skill fait plus sur une cible dans cet état (+0.15). Extrait des descriptions d'UtilityAI
  (« if target foe is Burning / casting / moving... », ~85 skills) + défini à la main pour Glowing
  Gaze (Burning), Glowing Ice (Hexed), Glowing Signet (`Need=Burning`). Un sort d'énergie avec
  `BonusIf` : sur une cible qui donne l'énergie, prioritaire (bande Upkeep) quand l'énergie baisse,
  simple nuke sinon ; sur une autre cible, seulement ses dégâts (bande Damage, réserve d'énergie).
- 14/11 — maléfices anti-attaque (Clumsiness, Ineptitude, Wandering Eye, Empathy) : `Prefer=NotCaster,Attacking`,
  jamais interdits sur un caster (il attaque à la baguette quand il n'y a pas de corps-à-corps).
  `Prefer=` compte désormais chaque qualificatif montré, les premiers de la liste pesant plus :
  combattant qui attaque > combattant > caster qui attaque > caster inactif.
- 14/11 — maléfices anti-caster revus d'après les descriptions : Guilt et Mistrust (sort lancé sur
  NOS alliés) sur les casters offensifs, pas les moines ; Shame (sort lancé sur SES alliés) sur
  moine/ritualiste d'abord ; Diversion et Migraine ne sont plus interdits sur un combattant ;
  Overload bonus si la cible incante ; Visions of Regret / Spiteful Spirit sur un groupe ;
  Wastrel's Worry/Demise évitent la cible qui incante (le maléfice finirait sans effet).
  Classement : un skill marqué « interrupt » par le jeu mais qui s'active en 1 s ou plus (Guilt,
  Shame : 2 s) n'est plus une interruption mais un maléfice préventif.
- 14/11 — **sets d'armes** (`Equipment/ZS_Weapons.au3`, P3) : les 4 sets et leurs mods sont lus une
  fois par instance (énergie, énergie conditionnelle, % d'enchantement, HCT/HSR). Set « maison » = celui
  de l'arme des attaques de la barre (sinon le plus d'énergie). On ne le quitte que si l'action le
  demande : attaque qui exige une autre arme ; énergie empruntée à un set plus riche (le jeu donne la
  différence tout de suite et la reprend au retour) seulement pour soin/rez/interrupt/cleanse/survie,
  ou entretien avec ≤ 5 de dette, jamais pour un sort de dégâts ; enchantement long avec ≥ 15 % de
  mieux, seulement si aucune attaque n'est prête. Retour au set maison dès qu'une attaque est choisie.
  Garde-fous : jamais de switch de confort pendant une chaîne d'assassin ni moins de 4 s après le
  précédent ; 4 switches en 10 s gèlent les switches 5 s. Option « Switch weapon sets » dans le
  Follower ; « Save snapshot » écrit aussi les sets lus (pour vérifier les mods).
- 15/11 — idées reprises de la branche LogicCast (réécrites, pas de code copié) : **Fast Casting**
  raccourcit nos sorts et signets (tous ceux de mesmer, les autres dès 2 s) ; le **vol de la flèche ou
  de la lance** compte dans le délai d'un interrupt à l'arc/lance ; « Interrupts a spell » extrait des
  descriptions → `Only=Spell` sur tous ces interrupts (Power Leech, Concussion Shot, Broad Head Arrow...),
  `AnyIf=Hexed` pour Signet of Disruption ; un interrupt qui rend de l'énergie vaut plus quand on en manque.
- 15/11 — P2 : **chaîne d'assassin** : une attaque d'ouverture est retenue si sa suite revient avant
  elle (sinon l'ouverture manquerait au moment de la chaîne) ou s'il ne reste pas l'énergie pour la
  suite ; une chaîne commencée n'est jamais retenue. **Adrénaline** (règle du jeu : utiliser un skill
  à adrénaline retire 1 coup à tous les autres) : le plus gros skill prêt passe en premier ; un petit
  attend quand un plus gros est à un coup d'être prêt. **Sorts ennemis** : la valeur d'une interruption
  vient de la famille du sort ennemi, avec le même classement que nos skills (rez +0,4, soin +0,3,
  protection +0,25, retrait de maléfice/condition +0,15, zone et maléfice +0,1).
- 15/11 — **audit de couverture** (5 relectures, une par groupe de professions, croisées avec les
  données du jeu et le code ; ~200 skills corrigés dans `ZS_LoadDefs_Audit`). Moteur :
  - **durée réelle** des effets au rang d'attribut du joueur (avant : rang 0), la barre est relue à
    chaque instance ;
  - **familier** lu dans le jeu (`ZS_Read_MyPet`) : distingué des esprits ; attaques de familier
    seulement s'il vit ; Comfort Animal / Revive Animal le soignent ou le relèvent (`OnPet=1`,
    `PetRez=`) ; Charm Animal n'est plus lancé sur lui ;
  - pièges et esprits plus bloqués pendant toute leur durée après un lancer ;
  - soins en enchantement (Mending, Healing Breeze, Reversal of Fortune...) jamais lancés deux fois ;
  - skills à cadavre (Soul Feast, Consume Corpse...) seulement s'il y a un cadavre ;
  - derviche : les skills qui retirent un enchantement ne prennent qu'un enchantement de derviche ;
  - **une posture (une forme) à la fois** : pas de remplacement, sauf une posture défensive sous forte
    pression ; `Defensive=0` force un skill entretenu (Shadow Form) ;
  - **glyphes** seulement si le sort qu'ils préparent est prêt (`Before=Cost:10` / `Cast:2000`), et ce
    sort passe ensuite en premier ;
  - **wards** : défensives selon la pression sur ceux qui sont dedans, offensives (`Ward=Foes`) selon
    les ennemis dedans, de soutien quand des ennemis approchent ;
  - interrupt au corps à corps : la marche jusqu'à la cible compte ; un interrupt-attaque sert d'attaque
    quand aucun ennemi n'incante ; aucune attaque quand le joueur est aveuglé ;
  - nettoyage de groupe lancé sur soi (Song of Purification...) compté sur les alliés de la zone ;
    soins et résurrections de zone limités à leur zone (Heal Area, Light of Dwayna) ;
  - weapon spells défensifs donnés à l'allié frappé ; pièges pas posés sous le feu ;
  - nouveaux paramètres : `MaxTargets=1` (Strength of Honor, Life Bond), `EndsOn=` (Battle Rage,
    Charging Strike...), `MinionsNear=`, `Spread=1` (maléfices qui s'étendent), `EndFor=LowHealth`
    (Aura of Displacement), qualificatifs `PetAlive/PetDead/PetHurt`, `NotEnchanted`, `NotBlind` ;
    `Need=/Avoid=` jugent aussi le joueur pour un buff qui peut viser un allié.

## Écarts par rapport au cahier des charges

- **Couche 2 calculée à l'exécution**, pas générée dans `Knowledge/Generated/` : la famille est
  déduite par `ZS_Knowledge_Classify` quand la barre change (8 skills). Le fichier généré ne
  deviendra utile qu'avec l'extraction du savoir UtilityAI (P6).
- **Couche 4 (INI par compte) non faite.**
- **`ZS_OnZoneChange` n'existe pas** : inutile, la perception détecte le changement d'instance et
  de barre (`ZS_Reset` existe pour un redémarrage propre).
- **Zaishen ne dépend plus d'UtilityAI** (15/11) : ses propres lecteurs (`Perception/ZS_Read.au3`,
  sur le cœur GwAu3 seulement) lisent agents, effets, bonds, effets visibles, barre de skills et cible
  appelée. Vérifié en compilant Zaishen sans le plugin UtilityAI. Seul le savoir sur les skills vient
  encore d'UtilityAI, mais hors ligne : `Knowledge/Generated/ZS_SkillDefs_UAI.au3` est un fichier figé.
  Le plugin **Pathfinder** appelle encore `UAI_Fight` (à rediriger vers Zaishen le jour où on retire UtilityAI).
- Les effets visibles sont lus pour tous les agents (un parcours de liste par agent) : à surveiller
  sur le temps de perception ; désactivable par `$g_b_ZS_ReadVisibleEffects = False`.

## À confirmer en jeu

- **Nouveaux lecteurs mémoire** (`ZS_Read.au3`) : mêmes offsets et mêmes structures que ceux
  d'UtilityAI qui marchaient en jeu, mais réécrits ; vérifier au premier essai (journal, Save snapshot)
  que les agents, l'énergie, les effets et la barre sont bien lus.
- **Familier** (`Party_GetPetInfo` : propriétaire = nous) et **rangs d'attribut** pour les durées
  (`Attribute_GetPartyAttributeInfo`, aussi pour les attributs PvE qui peuvent revenir à 0).
- Comfort Animal ressuscite-t-il bien un familier mort (version actuelle du skill) ?

- **Mods d'armes** : identifiants déduits des tables d'UtilityAI (`C867` énergie de base des armes de
  caster, `D822` énergie +N, `B820` énergie −N, `F822`/`2823`/`0823`/`1823` énergie conditionnelle,
  `B822` % d'enchantement, `0822`/`0828` HCT, `A823`/`2828` HSR) ; vérifier avec « Save snapshot »
  que l'énergie et le % lus correspondent à l'objet. Set en main reconnu par les ID d'objets tenus.
- **Énergie au changement de set** : supposée ajoutée/cachée immédiatement (wiki « Energy hiding »).

- **Coût en vie et overcast** lus par `Skill_GetSkillInfo(id, "HealthCost" | "Overcast")` au
  changement de barre (octets 0x36 et 0x34 de la structure du skill).
- **Niveau d'attribut des effets** (`AttributeLevel` du cache UtilityAI) : il donne la force des
  effets de coût (Glyph of Lesser Energy, Cultist's Fervor...).
- **Expertise** lue par `Attribute_GetPartyAttributeInfo(EXPERTISE, 0, "CurrentLevel")` à chaque instance.
- **Liaison ritual → esprit** : le premier nouvel esprit allié à moins de 350 dans les ~3 s après le
  lancement est considéré comme le nôtre (le jeu ne dit pas qui l'a créé). Un esprit d'un autre
  joueur posé au même moment au même endroit serait pris pour le nôtre.
- **Urne tenue** : `BundleItemID` non nul juste après un item spell lancé par Zaishen (repli : effet
  du skill sur le joueur). Une urne prise à la main par le joueur n'est pas reconnue.
- **Enchantements entretenus** : lus dans les bonds du joueur (`$g_amx3_PlayerBonds` d'UtilityAI) ;
  vérifier la cible enregistrée pour un enchantement sur soi (0 ou notre ID, les deux sont acceptés),
  et que `Effect_DropBond(skill, -2, 0)` met bien fin à Unyielding Aura.
- La régénération d'énergie (`EnergyRegen` de l'agent) doit bien passer à 0 ou moins quand elle est épuisée.
- **Orientation des tireurs** (`RotationCos/Sin`) et seuils de la vie perdue par seconde (2 à 12 %/s).

## Limites connues (à traiter)

- Les buffs d'alliés hors groupe ne sont pas visibles : on se fie à la durée du skill (`$g_m_ZS_Recent`).
- Les données du jeu donnent une zone à des sorts mono-cible (Flare) : classés `DamageAoE`, sans
  conséquence autre qu'un bonus aux groupes serrés.
- Un enchantement n'est reconnu comme « entretenu » qu'après l'avoir vu entretenu une fois : le
  premier lancement n'est donc pas limité.
- Unyielding Aura ressuscite un membre **au hasard** : avec plusieurs morts, on ne choisit pas lequel.
- Non repris : Rampage as One / Never Rampage Alone / Heal as One (familier vu, mais pas leur logique),
  Extend Enchantments avant Vow of Strength, jonglage d'adrénaline Brawling.
- **Refrains du parangon** : relancés quand ils finissent, pas renouvelés par les cris (coûte plus d'énergie).
- Puits et Putrid Explosion : on sait qu'un cadavre existe, pas **où** il est ni qui l'entoure.
- Sorts « Mind » (Mind Burn, Mind Shock...) : l'énergie ennemie n'est pas visible, ce sont de simples nukes.
- Intensity / Signet of Illusions : pas de condition « un sort de zone est prêt » (seuls les glyphes l'ont).
- Descriptions incertaines lors de l'audit, réglages prudents : Spirit to Flesh, Ether Signet,
  Signet of Removal, Keystone Signet, Arcane Conundrum, Lightbringer Signet (non touché).
- `AdrenReq` de quelques skills n'est pas un multiple de 25 (Cleave 80...) : unité à vérifier en jeu.
- Glowing Ice : le jeu demande un maléfice d'eau, Zaishen ne voit que « a un maléfice ».
- `BonusIf` vient de descriptions rédigées : quelques correspondances approximatives possibles
  (visibles dans `Knowledge/Generated/ZS_SkillDefs_UAI.au3`, corrigeables dans `ZS_SkillDefs.au3`).
- D'autres enchantements « dont la fin fait quelque chose » existent peut-être : ils s'ajoutent par
  une ligne `EndFor=` dans `ZS_SkillDefs.au3` (une seule règle pour l'instant : `DeadAlly`).
- Bundles : Zaishen ne se déplace pas pour lâcher une urne au bon endroit (UtilityAI le faisait en
  bloquant jusqu'à 3 s) ; il attend que la condition soit remplie là où il est.
- Effets de coût portés tels quels depuis UtilityAI ; Healer's Covenant et Expert Focus utilisent la
  force de l'effet à son niveau d'attribut (à vérifier sur quelques cas).
- Aucune gestion de la portée d'aggro des groupes non engagés.
- La menace (`ZS_Threat`) combine : ennemis au contact (< 300), ennemis à distance qui attaquent ou
  incantent **orientés** vers la cible (`ZS_AimOf` attribue chaque ennemi à celui d'entre nous qu'il
  vise le mieux), et **vie perdue par seconde** (`ZS_Perception_TrackDamage`, lissée sur ~1 s).
- Interrupts : le temps d'activation **ennemi** est celui de la table, sans ses accélérations
  (Fast Casting ennemi, Mantra...). Le début du sort ennemi est le premier tick où on le voit (jusqu'à
  40 ms de retard) : un hook « SkillLog » (idée de la branche LogicCast) donnerait l'instant exact et la
  cible du sort, non repris pour l'instant (injection dans le client, casse aux mises à jour).
- Vitesse des flèches (0,85 unité/ms) et des lances (1,05) : mesures de LogicCast, à confirmer.

## Prochaines étapes proposées

1. Continuer les essais en jeu et corriger au fil des retours (journal + snapshot).
2. P6 : outil d'extraction du savoir des `CanUse_*` / `BestTarget_*` d'UtilityAI, puis descriptions
   dédiées profession par profession.
3. P2 : table de dangerosité des skills ennemis, dépense d'adrénaline, préparation des conditions requises.
4. P4/P5 : mémoire partagée puis leader / suiveurs.
5. P7 : façade `UAI_Fight` → `ZS_Fight` pour basculer GwFarmer et Pathfinder.
