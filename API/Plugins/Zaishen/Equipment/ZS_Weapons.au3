#include-once

; Zaishen weapon sets: which of the 4 sets of the game to hold for the action decided.
; - The build fights with its HOME set: the one whose weapon its attack skills need (daggers of an assassin),
;   or, without attack skills, the set with the most energy.
; - It leaves it only when the action needs or clearly gains from another set, and comes back for its attacks:
;     an attack skill that needs another weapon;
;     energy: a set with more energy gives it at once (the game hides the difference again on the way back:
;       it is borrowed), only for an action that is worth the debt;
;     enchantment duration: an enchantment cast with a clearly better "of Enchanting" set, when no attack waits.
; - Never more than 4 switches in 10 s (then frozen 5 s), never an optional switch in the middle of a chain,
;   never an optional switch less than 4 s after the previous one.
; Mods are read from the item mod structure (identifiers below; to confirm in game with ZS_Weapon_Describe).

#Region Read from the game
;~ Description: Read the 4 weapon sets and their mods (instance change, or when the weapon in hand is unknown).
Func ZS_Weapon_ReadSets()
	$g_i_ZS_SetsReadAt = $g_i_ZS_Now
	Local $l_p_Weapon, $l_p_Offhand
	For $l_i_Set = 1 To 4
		ZS_Weapon_ClearSet($l_i_Set)
		$l_p_Weapon = Item_GetInventoryInfo("WeaponSet" & ($l_i_Set - 1) & "WeaponPtr")
		$l_p_Offhand = Item_GetInventoryInfo("WeaponSet" & ($l_i_Set - 1) & "OffhandPtr")
		If $l_p_Weapon <> 0 Then
			$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_WeaponID] = Item_GetItemInfoByPtr($l_p_Weapon, "ItemID")
			$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_ItemType] = Item_GetItemInfoByPtr($l_p_Weapon, "ItemType")
			ZS_Weapon_ParseMods($l_i_Set, Item_GetModStruct($l_p_Weapon))
		EndIf
		If $l_p_Offhand <> 0 Then
			$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_OffhandID] = Item_GetItemInfoByPtr($l_p_Offhand, "ItemID")
			$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_OffhandType] = Item_GetItemInfoByPtr($l_p_Offhand, "ItemType")
			ZS_Weapon_ParseMods($l_i_Set, Item_GetModStruct($l_p_Offhand))
		EndIf
		ZS_Weapon_FinishSet($l_i_Set)
	Next
EndFunc   ;==>ZS_Weapon_ReadSets

Func ZS_Weapon_ClearSet($a_i_Set)
	For $i = 0 To $GC_ZS_W_COUNT - 1
		$g_amx2_ZS_WSet[$a_i_Set][$i] = 0
	Next
EndFunc   ;==>ZS_Weapon_ClearSet

Func ZS_Weapon_FinishSet($a_i_Set)
	$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_Present] = ($g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_ItemType] <> 0 Or $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_OffhandType] <> 0)
	$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_Bit] = ZS_Weapon_ItemBit($g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_ItemType])
EndFunc   ;==>ZS_Weapon_FinishSet

