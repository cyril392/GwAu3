; Zaishen offline test bench. Runs WITHOUT Guild Wars: it never calls Core_Initialize.
;
;   D:\AutoIt3\AutoIt3.exe /ErrorStdOut "API\Plugins\Zaishen\Tests\ZS_TestBench.au3"
;
; 1) classification checks      known skills land in the expected family
; 2) scenarios                  every Tests\Scenarios\*.zs snapshot is evaluated and compared to its E| lines
; 3) execution state machine    Idle -> WaitCast -> Casting -> Aftercast -> Idle, in dry run
; The report goes to Tests\last_report.txt and to the console; the exit code is the number of failures.

#include "..\..\..\_GwAu3.au3"
#include <File.au3>

Global $g_i_BenchPass = 0, $g_i_BenchFail = 0, $g_s_BenchReport = ""

$g_b_ZS_DryRun = True
$g_b_ZS_Explain = True

Bench_Classification()
Bench_DamageTracking()
Bench_Hazards()
Bench_Issues()
Bench_Scenarios()
Bench_StateMachine()
Bench_Speed()

Bench_Line("")
Bench_Line($g_i_BenchPass & " passed, " & $g_i_BenchFail & " failed")
Local $g_h_BenchOut = FileOpen(@ScriptDir & "\last_report.txt", 2)
FileWrite($g_h_BenchOut, $g_s_BenchReport)
FileClose($g_h_BenchOut)
Exit $g_i_BenchFail

Func Bench_Line($a_s_Text)
	$g_s_BenchReport &= $a_s_Text & @CRLF
	ConsoleWrite($a_s_Text & @CRLF)
EndFunc   ;==>Bench_Line

Func Bench_Check($a_b_OK, $a_s_Name, $a_s_Detail = "")
	If $a_b_OK Then
		$g_i_BenchPass += 1
		Bench_Line("  ok    " & $a_s_Name)
	Else
		$g_i_BenchFail += 1
		Bench_Line("  FAIL  " & $a_s_Name & ($a_s_Detail = "" ? "" : "  -> " & $a_s_Detail))
	EndIf
EndFunc   ;==>Bench_Check

