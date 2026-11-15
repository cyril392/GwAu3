#include-once

; Zaishen execution: a state machine advanced by ONE step per tick. Nothing here waits or sleeps.
;   Idle -> WaitCast (command sent) -> Casting (activation seen) -> Aftercast -> Idle
; An instant skill goes WaitCast -> Aftercast as soon as its recharge (or adrenaline) shows it went off.

#Region Commands (the only functions that act on the game)
Func ZS_Cmd_UseSkill($a_i_Slot, $a_i_TargetID)
	$g_s_ZS_LastCommand = "UseSkill " & $a_i_Slot & " -> " & $a_i_TargetID
	If $g_b_ZS_DryRun Then Return
	Skill_UseSkill($a_i_Slot, $a_i_TargetID)
EndFunc   ;==>ZS_Cmd_UseSkill

Func ZS_Cmd_Attack($a_i_TargetID)
	$g_s_ZS_LastCommand = "Attack -> " & $a_i_TargetID
	If $g_b_ZS_DryRun Then Return
	Agent_Attack($a_i_TargetID, False)
EndFunc   ;==>ZS_Cmd_Attack

Func ZS_Cmd_DropBundle()
	$g_s_ZS_LastCommand = "DropBundle"
	If $g_b_ZS_DryRun Then Return
	Item_DropBundle()
EndFunc   ;==>ZS_Cmd_DropBundle

;~ Description: End an enchantment the player keeps up (drops its bond).
Func ZS_Cmd_EndBuff($a_i_SkillID)
	$g_s_ZS_LastCommand = "EndBuff " & $a_i_SkillID
	If $g_b_ZS_DryRun Then Return
	Effect_DropBond($a_i_SkillID, -2, 0)
EndFunc   ;==>ZS_Cmd_EndBuff

;~ Description: Hold weapon set $a_i_Set (1..4). Queued by the game like any action.
Func ZS_Cmd_SwitchSet($a_i_Set)
	$g_s_ZS_LastCommand = "SwitchSet " & $a_i_Set
	If $g_b_ZS_DryRun Then Return
	Core_PerformAction($GC_I_CONTROL_INVENTORY_ACTIVATE_WEAPON_SET_1 + $a_i_Set - 1, $GC_I_CONTROL_TYPE_ACTIVATE)
EndFunc   ;==>ZS_Cmd_SwitchSet

Func ZS_Cmd_Move($a_f_X, $a_f_Y)
	$g_s_ZS_LastCommand = "Move " & Round($a_f_X) & "," & Round($a_f_Y)
	If $g_b_ZS_DryRun Then Return
	Map_Move($a_f_X, $a_f_Y, 0)
EndFunc   ;==>ZS_Cmd_Move

Func ZS_Cmd_Cancel()
	$g_s_ZS_LastCommand = "Cancel"
	If $g_b_ZS_DryRun Then Return
	Core_ControlAction($GC_I_CONTROL_ACTION_CANCEL_ACTION)
EndFunc   ;==>ZS_Cmd_Cancel
#EndRegion Commands

#Region State machine
Func ZS_Exec_SetState($a_i_State)
	$g_i_ZS_State = $a_i_State
	$g_i_ZS_StateSince = $g_i_ZS_Now
EndFunc   ;==>ZS_Exec_SetState

;~ Description: Back to Idle and forget the running action (death, new instance, tests).
Func ZS_Exec_Reset()
	$g_i_ZS_State = $GC_ZS_ST_IDLE
	$g_i_ZS_StateSince = $g_i_ZS_Now
	$g_i_ZS_ExecSlot = 0
	$g_i_ZS_ExecSkill = 0
	$g_i_ZS_ExecTarget = 0
	$g_b_ZS_ExecIsRez = False
EndFunc   ;==>ZS_Exec_Reset