;~ Description: Add the mods of one item (raw mod structure) to set $a_i_Set.
;~ Each mod is 4 bytes: arg1, arg2, identifier (2 bytes), as the GwAu3 mod tables write them.
Func ZS_Weapon_ParseMods($a_i_Set, $a_v_ModStruct)
	Local $l_s_Hex = StringUpper(String($a_v_ModStruct))
	If StringLeft($l_s_Hex, 2) = "0X" Then $l_s_Hex = StringTrimLeft($l_s_Hex, 2)
	Local $l_i_A1, $l_i_A2
	For $i = 0 To Int(StringLen($l_s_Hex) / 8) - 1
		$l_i_A1 = Dec(StringMid($l_s_Hex, 8 * $i + 1, 2))
		$l_i_A2 = Dec(StringMid($l_s_Hex, 8 * $i + 3, 2))
		Switch StringMid($l_s_Hex, 8 * $i + 5, 4)
			Case "C867" ; energy of a caster item (staff, wand, focus)
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EFlat] += $l_i_A2
			Case "D822" ; Energy +N (Insightful, I have the power!, Seize the Day, Live for Today)
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EFlat] += $l_i_A1
			Case "B820" ; Energy -N (Brawn over Brains, Ignorance is Bliss)
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EFlat] -= $l_i_A1
			Case "F822" ; Energy +N while enchanted
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EEnch] += $l_i_A1
			Case "2823" ; Energy +N while hexed
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHex] += $l_i_A1
			Case "0823" ; Energy +N while health above arg2 %
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPHi] += $l_i_A1
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPHiThr] = $l_i_A2
			Case "1823" ; Energy +N while health below arg2 %
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPLo] += $l_i_A1
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPLoThr] = $l_i_A2
			Case "B822" ; +N % enchantment duration
				$g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_Ench] += $l_i_A1
			Case "0822", "0828" ; half casting time, N % chance
				If $l_i_A2 > $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_HCT] Then $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_HCT] = $l_i_A2
			Case "A823", "2828" ; half recharge time, N % chance
				If $l_i_A2 > $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_HSR] Then $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_HSR] = $l_i_A2
		EndSwitch
	Next
EndFunc   ;==>ZS_Weapon_ParseMods

;~ Description: Find the set in hand from the items held. Called by ZS_Perceive every tick (no memory read).
Func ZS_Weapon_Perceive($a_i_WeaponID, $a_i_OffhandID, $a_b_NewInstance)
	Local $l_b_Read = ($a_b_NewInstance Or $g_i_ZS_SetsReadAt < 0)
	If $l_b_Read Then ZS_Weapon_ReadSets()
	$g_i_ZS_ActiveSet = ZS_Weapon_FindActive($a_i_WeaponID, $a_i_OffhandID)
	; What was read, in the journal: checks the sets and the item IDs in game
	If $l_b_Read Then ZS_Log_Event("weapon sets (held items " & $a_i_WeaponID & "/" & $a_i_OffhandID & "): " & StringReplace(ZS_Weapon_Describe(), @CRLF, " |"))
	; Items changed since the sets were read (the player swapped a weapon): read again, not too often
	If $g_i_ZS_ActiveSet = 0 And ($a_i_WeaponID <> 0 Or $a_i_OffhandID <> 0) And $g_i_ZS_Now - $g_i_ZS_SetsReadAt > 3000 Then
		ZS_Weapon_ReadSets()
		$g_i_ZS_ActiveSet = ZS_Weapon_FindActive($a_i_WeaponID, $a_i_OffhandID)
	EndIf
	If $g_i_ZS_SwitchTo <> 0 And ($g_i_ZS_ActiveSet = $g_i_ZS_SwitchTo Or $g_i_ZS_Now > $g_i_ZS_SwitchUntil) Then $g_i_ZS_SwitchTo = 0
EndFunc   ;==>ZS_Weapon_Perceive

;~ The agent keeps the item IDs on 16 bits (read signed: above 32767 they come negative), the inventory on 32:
;~ both are compared on their low 16 bits. A set whose weapon matches wins over one that only matches the off-hand.
Func ZS_Weapon_FindActive($a_i_WeaponID, $a_i_OffhandID)
	Local $l_i_W = BitAND($a_i_WeaponID, 0xFFFF), $l_i_O = BitAND($a_i_OffhandID, 0xFFFF), $l_i_WeaponOnly = 0, $l_i_OffOnly = 0
	For $l_i_Set = 1 To 4
		If Not $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Present] Then ContinueLoop
		Local $l_b_W = (BitAND($g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_WeaponID], 0xFFFF) = $l_i_W)
		Local $l_b_O = (BitAND($g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_OffhandID], 0xFFFF) = $l_i_O)
		If $l_b_W And $l_b_O Then Return $l_i_Set
		If $l_b_W And $l_i_W <> 0 And $l_i_WeaponOnly = 0 Then $l_i_WeaponOnly = $l_i_Set
		If $l_b_O And $l_i_O <> 0 And $l_i_OffOnly = 0 Then $l_i_OffOnly = $l_i_Set
	Next
	If $l_i_WeaponOnly <> 0 Then Return $l_i_WeaponOnly
	Return $l_i_OffOnly
