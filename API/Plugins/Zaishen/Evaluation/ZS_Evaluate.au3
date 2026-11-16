#include-once

; Zaishen evaluation: score every (skill, target) pair of the snapshot and keep the best.
; PURE: reads the snapshot globals only - no game memory, no command, no Sleep. Safe to run without the game.
;
; score = band * 10 + utility. A higher band always wins; inside a band the highest utility wins.
; utility = family consideration (0..1) x generic modifiers (distance, energy reserve, weight).

Global $g_ai_ZS_Foes[1]       ; rows of the living foes worth acting on, [0] = count
Global $g_ai_ZS_Allies[1]     ; rows of the living allies in reach (player excluded), [0] = count
Global $g_ai_ZS_DeadAllies[1]
Global $g_ai_ZS_Others[1]     ; allied minions and spirits
Global $g_b_ZS_AnyCorpse = False
Global $g_b_ZS_Renewal = False   ; scratch: the candidate being scored renews an effect that is about to end

#Region Response curves
;~ Description: 0 below $a_f_From, 1 above $a_f_To, linear in between.
Func ZS_Curve_Ramp($a_f_X, $a_f_From, $a_f_To)
	If $a_f_X <= $a_f_From Then Return 0
	If $a_f_X >= $a_f_To Then Return 1
	Return ($a_f_X - $a_f_From) / ($a_f_To - $a_f_From)
EndFunc   ;==>ZS_Curve_Ramp

Func ZS_Curve_Clamp($a_f_X)
	If $a_f_X < 0 Then Return 0
	If $a_f_X > 1 Then Return 1
	Return $a_f_X
EndFunc   ;==>ZS_Curve_Clamp
#EndRegion Response curves

#Region Entry point
;~ Description: Decide the best action for the current snapshot.
;~ Fills $g_av_ZS_Decision and $g_amx2_ZS_Top. Returns True when there is something to do.
Func ZS_Evaluate()
	For $i = 0 To $GC_ZS_D_COUNT - 1
		$g_av_ZS_Decision[$i] = 0
	Next
	$g_av_ZS_Decision[$GC_ZS_D_Why] = ""
	$g_i_ZS_TopCount = 0
	$g_i_ZS_CandidateCount = 0

	Local $l_i_Me = $g_i_ZS_MeIdx
	If $l_i_Me = 0 Then Return False
	If ZS_Is($l_i_Me, $GC_ZS_AF_DEAD + $GC_ZS_AF_KNOCKED) Then Return False

	ZS_Eval_BuildLists()

	; An effect on the player that ends when it uses some kind of skill (Battle Rage, Charging Strike...)
	Local $l_s_EndsOn = ZS_Eval_EndsOnRule()
	; Time since the previous evaluation, for the problems file (a pause between fights does not count)
	Local $l_i_Dt = $g_i_ZS_Now - $g_i_ZS_LastEvalAt
	If $l_i_Dt < 0 Or $l_i_Dt > 1000 Then $l_i_Dt = 0
	$g_i_ZS_LastEvalAt = $g_i_ZS_Now

	Local $l_i_Family
	For $l_i_Slot = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] = 0 Then ContinueLoop
		$l_i_Family = $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Family]
		If $l_i_Family = $GC_ZS_FAM_NONE Then ContinueLoop
		If $l_s_EndsOn <> "" And ZS_Eval_WouldEnd($l_i_Slot, $l_s_EndsOn) Then ContinueLoop
		; Set aside after the game refused it twice in a row (ZS_Exec_NoteNoCast)
		Local $l_s_Aside = "skill:" & $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID]
		If MapExists($g_m_ZS_Recent, $l_s_Aside) And $g_m_ZS_Recent[$l_s_Aside] > $g_i_ZS_Now Then ContinueLoop
		Local $l_s_Veto = ZS_Veto_Resources($l_i_Slot)
		If $l_s_Veto <> "" Then
			ZS_Issue_TrackSlot($l_i_Slot, False, $l_s_Veto, $l_i_Dt)
			ContinueLoop
		EndIf
		Local $l_i_Before = $g_i_ZS_CandidateCount
		ZS_Eval_Slot($l_i_Slot, $l_i_Family)
		ZS_Issue_TrackSlot($l_i_Slot, $g_i_ZS_CandidateCount > $l_i_Before, "", $l_i_Dt)
	Next
	ZS_Eval_Bundles()
	ZS_Eval_EndBuffs()
	ZS_Eval_AutoAttack()
	ZS_Eval_Position()

	If $g_i_ZS_TopCount = 0 Then Return False
	For $i = 0 To $GC_ZS_D_COUNT - 1
		$g_av_ZS_Decision[$i] = $g_amx2_ZS_Top[0][$i]
	Next
	Return True
EndFunc   ;==>ZS_Evaluate

;~ Description: One pass over the agents to sort them by role, so each skill only visits its possible targets.
Func ZS_Eval_BuildLists()
	Local $l_i_N = $g_i_ZS_AgentCount
	Global $g_ai_ZS_Foes[$l_i_N + 1], $g_ai_ZS_Allies[$l_i_N + 1], $g_ai_ZS_DeadAllies[$l_i_N + 1], $g_ai_ZS_Others[$l_i_N + 1]
	$g_b_ZS_AnyCorpse = False

	Local $l_f_FoeReach = $g_f_ZS_AggroRange * 1.25
	Local $l_f_AllyReach = 1500
	Local $l_i_F = 0, $l_i_A = 0, $l_i_D = 0, $l_i_O = 0, $l_f_Dist, $l_i_Flags
	For $i = 1 To $l_i_N
		If $i = $g_i_ZS_MeIdx Then ContinueLoop
		$l_f_Dist = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Dist]
		$l_i_Flags = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags]
		If BitAND($l_i_Flags, $GC_ZS_AF_CORPSE) And $l_f_Dist <= $GC_I_RANGE_EARSHOT Then $g_b_ZS_AnyCorpse = True

		Switch $g_amx2_ZS_Agent[$i][$GC_ZS_A_Allegiance]
			Case $GC_I_ALLEGIANCE_ENEMY
				If BitAND($l_i_Flags, $GC_ZS_AF_DEAD) Or $l_f_Dist > $l_f_FoeReach Then ContinueLoop
				If ZS_ModelIn($i, $g_v_ZS_AvoidModels) Then ContinueLoop
				$l_i_F += 1
				$g_ai_ZS_Foes[$l_i_F] = $i
			Case $GC_I_ALLEGIANCE_ALLY
				If BitAND($l_i_Flags, $GC_ZS_AF_SPAWNED) Or $l_f_Dist > $l_f_AllyReach Then ContinueLoop
				If BitAND($l_i_Flags, $GC_ZS_AF_DEAD) Then
					$l_i_D += 1
					$g_ai_ZS_DeadAllies[$l_i_D] = $i
				Else
					$l_i_A += 1
					$g_ai_ZS_Allies[$l_i_A] = $i
				EndIf
			Case $GC_I_ALLEGIANCE_MINION, $GC_I_ALLEGIANCE_SPIRIT
				If BitAND($l_i_Flags, $GC_ZS_AF_DEAD) Or $l_f_Dist > $l_f_AllyReach Then ContinueLoop
				$l_i_O += 1
				$g_ai_ZS_Others[$l_i_O] = $i
		EndSwitch
	Next
	$g_ai_ZS_Foes[0] = $l_i_F
	$g_ai_ZS_Allies[0] = $l_i_A
	$g_ai_ZS_DeadAllies[0] = $l_i_D
	$g_ai_ZS_Others[0] = $l_i_O
EndFunc   ;==>ZS_Eval_BuildLists
#EndRegion Entry point

#Region Candidates
;~ Description: Score the skill of one slot on every target its mask allows.
Func ZS_Eval_Slot($a_i_Slot, $a_i_Family)
	Local $l_i_Mask = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_TargetMask]

	; Conditions of the skill on the player (effects needed or forbidding it, own health...)
	If ZS_Req_Slot($a_i_Slot) <> "" Then Return

	; A skill that needs a corpse (Soul Feast, Consume Corpse...) fails without one, whatever its family
	If $a_i_Family <> $GC_ZS_FAM_RESURRECT And Not $g_b_ZS_AnyCorpse And _
			BitAND($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Special], $GC_I_SKILL_SPECIAL_FLAG_CORPSE) Then Return

	; Dervish skill that strips our newest enchantment: only when that enchantment is worth losing
	$g_f_ZS_SlotBonus = 0
	$g_s_ZS_SlotWhy = ""
	If ZS_IsStripper($a_i_Slot) Then
		$g_f_ZS_SlotBonus = ZS_StripBonus($a_i_Slot)
		If $g_f_ZS_SlotBonus = -1 Then Return
	EndIf

	; Hexes on the player that forbid this skill, by side of the target
	Local $l_b_FoeOK = (ZS_Veto_Punished(ZS_Veto_KindOf($a_i_Slot, True)) = "")
	Local $l_b_OwnOK = (ZS_Veto_Punished(ZS_Veto_KindOf($a_i_Slot, False)) = "")

	; A skill cast on oneself for the pet (Comfort Animal, Revive Animal): judged on the pet
	If ZS_SlotParam($a_i_Slot, "OnPet") = "1" Then
		If $g_i_ZS_PetIdx > 0 And $l_b_OwnOK Then ZS_Eval_Candidate($a_i_Slot, $a_i_Family, $g_i_ZS_PetIdx)
		Return
	EndIf

	If BitAND($l_i_Mask, $GC_ZS_TM_SELF) And $l_b_OwnOK Then ZS_Eval_Candidate($a_i_Slot, $a_i_Family, $g_i_ZS_MeIdx)
	If BitAND($l_i_Mask, $GC_ZS_TM_ALLY) And $l_b_OwnOK Then
		For $i = 1 To $g_ai_ZS_Allies[0]
			ZS_Eval_Candidate($a_i_Slot, $a_i_Family, $g_ai_ZS_Allies[$i])
		Next
	EndIf
	If BitAND($l_i_Mask, $GC_ZS_TM_FOE) And $l_b_FoeOK Then
		For $i = 1 To $g_ai_ZS_Foes[0]
			ZS_Eval_Candidate($a_i_Slot, $a_i_Family, $g_ai_ZS_Foes[$i])
		Next
	EndIf
	If BitAND($l_i_Mask, $GC_ZS_TM_DEADALLY) And $l_b_OwnOK Then
		For $i = 1 To $g_ai_ZS_DeadAllies[0]
			ZS_Eval_Candidate($a_i_Slot, $a_i_Family, $g_ai_ZS_DeadAllies[$i])
		Next
	EndIf
	If BitAND($l_i_Mask, $GC_ZS_TM_MINION + $GC_ZS_TM_SPIRIT) And $l_b_OwnOK Then
		Local $l_i_Want
		For $i = 1 To $g_ai_ZS_Others[0]
			; The pet is a target only for the skills made for it
			If $g_ai_ZS_Others[$i] = $g_i_ZS_PetIdx And ZS_SlotParam($a_i_Slot, "Pet") <> "1" Then ContinueLoop
			$l_i_Want = ($g_amx2_ZS_Agent[$g_ai_ZS_Others[$i]][$GC_ZS_A_Allegiance] = $GC_I_ALLEGIANCE_MINION ? $GC_ZS_TM_MINION : $GC_ZS_TM_SPIRIT)
			If BitAND($l_i_Mask, $l_i_Want) Then ZS_Eval_Candidate($a_i_Slot, $a_i_Family, $g_ai_ZS_Others[$i])
		Next
	EndIf
