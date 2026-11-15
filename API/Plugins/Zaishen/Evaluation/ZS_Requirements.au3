#include-once

; Zaishen requirements: the per-skill conditions written as parameters (generated from UtilityAI or written by hand).
; Pure functions on the snapshot. See Tools/ZS_ExtractUAI.ps1 for the list of parameters.

#Region Qualifiers
;~ Description: True when agent row $a_i_Idx shows qualifier $a_s_Q (Caster, Hexed, Casting, AfterLead...).
;~ A qualifier Zaishen cannot see is considered met (a requirement it cannot check never blocks a skill).
Func ZS_Qualifies($a_i_Idx, $a_s_Q)
	Local $l_i_Flags = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Flags]
	Local $l_i_Prim = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Primary]
	Local $l_f_HP = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_HP]
	Switch $a_s_Q
		Case "Attacking"
			Return BitAND($l_i_Flags, $GC_ZS_AF_ATTACKING) <> 0
		Case "Casting"
			Return BitAND($l_i_Flags, $GC_ZS_AF_CASTING) <> 0
		Case "Moving"
			Return BitAND($l_i_Flags, $GC_ZS_AF_MOVING) <> 0
		Case "Knocked"
			Return BitAND($l_i_Flags, $GC_ZS_AF_KNOCKED) <> 0
		Case "Hexed"
			Return BitAND($l_i_Flags, $GC_ZS_AF_HEXED) <> 0
		Case "DegenHexed"
			Return BitAND($l_i_Flags, $GC_ZS_AF_DEGENHEXED) <> 0
		Case "Enchanted"
			Return BitAND($l_i_Flags, $GC_ZS_AF_ENCHANTED) <> 0
		Case "Conditioned", "HasCondition"
			Return BitAND($l_i_Flags, $GC_ZS_AF_CONDITIONED) <> 0
		Case "Burning"
			Return BitAND($l_i_Flags, $GC_ZS_AF_BURNING) <> 0
		Case "Blind", "Blinded"
			Return BitAND($l_i_Flags, $GC_ZS_AF_BLIND) <> 0
		Case "Dazed"
			Return BitAND($l_i_Flags, $GC_ZS_AF_DAZED) <> 0
		Case "Weakness", "Weakened", "CrackedArmor"
			Return BitAND($l_i_Flags, $GC_ZS_AF_WEAKNESS) <> 0
		Case "Diseased"
			Return BitAND($l_i_Flags, $GC_ZS_AF_DISEASED) <> 0
		Case "DeepWounded"
			Return BitAND($l_i_Flags, $GC_ZS_AF_DEEPWOUND) <> 0
		Case "NotDeepWounded", "NotIsDeepWounded"
			Return BitAND($l_i_Flags, $GC_ZS_AF_DEEPWOUND) = 0
		Case "Bleeding"
			Return BitAND($l_i_Flags, $GC_ZS_AF_BLEEDING) <> 0
		Case "Poisoned"
			Return BitAND($l_i_Flags, $GC_ZS_AF_POISONED) <> 0
		Case "NotPoisoned"
			Return BitAND($l_i_Flags, $GC_ZS_AF_POISONED) = 0
		Case "Crippled"
			Return BitAND($l_i_Flags, $GC_ZS_AF_CRIPPLED) <> 0
		Case "WeaponSpelled"
			Return BitAND($l_i_Flags, $GC_ZS_AF_WEAPONSPELL) <> 0
		Case "Boss"
			Return BitAND($l_i_Flags, $GC_ZS_AF_BOSS) <> 0
		Case "HexedOrEnchanted"
			Return BitAND($l_i_Flags, $GC_ZS_AF_HEXED + $GC_ZS_AF_ENCHANTED) <> 0
		Case "HexedOrConditioned"
			Return BitAND($l_i_Flags, $GC_ZS_AF_HEXED + $GC_ZS_AF_CONDITIONED) <> 0
		Case "ConditionedOrEnchanted"
			Return BitAND($l_i_Flags, $GC_ZS_AF_CONDITIONED + $GC_ZS_AF_ENCHANTED) <> 0
		Case "Caster"
			Return ZS_IsCasterProfession($l_i_Prim)
		Case "NotCaster"
			Return Not ZS_IsCasterProfession($l_i_Prim)
		Case "Melee"
			Return $l_i_Prim = $GC_I_PROFESSION_WARRIOR Or $l_i_Prim = $GC_I_PROFESSION_ASSASSIN Or $l_i_Prim = $GC_I_PROFESSION_DERVISH
		Case "Ranged"
			Return $l_i_Prim = $GC_I_PROFESSION_RANGER Or $l_i_Prim = $GC_I_PROFESSION_PARAGON
		Case "Warrior"
			Return $l_i_Prim = $GC_I_PROFESSION_WARRIOR
		Case "Ranger"
			Return $l_i_Prim = $GC_I_PROFESSION_RANGER
		Case "Monk"
			Return $l_i_Prim = $GC_I_PROFESSION_MONK
		Case "Necromancer"
			Return $l_i_Prim = $GC_I_PROFESSION_NECROMANCER
		Case "Mesmer"
			Return $l_i_Prim = $GC_I_PROFESSION_MESMER
		Case "Elementalist"
			Return $l_i_Prim = $GC_I_PROFESSION_ELEMENTALIST
		Case "Assassin"
			Return $l_i_Prim = $GC_I_PROFESSION_ASSASSIN
		Case "Ritualist"
			Return $l_i_Prim = $GC_I_PROFESSION_RITUALIST
		Case "Paragon"
			Return $l_i_Prim = $GC_I_PROFESSION_PARAGON
		Case "Dervish"
			Return $l_i_Prim = $GC_I_PROFESSION_DERVISH
		Case "Below50HP"
			Return $l_f_HP < 0.5
		Case "Below25HP"
			Return $l_f_HP < 0.25
		Case "Above50HP"
			Return $l_f_HP >= 0.5
		Case "AgentHasMoreHpThanMe"
			Return $l_f_HP > $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_HP]
		Case "AfterLead"
			Return $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_LastStrike] = $GC_I_SKILL_COMBO_LEAD_ATTACK
		Case "AfterOffHand"
			Return $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_LastStrike] = $GC_I_SKILL_COMBO_OFF_HAND_ATTACK
		Case "AfterDual"
			Return $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_LastStrike] = $GC_I_SKILL_COMBO_DUAL_ATTACK
		Case "AfterLeadOrOffHand"
			Local $l_i_Last = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_LastStrike]
			Return $l_i_Last = $GC_I_SKILL_COMBO_LEAD_ATTACK Or $l_i_Last = $GC_I_SKILL_COMBO_OFF_HAND_ATTACK
		Case "Spirit"
			If BitAND($l_i_Flags, $GC_ZS_AF_PET) Then Return False
			Return $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Allegiance] = $GC_I_ALLEGIANCE_SPIRIT Or BitAND($l_i_Flags, $GC_ZS_AF_SPAWNED) <> 0
		Case "Minion"
			Return $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Allegiance] = $GC_I_ALLEGIANCE_MINION
		Case "NotEnchanted"
			Return BitAND($l_i_Flags, $GC_ZS_AF_ENCHANTED) = 0
		Case "NotBlind"
			Return BitAND($l_i_Flags, $GC_ZS_AF_BLIND) = 0
		; The player's pet, whatever agent is asked about (SelfIs=PetAlive...)
		Case "PetAlive"
			Return $g_i_ZS_PetIdx > 0 And Not ZS_Is($g_i_ZS_PetIdx, $GC_ZS_AF_DEAD)
		Case "PetDead"
			Return $g_i_ZS_PetIdx > 0 And ZS_Is($g_i_ZS_PetIdx, $GC_ZS_AF_DEAD)
		Case "PetHurt"
			Return $g_i_ZS_PetIdx > 0 And Not ZS_Is($g_i_ZS_PetIdx, $GC_ZS_AF_DEAD) And $g_amx2_ZS_Agent[$g_i_ZS_PetIdx][$GC_ZS_A_HP] < 0.6
	EndSwitch
	Return True