#Region 1) classification
Func Bench_Classification()
	Bench_Line("== Classification ==")
	Local $l_amx2_Cases[34][2] = [ _
			[184, $GC_ZS_FAM_ENERGY_BUFF], _  ; Fire Attunement
			[181, $GC_ZS_FAM_ENERGY_BUFF], _  ; Ether Renewal
			[268, $GC_ZS_FAM_SELF_BUFF], _    ; Unyielding Aura (dedicated definition: ended to resurrect)
			[2537, $GC_ZS_FAM_ITEM_SPELL], _  ; Courageous Was Saidra
			[281, $GC_ZS_FAM_HEAL_SINGLE], _  ; Orison of Healing
			[287, $GC_ZS_FAM_HEAL_PARTY], _   ; Heal Party
			[1, $GC_ZS_FAM_HEAL_SELF], _      ; Healing Signet
			[446, $GC_ZS_FAM_HEAL_SELF], _    ; Troll Unguent
			[2, $GC_ZS_FAM_RESURRECT], _      ; Resurrection Signet
			[1481, $GC_ZS_FAM_RESURRECT], _   ; Death Pact Signet
			[5, $GC_ZS_FAM_INTERRUPT], _      ; Power Block
			[57, $GC_ZS_FAM_INTERRUPT], _     ; Cry of Frustration
			[426, $GC_ZS_FAM_INTERRUPT], _    ; Savage Shot (attack that interrupts)
			[301, $GC_ZS_FAM_HEX_REMOVAL], _  ; Remove Hex
			[22, $GC_ZS_FAM_HEX_REMOVAL], _   ; Inspired Hex
			[275, $GC_ZS_FAM_COND_REMOVAL], _ ; Mend Condition
			[245, $GC_ZS_FAM_PROTECT], _      ; Protective Spirit
			[257, $GC_ZS_FAM_PARTY_BUFF], _   ; Aegis
			[826, $GC_ZS_FAM_SELF_BUFF], _    ; Shadow Form
			[346, $GC_ZS_FAM_SELF_BUFF], _    ; Frenzy
			[28, $GC_ZS_FAM_HEX], _           ; Backfire
			[21, $GC_ZS_FAM_ENCH_REMOVAL], _  ; Inspired Enchantment (dedicated definition)
			[194, $GC_ZS_FAM_DAMAGE_AOE], _   ; Flare (the game data gives it an area)
			[186, $GC_ZS_FAM_DAMAGE_AOE], _   ; Fireball
			[183, $GC_ZS_FAM_PBAOE], _        ; Inferno
			[382, $GC_ZS_FAM_ATTACK], _       ; Sever Artery
			[782, $GC_ZS_FAM_ATTACK], _       ; Jagged Strike
			[792, $GC_ZS_FAM_WEAPON_SPELL], _ ; Splinter Weapon
			[1247, $GC_ZS_FAM_SPIRIT], _      ; Pain
			[85, $GC_ZS_FAM_CORPSE], _        ; Animate Bone Minions
			[92, $GC_ZS_FAM_CORPSE], _        ; Well of Blood
			[176, $GC_ZS_FAM_WARD], _         ; Ward Against Melee
			[458, $GC_ZS_FAM_TRAP], _         ; Barbed Trap
			[4, $GC_ZS_FAM_NONE]]             ; BAMPH (monster skill)

	Local $l_ai_Bar[8]
	For $i = 0 To UBound($l_amx2_Cases) - 1
		$l_ai_Bar[0] = $l_amx2_Cases[$i][0]
		ZS_Knowledge_ResolveBar($l_ai_Bar)
		Local $l_i_Got = $g_amx2_ZS_Slot[1][$GC_ZS_S_Family]
		Bench_Check($l_i_Got = $l_amx2_Cases[$i][1], ZS_SkillName($l_amx2_Cases[$i][0]) & " is " & $GC_AS_ZS_FAMNAMES[$l_amx2_Cases[$i][1]], _
				"got " & $GC_AS_ZS_FAMNAMES[$l_i_Got])
	Next
EndFunc   ;==>Bench_Classification
#EndRegion 1) classification

#Region 1b) damage tracking
;~ Description: The health loss rate follows real damage and fades once the damage stops.
Func Bench_DamageTracking()
	Bench_Line("")
	Bench_Line("== Damage tracking ==")
	ZS_Perception_ForgetTracking()
	Local $l_f_HP = 1, $l_f_Rate = 0
	; 1 s of losing 1 % every 100 ms (10 % per second), one reading per 100 ms tick
	For $i = 0 To 10
		$g_i_ZS_Now = 10000 + $i * 100
		$l_f_Rate = ZS_Perception_TrackDamage(42, $l_f_HP, False)
		$l_f_HP -= 0.01
	Next
	Bench_Check($l_f_Rate > 0.05 And $l_f_Rate < 0.11, "10 %/s for 1 s reads " & Round($l_f_Rate * 100, 1) & " %/s", "expected between 5 and 11")
	; then 2 s without damage
	For $i = 1 To 20
		$g_i_ZS_Now += 100
		$l_f_Rate = ZS_Perception_TrackDamage(42, $l_f_HP, False)
	Next
	Bench_Check($l_f_Rate < 0.02, "2 s without damage fades to " & Round($l_f_Rate * 100, 1) & " %/s", "expected under 2")
	; a heal is not a negative damage
	$g_i_ZS_Now += 100
	$l_f_Rate = ZS_Perception_TrackDamage(42, 1, False)
	Bench_Check($l_f_Rate >= 0 And $l_f_Rate < 0.02, "a heal does not count as damage")
	Bench_Check(ZS_Perception_TrackDamage(42, 0, True) = 0, "death resets the tracking")