;~ Description: True when the target of the running action can no longer receive it.
Func ZS_Exec_TargetLost()
	Local $l_i_Idx = ZS_IdxOf($g_i_ZS_ExecTarget)
	If $l_i_Idx = 0 Then Return True
	Local $l_b_Dead = ZS_Is($l_i_Idx, $GC_ZS_AF_DEAD)
	If $g_b_ZS_ExecIsRez Then Return Not $l_b_Dead
	Return $l_b_Dead
EndFunc   ;==>ZS_Exec_TargetLost

;~ Description: The game did not start the skill of the slot. Twice in a row: something forbids it (disabled by a
;~ foe skill, a condition Zaishen does not see...): set aside $g_i_ZS_NoCastPause ms instead of trying again and again.
;~ The journal gets the bar's "disabled" field read from the game, to find out the cause.
Func ZS_Exec_NoteNoCast($a_i_Slot)
	Local $l_i_SkillID = $g_i_ZS_ExecSkill
	Local $l_i_N = (MapExists($g_m_ZS_NoCast, $l_i_SkillID) ? $g_m_ZS_NoCast[$l_i_SkillID] : 0) + 1
	$g_m_ZS_NoCast[$l_i_SkillID] = $l_i_N
	ZS_Issue($l_i_SkillID, "the game did not start it", "slot " & $a_i_Slot & ", energy " & Round($g_f_ZS_Energy) & _
			($g_h_GWProcess <> 0 And Not $g_b_ZS_DryRun ? ", bar disabled field 0x" & Hex(Skill_GetSkillbarInfo($a_i_Slot, "Disabled"), 8) : ""))
	If $l_i_N >= 2 Then
		$g_m_ZS_Recent["skill:" & $l_i_SkillID] = $g_i_ZS_Now + $g_i_ZS_NoCastPause
		ZS_Log_Event(ZS_SkillName($l_i_SkillID) & " not started " & $l_i_N & " times in a row: set aside " & Round($g_i_ZS_NoCastPause / 1000) & " s")
	EndIf
EndFunc   ;==>ZS_Exec_NoteNoCast

;~ Description: Give up the running action; the pair may be tried again shortly.
Func ZS_Exec_Abort($a_s_Reason, $a_b_SendCancel)
	If $a_b_SendCancel Then ZS_Cmd_Cancel()
	$g_m_ZS_Recent[$g_i_ZS_ExecSkill & ":" & $g_i_ZS_ExecTarget] = $g_i_ZS_Now + 500
	ZS_Log_Event($a_s_Reason & " " & ZS_SkillName($g_i_ZS_ExecSkill) & " -> " & $g_i_ZS_ExecTarget)
	ZS_Exec_Reset()
EndFunc   ;==>ZS_Exec_Abort