EndFunc   ;==>ZS_Qualifies

Func ZS_IsCasterProfession($a_i_Prof)
	Switch $a_i_Prof
		Case $GC_I_PROFESSION_MONK, $GC_I_PROFESSION_NECROMANCER, $GC_I_PROFESSION_MESMER, $GC_I_PROFESSION_ELEMENTALIST, $GC_I_PROFESSION_RITUALIST
			Return True
	EndSwitch
	Return False
EndFunc   ;==>ZS_IsCasterProfession

;~ Description: Living allied spirits within $a_f_Range of the player.
Func ZS_CountOurSpirits($a_f_Range)
	Local $l_i_N = 0
	For $i = 1 To $g_i_ZS_AgentCount
		If $g_amx2_ZS_Agent[$i][$GC_ZS_A_Allegiance] <> $GC_I_ALLEGIANCE_SPIRIT Then ContinueLoop
		If BitAND($g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags], $GC_ZS_AF_DEAD + $GC_ZS_AF_PET) Then ContinueLoop
		If $g_amx2_ZS_Agent[$i][$GC_ZS_A_Dist] <= $a_f_Range Then $l_i_N += 1
	Next
	Return $l_i_N
EndFunc   ;==>ZS_CountOurSpirits

;~ Description: A speed effect on the player other than $a_i_Except (a skill whose definition says "Speed="), 0 when none.
Func ZS_OtherSpeedOnMe($a_i_Except)
	Local $l_av_Def
	For $l_i_SkillID In MapKeys($g_m_ZS_SelfFx)
		If $l_i_SkillID = $a_i_Except Or Not MapExists($g_m_ZS_Defs, $l_i_SkillID) Then ContinueLoop
		$l_av_Def = $g_m_ZS_Defs[$l_i_SkillID]
		If StringInStr("|" & $l_av_Def[3], "|Speed=") Then Return $l_i_SkillID
	Next
	Return 0
