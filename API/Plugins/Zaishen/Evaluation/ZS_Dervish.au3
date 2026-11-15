#include-once

; Zaishen Dervish enchantment play: "feed and kick".
; - Flash enchantments (game flag ENCHANT_FLASH: Grenth's Fingers, Aura of Thorns, Heart of Holy Flame...) do their job
;   when they END. Casting one, then ending it at once is the point.
; - Skills that strip one of your own enchantments (game flag SELF_ENCHANT_REMOVAL: Twin Moon Sweep, Wearying Strike,
;   Pious Haste, Signet of Pious Light...) remove the NEWEST enchantment on you and get a bonus for it.
; So: a stripper only goes when the newest enchantment is worth losing (a flash one, or one about to end anyway),
; never on a long enchantment the build relies on; and a flash enchantment is cast first when a stripper is ready.
; Everything comes from the game data: no list of skills to maintain. Pure functions on the snapshot.


Func ZS_IsFlashEnchant($a_i_SkillID)
	Return BitAND(ZS_SkillData($a_i_SkillID, $GC_I_SKILL_SPECIAL), $GC_I_SKILL_SPECIAL_FLAG_ENCHANT_FLASH) <> 0
EndFunc   ;==>ZS_IsFlashEnchant

;~ Description: True for a Dervish skill that strips one of the player's own enchantments.
Func ZS_IsStripper($a_i_Slot)
	If $g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Profession] <> $GC_I_PROFESSION_DERVISH Then Return False
	Return BitAND($g_amx2_ZS_Slot[$a_i_Slot][$GC_ZS_S_Effect2], $GC_I_SKILL_EFFECT2_SELF_ENCHANT_REMOVAL) <> 0
EndFunc   ;==>ZS_IsStripper

;~ Description: Newest DERVISH enchantment on the player (0 = none). @extended = its remaining ms.
;~ The strippers only take a Dervish enchantment: a monk's Protective Spirit on us is never at risk.
Func ZS_TopSelfEnchant()
	Local $l_i_Best = 0, $l_i_BestAge = 0x7FFFFFFF, $l_i_Age
	For $l_i_SkillID In MapKeys($g_m_ZS_SelfFx)
		If ZS_SkillData($l_i_SkillID, $GC_I_SKILL_TYPE) <> $GC_I_SKILL_TYPE_ENCHANTMENT Then ContinueLoop
		If ZS_SkillData($l_i_SkillID, $GC_I_SKILL_PROFESSION) <> $GC_I_PROFESSION_DERVISH Then ContinueLoop
		$l_i_Age = (MapExists($g_m_ZS_SelfFxAge, $l_i_SkillID) ? $g_m_ZS_SelfFxAge[$l_i_SkillID] : 0x7FFFFFFF)
		If $l_i_Age < $l_i_BestAge Then
			$l_i_BestAge = $l_i_Age
			$l_i_Best = $l_i_SkillID
		EndIf
	Next
	If $l_i_Best = 0 Then Return 0
	Return SetExtended($g_m_ZS_SelfFx[$l_i_Best], $l_i_Best)
EndFunc   ;==>ZS_TopSelfEnchant

;~ Description: Utility bonus of a stripper slot right now, or -1 when it would strip an enchantment worth keeping.
;~ Fills $g_s_ZS_SlotWhy.
Func ZS_StripBonus($a_i_Slot)
	Local $l_i_Top = ZS_TopSelfEnchant()
	Local $l_i_Remain = @extended
	If $l_i_Top = 0 Then
		; Nothing to strip: the skill works, without its bonus
		$g_s_ZS_SlotWhy = " no enchantment to strip"
		Return -0.15
	EndIf
	If ZS_IsFlashEnchant($l_i_Top) Then
		$g_s_ZS_SlotWhy = " kicks " & ZS_SkillName($l_i_Top)
		Return 0.2
	EndIf
	If $l_i_Remain <> $GC_ZS_FX_MAINTAINED And $l_i_Remain < 3000 Then
		$g_s_ZS_SlotWhy = " strips " & ZS_SkillName($l_i_Top) & " (ending)"
		Return 0
	EndIf
	Return -1 ; would waste a long enchantment the build relies on
EndFunc   ;==>ZS_StripBonus

;~ Description: True when a stripper of the bar could be used now (resources, a foe in reach for an attack).
Func ZS_StripperReady()
	For $l_i_Slot = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] = 0 Or Not ZS_IsStripper($l_i_Slot) Then ContinueLoop
		If ZS_Veto_Resources($l_i_Slot) <> "" Then ContinueLoop
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Type] = $GC_I_SKILL_TYPE_ATTACK And $g_ai_ZS_Foes[0] = 0 Then ContinueLoop
		Return True
	Next
	Return False
EndFunc   ;==>ZS_StripperReady
