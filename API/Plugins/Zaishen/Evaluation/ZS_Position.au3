#include-once

; Zaishen positioning: where the player should stand during a fight.
; A move is a candidate like the skills (ZS_Eval_Offer with $GC_ZS_ACT_MOVE): it only happens when it is worth more
; than anything else. Cases:
;   - standing in a damaging area a foe put on the ground (Fire Storm, Maelstrom...): leave it (Survival band);
;   - a caster (ranged weapon) with foes hitting it in melee: one step back, towards the party (Damage, Heal under
;     heavy pressure), at most once every $g_i_ZS_BackOffCooldown ms, and never out of spell range of every foe;
;   - holding a resurrecting urn (Drop=DeadAlly) with the dead ally out of its area: walk to it.
; Reaching a target is not handled here: the game walks to range by itself when a skill or an attack is used.
; A move once started is kept until reached (or timed out): a lesser action does not stop it halfway.
; Area detection, pure on the snapshot: a foe seen casting a ground area spell (by name in the offline table, its
; monster versions included) at one of us leaves, when the cast completes, an area where that one of us stood.

; Ground area spells: names of the offline skill table (player and monster versions share them)
Global Const $GC_AS_ZS_GROUND_AREAS[11] = ["Fire Storm", "Meteor Shower", "Maelstrom", "Chaos Storm", "Searing Heat", _
		"Bed of Coals", "Eruption", "Savannah Heat", "Sandstorm", "Lightning Storm", "Churning Earth"]

#Region Damaging areas
;~ Description: True when $a_i_SkillID leaves a damaging area on the ground (cached per skill).
Func ZS_IsGroundArea($a_i_SkillID)
	If MapExists($g_m_ZS_HazSkill, $a_i_SkillID) Then Return $g_m_ZS_HazSkill[$a_i_SkillID]
	Local $l_s_Name = ZS_SkillName($a_i_SkillID), $l_b_Is = False
	For $i = 0 To UBound($GC_AS_ZS_GROUND_AREAS) - 1
		If $l_s_Name = $GC_AS_ZS_GROUND_AREAS[$i] Then $l_b_Is = True
	Next
	$g_m_ZS_HazSkill[$a_i_SkillID] = $l_b_Is
	Return $l_b_Is
EndFunc   ;==>ZS_IsGroundArea

;~ Description: Follow the foes casting a ground area spell, and turn every completed cast into an area.
;~ Called once per snapshot (ZS_Snapshot_Finalize), after the distances.
Func ZS_Hazard_Update()
	; Areas that are over
	Local $l_i_Keep = 0
	For $i = 0 To $g_i_ZS_HazardCount - 1
		If $g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_Until] <= $g_i_ZS_Now Then ContinueLoop
		If $l_i_Keep <> $i Then
			For $c = 0 To $GC_ZS_HZ_COUNT - 1
				$g_amx2_ZS_Hazard[$l_i_Keep][$c] = $g_amx2_ZS_Hazard[$i][$c]
			Next
		EndIf
		$l_i_Keep += 1
	Next
	$g_i_ZS_HazardCount = $l_i_Keep

	; Casts that ended since the last tick: completed ones become areas
	Local $l_i_Idx, $l_av_Cast, $l_i_Skill
	For $l_i_ID In MapKeys($g_m_ZS_HazCast)
		$l_av_Cast = $g_m_ZS_HazCast[$l_i_ID]
		$l_i_Idx = ZS_IdxOf($l_i_ID)
		If $l_i_Idx > 0 And $g_amx2_ZS_Agent[$l_i_Idx][$GC_ZS_A_Skill] = $l_av_Cast[0] Then ContinueLoop ; still casting
		MapRemove($g_m_ZS_HazCast, $l_i_ID)
		If $l_i_Idx = 0 Or ZS_Is($l_i_Idx, $GC_ZS_AF_DEAD + $GC_ZS_AF_KNOCKED) Then ContinueLoop ; died or was interrupted
		$l_i_Skill = $l_av_Cast[0]
		If $g_i_ZS_Now - $l_av_Cast[3] < 0.75 * ZS_SkillData($l_i_Skill, $GC_F_SKILL_ACTIVATION_TIME) * 1000 Then ContinueLoop ; cut short
		ZS_Hazard_Add($l_av_Cast[1], $l_av_Cast[2], $l_i_Skill)
	Next

	; Foes casting one now: remember where the one of us it faces stands (a well: the corpse nearest the caster)
	Local $l_i_Aim
	For $i = 1 To $g_i_ZS_AgentCount
		If Not ZS_IsFoe($i) Then ContinueLoop
		$l_i_Skill = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Skill]
		If $l_i_Skill = 0 Then ContinueLoop
		If ZS_IsFoeWell($l_i_Skill) Then
			$l_i_Aim = ZS_NearestCorpseTo($i)
		ElseIf ZS_IsGroundArea($l_i_Skill) Then
			$l_i_Aim = ZS_AimOf($i)
		Else
			ContinueLoop
		EndIf
		If $l_i_Aim = 0 Then ContinueLoop
		Local $l_i_FoeID = $g_amx2_ZS_Agent[$i][$GC_ZS_A_ID]
		Local $l_i_Start = $g_i_ZS_Now - $g_amx2_ZS_Agent[$i][$GC_ZS_A_CastMs]
		If MapExists($g_m_ZS_HazCast, $l_i_FoeID) Then
			Local $l_av_Old = $g_m_ZS_HazCast[$l_i_FoeID]
			If $l_av_Old[0] = $l_i_Skill Then $l_i_Start = $l_av_Old[3]
		EndIf
		Local $l_av_New[4] = [$l_i_Skill, $g_amx2_ZS_Agent[$l_i_Aim][$GC_ZS_A_X], $g_amx2_ZS_Agent[$l_i_Aim][$GC_ZS_A_Y], $l_i_Start]
		$g_m_ZS_HazCast[$l_i_FoeID] = $l_av_New
	Next