EndFunc   ;==>ZS_Eval_Slot

;~ Description: Score one (slot, target) pair and offer it to the ranking.
Func ZS_Eval_Candidate($a_i_Slot, $a_i_Family, $a_i_Idx)
	Local $l_i_SkillID = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID]
	Local $l_i_TargetID = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_ID]
	; Judged on the pet, cast on the player
	Local $l_b_OnPet = ($a_i_Idx = $g_i_ZS_PetIdx And $a_i_Idx > 0 And ZS_SlotParam($a_i_Slot, "OnPet") = "1")
	If $l_b_OnPet Then $l_i_TargetID = $g_i_ZS_MyID

	; Pair acted on a moment ago: let the game show the result before trying again
	Local $l_s_Key = $l_i_SkillID & ":" & $l_i_TargetID
	If MapExists($g_m_ZS_Recent, $l_s_Key) And $g_m_ZS_Recent[$l_s_Key] > $g_i_ZS_Now Then Return

	$g_s_ZS_Why = ""
	$g_b_ZS_Renewal = False
	$g_b_ZS_AsDamage = False
	; Conditions of the skill on this target (Need, Avoid, Range, health bounds...)
	Local $l_f_ReqBonus = ZS_Req_Target($a_i_Slot, $a_i_Idx)
	If $l_f_ReqBonus < 0 Then Return
	Local $l_s_ReqWhy = $g_s_ZS_Why
	$g_s_ZS_Why = ""
	Local $l_f_U = ZS_Eval_Utility($a_i_Slot, $a_i_Family, $a_i_Idx)
	If $l_f_U <= 0 Then Return
	$l_f_U += $l_f_ReqBonus + $g_f_ZS_SlotBonus + ZS_Eval_GlyphFollowUp($a_i_Slot)
	$g_s_ZS_Why &= $l_s_ReqWhy & $g_s_ZS_SlotWhy
	$g_i_ZS_CandidateCount += 1

	; The band is decided by the need itself, before the practical modifiers
	Local $l_i_Band = ZS_Knowledge_Band($a_i_Family, $l_f_U)
	; An energy skill used for its damage alone is a damage skill (band and energy reserve)
	Local $l_b_EnergyGain = ($a_i_Family = $GC_ZS_FAM_ENERGY And Not $g_b_ZS_AsDamage)
	If $g_b_ZS_AsDamage Then $l_i_Band = $GC_ZS_BAND_DAMAGE
	; A core buff of the build ("Upkeep=1") goes before damage when it is down
	If ZS_SlotParam($a_i_Slot, "Upkeep") = "1" And $l_i_Band < $GC_ZS_BAND_UPKEEP Then $l_i_Band = $GC_ZS_BAND_UPKEEP
	; Keeping up a buff that was worth casting goes before damage
	If $g_b_ZS_Renewal Then
		If $l_i_Band < $GC_ZS_BAND_UPKEEP Then $l_i_Band = $GC_ZS_BAND_UPKEEP
		If $g_b_ZS_Explain Then $g_s_ZS_Why = StringReplace($g_s_ZS_Why, "not active", "") & " renew, " & _
				ZS_FxRemain($l_i_TargetID, $l_i_SkillID) & " ms left"
	EndIf

	; Distance: the game walks to range by itself, but a far target costs time
	If $a_i_Idx <> $g_i_ZS_MeIdx And Not $l_b_OnPet Then
		Local $l_f_Extra = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Dist] - ZS_Eval_Range($a_i_Slot)
		If $l_f_Extra > 0 Then
			Local $l_f_Far = 1 - $l_f_Extra / 1500
			If $l_f_Far < 0.4 Then $l_f_Far = 0.4
			$l_f_U *= $l_f_Far
			If $g_b_ZS_Explain Then $g_s_ZS_Why &= " far x" & Round($l_f_Far, 2)
		EndIf
	EndIf

	; The cost was checked for the cheapest target: on the player some reductions do not apply
	Local $l_b_OnOther = ($a_i_Idx <> $g_i_ZS_MeIdx And Not $l_b_OnPet)
	If Not $l_b_OnOther And ZS_Cost_Veto($a_i_Slot, False) <> "" Then Return

	; Energy reserve: a non urgent action must not eat what the emergency skills need
	If $l_i_Band < $GC_ZS_BAND_HEAL And Not $l_b_EnergyGain Then
		Local $l_f_Cost = ZS_Cost_Energy($a_i_Slot, $l_b_OnOther)
		If $l_f_Cost > 0 And $g_f_ZS_Energy - $l_f_Cost < $g_f_ZS_ReserveEnergy Then
			; It then only competes with the free actions (auto attack)
			$l_i_Band = $GC_ZS_BAND_IDLE
			$l_f_U *= $g_f_ZS_ReservePenalty
			If $g_b_ZS_Explain Then $g_s_ZS_Why &= " reserve x" & $g_f_ZS_ReservePenalty
		EndIf
	EndIf

	; Energy borrowed from another weapon set: only for what is worth the debt
	If Not ZS_Weapon_BorrowOK($l_i_Band, ZS_Cost_Energy($a_i_Slot, $l_b_OnOther)) Then Return
	; Another weapon set first: a switch costs a moment
	If ZS_Weapon_ForSkill($a_i_Slot, $l_b_OnOther) > 0 Then
		$l_f_U -= 0.03
		If $g_b_ZS_Explain Then $g_s_ZS_Why &= " (" & $g_s_ZS_WeaponWhy & ")"
	EndIf

	$l_f_U *= $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Weight]
	If $l_f_U < $g_f_ZS_MinUtility Then Return

	ZS_Eval_Offer($GC_ZS_ACT_SKILL, $a_i_Slot, $l_i_TargetID, $l_i_Band, $l_f_U, $g_s_ZS_Why)
EndFunc   ;==>ZS_Eval_Candidate

;~ Description: Dropping a bundle is a candidate. The urn held is the item spell we cast last while an item is in hand
;~ ($g_i_ZS_HeldUrn), or, failing that, an item spell of the bar whose effect is on the player.
;~ The "Drop=" rule of its definition says when dropping is worth it. Nothing here moves the player.
Func ZS_Eval_Bundles()
	If MapExists($g_m_ZS_Recent, "drop") And $g_m_ZS_Recent["drop"] > $g_i_ZS_Now Then Return
	Local $l_s_Rule, $l_i_Band, $l_f_U, $l_i_SkillID
	For $l_i_Slot = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Type] <> $GC_I_SKILL_TYPE_ITEM_SPELL Then ContinueLoop
		$l_i_SkillID = $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID]
		If $g_i_ZS_HeldUrn <> 0 Then
			If $g_i_ZS_HeldUrn <> $l_i_SkillID Then ContinueLoop
		ElseIf Not ZS_SelfHasFx($l_i_SkillID) Then
			ContinueLoop
		EndIf
		$l_s_Rule = ZS_SlotParam($l_i_Slot, "Drop")
		If $l_s_Rule = "" Then ContinueLoop ; no drop effect: the bundle itself is the effect
		$g_s_ZS_Why = ""
		$l_i_Band = $GC_ZS_BAND_DAMAGE
		$l_f_U = ZS_Eval_DropRule($l_s_Rule, $l_i_Slot, $l_i_Band)
		; Recycling: the urn can be cast again, so its drop effect is free to take now
		If $l_f_U <= 0 And $g_b_ZS_InCombat And $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Recharged] Then
			$l_i_Band = $GC_ZS_BAND_DAMAGE
			$l_f_U = 0.42
			$g_s_ZS_Why = "recharged: drop and cast again"
		EndIf
		If $l_f_U <= 0 Then ContinueLoop
		$g_i_ZS_CandidateCount += 1
		ZS_Eval_Offer($GC_ZS_ACT_DROP, $l_i_Slot, $g_i_ZS_MyID, $l_i_Band, $l_f_U, $g_s_ZS_Why)
	Next
EndFunc   ;==>ZS_Eval_Bundles

;~ Description: Ending an enchantment the player keeps up is a candidate when its "EndFor=" rule holds
;~ (Unyielding Aura: its end resurrects a dead party member).
Func ZS_Eval_EndBuffs()
	If MapExists($g_m_ZS_Recent, "endbuff") And $g_m_ZS_Recent["endbuff"] > $g_i_ZS_Now Then Return
	Local $l_s_Rule
	For $l_i_Slot = 1 To 8
		$l_s_Rule = ZS_SlotParam($l_i_Slot, "EndFor")
		If $l_s_Rule = "" Then ContinueLoop
		If Not ZS_KeepsUp($g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID]) Then ContinueLoop
		Switch $l_s_Rule
			Case "DeadAlly"
				If $g_ai_ZS_DeadAllies[0] = 0 Then ContinueLoop
				$g_i_ZS_CandidateCount += 1
				ZS_Eval_Offer($GC_ZS_ACT_ENDBUFF, $l_i_Slot, $g_i_ZS_MyID, $GC_ZS_BAND_RESURRECT, 0.95, $g_ai_ZS_DeadAllies[0] & " dead ally: end it to resurrect")
			Case "LowHealth"
				; Aura of Displacement: its end takes the player back where it was cast, away from the fight
				If $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_HP] >= 0.4 Then ContinueLoop
				$g_i_ZS_CandidateCount += 1
				ZS_Eval_Offer($GC_ZS_ACT_ENDBUFF, $l_i_Slot, $g_i_ZS_MyID, $GC_ZS_BAND_SURVIVAL, 0.6, "my hp " & _
						Round($g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_HP] * 100) & "%: end it to get away")
		EndSwitch
	Next
EndFunc   ;==>ZS_Eval_EndBuffs

