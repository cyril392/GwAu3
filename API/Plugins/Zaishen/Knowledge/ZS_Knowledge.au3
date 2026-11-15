#include-once

; Zaishen knowledge: what each skill is for.
; Layers, last one wins: 1) game data ($GC_AMX2_SKILL_DATA)  2) family deduced by rules (ZS_Knowledge_Classify)
;                        3) dedicated definitions (ZS_DefineSkill, Knowledge/ZS_SkillDefs.au3)
; Only the 8 skills of the bar are resolved, when the bar changes: nothing here runs during the fight.

Global $g_m_ZS_Defs[]             ; skill ID -> [family, mask, weight, params]
Global $g_m_ZS_GenParams[]        ; skill ID -> parameters generated from UtilityAI (Knowledge/Generated), overridden by $g_m_ZS_Defs
Global $g_b_ZS_DefsLoaded = False
Global $g_am_ZS_SlotParams[9]     ; per slot: map of the parsed "Key=Value" parameters

#Region Game data
;~ Description: One cell of the offline skill table, 0 for an ID the table does not know.
Func ZS_SkillData($a_i_SkillID, $a_i_Column)
	If $a_i_SkillID <= 0 Or $a_i_SkillID >= $GC_I_SKILL_DATA_ROWS Then Return 0
	Return $GC_AMX2_SKILL_DATA[$a_i_SkillID][$a_i_Column]
EndFunc   ;==>ZS_SkillData

Func ZS_SkillName($a_i_SkillID)
	If $a_i_SkillID <= 0 Or $a_i_SkillID >= $GC_I_SKILL_DATA_ROWS Then Return "#" & $a_i_SkillID
	Return $GC_AMX2_SKILL_DATA[$a_i_SkillID][$GC_S_SKILL_NAME]
EndFunc   ;==>ZS_SkillName

;~ Description: True for the skill types the game treats as spells.
Func ZS_IsSpellType($a_i_Type)
	Switch $a_i_Type
		Case $GC_I_SKILL_TYPE_SPELL, $GC_I_SKILL_TYPE_HEX, $GC_I_SKILL_TYPE_ENCHANTMENT, $GC_I_SKILL_TYPE_WELL, _
				$GC_I_SKILL_TYPE_WARD, $GC_I_SKILL_TYPE_WEAPON_SPELL, $GC_I_SKILL_TYPE_ITEM_SPELL
			Return True
	EndSwitch
	Return False
EndFunc   ;==>ZS_IsSpellType
#EndRegion Game data

#Region Rules (layer 2)
;~ Description: Who the game lets this skill be used on, as a $GC_ZS_TM_* mask.
Func ZS_Knowledge_TargetMask($a_i_SkillID)
	Local $l_i_Special = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_SPECIAL)
	Switch ZS_SkillData($a_i_SkillID, $GC_I_SKILL_TARGET_TYPE)
		Case $GC_I_SKILL_TARGET_ALLY
			Return $GC_ZS_TM_SELF + $GC_ZS_TM_ALLY
		Case $GC_I_SKILL_TARGET_OTHER_ALLY
			Return $GC_ZS_TM_ALLY
		Case $GC_I_SKILL_TARGET_ENEMY, $GC_I_SKILL_TARGET_GROUND, $GC_I_SKILL_TARGET_SPIRIT_ENEMY
			Return $GC_ZS_TM_FOE
		Case $GC_I_SKILL_TARGET_DEAD_ALLY
			Return $GC_ZS_TM_DEADALLY
		Case $GC_I_SKILL_TARGET_MINION
			Return $GC_ZS_TM_MINION
		Case 1 ; spirit, animal or corpse: the game uses one value for the three
			If BitAND($l_i_Special, $GC_I_SKILL_SPECIAL_FLAG_CORPSE) Then Return $GC_ZS_TM_CORPSE
			Return $GC_ZS_TM_SPIRIT
	EndSwitch
	Return $GC_ZS_TM_SELF
EndFunc   ;==>ZS_Knowledge_TargetMask

