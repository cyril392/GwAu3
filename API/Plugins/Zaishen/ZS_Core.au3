#include-once

; Zaishen public entry points.
;   ZS_Fight(x, y)   fight until the combat is over (drop-in for a bot main loop)
;   ZS_Tick()        one perceive -> evaluate -> execute step, for bots that own their loop
; Nothing has to be called when the zone or the skill bar changes: the perception notices both.

#Region Public
;~ Description: One step of the AI. Returns a $GC_ZS_TICK_* status.
Func ZS_Tick($a_f_AggroRange = 1320)
	Local $l_h_Timer = TimerInit()

	If Not ZS_Perceive($a_f_AggroRange) Then
		ZS_Exec_Reset()
		Return $GC_ZS_TICK_NOTREADY
	EndIf
	If ZS_Is($g_i_ZS_MeIdx, $GC_ZS_AF_DEAD) Then
		ZS_Exec_Reset()
		Return $GC_ZS_TICK_DOWN
	EndIf

	; Deciding only makes sense when a new action can start
	If $g_i_ZS_State = $GC_ZS_ST_IDLE Then
		ZS_Evaluate()
	Else
		$g_av_ZS_Decision[$GC_ZS_D_Action] = $GC_ZS_ACT_NONE
	EndIf
	ZS_Execute()

	Local $l_f_Ms = TimerDiff($l_h_Timer)
	$g_i_ZS_StatTicks += 1
	$g_f_ZS_StatTickMsSum += $l_f_Ms
	If $l_f_Ms > $g_f_ZS_StatTickMsMax Then $g_f_ZS_StatTickMsMax = $l_f_Ms

	If $g_b_ZS_InCombat Or $g_i_ZS_State <> $GC_ZS_ST_IDLE Then Return $GC_ZS_TICK_FIGHTING
	Return $GC_ZS_TICK_NOFOE
EndFunc   ;==>ZS_Tick

;~ Description: Fight around ($a_f_X, $a_f_Y) until no foe is left, the player is down, the map changes,
;~ the player is farther than $a_f_MaxDistance from the point (0 = no limit), or $a_s_ExitCallback returns True.
;~ Out of combat it makes one tick and returns: called in a bot loop, it also resurrects, heals and speeds the
;~ player up between fights. An action under way is always finished before it returns.
;~ Returns True when the fight ended with the player alive.
Func ZS_Fight($a_f_X, $a_f_Y, $a_f_AggroRange = 1320, $a_f_MaxDistance = 3500, $a_s_ExitCallback = "")
	Local $l_i_Map = Map_GetMapID()
	Local $l_i_Status, $l_f_DX, $l_f_DY

	While True
		$l_i_Status = ZS_Tick($a_f_AggroRange)
		If $l_i_Status = $GC_ZS_TICK_NOTREADY Then Return False
		If $l_i_Status = $GC_ZS_TICK_DOWN Then Return False
		If $l_i_Status = $GC_ZS_TICK_NOFOE Then Return True
		If Map_GetMapID() <> $l_i_Map Then Return False
		; An action under way (a resurrection out of combat, a cast...) is finished before the bot moves again
		If $g_i_ZS_State <> $GC_ZS_ST_IDLE Then
			Sleep($g_i_ZS_TickSleep)
			ContinueLoop
		EndIf

		If $a_f_MaxDistance > 0 Then
			$l_f_DX = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_X] - $a_f_X
			$l_f_DY = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_Y] - $a_f_Y
			If $l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY > $a_f_MaxDistance * $a_f_MaxDistance Then Return True
		EndIf
		If $a_s_ExitCallback <> "" And Call($a_s_ExitCallback) Then Return True

		Sleep($g_i_ZS_TickSleep)
	WEnd
EndFunc   ;==>ZS_Fight

;~ Description: Forget everything remembered between ticks. Not required: provided for a clean restart of a bot.
Func ZS_Reset()
	ZS_Perception_ForgetTracking()
	ZS_Exec_Reset()
	ZS_Weapon_Reset()
	For $l_i_Slot = 1 To 8
		$g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] = 0
	Next
EndFunc   ;==>ZS_Reset

;~ Description: One line summary of the session counters.
Func ZS_Stats()
	Local $l_f_Avg = ($g_i_ZS_StatTicks > 0 ? $g_f_ZS_StatTickMsSum / $g_i_ZS_StatTicks : 0)
	Return "ticks " & $g_i_ZS_StatTicks & ", avg " & Round($l_f_Avg, 1) & " ms, max " & Round($g_f_ZS_StatTickMsMax, 1) & " ms, casts " & _
			$g_i_ZS_StatCasts & ", cancelled " & $g_i_ZS_StatCancelled & ", timeouts " & $g_i_ZS_StatTimeouts & ", weapon switches " & $g_i_ZS_StatSwitches & ", moves " & $g_i_ZS_StatMoves
