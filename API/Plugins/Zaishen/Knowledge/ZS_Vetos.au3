#include-once

; Zaishen vetos: reasons an action must not be attempted at all, checked before any scoring.
; Pure functions on the snapshot. A veto returns a short reason, "" means "allowed".

; What a punishing hex applies to
Global Const $GC_ZS_PUN_SPELL = 0x1        ; any spell
Global Const $GC_ZS_PUN_ATTACK = 0x2       ; attack skills and auto attack
Global Const $GC_ZS_PUN_ANY = 0x4          ; any skill
Global Const $GC_ZS_PUN_ALLYSPELL = 0x8    ; spells that target an ally
Global Const $GC_ZS_PUN_FOESPELL = 0x10    ; spells that target a foe

; Hexes that punish the bearer for acting: [skill ID, what it applies to, hurts (True) or simply forbids (False)]
; A hex that hurts is tolerated while the player can take the hit.
Global Const $GC_AMX2_ZS_PUNISHERS[15][3] = [ _
		[$GC_I_SKILL_ID_BACKFIRE, $GC_ZS_PUN_SPELL, True], _
		[$GC_I_SKILL_ID_VISIONS_OF_REGRET, $GC_ZS_PUN_ANY, True], _
		[$GC_I_SKILL_ID_SOUL_LEECH, $GC_ZS_PUN_SPELL, True], _
		[$GC_I_SKILL_ID_SPITEFUL_SPIRIT, $GC_ZS_PUN_SPELL + $GC_ZS_PUN_ATTACK, True], _
		[$GC_I_SKILL_ID_EMPATHY, $GC_ZS_PUN_ATTACK, True], _
		[$GC_I_SKILL_ID_INSIDIOUS_PARASITE, $GC_ZS_PUN_ATTACK, True], _
		[$GC_I_SKILL_ID_PRICE_OF_FAILURE, $GC_ZS_PUN_ATTACK, True], _
		[$GC_I_SKILL_ID_DIVERSION, $GC_ZS_PUN_ANY, False], _
		[$GC_I_SKILL_ID_SHAME, $GC_ZS_PUN_ALLYSPELL, False], _
		[$GC_I_SKILL_ID_MARK_OF_SUBVERSION, $GC_ZS_PUN_ALLYSPELL, False], _
		[$GC_I_SKILL_ID_GUILT, $GC_ZS_PUN_FOESPELL, False], _
		[$GC_I_SKILL_ID_MISTRUST, $GC_ZS_PUN_FOESPELL, False], _
		[$GC_I_SKILL_ID_INEPTITUDE, $GC_ZS_PUN_ATTACK, False], _
		[$GC_I_SKILL_ID_CLUMSINESS, $GC_ZS_PUN_ATTACK, False], _
		[$GC_I_SKILL_ID_SPIRIT_SHACKLES, $GC_ZS_PUN_ATTACK, False]]

;~ Description: Reason the player cannot pay for the skill of this slot right now, "" when he can.
Func ZS_Veto_Resources($a_i_Slot)
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AdrenReq] > 0 Then
		If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Adrenaline] < $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AdrenReq] Then Return "adrenaline"
	ElseIf Not $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Recharged] Then
		Return "recharge"
	EndIf
	; Energy, sacrifice, overcast. Cheapest case here (cast on someone else), the exact one is checked per target.
	Local $l_s_Cost = ZS_Cost_Veto($a_i_Slot, $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_TargetMask] <> $GC_ZS_TM_SELF)
	If $l_s_Cost <> "" Then Return $l_s_Cost

	; An enchantment already seen kept up by the player: each one more costs energy regeneration
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ENCHANTMENT And MapExists($g_m_ZS_Maintainable, $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID]) Then
		If $g_i_ZS_MaintainedCount >= $g_i_ZS_MaxMaintained Then Return "maintained limit"
		If $g_i_ZS_EnergyPips <= 0 Then Return "no energy regeneration"
	EndIf

	Local $l_i_Req = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_WeaponReq]
	; Another set may hold the weapon: the execution switches to it first
	If $l_i_Req <> 0 And BitAND($l_i_Req, ZS_Weapon_ActiveBit()) = 0 Then
		If ZS_Weapon_SetWithBit($l_i_Req) = 0 Or Not ZS_Weapon_CanSwitch(False) Then Return "weapon"
	EndIf
	Return ""
EndFunc   ;==>ZS_Veto_Resources

