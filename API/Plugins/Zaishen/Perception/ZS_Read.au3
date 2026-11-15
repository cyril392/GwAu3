#include-once

; Zaishen memory readers: the ONLY code of Zaishen that reads the game, used by ZS_Perceive.
; Built on GwAu3 core only (Memory_*, Agent_*, World_*, Party_*, Skill_GetSkillTimer, Utils_TList_*):
; Zaishen does not need the UtilityAI plugin. Each reader reads only what Zaishen uses, in bulk.

Global $g_p_ZS_Skillbar = 0          ; skill bar of the player (dies with the instance)

; Columns of a raw agent row (ZS_Read_Agents), same order as the fields of ZS_Read_AgentStruct, then the pointer
Global Enum $GC_ZS_R_ID, $GC_ZS_R_RotCos, $GC_ZS_R_RotSin, $GC_ZS_R_X, $GC_ZS_R_Y, $GC_ZS_R_Type, $GC_ZS_R_MoveX, $GC_ZS_R_MoveY, _
	$GC_ZS_R_PlayerNumber, $GC_ZS_R_Primary, $GC_ZS_R_Secondary, $GC_ZS_R_Level, $GC_ZS_R_EnergyRegen, $GC_ZS_R_Overcast, _
	$GC_ZS_R_EnergyPercent, $GC_ZS_R_MaxEnergy, $GC_ZS_R_HPPips, $GC_ZS_R_HP, $GC_ZS_R_MaxHP, $GC_ZS_R_Effects, $GC_ZS_R_ModelState, _
	$GC_ZS_R_TypeMap, $GC_ZS_R_LoginNumber, $GC_ZS_R_LastStrike, $GC_ZS_R_Allegiance, $GC_ZS_R_WeaponType, $GC_ZS_R_Skill, _
	$GC_ZS_R_WeaponItemId, $GC_ZS_R_OffhandItemId, $GC_ZS_R_Ptr, $GC_ZS_R_COUNT

Global Const $GC_ZS_AGENT_LIVING = 0xDB

#Region Agents
Func ZS_Read_AgentStruct()
	Static $s_d = Memory_CreateStructure( _
			"long ID[0x2C];" & _
			"float RotationCos[0x50];" & _
			"float RotationSin[0x54];" & _
			"float X[0x74];" & _
			"float Y[0x78];" & _
			"long Type[0x9C];" & _
			"float MoveX[0xA0];" & _
			"float MoveY[0xA4];" & _
			"short PlayerNumber[0xF4];" & _
			"byte Primary[0x10E];" & _
			"byte Secondary[0x10F];" & _
			"byte Level[0x110];" & _
			"float EnergyRegen[0x118];" & _
			"float Overcast[0x11C];" & _
			"float EnergyPercent[0x120];" & _
			"dword MaxEnergy[0x124];" & _
			"float HPPips[0x12C];" & _
			"float HP[0x134];" & _
			"dword MaxHP[0x138];" & _
			"dword Effects[0x13C];" & _
			"dword ModelState[0x158];" & _
			"dword TypeMap[0x15C];" & _
			"dword LoginNumber[0x184];" & _
			"byte LastStrike[0x1B4];" & _
			"byte Allegiance[0x1B5];" & _
			"short WeaponType[0x1B6];" & _
			"short Skill[0x1B8];" & _
			"short WeaponItemId[0x1BE];" & _
			"short OffhandItemId[0x1C0]")
	Return $s_d
EndFunc   ;==>ZS_Read_AgentStruct