EndFunc   ;==>ZS_Stats
#EndRegion Public

#Region Problems file
;~ Description: Note a problem of a skill in the problems file ($g_s_ZS_IssueFile): the first time, then every 10 times.
Func ZS_Issue($a_i_SkillID, $a_s_Problem, $a_s_Detail = "")
	Local $l_s_Key = $a_i_SkillID & "|" & $a_s_Problem
	Local $l_i_N = (MapExists($g_m_ZS_IssueCount, $l_s_Key) ? $g_m_ZS_IssueCount[$l_s_Key] : 0) + 1
	$g_m_ZS_IssueCount[$l_s_Key] = $l_i_N
	If $l_i_N <> 1 And Mod($l_i_N, 10) <> 0 Then Return
	ZS_Log_Event("PROBLEM " & ZS_SkillName($a_i_SkillID) & ": " & $a_s_Problem & ($a_s_Detail = "" ? "" : " - " & $a_s_Detail))
	If $g_s_ZS_IssueFile = "" Then Return
	Local $l_s_Map = ($g_h_GWProcess <> 0 ? Map_GetMapID() : 0)
	Local $l_h = FileOpen($g_s_ZS_IssueFile, 1 + 8)
	If $l_h = -1 Then Return
	FileWriteLine($l_h, @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & " | " & $g_s_ZS_IssueTag & " | map " & $l_s_Map & _
			" | " & ZS_SkillName($a_i_SkillID) & " (" & $a_i_SkillID & ") | " & $a_s_Problem & ($l_i_N > 1 ? " (x" & $l_i_N & ")" : "") & _
			($a_s_Detail = "" ? "" : " | " & $a_s_Detail))
	FileClose($l_h)
EndFunc   ;==>ZS_Issue

;~ Description: Follow a slot during fights: ready (recharged, resources there) but never offered as a candidate for
;~ $g_i_ZS_IdleAlertMs of combat = reported once, with why. $a_b_Offered: it was a candidate this tick;
;~ $a_s_Veto: the resource veto of the tick ("" = none).
Func ZS_Issue_TrackSlot($a_i_Slot, $a_b_Offered, $a_s_Veto, $a_i_Dt)
	Local $l_i_SkillID = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID]
	If $g_ai_ZS_SlotIdleSkill[$a_i_Slot] <> $l_i_SkillID Then
		$g_ai_ZS_SlotIdleSkill[$a_i_Slot] = $l_i_SkillID
		$g_ai_ZS_SlotIdleMs[$a_i_Slot] = 0
	EndIf
	If $a_b_Offered Or Not $g_b_ZS_InCombat Or $g_ai_ZS_Foes[0] = 0 Then
		If $a_b_Offered Then $g_ai_ZS_SlotIdleMs[$a_i_Slot] = 0
		Return
	EndIf
	; Waiting for its resources is normal
	Switch $a_s_Veto
		Case "recharge", "adrenaline", "energy", "sacrifice", "overcast", "maintained limit", "no energy regeneration"
			Return
	EndSwitch
	; Skills that wait for an occasion by nature
	If $g_i_ZS_IdleAlertMs <= 0 Then Return
	Switch $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Family]
		Case $GC_ZS_FAM_NONE, $GC_ZS_FAM_RESURRECT, $GC_ZS_FAM_HEAL_SINGLE, $GC_ZS_FAM_HEAL_SELF, $GC_ZS_FAM_HEAL_PARTY, _
				$GC_ZS_FAM_PROTECT, $GC_ZS_FAM_HEX_REMOVAL, $GC_ZS_FAM_COND_REMOVAL, $GC_ZS_FAM_INTERRUPT, $GC_ZS_FAM_ITEM_SPELL, _
				$GC_ZS_FAM_CORPSE, $GC_ZS_FAM_ENCH_REMOVAL
			Return
	EndSwitch
	If ZS_Eval_IsDefensive($a_i_Slot) Then Return
	; Still up on the player: nothing to do
	If ZS_SelfHasFx($l_i_SkillID) Then Return

	$g_ai_ZS_SlotIdleMs[$a_i_Slot] += $a_i_Dt
	If $g_ai_ZS_SlotIdleMs[$a_i_Slot] >= $g_i_ZS_IdleAlertMs Then
		; Why, as things stand now (only worked out when reporting: it costs)
		If $a_s_Veto <> "" Then
			$g_as_ZS_SlotIdleWhy[$a_i_Slot] = "blocked: " & $a_s_Veto
		Else
			Local $l_s_Req = ZS_Req_Slot($a_i_Slot)
			$g_as_ZS_SlotIdleWhy[$a_i_Slot] = ($l_s_Req <> "" ? $l_s_Req : "no target suits it" & _
					($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Params] = "" ? "" : " (" & $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Params] & ")"))
		EndIf
		ZS_Issue($l_i_SkillID, "ready but never chosen in " & Round($g_i_ZS_IdleAlertMs / 1000) & " s of fight", _
				$g_as_ZS_SlotIdleWhy[$a_i_Slot] & " [" & $GC_AS_ZS_FAMNAMES[$g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Family]] & "]")
		$g_ai_ZS_SlotIdleMs[$a_i_Slot] = 0
	EndIf