EndFunc   ;==>Bench_DamageTracking
#EndRegion 1b) damage tracking

#Region 1c) damaging areas
;~ Description: A foe casting Fire Storm at the player: when the cast completes, an area appears where the player
;~ stood and the player walks out of it. An interrupted cast leaves nothing.
Func Bench_Hazards()
	Bench_Line("")
	Bench_Line("== Damaging areas (two ticks) ==")
	Local $l_s_File = @TempDir & "\zs_bench_hazard.zs"
	Local $l_h = FileOpen($l_s_File, 2)
	FileWrite($l_h, "M|now=1000|ping=80|myid=1|energy=30|maxenergy=40" & @CRLF & _
			"S|1|194" & @CRLF & _
			"A|1|0|0|0.9|480|0|ally|player|0|0|6|0|0|12" & @CRLF & _
			"A|10|700|0|1|0|0|foe|-|197|1500|6|0|0|0|0|0|-1|0" & @CRLF) ; Fire Storm, 1.5 s into its 2 s, facing the player
	FileClose($l_h)
	For $l_i_Case = 1 To 2
		ZS_Snapshot_Load($l_s_File)
		Bench_Check(MapExists($g_m_ZS_HazCast, 10), "cast " & $l_i_Case & ": Fire Storm at the player followed")
		; next tick: the cast is over (completed in case 1, cut by a knockdown in case 2)
		$g_i_ZS_Now += 600
		$g_amx2_ZS_Agent[2][$GC_ZS_A_Skill] = 0
		If $l_i_Case = 2 Then $g_amx2_ZS_Agent[2][$GC_ZS_A_Flags] = BitOR($g_amx2_ZS_Agent[2][$GC_ZS_A_Flags], $GC_ZS_AF_KNOCKED)
		ZS_Snapshot_Finalize()
		If $l_i_Case = 1 Then
			Bench_Check($g_i_ZS_HazardCount = 1 And ZS_Hazard_At(0, 0) >= 0, "completed cast leaves an area on the player", $g_i_ZS_HazardCount & " areas")
			ZS_Evaluate()
			Bench_Check($g_av_ZS_Decision[$GC_ZS_D_Action] = $GC_ZS_ACT_MOVE, "the player walks out of it", ZS_Describe(0))
		Else
			Bench_Check($g_i_ZS_HazardCount = 0, "interrupted cast leaves nothing", $g_i_ZS_HazardCount & " areas")
		EndIf
	Next

	; A foe well: centred on the corpse nearest the caster, not on the one of us it faces
	$l_h = FileOpen($l_s_File, 2)
	FileWrite($l_h, "M|now=1000|ping=80|myid=1|energy=30|maxenergy=40" & @CRLF & _
			"A|1|0|0|0.9|480|0|ally|player|0|0|4" & @CRLF & _
			"A|20|600|300|0|0|0|foe|dead,corpse" & @CRLF & _
			"A|10|700|0|1|0|0|foe|-|93|800|4|0|0|0|0|0|-1|0" & @CRLF) ; Well of Suffering, 0.8 s into its 1 s
	FileClose($l_h)
	ZS_Snapshot_Load($l_s_File)
	$g_i_ZS_Now += 400
	$g_amx2_ZS_Agent[ZS_IdxOf(10)][$GC_ZS_A_Skill] = 0
	ZS_Snapshot_Finalize()
	Bench_Check($g_i_ZS_HazardCount = 1 And ZS_Hazard_At(600, 300) >= 0 And ZS_Hazard_At(0, 0) < 0, _
			"a foe well is an area on its corpse", $g_i_ZS_HazardCount & " areas")
	FileDelete($l_s_File)
EndFunc   ;==>Bench_Hazards
#EndRegion 1c) damaging areas