EndFunc   ;==>ZS_Hazard_Update

;~ Description: True for a well that harms the ones standing in it (all but Well of Blood and Well of Power).
Func ZS_IsFoeWell($a_i_SkillID)
	If ZS_SkillData($a_i_SkillID, $GC_I_SKILL_TYPE) <> $GC_I_SKILL_TYPE_WELL Then Return False
	Return $a_i_SkillID <> $GC_I_SKILL_ID_WELL_OF_BLOOD And $a_i_SkillID <> $GC_I_SKILL_ID_WELL_OF_POWER
EndFunc   ;==>ZS_IsFoeWell

;~ Description: Row of the exploitable corpse nearest agent row $a_i_Idx, within earshot of it (0 = none).
Func ZS_NearestCorpseTo($a_i_Idx)
	Local $l_f_X = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_X], $l_f_Y = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Y]
	Local $l_f_Best = $GC_I_RANGE_EARSHOT * $GC_I_RANGE_EARSHOT, $l_i_Best = 0, $l_f_DX, $l_f_DY, $l_f_Sq
	For $i = 1 To $g_i_ZS_AgentCount
		If Not BitAND($g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags], $GC_ZS_AF_CORPSE) Then ContinueLoop
		$l_f_DX = $g_amx2_ZS_Agent[$i][$GC_ZS_A_X] - $l_f_X
		$l_f_DY = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Y] - $l_f_Y
		$l_f_Sq = $l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY
		If $l_f_Sq <= $l_f_Best Then
			$l_f_Best = $l_f_Sq
			$l_i_Best = $i
		EndIf
	Next
	Return $l_i_Best
EndFunc   ;==>ZS_NearestCorpseTo