;~ Description: Advance the running action by one step, or start the action of $g_av_ZS_Decision when idle.
Func ZS_Execute()
	Local $l_i_Me = $g_i_ZS_MeIdx
	If $l_i_Me = 0 Then Return
	Local $l_i_MySkill = $g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_Skill]
	Local $l_i_Elapsed = $g_i_ZS_Now - $g_i_ZS_StateSince
	Local $l_i_Slot = $g_i_ZS_ExecSlot

	Switch $g_i_ZS_State
		Case $GC_ZS_ST_WAITCAST
			If ZS_Is($l_i_Me, $GC_ZS_AF_DEAD + $GC_ZS_AF_KNOCKED) Then Return ZS_Exec_Reset()
			If ZS_Exec_TargetLost() Then
				$g_i_ZS_StatCancelled += 1
				Return ZS_Exec_Abort("target lost before cast:", True)
			EndIf
			If $l_i_MySkill = $g_i_ZS_ExecSkill Then
				If MapExists($g_m_ZS_NoCast, $g_i_ZS_ExecSkill) Then MapRemove($g_m_ZS_NoCast, $g_i_ZS_ExecSkill)
				Return ZS_Exec_SetState($GC_ZS_ST_CASTING)
			EndIf
			; No activation seen but the skill is spent: it was instant
			Local $l_b_Spent = Not $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Recharged]
			If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_AdrenReq] > 0 Then $l_b_Spent = ($g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Adrenaline] < $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_AdrenReq])
			If $l_b_Spent And $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] = $g_i_ZS_ExecSkill Then
				If MapExists($g_m_ZS_NoCast, $g_i_ZS_ExecSkill) Then MapRemove($g_m_ZS_NoCast, $g_i_ZS_ExecSkill)
				$g_i_ZS_StatCasts += 1
				Return ZS_Exec_SetState($GC_ZS_ST_AFTERCAST)
			EndIf
			If $l_i_Elapsed > $g_i_ZS_ExecTimeout Then
				; Still walking to the target (a range shorter than thought, a foe that moved): the game will cast on arrival
				If ZS_Is($l_i_Me, $GC_ZS_AF_MOVING) And $l_i_Elapsed <= $g_i_ZS_ExecTimeout + 4000 Then Return
				$g_i_ZS_StatTimeouts += 1
				ZS_Exec_NoteNoCast($l_i_Slot)
				Return ZS_Exec_Abort("no cast after " & $l_i_Elapsed & " ms:", False)
			EndIf
			Return

		Case $GC_ZS_ST_CASTING
			If ZS_Is($l_i_Me, $GC_ZS_AF_DEAD + $GC_ZS_AF_KNOCKED) Then Return ZS_Exec_Reset()
			If $l_i_MySkill <> $g_i_ZS_ExecSkill Then
				$g_i_ZS_StatCasts += 1
				Return ZS_Exec_SetState($GC_ZS_ST_AFTERCAST)
			EndIf
			If ZS_Exec_TargetLost() Then
				$g_i_ZS_StatCancelled += 1
				Return ZS_Exec_Abort("target lost, cancelled:", True)
			EndIf
			Return

		Case $GC_ZS_ST_AFTERCAST
			; The next command may leave one ping before the aftercast ends: the game queues it
			Local $l_i_Wait = 0
			If $l_i_Slot >= 1 And $l_i_Slot <= 8 Then $l_i_Wait = $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_AftercastMs] - $g_i_ZS_Ping
			If $l_i_Elapsed >= $l_i_Wait Then ZS_Exec_Reset()
			Return
	EndSwitch

	; --- Idle: start what was decided ---
	; The right weapon set first; the decision is taken again once it is in hand
	If ZS_Exec_NeedSwitch() Then Return
	Switch $g_av_ZS_Decision[$GC_ZS_D_Action]
		Case $GC_ZS_ACT_SKILL
			ZS_Exec_StartSkill($g_av_ZS_Decision[$GC_ZS_D_Slot], $g_av_ZS_Decision[$GC_ZS_D_TargetID])
		Case $GC_ZS_ACT_ATTACK
			ZS_Exec_StartAttack($g_av_ZS_Decision[$GC_ZS_D_TargetID])
		Case $GC_ZS_ACT_DROP
			; Instant: stays Idle, and is not offered again until the game shows the bundle gone
			$g_m_ZS_Recent["drop"] = $g_i_ZS_Now + 1000 + $g_i_ZS_Ping
			ZS_Log_Decision()
			ZS_Cmd_DropBundle()
		Case $GC_ZS_ACT_ENDBUFF
			$g_m_ZS_Recent["endbuff"] = $g_i_ZS_Now + 1500 + $g_i_ZS_Ping
			ZS_Log_Decision()
			ZS_Cmd_EndBuff($g_amx2_ZS_Slot[$g_av_ZS_Decision[$GC_ZS_D_Slot]][$GC_ZS_S_SkillID])
		Case $GC_ZS_ACT_MOVE
			ZS_Exec_Move()
	EndSwitch
EndFunc   ;==>ZS_Execute

