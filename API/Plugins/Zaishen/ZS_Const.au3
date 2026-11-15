#include-once

; Zaishen - autonomous combat AI. Constants, enums and settings.
; One tick = ZS_Perceive (snapshot) -> ZS_Evaluate (pure, no memory read) -> ZS_Execute (one step).

#Region Settings (safe defaults, change them from the bot script before fighting)
Global $g_i_ZS_TickSleep = 40              ; ms slept between two ticks in ZS_Fight
Global $g_f_ZS_PerceiveRange = 2500        ; agents farther than this from the player are not read
Global $g_f_ZS_ArrowSpeed = 0.85           ; units per ms of an arrow, of a spear (measured by LogicCast, to confirm)
Global $g_f_ZS_SpearSpeed = 1.05
Global $g_i_ZS_FastCasting = 0             ; Fast Casting of the player (read once per instance)
Global $g_b_ZS_ReadVisibleEffects = True   ; read burning, blindness, daze, weakness, disease on every agent (costs reads)
Global $g_f_ZS_MinUtility = 0.05           ; candidates below this utility are ignored
Global $g_f_ZS_CalledTargetBonus = 0.15    ; utility bonus on the called / forced target
Global $g_f_ZS_InertiaBonus = 0.05         ; utility bonus on the target of the previous foe action
Global $g_f_ZS_LowHPWeight = 0.25          ; > 0 finishes low foes first, < 0 spreads pressure on healthy foes
Global $g_f_ZS_FacingCos = 0.94            ; a foe "aims" at an agent when it faces it within ~20 degrees
Global $g_i_ZS_MaxMaintained = 3           ; enchantments the player keeps up at once (each one costs energy regeneration)
Global $g_f_ZS_SacrificeFloor = 0.1        ; never sacrifice health below this fraction of max health
Global $g_f_ZS_ReservePenalty = 0.35       ; utility factor of a non urgent action that eats the emergency energy
Global $g_i_ZS_CastMargin = 250            ; ms of safety before renewing an effect that is about to end
Global $g_i_ZS_InterruptMargin = 60        ; ms of safety for an interrupt (detection lag is already partly in the ping)
Global $g_b_ZS_DryRun = False              ; True = decide but never send a command to the game
Global $g_b_ZS_Explain = False             ; True = build the textual detail of every candidate (journal, tests)
Global $g_s_ZS_LogFile = ""                ; decision journal file, "" = no journal
Global $g_i_ZS_ForceTarget = 0             ; agent ID every foe action should prefer (0 = none)
Global $g_v_ZS_AvoidModels = 0             ; model (PlayerNumber) or array of models never targeted
Global $g_v_ZS_PriorityModels = 0          ; model or array of models targeted first
#EndRegion Settings

#Region Agent snapshot
; Columns of $g_amx2_ZS_Agent[row][col]. Row 0 is unused, rows 1..$g_i_ZS_AgentCount.
Global Enum $GC_ZS_A_ID, _
	$GC_ZS_A_X, _
	$GC_ZS_A_Y, _
	$GC_ZS_A_HP, _           ; 0..1
	$GC_ZS_A_MaxHP, _        ; absolute, often 0 for agents outside the party
	$GC_ZS_A_HPPips, _
	$GC_ZS_A_Allegiance, _   ; $GC_I_ALLEGIANCE_*
	$GC_ZS_A_Flags, _        ; bit mask of $GC_ZS_AF_*
	$GC_ZS_A_Skill, _        ; skill being activated, 0 = none
	$GC_ZS_A_CastMs, _       ; ms since this activation was first seen
	$GC_ZS_A_Primary, _
	$GC_ZS_A_Secondary, _
	$GC_ZS_A_Model, _        ; PlayerNumber
	$GC_ZS_A_WeaponType, _
	$GC_ZS_A_Level, _
	$GC_ZS_A_LastStrike, _   ; 1 lead, 2 off-hand, 3 dual (assassin chain state of this target)
	$GC_ZS_A_RotCos, _       ; facing direction (cos, sin of the rotation angle)
	$GC_ZS_A_RotSin, _
	$GC_ZS_A_DmgRate, _      ; health lost per second, as a fraction of max health, smoothed over ~1 s
	$GC_ZS_A_Dist, _         ; distance to the player
	$GC_ZS_A_Near240, _      ; derived, lazily: foes of this agent's side within 240 (-1 = not computed)
	$GC_ZS_A_Near312, _
	$GC_ZS_A_Threat, _       ; derived, lazily: 0..1 pressure on this agent (-1 = not computed)
	$GC_ZS_A_AimIdx, _       ; derived, lazily, foes only: row of our agent it faces best (0 = none, -1 = not computed)
	$GC_ZS_A_COUNT