;~ Description: Add a damaging area of skill $a_i_SkillID centred on ($a_f_X, $a_f_Y), for the skill's duration
;~ (the foe's rank is unknown: the rank 15 one), $a_i_RemainMs when given.
Func ZS_Hazard_Add($a_f_X, $a_f_Y, $a_i_SkillID, $a_i_RemainMs = 0, $a_f_Radius = 0)
	If $g_i_ZS_HazardCount >= UBound($g_amx2_ZS_Hazard) Then ReDim $g_amx2_ZS_Hazard[$g_i_ZS_HazardCount + 4][$GC_ZS_HZ_COUNT]
	Local $l_f_R = $a_f_Radius
	If $l_f_R <= 0 Then $l_f_R = ZS_SkillData($a_i_SkillID, $GC_I_SKILL_AOE_RANGE)
	If $l_f_R < 156 Then $l_f_R = 156
	Local $l_i_Ms = $a_i_RemainMs
	If $l_i_Ms <= 0 Then
		$l_i_Ms = 1000 * ZS_SkillData($a_i_SkillID, $GC_I_SKILL_DURATION_15)
		If 1000 * ZS_SkillData($a_i_SkillID, $GC_I_SKILL_DURATION_0) > $l_i_Ms Then $l_i_Ms = 1000 * ZS_SkillData($a_i_SkillID, $GC_I_SKILL_DURATION_0)
		If $l_i_Ms <= 0 Then $l_i_Ms = 8000
		If $l_i_Ms > 15000 Then $l_i_Ms = 15000
	EndIf
	Local $l_i_H = $g_i_ZS_HazardCount
	$g_amx2_ZS_Hazard[$l_i_H][$GC_ZS_HZ_X] = $a_f_X
	$g_amx2_ZS_Hazard[$l_i_H][$GC_ZS_HZ_Y] = $a_f_Y
	$g_amx2_ZS_Hazard[$l_i_H][$GC_ZS_HZ_R] = $l_f_R
	$g_amx2_ZS_Hazard[$l_i_H][$GC_ZS_HZ_Until] = $g_i_ZS_Now + $l_i_Ms
	$g_amx2_ZS_Hazard[$l_i_H][$GC_ZS_HZ_Skill] = $a_i_SkillID
	$g_i_ZS_HazardCount += 1
	If $g_s_ZS_LogFile <> "" Then ZS_Log_Event("damaging area " & ZS_SkillName($a_i_SkillID) & " at " & Round($a_f_X) & "," & Round($a_f_Y) & " r" & Round($l_f_R))
EndFunc   ;==>ZS_Hazard_Add

;~ Description: Forget the areas and the casts followed (new instance, tests).
Func ZS_Hazard_Reset()
	$g_i_ZS_HazardCount = 0
	Local $l_m_Empty[]
	$g_m_ZS_HazCast = $l_m_Empty
EndFunc   ;==>ZS_Hazard_Reset

;~ Description: Index of the area that covers ($a_f_X, $a_f_Y) for at least $a_i_ForMs more (with a margin), -1 when none.
Func ZS_Hazard_At($a_f_X, $a_f_Y, $a_i_ForMs = 0, $a_f_Margin = 40)
	Local $l_f_DX, $l_f_DY, $l_f_R
	For $i = 0 To $g_i_ZS_HazardCount - 1
		If $g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_Until] - $g_i_ZS_Now <= $a_i_ForMs Then ContinueLoop
		$l_f_DX = $a_f_X - $g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_X]
		$l_f_DY = $a_f_Y - $g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_Y]
		$l_f_R = $g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_R] + $a_f_Margin
		If $l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY <= $l_f_R * $l_f_R Then Return $i
	Next
	Return -1
EndFunc   ;==>ZS_Hazard_At
#EndRegion Damaging areas

#Region Moves
;~ Description: Offer the moves worth making now. Called by ZS_Evaluate after the skills.
Func ZS_Eval_Position()
	If Not $g_b_ZS_Positioning Or Not $g_b_ZS_InCombat Then Return
	Local $l_i_Me = $g_i_ZS_MeIdx
	Local $l_f_MX = $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_X], $l_f_MY = $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_Y]

	; --- 1) leave a damaging area: decided again every tick while inside ---
	Local $l_i_H = ZS_Hazard_At($l_f_MX, $l_f_MY, 1000)
	If $l_i_H >= 0 Then
		Local $l_f_DX, $l_f_DY
		If ZS_Pos_EscapeFrom($l_i_H, $l_f_DX, $l_f_DY) Then
			ZS_Pos_Offer($l_f_DX, $l_f_DY, $GC_ZS_BAND_SURVIVAL, 0.7, "leave " & ZS_SkillName($g_amx2_ZS_Hazard[$l_i_H][$GC_ZS_HZ_Skill]))
			Return
		EndIf
	EndIf

	; --- a move under way goes on until reached ---
	If $g_i_ZS_MoveUntil > $g_i_ZS_Now Then
		If ZS_Pos_Dist($l_f_MX, $l_f_MY, $g_f_ZS_MoveX, $g_f_ZS_MoveY) > 80 Then
			ZS_Pos_Offer($g_f_ZS_MoveX, $g_f_ZS_MoveY, $g_i_ZS_MoveBand, $g_f_ZS_MoveU + 0.05, "keep moving: " & $g_s_ZS_MoveWhy)
			Return
		EndIf
		$g_i_ZS_MoveUntil = 0
	EndIf

	; --- 2) a ranged fighter or caster steps back from melee foes ---
	ZS_Pos_BackOff()

	; --- 3) a resurrecting urn: to the dead ally ---
	ZS_Pos_ToDeadAlly()