;~ Description: Utility of dropping the bundle of a slot under rule $a_s_Rule; $a_i_Band receives the band.
Func ZS_Eval_DropRule($a_s_Rule, $a_i_Slot, ByRef $a_i_Band)
	Local $l_i_Me = $g_i_ZS_MeIdx
	Local $l_f_X = $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_X], $l_f_Y = $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_Y]
	Local $l_i_N
	Switch $a_s_Rule
		Case "LowHealth"
			If $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_HP] >= 0.5 Then Return 0
			$a_i_Band = $GC_ZS_BAND_HEAL
			$g_s_ZS_Why = "my hp " & Round($g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_HP] * 100) & "%"
			Return 0.8
		Case "PartyHurt"
			$l_i_N = 0
			For $i = 1 To $g_ai_ZS_Allies[0]
				If $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_HP] < 0.75 Then $l_i_N += 1
			Next
			If $l_i_N < 2 And $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_HP] >= 0.7 Then Return 0
			$a_i_Band = $GC_ZS_BAND_HEAL
			$g_s_ZS_Why = $l_i_N & " allies under 75%"
			Return 0.7
		Case "LowEnergy"
			If $g_f_ZS_MaxEnergy <= 0 Then Return 0
			If $g_f_ZS_Energy >= 0.25 * $g_f_ZS_MaxEnergy And $g_f_ZS_Energy >= 15 Then Return 0
			$a_i_Band = $GC_ZS_BAND_UPKEEP
			$g_s_ZS_Why = "energy " & Round($g_f_ZS_Energy)
			Return 0.7
		Case "DeadAlly"
			$l_i_N = 0
			For $i = 1 To $g_ai_ZS_DeadAllies[0]
				If $g_amx2_ZS_Agent[$g_ai_ZS_DeadAllies[$i]][$GC_ZS_A_Dist] <= $GC_I_RANGE_AREA Then $l_i_N += 1
			Next
			If $l_i_N = 0 Then Return 0
			$a_i_Band = $GC_ZS_BAND_RESURRECT
			$g_s_ZS_Why = $l_i_N & " dead ally in the area"
			Return 0.8
		Case "AlliesConditioned"
			$l_i_N = 0
			For $i = 1 To $g_ai_ZS_Allies[0]
				If $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_Dist] <= $GC_I_RANGE_EARSHOT And ZS_Is($g_ai_ZS_Allies[$i], $GC_ZS_AF_CONDITIONED) Then $l_i_N += 1
			Next
			If ZS_Is($l_i_Me, $GC_ZS_AF_CONDITIONED) Then $l_i_N += 1
			If $l_i_N < 2 Then Return 0
			$a_i_Band = $GC_ZS_BAND_CLEANSE
			$g_s_ZS_Why = $l_i_N & " of us conditioned"
			Return 0.6
		Case "SelfConditioned"
			If Not ZS_Is($l_i_Me, $GC_ZS_AF_CONDITIONED) Then Return 0
			$a_i_Band = $GC_ZS_BAND_CLEANSE
			$g_s_ZS_Why = "conditioned"
			Return 0.55
		Case "FoesNearby", "FoesInArea"
			Local $l_f_Radius = ($a_s_Rule = "FoesNearby" ? $GC_I_RANGE_NEARBY : $GC_I_RANGE_AREA)
			$l_i_N = ZS_CountAround($l_f_X, $l_f_Y, $l_f_Radius, True)
			If $l_i_N < 2 Then Return 0
			$g_s_ZS_Why = $l_i_N & " foes around me"
			Return 0.45 + ($l_i_N > 4 ? 0.3 : 0.075 * $l_i_N)
		Case "FightersNearby"
			; Foes that hit with weapons (not casters) within nearby range
			$l_i_N = 0
			Local $l_f_Sq = $GC_I_RANGE_NEARBY * $GC_I_RANGE_NEARBY, $l_f_DX, $l_f_DY
			For $i = 1 To $g_ai_ZS_Foes[0]
				Local $l_i_F = $g_ai_ZS_Foes[$i]
				If Not ZS_Is($l_i_F, $GC_ZS_AF_ATTACKING) Then ContinueLoop
				$l_f_DX = $g_amx2_ZS_Agent[$l_i_F][$GC_ZS_A_X] - $l_f_X
				$l_f_DY = $g_amx2_ZS_Agent[$l_i_F][$GC_ZS_A_Y] - $l_f_Y
				If $l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY <= $l_f_Sq Then $l_i_N += 1
			Next
			If $l_i_N < 2 Then Return 0
			$g_s_ZS_Why = $l_i_N & " attackers around me"
			Return 0.55
		Case "RitHexesRecharging"
			; Its bonus (cheaper Ritualist hexes) is useless while all of them recharge
			Local $l_b_Any = False
			For $l_i_S = 1 To 8
				If $l_i_S = $a_i_Slot Then ContinueLoop
				If $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_Type] <> $GC_I_SKILL_TYPE_HEX Then ContinueLoop
				If $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_Profession] <> $GC_I_PROFESSION_RITUALIST Then ContinueLoop
				$l_b_Any = True
				If $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_Recharged] Then Return 0
			Next
			If Not $l_b_Any Then Return 0
			$g_s_ZS_Why = "ritualist hexes recharging"
			Return 0.3
	EndSwitch
	Return 0
EndFunc   ;==>ZS_Eval_DropRule

;~ Description: Auto attack is a candidate like the others, in the lowest band.
Func ZS_Eval_AutoAttack()
	If $g_ai_ZS_Foes[0] = 0 Or Not $g_b_ZS_InCombat Then Return
	If ZS_Veto_Punished($GC_ZS_PUN_ATTACK) <> "" Then Return

	Local $l_i_Best = 0, $l_f_BestU = 0, $l_f_U, $l_i_Idx
	For $i = 1 To $g_ai_ZS_Foes[0]
		$l_i_Idx = $g_ai_ZS_Foes[$i]
		$l_f_U = 0.3 + ZS_Eval_FoeBias($l_i_Idx) - $g_amx2_ZS_Agent[$l_i_Idx][$GC_ZS_A_Dist] / 10000
		If $g_amx2_ZS_Agent[$l_i_Idx][$GC_ZS_A_ID] = $g_i_ZS_AttackTarget Then $l_f_U += 0.1
		If $l_f_U > $l_f_BestU Then
			$l_f_BestU = $l_f_U
			$l_i_Best = $l_i_Idx
		EndIf
	Next
	If $l_i_Best = 0 Then Return
	ZS_Eval_Offer($GC_ZS_ACT_ATTACK, 0, $g_amx2_ZS_Agent[$l_i_Best][$GC_ZS_A_ID], $GC_ZS_BAND_IDLE, ZS_Curve_Clamp($l_f_BestU), "auto attack")
EndFunc   ;==>ZS_Eval_AutoAttack

;~ Description: Insert a candidate in the ranking of the tick (best first, $GC_ZS_TOPN kept).
Func ZS_Eval_Offer($a_i_Action, $a_i_Slot, $a_i_TargetID, $a_i_Band, $a_f_Utility, $a_s_Why, $a_f_X = 0, $a_f_Y = 0)
	If $a_f_Utility > 9.9 Then $a_f_Utility = 9.9
	Local $l_f_Score = $a_i_Band * 10 + $a_f_Utility

	Local $l_i_Pos = $g_i_ZS_TopCount
	While $l_i_Pos > 0 And $g_amx2_ZS_Top[$l_i_Pos - 1][$GC_ZS_D_Score] < $l_f_Score
		$l_i_Pos -= 1
	WEnd
	If $l_i_Pos >= $GC_ZS_TOPN Then Return

	Local $l_i_Last = $g_i_ZS_TopCount
	If $l_i_Last > $GC_ZS_TOPN - 1 Then $l_i_Last = $GC_ZS_TOPN - 1
	For $i = $l_i_Last To $l_i_Pos + 1 Step -1
		For $j = 0 To $GC_ZS_D_COUNT - 1
			$g_amx2_ZS_Top[$i][$j] = $g_amx2_ZS_Top[$i - 1][$j]
		Next
	Next
	$g_amx2_ZS_Top[$l_i_Pos][$GC_ZS_D_Action] = $a_i_Action
	$g_amx2_ZS_Top[$l_i_Pos][$GC_ZS_D_Slot] = $a_i_Slot
	$g_amx2_ZS_Top[$l_i_Pos][$GC_ZS_D_TargetID] = $a_i_TargetID
	$g_amx2_ZS_Top[$l_i_Pos][$GC_ZS_D_Band] = $a_i_Band
	$g_amx2_ZS_Top[$l_i_Pos][$GC_ZS_D_Utility] = $a_f_Utility
	$g_amx2_ZS_Top[$l_i_Pos][$GC_ZS_D_Score] = $l_f_Score
	$g_amx2_ZS_Top[$l_i_Pos][$GC_ZS_D_Why] = $a_s_Why
	$g_amx2_ZS_Top[$l_i_Pos][$GC_ZS_D_X] = $a_f_X
	$g_amx2_ZS_Top[$l_i_Pos][$GC_ZS_D_Y] = $a_f_Y
	If $g_i_ZS_TopCount < $GC_ZS_TOPN Then $g_i_ZS_TopCount += 1
EndFunc   ;==>ZS_Eval_Offer
#EndRegion Candidates

#Region Shared considerations
;~ Description: Distance from which the skill of the slot can be used.
Func ZS_Eval_Range($a_i_Slot)
	Local $l_i_Special = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Special]
	If BitAND($l_i_Special, $GC_I_SKILL_SPECIAL_FLAG_TOUCH) Then Return $GC_I_RANGE_INTERACT
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ATTACK Then
		Switch $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_WeaponType]
			Case $GC_I_WEAPON_TYPE_AXE, $GC_I_WEAPON_TYPE_HAMMER, $GC_I_WEAPON_TYPE_DAGGERS, $GC_I_WEAPON_TYPE_SCYTHE, $GC_I_WEAPON_TYPE_SWORD
				Return $GC_I_RANGE_INTERACT
		EndSwitch
		Return $GC_I_RANGE_LONGBOW
	EndIf
	If BitAND($l_i_Special, $GC_I_SKILL_SPECIAL_FLAG_HALF_RANGE) Then Return $GC_I_RANGE_SPELLCASTING / 2
	Return $GC_I_RANGE_SPELLCASTING
EndFunc   ;==>ZS_Eval_Range