;~ Description: Living agents within $a_f_Range of the player (the player always included).
;~ Returns rows [1..n][$GC_ZS_R_*], [0][0] = n; @extended = row of the player (0 = not found).
Func ZS_Read_Agents($a_i_MyID, $a_f_Range)
	Local $l_ax_Empty[1][$GC_ZS_R_COUNT]
	$l_ax_Empty[0][0] = 0
	Local $l_i_Max = Agent_GetMaxAgents()
	If $l_i_Max <= 0 Then Return SetError(1, 0, $l_ax_Empty)

	Local $l_d_Ptrs = DllStructCreate("ptr[" & $l_i_Max & "]")
	DllCall($g_h_Kernel32, "bool", "ReadProcessMemory", "handle", $g_h_GWProcess, "ptr", Memory_Read($g_p_AgentBase), _
			"struct*", $l_d_Ptrs, "ulong_ptr", 4 * $l_i_Max, "ulong_ptr*", 0)
	If @error Then Return SetError(2, 0, $l_ax_Empty)

	; The player first: the range is measured from it
	Local $l_d_Struct = ZS_Read_AgentStruct()
	Local $l_p_Me = Agent_GetAgentPtr($a_i_MyID)
	If $l_p_Me = 0 Then Return SetError(3, 0, $l_ax_Empty)
	Local $l_av_Me = Memory_ReadStruct($l_p_Me, $l_d_Struct)
	If @error Then Return SetError(3, 0, $l_ax_Empty)
	Local $l_f_PX = $l_av_Me[$GC_ZS_R_X], $l_f_PY = $l_av_Me[$GC_ZS_R_Y]
	Local $l_f_Sq = $a_f_Range * $a_f_Range

	Local $l_ax_Rows[$l_i_Max + 1][$GC_ZS_R_COUNT]
	Local $l_i_N = 0, $l_i_MeRow = 0, $l_p, $l_av, $l_f_DX, $l_f_DY
	For $i = 1 To $l_i_Max
		$l_p = DllStructGetData($l_d_Ptrs, 1, $i)
		If $l_p = 0 Then ContinueLoop
		If $l_p = $l_p_Me Then
			$l_av = $l_av_Me
		Else
			$l_av = Memory_ReadStruct($l_p, $l_d_Struct)
			If @error Then ContinueLoop
			If $l_av[$GC_ZS_R_Type] <> $GC_ZS_AGENT_LIVING Then ContinueLoop
			$l_f_DX = $l_av[$GC_ZS_R_X] - $l_f_PX
			$l_f_DY = $l_av[$GC_ZS_R_Y] - $l_f_PY
			If $l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY > $l_f_Sq Then ContinueLoop
		EndIf
		$l_i_N += 1
		For $c = 0 To $GC_ZS_R_Ptr - 1
			$l_ax_Rows[$l_i_N][$c] = $l_av[$c]
		Next
		$l_ax_Rows[$l_i_N][$GC_ZS_R_Ptr] = $l_p
		If $l_p = $l_p_Me Then $l_i_MeRow = $l_i_N
	Next
	ReDim $l_ax_Rows[$l_i_N + 1][$GC_ZS_R_COUNT]
	$l_ax_Rows[0][0] = $l_i_N
	Return SetExtended($l_i_MeRow, $l_ax_Rows)
EndFunc   ;==>ZS_Read_Agents

;~ Description: Zaishen flags ($GC_ZS_AF_*) of a raw agent row, from its effect mask, model state and type map.
Func ZS_Read_AgentFlags(ByRef $a_ax_Rows, $a_i_Row)
	Local $l_i_Fx = $a_ax_Rows[$a_i_Row][$GC_ZS_R_Effects]
	Local $l_i_State = $a_ax_Rows[$a_i_Row][$GC_ZS_R_ModelState]
	Local $l_i_Map = $a_ax_Rows[$a_i_Row][$GC_ZS_R_TypeMap]
	Local $l_i_F = 0
	If BitAND($l_i_Fx, 0x10) Or $a_ax_Rows[$a_i_Row][$GC_ZS_R_HP] <= 0 Then $l_i_F += $GC_ZS_AF_DEAD
	If $a_ax_Rows[$a_i_Row][$GC_ZS_R_Skill] <> 0 Or $l_i_State = 0x41 Or $l_i_State = 0x245 Then $l_i_F += $GC_ZS_AF_CASTING
	If $l_i_State = 0x40 Or $l_i_State = 0x60 Or $l_i_State = 0x440 Or $l_i_State = 0x460 Then $l_i_F += $GC_ZS_AF_ATTACKING
	If $a_ax_Rows[$a_i_Row][$GC_ZS_R_MoveX] <> 0 Or $a_ax_Rows[$a_i_Row][$GC_ZS_R_MoveY] <> 0 Or $l_i_State = 0x4C Or $l_i_State = 0xCC Then $l_i_F += $GC_ZS_AF_MOVING
	If $l_i_State = 0x450 Then $l_i_F += $GC_ZS_AF_KNOCKED
	If BitAND($l_i_Fx, 0x0800) Then $l_i_F += $GC_ZS_AF_HEXED
	If BitAND($l_i_Fx, 0x0400) Then $l_i_F += $GC_ZS_AF_DEGENHEXED
	If BitAND($l_i_Fx, 0x0080) Then $l_i_F += $GC_ZS_AF_ENCHANTED
	If BitAND($l_i_Fx, 0x0002) Then $l_i_F += $GC_ZS_AF_CONDITIONED
	If BitAND($l_i_Fx, 0x0001) Then $l_i_F += $GC_ZS_AF_BLEEDING
	If BitAND($l_i_Fx, 0x0040) Then $l_i_F += $GC_ZS_AF_POISONED
	If BitAND($l_i_Fx, 0x0020) Then $l_i_F += $GC_ZS_AF_DEEPWOUND
	If BitAND($l_i_Fx, 0x000A) = 0x000A Then $l_i_F += $GC_ZS_AF_CRIPPLED
	If BitAND($l_i_Fx, 0x8000) Then $l_i_F += $GC_ZS_AF_WEAPONSPELL
	If BitAND($l_i_Map, 0x000400) Then $l_i_F += $GC_ZS_AF_BOSS
	If $a_ax_Rows[$a_i_Row][$GC_ZS_R_LoginNumber] <> 0 Then $l_i_F += $GC_ZS_AF_PLAYER
	If BitAND($l_i_Fx, 0x10) And BitAND($l_i_Fx, 0x4) Then $l_i_F += $GC_ZS_AF_CORPSE
	If BitAND($l_i_Map, 0x040000) Then $l_i_F += $GC_ZS_AF_SPAWNED
	Return $l_i_F
