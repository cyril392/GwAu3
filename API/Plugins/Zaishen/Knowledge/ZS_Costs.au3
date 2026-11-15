#include-once

; Zaishen costs: what a skill really costs right now (energy, health, overcast).
; The effects that change the energy cost live in ONE table: add a line, not code, for a new one.
; Pure functions on the snapshot.

; Which skills an effect applies to
Global Enum $GC_ZS_CS_ALL, _        ; every skill
	$GC_ZS_CS_TYPE, _               ; skills of type <value>
	$GC_ZS_CS_SPELLS, _             ; every spell type (spell, hex, enchantment, well, ward, weapon and item spells)
	$GC_ZS_CS_SPELL_ON_OTHER, _     ; spells cast on someone else than the player
	$GC_ZS_CS_ATTRS, _              ; skills of the attributes listed in <value> ("13,14")
	$GC_ZS_CS_RIT_HEX, _            ; Ritualist hexes
	$GC_ZS_CS_BOW, _                ; bow attacks
	$GC_ZS_CS_OFF_OR_DUAL           ; off-hand and dual attacks

; What it does to the cost
Global Enum $GC_ZS_CO_MUL, _        ; cost x value
	$GC_ZS_CO_ADD, _                ; cost + value
	$GC_ZS_CO_SUB, _                ; cost - value
	$GC_ZS_CO_ADD_SCALE, _          ; cost + strength of the effect
	$GC_ZS_CO_SUB_SCALE, _          ; cost - strength of the effect
	$GC_ZS_CO_SUB_BONUS, _          ; cost - bonus strength of the effect
	$GC_ZS_CO_SUB_PCT, _            ; cost - base cost x strength %
	$GC_ZS_CO_SUB15_MIN10, _        ; cost - 15, not under 10
	$GC_ZS_CO_FREE                  ; cost = 0

; [effect on the player, scope, scope value, operation, value]
; Strength = Scale (or BonusScale) of the effect at its attribute level, from the offline table.
Global Const $GC_AMX2_ZS_COST_MODS[22][5] = [ _
		[$GC_I_SKILL_ID_QUICKENING_ZEPHYR, $GC_ZS_CS_ALL, 0, $GC_ZS_CO_MUL, 1.3], _
		[$GC_I_SKILL_ID_NATURES_RENEWAL, $GC_ZS_CS_TYPE, $GC_I_SKILL_TYPE_HEX, $GC_ZS_CO_MUL, 2], _
		[$GC_I_SKILL_ID_NATURES_RENEWAL, $GC_ZS_CS_TYPE, $GC_I_SKILL_TYPE_ENCHANTMENT, $GC_ZS_CO_MUL, 2], _
		[$GC_I_SKILL_ID_PRIMAL_ECHOES, $GC_ZS_CS_TYPE, $GC_I_SKILL_TYPE_SIGNET, $GC_ZS_CO_ADD, 10], _
		[$GC_I_SKILL_ID_ROARING_WINDS, $GC_ZS_CS_TYPE, $GC_I_SKILL_TYPE_SHOUT, $GC_ZS_CO_ADD_SCALE, 0], _
		[$GC_I_SKILL_ID_ROARING_WINDS, $GC_ZS_CS_TYPE, $GC_I_SKILL_TYPE_CHANT, $GC_ZS_CO_ADD_SCALE, 0], _
		[$GC_I_SKILL_ID_ANGUISHED_WAS_LINGWAH, $GC_ZS_CS_RIT_HEX, 0, $GC_ZS_CO_SUB, 5], _
		[$GC_I_SKILL_ID_SELFLESS_SPIRIT_LUXON, $GC_ZS_CS_SPELL_ON_OTHER, 0, $GC_ZS_CO_SUB, 3], _
		[$GC_I_SKILL_ID_SELFLESS_SPIRIT_KURZICK, $GC_ZS_CS_SPELL_ON_OTHER, 0, $GC_ZS_CO_SUB, 3], _
		[$GC_I_SKILL_ID_GLYPH_OF_LESSER_ENERGY, $GC_ZS_CS_SPELLS, 0, $GC_ZS_CO_SUB_SCALE, 0], _
		[$GC_I_SKILL_ID_GLYPH_OF_ENERGY, $GC_ZS_CS_SPELLS, 0, $GC_ZS_CO_SUB_SCALE, 0], _
		[$GC_I_SKILL_ID_ATTUNED_WAS_SONGKAI, $GC_ZS_CS_SPELLS, 0, $GC_ZS_CO_SUB_PCT, 0], _
		[$GC_I_SKILL_ID_SOUL_TWISTING, $GC_ZS_CS_TYPE, $GC_I_SKILL_TYPE_RITUAL, $GC_ZS_CO_SUB, 15], _
		[$GC_I_SKILL_ID_RENEWING_MEMORIES, $GC_ZS_CS_TYPE, $GC_I_SKILL_TYPE_WEAPON_SPELL, $GC_ZS_CO_SUB_PCT, 0], _
		[$GC_I_SKILL_ID_RENEWING_MEMORIES, $GC_ZS_CS_TYPE, $GC_I_SKILL_TYPE_ITEM_SPELL, $GC_ZS_CO_SUB_PCT, 0], _
		[$GC_I_SKILL_ID_ENERGIZING_WIND, $GC_ZS_CS_ALL, 0, $GC_ZS_CO_SUB15_MIN10, 0], _
		[$GC_I_SKILL_ID_DIVINE_SPIRIT, $GC_ZS_CS_ATTRS, "13,14,15,16", $GC_ZS_CO_SUB, 5], _
		[$GC_I_SKILL_ID_HEALERS_COVENANT, $GC_ZS_CS_ATTRS, "13", $GC_ZS_CO_SUB_BONUS, 0], _
		[$GC_I_SKILL_ID_CULTISTS_FERVOR, $GC_ZS_CS_ATTRS, "4,5,6,7", $GC_ZS_CO_SUB_SCALE, 0], _
		[$GC_I_SKILL_ID_EXPERT_FOCUS, $GC_ZS_CS_BOW, 0, $GC_ZS_CO_SUB_SCALE, 0], _
		[$GC_I_SKILL_ID_WAY_OF_THE_EMPTY_PALM, $GC_ZS_CS_OFF_OR_DUAL, 0, $GC_ZS_CO_FREE, 0], _
		[0, $GC_ZS_CS_ALL, 0, $GC_ZS_CO_ADD, 0]] ; spare line