EndFunc   ;==>ZS_OtherSpeedOnMe

;~ Description: True for a speed skill that works on the party around the player (Incoming!, Fall Back!...).
Func ZS_IsGroupSpeed($a_i_Slot)
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Family] = $GC_ZS_FAM_PARTY_BUFF Then Return True
	Return $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_TargetMask] = $GC_ZS_TM_SELF And $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE] >= $GC_I_RANGE_NEARBY
EndFunc   ;==>ZS_IsGroupSpeed

;~ Description: Living allied minions within $a_f_Range of the player.
Func ZS_CountMinions($a_f_Range)
	Local $l_i_N = 0
	For $i = 1 To $g_i_ZS_AgentCount
		If $g_amx2_ZS_Agent[$i][$GC_ZS_A_Allegiance] <> $GC_I_ALLEGIANCE_MINION Then ContinueLoop
		If BitAND($g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags], $GC_ZS_AF_DEAD) Then ContinueLoop
		If $g_amx2_ZS_Agent[$i][$GC_ZS_A_Dist] <= $a_f_Range Then $l_i_N += 1
	Next
	Return $l_i_N
EndFunc   ;==>ZS_CountMinions

;~ Description: True when the agent shows every qualifier of the comma list ($a_b_All) or at least one (Not $a_b_All).
Func ZS_QualifiesList($a_i_Idx, $a_s_List, $a_b_All)
	Local $l_as_Q = StringSplit($a_s_List, ",", 2)
	For $i = 0 To UBound($l_as_Q) - 1
		If ZS_Qualifies($a_i_Idx, $l_as_Q[$i]) Then
			If Not $a_b_All Then Return True
		ElseIf $a_b_All Then
			Return False
		EndIf
	Next
	Return $a_b_All