;~ Description: Family deduced from the game data alone. $a_i_Mask receives the target mask.
Func ZS_Knowledge_Classify($a_i_SkillID, ByRef $a_i_Mask)
	$a_i_Mask = 0
	If $a_i_SkillID <= 0 Or $a_i_SkillID >= $GC_I_SKILL_DATA_ROWS Then Return $GC_ZS_FAM_NONE

	Local $l_i_Type = $GC_AMX2_SKILL_DATA[$a_i_SkillID][$GC_I_SKILL_TYPE]
	Local $l_i_Special = $GC_AMX2_SKILL_DATA[$a_i_SkillID][$GC_I_SKILL_SPECIAL]
	Local $l_i_E1 = $GC_AMX2_SKILL_DATA[$a_i_SkillID][$GC_I_SKILL_EFFECT_1]
	Local $l_i_E2 = $GC_AMX2_SKILL_DATA[$a_i_SkillID][$GC_I_SKILL_EFFECT_2]
	Local $l_i_AoE = $GC_AMX2_SKILL_DATA[$a_i_SkillID][$GC_I_SKILL_AOE_RANGE]

	; Not something a player can have on a bar
	Switch $l_i_Type
		Case 0, $GC_I_SKILL_TYPE_BOUNTY, $GC_I_SKILL_TYPE_SCROLL, $GC_I_SKILL_TYPE_CONDITION, $GC_I_SKILL_TYPE_TITLE, _
				$GC_I_SKILL_TYPE_PASSIVE, $GC_I_SKILL_TYPE_ENVIRONMENTAL, $GC_I_SKILL_TYPE_ENVIRONMENTALTRAP, $GC_I_SKILL_TYPE_DISGUISE
			Return $GC_ZS_FAM_NONE
	EndSwitch
	If BitAND($l_i_Special, $GC_I_SKILL_SPECIAL_FLAG_MONSTER_SKILL + $GC_I_SKILL_SPECIAL_FLAG_PASSIVE_MONSTER) Then Return $GC_ZS_FAM_NONE

	$a_i_Mask = ZS_Knowledge_TargetMask($a_i_SkillID)
	Local $l_b_OnFoe = BitAND($a_i_Mask, $GC_ZS_TM_FOE) <> 0
	Local $l_b_OnAlly = BitAND($a_i_Mask, $GC_ZS_TM_ALLY) <> 0
	Local $l_b_SelfOnly = ($a_i_Mask = $GC_ZS_TM_SELF)

	; --- what the skill does wins over what kind of skill it is ---
	If BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_RESURRECTION + $GC_I_SKILL_EFFECT2_RES_SIGNET) Or BitAND($l_i_Special, $GC_I_SKILL_SPECIAL_FLAG_RESURRECTION) _
			Or BitAND($a_i_Mask, $GC_ZS_TM_DEADALLY) Then
		If Not $l_b_SelfOnly Then $a_i_Mask = $GC_ZS_TM_DEADALLY
		Return $GC_ZS_FAM_RESURRECT
	EndIf

	If $l_i_Type = $GC_I_SKILL_TYPE_PETATTACK Then
		$a_i_Mask = $GC_ZS_TM_FOE
		Return $GC_ZS_FAM_PET_ATTACK
	EndIf

	; A real interrupt is fast; a 2 s hex flagged "interrupt" (Guilt, Shame: "next spell fails") is cast ahead
	If BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_INTERRUPT) And $l_b_OnFoe And ZS_SkillData($a_i_SkillID, $GC_F_SKILL_ACTIVATION_TIME) < 1 Then Return $GC_ZS_FAM_INTERRUPT

	If $l_i_Type = $GC_I_SKILL_TYPE_ATTACK Then
		$a_i_Mask = $GC_ZS_TM_FOE
		Return $GC_ZS_FAM_ATTACK
	EndIf

	Local $l_b_Plain = False ; spell, signet or untyped skill: the kinds whose effect flags describe the whole skill
	Switch $l_i_Type
		Case $GC_I_SKILL_TYPE_SPELL, $GC_I_SKILL_TYPE_SIGNET, $GC_I_SKILL_TYPE_SKILL, $GC_I_SKILL_TYPE_SKILL2
			$l_b_Plain = True
	EndSwitch
	Local $l_b_PlainOrBuff = $l_b_Plain
	Switch $l_i_Type
		Case $GC_I_SKILL_TYPE_ENCHANTMENT, $GC_I_SKILL_TYPE_SHOUT, $GC_I_SKILL_TYPE_CHANT, $GC_I_SKILL_TYPE_ECHO_REFRAIN
			$l_b_PlainOrBuff = True
	EndSwitch

	If $l_b_PlainOrBuff And Not $l_b_OnFoe Then
		If BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_HEX_REMOVAL) Then Return $GC_ZS_FAM_HEX_REMOVAL
		If BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_CONDITION_REMOVAL) Then Return $GC_ZS_FAM_COND_REMOVAL
		If BitAND($l_i_E1, $GC_I_SKILL_EFFECT1_HEAL) Or BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_CAN_HEAL_OTHER + $GC_I_SKILL_EFFECT2_CAN_HEAL_SELF) Then
			If $l_b_OnAlly Then Return $GC_ZS_FAM_HEAL_SINGLE
			If $l_b_SelfOnly Then
				If BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_CAN_HEAL_OTHER) Then Return $GC_ZS_FAM_HEAL_PARTY
				Return $GC_ZS_FAM_HEAL_SELF
			EndIf
		EndIf
	EndIf

	If $l_b_Plain And BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_ENERGY_GAIN + $GC_I_SKILL_EFFECT2_ENERGY_STEAL) Then Return $GC_ZS_FAM_ENERGY

	; --- then the kind of skill ---
	Switch $l_i_Type
		Case $GC_I_SKILL_TYPE_HEX
			If $l_b_OnFoe Then Return $GC_ZS_FAM_HEX
			; A hex cast on oneself hits the foes around (Grasping Earth, Frozen Burst)
			If $l_i_AoE > 0 Then Return $GC_ZS_FAM_PBAOE
			Return $GC_ZS_FAM_GENERIC_SELF
		Case $GC_I_SKILL_TYPE_ENCHANTMENT
			If $l_b_OnFoe Then Return $GC_ZS_FAM_GENERIC_FOE
			If $l_b_OnAlly Then
				If $GC_AMX2_SKILL_DATA[$a_i_SkillID][$GC_I_SKILL_ATTRIBUTE] = $GC_I_ATTRIBUTE_PROTECTION_PRAYERS Then Return $GC_ZS_FAM_PROTECT
				Return $GC_ZS_FAM_ALLY_BUFF
			EndIf
			If $l_i_AoE >= $GC_I_RANGE_EARSHOT Then Return $GC_ZS_FAM_PARTY_BUFF
			; Feeds energy back (attunements, Ether Renewal): kept up before anything that spends it
			If BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_ENERGY_GAIN + $GC_I_SKILL_EFFECT2_SELF_TARGET_ENCHANT) Then Return $GC_ZS_FAM_ENERGY_BUFF
			Return $GC_ZS_FAM_SELF_BUFF
		Case $GC_I_SKILL_TYPE_STANCE, $GC_I_SKILL_TYPE_FORM, $GC_I_SKILL_TYPE_GLYPH, $GC_I_SKILL_TYPE_PREPARATION
			$a_i_Mask = $GC_ZS_TM_SELF
			Return $GC_ZS_FAM_SELF_BUFF
		Case $GC_I_SKILL_TYPE_SHOUT, $GC_I_SKILL_TYPE_CHANT, $GC_I_SKILL_TYPE_ECHO_REFRAIN
			If $l_b_OnFoe Then Return $GC_ZS_FAM_GENERIC_FOE
			If $l_b_OnAlly Then Return $GC_ZS_FAM_ALLY_BUFF
			Return $GC_ZS_FAM_PARTY_BUFF
		Case $GC_I_SKILL_TYPE_WEAPON_SPELL
			Return $GC_ZS_FAM_WEAPON_SPELL
		Case $GC_I_SKILL_TYPE_ITEM_SPELL
			$a_i_Mask = $GC_ZS_TM_SELF
			Return $GC_ZS_FAM_ITEM_SPELL
		Case $GC_I_SKILL_TYPE_RITUAL
			$a_i_Mask = $GC_ZS_TM_SELF
			Return $GC_ZS_FAM_SPIRIT
		Case $GC_I_SKILL_TYPE_WELL
			$a_i_Mask = $GC_ZS_TM_SELF
			Return $GC_ZS_FAM_CORPSE
		Case $GC_I_SKILL_TYPE_WARD
			$a_i_Mask = $GC_ZS_TM_SELF
			Return $GC_ZS_FAM_WARD
		Case $GC_I_SKILL_TYPE_TRAP
			$a_i_Mask = $GC_ZS_TM_SELF
			Return $GC_ZS_FAM_TRAP
	EndSwitch

	; Spell, signet, untyped skill
	If BitAND($l_i_Special, $GC_I_SKILL_SPECIAL_FLAG_CORPSE) Then
		$a_i_Mask = $GC_ZS_TM_SELF ; the game picks the corpse itself
		Return $GC_ZS_FAM_CORPSE
	EndIf
	If $l_b_OnFoe Then
		If $l_i_AoE > 0 Then Return $GC_ZS_FAM_DAMAGE_AOE
		Return $GC_ZS_FAM_DAMAGE
	EndIf
	If Not $l_b_SelfOnly Then Return $GC_ZS_FAM_GENERIC_ALLY
	If BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_CLOSE_RANGE + $GC_I_SKILL_EFFECT2_SURROUNDING) Or ($l_i_AoE > 0 And $l_i_AoE <= 400) Then Return $GC_ZS_FAM_PBAOE
	If $GC_AMX2_SKILL_DATA[$a_i_SkillID][$GC_I_SKILL_DURATION_0] > 0 Or $GC_AMX2_SKILL_DATA[$a_i_SkillID][$GC_I_SKILL_DURATION_15] > 0 Then Return $GC_ZS_FAM_SELF_BUFF
	Return $GC_ZS_FAM_GENERIC_SELF