EndFunc   ;==>ZS_Issue_TrackSlot
#EndRegion Problems file

#Region Journal
Global $g_h_ZS_Log = -1
Global $g_s_ZS_LogOpened = ""

;~ Description: Text of one ranked candidate: band, utility, skill, target and the reasons.
Func ZS_Describe($a_i_Rank)
	If $a_i_Rank < 0 Or $a_i_Rank >= $g_i_ZS_TopCount Then Return ""
	Local $l_i_TargetID = $g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_TargetID]
	Local $l_i_Idx = ZS_IdxOf($l_i_TargetID)
	Local $l_s_Target = ($l_i_TargetID = $g_i_ZS_MyID ? "self" : "#" & $l_i_TargetID)
	If $l_i_Idx > 0 And $l_i_TargetID <> $g_i_ZS_MyID Then $l_s_Target &= " (" & Round($g_amx2_ZS_Agent[$l_i_Idx][$GC_ZS_A_HP] * 100) & "%)"

	Local $l_s_What = "attack"
	If $g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Action] = $GC_ZS_ACT_DROP Then
		Local $l_i_DropSlot = $g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Slot]
		$l_s_What = "drop bundle s" & $l_i_DropSlot & " " & ZS_SkillName($g_amx2_ZS_Slot[$l_i_DropSlot][$GC_ZS_S_SkillID])
	ElseIf $g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Action] = $GC_ZS_ACT_ENDBUFF Then
		Local $l_i_EndSlot = $g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Slot]
		$l_s_What = "end s" & $l_i_EndSlot & " " & ZS_SkillName($g_amx2_ZS_Slot[$l_i_EndSlot][$GC_ZS_S_SkillID])
	ElseIf $g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Action] = $GC_ZS_ACT_MOVE Then
		$l_s_What = "move to " & Round($g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_X]) & "," & Round($g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Y])
	ElseIf $g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Action] = $GC_ZS_ACT_SKILL Then
		Local $l_i_Slot = $g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Slot]
		$l_s_What = "s" & $l_i_Slot & " " & ZS_SkillName($g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID]) & _
				" [" & $GC_AS_ZS_FAMNAMES[$g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Family]] & "]"
	EndIf
	Local $l_s_Line = $GC_AS_ZS_BANDNAMES[$g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Band]] & " " & Round($g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Utility], 2) & _
			" " & $l_s_What & " -> " & $l_s_Target
	If $g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Why] <> "" Then $l_s_Line &= " {" & StringStripWS($g_amx2_ZS_Top[$a_i_Rank][$GC_ZS_D_Why], 3) & "}"
	Return $l_s_Line
EndFunc   ;==>ZS_Describe

;~ Description: Journal line for the action being started: the winner, then the runners-up.
Func ZS_Log_Decision()
	If $g_s_ZS_LogFile = "" Then Return
	Local $l_s_Line = ZS_Describe(0)
	For $i = 1 To $g_i_ZS_TopCount - 1
		$l_s_Line &= "  |  " & ZS_Describe($i)
	Next
	ZS_Log_Write("DO " & $l_s_Line & "  (" & $g_i_ZS_CandidateCount & " candidates, energy " & Round($g_f_ZS_Energy) & ")")
EndFunc   ;==>ZS_Log_Decision

Func ZS_Log_Event($a_s_Text)
	If $g_s_ZS_LogFile = "" Then Return
	ZS_Log_Write("-- " & $a_s_Text)
EndFunc   ;==>ZS_Log_Event

Func ZS_Log_Write($a_s_Text)
	If $g_s_ZS_LogOpened <> $g_s_ZS_LogFile Then
		If $g_h_ZS_Log <> -1 Then FileClose($g_h_ZS_Log)
		$g_h_ZS_Log = FileOpen($g_s_ZS_LogFile, 1 + 8) ; append, create the folders
		$g_s_ZS_LogOpened = $g_s_ZS_LogFile
	EndIf
	If $g_h_ZS_Log = -1 Then Return
	FileWriteLine($g_h_ZS_Log, "[" & $g_i_ZS_Now & "] " & $a_s_Text)
EndFunc   ;==>ZS_Log_Write
#EndRegion Journal