EndFunc   ;==>ZS_Weapon_FindActive

;~ Description: True when at least one weapon set was read.
Func ZS_Weapon_AnySet()
	For $l_i_Set = 1 To 4
		If $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Present] Then Return True
	Next
	Return False
EndFunc   ;==>ZS_Weapon_AnySet

;~ Description: Forget the sets and the switch history (tests, reset).
Func ZS_Weapon_Reset()
	For $l_i_Set = 1 To 4
		ZS_Weapon_ClearSet($l_i_Set)
	Next
	$g_i_ZS_ActiveSet = 0
	$g_i_ZS_HomeSet = 0
	$g_i_ZS_SetsReadAt = -100000
	$g_i_ZS_SwitchTo = 0
	$g_i_ZS_SwitchFrozenUntil = 0
	For $i = 0 To 3
		$g_ai_ZS_SwitchTimes[$i] = -100000
	Next
EndFunc   ;==>ZS_Weapon_Reset

;~ Description: One line per set, for the journal (checks the mod reading in game).
Func ZS_Weapon_Describe()
	Local $l_s = "home " & $g_i_ZS_HomeSet & ", in hand " & $g_i_ZS_ActiveSet
	For $l_i_Set = 1 To 4
		If Not $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Present] Then ContinueLoop
		$l_s &= @CRLF & "  set " & $l_i_Set & ": items " & $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_WeaponID] & "/" & $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_OffhandID] & _
				", item type " & $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_ItemType] & "/" & $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_OffhandType] & _
				", energy " & $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_EFlat] & " (now " & ZS_Weapon_Bonus($l_i_Set) & ")" & _
				", enchant +" & $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Ench] & "%, HCT " & $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_HCT] & _
				"%, HSR " & $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_HSR] & "%"
	Next
	Return $l_s
EndFunc   ;==>ZS_Weapon_Describe
#EndRegion Read from the game

#Region Policy (pure, on the snapshot)
;~ Description: Skill weapon requirement bit of an item type (4 = staff, wand, focus or nothing: no weapon skill).
Func ZS_Weapon_ItemBit($a_i_ItemType)
	Switch $a_i_ItemType
		Case $GC_I_TYPE_AXE
			Return $GC_I_SKILL_REQUIRE_AXE
		Case $GC_I_TYPE_BOW
			Return $GC_I_SKILL_REQUIRE_BOW
		Case $GC_I_TYPE_DAGGERS
			Return $GC_I_SKILL_REQUIRE_DAGGER
		Case $GC_I_TYPE_HAMMER
			Return $GC_I_SKILL_REQUIRE_HAMMER
		Case $GC_I_TYPE_SCYTHE
			Return $GC_I_SKILL_REQUIRE_SCYTHE
		Case $GC_I_TYPE_SPEAR
			Return $GC_I_SKILL_REQUIRE_SPEAR
		Case $GC_I_TYPE_SWORD
			Return $GC_I_SKILL_REQUIRE_SWORD
	EndSwitch
	Return 4
EndFunc   ;==>ZS_Weapon_ItemBit

;~ Description: Weapon requirement bit of what the player holds now.
Func ZS_Weapon_ActiveBit()
	If $g_i_ZS_ActiveSet > 0 Then Return $g_amx2_ZS_WSet[$g_i_ZS_ActiveSet][$GC_ZS_W_Bit]
	Return ZS_Veto_WeaponBit($g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_WeaponType])
EndFunc   ;==>ZS_Weapon_ActiveBit

;~ Description: Energy set $a_i_Set gives right now (its conditional mods checked on the player).
Func ZS_Weapon_Bonus($a_i_Set)
	If $a_i_Set < 1 Or $a_i_Set > 4 Then Return 0
	Local $l_i_E = $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EFlat]
	If $g_i_ZS_MeIdx > 0 Then
		Local $l_i_Me = $g_i_ZS_MeIdx
		Local $l_f_HP = $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_HP] * 100
		If ZS_Is($l_i_Me, $GC_ZS_AF_ENCHANTED) Then $l_i_E += $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EEnch]
		If ZS_Is($l_i_Me, $GC_ZS_AF_HEXED) Then $l_i_E += $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHex]
		If $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPHi] <> 0 And $l_f_HP > $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPHiThr] Then $l_i_E += $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPHi]
		If $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPLo] <> 0 And $l_f_HP < $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPLoThr] Then $l_i_E += $g_amx2_ZS_WSet[$a_i_Set][$GC_ZS_W_EHPLo]
	EndIf
	Return $l_i_E