EndFunc   ;==>ZS_Eval_Position

;~ Description: Offer a move to ($a_f_X, $a_f_Y).
Func ZS_Pos_Offer($a_f_X, $a_f_Y, $a_i_Band, $a_f_U, $a_s_Why)
	$g_i_ZS_CandidateCount += 1
	ZS_Eval_Offer($GC_ZS_ACT_MOVE, 0, $g_i_ZS_MyID, $a_i_Band, $a_f_U, $a_s_Why, $a_f_X, $a_f_Y)
EndFunc   ;==>ZS_Pos_Offer

;~ Description: Angle of the vector (x, y) in radians (AutoIt has no ATan2).
Func ZS_Pos_ATan2($a_f_Y, $a_f_X)
	If $a_f_X > 0 Then Return ATan($a_f_Y / $a_f_X)
	If $a_f_X < 0 Then Return ATan($a_f_Y / $a_f_X) + ($a_f_Y >= 0 ? 3.14159265359 : -3.14159265359)
	If $a_f_Y > 0 Then Return 1.5707963268
	If $a_f_Y < 0 Then Return -1.5707963268
	Return 0
EndFunc   ;==>ZS_Pos_ATan2

Func ZS_Pos_Dist($a_f_X1, $a_f_Y1, $a_f_X2, $a_f_Y2)
	Return Sqrt(($a_f_X1 - $a_f_X2) ^ 2 + ($a_f_Y1 - $a_f_Y2) ^ 2)
EndFunc   ;==>ZS_Pos_Dist

;~ Description: Average position of the living allies in reach (player excluded). False when there is none.
Func ZS_Pos_PartyCentre(ByRef $a_f_X, ByRef $a_f_Y)
	If $g_ai_ZS_Allies[0] = 0 Then Return False
	$a_f_X = 0
	$a_f_Y = 0
	For $i = 1 To $g_ai_ZS_Allies[0]
		$a_f_X += $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_X]
		$a_f_Y += $g_amx2_ZS_Agent[$g_ai_ZS_Allies[$i]][$GC_ZS_A_Y]
	Next
	$a_f_X /= $g_ai_ZS_Allies[0]
	$a_f_Y /= $g_ai_ZS_Allies[0]
	Return True
EndFunc   ;==>ZS_Pos_PartyCentre

;~ Description: A point out of area $a_i_H: straight away from its centre first, else turning by 45° steps,
;~ the side of the party first. False when every direction ends in another area.
Func ZS_Pos_EscapeFrom($a_i_H, ByRef $a_f_X, ByRef $a_f_Y)
	Local $l_f_MX = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_X], $l_f_MY = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_Y]
	Local $l_f_CX = $g_amx2_ZS_Hazard[$a_i_H][$GC_ZS_HZ_X], $l_f_CY = $g_amx2_ZS_Hazard[$a_i_H][$GC_ZS_HZ_Y]
	Local $l_f_R = $g_amx2_ZS_Hazard[$a_i_H][$GC_ZS_HZ_R] + 150
	Local $l_f_Angle
	If ZS_Pos_Dist($l_f_MX, $l_f_MY, $l_f_CX, $l_f_CY) > 30 Then
		$l_f_Angle = ZS_Pos_ATan2($l_f_MY - $l_f_CY, $l_f_MX - $l_f_CX)
	Else
		; In the middle: towards the party, or away from the nearest foe
		Local $l_f_PX, $l_f_PY
		If ZS_Pos_PartyCentre($l_f_PX, $l_f_PY) And ZS_Pos_Dist($l_f_PX, $l_f_PY, $l_f_CX, $l_f_CY) > 30 Then
			$l_f_Angle = ZS_Pos_ATan2($l_f_PY - $l_f_CY, $l_f_PX - $l_f_CX)
		Else
			$l_f_Angle = 0
		EndIf
	EndIf
	; The side of the party first when turning
	Local $l_i_Side = 1, $l_f_PX2, $l_f_PY2
	If ZS_Pos_PartyCentre($l_f_PX2, $l_f_PY2) Then
		Local $l_f_Cross = Cos($l_f_Angle) * ($l_f_PY2 - $l_f_CY) - Sin($l_f_Angle) * ($l_f_PX2 - $l_f_CX)
		If $l_f_Cross < 0 Then $l_i_Side = -1
	EndIf
	Local $l_af_Turns[7] = [0, 1, -1, 2, -2, 3, -3]
	Local $l_f_A, $l_f_X, $l_f_Y
	For $i = 0 To 6
		$l_f_A = $l_f_Angle + $l_i_Side * $l_af_Turns[$i] * 0.7853981634
		$l_f_X = $l_f_CX + $l_f_R * Cos($l_f_A)
		$l_f_Y = $l_f_CY + $l_f_R * Sin($l_f_A)
		If ZS_Hazard_At($l_f_X, $l_f_Y, 0, 0) >= 0 Then ContinueLoop
		$a_f_X = $l_f_X
		$a_f_Y = $l_f_Y
		Return True
	Next
	Return False