EndFunc   ;==>ZS_Knowledge_Classify
#EndRegion Rules (layer 2)

#Region Dedicated definitions (layer 3)
;~ Description: Replace the deduced behaviour of a skill.
;~ $a_i_Mask = -1 keeps the mask of the game data. $a_s_Params is "Key=Value|Key=Value".
Func ZS_DefineSkill($a_i_SkillID, $a_i_Family, $a_i_Mask = -1, $a_s_Params = "", $a_f_Weight = 1)
	Local $l_av_Def[4] = [$a_i_Family, $a_i_Mask, $a_f_Weight, $a_s_Params]
	$g_m_ZS_Defs[$a_i_SkillID] = $l_av_Def
EndFunc   ;==>ZS_DefineSkill

;~ Description: Parameters of a skill without changing its family (generated file). A ZS_DefineSkill of the same
;~ skill keeps them, and its own parameters win key by key.
Func ZS_DefineParams($a_i_SkillID, $a_s_Params)
	$g_m_ZS_GenParams[$a_i_SkillID] = $a_s_Params
EndFunc   ;==>ZS_DefineParams
#EndRegion Dedicated definitions (layer 3)

#Region Bar resolution
;~ Description: Fill the static and knowledge columns of one slot. Called when the skill of the slot changes.
Func ZS_Knowledge_ResolveSlot($a_i_Slot, $a_i_SkillID)
	If Not $g_b_ZS_DefsLoaded Then
		$g_b_ZS_DefsLoaded = True
		ZS_Knowledge_LoadGenerated()
		ZS_Knowledge_LoadDefs()
	EndIf

	For $i = 0 To $GC_ZS_S_COUNT - 1
		$g_amx2_ZS_Slot[$a_i_Slot][$i] = 0
	Next
	Local $l_m_NoParams[]
	$g_am_ZS_SlotParams[$a_i_Slot] = $l_m_NoParams
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID] = $a_i_SkillID
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Weight] = 1
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Params] = ""
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Origin] = ""
	If $a_i_SkillID = 0 Then
		ZS_Req_Prepare($a_i_Slot)
		ZS_Knowledge_ComputeReserve()
		Return
	EndIf

	Local $l_i_Dur = ZS_Knowledge_Duration($a_i_SkillID)
	Local $l_i_Scale = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_SCALE_15)
	If ZS_SkillData($a_i_SkillID, $GC_I_SKILL_SCALE_0) > $l_i_Scale Then $l_i_Scale = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_SCALE_0)

	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_TYPE)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Target] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_TARGET_TYPE)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Special] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_SPECIAL)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Effect1] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_EFFECT_1)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Effect2] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_EFFECT_2)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Req] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_REQ)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_WeaponReq] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_WEAPON_REQ)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ComboType] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_COMBO_TYPE)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ComboReq] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_COMBO_REQ)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Energy] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_ENERGY_REQ)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AdrenReq] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_ADRENALINE_REQ)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ActivationMs] = ZS_Knowledge_ActivationMs($a_i_SkillID)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AftercastMs] = Int(ZS_SkillData($a_i_SkillID, $GC_F_SKILL_AFTERCAST) * 1000)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Recharge] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_RECHARGE_TIME)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Duration] = $l_i_Dur
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Scale] = $l_i_Scale
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_AOE_RANGE)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Attribute] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_ATTRIBUTE)
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Profession] = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_PROFESSION)

	; Sacrifice and overcast are missing from the offline table: read once from the game when attached
	; (offline, the test snapshots give them on the S| line)
	If $g_h_GWProcess <> 0 And $g_p_SkillBase <> 0 Then
		$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_HealthCost] = Skill_GetSkillInfo($a_i_SkillID, "HealthCost")
		$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_OvercastCost] = Skill_GetSkillInfo($a_i_SkillID, "Overcast")
	EndIf

	Local $l_i_Mask = 0
	Local $l_i_Family = ZS_Knowledge_Classify($a_i_SkillID, $l_i_Mask)
	Local $l_s_Origin = "rule"
	Local $l_s_DefParams = ""
	If MapExists($g_m_ZS_Defs, $a_i_SkillID) Then
		Local $l_av_Def = $g_m_ZS_Defs[$a_i_SkillID]
		If $l_av_Def[0] >= 0 Then $l_i_Family = $l_av_Def[0] ; -1 = keep the family deduced from the game data
		If $l_av_Def[1] >= 0 Then $l_i_Mask = $l_av_Def[1]
		$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Weight] = $l_av_Def[2]
		$l_s_DefParams = $l_av_Def[3]
		$l_s_Origin = "def"
	EndIf
	Local $l_s_Params = ""
	If MapExists($g_m_ZS_GenParams, $a_i_SkillID) Then
		$l_s_Params = $g_m_ZS_GenParams[$a_i_SkillID]
		; Heals follow Zaishen's own health tiers: the fixed thresholds of UtilityAI are dropped
		; (a heal that is better under some health says so with BonusBelow= in ZS_SkillDefs.au3)
		Switch $l_i_Family
			Case $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_FAM_HEAL_SELF, $GC_ZS_FAM_HEAL_PARTY
				$l_s_Params = ZS_Knowledge_DropKeys($l_s_Params, "TargetBelow,TargetAbove,MyHPBelow,MyHPAbove")
		EndSwitch
		If $l_s_Origin = "rule" Then $l_s_Origin = "rule+uai"
	EndIf
	; dedicated parameters come last: the parser keeps the last value of a key
	If $l_s_DefParams <> "" Then $l_s_Params = ($l_s_Params = "" ? "" : $l_s_Params & "|") & $l_s_DefParams

	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Family] = $l_i_Family
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_TargetMask] = $l_i_Mask
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Params] = $l_s_Params
	$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Origin] = $l_s_Origin

	If $l_s_Params <> "" Then
		Local $l_m_Params[]
		Local $l_as_Pairs = StringSplit($l_s_Params, "|", 2)
		For $i = 0 To UBound($l_as_Pairs) - 1
			Local $l_i_Eq = StringInStr($l_as_Pairs[$i], "=")
			If $l_i_Eq > 1 Then $l_m_Params[StringLeft($l_as_Pairs[$i], $l_i_Eq - 1)] = StringMid($l_as_Pairs[$i], $l_i_Eq + 1)
		Next
		$g_am_ZS_SlotParams[$a_i_Slot] = $l_m_Params
	EndIf
	ZS_Req_Prepare($a_i_Slot)

	ZS_Knowledge_ComputeReserve()