EndFunc   ;==>ZS_QualifiesList
#EndRegion Qualifiers

#Region Requirements
; Target requirements of each slot, parsed once when the bar changes (ZS_Req_Prepare): [slot][column]
Global Enum $GC_ZS_RQ_Any, $GC_ZS_RQ_Need, $GC_ZS_RQ_Avoid, $GC_ZS_RQ_Range, $GC_ZS_RQ_Below, $GC_ZS_RQ_Above, _
	$GC_ZS_RQ_MinFoes, $GC_ZS_RQ_Prefer, $GC_ZS_RQ_Highest, $GC_ZS_RQ_BonusIf, $GC_ZS_RQ_MaxTargets, $GC_ZS_RQ_COUNT
Global $g_amx2_ZS_Req[9][$GC_ZS_RQ_COUNT]

;~ Description: Parse the target requirements of a slot (called by ZS_Knowledge_ResolveSlot).
Func ZS_Req_Prepare($a_i_Slot)
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Need] = ZS_SlotParam($a_i_Slot, "Need")
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Avoid] = ZS_SlotParam($a_i_Slot, "Avoid")
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Range] = Number(ZS_SlotParam($a_i_Slot, "Range", 0))
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Below] = Number(ZS_SlotParam($a_i_Slot, "TargetBelow", 2))
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Above] = Number(ZS_SlotParam($a_i_Slot, "TargetAbove", -1))
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_MinFoes] = Int(ZS_SlotParam($a_i_Slot, "MinFoes", 0))
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Prefer] = ZS_SlotParam($a_i_Slot, "Prefer")
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Highest] = (ZS_SlotParam($a_i_Slot, "Pick") = "highest")
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_BonusIf] = ZS_SlotParam($a_i_Slot, "BonusIf")
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_MaxTargets] = Int(ZS_SlotParam($a_i_Slot, "MaxTargets", 0))
	$g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Any] = ($g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Need] <> "" Or $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Avoid] <> "" _
			 Or $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_MaxTargets] > 0 _
			 Or $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_BonusIf] <> "" _
			 Or $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Range] > 0 Or $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Below] < 2 _
			 Or $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Above] >= 0 Or $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_MinFoes] > 0 _
			 Or $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Prefer] <> "" Or $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Highest])