;~ Description: Energy the skill of the slot costs right now. $a_b_OnOther: cast on someone else than the player.
Func ZS_Cost_Energy($a_i_Slot, $a_b_OnOther = False)
	Local $l_f_Base = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Energy]
	If $l_f_Base <= 0 Then Return 0
	Local $l_f_Cost = $l_f_Base
	Local $l_b_Free = False, $l_b_Min10 = False
	Local $l_i_Effect, $l_i_Op

	; Multiplications first, then additions and reductions (same order as the game)
	For $l_i_Pass = 1 To 2
		For $i = 0 To UBound($GC_AMX2_ZS_COST_MODS) - 1
			$l_i_Effect = $GC_AMX2_ZS_COST_MODS[$i][0]
			If $l_i_Effect = 0 Or Not MapExists($g_m_ZS_SelfFx, $l_i_Effect) Then ContinueLoop
			$l_i_Op = $GC_AMX2_ZS_COST_MODS[$i][3]
			If ($l_i_Op = $GC_ZS_CO_MUL) <> ($l_i_Pass = 1) Then ContinueLoop
			If Not ZS_Cost_InScope($a_i_Slot, $GC_AMX2_ZS_COST_MODS[$i][1], $GC_AMX2_ZS_COST_MODS[$i][2], $a_b_OnOther) Then ContinueLoop

			Switch $l_i_Op
				Case $GC_ZS_CO_MUL
					$l_f_Cost *= $GC_AMX2_ZS_COST_MODS[$i][4]
				Case $GC_ZS_CO_ADD
					$l_f_Cost += $GC_AMX2_ZS_COST_MODS[$i][4]
				Case $GC_ZS_CO_SUB
					$l_f_Cost -= $GC_AMX2_ZS_COST_MODS[$i][4]
				Case $GC_ZS_CO_ADD_SCALE
					$l_f_Cost += ZS_SelfFxScale($l_i_Effect)
				Case $GC_ZS_CO_SUB_SCALE
					$l_f_Cost -= ZS_SelfFxScale($l_i_Effect)
				Case $GC_ZS_CO_SUB_BONUS
					$l_f_Cost -= ZS_SelfFxScale($l_i_Effect, True)
				Case $GC_ZS_CO_SUB_PCT
					$l_f_Cost -= $l_f_Base * ZS_SelfFxScale($l_i_Effect) / 100
				Case $GC_ZS_CO_SUB15_MIN10
					$l_b_Min10 = True
				Case $GC_ZS_CO_FREE
					$l_b_Free = True
			EndSwitch
		Next
	Next

	; Expertise: attacks, rituals and touch skills, 4 % per rank
	If $g_i_ZS_Expertise > 0 Then
		Local $l_i_Type = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type]
		If $l_i_Type = $GC_I_SKILL_TYPE_ATTACK Or $l_i_Type = $GC_I_SKILL_TYPE_RITUAL Or _
				BitAND($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Special], $GC_I_SKILL_SPECIAL_FLAG_TOUCH) Then
			$l_f_Cost -= $l_f_Base * 0.04 * $g_i_ZS_Expertise
		EndIf
	EndIf

	If $l_b_Min10 And $l_f_Cost > 10 Then
		$l_f_Cost -= 15
		If $l_f_Cost < 10 Then $l_f_Cost = 10
	EndIf
	If $l_b_Free Then Return 0
	If $l_f_Cost < 1 Then $l_f_Cost = 1
	Return Ceiling($l_f_Cost)