EndFunc   ;==>ZS_Pos_EscapeFrom

;~ Description: True when the player fights at range (bow, spear, wand or staff): it gains nothing in melee.
;~ The build decides first, not the weapon in hand: a dervish or an assassin holding a staff for its energy,
;~ or whose weapon is misread, is still a melee fighter.
Func ZS_Pos_Ranged()
	Local Const $l_i_Melee = BitOR($GC_I_SKILL_REQUIRE_AXE, $GC_I_SKILL_REQUIRE_DAGGER, $GC_I_SKILL_REQUIRE_HAMMER, _
			$GC_I_SKILL_REQUIRE_SCYTHE, $GC_I_SKILL_REQUIRE_SWORD)
	; Attack skills of a melee weapon on the bar
	For $l_i_Slot = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] = 0 Or $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Type] <> $GC_I_SKILL_TYPE_ATTACK Then ContinueLoop
		If BitAND($g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_WeaponReq], $l_i_Melee) Then Return False
	Next
	; The home weapon set is a melee weapon
	If $g_i_ZS_HomeSet > 0 And BitAND($g_amx2_ZS_WSet[$g_i_ZS_HomeSet][$GC_ZS_W_Bit], $l_i_Melee) Then Return False
	; A melee profession with nothing else to tell
	Switch $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_Primary]
		Case $GC_I_PROFESSION_WARRIOR, $GC_I_PROFESSION_ASSASSIN, $GC_I_PROFESSION_DERVISH
			Return False
	EndSwitch
	Switch $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_WeaponType]
		Case $GC_I_WEAPON_TYPE_AXE, $GC_I_WEAPON_TYPE_HAMMER, $GC_I_WEAPON_TYPE_DAGGERS, $GC_I_WEAPON_TYPE_SCYTHE, $GC_I_WEAPON_TYPE_SWORD
			Return False
	EndSwitch
	Return True
EndFunc   ;==>ZS_Pos_Ranged