EndFunc   ;==>ZS_Weapon_Bonus

;~ Description: Energy the player would have on set $a_i_Set (the game adds or hides the difference at once).
Func ZS_Weapon_EnergyOn($a_i_Set)
	Return $g_f_ZS_Energy - ZS_Weapon_Bonus($g_i_ZS_ActiveSet) + ZS_Weapon_Bonus($a_i_Set)
EndFunc   ;==>ZS_Weapon_EnergyOn

;~ Description: True when the bar has attack skills (a fighter comes back to its weapon for them).
Func ZS_Weapon_IsFighter()
	For $l_i_Slot = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] <> 0 And $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ATTACK Then Return True
	Next
	Return False
EndFunc   ;==>ZS_Weapon_IsFighter

;~ Description: Set the build fights with. Attack skills decide (most of them usable with its weapon),
;~ otherwise the set with the most energy; the set in hand wins ties.
Func ZS_Weapon_ComputeHome()
	$g_i_ZS_HomeSet = 0
	If $g_i_ZS_HomeSetForced >= 1 And $g_i_ZS_HomeSetForced <= 4 And $g_amx2_ZS_WSet[$g_i_ZS_HomeSetForced][$GC_ZS_W_Present] Then
		$g_i_ZS_HomeSet = $g_i_ZS_HomeSetForced
		Return
	EndIf
	Local $l_b_Fighter = ZS_Weapon_IsFighter()
	Local $l_f_Best = -1000, $l_f_Score, $l_i_Req
	For $l_i_Set = 1 To 4
		If Not $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Present] Then ContinueLoop
		$l_f_Score = 0
		If $l_b_Fighter Then
			For $l_i_Slot = 1 To 8
				If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Type] <> $GC_I_SKILL_TYPE_ATTACK Then ContinueLoop
				$l_i_Req = $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_WeaponReq]
				If $l_i_Req = 0 Or BitAND($l_i_Req, $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Bit]) Then $l_f_Score += 10
			Next
		EndIf
		$l_f_Score += $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_EFlat] / 100
		If $l_i_Set = $g_i_ZS_ActiveSet Then $l_f_Score += 0.5
		If $l_f_Score > $l_f_Best Then
			$l_f_Best = $l_f_Score
			$g_i_ZS_HomeSet = $l_i_Set
		EndIf
	Next
EndFunc   ;==>ZS_Weapon_ComputeHome

;~ Description: True when a switch may be sent now. An optional switch (comfort, not need) is stricter.
Func ZS_Weapon_CanSwitch($a_b_Optional)
	If Not $g_b_ZS_WeaponSwap Then Return False
	; Set in hand not recognised: only a needed switch (the weapon of an attack), never a comfort one
	If $g_i_ZS_ActiveSet = 0 And ($a_b_Optional Or Not ZS_Weapon_AnySet()) Then Return False
	If $g_i_ZS_Now < $g_i_ZS_SwitchFrozenUntil Then Return False
	Local $l_i_Last = $g_ai_ZS_SwitchTimes[3]
	If $a_b_Optional Then
		If $g_i_ZS_Now - $l_i_Last < 4000 Then Return False
		If ZS_Weapon_InChain() Then Return False
	ElseIf $g_i_ZS_Now - $l_i_Last < 700 Then
		Return False
	EndIf
	Return True
EndFunc   ;==>ZS_Weapon_CanSwitch

