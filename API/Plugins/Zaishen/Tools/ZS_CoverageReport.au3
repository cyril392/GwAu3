; Zaishen coverage report. Runs WITHOUT Guild Wars.
;
;   D:\AutoIt3\AutoIt3.exe /ErrorStdOut "API\Plugins\Zaishen\Tools\ZS_CoverageReport.au3"
;
; Classifies every skill of the game data and writes:
;   Tools\coverage.tsv          one line per skill: ID, name, type, family, target mask, origin (rule / def)
;   Tools\coverage_summary.txt  number of skills per family, and what is left without behaviour

#include "..\..\..\_GwAu3.au3"

Global $g_ai_CovCount[$GC_ZS_FAM_COUNT], $g_i_CovDefs = 0, $g_i_CovPlayable = 0, $g_i_CovNone = 0

Local $l_h_Tsv = FileOpen(@ScriptDir & "\coverage.tsv", 2)
FileWriteLine($l_h_Tsv, "SkillID" & @TAB & "Name" & @TAB & "Type" & @TAB & "Family" & @TAB & "TargetMask" & @TAB & "Origin")

For $l_i_ID = 1 To $GC_I_SKILL_DATA_ROWS - 1
	ZS_Knowledge_ResolveSlot(1, $l_i_ID)
	Local $l_i_Family = $g_amx2_ZS_Slot[1][$GC_ZS_S_Family]
	$g_ai_CovCount[$l_i_Family] += 1
	If $g_amx2_ZS_Slot[1][$GC_ZS_S_Origin] = "def" Then $g_i_CovDefs += 1

	; A skill a player can put on a bar: not a monster skill, and not a bounty, disguise, passive or environment effect
	Local $l_b_Playable = (BitAND($g_amx2_ZS_Slot[1][$GC_ZS_S_Special], $GC_I_SKILL_SPECIAL_FLAG_MONSTER_SKILL + $GC_I_SKILL_SPECIAL_FLAG_PASSIVE_MONSTER) = 0)
	Switch $g_amx2_ZS_Slot[1][$GC_ZS_S_Type]
		Case 0, $GC_I_SKILL_TYPE_BOUNTY, $GC_I_SKILL_TYPE_SCROLL, $GC_I_SKILL_TYPE_CONDITION, $GC_I_SKILL_TYPE_TITLE, _
				$GC_I_SKILL_TYPE_PASSIVE, $GC_I_SKILL_TYPE_ENVIRONMENTAL, $GC_I_SKILL_TYPE_ENVIRONMENTALTRAP, $GC_I_SKILL_TYPE_DISGUISE
			$l_b_Playable = False
	EndSwitch
	If $l_b_Playable Then $g_i_CovPlayable += 1
	If $l_b_Playable And $l_i_Family = $GC_ZS_FAM_NONE Then $g_i_CovNone += 1

	FileWriteLine($l_h_Tsv, $l_i_ID & @TAB & ZS_SkillName($l_i_ID) & @TAB & $g_amx2_ZS_Slot[1][$GC_ZS_S_Type] & @TAB & $GC_AS_ZS_FAMNAMES[$l_i_Family] & _
			@TAB & $g_amx2_ZS_Slot[1][$GC_ZS_S_TargetMask] & @TAB & $g_amx2_ZS_Slot[1][$GC_ZS_S_Origin])
Next
FileClose($l_h_Tsv)

Local $l_s_Summary = "Zaishen coverage - " & ($GC_I_SKILL_DATA_ROWS - 1) & " skills in the game data" & @CRLF & @CRLF
For $i = 0 To $GC_ZS_FAM_COUNT - 1
	$l_s_Summary &= StringFormat("%-14s %5d", $GC_AS_ZS_FAMNAMES[$i], $g_ai_CovCount[$i]) & @CRLF
Next
$l_s_Summary &= @CRLF & "Skills a player can put on a bar: " & $g_i_CovPlayable & @CRLF
$l_s_Summary &= "  of which without behaviour (family None): " & $g_i_CovNone & @CRLF
$l_s_Summary &= "Dedicated definitions: " & $g_i_CovDefs & @CRLF
Local $l_h_Sum = FileOpen(@ScriptDir & "\coverage_summary.txt", 2)
FileWrite($l_h_Sum, $l_s_Summary)
FileClose($l_h_Sum)
ConsoleWrite($l_s_Summary)

Func Out($a_s_Text)
	ConsoleWrite($a_s_Text & @CRLF)
EndFunc   ;==>Out

Func StartBot()
EndFunc   ;==>StartBot

Func _Exit()
	Exit
EndFunc   ;==>_Exit