EndFunc   ;==>ZS_Req_Prepare
;~ Description: Reason the skill of the slot cannot be used at all right now ("" = it can), from its parameters on the player.
Func ZS_Req_Slot($a_i_Slot)
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Params] = "" Then Return ""
	Local $l_s_V, $l_as_IDs
	$l_s_V = ZS_SlotParam($a_i_Slot, "SelfNeed")
	If $l_s_V <> "" Then
		$l_as_IDs = StringSplit($l_s_V, ",", 2)
		For $i = 0 To UBound($l_as_IDs) - 1
			If Not MapExists($g_m_ZS_SelfFx, Int($l_as_IDs[$i])) Then Return "needs " & ZS_SkillName(Int($l_as_IDs[$i]))
		Next
	EndIf
	$l_s_V = ZS_SlotParam($a_i_Slot, "SelfNot")
	If $l_s_V <> "" Then
		$l_as_IDs = StringSplit($l_s_V, ",", 2)
		For $i = 0 To UBound($l_as_IDs) - 1
			If MapExists($g_m_ZS_SelfFx, Int($l_as_IDs[$i])) Then Return "blocked by " & ZS_SkillName(Int($l_as_IDs[$i]))
		Next
	EndIf
	$l_s_V = ZS_SlotParam($a_i_Slot, "SelfIs")
	If $l_s_V <> "" And Not ZS_QualifiesList($g_i_ZS_MeIdx, $l_s_V, True) Then Return "player not " & $l_s_V
	$l_s_V = ZS_SlotParam($a_i_Slot, "SelfIsAny")
	If $l_s_V <> "" And Not ZS_QualifiesList($g_i_ZS_MeIdx, $l_s_V, False) Then Return "player none of " & $l_s_V
	; Speed=1: a speed skill, only worth it while the player walks; Speed=2: also used for its other effect
	; in fights (Escape blocks), a speed skill out of combat only
	If ZS_SlotParam($a_i_Slot, "Speed") = "1" And Not ZS_Is($g_i_ZS_MeIdx, $GC_ZS_AF_MOVING) Then Return "player not moving"
	; Speed boosts do not add up: another one on the player (ours, or a party shout another bot gave) is enough
	If ZS_SlotParam($a_i_Slot, "Speed") = "1" Then
		Local $l_i_Other = ZS_OtherSpeedOnMe($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID])
		If $l_i_Other <> 0 Then Return "already sped up by " & ZS_SkillName($l_i_Other)
	EndIf
	$l_s_V = ZS_SlotParam($a_i_Slot, "SelfIsNot")
	If $l_s_V <> "" And ZS_QualifiesList($g_i_ZS_MeIdx, $l_s_V, False) Then Return "player is " & $l_s_V
	$l_s_V = ZS_SlotParam($a_i_Slot, "SpiritsNear")
	If $l_s_V <> "" And ZS_CountOurSpirits($GC_I_RANGE_EARSHOT) < Int($l_s_V) Then Return "no spirit near"
	$l_s_V = ZS_SlotParam($a_i_Slot, "MinionsNear")
	If $l_s_V <> "" And ZS_CountMinions($GC_I_RANGE_EARSHOT) < Int($l_s_V) Then Return "fewer than " & $l_s_V & " minions"
	Local $l_f_HP = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_HP]
	$l_s_V = ZS_SlotParam($a_i_Slot, "MyHPAbove")
	If $l_s_V <> "" And $l_f_HP < Number($l_s_V) Then Return "my health under " & $l_s_V
	$l_s_V = ZS_SlotParam($a_i_Slot, "MyHPBelow")
	If $l_s_V <> "" And $l_f_HP > Number($l_s_V) Then Return "my health over " & $l_s_V
	$l_s_V = ZS_SlotParam($a_i_Slot, "MyEnergyBelow")
	If $l_s_V <> "" And $g_f_ZS_Energy >= Number($l_s_V) Then Return "my energy over " & $l_s_V
	$l_s_V = ZS_SlotParam($a_i_Slot, "MinAdjacent")
	If $l_s_V <> "" Then
		Local $l_i_Me = $g_i_ZS_MeIdx
		If ZS_CountAround($g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_X], $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_Y], $GC_I_RANGE_ADJACENT, True) < Int($l_s_V) Then Return "fewer than " & $l_s_V & " adjacent foes"
	EndIf
	Return ""
EndFunc   ;==>ZS_Req_Slot