; Bits of $GC_ZS_A_Flags
Global Const $GC_ZS_AF_DEAD = 0x1
Global Const $GC_ZS_AF_CASTING = 0x2
Global Const $GC_ZS_AF_ATTACKING = 0x4
Global Const $GC_ZS_AF_MOVING = 0x8
Global Const $GC_ZS_AF_KNOCKED = 0x10
Global Const $GC_ZS_AF_HEXED = 0x20
Global Const $GC_ZS_AF_DEGENHEXED = 0x40
Global Const $GC_ZS_AF_ENCHANTED = 0x80
Global Const $GC_ZS_AF_CONDITIONED = 0x100
Global Const $GC_ZS_AF_BLEEDING = 0x200
Global Const $GC_ZS_AF_POISONED = 0x400
Global Const $GC_ZS_AF_DEEPWOUND = 0x800
Global Const $GC_ZS_AF_CRIPPLED = 0x1000
Global Const $GC_ZS_AF_WEAPONSPELL = 0x2000
Global Const $GC_ZS_AF_BOSS = 0x4000
Global Const $GC_ZS_AF_PLAYER = 0x8000       ; human controlled character
Global Const $GC_ZS_AF_CORPSE = 0x10000      ; exploitable corpse
Global Const $GC_ZS_AF_SPAWNED = 0x20000     ; spirit, minion or other spawned creature
; Conditions only the visible effects show (any agent, foes included)
Global Const $GC_ZS_AF_BURNING = 0x40000
Global Const $GC_ZS_AF_BLIND = 0x80000
Global Const $GC_ZS_AF_DAZED = 0x100000
Global Const $GC_ZS_AF_WEAKNESS = 0x200000   ; the game shows Cracked Armor with the same icon
Global Const $GC_ZS_AF_DISEASED = 0x400000
Global Const $GC_ZS_AF_PET = 0x800000        ; the player's own animal companion (the game gives pets the spirit allegiance)

; Names used by the snapshot text format, same order as the bits above
Global Const $GC_AS_ZS_FLAGNAMES[24] = ["dead", "casting", "attacking", "moving", "knocked", "hexed", "degenhexed", "enchanted", _
		"conditioned", "bleeding", "poisoned", "deepwound", "crippled", "weaponspell", "boss", "player", "corpse", "spawned", _
		"burning", "blind", "dazed", "weakness", "diseased", "pet"]

; The player's pet: agent ID read from the game every second (0 = none); row in the snapshot (0 = not seen)
Global $g_i_ZS_PetID = 0, $g_i_ZS_PetReadAt = -100000, $g_i_ZS_PetIdx = 0
; Attribute rank used for durations when the game cannot be read (test snapshots: "rank=" meta key)
Global $g_i_ZS_OfflineRank = 12

Global $g_amx2_ZS_Agent[1][$GC_ZS_A_COUNT]
Global $g_i_ZS_AgentCount = 0
Global $g_i_ZS_MeIdx = 0                   ; row of the player in $g_amx2_ZS_Agent
Global $g_i_ZS_MyID = 0
Global $g_m_ZS_IdToIdx[]                   ; agent ID -> row

; Player only values
Global $g_f_ZS_Energy = 0
Global $g_f_ZS_MaxEnergy = 0
Global $g_i_ZS_EnergyPips = 0
Global $g_i_ZS_Overcast = 0
Global $g_i_ZS_Expertise = 0               ; rank in Expertise (ranger): attacks, rituals and touch skills cost 4 % less per rank