;~ Description: Walk to the destination of the decision. Stays Idle: the move goes on by itself, and is offered
;~ again each tick until reached (ZS_Eval_Position), so the order is only sent again when it changed or got lost.
Func ZS_Exec_Move()
	Local $l_f_X = $g_av_ZS_Decision[$GC_ZS_D_X], $l_f_Y = $g_av_ZS_Decision[$GC_ZS_D_Y]
	Local $l_b_Same = ($g_i_ZS_MoveUntil > $g_i_ZS_Now And ZS_Pos_Dist($l_f_X, $l_f_Y, $g_f_ZS_MoveX, $g_f_ZS_MoveY) < 60)
	If $l_b_Same And $g_i_ZS_Now - $g_i_ZS_MoveSentAt < 1000 Then Return
	If Not $l_b_Same Then
		; A new move: until when it may take, then the step back cooldown
		Local $l_f_Dist = ZS_Pos_Dist($l_f_X, $l_f_Y, $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_X], $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_Y])
		Local $l_i_Ms = Int($l_f_Dist / $g_f_ZS_WalkSpeed) + 800
		If $l_i_Ms > 5000 Then $l_i_Ms = 5000
		$g_f_ZS_MoveX = $l_f_X
		$g_f_ZS_MoveY = $l_f_Y
		$g_i_ZS_MoveUntil = $g_i_ZS_Now + $l_i_Ms
		$g_i_ZS_MoveBand = $g_av_ZS_Decision[$GC_ZS_D_Band]
		$g_f_ZS_MoveU = $g_av_ZS_Decision[$GC_ZS_D_Utility]
		$g_s_ZS_MoveWhy = StringRegExpReplace($g_av_ZS_Decision[$GC_ZS_D_Why], "^keep moving: ", "")
		If StringLeft($g_s_ZS_MoveWhy, 9) = "step back" Then $g_m_ZS_Recent["backoff"] = $g_i_ZS_Now + $l_i_Ms + $g_i_ZS_BackOffCooldown
		$g_i_ZS_StatMoves += 1
		ZS_Log_Decision()
	EndIf
	$g_i_ZS_MoveSentAt = $g_i_ZS_Now
	ZS_Cmd_Move($l_f_X, $l_f_Y)
EndFunc   ;==>ZS_Exec_Move

;~ Description: True when the decided action waits for a weapon set (switch sent now, or on its way).
;~ In dry run the switch is only written in the journal and the action goes on.
Func ZS_Exec_NeedSwitch()
	Local $l_i_Set = 0
	Switch $g_av_ZS_Decision[$GC_ZS_D_Action]
		Case $GC_ZS_ACT_SKILL
			Local $l_i_Idx = ZS_IdxOf($g_av_ZS_Decision[$GC_ZS_D_TargetID])
			$l_i_Set = ZS_Weapon_ForSkill($g_av_ZS_Decision[$GC_ZS_D_Slot], $l_i_Idx <> $g_i_ZS_MeIdx)
		Case $GC_ZS_ACT_ATTACK
			$l_i_Set = ZS_Weapon_ForAttack()
	EndSwitch
	If $l_i_Set = 0 Or $l_i_Set = $g_i_ZS_ActiveSet Then Return False
	If $g_i_ZS_SwitchTo = $l_i_Set Then Return Not $g_b_ZS_DryRun ; sent, not in hand yet
	ZS_Log_Event("weapon set " & $g_i_ZS_ActiveSet & " -> " & $l_i_Set & ": " & $g_s_ZS_WeaponWhy)
	ZS_Weapon_NoteSwitch($l_i_Set)
	ZS_Cmd_SwitchSet($l_i_Set)
	Return Not $g_b_ZS_DryRun
EndFunc   ;==>ZS_Exec_NeedSwitch

