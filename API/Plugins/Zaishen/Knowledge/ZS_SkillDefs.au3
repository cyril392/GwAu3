#include-once

; Zaishen dedicated skill definitions (layer 3).
; Only skills whose family cannot be deduced from the game data, or that need a parameter, belong here.
; ZS_DefineSkill(id, family, mask, params): family -1 keeps the family deduced from the game data, mask -1 its mask.
; These parameters come on top of the ones generated from UtilityAI (Knowledge/Generated/ZS_SkillDefs_UAI.au3)
; and win key by key. Conditions understood everywhere (see Evaluation/ZS_Requirements.au3):
;   Need= / Prefer= / Avoid=<qualifiers>   on the target (Caster, Hexed, Casting, Knocked, AfterLead, Boss...)
;   Range=n  TargetBelow=f  TargetAbove=f  MinFoes=n  Pick=highest
;   SelfNeed= / SelfNot=<skill IDs>   SelfIs= / SelfIsAny= / SelfIsNot=<qualifiers>
;   MyHPAbove=f  MyHPBelow=f  MyEnergyBelow=n  MinAdjacent=n  SpiritsNear=n
; Parameters understood by the families:
;   Only=Spell      Interrupt: the target must be activating a spell or a chant
;   MinFoes=N       PBAoE / DamageAoE: at least N foes in the area
;   Below=0.5       Heal* / Protect: the target health must be under this fraction
;   BonusBelow=0.5  HealSingle / HealSelf: heals more under this fraction: waits for it unless the target is under 30 %
;   BonusIf=<q>     does more on a target showing qualifier q (+0.15); for an Energy skill, the energy only comes from
;                   such a target (Glowing Gaze: Burning), elsewhere it is used for its damage alone
;   Drop=<rule>     ItemSpell: when to drop the bundle it gives (see ZS_Eval_DropRule). Without it the bundle is kept.
;   Defensive=1     the skill reduces damage taken: only used on someone under pressure
;   Upkeep=1        a core buff of the build: when it is down, putting it back goes before damage
;   EndFor=<rule>   an enchantment the player keeps up whose END does something (see ZS_Eval_EndBuffs):
;                   Zaishen ends it when the rule holds (DeadAlly, LowHealth), then casts it again
;   Defensive=0     never wait for pressure, whatever the game flags say (Shadow Form kept up)
;   MaxTargets=1    a buff kept on that many allies at most (Strength of Honor, Life Bond)
;   EndsOn=<kind>   while its effect is on the player, no skill of that kind: Skill, NonAdrenal, Adrenal
;   MinionsNear=n   at least n of our minions in earshot
;   Spread=1        Hex: worth more on a foe with others around it
;   Ward=Foes       Ward: works on the foes standing in it (else: defensive with Defensive=1, or support)
;   Before=<conds>  Glyph or other preparation (Intensity...): the spell it prepares; only used when one is ready.
;                   Conditions, all needed, comma separated: Cost:n, Cast:ms, Type:Enchantment|Hex|Spell,
;                   Prof:<profession>, Damage, Skill:<id> (glyph default: 10 energy or 2 s of cast)
;   OnPet=1         cast on the player, judged on the player's pet; PetRez=1 also brings a dead pet back,
;                   PetRez=2 only that (Revive Animal)
;   Hold=1          Interrupt attack: never used as a plain attack when nothing is to be stopped
;   Speed=1 | 2     speed skill: used while the player walks, in fights and between them (2: in fights as usual)
;   OutOfCombat=1   a buff also kept up between fights (the others wait for a fight)
;   Corpse=Foes|Allies  corpse skill that works around the corpse it exploits: foes / hurt allies must be there
;                   (wells: Foes by default)