; Snapshot wide values
Global $g_i_ZS_Now = 0                     ; ms clock of the snapshot
Global $g_i_ZS_Ping = 0
Global $g_i_ZS_CalledTarget = 0            ; target called by another human player of the party
Global $g_f_ZS_AggroRange = 1320
Global $g_b_ZS_InCombat = False            ; derived: a living foe is near the player or an ally

; Effects known on agents (party members only: the client has nothing for the others)
; Age = ms since the effect was applied (the newest enchantment is the one a Dervish skill strips first)
Global Enum $GC_ZS_FX_AgentID, $GC_ZS_FX_SkillID, $GC_ZS_FX_RemainMs, $GC_ZS_FX_CasterID, $GC_ZS_FX_Level, $GC_ZS_FX_Age, $GC_ZS_FX_COUNT
Global Const $GC_ZS_FX_MAINTAINED = 0x7FFFFFFF
Global $g_amx2_ZS_Fx[1][$GC_ZS_FX_COUNT]
Global $g_i_ZS_FxCount = 0
Global $g_m_ZS_SelfFx[]                    ; skill ID -> remaining ms, effects on the player
Global $g_m_ZS_SelfFxLvl[]                 ; skill ID -> attribute level of that effect (its strength)
Global $g_m_ZS_SelfFxAge[]                 ; skill ID -> ms since that effect was applied
; Enchantments the player keeps up (the game lists them as "bonds" of their caster): [skill ID, target agent ID]
Global $g_amx2_ZS_Bond[1][2]
Global $g_i_ZS_BondCount = 0
Global $g_i_ZS_MaintainedCount = 0         ; enchantments the player keeps up right now
Global $g_m_ZS_Maintainable[]              ; skill ID -> True once seen kept up by the player (learned while playing)

; Ritualist urns and ashes: the game tells which item is held, not which skill gave it
Global $g_i_ZS_BundleItem = 0              ; item held in hand (0 = none)
Global $g_i_ZS_HeldUrn = 0                 ; skill ID of the urn the player holds (0 = none or not ours)
Global $g_i_ZS_LastUrnSkill = 0            ; last item spell cast, and when
Global $g_i_ZS_LastUrnAt = 0

; Weapon sets (Equipment/ZS_Weapons.au3). Rows 1..4 = the 4 sets of the game.
Global $g_b_ZS_WeaponSwap = True            ; False = never change weapon set
Global $g_i_ZS_HomeSetForced = 0            ; 1..4 = set to fight with, 0 = deduced from the attack skills of the bar
Global Enum $GC_ZS_W_Present, $GC_ZS_W_WeaponID, $GC_ZS_W_OffhandID, $GC_ZS_W_ItemType, $GC_ZS_W_OffhandType, $GC_ZS_W_Bit, _
	$GC_ZS_W_EFlat, $GC_ZS_W_EEnch, $GC_ZS_W_EHex, $GC_ZS_W_EHPHi, $GC_ZS_W_EHPHiThr, $GC_ZS_W_EHPLo, $GC_ZS_W_EHPLoThr, _
	$GC_ZS_W_Ench, $GC_ZS_W_HCT, $GC_ZS_W_HSR, $GC_ZS_W_COUNT
Global $g_amx2_ZS_WSet[5][$GC_ZS_W_COUNT]
Global $g_i_ZS_ActiveSet = 0                ; set in hand (0 = unknown: no weapon switching)
Global $g_i_ZS_HomeSet = 0                  ; set the build fights with
Global $g_i_ZS_SetsReadAt = -100000         ; when the sets were last read from the game
Global $g_i_ZS_SwitchTo = 0                 ; switch sent and not seen yet
Global $g_i_ZS_SwitchUntil = 0
Global $g_ai_ZS_SwitchTimes[4] = [-100000, -100000, -100000, -100000] ; last switches (circuit breaker)
Global $g_i_ZS_SwitchFrozenUntil = 0
Global $g_i_ZS_StatSwitches = 0
Global $g_s_ZS_WeaponWhy = ""               ; why ZS_Weapon_ForSkill / ZS_Weapon_ForAttack want a set