#Region 1d) problems file
;~ Description: Backfire with only a warrior around for a minute of fight: reported as ready but never chosen.
Func Bench_Issues()
	Bench_Line("")
	Bench_Line("== Problems file ==")
	Local $l_s_Saved = $g_s_ZS_IssueFile
	$g_s_ZS_IssueFile = "" ; journal only, no file written by the bench
	ZS_Snapshot_Load(@ScriptDir & "\Scenarios\req_backfire_needs_caster.zs")
	Local $l_m_Empty[]
	$g_m_ZS_IssueCount = $l_m_Empty
	$g_i_ZS_LastEvalAt = $g_i_ZS_Now
	For $i = 1 To 125
		$g_i_ZS_Now += 500
		ZS_Evaluate()
	Next
	Local $l_b_Found = False
	For $l_s_Key In MapKeys($g_m_ZS_IssueCount)
		If StringLeft($l_s_Key, 3) = "28|" And StringInStr($l_s_Key, "never chosen") Then $l_b_Found = True
	Next
	Bench_Check($l_b_Found, "Backfire ready but never chosen for 60 s is reported")
	Local $l_b_Flare = False
	For $l_s_Key In MapKeys($g_m_ZS_IssueCount)
		If StringLeft($l_s_Key, 4) = "194|" Then $l_b_Flare = True
	Next
	Bench_Check(Not $l_b_Flare, "Flare (recharging all along) is not reported")
	$g_s_ZS_IssueFile = $l_s_Saved
EndFunc   ;==>Bench_Issues
#EndRegion 1d) problems file

#Region 2) scenarios
Func Bench_Scenarios()
	Bench_Line("")
	Bench_Line("== Scenarios ==")
	Local $l_as_Files = _FileListToArray(@ScriptDir & "\Scenarios", "*.zs", $FLTA_FILES)
	If @error Then
		Bench_Check(False, "scenario folder", "no *.zs file in Tests\Scenarios")
		Return
	EndIf
	For $i = 1 To $l_as_Files[0]
		Bench_RunScenario($l_as_Files[$i])
	Next
EndFunc   ;==>Bench_Scenarios