EndFunc   ;==>ZS_Knowledge_ResolveSlot

;~ Description: "Key=Value|..." without the keys listed in $a_s_Keys ("A,B").
Func ZS_Knowledge_DropKeys($a_s_Params, $a_s_Keys)
	Local $l_as_Pairs = StringSplit($a_s_Params, "|", 2), $l_s_Out = ""
	For $i = 0 To UBound($l_as_Pairs) - 1
		Local $l_s_Key = StringLeft($l_as_Pairs[$i], StringInStr($l_as_Pairs[$i], "=") - 1)
		If StringInStr("," & $a_s_Keys & ",", "," & $l_s_Key & ",") Then ContinueLoop
		$l_s_Out &= ($l_s_Out = "" ? "" : "|") & $l_as_Pairs[$i]
	Next
	Return $l_s_Out
EndFunc   ;==>ZS_Knowledge_DropKeys

;~ Description: Duration in seconds of one of OUR skills at the player's rank in its attribute
;~ (the game data gives it at ranks 0 and 15; it grows linearly, and on above 15 with runes and headgear).
Func ZS_Knowledge_Duration($a_i_SkillID)
	Local $l_f_D0 = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_DURATION_0)
	Local $l_f_D15 = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_DURATION_15)
	If $l_f_D0 <= 0 Then Return $l_f_D15
	If $l_f_D15 <= 0 Or $l_f_D15 = $l_f_D0 Then Return $l_f_D0
	Return Int($l_f_D0 + ($l_f_D15 - $l_f_D0) * ZS_Knowledge_Rank(ZS_SkillData($a_i_SkillID, $GC_I_SKILL_ATTRIBUTE)) / 15)