; Spirits we put down: a ritual is not recast while its spirit lives near the fight
Global $g_m_ZS_SeenSpirit[]                ; agent ID -> True for every allied spirit already seen
Global $g_m_ZS_SpiritOf[]                  ; skill ID -> agent ID of the spirit it created
Global $g_i_ZS_PendingSpirit = 0           ; ritual just cast, waiting for its spirit to appear
Global $g_i_ZS_PendingSpiritUntil = 0
#EndRegion Agent snapshot

#Region Skill bar
; Columns of $g_amx2_ZS_Slot[1..8][col]
Global Enum $GC_ZS_S_SkillID, _
	$GC_ZS_S_Type, _
	$GC_ZS_S_Target, _
	$GC_ZS_S_Special, _
	$GC_ZS_S_Effect1, _
	$GC_ZS_S_Effect2, _
	$GC_ZS_S_Req, _           ; condition the target must have for the full effect
	$GC_ZS_S_WeaponReq, _
	$GC_ZS_S_ComboType, _
	$GC_ZS_S_ComboReq, _
	$GC_ZS_S_Energy, _
	$GC_ZS_S_AdrenReq, _
	$GC_ZS_S_ActivationMs, _
	$GC_ZS_S_AftercastMs, _
	$GC_ZS_S_Recharge, _      ; seconds
	$GC_ZS_S_Duration, _      ; seconds, lowest known value
	$GC_ZS_S_Scale, _         ; highest scaling value of the skill (heal, damage...)
	$GC_ZS_S_AoE, _
	$GC_ZS_S_Attribute, _
	$GC_ZS_S_Profession, _
	$GC_ZS_S_Family, _        ; $GC_ZS_FAM_* (knowledge)
	$GC_ZS_S_TargetMask, _    ; $GC_ZS_TM_* (knowledge)
	$GC_ZS_S_Weight, _        ; utility multiplier (knowledge)
	$GC_ZS_S_Params, _        ; "Key=Value|Key=Value" (knowledge)
	$GC_ZS_S_Origin, _        ; where the behaviour comes from: "rule", "def" or "ini"
	$GC_ZS_S_HealthCost, _    ; sacrifice, % of max health (read from the game, absent from the offline table)
	$GC_ZS_S_OvercastCost, _  ; overcast points (read from the game)
	$GC_ZS_S_Recharged, _     ; dynamic
	$GC_ZS_S_RechargeMs, _    ; dynamic
	$GC_ZS_S_Adrenaline, _    ; dynamic
	$GC_ZS_S_COUNT

Global $g_amx2_ZS_Slot[9][$GC_ZS_S_COUNT]
Global $g_f_ZS_ReserveEnergy = 0           ; energy kept for the emergency skills of the bar
#EndRegion Skill bar

#Region Knowledge
; Behaviour families. Every skill of the bar gets one; NONE means "never used by the AI".
Global Enum $GC_ZS_FAM_NONE, _
	$GC_ZS_FAM_RESURRECT, _
	$GC_ZS_FAM_HEAL_SINGLE, _
	$GC_ZS_FAM_HEAL_SELF, _
	$GC_ZS_FAM_HEAL_PARTY, _
	$GC_ZS_FAM_PROTECT, _
	$GC_ZS_FAM_HEX_REMOVAL, _
	$GC_ZS_FAM_COND_REMOVAL, _
	$GC_ZS_FAM_INTERRUPT, _
	$GC_ZS_FAM_ENERGY, _
	$GC_ZS_FAM_SELF_BUFF, _
	$GC_ZS_FAM_ALLY_BUFF, _
	$GC_ZS_FAM_PARTY_BUFF, _
	$GC_ZS_FAM_WEAPON_SPELL, _
	$GC_ZS_FAM_HEX, _
	$GC_ZS_FAM_ENCH_REMOVAL, _
	$GC_ZS_FAM_DAMAGE, _
	$GC_ZS_FAM_DAMAGE_AOE, _
	$GC_ZS_FAM_PBAOE, _
	$GC_ZS_FAM_ATTACK, _
	$GC_ZS_FAM_PET_ATTACK, _
	$GC_ZS_FAM_SPIRIT, _
	$GC_ZS_FAM_CORPSE, _
	$GC_ZS_FAM_WARD, _
	$GC_ZS_FAM_TRAP, _
	$GC_ZS_FAM_ITEM_SPELL, _
	$GC_ZS_FAM_GENERIC_FOE, _
	$GC_ZS_FAM_GENERIC_SELF, _
	$GC_ZS_FAM_GENERIC_ALLY, _
	$GC_ZS_FAM_ENERGY_BUFF, _       ; self enchantment that feeds energy (attunements, Ether Renewal): kept up first
	$GC_ZS_FAM_COUNT