Func Bench_RunScenario($a_s_Name)
	If Not ZS_Snapshot_Load(@ScriptDir & "\Scenarios\" & $a_s_Name) Then
		Bench_Check(False, $a_s_Name, "cannot load, error " & @error)
		Return
	EndIf
	ZS_Evaluate()

	Local $l_s_Problems = ""
	For $i = 1 To $g_as_ZS_Expect[0]
		Local $l_as_Pairs = StringSplit($g_as_ZS_Expect[$i], "|", 2)
		For $j = 0 To UBound($l_as_Pairs) - 1
			Local $l_s_Problem = Bench_Expect(StringStripWS($l_as_Pairs[$j], 3))
			If $l_s_Problem <> "" Then $l_s_Problems &= $l_s_Problem & "; "
		Next
	Next
	If $g_as_ZS_Expect[0] = 0 Then $l_s_Problems = "no E| line in the scenario"

	Local $l_s_Did = ($g_i_ZS_TopCount > 0 ? ZS_Describe(0) : "nothing")
	Bench_Check($l_s_Problems = "", $a_s_Name & "  =>  " & $l_s_Did, $l_s_Problems)
	If $l_s_Problems <> "" Then
		For $i = 1 To $g_i_ZS_TopCount - 1
			Bench_Line("          #" & ($i + 1) & " " & ZS_Describe($i))
		Next
	EndIf
EndFunc   ;==>Bench_RunScenario

;~ Description: "" when the decision satisfies one "key=value" expectation, else what is wrong.
Func Bench_Expect($a_s_Pair)
	Local $l_i_Eq = StringInStr($a_s_Pair, "=")
	If $l_i_Eq < 2 Then Return ""
	Local $l_s_Key = StringLower(StringLeft($a_s_Pair, $l_i_Eq - 1)), $l_s_Value = StringMid($a_s_Pair, $l_i_Eq + 1)
	Local $l_i_Action = $g_av_ZS_Decision[$GC_ZS_D_Action]
	Switch $l_s_Key
		Case "action"
			Local $l_s_Is = "none"
			If $l_i_Action = $GC_ZS_ACT_SKILL Then $l_s_Is = "skill"
			If $l_i_Action = $GC_ZS_ACT_ATTACK Then $l_s_Is = "attack"
			If $l_i_Action = $GC_ZS_ACT_DROP Then $l_s_Is = "drop"
			If $l_i_Action = $GC_ZS_ACT_ENDBUFF Then $l_s_Is = "endbuff"
			If $l_i_Action = $GC_ZS_ACT_MOVE Then $l_s_Is = "move"
			If $l_s_Is <> StringLower($l_s_Value) Then Return "action is " & $l_s_Is & ", expected " & $l_s_Value
		Case "slot"
			If $l_i_Action = $GC_ZS_ACT_NONE Or $l_i_Action = $GC_ZS_ACT_ATTACK Or $g_av_ZS_Decision[$GC_ZS_D_Slot] <> Int($l_s_Value) Then Return "expected slot " & $l_s_Value
		Case "notslot"
			If $l_i_Action = $GC_ZS_ACT_SKILL And $g_av_ZS_Decision[$GC_ZS_D_Slot] = Int($l_s_Value) Then Return "slot " & $l_s_Value & " must not be used"
		Case "target"
			If $g_av_ZS_Decision[$GC_ZS_D_TargetID] <> Int($l_s_Value) Then Return "expected target " & $l_s_Value
		Case "targetin"
			If Not StringInStr("," & $l_s_Value & ",", "," & $g_av_ZS_Decision[$GC_ZS_D_TargetID] & ",") Then Return "expected a target among " & $l_s_Value
		Case "band"
			If $l_i_Action = $GC_ZS_ACT_NONE Or $GC_AS_ZS_BANDNAMES[$g_av_ZS_Decision[$GC_ZS_D_Band]] <> $l_s_Value Then Return "expected band " & $l_s_Value
		Case "movefrom", "moveto"
			; a move whose destination is farther from (movefrom) / nearer to (moveto) the point "x,y" than the player
			If $l_i_Action <> $GC_ZS_ACT_MOVE Then Return "expected a move"
			Local $l_as_XY = StringSplit($l_s_Value, ",", 2)
			Local $l_f_PX = Number($l_as_XY[0]), $l_f_PY = Number($l_as_XY[1])
			Local $l_f_Now = ZS_Pos_Dist($g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_X], $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_Y], $l_f_PX, $l_f_PY)
			Local $l_f_Then = ZS_Pos_Dist($g_av_ZS_Decision[$GC_ZS_D_X], $g_av_ZS_Decision[$GC_ZS_D_Y], $l_f_PX, $l_f_PY)
			If $l_s_Key = "movefrom" And $l_f_Then <= $l_f_Now Then Return "move does not go away from " & $l_s_Value
			If $l_s_Key = "moveto" And $l_f_Then >= $l_f_Now Then Return "move does not go towards " & $l_s_Value
		Case "wset"
			; weapon set the execution would switch to for this decision (0 = stays on the set in hand)
			Local $l_i_Want = 0
			If $l_i_Action = $GC_ZS_ACT_SKILL Then $l_i_Want = ZS_Weapon_ForSkill($g_av_ZS_Decision[$GC_ZS_D_Slot], ZS_IdxOf($g_av_ZS_Decision[$GC_ZS_D_TargetID]) <> $g_i_ZS_MeIdx)
			If $l_i_Action = $GC_ZS_ACT_ATTACK Then $l_i_Want = ZS_Weapon_ForAttack()
			If $l_i_Want <> Int($l_s_Value) Then Return "expected weapon set " & $l_s_Value & ", got " & $l_i_Want & " (" & $g_s_ZS_WeaponWhy & ")"
	EndSwitch
	Return ""
EndFunc   ;==>Bench_Expect
#EndRegion 2) scenarios