EndFunc   ;==>ZS_Cost_Energy

;~ Description: True when a cost effect applies to the skill of the slot.
Func ZS_Cost_InScope($a_i_Slot, $a_i_Scope, $a_v_Value, $a_b_OnOther)
	Local $l_i_Type = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type]
	Switch $a_i_Scope
		Case $GC_ZS_CS_ALL
			Return True
		Case $GC_ZS_CS_TYPE
			Return $l_i_Type = $a_v_Value
		Case $GC_ZS_CS_SPELLS
			Return ZS_IsSpellType($l_i_Type)
		Case $GC_ZS_CS_SPELL_ON_OTHER
			Return $a_b_OnOther And ZS_IsSpellType($l_i_Type)
		Case $GC_ZS_CS_ATTRS
			Return StringInStr("," & $a_v_Value & ",", "," & $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Attribute] & ",") > 0
		Case $GC_ZS_CS_RIT_HEX
			Return $l_i_Type = $GC_I_SKILL_TYPE_HEX And $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Profession] = $GC_I_PROFESSION_RITUALIST
		Case $GC_ZS_CS_BOW
			Return $l_i_Type = $GC_I_SKILL_TYPE_ATTACK And $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_WeaponReq] = $GC_I_SKILL_REQUIRE_BOW
		Case $GC_ZS_CS_OFF_OR_DUAL
			Local $l_i_Combo = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ComboType]
			Return $l_i_Combo = $GC_I_SKILL_COMBO_OFF_HAND_ATTACK Or $l_i_Combo = $GC_I_SKILL_COMBO_DUAL_ATTACK
	EndSwitch
	Return False
EndFunc   ;==>ZS_Cost_InScope

;~ Description: Health the skill of the slot would take, in absolute points (0 when it takes none or max health is unknown).
Func ZS_Cost_Health($a_i_Slot)
	Local $l_f_MaxHP = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_MaxHP]
	If $l_f_MaxHP <= 0 Then Return 0
	Local $l_f_Cost = $l_f_MaxHP * $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_HealthCost] / 100
	If $l_f_Cost > 0 Then
		If MapExists($g_m_ZS_SelfFx, $GC_I_SKILL_ID_AWAKEN_THE_BLOOD) Then $l_f_Cost *= 1.5
		If MapExists($g_m_ZS_SelfFx, $GC_I_SKILL_ID_SCOURGE_SACRIFICE) Then $l_f_Cost *= 2
	EndIf
	; Masochism: every spell takes 5 % of max health
	If MapExists($g_m_ZS_SelfFx, $GC_I_SKILL_ID_MASOCHISM) And ZS_IsSpellType($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type]) Then $l_f_Cost += $l_f_MaxHP * 0.05
	Return $l_f_Cost
EndFunc   ;==>ZS_Cost_Health

;~ Description: Reason the player cannot pay for the skill of this slot right now, "" when he can.
;~ $a_b_OnOther: cast on someone else than the player (cheaper under Selfless Spirit).
Func ZS_Cost_Veto($a_i_Slot, $a_b_OnOther = False)
	; Not enough in hand: another weapon set may lend it (ZS_Weapon_BorrowOK decides per action)
	Local $l_f_Cost = ZS_Cost_Energy($a_i_Slot, $a_b_OnOther)
	If $l_f_Cost > $g_f_ZS_Energy And ZS_Weapon_EnergySet($l_f_Cost) = 0 Then Return "energy"

	Local $l_f_Health = ZS_Cost_Health($a_i_Slot)
	If $l_f_Health > 0 Then
		Local $l_f_MaxHP = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_MaxHP]
		Local $l_f_Left = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_HP] * $l_f_MaxHP - $l_f_Health
		If $l_f_Left < $g_f_ZS_SacrificeFloor * $l_f_MaxHP Then Return "sacrifice"
	EndIf

	Local $l_i_Overcast = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_OvercastCost]
	If $l_i_Overcast > 0 And Not MapExists($g_m_ZS_SelfFx, $GC_I_SKILL_ID_GLYPH_OF_ENERGY) Then
		If $g_i_ZS_Overcast + $l_i_Overcast >= $g_f_ZS_MaxEnergy * 0.5 Then Return "overcast"
	EndIf
	Return ""
EndFunc   ;==>ZS_Cost_Veto