;~ Description: Utility added to the (slot, target) pair by its parameters, or -1 when the target is not allowed.
Func ZS_Req_Target($a_i_Slot, $a_i_Idx)
	If Not $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Any] Then Return 0
	Local $l_s_V
	Local $l_b_Other = ($a_i_Idx <> $g_i_ZS_MeIdx)
	; A buff that can go on any ally judges the player like the others (Strength of Honor: Need=Melee);
	; on a skill that only targets the player, Need/Avoid describe the foes around it
	Local $l_b_Judged = $l_b_Other Or BitAND($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_TargetMask], $GC_ZS_TM_ALLY) <> 0
	If $l_b_Judged Then
		$l_s_V = $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Need]
		If $l_s_V <> "" And Not ZS_QualifiesList($a_i_Idx, $l_s_V, True) Then Return -1
		$l_s_V = $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Avoid]
		If $l_s_V <> "" And ZS_QualifiesList($a_i_Idx, $l_s_V, False) Then Return -1
		If $l_b_Other And $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Range] > 0 And $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Dist] > $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Range] Then Return -1
	EndIf
	; A buff kept on one ally only (Strength of Honor, Life Bond...): not on a second one
	If $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_MaxTargets] > 0 And ZS_Req_OtherHolders($a_i_Slot, $a_i_Idx) >= $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_MaxTargets] Then Return -1

	Local $l_f_HP = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_HP]
	If $l_f_HP > $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Below] Then Return -1
	If $l_f_HP < $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Above] Then Return -1

	If $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_MinFoes] > 0 Then
		Local $l_f_Radius = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE]
		If $l_f_Radius < $GC_I_RANGE_NEARBY Then $l_f_Radius = $GC_I_RANGE_NEARBY
		If ZS_CountAround($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_X], $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Y], $l_f_Radius, True) < $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_MinFoes] Then Return -1
	EndIf

	Local $l_f_Bonus = 0
	If $l_b_Other Then
		$l_s_V = $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Prefer]
		If $l_s_V <> "" Then
			; Each qualifier shown counts, the first ones more (written by importance):
			; a fighter who attacks > a fighter > a caster who attacks > an idle caster
			Local $l_as_Q = StringSplit($l_s_V, ",", 2), $l_i_N = UBound($l_as_Q), $l_i_Met = 0, $l_i_All = 0
			For $i = 0 To $l_i_N - 1
				$l_i_All += $l_i_N - $i
				If ZS_Qualifies($a_i_Idx, $l_as_Q[$i]) Then $l_i_Met += $l_i_N - $i
			Next
			If $l_i_Met > 0 Then
				$l_f_Bonus += 0.12 * $l_i_Met / $l_i_All
				If $g_b_ZS_Explain Then $g_s_ZS_Why &= " prefer " & $l_s_V & ($l_i_Met < $l_i_All ? " (" & $l_i_Met & "/" & $l_i_All & ")" : "")
			EndIf
		EndIf
		; "lowest" is what the finisher weight already does; "highest" goes the other way
		If $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_Highest] Then $l_f_Bonus += 0.15 * $l_f_HP
		; The skill does more on a target in this state (game description: "if target foe is burning...")
		If ZS_Req_BonusMet($a_i_Slot, $a_i_Idx) = 1 Then
			$l_f_Bonus += 0.15
			If $g_b_ZS_Explain Then $g_s_ZS_Why &= " bonus: " & $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_BonusIf]
		EndIf
	EndIf
	Return $l_f_Bonus
EndFunc   ;==>ZS_Req_Target

;~ Description: Number of agents other than $a_i_Idx that carry the effect of the slot (seen on the party, or kept up by the player).
Func ZS_Req_OtherHolders($a_i_Slot, $a_i_Idx)
	Local $l_i_SkillID = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID], $l_i_N = 0, $l_i_ID
	For $i = 1 To $g_i_ZS_AgentCount
		If $i = $a_i_Idx Or ZS_Is($i, $GC_ZS_AF_DEAD) Then ContinueLoop
		$l_i_ID = $g_amx2_ZS_Agent[$i][$GC_ZS_A_ID]
		If ZS_FxRemain($l_i_ID, $l_i_SkillID) > 0 Then $l_i_N += 1
	Next
	Return $l_i_N
EndFunc   ;==>ZS_Req_OtherHolders

;~ Description: 1 when the target gives the skill its bonus ("BonusIf="), -1 when it does not, 0 when the skill has none.
Func ZS_Req_BonusMet($a_i_Slot, $a_i_Idx)
	Local $l_s_V = $g_amx2_ZS_Req[$a_i_Slot][$GC_ZS_RQ_BonusIf]
	If $l_s_V = "" Then Return 0
	Return (ZS_QualifiesList($a_i_Idx, $l_s_V, False) ? 1 : -1)
EndFunc   ;==>ZS_Req_BonusMet
#EndRegion Requirements