EndFunc   ;==>ZS_Knowledge_Duration

;~ Description: The player's rank in an attribute: read from the game when attached, $g_i_ZS_OfflineRank otherwise.
Func ZS_Knowledge_Rank($a_i_Attribute)
	If $a_i_Attribute = $GC_I_ATTRIBUTE_NONE Then Return 0
	If $g_h_GWProcess <> 0 And $g_p_SkillBase <> 0 Then Return Attribute_GetPartyAttributeInfo($a_i_Attribute, 0, "CurrentLevel")
	Return $g_i_ZS_OfflineRank
EndFunc   ;==>ZS_Knowledge_Rank

;~ Description: Activation of one of OUR skills in ms. Fast Casting (Mesmer primary attribute) shortens
;~ spells and signets: every Mesmer one, the others only from 2 s of activation.
Func ZS_Knowledge_ActivationMs($a_i_SkillID)
	Local $l_f_Ms = ZS_SkillData($a_i_SkillID, $GC_F_SKILL_ACTIVATION_TIME) * 1000
	If $g_i_ZS_FastCasting > 0 And $l_f_Ms > 0 Then
		Local $l_i_Type = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_TYPE)
		If ZS_IsSpellType($l_i_Type) Or $l_i_Type = $GC_I_SKILL_TYPE_SIGNET Then
			If ZS_SkillData($a_i_SkillID, $GC_I_SKILL_PROFESSION) = $GC_I_PROFESSION_MESMER Or $l_f_Ms >= 2000 Then
				$l_f_Ms *= 2 ^ (-$g_i_ZS_FastCasting / 15)
			EndIf
		EndIf
	EndIf
	Return Int($l_f_Ms)