EndFunc   ;==>ZS_Read_AgentFlags

;~ Description: Conditions only the visible effects show (burning, blind, dazed, weakness, disease) of one agent.
;~ Walks the visible effect list of the agent (one read per effect).
Func ZS_Read_VisibleFlags($a_p_Agent)
	Static $s_d = Memory_CreateStructure("dword EffectType[0x0];dword EffectID[0x4];dword HasEnded[0x8]")
	If $a_p_Agent = 0 Then Return 0
	Local $l_av_It = Utils_TList_CreateIterator($a_p_Agent + 0x174)
	Local $l_p = Utils_TList_Iterator_Current($l_av_It)
	Local $l_i_F = 0, $l_i_Guard = 0, $l_av
	While $l_p <> 0 And $l_i_Guard < 31
		$l_i_Guard += 1
		$l_av = Memory_ReadStruct($l_p, $s_d)
		If @error Then ExitLoop
		If $l_av[0] = $GC_I_EFFECT_TYPE_STATUS And $l_av[2] = 0 Then
			Switch $l_av[1]
				Case $GC_I_EFFECT_ID_BURNING
					$l_i_F = BitOR($l_i_F, $GC_ZS_AF_BURNING)
				Case $GC_I_EFFECT_ID_BLINDED
					$l_i_F = BitOR($l_i_F, $GC_ZS_AF_BLIND)
				Case $GC_I_EFFECT_ID_DAZED
					$l_i_F = BitOR($l_i_F, $GC_ZS_AF_DAZED)
				Case $GC_I_EFFECT_ID_WEAKNESS
					$l_i_F = BitOR($l_i_F, $GC_ZS_AF_WEAKNESS)
				Case $GC_I_EFFECT_ID_DISEASED
					$l_i_F = BitOR($l_i_F, $GC_ZS_AF_DISEASED)
			EndSwitch
		EndIf
		If Not Utils_TList_Iterator_Next($l_av_It) Then ExitLoop
		$l_p = Utils_TList_Iterator_Current($l_av_It)
	WEnd
	Return $l_i_F
EndFunc   ;==>ZS_Read_VisibleFlags
#EndRegion Agents