Global Const $GC_AS_ZS_FAMNAMES[$GC_ZS_FAM_COUNT] = ["None", "Resurrect", "HealSingle", "HealSelf", "HealParty", "Protect", _
		"HexRemoval", "CondRemoval", "Interrupt", "Energy", "SelfBuff", "AllyBuff", "PartyBuff", "WeaponSpell", "Hex", _
		"EnchRemoval", "Damage", "DamageAoE", "PBAoE", "Attack", "PetAttack", "Spirit", "Corpse", "Ward", "Trap", "ItemSpell", _
		"GenericFoe", "GenericSelf", "GenericAlly", "EnergyBuff"]

; Who a skill may be used on
Global Const $GC_ZS_TM_SELF = 0x1
Global Const $GC_ZS_TM_ALLY = 0x2          ; living allies other than the player
Global Const $GC_ZS_TM_FOE = 0x4
Global Const $GC_ZS_TM_DEADALLY = 0x8
Global Const $GC_ZS_TM_CORPSE = 0x10
Global Const $GC_ZS_TM_MINION = 0x20
Global Const $GC_ZS_TM_SPIRIT = 0x40       ; allied spirits and pets

; Priority bands, highest wins as soon as it holds a candidate
Global Enum $GC_ZS_BAND_IDLE, _            ; auto attack
	$GC_ZS_BAND_DAMAGE, _
	$GC_ZS_BAND_UPKEEP, _
	$GC_ZS_BAND_CLEANSE, _
	$GC_ZS_BAND_HEAL, _
	$GC_ZS_BAND_INTERRUPT, _
	$GC_ZS_BAND_RESURRECT, _
	$GC_ZS_BAND_SURVIVAL, _
	$GC_ZS_BAND_COUNT

Global Const $GC_AS_ZS_BANDNAMES[$GC_ZS_BAND_COUNT] = ["Idle", "Damage", "Upkeep", "Cleanse", "Heal", "Interrupt", "Resurrect", "Survival"]
#EndRegion Knowledge

#Region Decision
; DROP = drop the bundle of the slot ; ENDBUFF = end the enchantment of the slot the player keeps up (Unyielding Aura)
; MOVE = walk to ($GC_ZS_D_X, $GC_ZS_D_Y): leave a damaging area, step back from melee foes...
Global Enum $GC_ZS_ACT_NONE, $GC_ZS_ACT_SKILL, $GC_ZS_ACT_ATTACK, $GC_ZS_ACT_DROP, $GC_ZS_ACT_ENDBUFF, $GC_ZS_ACT_MOVE

; Columns of a decision / candidate row
Global Enum $GC_ZS_D_Action, _
	$GC_ZS_D_Slot, _
	$GC_ZS_D_TargetID, _
	$GC_ZS_D_Band, _
	$GC_ZS_D_Utility, _
	$GC_ZS_D_Score, _         ; band * 10 + utility
	$GC_ZS_D_Why, _           ; filled when $g_b_ZS_Explain
	$GC_ZS_D_X, _             ; destination of a MOVE
	$GC_ZS_D_Y, _
	$GC_ZS_D_COUNT

Global Const $GC_ZS_TOPN = 5
Global $g_av_ZS_Decision[$GC_ZS_D_COUNT]          ; winner of the last evaluation
Global $g_amx2_ZS_Top[$GC_ZS_TOPN][$GC_ZS_D_COUNT] ; best candidates of the last evaluation, best first
Global $g_i_ZS_TopCount = 0
Global $g_i_ZS_CandidateCount = 0                 ; candidates scored during the last evaluation
Global $g_s_ZS_Why = ""                           ; scratch: detail of the candidate being scored
Global $g_f_ZS_SlotBonus = 0                      ; scratch: utility added to every candidate of the slot (Dervish stripper)
Global $g_s_ZS_SlotWhy = ""
; Set by ZS_Eval_Utility when an energy skill is only worth its damage on this target (its energy bonus is not met)
Global $g_b_ZS_AsDamage = False
Global $g_m_ZS_FoeDanger[]                  ; foe skill ID -> value of interrupting it (ZS_Eval_FoeSkillDanger)
Global $g_i_ZS_LastFoeTarget = 0                  ; target of the previous foe action (inertia)
Global $g_m_ZS_Recent[]                           ; "skillID:agentID" -> ms until which the pair is not recast
#EndRegion Decision