Func ZS_Knowledge_LoadDefs()
	; --- Mesmer: interrupts that only work on spells and chants ---
	ZS_DefineSkill($GC_I_SKILL_ID_POWER_BLOCK, $GC_ZS_FAM_INTERRUPT, -1, "Only=Spell")
	ZS_DefineSkill($GC_I_SKILL_ID_POWER_SPIKE, $GC_ZS_FAM_INTERRUPT, -1, "Only=Spell")
	ZS_DefineSkill($GC_I_SKILL_ID_POWER_LEAK, $GC_ZS_FAM_INTERRUPT, -1, "Only=Spell")
	; UtilityAI kept it for energy under 20: an interrupt is worth more than that
	ZS_DefineSkill($GC_I_SKILL_ID_POWER_DRAIN, $GC_ZS_FAM_INTERRUPT, -1, "Only=Spell|MyEnergyBelow=9999")

	; --- Heals: Zaishen's health tiers decide; only a heal that is better under some health says so ---
	ZS_DefineSkill($GC_I_SKILL_ID_WORD_OF_HEALING, -1, -1, "BonusBelow=0.5")       ; +115 healing under 50 %
	ZS_DefineSkill($GC_I_SKILL_ID_ZEALOUS_BENEDICTION, -1, -1, "BonusBelow=0.5")   ; +7 energy under 50 %

	; --- Hexes that only work when the foe attacks: never on a foe that is not attacking right now;
	;     a fighter before a caster swinging its wand ---
	ZS_DefineSkill($GC_I_SKILL_ID_CLUMSINESS, -1, -1, "Need=Attacking|Prefer=NotCaster")
	ZS_DefineSkill($GC_I_SKILL_ID_INEPTITUDE, -1, -1, "Need=Attacking|Prefer=NotCaster")
	ZS_DefineSkill($GC_I_SKILL_ID_WANDERING_EYE, -1, -1, "Need=Attacking|Prefer=NotCaster")
	ZS_DefineSkill($GC_I_SKILL_ID_EMPATHY, -1, -1, "Need=Attacking|Prefer=NotCaster")

	; --- Hexes against skill users (from the game descriptions) ---
	; CastsOnUs / CastsOnAllies: from the spells the foe was seen casting (its profession before that)
	; Spells that fail when cast on one of OUR allies: foes seen casting at us (a smiting monk too), the one casting first
	ZS_DefineSkill($GC_I_SKILL_ID_GUILT, -1, -1, "Need=CastsOnUs|Prefer=Casting")
	ZS_DefineSkill($GC_I_SKILL_ID_MISTRUST, -1, -1, "Need=CastsOnUs|Prefer=Casting")
	; Spell that fails when cast on ITS allies: healers and supports
	ZS_DefineSkill($GC_I_SKILL_ID_SHAME, -1, -1, "Need=Caster|Prefer=CastsOnAllies,Casting")
	ZS_DefineSkill($GC_I_SKILL_ID_BACKFIRE, -1, -1, "Prefer=Casting")                 ; Need=Caster comes from UtilityAI
	; Any skill: worth most on a boss (elite skill), a caster otherwise; never blocked on a fighter
	ZS_DefineSkill($GC_I_SKILL_ID_DIVERSION, -1, -1, "Need=|Prefer=Boss,Caster")
	ZS_DefineSkill($GC_I_SKILL_ID_MIGRAINE, -1, -1, "Need=|Prefer=Caster")
	ZS_DefineSkill($GC_I_SKILL_ID_VISIONS_OF_REGRET, -1, -1, "Prefer=Caster|MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_SPITEFUL_SPIRIT, -1, -1, "Prefer=Attacking|MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_OVERLOAD, -1, -1, "Prefer=Casting|BonusIf=Casting")
	ZS_DefineSkill($GC_I_SKILL_ID_ENERGY_SURGE, -1, -1, "Prefer=Caster")
	; Ends early when the foe uses a skill: on the ones that use few
	ZS_DefineSkill($GC_I_SKILL_ID_WASTRELS_WORRY, -1, -1, "Avoid=Casting|Prefer=NotCaster")
	ZS_DefineSkill($GC_I_SKILL_ID_WASTRELS_DEMISE, -1, -1, "Avoid=Casting|Prefer=NotCaster")

	; --- Energy only on a target in some state: prefer such a target, priority when energy is low ---
	ZS_DefineSkill($GC_I_SKILL_ID_GLOWING_GAZE1, -1, -1, "BonusIf=Burning")     ; damage, + energy if burning
	ZS_DefineSkill($GC_I_SKILL_ID_GLOWING_GAZE2, -1, -1, "BonusIf=Burning")
	ZS_DefineSkill($GC_I_SKILL_ID_GLOWING_ICE, -1, -1, "Prefer=WaterHexed|BonusIf=WaterHexed")  ; our own water hexes (see ZS_WaterHexed)
	ZS_DefineSkill($GC_I_SKILL_ID_GLOWING_SIGNET, -1, -1, "Need=Burning")      ; does nothing else: only on a burning foe

	; --- Conditions UtilityAI wrote in code that the extraction tool cannot read (Tools/uai_review.md) ---
	; Dervish attacks that strip an enchantment: handled for every such skill by Evaluation/ZS_Dervish.au3
	ZS_DefineSkill($GC_I_SKILL_ID_IMBUE_HEALTH, $GC_ZS_FAM_HEAL_SINGLE, -1, "MyHPAbove=0.6")   ; a heal paid with your own health
	ZS_DefineSkill($GC_I_SKILL_ID_NATURAL_TEMPER, -1, -1, "SelfIsNot=Enchanted")
	; Anti-knockdown and armor: put up when hit (the player cannot act once knocked down)
	ZS_DefineSkill($GC_I_SKILL_ID_I_AM_UNSTOPPABLE, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_CYCLONE_AXE, -1, -1, "MinAdjacent=2")
	; The hex removal is the point; the damage around the ally is a bonus
	ZS_DefineSkill($GC_I_SKILL_ID_SMITE_HEX, -1, -1, "MinFoes=0")
	ZS_DefineSkill($GC_I_SKILL_ID_SPIRIT_TRANSFER, $GC_ZS_FAM_HEAL_SINGLE, -1, "SpiritsNear=1")   ; heals from a spirit's health
	ZS_DefineSkill($GC_I_SKILL_ID_GHOSTMIRROR_LIGHT, $GC_ZS_FAM_HEAL_SINGLE, -1, "SpiritsNear=")  ; a spirit only adds to it
	; Not carried over (rare in PvE): Brawling adrenaline juggling.
	; Paragon refrains and finales: no definition needed, see ZS_Eval_EchoRenewal (shouts and chants keep them going).

	; --- Enchantment removal: the game data has no flag for it ---
	ZS_DefineSkill($GC_I_SKILL_ID_INSPIRED_ENCHANTMENT, $GC_ZS_FAM_ENCH_REMOVAL)
	ZS_DefineSkill($GC_I_SKILL_ID_DRAIN_ENCHANTMENT, $GC_ZS_FAM_ENCH_REMOVAL, -1, "MyEnergyBelow=9999")  ; strips even at full energy
	ZS_DefineSkill($GC_I_SKILL_ID_JAUNDICED_GAZE, $GC_ZS_FAM_ENCH_REMOVAL)
	ZS_DefineSkill($GC_I_SKILL_ID_SHATTER_ENCHANTMENT, $GC_ZS_FAM_ENCH_REMOVAL)
	ZS_DefineSkill($GC_I_SKILL_ID_REND_ENCHANTMENTS, $GC_ZS_FAM_ENCH_REMOVAL)
	ZS_DefineSkill($GC_I_SKILL_ID_STRIP_ENCHANTMENT, $GC_ZS_FAM_ENCH_REMOVAL)

	; --- Ritualist bundles (urns and ashes): when dropping them is worth it ---
	ZS_DefineSkill($GC_I_SKILL_ID_GENEROUS_WAS_TSUNGRAI, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=LowHealth")      ; heal on drop
	ZS_DefineSkill($GC_I_SKILL_ID_PROTECTIVE_WAS_KAOLAI, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=PartyHurt")      ; party heal on drop
	ZS_DefineSkill($GC_I_SKILL_ID_ENERGETIC_WAS_LEE_SA, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=LowEnergy")       ; energy on drop
	ZS_DefineSkill($GC_I_SKILL_ID_LIVELY_WAS_NAOMEI, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=DeadAlly")           ; resurrection on drop
	ZS_DefineSkill($GC_I_SKILL_ID_PURE_WAS_LI_MING, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=AlliesConditioned")   ; condition removal on drop
	ZS_DefineSkill($GC_I_SKILL_ID_RESILIENT_WAS_XIKO, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=SelfConditioned")   ; self condition removal on drop
	ZS_DefineSkill($GC_I_SKILL_ID_CRUEL_WAS_DAOSHEN, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=FoesNearby")         ; damage to nearby foes
	ZS_DefineSkill($GC_I_SKILL_ID_GRASPING_WAS_KUURONG, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=FoesNearby")      ; damage + knockdown
	ZS_DefineSkill($GC_I_SKILL_ID_DEFIANT_WAS_XINRAE, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=FoesNearby")
	ZS_DefineSkill($GC_I_SKILL_ID_DESTRUCTIVE_WAS_GLAIVE, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=FoesInArea")    ; damage in the area
	ZS_DefineSkill($GC_I_SKILL_ID_BLIND_WAS_MINGSON, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=FightersNearby")     ; blinds nearby attackers
	ZS_DefineSkill($GC_I_SKILL_ID_ANGUISHED_WAS_LINGWAH, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=RitHexesRecharging") ; its bonus is spent
	ZS_DefineSkill($GC_I_SKILL_ID_COURAGEOUS_WAS_SAIDRA, $GC_ZS_FAM_ITEM_SPELL, -1, "Drop=PartyHurt")      ; party heal on drop
	; Vocal, Attuned, Vengeful, Tranquil and Mighty Was...: no drop effect, the bundle itself is the effect: kept

	; --- Corpse skills that work around the corpse (the nearest one, chosen by the game) ---
	; Wells work on the foes standing in them unless told otherwise; Putrid Explosion hits the foes near the corpse
	ZS_DefineSkill($GC_I_SKILL_ID_WELL_OF_BLOOD, -1, -1, "Corpse=Allies")
	ZS_DefineSkill($GC_I_SKILL_ID_WELL_OF_POWER, -1, -1, "Corpse=Allies")
	ZS_DefineSkill($GC_I_SKILL_ID_PUTRID_EXPLOSION, -1, -1, "Corpse=Foes")

	; --- Enchantments whose end does the job ---
	; Unyielding Aura: kept up on oneself (heals +60 %); when it ends, a dead party member is resurrected.
	; Casting it does not resurrect anyone: it is put up, and ended when someone dies.
	ZS_DefineSkill($GC_I_SKILL_ID_UNYIELDING_AURA, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF, "Upkeep=1|EndFor=DeadAlly")
	; Aura of Displacement: its end takes the player back to where it was cast
	ZS_DefineSkill($GC_I_SKILL_ID_AURA_OF_DISPLACEMENT, -1, -1, "EndFor=LowHealth")

	ZS_LoadDefs_Audit()
EndFunc   ;==>ZS_Knowledge_LoadDefs

;~ Description: Definitions from the coverage audit of 15/11/2026 (one agent per group of professions, checked against
;~ the game data and the code). Grouped by what was wrong.
Func ZS_LoadDefs_Audit()
	; ===== Never used by the AI: they would throw the player out of a fight or do nothing useful in it =====
	ZS_DefineSkill($GC_I_SKILL_ID_CHARM_ANIMAL, $GC_ZS_FAM_NONE)         ; 10 s cast on our own pet
	ZS_DefineSkill($GC_I_SKILL_ID_CHARM_ANIMAL_CODEX, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_SIGNET_OF_CAPTURE, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_LEAVE_JUNUNDU, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_DISMOUNT_SIEGE_DEVOURER, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_UNKNOWN_JUNUNDU_ABILITY, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_NECROTIC_TRAVERSAL, $GC_ZS_FAM_NONE)   ; teleports to any corpse
	ZS_DefineSkill($GC_I_SKILL_ID_RECALL, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_RETURN, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_SPIRIT_WALK, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_SWAP, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_DRAW_SPIRIT, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_REVERSAL_OF_DEATH, $GC_ZS_FAM_NONE)    ; death penalty, not a fight skill
	ZS_DefineSkill($GC_I_SKILL_ID_COMPANIONSHIP, $GC_ZS_FAM_NONE)
	ZS_DefineSkill($GC_I_SKILL_ID_ARCANE_MIMICRY, $GC_ZS_FAM_NONE)

	; ===== Pet (Zaishen reads the player's pet from the game) =====
	ZS_DefineSkill($GC_I_SKILL_ID_COMFORT_ANIMAL, $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_TM_SELF, "OnPet=1|PetRez=1|Below=0.7")
	ZS_DefineSkill($GC_I_SKILL_ID_REVIVE_ANIMAL, $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_TM_SELF, "OnPet=1|PetRez=2")
	; Shouts that buff the pet only: judged on the pet (its effect is on it), never without a living pet
	ZS_DefineSkill($GC_I_SKILL_ID_CALL_OF_PROTECTION, -1, -1, "OnPet=1|SelfIs=PetAlive")
	ZS_DefineSkill($GC_I_SKILL_ID_CALL_OF_HASTE, -1, -1, "OnPet=1|SelfIs=PetAlive")
	ZS_DefineSkill($GC_I_SKILL_ID_SYMBIOTIC_BOND, -1, -1, "OnPet=1|SelfIs=PetAlive")
	ZS_DefineSkill($GC_I_SKILL_ID_OTYUGHS_CRY, -1, -1, "OnPet=1|SelfIs=PetAlive")
	ZS_DefineSkill($GC_I_SKILL_ID_PREDATORY_BOND, -1, -1, "OnPet=1|SelfIs=PetAlive")
	; "You and your animal companion": nothing without a living pet
	ZS_DefineSkill($GC_I_SKILL_ID_RAMPAGE_AS_ONE, -1, -1, "SelfIs=PetAlive")
	ZS_DefineSkill($GC_I_SKILL_ID_NEVER_RAMPAGE_ALONE, -1, -1, "SelfIs=PetAlive")

	; ===== Heals the rules took for buffs =====
	ZS_DefineSkill($GC_I_SKILL_ID_MYSTIC_HEALING, $GC_ZS_FAM_HEAL_PARTY, $GC_ZS_TM_SELF)
	ZS_DefineSkill($GC_I_SKILL_ID_HEART_OF_SHADOW, $GC_ZS_FAM_HEAL_SELF, $GC_ZS_TM_SELF)
	ZS_DefineSkill($GC_I_SKILL_ID_EBON_ESCAPE, $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_TM_ALLY)
	ZS_DefineSkill($GC_I_SKILL_ID_MENDING_GRIP, $GC_ZS_FAM_HEAL_SINGLE, -1, "Prefer=Conditioned")
	ZS_DefineSkill($GC_I_SKILL_ID_VITALITY_TRANSFER, $GC_ZS_FAM_HEAL_SINGLE)
	ZS_DefineSkill($GC_I_SKILL_ID_SPIRITUAL_HEALING, $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_TM_ALLY)
	ZS_DefineSkill($GC_I_SKILL_ID_SPIRITUAL_HEALING_REAPER_SKILL, $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_TM_ALLY)
	ZS_DefineSkill($GC_I_SKILL_ID_FEAST_OF_SOULS, $GC_ZS_FAM_HEAL_PARTY, $GC_ZS_TM_SELF, "SpiritsNear=2")  ; kills our spirits
	ZS_DefineSkill($GC_I_SKILL_ID_HEALING_SPRING, $GC_ZS_FAM_HEAL_PARTY, $GC_ZS_TM_SELF)
	ZS_DefineSkill($GC_I_SKILL_ID_HEALING_RING, $GC_ZS_FAM_HEAL_PARTY)
	ZS_DefineSkill($GC_I_SKILL_ID_BREATH_OF_THE_GREAT_DWARF, $GC_ZS_FAM_HEAL_PARTY, $GC_ZS_TM_SELF)
	ZS_DefineSkill($GC_I_SKILL_ID_INFUSE_HEALTH, -1, -1, "MyHPAbove=0.7|Below=0.4")   ; costs half our health
	ZS_DefineSkill($GC_I_SKILL_ID_ANGELIC_PROTECTION, $GC_ZS_FAM_PROTECT, $GC_ZS_TM_ALLY)

	; ===== Cleanses the rules took for buffs =====
	ZS_DefineSkill($GC_I_SKILL_ID_DISMISS_CONDITION, $GC_ZS_FAM_COND_REMOVAL)
	ZS_DefineSkill($GC_I_SKILL_ID_FOUL_FEAST, $GC_ZS_FAM_COND_REMOVAL, $GC_ZS_TM_ALLY)
	ZS_DefineSkill($GC_I_SKILL_ID_SIGNET_OF_REMOVAL, $GC_ZS_FAM_HEX_REMOVAL)
	ZS_DefineSkill($GC_I_SKILL_ID_PURIFYING_PRAYER, $GC_ZS_FAM_HEX_REMOVAL)
	ZS_DefineSkill($GC_I_SKILL_ID_ANTIDOTE_SIGNET, $GC_ZS_FAM_COND_REMOVAL, $GC_ZS_TM_SELF)

	; ===== Damage reduction: only for someone being hit =====
	ZS_DefineSkill($GC_I_SKILL_ID_DEFY_PAIN, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF, "Defensive=1")   ; was taken for an area skill
	ZS_DefineSkill($GC_I_SKILL_ID_ENDURE_PAIN, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_MENTAL_BLOCK, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SAVE_YOURSELVES_LUXON, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SAVE_YOURSELVES_KURZICK, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_THERES_NOTHING_TO_FEAR, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_THERES_NOTHING_TO_FEAR_THACKERAY, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_HOLY_WRATH, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_RETRIBUTION, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_REVERSAL_OF_DAMAGE, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SHIELD_OF_JUDGMENT, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SPELL_BREAKER, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SEED_OF_LIFE, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_DIVINE_INTERVENTION, -1, -1, "Defensive=1|TargetBelow=0.5")
	ZS_DefineSkill($GC_I_SKILL_ID_JUDGES_INTERVENTION, -1, -1, "Defensive=1|TargetBelow=0.5")
	; Elementalist armors (Armor of Earth also slows the player down)
	ZS_DefineSkill($GC_I_SKILL_ID_ARMOR_OF_EARTH, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_KINETIC_ARMOR, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_STONEFLESH_AURA, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_OBSIDIAN_FLESH, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_ARMOR_OF_FROST, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_ARMOR_OF_MIST, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_FRIGID_ARMOR, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_MAGNETIC_AURA, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF)   ; its area only matters overcast
	ZS_DefineSkill($GC_I_SKILL_ID_SWIRLING_AURA, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF)
	ZS_DefineSkill($GC_I_SKILL_ID_STONE_SHEATH, $GC_ZS_FAM_ALLY_BUFF, $GC_ZS_TM_ALLY, "Defensive=1")  ; "you and target ally"
	; Damage type the mantras resist is unknown to Zaishen: at least only when hit
	ZS_DefineSkill($GC_I_SKILL_ID_MANTRA_OF_FLAME, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_MANTRA_OF_FROST, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_MANTRA_OF_LIGHTNING, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_MANTRA_OF_EARTH, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_ELEMENTAL_RESISTANCE, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_PHYSICAL_RESISTANCE, -1, -1, "Defensive=1")
	; Protective weapon spells: on whoever is being hit
	ZS_DefineSkill($GC_I_SKILL_ID_WEAPON_OF_WARDING, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_XINRAES_WEAPON, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_WEAPON_OF_REMEDY, -1, -1, "Defensive=1|Prefer=Conditioned")
	ZS_DefineSkill($GC_I_SKILL_ID_VENGEFUL_WEAPON, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_WEAPON_OF_SHADOW, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_RESILIENT_WEAPON, -1, -1, "Defensive=1|Need=HexedOrConditioned")
	ZS_DefineSkill($GC_I_SKILL_ID_SPIRIT_LIGHT_WEAPON, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_VITAL_WEAPON, -1, -1, "Defensive=1")
	; Shadow Form: perma builds keep it up all the time (its "block" flag would wait for pressure)
	ZS_DefineSkill($GC_I_SKILL_ID_SHADOW_FORM, -1, -1, "Defensive=0|Upkeep=1")

	; ===== Wards =====
	ZS_DefineSkill($GC_I_SKILL_ID_WARD_AGAINST_MELEE, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_WARD_AGAINST_ELEMENTS, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_WARD_AGAINST_HARM, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_WARD_OF_STABILITY, -1, -1, "Defensive=1")
	ZS_DefineSkill($GC_I_SKILL_ID_WARD_AGAINST_FOES, -1, -1, "Ward=Foes|MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_TEINAIS_HEAT, -1, -1, "Ward=Foes|MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_WARD_OF_WEAKNESS, -1, -1, "Ward=Foes|MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_RADIATION_FIELD, $GC_ZS_FAM_PBAOE, $GC_ZS_TM_SELF, "MinFoes=2")

	; ===== Core of the build: up before damage =====
	ZS_DefineSkill($GC_I_SKILL_ID_AVATAR_OF_BALTHAZAR, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_AVATAR_OF_GRENTH, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_AVATAR_OF_LYSSA, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_AVATAR_OF_MELANDRU, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_AVATAR_OF_DWAYNA, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SOUL_TWISTING, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF, "Upkeep=1")   ; was an area skill of radius 5
	ZS_DefineSkill($GC_I_SKILL_ID_OVER_THE_LIMIT, -1, -1, "Upkeep=1")
	; Ranger preparations: they shape every arrow
	ZS_DefineSkill($GC_I_SKILL_ID_APPLY_POISON, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_BARBED_ARROWS, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_IGNITE_ARROWS, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_KINDLE_ARROWS, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_READ_THE_WIND, -1, -1, "Upkeep=1")
	ZS_DefineSkill($GC_I_SKILL_ID_GLASS_ARROWS, -1, -1, "Upkeep=1")

	; ===== Buffs the rules took for area skills (a small area of the game data) =====
	ZS_DefineSkill($GC_I_SKILL_ID_KEYSTONE_SIGNET, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF)
	; Preparations: only right before a spell they work on is cast (see Before= above)
	ZS_DefineSkill($GC_I_SKILL_ID_INTENSITY, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF, "Before=Prof:Elementalist,Damage")
	ZS_DefineSkill($GC_I_SKILL_ID_SIGNET_OF_ILLUSIONS, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF, "Before=Prof:Mesmer")
	ZS_DefineSkill($GC_I_SKILL_ID_EXTEND_ENCHANTMENTS, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF, "Before=Type:Enchantment")
	ZS_DefineSkill($GC_I_SKILL_ID_SPIRIT_CHANNELING, $GC_ZS_FAM_ENERGY_BUFF, $GC_ZS_TM_SELF, "SpiritsNear=1")
	ZS_DefineSkill($GC_I_SKILL_ID_GHOSTLY_HASTE, $GC_ZS_FAM_SELF_BUFF, $GC_ZS_TM_SELF, "SpiritsNear=1")
	ZS_DefineSkill($GC_I_SKILL_ID_ARMOR_OF_UNFEELING, -1, -1, "SpiritsNear=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SIGNET_OF_SPIRITS, $GC_ZS_FAM_SPIRIT, $GC_ZS_TM_SELF)
	; "You and target ally" skills: the game gives them the spirit target type
	ZS_DefineSkill($GC_I_SKILL_ID_DOUBLE_DRAGON, $GC_ZS_FAM_ALLY_BUFF, $GC_ZS_TM_ALLY, "Prefer=Melee|MinFoes=1")
	ZS_DefineSkill($GC_I_SKILL_ID_RIDE_THE_LIGHTNING, $GC_ZS_FAM_DAMAGE, $GC_ZS_TM_FOE)
	; Hexes cast on oneself that hit the foes around
	ZS_DefineSkill($GC_I_SKILL_ID_FROZEN_BURST, $GC_ZS_FAM_PBAOE, $GC_ZS_TM_SELF, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_GRASPING_EARTH, $GC_ZS_FAM_PBAOE, $GC_ZS_TM_SELF, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_AMITY, $GC_ZS_FAM_PBAOE, $GC_ZS_TM_SELF, "MinFoes=2")

	; ===== Interrupts the game data does not flag =====
	ZS_DefineSkill($GC_I_SKILL_ID_MAGEBANE_SHOT, $GC_ZS_FAM_INTERRUPT)
	ZS_DefineSkill($GC_I_SKILL_ID_DISRUPTING_SHOT, $GC_ZS_FAM_INTERRUPT)
	ZS_DefineSkill($GC_I_SKILL_ID_CONCUSSION_SHOT, $GC_ZS_FAM_INTERRUPT, -1, "Only=Spell")
	ZS_DefineSkill($GC_I_SKILL_ID_DISRUPTING_THROW, $GC_ZS_FAM_INTERRUPT, -1, "Need=Conditioned")
	ZS_DefineSkill($GC_I_SKILL_ID_CRY_OF_PAIN, $GC_ZS_FAM_INTERRUPT, -1, "Need=|Prefer=Hexed")
	; Interrupts any action, knocks down the foes around when it was a skill (was taken for area damage)
	ZS_DefineSkill($GC_I_SKILL_ID_PSYCHIC_INSTABILITY, $GC_ZS_FAM_INTERRUPT, -1, "Need=")

	; ===== Area damage: worth a pack, not one foe, and not foes on the run =====
	ZS_DefineSkill($GC_I_SKILL_ID_METEOR_SHOWER, -1, -1, "MinFoes=2|Avoid=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_FIRE_STORM, -1, -1, "MinFoes=2|Avoid=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_MAELSTROM, -1, -1, "MinFoes=2|Avoid=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_CHAOS_STORM, -1, -1, "MinFoes=2|Avoid=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_SEARING_HEAT, -1, -1, "MinFoes=2|Avoid=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_SAVANNAH_HEAT, -1, -1, "MinFoes=2|Avoid=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_SANDSTORM, -1, -1, "MinFoes=2|Avoid=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_BED_OF_COALS, -1, -1, "MinFoes=2|Avoid=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_ERUPTION, -1, -1, "MinFoes=2|Avoid=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_RODGORTS_INVOCATION, -1, -1, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_EARTHQUAKE, -1, -1, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_DRAGONS_STOMP, -1, -1, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_LIGHTNING_STORM, -1, -1, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_DEEP_FREEZE, -1, -1, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_ICE_SPIKES, -1, -1, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_BALTHAZARS_AURA, -1, -1, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_UNHOLY_FEAST, -1, -1, "MinFoes=1")
	ZS_DefineSkill($GC_I_SKILL_ID_WHIRLWIND_ATTACK, -1, -1, "MinAdjacent=2")
	; Hexes that spread to the foes around their target
	ZS_DefineSkill($GC_I_SKILL_ID_MARK_OF_RODGORT, -1, -1, "Spread=1")
	ZS_DefineSkill($GC_I_SKILL_ID_MARK_OF_PAIN, -1, -1, "Spread=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SUFFERING, -1, -1, "Spread=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SHADOW_OF_FEAR, -1, -1, "Spread=1")
	ZS_DefineSkill($GC_I_SKILL_ID_MEEKNESS, -1, -1, "Spread=1")
	ZS_DefineSkill($GC_I_SKILL_ID_RECKLESS_HASTE, -1, -1, "Spread=1")
	ZS_DefineSkill($GC_I_SKILL_ID_ULCEROUS_LUNGS, -1, -1, "Spread=1")
	ZS_DefineSkill($GC_I_SKILL_ID_PANIC, -1, -1, "Spread=1|MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_SHARED_BURDEN, -1, -1, "Spread=1|MinFoes=2")

	; ===== Conditions on the target the skill does nothing without =====
	ZS_DefineSkill($GC_I_SKILL_ID_DISCORD, -1, -1, "Need=Conditioned,HexedOrEnchanted")
	ZS_DefineSkill($GC_I_SKILL_ID_NECROSIS, -1, -1, "Need=HexedOrConditioned|Prefer=")
	ZS_DefineSkill($GC_I_SKILL_ID_GAZE_OF_CONTEMPT, -1, -1, "Need=Enchanted|TargetAbove=0.5")
	ZS_DefineSkill($GC_I_SKILL_ID_AWE, -1, -1, "Need=Knocked|Prefer=")
	ZS_DefineSkill($GC_I_SKILL_ID_SIGNET_OF_HUMILITY, -1, -1, "Need=Boss")              ; disables an elite skill
	ZS_DefineSkill($GC_I_SKILL_ID_ARCANE_CONUNDRUM, -1, -1, "Need=Caster|Prefer=Casting")
	ZS_DefineSkill($GC_I_SKILL_ID_SMOOTH_CRIMINAL, -1, -1, "Need=Caster")
	ZS_DefineSkill($GC_I_SKILL_ID_BLINDING_FLASH, -1, -1, "Avoid=Blind|Prefer=NotCaster,Attacking|Pick=")
	ZS_DefineSkill($GC_I_SKILL_ID_YOU_MOVE_LIKE_A_DWARF, -1, -1, "Prefer=Casting,Monk")
	; Bonus on a target in some state
	ZS_DefineSkill($GC_I_SKILL_ID_SEARING_FLAMES1, -1, -1, "BonusIf=Burning")
	ZS_DefineSkill($GC_I_SKILL_ID_SEARING_FLAMES2, -1, -1, "BonusIf=Burning")
	ZS_DefineSkill($GC_I_SKILL_ID_VILE_MIASMA, -1, -1, "Prefer=Conditioned|BonusIf=Conditioned")
	ZS_DefineSkill($GC_I_SKILL_ID_STUNNING_STRIKE, -1, -1, "BonusIf=Conditioned")
	ZS_DefineSkill($GC_I_SKILL_ID_LIQUID_FLAME, -1, -1, "BonusIf=Attacking,Casting")
	ZS_DefineSkill($GC_I_SKILL_ID_ICY_PRISM, -1, -1, "BonusIf=Hexed")
	ZS_DefineSkill($GC_I_SKILL_ID_WATER_TRIDENT, -1, -1, "BonusIf=Moving")
	ZS_DefineSkill($GC_I_SKILL_ID_UNNATURAL_SIGNET, -1, -1, "BonusIf=HexedOrEnchanted|Prefer=")
	ZS_DefineSkill($GC_I_SKILL_ID_BODY_SHOT, -1, -1, "BonusIf=Weakness")
	ZS_DefineSkill($GC_I_SKILL_ID_NEEDLING_SHOT, -1, -1, "Prefer=Below50HP")
	ZS_DefineSkill($GC_I_SKILL_ID_VAPOR_BLADE, -1, -1, "BonusIf=|Prefer=NotEnchanted")   ; half damage on an enchanted foe
	ZS_DefineSkill($GC_I_SKILL_ID_IMAGES_OF_REMORSE, -1, -1, "Need=|BonusIf=Attacking")
	ZS_DefineSkill($GC_I_SKILL_ID_BARBED_SPEAR, -1, -1, "Avoid=")
	; Hexes that punish attacking: fighters first, never blocked on a caster
	ZS_DefineSkill($GC_I_SKILL_ID_FAINTHEARTEDNESS, -1, -1, "Need=|Prefer=NotCaster,Attacking")
	ZS_DefineSkill($GC_I_SKILL_ID_INSIDIOUS_PARASITE, -1, -1, "Need=|Prefer=NotCaster,Attacking")
	ZS_DefineSkill($GC_I_SKILL_ID_PRICE_OF_FAILURE, -1, -1, "Need=|Prefer=NotCaster,Attacking")

	; ===== Buffs for the right ally =====
	ZS_DefineSkill($GC_I_SKILL_ID_STRENGTH_OF_HONOR, -1, -1, "Need=Melee|Prefer=Attacking|MaxTargets=1")
	ZS_DefineSkill($GC_I_SKILL_ID_BALTHAZARS_SPIRIT, -1, -1, "Prefer=Melee,Attacking")
	ZS_DefineSkill($GC_I_SKILL_ID_JUDGES_INSIGHT, -1, -1, "Need=NotCaster|Prefer=Attacking")
	ZS_DefineSkill($GC_I_SKILL_ID_TAINTED_FLESH, -1, -1, "Need=Melee")
	ZS_DefineSkill($GC_I_SKILL_ID_BLOOD_IS_POWER, -1, -1, "Need=Caster|Prefer=Monk,Casting|MyHPAbove=0.6")
	ZS_DefineSkill($GC_I_SKILL_ID_BLOOD_RITUAL, -1, -1, "Need=Caster|Prefer=Monk,Casting|MyHPAbove=0.6")
	ZS_DefineSkill($GC_I_SKILL_ID_INSPIRATIONAL_SPEECH, -1, -1, "Avoid=Caster|Prefer=Attacking")
	ZS_DefineSkill($GC_I_SKILL_ID_LIFE_BOND, -1, -1, "MaxTargets=1")
	ZS_DefineSkill($GC_I_SKILL_ID_LIFE_BARRIER, -1, -1, "MaxTargets=1")
	ZS_DefineSkill($GC_I_SKILL_ID_BRUTAL_WEAPON, -1, -1, "Avoid=Enchanted")
	ZS_DefineSkill($GC_I_SKILL_ID_WEAPON_OF_QUICKENING, -1, -1, "Need=Caster")
	ZS_DefineSkill($GC_I_SKILL_ID_SPLINTER_WEAPON, -1, -1, "Prefer=Melee,Attacking")
	; Paragon finales and refrains: buffs whose effect comes when a shout or chant ends on the ally
	ZS_DefineSkill($GC_I_SKILL_ID_FINALE_OF_RESTORATION, $GC_ZS_FAM_ALLY_BUFF)
	ZS_DefineSkill($GC_I_SKILL_ID_MENDING_REFRAIN, $GC_ZS_FAM_ALLY_BUFF)
	ZS_DefineSkill($GC_I_SKILL_ID_PURIFYING_FINALE, $GC_ZS_FAM_ALLY_BUFF)

	; ===== Conditions on the player =====
	ZS_DefineSkill($GC_I_SKILL_ID_PLAGUE_SIGNET, -1, -1, "SelfIs=Conditioned")      ; sends our conditions
	ZS_DefineSkill($GC_I_SKILL_ID_PLAGUE_TOUCH, -1, -1, "SelfIs=Conditioned")
	ZS_DefineSkill($GC_I_SKILL_ID_PLAGUE_SENDING, -1, -1, "SelfIs=Conditioned")
	ZS_DefineSkill($GC_I_SKILL_ID_FRENZY, -1, -1, "SelfIs=Attacking|MyHPAbove=0.5")  ; double damage taken
	ZS_DefineSkill($GC_I_SKILL_ID_CRITICAL_AGILITY, -1, -1, "SelfIs=Attacking")
	ZS_DefineSkill($GC_I_SKILL_ID_WARRIORS_ENDURANCE, -1, -1, "MyEnergyBelow=20")
	ZS_DefineSkill($GC_I_SKILL_ID_ETHER_LORD, -1, -1, "MyEnergyBelow=10")           ; "you lose all energy"
	ZS_DefineSkill($GC_I_SKILL_ID_ETHER_PRODIGY, -1, -1, "MyEnergyBelow=15")        ; ends all our enchantments later
	ZS_DefineSkill($GC_I_SKILL_ID_ETHER_SIGNET, $GC_ZS_FAM_ENERGY, $GC_ZS_TM_SELF, "MyEnergyBelow=10")
	ZS_DefineSkill($GC_I_SKILL_ID_SPIRIT_SIPHON, $GC_ZS_FAM_ENERGY, $GC_ZS_TM_SELF, "SpiritsNear=1")
	ZS_DefineSkill($GC_I_SKILL_ID_RECLAIM_ESSENCE, -1, -1, "MyEnergyBelow=10|SpiritsNear=1")   ; kills all our spirits
	ZS_DefineSkill($GC_I_SKILL_ID_ORDER_OF_PAIN, -1, -1, "MyHPAbove=0.5")
	ZS_DefineSkill($GC_I_SKILL_ID_ORDER_OF_THE_VAMPIRE, -1, -1, "MyHPAbove=0.5")
	ZS_DefineSkill($GC_I_SKILL_ID_DARK_FURY, -1, -1, "MyHPAbove=0.5")
	ZS_DefineSkill($GC_I_SKILL_ID_DEATHS_CHARGE, -1, -1, "MyHPBelow=0.6")           ; a getaway, no damage
	ZS_DefineSkill($GC_I_SKILL_ID_BRAWLING_BLOCK, -1, -1, "SelfIsNot=Dazed")
	ZS_DefineSkill($GC_I_SKILL_ID_JUNUNDU_TUNNEL, -1, -1, "MinAdjacent=1")
	ZS_DefineSkill($GC_I_SKILL_ID_JUNUNDU_FEAST, $GC_ZS_FAM_CORPSE, $GC_ZS_TM_SELF)
	ZS_DefineSkill($GC_I_SKILL_ID_AURA_OF_THE_LICH, $GC_ZS_FAM_CORPSE)
	; Speed: only while walking, in a fight or between fights (following the leader); never instead of a
	; fighting stance. Speed=2: its other effect is used in fights as usual (Escape blocks), speed out of combat.
	ZS_DefineSkill($GC_I_SKILL_ID_SPRINT, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_DASH, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_STORM_DJINNS_HASTE, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_ZOJUNS_HASTE, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_BURNING_SPEED, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_PIOUS_HASTE, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_ENCHANTED_HASTE, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_FEATHERFOOT_GRACE, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_CHARGE, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_FALL_BACK, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_RETREAT, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_INCOMING, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_MAKE_HASTE, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_HASTY_REFRAIN, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_WINDBORNE_SPEED, -1, -1, "Speed=1")
	ZS_DefineSkill($GC_I_SKILL_ID_ESCAPE, -1, -1, "Speed=2")
	ZS_DefineSkill($GC_I_SKILL_ID_DARK_ESCAPE, -1, -1, "Defensive=1|Speed=2")
	; Effects that end when the player uses some kind of skill: nothing else of that kind while they last
	ZS_DefineSkill($GC_I_SKILL_ID_BATTLE_RAGE, -1, -1, "EndsOn=NonAdrenal")
	ZS_DefineSkill($GC_I_SKILL_ID_BULLS_CHARGE, -1, -1, "EndsOn=Skill")
	ZS_DefineSkill($GC_I_SKILL_ID_CHARGING_STRIKE, -1, -1, "EndsOn=Skill")
	ZS_DefineSkill($GC_I_SKILL_ID_DISCIPLINED_STANCE, -1, -1, "EndsOn=Adrenal")

	; ===== Minions and spirits we would sacrifice for nothing =====
	ZS_DefineSkill($GC_I_SKILL_ID_TASTE_OF_DEATH, -1, -1, "MyHPBelow=0.5")
	ZS_DefineSkill($GC_I_SKILL_ID_DRAIN_MINION, -1, $GC_ZS_TM_MINION, "MyHPBelow=0.5")
	ZS_DefineSkill($GC_I_SKILL_ID_PUTRID_FLESH, -1, $GC_ZS_TM_MINION, "MinFoes=2")
	ZS_DefineSkill($GC_I_SKILL_ID_DEATH_NOVA, -1, $GC_ZS_TM_MINION)
	ZS_DefineSkill($GC_I_SKILL_ID_RUPTURE_SOUL, -1, -1, "Need=Spirit|TargetBelow=0.5|MinFoes=1")
	ZS_DefineSkill($GC_I_SKILL_ID_SPIRIT_TO_FLESH, -1, -1, "TargetBelow=0.3")
EndFunc   ;==>ZS_LoadDefs_Audit