#Region 3) execution state machine
Func Bench_StateMachine()
	Bench_Line("")
	Bench_Line("== Execution state machine (dry run) ==")
	If Not ZS_Snapshot_Load(@ScriptDir & "\Scenarios\heal_lowest_ally.zs") Then
		Bench_Check(False, "state machine", "scenario heal_lowest_ally.zs missing")
		Return
	EndIf
	Local $l_i_Me = $g_i_ZS_MeIdx

	ZS_Evaluate()
	ZS_Execute()
	Bench_Check($g_i_ZS_State = $GC_ZS_ST_WAITCAST And $g_s_ZS_LastCommand = "UseSkill 1 -> 3", "idle: the decision is sent", _
			"state " & $GC_AS_ZS_STATENAMES[$g_i_ZS_State] & ", command '" & $g_s_ZS_LastCommand & "'")

	; Same pair is not offered again while the result is pending
	ZS_Evaluate()
	Bench_Check(Not ($g_av_ZS_Decision[$GC_ZS_D_Action] = $GC_ZS_ACT_SKILL And $g_av_ZS_Decision[$GC_ZS_D_Slot] = 1 And $g_av_ZS_Decision[$GC_ZS_D_TargetID] = 3), _
			"the pair just sent is not offered again")

	$g_i_ZS_Now += 100
	$g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_Skill] = $g_i_ZS_ExecSkill
	ZS_Execute()
	Bench_Check($g_i_ZS_State = $GC_ZS_ST_CASTING, "activation seen: casting", "state " & $GC_AS_ZS_STATENAMES[$g_i_ZS_State])

	$g_i_ZS_Now += 1000
	$g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_Skill] = 0
	ZS_Execute()
	Bench_Check($g_i_ZS_State = $GC_ZS_ST_AFTERCAST And $g_i_ZS_StatCasts = 1, "activation over: aftercast", "state " & $GC_AS_ZS_STATENAMES[$g_i_ZS_State])

	$g_i_ZS_Now += 100
	ZS_Execute()
	Bench_Check($g_i_ZS_State = $GC_ZS_ST_AFTERCAST, "aftercast is waited")
	$g_i_ZS_Now += 700
	ZS_Execute()
	Bench_Check($g_i_ZS_State = $GC_ZS_ST_IDLE, "aftercast over: idle", "state " & $GC_AS_ZS_STATENAMES[$g_i_ZS_State])

	; Target dies during the activation: the cast is cancelled
	ZS_Snapshot_Load(@ScriptDir & "\Scenarios\heal_lowest_ally.zs")
	$l_i_Me = $g_i_ZS_MeIdx
	ZS_Evaluate()
	ZS_Execute()
	$g_amx2_ZS_Agent[$l_i_Me][$GC_ZS_A_Skill] = $g_i_ZS_ExecSkill
	ZS_Execute()
	Local $l_i_Target = ZS_IdxOf(3)
	$g_amx2_ZS_Agent[$l_i_Target][$GC_ZS_A_Flags] = BitOR($g_amx2_ZS_Agent[$l_i_Target][$GC_ZS_A_Flags], $GC_ZS_AF_DEAD)
	ZS_Execute()
	Bench_Check($g_i_ZS_State = $GC_ZS_ST_IDLE And $g_s_ZS_LastCommand = "Cancel", "target dies while casting: cancelled", _
			"state " & $GC_AS_ZS_STATENAMES[$g_i_ZS_State] & ", command '" & $g_s_ZS_LastCommand & "'")

	; Command lost: back to idle after the timeout
	ZS_Snapshot_Load(@ScriptDir & "\Scenarios\heal_lowest_ally.zs")
	ZS_Evaluate()
	ZS_Execute()
	$g_i_ZS_Now += $g_i_ZS_ExecTimeout + 1
	ZS_Execute()
	Bench_Check($g_i_ZS_State = $GC_ZS_ST_IDLE, "no activation: gives up after the timeout", "state " & $GC_AS_ZS_STATENAMES[$g_i_ZS_State])

	; Ritual: the spirit that appears next to us right after the cast is bound to the skill
	ZS_Snapshot_Load(@ScriptDir & "\Scenarios\spirit_dead_recast.zs")
	ZS_Evaluate()
	ZS_Execute()
	Bench_Check($g_i_ZS_PendingSpirit = 1247, "ritual sent: waiting for its spirit", "pending " & $g_i_ZS_PendingSpirit)
	Local $l_i_N = $g_i_ZS_AgentCount + 1
	ReDim $g_amx2_ZS_Agent[$l_i_N + 1][$GC_ZS_A_COUNT]
	$g_i_ZS_AgentCount = $l_i_N
	$g_amx2_ZS_Agent[$l_i_N][$GC_ZS_A_ID] = 77
	$g_amx2_ZS_Agent[$l_i_N][$GC_ZS_A_X] = 60
	$g_amx2_ZS_Agent[$l_i_N][$GC_ZS_A_Y] = 40
	$g_amx2_ZS_Agent[$l_i_N][$GC_ZS_A_HP] = 1
	$g_amx2_ZS_Agent[$l_i_N][$GC_ZS_A_Allegiance] = $GC_I_ALLEGIANCE_SPIRIT
	$g_amx2_ZS_Agent[$l_i_N][$GC_ZS_A_Flags] = $GC_ZS_AF_SPAWNED
	$g_i_ZS_Now += 1200
	ZS_Snapshot_Finalize()
	Bench_Check(MapExists($g_m_ZS_SpiritOf, 1247) And $g_m_ZS_SpiritOf[1247] = 77 And $g_i_ZS_PendingSpirit = 0, _
			"the new spirit next to us is bound to the ritual")

	; Instant skill: no activation, the recharge shows it went off
	ZS_Snapshot_Load(@ScriptDir & "\Scenarios\buff_renew_expiring.zs")
	ZS_Evaluate()
	ZS_Execute()
	Local $l_i_Slot = $g_i_ZS_ExecSlot
	If $l_i_Slot >= 1 Then $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Recharged] = False
	$g_i_ZS_Now += 80
	ZS_Execute()
	Bench_Check($l_i_Slot >= 1 And $g_i_ZS_State = $GC_ZS_ST_AFTERCAST, "instant skill: recharge started means it went off", _
			"state " & $GC_AS_ZS_STATENAMES[$g_i_ZS_State])