EndFunc   ;==>ZS_Knowledge_ActivationMs

;~ Description: Resolve a whole bar from 8 skill IDs (tests, tools).
Func ZS_Knowledge_ResolveBar($a_ai_SkillIDs)
	For $l_i_Slot = 1 To 8
		Local $l_i_ID = 0
		If $l_i_Slot - 1 < UBound($a_ai_SkillIDs) Then $l_i_ID = $a_ai_SkillIDs[$l_i_Slot - 1]
		ZS_Knowledge_ResolveSlot($l_i_Slot, $l_i_ID)
	Next
EndFunc   ;==>ZS_Knowledge_ResolveBar

;~ Description: Parameter of a slot ("Key=Value" of its definition), $a_v_Default when absent.
Func ZS_SlotParam($a_i_Slot, $a_s_Key, $a_v_Default = "")
	Local $l_m_Params = $g_am_ZS_SlotParams[$a_i_Slot]
	If IsMap($l_m_Params) And MapExists($l_m_Params, $a_s_Key) Then Return $l_m_Params[$a_s_Key]
	Return $a_v_Default
EndFunc   ;==>ZS_SlotParam

;~ Description: Energy to keep for the dearest emergency skill of the bar (heal, protection, resurrection).
Func ZS_Knowledge_ComputeReserve()
	Local $l_f_Reserve = 0
	For $l_i_Slot = 1 To 8
		Switch $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Family]
			Case $GC_ZS_FAM_RESURRECT, $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_FAM_HEAL_SELF, $GC_ZS_FAM_HEAL_PARTY, $GC_ZS_FAM_PROTECT
				If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_AdrenReq] = 0 And $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Energy] > $l_f_Reserve Then _
						$l_f_Reserve = $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Energy]
		EndSwitch
	Next
	$g_f_ZS_ReserveEnergy = $l_f_Reserve