;~ Description: Utility added to a foe by who it is: called or priority target, previous target, health.
Func ZS_Eval_FoeBias($a_i_Idx)
	Local $l_f_Bias = 0
	Local $l_i_ID = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_ID]
	Local $l_i_Called = ($g_i_ZS_ForceTarget <> 0 ? $g_i_ZS_ForceTarget : $g_i_ZS_CalledTarget)
	If $l_i_ID = $l_i_Called Then
		$l_f_Bias += $g_f_ZS_CalledTargetBonus
		If $g_b_ZS_Explain Then $g_s_ZS_Why &= " called+" & $g_f_ZS_CalledTargetBonus
	EndIf
	If ZS_ModelIn($a_i_Idx, $g_v_ZS_PriorityModels) Then $l_f_Bias += $g_f_ZS_CalledTargetBonus
	If $l_i_ID = $g_i_ZS_LastFoeTarget Then $l_f_Bias += $g_f_ZS_InertiaBonus
	$l_f_Bias += $g_f_ZS_LowHPWeight * (1 - $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_HP])
	; A summoned creature is rarely worth a skill
	If BitAND($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Flags], $GC_ZS_AF_SPAWNED) Then $l_f_Bias -= 0.2
	Return $l_f_Bias
EndFunc   ;==>ZS_Eval_FoeBias

;~ Description: False when the skill wants a condition on its target that the target does not show.
Func ZS_Eval_ReqMet($a_i_Slot, $a_i_Idx)
	Local $l_i_Req = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Req]
	If $l_i_Req = 0 Then Return True
	Local $l_i_Flags = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Flags]
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_BLEEDING) And BitAND($l_i_Flags, $GC_ZS_AF_BLEEDING) Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_POISONED) And BitAND($l_i_Flags, $GC_ZS_AF_POISONED) Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_DEEP_WOUND) And BitAND($l_i_Flags, $GC_ZS_AF_DEEPWOUND) Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_CRIPPLED) And BitAND($l_i_Flags, $GC_ZS_AF_CRIPPLED) Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_KNOCKDOWN) And BitAND($l_i_Flags, $GC_ZS_AF_KNOCKED) Then Return True
	; Burning, blindness, daze, weakness and disease come from the visible effects
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_BURNING) And BitAND($l_i_Flags, $GC_ZS_AF_BURNING) Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_BLINDED) And BitAND($l_i_Flags, $GC_ZS_AF_BLIND) Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_DAZED) And BitAND($l_i_Flags, $GC_ZS_AF_DAZED) Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_WEAKNESS) And BitAND($l_i_Flags, $GC_ZS_AF_WEAKNESS) Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_DISEASED) And BitAND($l_i_Flags, $GC_ZS_AF_DISEASED) Then Return True
	; Without the visible effects, any condition stands for them
	If Not $g_b_ZS_ReadVisibleEffects And BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_BURNING + $GC_I_SKILL_REQUIRE_BLINDED + $GC_I_SKILL_REQUIRE_DAZED _
			 + $GC_I_SKILL_REQUIRE_WEAKNESS + $GC_I_SKILL_REQUIRE_DISEASED) And BitAND($l_i_Flags, $GC_ZS_AF_CONDITIONED) Then Return True
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_SLOWER_MOVEMENT) And BitAND($l_i_Flags, $GC_ZS_AF_CONDITIONED) Then Return True
	Return False
EndFunc   ;==>ZS_Eval_ReqMet

;~ Description: Where the effect of the slot stands on the agent:
;~ -1 still active for longer than a recast takes (do not cast), 1 active but about to end (renewal), 0 absent.
;~ A renewal raises $g_b_ZS_Renewal: keeping up a useful buff goes before damage (Upkeep band).
Func ZS_Eval_BuffState($a_i_Slot, $a_i_AgentID)
	Local $l_i_Remain = ZS_FxRemain($a_i_AgentID, $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID])
	If $l_i_Remain <= 0 Then Return 0
	Local $l_i_Guard = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ActivationMs] + $g_i_ZS_Ping + $g_i_ZS_CastMargin + 500
	If $l_i_Remain > $l_i_Guard Then Return -1
	$g_b_ZS_Renewal = True
	Return 1
EndFunc   ;==>ZS_Eval_BuffState

;~ Description: True for a skill whose point is to reduce the damage taken (block, armor, protection).
;~ Such a skill is only worth casting on someone who is being hit.
Func ZS_Eval_IsDefensive($a_i_Slot)
	; "Defensive=0": a build keeps it up all the time (Shadow Form), whatever the game flags say
	Local $l_s_Def = ZS_SlotParam($a_i_Slot, "Defensive")
	If $l_s_Def = "0" Then Return False
	If $l_s_Def = "1" Then Return True
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Family] = $GC_ZS_FAM_PROTECT Then Return True
	If BitAND($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Effect2], $GC_I_SKILL_EFFECT2_BLOCKING) Then Return True
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Attribute] = $GC_I_ATTRIBUTE_PROTECTION_PRAYERS Then Return True
	Return False
EndFunc   ;==>ZS_Eval_IsDefensive

;~ Description: Rule of the effect on the player that ends when it uses a skill ("EndsOn=" of its slot), "" when none.
;~ Skill: any skill ends it (Charging Strike); NonAdrenal: a skill without adrenaline (Battle Rage); Adrenal (Disciplined Stance).
Func ZS_Eval_EndsOnRule()
	Local $l_s_Rule
	For $l_i_Slot = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] = 0 Then ContinueLoop
		$l_s_Rule = ZS_SlotParam($l_i_Slot, "EndsOn")
		If $l_s_Rule <> "" And ZS_SelfHasFx($g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID]) Then Return $l_s_Rule
	Next
	Return ""
EndFunc   ;==>ZS_Eval_EndsOnRule

;~ Description: True when using the slot would end the effect of rule $a_s_Rule.
Func ZS_Eval_WouldEnd($a_i_Slot, $a_s_Rule)
	Local $l_b_Adrenal = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AdrenReq] > 0
	Switch $a_s_Rule
		Case "Skill"
			Return True
		Case "NonAdrenal"
			Return Not $l_b_Adrenal
		Case "Adrenal"
			Return $l_b_Adrenal
	EndSwitch
	Return False
EndFunc   ;==>ZS_Eval_WouldEnd

;~ Description: True when another stance (or form) of the player is still up for a while: a new one would replace it.
Func ZS_Eval_OtherStanceUp($a_i_Slot)
	Local $l_i_Type = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type]
	Local $l_i_Own = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID]
	Local $l_i_Guard = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ActivationMs] + $g_i_ZS_Ping + $g_i_ZS_CastMargin + 500
	For $l_i_SkillID In MapKeys($g_m_ZS_SelfFx)
		If $l_i_SkillID = $l_i_Own Then ContinueLoop
		If ZS_SkillData($l_i_SkillID, $GC_I_SKILL_TYPE) <> $l_i_Type Then ContinueLoop
		If $g_m_ZS_SelfFx[$l_i_SkillID] > $l_i_Guard Then Return $l_i_SkillID
	Next
	Return 0
EndFunc   ;==>ZS_Eval_OtherStanceUp

;~ Description: True for a skill whose effect prepares the next spell: a glyph, or any skill given "Before="
;~ (Intensity, Signet of Illusions, Extend Enchantments). It is only used when such a spell is ready to follow.
Func ZS_Eval_IsPrep($a_i_Slot)
	Return $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_GLYPH Or ZS_SlotParam($a_i_Slot, "Before") <> ""
EndFunc   ;==>ZS_Eval_IsPrep

;~ Description: True when spell slot $a_i_Spell is what preparation slot $a_i_Glyph prepares. "Before=" lists conditions
;~ that must all hold, separated by commas: Cost:n (energy), Cast:ms, Type:Enchantment|Hex|Spell, Prof:<profession>,
;~ Damage (a damage spell), Skill:<id>. Without it (glyphs): a spell of 10 energy or more, or of 2 s or more.
Func ZS_Eval_GlyphFits($a_i_Glyph, $a_i_Spell)
	If Not ZS_IsSpellType($g_amx2_ZS_Slot[$a_i_Spell][$GC_ZS_S_Type]) Then Return False
	Local $l_s_Rule = ZS_SlotParam($a_i_Glyph, "Before")
	Local $l_i_Cost = $g_amx2_ZS_Slot[$a_i_Spell][$GC_ZS_S_Energy], $l_i_Cast = $g_amx2_ZS_Slot[$a_i_Spell][$GC_ZS_S_ActivationMs]
	If $l_s_Rule = "" Then Return $l_i_Cost >= 10 Or $l_i_Cast >= 2000
	Local $l_as_Conds = StringSplit($l_s_Rule, ",", 2), $l_as_R, $l_s_V
	For $l_s_Cond In $l_as_Conds
		$l_as_R = StringSplit($l_s_Cond, ":", 2)
		$l_s_V = (UBound($l_as_R) > 1 ? $l_as_R[1] : "")
		Switch $l_as_R[0]
			Case "Cost"
				If $l_i_Cost < Number($l_s_V) Then Return False
			Case "Cast"
				If $l_i_Cast < Number($l_s_V) Then Return False
			Case "Type"
				If Not ZS_Eval_TypeIs($g_amx2_ZS_Slot[$a_i_Spell][$GC_ZS_S_Type], $l_s_V) Then Return False
			Case "Prof"
				If Not ZS_Qualifies_Prof($g_amx2_ZS_Slot[$a_i_Spell][$GC_ZS_S_Profession], $l_s_V) Then Return False
			Case "Damage"
				Switch $g_amx2_ZS_Slot[$a_i_Spell][$GC_ZS_S_Family]
					Case $GC_ZS_FAM_DAMAGE, $GC_ZS_FAM_DAMAGE_AOE, $GC_ZS_FAM_PBAOE
					Case Else
						Return False
				EndSwitch
			Case "Skill"
				If $g_amx2_ZS_Slot[$a_i_Spell][$GC_ZS_S_SkillID] <> Int($l_s_V) Then Return False
		EndSwitch
	Next
	Return True
EndFunc   ;==>ZS_Eval_GlyphFits

;~ Description: True when skill type $a_i_Type is the one named ("Enchantment", "Hex", "Spell": a plain spell).
Func ZS_Eval_TypeIs($a_i_Type, $a_s_Name)
	Switch $a_s_Name
		Case "Enchantment"
			Return $a_i_Type = $GC_I_SKILL_TYPE_ENCHANTMENT
		Case "Hex"
			Return $a_i_Type = $GC_I_SKILL_TYPE_HEX
		Case "Spell"
			Return $a_i_Type = $GC_I_SKILL_TYPE_SPELL
	EndSwitch
	Return False
EndFunc   ;==>ZS_Eval_TypeIs

;~ Description: True when a spell of the bar that glyph slot $a_i_Glyph prepares is ready to follow it.
Func ZS_Eval_GlyphTargetReady($a_i_Glyph)
	For $l_i_S = 1 To 8
		If $l_i_S = $a_i_Glyph Or $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_SkillID] = 0 Then ContinueLoop
		If Not ZS_Eval_GlyphFits($a_i_Glyph, $l_i_S) Then ContinueLoop
		If $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_Recharged] Then Return True
	Next
	Return False