#Region Effects and bonds
;~ Description: Effects of the agents of the snapshot (the client knows them for the party only) into $g_amx2_ZS_Fx,
;~ and the bonds of the player (enchantments it keeps up) into $g_amx2_ZS_Bond.
;~ $a_m_IDs: agent ID -> True for the agents of the snapshot.
Func ZS_Read_EffectsAndBonds($a_i_MyID, ByRef $a_m_IDs)
	Static $s_d_Entry = Memory_CreateArrayStructure("dword AgentID[0x0];ptr BondArray[0x4];long BondCount[0xC];ptr EffectArray[0x14];long EffectCount[0x1C]", 0x24)
	Static $s_d_Effect = Memory_CreateArrayStructure("long SkillID[0x0];dword AttributeLevel[0x4];long EffectID[0x8];dword CasterID[0xC];float Duration[0x10];dword Timestamp[0x14]", 0x18)
	Static $s_d_Bond = Memory_CreateArrayStructure("long SkillID[0x0];dword Unknown[0x4];long BondID[0x8];dword TargetAgentID[0xC]", 0x10)

	$g_i_ZS_FxCount = 0
	$g_i_ZS_BondCount = 0
	ReDim $g_amx2_ZS_Fx[1][$GC_ZS_FX_COUNT]
	ReDim $g_amx2_ZS_Bond[1][2]

	Local $l_p_Base = World_GetWorldInfo("AgentEffectsArray")
	Local $l_i_Size = World_GetWorldInfo("AgentEffectsArraySize")
	If $l_p_Base = 0 Or $l_i_Size <= 0 Then Return False
	Local $l_ax_Entries = Memory_ReadArrayStruct($l_p_Base, $l_i_Size, $s_d_Entry)
	If @error Then Return False

	Local $l_i_Timer = Skill_GetSkillTimer()
	Local $l_i_AgentID, $l_i_Count, $l_ax, $l_i_Stamp, $l_i_Row = 0
	For $j = 0 To $l_i_Size - 1
		$l_i_AgentID = $l_ax_Entries[$j][0]
		If $l_i_AgentID = 0 Or Not MapExists($a_m_IDs, $l_i_AgentID) Then ContinueLoop

		; --- effects ---
		$l_i_Count = $l_ax_Entries[$j][4]
		If $l_ax_Entries[$j][3] <> 0 And $l_i_Count > 0 Then
			If $l_i_Count > 31 Then $l_i_Count = 31
			$l_ax = Memory_ReadArrayStruct($l_ax_Entries[$j][3], $l_i_Count, $s_d_Effect)
			If Not @error Then
				ReDim $g_amx2_ZS_Fx[$l_i_Row + $l_i_Count + 1][$GC_ZS_FX_COUNT]
				For $k = 0 To $l_i_Count - 1
					$g_amx2_ZS_Fx[$l_i_Row][$GC_ZS_FX_AgentID] = $l_i_AgentID
					$g_amx2_ZS_Fx[$l_i_Row][$GC_ZS_FX_SkillID] = $l_ax[$k][0]
					$g_amx2_ZS_Fx[$l_i_Row][$GC_ZS_FX_Level] = $l_ax[$k][1]
					$g_amx2_ZS_Fx[$l_i_Row][$GC_ZS_FX_CasterID] = $l_ax[$k][3]
					$l_i_Stamp = $l_ax[$k][5]
					If $l_i_Stamp = 0 Then
						$g_amx2_ZS_Fx[$l_i_Row][$GC_ZS_FX_RemainMs] = $GC_ZS_FX_MAINTAINED
						$g_amx2_ZS_Fx[$l_i_Row][$GC_ZS_FX_Age] = $GC_ZS_FX_MAINTAINED
					Else
						$g_amx2_ZS_Fx[$l_i_Row][$GC_ZS_FX_Age] = BitAND($l_i_Timer - $l_i_Stamp, 0xFFFFFFFF)
						$g_amx2_ZS_Fx[$l_i_Row][$GC_ZS_FX_RemainMs] = Int($l_ax[$k][4] * 1000 - $g_amx2_ZS_Fx[$l_i_Row][$GC_ZS_FX_Age])
					EndIf
					$l_i_Row += 1
				Next
			EndIf
		EndIf

		; --- bonds: only the player's interest Zaishen (what it keeps up) ---
		If $l_i_AgentID <> $a_i_MyID Then ContinueLoop
		$l_i_Count = $l_ax_Entries[$j][2]
		If $l_ax_Entries[$j][1] = 0 Or $l_i_Count <= 0 Then ContinueLoop
		If $l_i_Count > 31 Then $l_i_Count = 31
		$l_ax = Memory_ReadArrayStruct($l_ax_Entries[$j][1], $l_i_Count, $s_d_Bond)
		If @error Then ContinueLoop
		ReDim $g_amx2_ZS_Bond[$l_i_Count + 1][2]
		For $k = 0 To $l_i_Count - 1
			$g_amx2_ZS_Bond[$k][0] = $l_ax[$k][0]
			$g_amx2_ZS_Bond[$k][1] = $l_ax[$k][3]
		Next
		$g_i_ZS_BondCount = $l_i_Count
	Next
	$g_i_ZS_FxCount = $l_i_Row
	Return True