EndFunc   ;==>Bench_StateMachine
#EndRegion 3) execution state machine

#Region 4) speed
;~ Description: Time of ZS_Evaluate on the biggest scenario (40 agents). Informative, plus a loose ceiling.
Func Bench_Speed()
	Bench_Line("")
	Bench_Line("== Speed ==")
	If Not ZS_Snapshot_Load(@ScriptDir & "\Scenarios\big_fight.zs") Then Return
	$g_b_ZS_Explain = False
	Local $l_h_Timer = TimerInit()
	For $i = 1 To 50
		ZS_Snapshot_Finalize() ; resets the per tick caches, as a real tick would
		ZS_Evaluate()
	Next
	Local $l_f_Ms = TimerDiff($l_h_Timer) / 50
	$g_b_ZS_Explain = True
	Bench_Check($l_f_Ms < 30, "evaluation of " & $g_i_ZS_AgentCount & " agents: " & Round($l_f_Ms, 2) & " ms per tick (" & $g_i_ZS_CandidateCount & " candidates)", _
			"over the 30 ms ceiling")
EndFunc   ;==>Bench_Speed
#EndRegion 4) speed

; Functions the API expects from the host script
Func Out($a_s_Text)
	ConsoleWrite($a_s_Text & @CRLF)
EndFunc   ;==>Out

Func StartBot()
EndFunc   ;==>StartBot

Func _Exit()
	Exit
EndFunc   ;==>_Exit