EndFunc   ;==>ZS_Eval_GlyphTargetReady

;~ Description: Bonus of a spell slot while the effect of a glyph (or other preparation) that prepares it is on the
;~ player: spend it on that spell.
Func ZS_Eval_GlyphFollowUp($a_i_Slot)
	If Not ZS_IsSpellType($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type]) Then Return 0
	For $l_i_G = 1 To 8
		If $l_i_G = $a_i_Slot Or $g_amx2_ZS_Slot[$l_i_G][$GC_ZS_S_SkillID] = 0 Or Not ZS_Eval_IsPrep($l_i_G) Then ContinueLoop
		If Not ZS_SelfHasFx($g_amx2_ZS_Slot[$l_i_G][$GC_ZS_S_SkillID]) Then ContinueLoop
		If ZS_Eval_GlyphFits($l_i_G, $a_i_Slot) Then
			If $g_b_ZS_Explain Then $g_s_ZS_Why &= " glyph up"
			Return 0.1
		EndIf
	Next
	Return 0
EndFunc   ;==>ZS_Eval_GlyphFollowUp

;~ Description: Utility of a buff out of combat. Only two kinds go between fights:
;~ - a speed skill ("Speed=") while the player walks (following the leader, going back to a fight);
;~ - a skill told so ("OutOfCombat=1": a pre-buff kept up, a maintained enchantment...).
;~ Not twice: an effect still up for a while is left alone.
Func ZS_Eval_OutOfCombat($a_i_Slot, $a_i_AgentID)
	Local $l_b_Speed = (Int(ZS_SlotParam($a_i_Slot, "Speed", 0)) > 0)
	If $l_b_Speed Then
		If Not ZS_Is($g_i_ZS_MeIdx, $GC_ZS_AF_MOVING) Then Return 0
	ElseIf ZS_SlotParam($a_i_Slot, "OutOfCombat") <> "1" Then
		Return 0
	EndIf
	; A speed buff given to an ally (Windborne Speed): on the player, it walks with the party
	If $l_b_Speed And $a_i_AgentID <> $g_i_ZS_MyID And $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_TargetMask] <> $GC_ZS_TM_ALLY Then Return 0
	If ZS_Eval_BuffState($a_i_Slot, $a_i_AgentID) < 0 Then Return 0
	If $g_b_ZS_Explain Then $g_s_ZS_Why = ($l_b_Speed ? "out of combat: walking" : "out of combat: kept up")
	; A party speed skill goes before a personal one, more so with more of us around to share it
	If $l_b_Speed And ZS_IsGroupSpeed($a_i_Slot) Then
		Local $l_f_Area = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE]
		If $l_f_Area <= 0 Or $l_f_Area > $GC_I_RANGE_EARSHOT Then $l_f_Area = $GC_I_RANGE_EARSHOT
		Local $l_i_With = 0
		For $i = 1 To $g_ai_ZS_Allies[0]
			If $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_Dist] <= $l_f_Area Then $l_i_With += 1
		Next
		If $l_i_With > 4 Then $l_i_With = 4
		If $g_b_ZS_Explain Then $g_s_ZS_Why &= ", party speed for " & ($l_i_With + 1)
		Return 0.45 + 0.05 * $l_i_With
	EndIf
	; A personal one: the party walks together, a bot never outruns it (see $g_i_ZS_SoloSpeed)
	If $l_b_Speed Then
		Switch $g_i_ZS_SoloSpeed
			Case 0
				Return 0
			Case 1
				Local $l_f_Nearest = 1000000
				For $i = 1 To $g_ai_ZS_Allies[0]
					If $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_Dist] < $l_f_Nearest Then $l_f_Nearest = $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_Dist]
				Next
				If $g_ai_ZS_Allies[0] > 0 And $l_f_Nearest <= $g_f_ZS_CatchUpDist Then Return 0
				If $g_b_ZS_Explain Then $g_s_ZS_Why &= ($g_ai_ZS_Allies[0] = 0 ? ", alone" : ", catching up (" & Round($l_f_Nearest) & ")")
		EndSwitch
	EndIf
	Return 0.4
EndFunc   ;==>ZS_Eval_OutOfCombat

;~ Description: Slot of the bar holding $a_i_SkillID, 0 when none.
Func ZS_Eval_SlotOf($a_i_SkillID)
	For $l_i_S = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_SkillID] = $a_i_SkillID Then Return $l_i_S
	Next
	Return 0
EndFunc   ;==>ZS_Eval_SlotOf

;~ Description: True for a cleanse cast on the player that works on the allies around it (Song of Purification,
;~ Cautery Signet...): the skill only targets the player and has an area.
Func ZS_Eval_SelfArea($a_i_Slot, $a_i_Idx)
	If $a_i_Idx <> $g_i_ZS_MeIdx Or $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_TargetMask] <> $GC_ZS_TM_SELF Then Return False
	Return $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE] > 0
EndFunc   ;==>ZS_Eval_SelfArea

;~ Description: Utility of an area cleanse cast on the player: how many of us in its area show $a_i_Flag.
Func ZS_Eval_AreaCleanse($a_i_Slot, $a_i_Flag, $a_f_Base)
	Local $l_f_Area = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE], $l_i_N = 0
	If $l_f_Area >= 1000 Then $l_f_Area = 1500
	If ZS_Is($g_i_ZS_MeIdx, $a_i_Flag) Then $l_i_N = 1
	For $i = 1 To $g_ai_ZS_Allies[0]
		If $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_Dist] <= $l_f_Area And ZS_Is($g_ai_ZS_Allies[$i], $a_i_Flag) Then $l_i_N += 1
	Next
	If $l_i_N = 0 Then Return 0
	If $g_b_ZS_Explain Then $g_s_ZS_Why = $l_i_N & " of us to cleanse in the area"
	Return ZS_Curve_Clamp($a_f_Base + 0.1 * ($l_i_N - 1))
EndFunc   ;==>ZS_Eval_AreaCleanse

;~ Description: Highest pressure on the player or an ally in reach (0..1).
Func ZS_Eval_PartyPressure()
	Local $l_f_Max = ZS_Threat($g_i_ZS_MeIdx), $l_f_T
	For $i = 1 To $g_ai_ZS_Allies[0]
		$l_f_T = ZS_Threat($g_ai_ZS_Allies[$i])
		If $l_f_T > $l_f_Max Then $l_f_Max = $l_f_T
	Next
	Return $l_f_Max
EndFunc   ;==>ZS_Eval_PartyPressure
#EndRegion Shared considerations

