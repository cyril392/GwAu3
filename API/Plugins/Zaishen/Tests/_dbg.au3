#include "..\..\..\_GwAu3.au3"
Local $a = ["defy_pain_hit.zs", "dervish_strip_ignores_monk_enchant.zs"]
For $f In $a
	ZS_Snapshot_Load(@ScriptDir & "\Scenarios\" & $f)
	ZS_Eval_BuildLists()
	ConsoleWrite($f & ": fam=" & $g_amx2_ZS_Slot[1][$GC_ZS_S_Family] & " mask=" & $g_amx2_ZS_Slot[1][$GC_ZS_S_TargetMask] & " params=" & $g_amx2_ZS_Slot[1][$GC_ZS_S_Params] & @CRLF)
	ConsoleWrite("  veto=" & ZS_Veto_Resources(1) & " req=" & ZS_Req_Slot(1) & " threat=" & ZS_Threat($g_i_ZS_MeIdx) & " incombat=" & $g_b_ZS_InCombat & " strip=" & (ZS_IsStripper(1) ? ZS_StripBonus(1) : "n/a") & $g_s_ZS_SlotWhy & @CRLF)
	ConsoleWrite("  util=" & ZS_Eval_Utility(1, $g_amx2_ZS_Slot[1][$GC_ZS_S_Family], ($g_amx2_ZS_Slot[1][$GC_ZS_S_TargetMask] = 1 ? $g_i_ZS_MeIdx : ZS_IdxOf(10))) & " " & $g_s_ZS_Why & " reqT=" & ZS_Req_Target(1, ZS_IdxOf(10)) & @CRLF)
Next
Func Out($s)
EndFunc
Func StartBot()
EndFunc
Func _Exit()
EndFunc