Func ZS_Exec_StartSkill($a_i_Slot, $a_i_TargetID)
	Local $l_i_Idx = ZS_IdxOf($a_i_TargetID)
	If $l_i_Idx = 0 Then Return
	Local $l_i_SkillID = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_SkillID]
	Local $l_i_Family = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Family]
	Local $l_i_Activation = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_ActivationMs]

	$g_i_ZS_ExecSlot = $a_i_Slot
	$g_i_ZS_ExecSkill = $l_i_SkillID
	$g_i_ZS_ExecTarget = $a_i_TargetID
	$g_b_ZS_ExecIsRez = ($l_i_Family = $GC_ZS_FAM_RESURRECT And $l_i_Idx <> $g_i_ZS_MeIdx)

	; How long the activation may take to show: latency, plus the walk to range.
	; An attack skill only goes off with the next swing of the weapon (up to 2 s for a bow).
	$g_i_ZS_ExecTimeout = ($l_i_Activation = 0 ? 500 : 1500) + 2 * $g_i_ZS_Ping
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ATTACK Then $g_i_ZS_ExecTimeout += 2000
	Local $l_f_Extra = $g_amx2_ZS_Agent[$l_i_Idx][$GC_ZS_A_Dist] - ZS_Eval_Range($a_i_Slot)
	If $l_i_Idx <> $g_i_ZS_MeIdx And $l_f_Extra > 0 Then
		Local $l_i_Walk = Int($l_f_Extra / 0.25) ; about 250 units per second
		If $l_i_Walk > 6000 Then $l_i_Walk = 6000
		$g_i_ZS_ExecTimeout += $l_i_Walk
	EndIf

	; Do not offer the same pair again before the game can show its result.
	; Where the result is not visible on the target, trust the duration of the skill instead (at the player's rank).
	; Not for traps (they are stacked) nor rituals (the spirit itself tells whether it still stands).
	Local $l_i_Quiet = $l_i_Activation + $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_AftercastMs] + $g_i_ZS_Ping + 1000
	Switch $l_i_Family
		Case $GC_ZS_FAM_HEX, $GC_ZS_FAM_WEAPON_SPELL, $GC_ZS_FAM_ALLY_BUFF, $GC_ZS_FAM_GENERIC_ALLY, $GC_ZS_FAM_PROTECT, _
				$GC_ZS_FAM_WARD
			Local $l_i_Duration = $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Duration]
			If $l_i_Duration > 120 Then $l_i_Duration = 120
			$l_i_Quiet += $l_i_Duration * 1000
	EndSwitch
	$g_m_ZS_Recent[$l_i_SkillID & ":" & $a_i_TargetID] = $g_i_ZS_Now + $l_i_Quiet

	If ZS_IsFoe($l_i_Idx) Then $g_i_ZS_LastFoeTarget = $a_i_TargetID

	; An urn: the item that will be in hand comes from this skill
	If $l_i_Family = $GC_ZS_FAM_ITEM_SPELL Then
		$g_i_ZS_LastUrnSkill = $l_i_SkillID
		$g_i_ZS_LastUrnAt = $g_i_ZS_Now
	EndIf

	; A ritual: the next new spirit next to the player is the one it creates
	If $l_i_Family = $GC_ZS_FAM_SPIRIT Then
		$g_i_ZS_PendingSpirit = $l_i_SkillID
		$g_i_ZS_PendingSpiritUntil = $g_i_ZS_Now + $l_i_Activation + 3000 + 2 * $g_i_ZS_Ping
	EndIf

	ZS_Log_Decision()
	ZS_Cmd_UseSkill($a_i_Slot, $a_i_TargetID)
	ZS_Exec_SetState($GC_ZS_ST_WAITCAST)
EndFunc   ;==>ZS_Exec_StartSkill

;~ Description: Auto attack. Stays Idle: a skill can replace it at the next tick.
Func ZS_Exec_StartAttack($a_i_TargetID)
	Local $l_b_Attacking = ZS_Is($g_i_ZS_MeIdx, $GC_ZS_AF_ATTACKING)
	If $a_i_TargetID = $g_i_ZS_AttackTarget Then
		If $l_b_Attacking Then Return
		If $g_i_ZS_Now - $g_i_ZS_AttackSince < 1500 Then Return ; walking to the target
	EndIf
	$g_i_ZS_AttackTarget = $a_i_TargetID
	$g_i_ZS_AttackSince = $g_i_ZS_Now
	$g_i_ZS_LastFoeTarget = $a_i_TargetID
	ZS_Log_Decision()
	ZS_Cmd_Attack($a_i_TargetID)
EndFunc   ;==>ZS_Exec_StartAttack
#EndRegion State machine