#Region Family considerations
;~ Description: 0..1 need for using the skill of the slot on this agent. 0 or less = not a candidate.
Func ZS_Eval_Utility($a_i_Slot, $a_i_Family, $a_i_Idx)
	Local $l_f_HP = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_HP]
	Local $l_i_Flags = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Flags]
	Local $l_i_ID = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_ID]
	Local $l_f_U = 0

	Switch $a_i_Family
		Case $GC_ZS_FAM_RESURRECT
			If $a_i_Idx = $g_i_ZS_MeIdx Then ; area resurrection cast on oneself: a dead ally in its area
				Local $l_f_RezArea = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE]
				If $l_f_RezArea <= 0 Or $l_f_RezArea >= 1000 Then $l_f_RezArea = 1500
				Local $l_b_InArea = False
				For $i = 1 To $g_ai_ZS_DeadAllies[0]
					If $g_amx2_ZS_Agent[$g_ai_ZS_DeadAllies[$i]][$GC_ZS_A_Dist] <= $l_f_RezArea Then $l_b_InArea = True
				Next
				If Not $l_b_InArea Then Return 0
			EndIf
			$l_f_U = 0.9
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "dead ally"

		Case $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_FAM_HEAL_SELF
			; The pet (Comfort Animal): a dead pet is only for the skills that bring it back
			If $a_i_Idx = $g_i_ZS_PetIdx And BitAND($l_i_Flags, $GC_ZS_AF_DEAD) Then
				If ZS_SlotParam($a_i_Slot, "PetRez") = "" Then Return 0
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "pet dead"
				Return 0.75
			EndIf
			If ZS_SlotParam($a_i_Slot, "PetRez") = "2" Then Return 0 ; only brings the pet back (Revive Animal)
			If $l_f_HP >= Number(ZS_SlotParam($a_i_Slot, "Below", 1)) Then Return 0
			; A heal that stays on its target (Mending, Healing Breeze, Reversal of Fortune...): not twice
			If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ENCHANTMENT And ZS_Eval_BuffState($a_i_Slot, $l_i_ID) < 0 Then Return 0
			$l_f_U = ZS_Curve_Ramp(1 - $l_f_HP, 0.06, 0.68)
			If BitAND($l_i_Flags, $GC_ZS_AF_DEEPWOUND) Then $l_f_U += 0.05
			If $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_HPPips] < 0 Then $l_f_U += 0.03 * Abs($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_HPPips])
			$l_f_U = ZS_Curve_Clamp($l_f_U)
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "hp " & Round($l_f_HP * 100) & "%"
			; A heal with a bonus under some health (Word of Healing: under 50 %) waits for it, unless it is urgent
			Local $l_f_BonusBelow = Number(ZS_SlotParam($a_i_Slot, "BonusBelow", 0))
			If $l_f_BonusBelow > 0 And $l_f_HP >= $l_f_BonusBelow And $l_f_HP > 0.3 Then
				$l_f_U *= 0.5
				If $g_b_ZS_Explain Then $g_s_ZS_Why &= " waits for its bonus under " & Round($l_f_BonusBelow * 100) & "%"
			EndIf

		Case $GC_ZS_FAM_HEAL_PARTY
			; A small area (Heal Area, Kareis Healing Circle: adjacent allies) only counts who stands in it
			Local $l_f_HealArea = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE]
			If $l_f_HealArea <= 0 Or $l_f_HealArea >= 1000 Then $l_f_HealArea = 1500
			Local $l_f_Missing = 1 - $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_HP], $l_i_Hurt = 0, $l_i_Members = 1
			If $l_f_Missing > 0.2 Then $l_i_Hurt = 1
			For $i = 1 To $g_ai_ZS_Allies[0]
				If $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_Dist] > $l_f_HealArea Then ContinueLoop
				$l_i_Members += 1
				$l_f_Missing += 1 - $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_HP]
				If $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_HP] < 0.8 Then $l_i_Hurt += 1
			Next
			$l_f_U = ZS_Curve_Ramp($l_f_Missing / $l_i_Members, 0.08, 0.4)
			If $l_i_Hurt < 2 Then $l_f_U *= 0.5
			If $g_b_ZS_Explain Then $g_s_ZS_Why = $l_i_Hurt & " hurt, avg missing " & Round($l_f_Missing / $l_i_Members * 100) & "%"

		Case $GC_ZS_FAM_PROTECT
			If ZS_Eval_BuffState($a_i_Slot, $l_i_ID) < 0 Then Return 0
			If $l_f_HP >= Number(ZS_SlotParam($a_i_Slot, "Below", 2)) Then Return 0
			; A protection is for someone who is being hit, not a buff to keep up
			If ZS_Threat($a_i_Idx) < 0.2 And $l_f_HP > 0.85 Then Return 0
			$l_f_U = 0.4 * ZS_Curve_Ramp(1 - $l_f_HP, 0.1, 0.6) + 0.6 * ZS_Threat($a_i_Idx)
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "hp " & Round($l_f_HP * 100) & "% threat " & Round(ZS_Threat($a_i_Idx), 2)

		Case $GC_ZS_FAM_HEX_REMOVAL
			If ZS_Eval_SelfArea($a_i_Slot, $a_i_Idx) Then Return ZS_Eval_AreaCleanse($a_i_Slot, $GC_ZS_AF_HEXED, 0.6)
			If BitAND($l_i_Flags, $GC_ZS_AF_HEXED) = 0 Then Return 0
			$l_f_U = 0.6
			If BitAND($l_i_Flags, $GC_ZS_AF_DEGENHEXED) Then $l_f_U += 0.2
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "hexed"

		Case $GC_ZS_FAM_COND_REMOVAL
			If ZS_Eval_SelfArea($a_i_Slot, $a_i_Idx) Then Return ZS_Eval_AreaCleanse($a_i_Slot, $GC_ZS_AF_CONDITIONED, 0.45)
			If BitAND($l_i_Flags, $GC_ZS_AF_CONDITIONED) = 0 Then Return 0
			$l_f_U = 0.45
			If BitAND($l_i_Flags, $GC_ZS_AF_DEEPWOUND) Then $l_f_U += 0.15
			If BitAND($l_i_Flags, $GC_ZS_AF_BLEEDING + $GC_ZS_AF_POISONED) Then $l_f_U += 0.1
			If BitAND($l_i_Flags, $GC_ZS_AF_CRIPPLED) Then $l_f_U += 0.05
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "conditioned"

		Case $GC_ZS_FAM_INTERRUPT
			$l_f_U = ZS_Eval_Interrupt($a_i_Slot, $a_i_Idx)
			If $l_f_U > 0 Then Return $l_f_U
			; An attack that interrupts (Savage Shot, Distracting Blow...) still hits when nothing is to be stopped,
			; below the plain attacks: it stays ready for a cast most of the time
			If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] <> $GC_I_SKILL_TYPE_ATTACK Or Not $g_b_ZS_InCombat Then Return 0
			If ZS_IsFoe($a_i_Idx) = False Or ZS_Is($g_i_ZS_MeIdx, $GC_ZS_AF_BLIND) Then Return 0
			If ZS_SlotParam($a_i_Slot, "Hold") = "1" Then Return 0
			; Some foe is activating a skill: keep it for the next one
			For $i = 1 To $g_ai_ZS_Foes[0]
				If $g_amx2_ZS_Agent[$g_ai_ZS_Foes[$i]][$GC_ZS_A_Skill] <> 0 Then Return 0
			Next
			$g_b_ZS_AsDamage = True
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "nothing to interrupt: attack"
			Return 0.32 + ZS_Eval_FoeBias($a_i_Idx)

		Case $GC_ZS_FAM_ENERGY
			If $g_f_ZS_MaxEnergy <= 0 Then Return 0
			Local $l_f_Need = ZS_Curve_Ramp(1 - $g_f_ZS_Energy / $g_f_ZS_MaxEnergy, 0.35, 0.8)
			Local $l_i_Bonus = ($a_i_Idx = $g_i_ZS_MeIdx ? 0 : ZS_Req_BonusMet($a_i_Slot, $a_i_Idx))
			If $l_i_Bonus = 0 Then
				$l_f_U = $l_f_Need
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "energy " & Round($g_f_ZS_Energy) & "/" & Round($g_f_ZS_MaxEnergy)
			ElseIf $l_i_Bonus > 0 Or $l_f_Need <= 0 Then
				; Glowing Gaze on a burning foe: damage and energy. A nuke at worst, a priority when energy is low
				If Not $g_b_ZS_InCombat Then Return 0
				$l_f_U = 0.45
				If $l_i_Bonus > 0 And $l_f_Need > $l_f_U Then $l_f_U = $l_f_Need
				If $l_i_Bonus < 0 Or $l_f_Need <= 0 Then $g_b_ZS_AsDamage = True
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "energy " & Round($g_f_ZS_Energy) & "/" & Round($g_f_ZS_MaxEnergy) & _
						($l_i_Bonus > 0 ? " target gives energy" : " damage only")
			Else
				; Energy is needed but this target does not give it: only its damage
				If Not $g_b_ZS_InCombat Then Return 0
				$l_f_U = 0.35
				$g_b_ZS_AsDamage = True
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "no energy from this target, damage only"
			EndIf

		Case $GC_ZS_FAM_ENERGY_BUFF
			; Attunements, Ether Renewal...: they pay for everything else, keep them up during fights
			If Not $g_b_ZS_InCombat Then Return ZS_Eval_OutOfCombat($a_i_Slot, $l_i_ID)
			If ZS_Eval_BuffState($a_i_Slot, $l_i_ID) < 0 Then Return 0
			$l_f_U = 0.65
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "energy buff not active"

		Case $GC_ZS_FAM_SELF_BUFF, $GC_ZS_FAM_GENERIC_SELF, $GC_ZS_FAM_ITEM_SPELL
			If Not $g_b_ZS_InCombat Then Return ZS_Eval_OutOfCombat($a_i_Slot, $l_i_ID)
			; Holding an urn: drop it first (ZS_Eval_Bundles), never pick another one over it
			If $a_i_Family = $GC_ZS_FAM_ITEM_SPELL And $g_i_ZS_HeldUrn <> 0 Then Return 0
			If ZS_Eval_BuffState($a_i_Slot, $l_i_ID) < 0 Then Return 0
			; One stance (one form) at a time: a new one replaces the one up. Only a defensive one under
			; pressure may replace a stance that is not defensive.
			Local $l_i_SelfType = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type]
			If $l_i_SelfType = $GC_I_SKILL_TYPE_STANCE Or $l_i_SelfType = $GC_I_SKILL_TYPE_FORM Then
				Local $l_i_Up = ZS_Eval_OtherStanceUp($a_i_Slot)
				If $l_i_Up <> 0 Then
					If Not ZS_Eval_IsDefensive($a_i_Slot) Or ZS_Threat($a_i_Idx) < 0.5 Then Return 0
					Local $l_i_UpSlot = ZS_Eval_SlotOf($l_i_Up)
					If $l_i_UpSlot > 0 And ZS_Eval_IsDefensive($l_i_UpSlot) Then Return 0
					If $l_i_UpSlot = 0 And BitAND(ZS_SkillData($l_i_Up, $GC_I_SKILL_EFFECT_2), $GC_I_SKILL_EFFECT2_BLOCKING) Then Return 0
				EndIf
			EndIf
			; A glyph (or Intensity, Extend Enchantments...) only before the spell it prepares
			If ZS_Eval_IsPrep($a_i_Slot) Then
				If Not ZS_Eval_GlyphTargetReady($a_i_Slot) Then Return 0
				; Right before its spell: worth more than the spell itself, which follows on the next tick
				$l_f_U = 0.9
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "preparation: its spell is ready"
				Return $l_f_U
			EndIf
			If ZS_IsFlashEnchant($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID]) Then
				; Flash enchantment: worth most right before a stripper kicks it (its end effect + the stripper bonus)
				If ZS_StripperReady() Then
					$l_f_U = 0.55
					If $g_b_ZS_Explain Then $g_s_ZS_Why = "flash: feed the stripper"
				Else
					$l_f_U = 0.35
					If $g_b_ZS_Explain Then $g_s_ZS_Why = "flash, no stripper ready"
				EndIf
			ElseIf ZS_Eval_IsDefensive($a_i_Slot) Then
				; Worth what is hitting us, nothing when nobody is
				If ZS_Threat($a_i_Idx) < 0.2 Then Return 0
				$l_f_U = 0.25 + 0.75 * ZS_Threat($a_i_Idx)
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "defensive, threat " & Round(ZS_Threat($a_i_Idx), 2)
			Else
				; Just under a plain damage skill: goes when the damage skills are recharging
				$l_f_U = 0.4
				If $a_i_Family = $GC_ZS_FAM_GENERIC_SELF Then $l_f_U = 0.3
				If $a_i_Family = $GC_ZS_FAM_ITEM_SPELL Then $l_f_U = 0.35
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "not active"
			EndIf

		Case $GC_ZS_FAM_PARTY_BUFF
			If Not $g_b_ZS_InCombat Then Return ZS_Eval_OutOfCombat($a_i_Slot, $l_i_ID)
			If ZS_Eval_BuffState($a_i_Slot, $l_i_ID) < 0 Then Return 0
			If ZS_Eval_IsDefensive($a_i_Slot) Then
				Local $l_f_Pressure = ZS_Eval_PartyPressure()
				If $l_f_Pressure < 0.2 Then Return 0
				$l_f_U = 0.25 + 0.75 * $l_f_Pressure
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "defensive, party pressure " & Round($l_f_Pressure, 2)
			Else
				Local $l_i_Allies = $g_ai_ZS_Allies[0]
				If $l_i_Allies > 4 Then $l_i_Allies = 4
				$l_f_U = 0.35 + 0.025 * $l_i_Allies
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "not active, " & $g_ai_ZS_Allies[0] & " allies"
			EndIf

		Case $GC_ZS_FAM_ALLY_BUFF, $GC_ZS_FAM_GENERIC_ALLY
			If Not $g_b_ZS_InCombat Then Return ZS_Eval_OutOfCombat($a_i_Slot, $l_i_ID)
			If ZS_Eval_BuffState($a_i_Slot, $l_i_ID) < 0 Then Return 0
			If ZS_Eval_IsDefensive($a_i_Slot) Then
				If ZS_Threat($a_i_Idx) < 0.2 Then Return 0
				$l_f_U = 0.25 + 0.75 * ZS_Threat($a_i_Idx)
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "defensive, threat " & Round(ZS_Threat($a_i_Idx), 2)
			Else
				$l_f_U = ($a_i_Family = $GC_ZS_FAM_ALLY_BUFF ? 0.35 : 0.3)
				; An offensive buff is worth more on someone who is fighting
				If BitAND($l_i_Flags, $GC_ZS_AF_ATTACKING + $GC_ZS_AF_CASTING) Then $l_f_U += 0.05
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "not active"
			EndIf

		Case $GC_ZS_FAM_WEAPON_SPELL
			If Not $g_b_ZS_InCombat Then Return ZS_Eval_OutOfCombat($a_i_Slot, $l_i_ID)
			If BitAND($l_i_Flags, $GC_ZS_AF_WEAPONSPELL) Then Return 0
			; A protective one (Weapon of Warding, Vengeful Weapon...) goes to whoever is being hit
			If ZS_Eval_IsDefensive($a_i_Slot) Then
				If ZS_Threat($a_i_Idx) < 0.2 Then Return 0
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "defensive, threat " & Round(ZS_Threat($a_i_Idx), 2)
				Return 0.25 + 0.75 * ZS_Threat($a_i_Idx)
			EndIf
			$l_f_U = 0.25
			If $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_WeaponType] >= $GC_I_WEAPON_TYPE_BOW And $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_WeaponType] <= $GC_I_WEAPON_TYPE_SWORD Then $l_f_U += 0.15
			If BitAND($l_i_Flags, $GC_ZS_AF_ATTACKING) Then $l_f_U += 0.15
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "no weapon spell"

		Case $GC_ZS_FAM_HEX
			$l_f_U = (BitAND($l_i_Flags, $GC_ZS_AF_HEXED) ? 0.3 : 0.5)
			If $g_b_ZS_Explain Then $g_s_ZS_Why = (BitAND($l_i_Flags, $GC_ZS_AF_HEXED) ? "already hexed" : "not hexed")
			; A hex that spreads to the foes around its target (Spread=1: Mark of Rodgort, Suffering...)
			If ZS_SlotParam($a_i_Slot, "Spread") = "1" Then
				Local $l_i_Pack = ZS_CountSameSideNear($a_i_Idx, ($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE] <= 240 ? 240 : 312))
				If $l_i_Pack > 3 Then $l_i_Pack = 3
				$l_f_U += 0.08 * $l_i_Pack
				If $g_b_ZS_Explain Then $g_s_ZS_Why &= ", " & ($l_i_Pack + 1) & " in area"
			EndIf
			$l_f_U += ZS_Eval_FoeBias($a_i_Idx)

		Case $GC_ZS_FAM_ENCH_REMOVAL
			If BitAND($l_i_Flags, $GC_ZS_AF_ENCHANTED) = 0 Then Return 0
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "enchanted"
			$l_f_U = 0.55 + ZS_Eval_FoeBias($a_i_Idx)

		Case $GC_ZS_FAM_DAMAGE, $GC_ZS_FAM_GENERIC_FOE, $GC_ZS_FAM_PET_ATTACK
			; A pet attack needs a living pet
			If $a_i_Family = $GC_ZS_FAM_PET_ATTACK And Not ZS_Qualifies($a_i_Idx, "PetAlive") Then Return 0
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "foe hp " & Round($l_f_HP * 100) & "%"
			$l_f_U = ($a_i_Family = $GC_ZS_FAM_GENERIC_FOE ? 0.4 : 0.45) + ZS_Eval_FoeBias($a_i_Idx)
			If Not ZS_Eval_ReqMet($a_i_Slot, $a_i_Idx) Then $l_f_U *= 0.6

		Case $GC_ZS_FAM_DAMAGE_AOE
			Local $l_i_Near = ZS_CountSameSideNear($a_i_Idx, ($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE] <= 240 ? 240 : 312))
			If $l_i_Near + 1 < Number(ZS_SlotParam($a_i_Slot, "MinFoes", 1)) Then Return 0
			If $g_b_ZS_Explain Then $g_s_ZS_Why = ($l_i_Near + 1) & " foes in area"
			$l_f_U = 0.45 + ($l_i_Near > 3 ? 0.36 : 0.12 * $l_i_Near) + ZS_Eval_FoeBias($a_i_Idx)
			If Not ZS_Eval_ReqMet($a_i_Slot, $a_i_Idx) Then $l_f_U *= 0.6

		Case $GC_ZS_FAM_PBAOE
			Local $l_f_Radius = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE]
			If $l_f_Radius <= 0 Then $l_f_Radius = $GC_I_RANGE_NEARBY
			Local $l_i_Around = ZS_CountAround($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_X], $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Y], $l_f_Radius, True)
			If $l_i_Around < Number(ZS_SlotParam($a_i_Slot, "MinFoes", 1)) Then Return 0
			$l_f_U = 0.3 + ($l_i_Around > 3 ? 0.5 : 0.15 * $l_i_Around)
			If $g_b_ZS_Explain Then $g_s_ZS_Why = $l_i_Around & " foes around me"

		Case $GC_ZS_FAM_ATTACK
			If Not ZS_Veto_ComboOK($a_i_Slot, $a_i_Idx) Then Return 0
			; Blind: nine attacks out of ten miss, keep the skill (and its adrenaline) for later
			If ZS_Is($g_i_ZS_MeIdx, $GC_ZS_AF_BLIND) Then Return 0
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "foe hp " & Round($l_f_HP * 100) & "%"
			$l_f_U = 0.5 + ZS_Eval_FoeBias($a_i_Idx)
			; An attack whose chain requirement is met right now goes before the ones usable any time
			If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ComboReq] <> 0 Then
				$l_f_U += 0.15
				If $g_b_ZS_Explain Then $g_s_ZS_Why &= " chain+0.15"
			EndIf
			If Not ZS_Eval_ReqMet($a_i_Slot, $a_i_Idx) Then $l_f_U *= 0.6
			Local $l_f_Plan = ZS_Eval_AttackPlan($a_i_Slot, $a_i_Idx)
			If $l_f_Plan <= -1 Then Return 0 ; held for the chain
			$l_f_U += $l_f_Plan

		Case $GC_ZS_FAM_SPIRIT
			; A spirit only works around where it stands: wait for foes to be close, not just in aggro range
			Local $l_i_Close = ZS_CountAround($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_X], $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Y], $GC_I_RANGE_EARSHOT, True)
			If $l_i_Close = 0 Then Return 0
			; Our spirit of this ritual still lives (above 20 %) and still has foes around it: nothing to recast
			Local $l_i_SpiritSkill = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID]
			If MapExists($g_m_ZS_SpiritOf, $l_i_SpiritSkill) Then
				Local $l_i_Spirit = ZS_IdxOf($g_m_ZS_SpiritOf[$l_i_SpiritSkill])
				If $l_i_Spirit > 0 And Not ZS_Is($l_i_Spirit, $GC_ZS_AF_DEAD) And $g_amx2_ZS_Agent[$l_i_Spirit][$GC_ZS_A_HP] >= 0.2 Then
					If ZS_CountAround($g_amx2_ZS_Agent[$l_i_Spirit][$GC_ZS_A_X], $g_amx2_ZS_Agent[$l_i_Spirit][$GC_ZS_A_Y], 1100, True) > 0 Then Return 0
				EndIf
			EndIf
			$l_f_U = 0.4
			If $g_b_ZS_Explain Then $g_s_ZS_Why = $l_i_Close & " foes in earshot"

		Case $GC_ZS_FAM_CORPSE
			If Not $g_b_ZS_AnyCorpse Then Return 0
			$l_f_U = 0.5
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "corpse in reach"

		Case $GC_ZS_FAM_WARD
			If Not $g_b_ZS_InCombat Then Return 0
			Local $l_f_WX = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_X], $l_f_WY = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Y]
			Local $l_f_WardArea = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AoE]
			If $l_f_WardArea <= 0 Then $l_f_WardArea = $GC_I_RANGE_AREA
			If ZS_SlotParam($a_i_Slot, "Ward") = "Foes" Then
				; Against the foes standing in it (Ward Against Foes, Ward of Weakness)
				Local $l_i_FoesIn = ZS_CountAround($l_f_WX, $l_f_WY, $l_f_WardArea, True)
				If $l_i_FoesIn < Number(ZS_SlotParam($a_i_Slot, "MinFoes", 1)) Then Return 0
				$l_f_U = 0.35 + ($l_i_FoesIn > 4 ? 0.4 : 0.1 * $l_i_FoesIn)
				If $g_b_ZS_Explain Then $g_s_ZS_Why = $l_i_FoesIn & " foes in the ward"
			ElseIf ZS_Eval_IsDefensive($a_i_Slot) Then
				; Protects who stands in it (Ward Against Melee, Elements, Harm): worth the pressure on them
				Local $l_f_WardThreat = 0, $l_f_T
				For $i = 1 To $g_i_ZS_AgentCount
					If $i <> $g_i_ZS_MeIdx And Not ZS_IsAlly($i) Then ContinueLoop
					If ZS_Is($i, $GC_ZS_AF_DEAD) Then ContinueLoop
					If ($g_amx2_ZS_Agent[$i][$GC_ZS_A_X] - $l_f_WX) ^ 2 + ($g_amx2_ZS_Agent[$i][$GC_ZS_A_Y] - $l_f_WY) ^ 2 > $l_f_WardArea ^ 2 Then ContinueLoop
					$l_f_T = ZS_Threat($i)
					If $l_f_T > $l_f_WardThreat Then $l_f_WardThreat = $l_f_T
				Next
				If $l_f_WardThreat < 0.2 Then Return 0
				$l_f_U = 0.25 + 0.75 * $l_f_WardThreat
				If $g_b_ZS_Explain Then $g_s_ZS_Why = "defensive ward, threat " & Round($l_f_WardThreat, 2)
			Else
				; Helps who stands in it (Ebon Battle Standards...), once foes are near
				If ZS_CountAround($l_f_WX, $l_f_WY, $GC_I_RANGE_EARSHOT, True) = 0 Then Return 0
				Local $l_i_Covered = ZS_CountAround($l_f_WX, $l_f_WY, $l_f_WardArea, False)
				$l_f_U = ($l_i_Covered >= 2 ? 0.45 : 0.2)
				If $g_b_ZS_Explain Then $g_s_ZS_Why = $l_i_Covered & " of us in the ward"
			EndIf

		Case $GC_ZS_FAM_TRAP
			; Traps are slow and easily interrupted: lay them when foes come but none is on us yet
			Local $l_f_MX = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_X], $l_f_MY = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Y]
			If ZS_CountAround($l_f_MX, $l_f_MY, 700, True) = 0 Then Return 0
			If ZS_CountAround($l_f_MX, $l_f_MY, 200, True) > 0 Then Return 0
			; Archers and casters aiming at us would interrupt it too
			If ZS_Threat($a_i_Idx) >= 0.2 Then Return 0
			$l_f_U = 0.45
			If $g_b_ZS_Explain Then $g_s_ZS_Why = "foes approaching"
	EndSwitch

	Return $l_f_U