;~ Description: Bit of the skill weapon requirement mask matching a wielded weapon type.
Func ZS_Veto_WeaponBit($a_i_WeaponType)
	Switch $a_i_WeaponType
		Case $GC_I_WEAPON_TYPE_AXE
			Return $GC_I_SKILL_REQUIRE_AXE
		Case $GC_I_WEAPON_TYPE_BOW
			Return $GC_I_SKILL_REQUIRE_BOW
		Case $GC_I_WEAPON_TYPE_DAGGERS
			Return $GC_I_SKILL_REQUIRE_DAGGER
		Case $GC_I_WEAPON_TYPE_HAMMER
			Return $GC_I_SKILL_REQUIRE_HAMMER
		Case $GC_I_WEAPON_TYPE_SCYTHE
			Return $GC_I_SKILL_REQUIRE_SCYTHE
		Case $GC_I_WEAPON_TYPE_SPEAR
			Return $GC_I_SKILL_REQUIRE_SPEAR
		Case $GC_I_WEAPON_TYPE_SWORD
			Return $GC_I_SKILL_REQUIRE_SWORD
	EndSwitch
	Return 4 ; wand or staff: the unnamed bit of the "ranged, no weapon needed" mask
EndFunc   ;==>ZS_Veto_WeaponBit

;~ Description: Name of the hex on the player that forbids this kind of action, "" when none does.
;~ $a_i_Kind is a mask of $GC_ZS_PUN_* describing the action.
Func ZS_Veto_Punished($a_i_Kind)
	If Not ZS_Is($g_i_ZS_MeIdx, $GC_ZS_AF_HEXED) Then Return ""

	Local $l_f_MaxHP = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_MaxHP]
	Local $l_f_HP = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_HP]
	For $i = 0 To UBound($GC_AMX2_ZS_PUNISHERS) - 1
		If BitAND($GC_AMX2_ZS_PUNISHERS[$i][1], $a_i_Kind) = 0 Then ContinueLoop
		If Not MapExists($g_m_ZS_SelfFx, $GC_AMX2_ZS_PUNISHERS[$i][0]) Then ContinueLoop
		If $GC_AMX2_ZS_PUNISHERS[$i][2] Then
			; Worst case damage of the hex against what is left, keeping a 15 % cushion
			Local $l_i_Hit = ZS_SkillData($GC_AMX2_ZS_PUNISHERS[$i][0], $GC_I_SKILL_SCALE_15)
			If $l_f_MaxHP > 0 Then
				If $l_f_HP * $l_f_MaxHP > $l_i_Hit + 0.15 * $l_f_MaxHP Then ContinueLoop
			ElseIf $l_f_HP > 0.5 Then
				ContinueLoop
			EndIf
		EndIf
		Return ZS_SkillName($GC_AMX2_ZS_PUNISHERS[$i][0])
	Next
	Return ""
EndFunc   ;==>ZS_Veto_Punished

;~ Description: $GC_ZS_PUN_* mask describing the use of the skill of this slot on a foe or on our side.
Func ZS_Veto_KindOf($a_i_Slot, $a_b_OnFoe)
	Local $l_i_Kind = $GC_ZS_PUN_ANY
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ATTACK Then $l_i_Kind += $GC_ZS_PUN_ATTACK
	If ZS_IsSpellType($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type]) Then
		$l_i_Kind += $GC_ZS_PUN_SPELL
		$l_i_Kind += ($a_b_OnFoe ? $GC_ZS_PUN_FOESPELL : $GC_ZS_PUN_ALLYSPELL)
	EndIf
	Return $l_i_Kind
EndFunc   ;==>ZS_Veto_KindOf

;~ Description: True when the assassin chain requirement of the slot is met on this target.
Func ZS_Veto_ComboOK($a_i_Slot, $a_i_TargetIdx)
	Local $l_i_Req = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ComboReq]
	If $l_i_Req = 0 Then Return True
	Local $l_i_Last = $g_amx2_ZS_Agent[$a_i_TargetIdx][$GC_ZS_A_LastStrike]
	If BitAND($l_i_Req, $GC_I_SKILL_COMBO_REQ_LEAD_ATTACK) And $l_i_Last = $GC_I_SKILL_COMBO_LEAD_ATTACK Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_COMBO_REQ_OFF_HAND_ATTACK) And $l_i_Last = $GC_I_SKILL_COMBO_OFF_HAND_ATTACK Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_COMBO_REQ_DUAL_ATTACK) And $l_i_Last = $GC_I_SKILL_COMBO_DUAL_ATTACK Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_COMBO_REQ_HEXED_FOE) And ZS_Is($a_i_TargetIdx, $GC_ZS_AF_HEXED) Then Return True
	Return False
EndFunc   ;==>ZS_Veto_ComboOK