EndFunc   ;==>ZS_Knowledge_ComputeReserve

;~ Description: Band a family plays in for a given utility. Urgent families climb with their utility.
Func ZS_Knowledge_Band($a_i_Family, $a_f_Utility)
	Switch $a_i_Family
		Case $GC_ZS_FAM_RESURRECT
			Return $GC_ZS_BAND_RESURRECT
		Case $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_FAM_HEAL_SELF, $GC_ZS_FAM_HEAL_PARTY
			If $a_f_Utility >= 0.8 Then Return $GC_ZS_BAND_SURVIVAL
			If $a_f_Utility >= 0.3 Then Return $GC_ZS_BAND_HEAL
			Return $GC_ZS_BAND_DAMAGE
		Case $GC_ZS_FAM_PROTECT
			If $a_f_Utility >= 0.75 Then Return $GC_ZS_BAND_SURVIVAL
			If $a_f_Utility >= 0.4 Then Return $GC_ZS_BAND_HEAL
			Return $GC_ZS_BAND_DAMAGE
		Case $GC_ZS_FAM_INTERRUPT
			Return $GC_ZS_BAND_INTERRUPT
		Case $GC_ZS_FAM_HEX_REMOVAL, $GC_ZS_FAM_COND_REMOVAL
			Return $GC_ZS_BAND_CLEANSE
		Case $GC_ZS_FAM_ENERGY, $GC_ZS_FAM_ENERGY_BUFF
			Return $GC_ZS_BAND_UPKEEP
	EndSwitch
	; Buffs, spirits, minions, wards and damage share one band and are compared by utility.
	; A buff that is about to end is raised to Upkeep by the evaluation (renewal).
	Return $GC_ZS_BAND_DAMAGE
EndFunc   ;==>ZS_Knowledge_Band
#EndRegion Bar resolution