EndFunc   ;==>ZS_Read_EffectsAndBonds
#EndRegion Effects and bonds

#Region Skill bar
;~ Description: Find the skill bar of the player. Returns False when it is not there (loading).
Func ZS_Read_FindSkillbar($a_i_MyID)
	$g_p_ZS_Skillbar = 0
	Local $l_p_Array = World_GetWorldInfo("SkillbarArray")
	Local $l_i_Size = World_GetWorldInfo("SkillbarArraySize")
	If $l_p_Array = 0 Or $l_i_Size <= 0 Then Return False
	For $i = 0 To $l_i_Size - 1
		If Memory_Read($l_p_Array + 0xBC * $i, "long") = $a_i_MyID Then
			$g_p_ZS_Skillbar = $l_p_Array + 0xBC * $i
			Return True
		EndIf
	Next
	Return False
EndFunc   ;==>ZS_Read_FindSkillbar

;~ Description: True while the skill bar found still belongs to the player (it dies with the instance).
Func ZS_Read_SkillbarValid($a_i_MyID)
	Return $g_p_ZS_Skillbar <> 0 And Memory_Read($g_p_ZS_Skillbar, "long") = $a_i_MyID
EndFunc   ;==>ZS_Read_SkillbarValid

;~ Description: The 8 slots of the bar: skill, recharge, adrenaline. A new skill in a slot is resolved again.
Func ZS_Read_Skillbar()
	Static $s_d = Memory_CreateArrayStructure("dword Adrenaline[0x0];dword AdrenalineB[0x4];dword Timestamp[0x8];dword SkillID[0xC];dword Event[0x10]", 0x14)
	If $g_p_ZS_Skillbar = 0 Then Return False
	Local $l_ax = Memory_ReadArrayStruct($g_p_ZS_Skillbar + 0x4, 8, $s_d)
	If @error Then Return False
	Local $l_i_Timer = Utils_MakeInt32(Skill_GetSkillTimer())
	Local $l_i_SkillID, $l_i_Stamp, $l_i_Left
	For $l_i_Slot = 1 To 8
		$l_i_SkillID = $l_ax[$l_i_Slot - 1][3]
		If $l_i_SkillID <> $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] Then ZS_Knowledge_ResolveSlot($l_i_Slot, $l_i_SkillID)
		$l_i_Stamp = $l_ax[$l_i_Slot - 1][2]
		$l_i_Left = ($l_i_Stamp = 0 ? 0 : Utils_MakeInt32($l_i_Stamp) - $l_i_Timer)
		If $l_i_Left < 0 Then $l_i_Left = 0
		$g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Recharged] = ($l_i_Left = 0)
		$g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_RechargeMs] = $l_i_Left
		$g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Adrenaline] = $l_ax[$l_i_Slot - 1][0]
	Next
	Return True
EndFunc   ;==>ZS_Read_Skillbar
#EndRegion Skill bar

#Region Party
;~ Description: Target called by another player of the party (the first one found), 0 when none.
Func ZS_Read_CalledTarget()
	Local $l_i_Count = Party_GetMyPartyInfo("ArrayPlayerPartyMemberSize")
	Local $l_i_MyLogin = Agent_GetAgentInfo(-2, "LoginNumber")
	Local $l_i_Called
	For $i = 1 To $l_i_Count
		If Party_GetMyPartyPlayerMemberInfo($i, "LoginNumber") = $l_i_MyLogin Then ContinueLoop
		$l_i_Called = Party_GetMyPartyPlayerMemberInfo($i, "CalledTargetID")
		If $l_i_Called <> 0 Then Return $l_i_Called
	Next
	Return 0
EndFunc   ;==>ZS_Read_CalledTarget

;~ Description: Agent ID of the player's animal companion, 0 when it has none.
Func ZS_Read_MyPet($a_i_MyID)
	Local $l_i_Count = World_GetWorldInfo("PetInfoArraySize")
	If $l_i_Count <= 0 Or $l_i_Count > 16 Then Return 0
	For $i = 1 To $l_i_Count
		If Party_GetPetInfo($i, "OwnerAgentID") = $a_i_MyID Then Return Party_GetPetInfo($i, "AgentID")
	Next
	Return 0
EndFunc   ;==>ZS_Read_MyPet
#EndRegion Party