#Region Positioning
; Zaishen moves the player during a fight: out of a damaging area, back from melee foes (casters), to a dead
; ally with a resurrecting urn. Off with False: the player then only moves to reach its targets (the game does it).
Global $g_b_ZS_Positioning = True
Global $g_i_ZS_BackOffCooldown = 4000      ; ms between two steps back from melee foes
Global $g_f_ZS_BackOffStep = 400           ; length of a step back
Global $g_f_ZS_WalkSpeed = 0.28            ; units per ms (normal walking speed)
; Damaging areas foes put on the ground (Fire Storm, Maelstrom...): [i][x, y, radius, untilMs, skillID]
Global Enum $GC_ZS_HZ_X, $GC_ZS_HZ_Y, $GC_ZS_HZ_R, $GC_ZS_HZ_Until, $GC_ZS_HZ_Skill, $GC_ZS_HZ_COUNT
Global $g_amx2_ZS_Hazard[1][$GC_ZS_HZ_COUNT]
Global $g_i_ZS_HazardCount = 0
Global $g_m_ZS_HazCast[]                   ; foe agentID -> [skillID, aimX, aimY, startMs] while it casts an area spell
Global $g_m_ZS_HazSkill[]                  ; skill ID -> True/False: leaves a damaging area on the ground (cache)
; The move being made: kept until reached or timed out, so a lesser action does not stop it halfway
Global $g_f_ZS_MoveX = 0, $g_f_ZS_MoveY = 0, $g_i_ZS_MoveUntil = 0, $g_i_ZS_MoveBand = 0, $g_f_ZS_MoveU = 0
Global $g_s_ZS_MoveWhy = "", $g_i_ZS_MoveSentAt = -100000
Global $g_i_ZS_StatMoves = 0
#EndRegion Positioning

#Region Execution
Global Enum $GC_ZS_ST_IDLE, _       ; free to start an action
	$GC_ZS_ST_WAITCAST, _           ; command sent, activation not seen yet
	$GC_ZS_ST_CASTING, _            ; activation in progress
	$GC_ZS_ST_AFTERCAST             ; waiting for the aftercast delay

Global Const $GC_AS_ZS_STATENAMES[4] = ["Idle", "WaitCast", "Casting", "Aftercast"]

Global $g_i_ZS_State = $GC_ZS_ST_IDLE
Global $g_i_ZS_StateSince = 0
Global $g_i_ZS_ExecSlot = 0
Global $g_i_ZS_ExecSkill = 0
Global $g_i_ZS_ExecTarget = 0
Global $g_b_ZS_ExecIsRez = False
Global $g_i_ZS_ExecTimeout = 0
Global $g_i_ZS_AttackTarget = 0
Global $g_i_ZS_AttackSince = 0
Global $g_s_ZS_LastCommand = ""            ; last command issued, also filled in dry run (tests)

; Results of ZS_Tick
Global Enum $GC_ZS_TICK_FIGHTING, _  ; in combat, an action is running or was just decided
	$GC_ZS_TICK_NOFOE, _             ; nothing to fight
	$GC_ZS_TICK_DOWN, _              ; player dead
	$GC_ZS_TICK_NOTREADY             ; not in an explorable area, or no data

; Session counters
Global $g_i_ZS_StatTicks = 0
Global $g_f_ZS_StatTickMsSum = 0
Global $g_f_ZS_StatTickMsMax = 0
Global $g_i_ZS_StatCasts = 0
Global $g_i_ZS_StatCancelled = 0
Global $g_i_ZS_StatTimeouts = 0
#EndRegion Execution