;~ Description: One step back from the foes attacking the player in melee, towards the party.
Func ZS_Pos_BackOff()
	If Not ZS_Pos_Ranged() Then Return
	If MapExists($g_m_ZS_Recent, "backoff") And $g_m_ZS_Recent["backoff"] > $g_i_ZS_Now Then Return
	Local $l_i_Me = $g_i_ZS_MeIdx
	Local $l_f_Threat = ZS_Threat($l_i_Me)
	If $l_f_Threat < 0.3 Then Return
	Local $l_f_MX = $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_X], $l_f_MY = $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_Y]

	; The foes in melee with the player, and where they stand on average
	Local $l_i_N = 0, $l_f_FX = 0, $l_f_FY = 0, $l_i_F
	For $i = 1 To $g_ai_ZS_Foes[0]
		$l_i_F = $g_ai_ZS_Foes[$i]
		If $g_amx2_ZS_Agent[$l_i_F][$GC_ZS_A_Dist] > 250 Or Not ZS_Is($l_i_F, $GC_ZS_AF_ATTACKING) Then ContinueLoop
		$l_i_N += 1
		$l_f_FX += $g_amx2_ZS_Agent[$l_i_F][$GC_ZS_A_X]
		$l_f_FY += $g_amx2_ZS_Agent[$l_i_F][$GC_ZS_A_Y]
	Next
	If $l_i_N = 0 Then Return
	$l_f_FX /= $l_i_N
	$l_f_FY /= $l_i_N

	; Away from them, bent towards the party
	Local $l_f_AX = $l_f_MX - $l_f_FX, $l_f_AY = $l_f_MY - $l_f_FY, $l_f_Len = Sqrt($l_f_AX ^ 2 + $l_f_AY ^ 2)
	If $l_f_Len < 1 Then
		$l_f_AX = 1
		$l_f_AY = 0
	Else
		$l_f_AX /= $l_f_Len
		$l_f_AY /= $l_f_Len
	EndIf
	Local $l_f_PX, $l_f_PY
	If ZS_Pos_PartyCentre($l_f_PX, $l_f_PY) Then
		Local $l_f_TX = $l_f_PX - $l_f_MX, $l_f_TY = $l_f_PY - $l_f_MY, $l_f_TL = Sqrt($l_f_TX ^ 2 + $l_f_TY ^ 2)
		If $l_f_TL > 1 Then
			$l_f_AX = 0.7 * $l_f_AX + 0.3 * $l_f_TX / $l_f_TL
			$l_f_AY = 0.7 * $l_f_AY + 0.3 * $l_f_TY / $l_f_TL
			$l_f_Len = Sqrt($l_f_AX ^ 2 + $l_f_AY ^ 2)
			If $l_f_Len > 0 Then
				$l_f_AX /= $l_f_Len
				$l_f_AY /= $l_f_Len
			EndIf
		EndIf
	EndIf

	; Not into an area, and still in spell range of some foe (a shorter step otherwise)
	Local $l_af_Steps[2] = [$g_f_ZS_BackOffStep, $g_f_ZS_BackOffStep / 2]
	Local $l_f_X, $l_f_Y, $l_b_Found = False
	For $s = 0 To 1
		$l_f_X = $l_f_MX + $l_f_AX * $l_af_Steps[$s]
		$l_f_Y = $l_f_MY + $l_f_AY * $l_af_Steps[$s]
		If ZS_Hazard_At($l_f_X, $l_f_Y, 0) >= 0 Then ContinueLoop
		If Not ZS_Pos_FoeInRange($l_f_X, $l_f_Y, $GC_I_RANGE_SPELLCASTING - 100) Then ContinueLoop
		$l_b_Found = True
		ExitLoop
	Next
	If Not $l_b_Found Then Return

	Local $l_i_Band = ($l_f_Threat >= 0.8 ? $GC_ZS_BAND_HEAL : $GC_ZS_BAND_DAMAGE)
	ZS_Pos_Offer($l_f_X, $l_f_Y, $l_i_Band, 0.35 + 0.4 * $l_f_Threat, "step back from " & $l_i_N & " in melee, threat " & Round($l_f_Threat, 2))
EndFunc   ;==>ZS_Pos_BackOff

;~ Description: True when a living foe stands within $a_f_Range of the point.
Func ZS_Pos_FoeInRange($a_f_X, $a_f_Y, $a_f_Range)
	Return ZS_CountAround($a_f_X, $a_f_Y, $a_f_Range, True) > 0
EndFunc   ;==>ZS_Pos_FoeInRange

;~ Description: Holding an urn whose drop resurrects (Drop=DeadAlly) while the dead ally is out of its area: go to it.
Func ZS_Pos_ToDeadAlly()
	If $g_i_ZS_HeldUrn = 0 Or $g_ai_ZS_DeadAllies[0] = 0 Then Return
	Local $l_i_Slot = ZS_Eval_SlotOf($g_i_ZS_HeldUrn)
	If $l_i_Slot = 0 Or ZS_SlotParam($l_i_Slot, "Drop") <> "DeadAlly" Then Return
	Local $l_i_Best = 0, $l_f_Best = 1200, $l_f_D
	For $i = 1 To $g_ai_ZS_DeadAllies[0]
		$l_f_D = $g_amx2_ZS_Agent[$g_ai_ZS_DeadAllies[$i]][$GC_ZS_A_Dist]
		If $l_f_D <= $GC_I_RANGE_AREA Then Return ; one is already in the area: the drop does it
		If $l_f_D < $l_f_Best Then
			$l_f_Best = $l_f_D
			$l_i_Best = $g_ai_ZS_DeadAllies[$i]
		EndIf
	Next
	If $l_i_Best = 0 Then Return
	Local $l_f_X = $g_amx2_ZS_Agent[$l_i_Best][$GC_ZS_A_X], $l_f_Y = $g_amx2_ZS_Agent[$l_i_Best][$GC_ZS_A_Y]
	If ZS_Hazard_At($l_f_X, $l_f_Y, 0) >= 0 Then Return
	ZS_Pos_Offer($l_f_X, $l_f_Y, $GC_ZS_BAND_RESURRECT, 0.5, "urn: to the dead ally " & Round($l_f_Best))
EndFunc   ;==>ZS_Pos_ToDeadAlly
#EndRegion Moves