EndFunc   ;==>ZS_Eval_Utility

;~ Description: True when the skill of a slot could be used now (recharged or enough adrenaline, energy in hand).
Func ZS_Eval_SlotReady($a_i_Slot)
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID] = 0 Then Return False
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AdrenReq] > 0 Then
		If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Adrenaline] < $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AdrenReq] Then Return False
	ElseIf Not $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Recharged] Then
		Return False
	EndIf
	Return ZS_Cost_Energy($a_i_Slot, True) <= $g_f_ZS_Energy
EndFunc   ;==>ZS_Eval_SlotReady

;~ Description: Utility added to an attack skill by what comes after it:
;~ - assassin chain: a lead attack only starts a chain its follow-up can finish (follow-up ready, energy for both);
;~ - adrenaline: the game takes one strike from every other adrenal skill when one is used, so the biggest
;~   ready one goes first, and a small one waits when it would delay a bigger one one strike from ready.
Func ZS_Eval_AttackPlan($a_i_Slot, $a_i_Idx)
	Local $l_f_Adj = 0, $l_i_S

	; --- chain ---
	; Only the start of a chain is held: once a lead landed, the next step always goes
	Local $l_i_Next = 0
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ComboType] = $GC_I_SKILL_COMBO_LEAD_ATTACK Then $l_i_Next = $GC_I_SKILL_COMBO_REQ_LEAD_ATTACK
	If $l_i_Next <> 0 Then
		Local $l_b_Has = False, $l_b_Ready = False, $l_f_Cheapest = 1000, $l_i_Soonest = 0x7FFFFFFF
		For $l_i_S = 1 To 8
			If $l_i_S = $a_i_Slot Or BitAND($g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_ComboReq], $l_i_Next) = 0 Then ContinueLoop
			$l_b_Has = True
			If Not ZS_Eval_SlotReady($l_i_S) Then
				If $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_AdrenReq] = 0 And $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_RechargeMs] < $l_i_Soonest Then _
						$l_i_Soonest = $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_RechargeMs]
				ContinueLoop
			EndIf
			$l_b_Ready = True
			If ZS_Cost_Energy($l_i_S, True) < $l_f_Cheapest Then $l_f_Cheapest = ZS_Cost_Energy($l_i_S, True)
		Next
		If $l_b_Has And Not $l_b_Ready Then
			; Hold it when the follow-up comes back before it would: wasted now, missing for the chain then
			Local $l_i_OwnRecharge = Int(ZS_SkillData($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID], $GC_I_SKILL_RECHARGE_TIME) * 1000)
			If $l_i_Soonest < $l_i_OwnRecharge Then
				If $g_b_ZS_Explain Then $g_s_ZS_Why &= " held: follow-up back in " & $l_i_Soonest & " ms"
				Return -1
			EndIf
		ElseIf $l_b_Ready And ZS_Cost_Energy($a_i_Slot, True) + $l_f_Cheapest > $g_f_ZS_Energy Then
			If $g_b_ZS_Explain Then $g_s_ZS_Why &= " held: no energy for the follow-up"
			Return -1
		EndIf
	EndIf

	; --- adrenaline ---
	Local $l_i_Cost = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AdrenReq]
	If $l_i_Cost > 0 Then
		Local $l_i_Strikes = Int($l_i_Cost / 25)
		If $l_i_Strikes > 8 Then $l_i_Strikes = 8
		$l_f_Adj += 0.02 * $l_i_Strikes ; a bigger adrenal skill hits harder
		Local $l_i_Other
		For $l_i_S = 1 To 8
			If $l_i_S = $a_i_Slot Or $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_SkillID] = 0 Then ContinueLoop
			$l_i_Other = $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_AdrenReq]
			If $l_i_Other <= $l_i_Cost Then ContinueLoop
			; One strike from ready: using this one now would set it back a strike
			If $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_Adrenaline] < $l_i_Other And $g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_Adrenaline] + 25 >= $l_i_Other Then
				If $g_b_ZS_Explain Then $g_s_ZS_Why &= " held: would delay " & ZS_SkillName($g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_SkillID])
				Return -1
			EndIf
		Next
	EndIf
	#forceref $a_i_Idx
	Return $l_f_Adj