;~ Description: Record a switch; 4 within 10 s freezes switching for 5 s (no flip-flop).
Func ZS_Weapon_NoteSwitch($a_i_Set)
	For $i = 0 To 2
		$g_ai_ZS_SwitchTimes[$i] = $g_ai_ZS_SwitchTimes[$i + 1]
	Next
	$g_ai_ZS_SwitchTimes[3] = $g_i_ZS_Now
	If $g_i_ZS_Now - $g_ai_ZS_SwitchTimes[0] < 10000 Then $g_i_ZS_SwitchFrozenUntil = $g_i_ZS_Now + 5000
	$g_i_ZS_SwitchTo = $a_i_Set
	$g_i_ZS_SwitchUntil = $g_i_ZS_Now + 700 + 2 * $g_i_ZS_Ping
	$g_i_ZS_StatSwitches += 1
EndFunc   ;==>ZS_Weapon_NoteSwitch

;~ Description: True while an assassin chain is under way (a foe last struck by a lead or off-hand attack
;~ and a follow-up on the bar): the weapon must not change before the chain ends.
Func ZS_Weapon_InChain()
	Local $l_b_Chain = False
	For $l_i_Slot = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_ComboReq] <> 0 Then $l_b_Chain = True
	Next
	If Not $l_b_Chain Then Return False
	Local $l_i_Last
	For $i = 1 To $g_ai_ZS_Foes[0]
		$l_i_Last = $g_amx2_ZS_Agent[$g_ai_ZS_Foes[$i]][$GC_ZS_A_LastStrike]
		If $l_i_Last = $GC_I_SKILL_COMBO_LEAD_ATTACK Or $l_i_Last = $GC_I_SKILL_COMBO_OFF_HAND_ATTACK Then Return True
	Next
	Return False
EndFunc   ;==>ZS_Weapon_InChain

;~ Description: True when an attack skill of the bar could go now (recharged or enough adrenaline).
Func ZS_Weapon_AttackReady()
	For $l_i_Slot = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] = 0 Or $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Type] <> $GC_I_SKILL_TYPE_ATTACK Then ContinueLoop
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_AdrenReq] > 0 Then
			If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Adrenaline] >= $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_AdrenReq] Then Return True
		ElseIf $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Recharged] Then
			Return True
		EndIf
	Next
	Return False
EndFunc   ;==>ZS_Weapon_AttackReady

;~ Description: Set holding a weapon of requirement mask $a_i_Req (home first, then the one in hand), 0 = none.
Func ZS_Weapon_SetWithBit($a_i_Req)
	If $g_i_ZS_HomeSet > 0 And BitAND($a_i_Req, $g_amx2_ZS_WSet[$g_i_ZS_HomeSet][$GC_ZS_W_Bit]) Then Return $g_i_ZS_HomeSet
	If $g_i_ZS_ActiveSet > 0 And BitAND($a_i_Req, $g_amx2_ZS_WSet[$g_i_ZS_ActiveSet][$GC_ZS_W_Bit]) Then Return $g_i_ZS_ActiveSet
	For $l_i_Set = 1 To 4
		If $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Present] And BitAND($a_i_Req, $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Bit]) Then Return $l_i_Set
	Next
	Return 0
EndFunc   ;==>ZS_Weapon_SetWithBit

;~ Description: Set on which the player has at least $a_f_Cost energy, 0 = none (or no switch allowed).
;~ The set in hand is never returned: call it only when the energy in hand is not enough.
Func ZS_Weapon_EnergySet($a_f_Cost)
	If Not ZS_Weapon_CanSwitch(False) Then Return 0
	Local $l_i_Best = 0, $l_f_BestE = $a_f_Cost - 0.001, $l_f_E
	For $l_i_Set = 1 To 4
		If $l_i_Set = $g_i_ZS_ActiveSet Or Not $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Present] Then ContinueLoop
		$l_f_E = ZS_Weapon_EnergyOn($l_i_Set)
		If $l_f_E > $l_f_BestE Then
			$l_f_BestE = $l_f_E
			$l_i_Best = $l_i_Set
		EndIf
	Next
	Return $l_i_Best
EndFunc   ;==>ZS_Weapon_EnergySet