EndFunc   ;==>ZS_Eval_AttackPlan

;~ Description: Need for interrupting what this foe is activating, 0 when it cannot be caught in time.
Func ZS_Eval_Interrupt($a_i_Slot, $a_i_Idx)
	Local $l_i_Theirs = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Skill]
	If $l_i_Theirs = 0 Then Return 0

	Local $l_i_TheirType = ZS_SkillData($l_i_Theirs, $GC_I_SKILL_TYPE)
	; An interrupt of spells (Power Spike, Savage Shot...) does nothing on another skill,
	; unless its exception holds ("AnyIf=Hexed": Signet of Disruption on a hexed foe)
	If ZS_SlotParam($a_i_Slot, "Only") = "Spell" And Not (ZS_IsSpellType($l_i_TheirType) Or $l_i_TheirType = $GC_I_SKILL_TYPE_CHANT) Then
		Local $l_s_Any = ZS_SlotParam($a_i_Slot, "AnyIf")
		If $l_s_Any = "" Or Not ZS_QualifiesList($a_i_Idx, $l_s_Any, False) Then Return 0
	EndIf

	; Time left on their activation against the time our interrupt needs to land.
	; We see their cast half a ping late and our command arrives half a ping later: one full ping in all.
	; So a 1/4 s interrupt catches a 1/2 s spell when ping + detection lag stay under 250 ms, never a 1/4 s spell.
	Local $l_i_TheirMs = Int(ZS_SkillData($l_i_Theirs, $GC_F_SKILL_ACTIVATION_TIME) * 1000)
	Local $l_i_Left = $l_i_TheirMs - $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_CastMs]
	Local $l_i_Need = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ActivationMs] + $g_i_ZS_Ping + $g_i_ZS_InterruptMargin
	; An arrow or a spear also has to fly to the target; a melee attack has to walk to it
	Local $l_i_Flight = ZS_Eval_FlightMs($a_i_Slot, $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Dist])
	If $l_i_Flight = 0 And $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ATTACK Then
		Local $l_f_Walk = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Dist] - ZS_Eval_Range($a_i_Slot)
		If $l_f_Walk > 0 Then $l_i_Flight = Int($l_f_Walk / 0.25) ; about 250 units per second
	EndIf
	$l_i_Need += $l_i_Flight
	If $l_i_Left <= $l_i_Need Then Return 0

	Local $l_f_U = 0.55
	; An interrupt that gives energy (Power Drain, Power Leech...) is worth more when we lack it
	If BitAND($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Effect2], $GC_I_SKILL_EFFECT2_ENERGY_GAIN + $GC_I_SKILL_EFFECT2_ENERGY_STEAL) And $g_f_ZS_MaxEnergy > 0 Then
		$l_f_U += 0.15 * ZS_Curve_Ramp(1 - $g_f_ZS_Energy / $g_f_ZS_MaxEnergy, 0.3, 0.8)
	EndIf
	; What their skill does, with the same classification as ours (resurrection, heal, protection...)
	Local $l_f_Danger = ZS_Eval_FoeSkillDanger($l_i_Theirs)
	$l_f_U += $l_f_Danger
	If $l_i_TheirMs >= 2000 Then $l_f_U += 0.2
	If BitAND(ZS_SkillData($l_i_Theirs, $GC_I_SKILL_SPECIAL), $GC_I_SKILL_SPECIAL_FLAG_ELITE) Then $l_f_U += 0.1
	If $g_b_ZS_Explain Then $g_s_ZS_Why = "casting " & ZS_SkillName($l_i_Theirs) & ", " & $l_i_Left & " ms left, need " & $l_i_Need & _
			($l_i_Flight > 0 ? " (flight " & $l_i_Flight & ")" : "")
	Return ZS_Curve_Clamp($l_f_U)
EndFunc   ;==>ZS_Eval_Interrupt

;~ Description: Value of stopping a foe skill, from its family (cached per skill).
;~ Their resurrections and heals undo our work; protections, cleanses, area damage and hexes hurt us.
Func ZS_Eval_FoeSkillDanger($a_i_SkillID)
	If MapExists($g_m_ZS_FoeDanger, $a_i_SkillID) Then Return $g_m_ZS_FoeDanger[$a_i_SkillID]
	Local $l_i_Mask = 0, $l_f_D = 0
	Local $l_i_E2 = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_EFFECT_2)
	Switch ZS_Knowledge_Classify($a_i_SkillID, $l_i_Mask)
		Case $GC_ZS_FAM_RESURRECT
			$l_f_D = 0.4
		Case $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_FAM_HEAL_SELF, $GC_ZS_FAM_HEAL_PARTY
			$l_f_D = 0.3
		Case $GC_ZS_FAM_PROTECT
			$l_f_D = 0.25
		Case $GC_ZS_FAM_HEX_REMOVAL, $GC_ZS_FAM_COND_REMOVAL
			$l_f_D = 0.15
		Case $GC_ZS_FAM_DAMAGE_AOE, $GC_ZS_FAM_HEX
			$l_f_D = 0.1
	EndSwitch
	; Game flags as a safety net for families the rules miss
	If $l_f_D < 0.4 And BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_RESURRECTION + $GC_I_SKILL_EFFECT2_RES_SIGNET) Then $l_f_D = 0.4
	If $l_f_D < 0.3 And BitAND($l_i_E2, $GC_I_SKILL_EFFECT2_CAN_HEAL_OTHER + $GC_I_SKILL_EFFECT2_CAN_HEAL_SELF) Then $l_f_D = 0.3
	$g_m_ZS_FoeDanger[$a_i_SkillID] = $l_f_D
	Return $l_f_D
EndFunc   ;==>ZS_Eval_FoeSkillDanger

;~ Description: ms the projectile of a bow or spear skill of the slot takes over $a_f_Dist (0 for the others).
Func ZS_Eval_FlightMs($a_i_Slot, $a_f_Dist)
	Local $l_i_Req = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_WeaponReq]
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_BOW) And $g_f_ZS_ArrowSpeed > 0 Then Return Int($a_f_Dist / $g_f_ZS_ArrowSpeed)
	If BitAND($l_i_Req, $GC_I_SKILL_REQUIRE_SPEAR) And $g_f_ZS_SpearSpeed > 0 Then Return Int($a_f_Dist / $g_f_ZS_SpearSpeed)
	Return 0
EndFunc   ;==>ZS_Eval_FlightMs
#EndRegion Family considerations