;~ Description: True when borrowing the energy of another set is worth it for an action of band $a_i_Band.
;~ Back on the set in hand, the energy is short by the debt: only for urgent actions, or a small debt.
Func ZS_Weapon_BorrowOK($a_i_Band, $a_f_Cost)
	If $a_f_Cost <= $g_f_ZS_Energy Then Return True
	If ZS_Weapon_EnergySet($a_f_Cost) = 0 Then Return False
	If $a_i_Band >= $GC_ZS_BAND_HEAL Then Return True
	If $a_i_Band >= $GC_ZS_BAND_UPKEEP And $a_f_Cost - $g_f_ZS_Energy <= 5 Then Return True
	Return False
EndFunc   ;==>ZS_Weapon_BorrowOK

;~ Description: Set wanted for using the skill of a slot (0 = the one in hand). $g_s_ZS_WeaponWhy says why.
Func ZS_Weapon_ForSkill($a_i_Slot, $a_b_OnOther = True)
	$g_s_ZS_WeaponWhy = ""
	If Not $g_b_ZS_WeaponSwap Then Return 0
	Local $l_i_Set
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ATTACK Then
		Local $l_i_Req = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_WeaponReq]
		If $l_i_Req = 0 Or BitAND($l_i_Req, ZS_Weapon_ActiveBit()) Then Return 0
		$l_i_Set = ZS_Weapon_SetWithBit($l_i_Req)
		If $l_i_Set > 0 Then $g_s_ZS_WeaponWhy = "weapon of set " & $l_i_Set
		Return $l_i_Set
	EndIf
	If $g_i_ZS_ActiveSet = 0 Then Return 0 ; energy and enchantment need to know the set in hand

	; Not enough energy in hand: borrow it from another set
	Local $l_f_Cost = ZS_Cost_Energy($a_i_Slot, $a_b_OnOther)
	If $l_f_Cost > $g_f_ZS_Energy Then
		$l_i_Set = ZS_Weapon_EnergySet($l_f_Cost)
		If $l_i_Set > 0 Then $g_s_ZS_WeaponWhy = "energy of set " & $l_i_Set
		Return $l_i_Set
	EndIf

	; A lasting enchantment: a clearly better "of Enchanting" set, when no attack waits for the weapon
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ENCHANTMENT And $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Duration] >= 8 _
			 And Not ZS_IsFlashEnchant($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID]) Then
		Local $l_i_Best = $g_i_ZS_ActiveSet
		For $l_i_S = 1 To 4
			If $g_amx2_ZS_WSet[$l_i_S][$GC_ZS_W_Present] And $g_amx2_ZS_WSet[$l_i_S][$GC_ZS_W_Ench] > $g_amx2_ZS_WSet[$l_i_Best][$GC_ZS_W_Ench] Then $l_i_Best = $l_i_S
		Next
		If $g_amx2_ZS_WSet[$l_i_Best][$GC_ZS_W_Ench] - $g_amx2_ZS_WSet[$g_i_ZS_ActiveSet][$GC_ZS_W_Ench] < 15 Then Return 0
		; Do not lose more energy than the switch gains
		If ZS_Weapon_EnergyOn($l_i_Best) < $l_f_Cost Then Return 0
		If Not ZS_Weapon_CanSwitch(True) Then Return 0
		If ZS_Weapon_IsFighter() And ZS_Weapon_AttackReady() Then Return 0
		$g_s_ZS_WeaponWhy = "+" & $g_amx2_ZS_WSet[$l_i_Best][$GC_ZS_W_Ench] & "% enchantment on set " & $l_i_Best
		Return $l_i_Best
	EndIf
	Return 0
EndFunc   ;==>ZS_Weapon_ForSkill

;~ Description: Set wanted for auto attack: a fighter goes back to its home set.
Func ZS_Weapon_ForAttack()
	$g_s_ZS_WeaponWhy = ""
	If $g_i_ZS_ActiveSet = 0 Or $g_i_ZS_HomeSet = 0 Or $g_i_ZS_ActiveSet = $g_i_ZS_HomeSet Then Return 0
	If Not ZS_Weapon_IsFighter() Then Return 0
	If Not ZS_Weapon_CanSwitch(False) Then Return 0
	$g_s_ZS_WeaponWhy = "back to set " & $g_i_ZS_HomeSet
	Return $g_i_ZS_HomeSet
EndFunc   ;==>ZS_Weapon_ForAttack
#EndRegion Policy
