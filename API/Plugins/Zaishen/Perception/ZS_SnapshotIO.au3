#include-once

; Zaishen snapshot text format: save the perception of a tick, load it back without the game.
; One record per line, fields separated by "|", "#" starts a comment. Missing trailing fields are 0.
;
;   M|key=value|key=value...     now, ping, myid, called, aggro, energy, maxenergy, pips, overcast, expertise,
;                                bundle (skill ID of the urn the player holds)
;   S|slot|skillID|recharged|rechargeMs|adrenaline|healthCost|overcastCost
;        healthCost (% of max health) and overcastCost come from the game: give them when the skill has some
;   A|id|x|y|hp|maxhp|pips|allegiance|flags|skill|castMs|primary|secondary|model|weapon|level|lastStrike|rotCos|rotSin|dmgRate
;        rotCos/rotSin: facing (both 0 = unknown); dmgRate: health lost per second, fraction of max health
;        allegiance: ally, foe, spirit, minion, npc or a number
;        flags: names separated by "," (dead, casting, hexed...), "-" for none, or a number
;   F|agentID|skillID|remainMs|casterID|attributeLevel|ageMs      remainMs empty = kept up (maintained)
;        ageMs: ms since applied (smallest = newest); empty = in file order, the last line being the newest
;   B|skillID|agentID            the spirit that ritual created (bound while playing)
;   H|x|y|radius|remainMs|skillID   a damaging area a foe put on the ground
;   N|skillID|targetID           an enchantment the player keeps up (bond), on that target
;   U|agentID|spentEnergy|lastCastAgoMs   energy an ally was seen spending lately, and when it last started a skill
;   R|skillID|targetID|remainMs   a skill the player used on that target a moment ago, not offered again for that long
;        (a hex we put on a foe: Glowing Ice knows our water hexes this way)
;   W|set|itemType|offhandType|energy|energyEnchanted|energyHexed|energyHPAbove|hpAboveThr|energyHPBelow|hpBelowThr|enchant%|hct%|hsr%
;        a weapon set (1..4); item types as GwAu3_Const_Item ($GC_I_TYPE_*); the set in hand is M|wset=n
;   E|key=value|key=value...     expectation of a test scenario, kept in $g_as_ZS_Expect

Global $g_as_ZS_Expect[1] = [0]   ; [0] = count, then the raw "key=value|..." strings

#Region Load
;~ Description: Replace the current snapshot and skill bar with the content of a file. Returns False on error.
Func ZS_Snapshot_Load($a_s_File)
	Local $l_as_Lines = FileReadToArray($a_s_File)
	If @error Then Return SetError(1, 0, False)

	; First pass: count what the arrays must hold
	Local $l_i_Agents = 0, $l_i_Fx = 0, $l_i_Expect = 0, $l_i_Bonds = 0
	For $i = 0 To UBound($l_as_Lines) - 1
		Switch StringLeft(StringStripWS($l_as_Lines[$i], 1), 2)
			Case "A|"
				$l_i_Agents += 1
			Case "F|"
				$l_i_Fx += 1
			Case "N|"
				$l_i_Bonds += 1
			Case "E|"
				$l_i_Expect += 1
		EndSwitch
	Next

	ZS_Snapshot_Reset($l_i_Agents)
	Global $g_amx2_ZS_Fx[$l_i_Fx + 1][$GC_ZS_FX_COUNT]
	Global $g_amx2_ZS_Bond[$l_i_Bonds + 1][2]
	$g_i_ZS_HeldUrn = 0
	Global $g_as_ZS_Expect[$l_i_Expect + 1]
	$g_as_ZS_Expect[0] = $l_i_Expect
	ZS_Perception_ForgetTracking()
	ZS_Exec_Reset()
	ZS_Weapon_Reset()

	$g_i_ZS_Now = 0
	$g_i_ZS_Ping = 0
	$g_i_ZS_MyID = 0
	$g_i_ZS_CalledTarget = 0
	$g_f_ZS_AggroRange = 1320
	$g_f_ZS_Energy = 0
	$g_f_ZS_MaxEnergy = 0
	$g_i_ZS_EnergyPips = 0
	$g_i_ZS_Overcast = 0
	$g_i_ZS_Expertise = 0
	$g_i_ZS_FastCasting = 0
	$g_i_ZS_OfflineRank = 12
	$g_i_ZS_SoloSpeed = 1
	$g_i_ZS_PetID = 0
	Local $l_m_NoneLearned[]
	$g_m_ZS_Maintainable = $l_m_NoneLearned
	Local $l_ab_SlotSeen[9]

	Local $l_i_A = 0, $l_i_F = 0, $l_i_E = 0, $l_s_Line, $l_as_P, $l_i_N
	Local $l_m_Recent[]   ; applied once "now" is known
	For $i = 0 To UBound($l_as_Lines) - 1
		$l_s_Line = StringStripWS($l_as_Lines[$i], 3)
		If $l_s_Line = "" Or StringLeft($l_s_Line, 1) = "#" Then ContinueLoop
		If StringInStr($l_s_Line, " #") Then $l_s_Line = StringStripWS(StringLeft($l_s_Line, StringInStr($l_s_Line, " #") - 1), 3)
		$l_as_P = StringSplit($l_s_Line, "|", 2)
		$l_i_N = UBound($l_as_P)
		If $l_i_N < 20 Then ReDim $l_as_P[20] ; missing fields read as empty

		Switch $l_as_P[0]
			Case "M"
				For $j = 1 To $l_i_N - 1
					ZS_SnapshotIO_Meta($l_as_P[$j])
				Next

			Case "S"
				Local $l_i_Slot = Int($l_as_P[1])
				If $l_i_Slot < 1 Or $l_i_Slot > 8 Then ContinueLoop
				ZS_Knowledge_ResolveSlot($l_i_Slot, Int($l_as_P[2]))
				$g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Recharged] = ($l_as_P[3] = "" Or Int($l_as_P[3]) <> 0)
				$g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_RechargeMs] = Int($l_as_P[4])
				$g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Adrenaline] = Int($l_as_P[5])
				If $l_as_P[6] <> "" Then $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_HealthCost] = Int($l_as_P[6])
				If $l_as_P[7] <> "" Then $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_OvercastCost] = Int($l_as_P[7])
				$l_ab_SlotSeen[$l_i_Slot] = True

			Case "B"
				$g_m_ZS_SpiritOf[Int($l_as_P[1])] = Int($l_as_P[2])

			Case "H"
				ZS_Hazard_Add(Number($l_as_P[1]), Number($l_as_P[2]), Int($l_as_P[5]), Int($l_as_P[4]), Number($l_as_P[3]))

			Case "W"
				Local $l_i_Set = Int($l_as_P[1])
				If $l_i_Set < 1 Or $l_i_Set > 4 Then ContinueLoop
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_WeaponID] = 100 + $l_i_Set ; any distinct ID
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_ItemType] = Int($l_as_P[2])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_OffhandType] = Int($l_as_P[3])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_EFlat] = Int($l_as_P[4])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_EEnch] = Int($l_as_P[5])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_EHex] = Int($l_as_P[6])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_EHPHi] = Int($l_as_P[7])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_EHPHiThr] = Int($l_as_P[8])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_EHPLo] = Int($l_as_P[9])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_EHPLoThr] = Int($l_as_P[10])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Ench] = Int($l_as_P[11])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_HCT] = Int($l_as_P[12])
				$g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_HSR] = Int($l_as_P[13])
				ZS_Weapon_FinishSet($l_i_Set)

			Case "U"
				Local $l_av_U[3] = [Int($l_as_P[1]), Number($l_as_P[2]), Int($l_as_P[3])]
				$l_m_Recent["U" & $l_as_P[1]] = $l_av_U

			Case "R"
				$l_m_Recent[Int($l_as_P[1]) & ":" & Int($l_as_P[2])] = Int($l_as_P[3])

			Case "N"
				$g_amx2_ZS_Bond[$g_i_ZS_BondCount][0] = Int($l_as_P[1])
				$g_amx2_ZS_Bond[$g_i_ZS_BondCount][1] = Int($l_as_P[2])
				$g_i_ZS_BondCount += 1

			Case "A"
				$l_i_A += 1
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_ID] = Int($l_as_P[1])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_X] = Number($l_as_P[2])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Y] = Number($l_as_P[3])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_HP] = ($l_as_P[4] = "" ? 1 : Number($l_as_P[4]))
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_MaxHP] = Number($l_as_P[5])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_HPPips] = Number($l_as_P[6])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Allegiance] = ZS_SnapshotIO_Allegiance($l_as_P[7])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Flags] = ZS_SnapshotIO_FlagsFromText($l_as_P[8])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Skill] = Int($l_as_P[9])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_CastMs] = Int($l_as_P[10])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Primary] = Int($l_as_P[11])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Secondary] = Int($l_as_P[12])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Model] = Int($l_as_P[13])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_WeaponType] = Int($l_as_P[14])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Level] = Int($l_as_P[15])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_LastStrike] = Int($l_as_P[16])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_RotCos] = Number($l_as_P[17])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_RotSin] = Number($l_as_P[18])
				$g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_DmgRate] = Number($l_as_P[19])
				If $g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_HP] <= 0 Then $g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Flags] = BitOR($g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Flags], $GC_ZS_AF_DEAD)
				If $g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Skill] <> 0 Then $g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Flags] = BitOR($g_amx2_ZS_Agent[$l_i_A][$GC_ZS_A_Flags], $GC_ZS_AF_CASTING)

			Case "F"
				$g_amx2_ZS_Fx[$l_i_F][$GC_ZS_FX_AgentID] = Int($l_as_P[1])
				$g_amx2_ZS_Fx[$l_i_F][$GC_ZS_FX_SkillID] = Int($l_as_P[2])
				$g_amx2_ZS_Fx[$l_i_F][$GC_ZS_FX_RemainMs] = ($l_as_P[3] = "" ? $GC_ZS_FX_MAINTAINED : Int($l_as_P[3]))
				$g_amx2_ZS_Fx[$l_i_F][$GC_ZS_FX_CasterID] = Int($l_as_P[4])
				$g_amx2_ZS_Fx[$l_i_F][$GC_ZS_FX_Level] = Int($l_as_P[5])
				$g_amx2_ZS_Fx[$l_i_F][$GC_ZS_FX_Age] = ($l_as_P[6] = "" ? 100000 - 100 * $l_i_F : Int($l_as_P[6]))
				$l_i_F += 1

			Case "E"
				$l_i_E += 1
				$g_as_ZS_Expect[$l_i_E] = StringMid($l_s_Line, 3)
		EndSwitch
	Next
	$g_i_ZS_FxCount = $l_i_F
	Local $l_av_Use
	For $l_s_Key In MapKeys($l_m_Recent)
		If StringLeft($l_s_Key, 1) = "U" Then
			$l_av_Use = $l_m_Recent[$l_s_Key]
			$g_m_ZS_Spent[$l_av_Use[0]] = $l_av_Use[1]
			$g_m_ZS_SpentAt[$l_av_Use[0]] = $g_i_ZS_Now
			If $l_av_Use[2] > 0 Then $g_m_ZS_LastCastAt[$l_av_Use[0]] = $g_i_ZS_Now - $l_av_Use[2]
		Else
			$g_m_ZS_Recent[$l_s_Key] = $g_i_ZS_Now + $l_m_Recent[$l_s_Key]
		EndIf
	Next

	For $l_i_Slot = 1 To 8
		If Not $l_ab_SlotSeen[$l_i_Slot] Then ZS_Knowledge_ResolveSlot($l_i_Slot, 0)
	Next

	If Not ZS_Snapshot_Finalize() Then Return SetError(2, 0, False)
	Return True
EndFunc   ;==>ZS_Snapshot_Load

Func ZS_SnapshotIO_Meta($a_s_Pair)
	Local $l_i_Eq = StringInStr($a_s_Pair, "=")
	If $l_i_Eq < 2 Then Return
	Local $l_f_Value = Number(StringMid($a_s_Pair, $l_i_Eq + 1))
	Switch StringLower(StringStripWS(StringLeft($a_s_Pair, $l_i_Eq - 1), 3))
		Case "now"
			$g_i_ZS_Now = Int($l_f_Value)
		Case "ping"
			$g_i_ZS_Ping = Int($l_f_Value)
		Case "myid"
			$g_i_ZS_MyID = Int($l_f_Value)
		Case "called"
			$g_i_ZS_CalledTarget = Int($l_f_Value)
		Case "aggro"
			$g_f_ZS_AggroRange = $l_f_Value
		Case "energy"
			$g_f_ZS_Energy = $l_f_Value
		Case "maxenergy"
			$g_f_ZS_MaxEnergy = $l_f_Value
		Case "pips"
			$g_i_ZS_EnergyPips = Int($l_f_Value)
		Case "overcast"
			$g_i_ZS_Overcast = Int($l_f_Value)
		Case "expertise"
			$g_i_ZS_Expertise = Int($l_f_Value)
		Case "bundle"
			$g_i_ZS_HeldUrn = Int($l_f_Value)
		Case "fastcasting"
			$g_i_ZS_FastCasting = Int($l_f_Value)
		Case "rank"
			$g_i_ZS_OfflineRank = Int($l_f_Value)
		Case "solospeed"
			$g_i_ZS_SoloSpeed = Int($l_f_Value)
		Case "wset"
			$g_i_ZS_ActiveSet = Int($l_f_Value)
	EndSwitch
EndFunc   ;==>ZS_SnapshotIO_Meta

Func ZS_SnapshotIO_Allegiance($a_s_Text)
	Switch StringLower(StringStripWS($a_s_Text, 3))
		Case "ally"
			Return $GC_I_ALLEGIANCE_ALLY
		Case "foe", "enemy"
			Return $GC_I_ALLEGIANCE_ENEMY
		Case "spirit"
			Return $GC_I_ALLEGIANCE_SPIRIT
		Case "minion"
			Return $GC_I_ALLEGIANCE_MINION
		Case "npc"
			Return $GC_I_ALLEGIANCE_NPC
	EndSwitch
	Return Int($a_s_Text)
EndFunc   ;==>ZS_SnapshotIO_Allegiance

Func ZS_SnapshotIO_FlagsFromText($a_s_Text)
	$a_s_Text = StringStripWS($a_s_Text, 3)
	If $a_s_Text = "" Or $a_s_Text = "-" Then Return 0
	If StringIsDigit($a_s_Text) Then Return Int($a_s_Text)
	Local $l_i_Flags = 0
	Local $l_as_Names = StringSplit(StringLower($a_s_Text), ",", 2)
	For $i = 0 To UBound($l_as_Names) - 1
		For $j = 0 To UBound($GC_AS_ZS_FLAGNAMES) - 1
			If StringStripWS($l_as_Names[$i], 3) = $GC_AS_ZS_FLAGNAMES[$j] Then $l_i_Flags = BitOR($l_i_Flags, BitShift(1, -$j))
		Next
	Next
	Return $l_i_Flags
EndFunc   ;==>ZS_SnapshotIO_FlagsFromText
#EndRegion Load

#Region Save
Func ZS_SnapshotIO_FlagsToText($a_i_Flags)
	Local $l_s_Text = ""
	For $j = 0 To UBound($GC_AS_ZS_FLAGNAMES) - 1
		If BitAND($a_i_Flags, BitShift(1, -$j)) Then $l_s_Text &= ($l_s_Text = "" ? "" : ",") & $GC_AS_ZS_FLAGNAMES[$j]
	Next
	Return ($l_s_Text = "" ? "-" : $l_s_Text)
EndFunc   ;==>ZS_SnapshotIO_FlagsToText

;~ Description: Write the current snapshot to a file that ZS_Snapshot_Load reads back. Returns False on error.
Func ZS_Snapshot_Save($a_s_File, $a_s_Comment = "")
	Local $l_h_File = FileOpen($a_s_File, 2 + 8)
	If $l_h_File = -1 Then Return SetError(1, 0, False)

	If $a_s_Comment <> "" Then FileWriteLine($l_h_File, "# " & $a_s_Comment)
	FileWriteLine($l_h_File, "M|now=" & $g_i_ZS_Now & "|ping=" & $g_i_ZS_Ping & "|myid=" & $g_i_ZS_MyID & "|called=" & $g_i_ZS_CalledTarget & _
			"|aggro=" & $g_f_ZS_AggroRange & "|energy=" & Round($g_f_ZS_Energy, 1) & "|maxenergy=" & $g_f_ZS_MaxEnergy & "|pips=" & $g_i_ZS_EnergyPips & _
			"|overcast=" & $g_i_ZS_Overcast & "|expertise=" & $g_i_ZS_Expertise & "|bundle=" & $g_i_ZS_HeldUrn & "|wset=" & $g_i_ZS_ActiveSet)
	For $l_i_Set = 1 To 4
		If Not $g_amx2_ZS_WSet[$l_i_Set][$GC_ZS_W_Present] Then ContinueLoop
		Local $l_s_W = "W|" & $l_i_Set
		For $l_i_Col In StringSplit($GC_ZS_W_ItemType & "," & $GC_ZS_W_OffhandType & "," & $GC_ZS_W_EFlat & "," & $GC_ZS_W_EEnch & "," & $GC_ZS_W_EHex & "," & _
				$GC_ZS_W_EHPHi & "," & $GC_ZS_W_EHPHiThr & "," & $GC_ZS_W_EHPLo & "," & $GC_ZS_W_EHPLoThr & "," & $GC_ZS_W_Ench & "," & $GC_ZS_W_HCT & "," & $GC_ZS_W_HSR, ",", 2)
			$l_s_W &= "|" & $g_amx2_ZS_WSet[$l_i_Set][Int($l_i_Col)]
		Next
		FileWriteLine($l_h_File, $l_s_W)
	Next
	For $k = 0 To $g_i_ZS_BondCount - 1
		FileWriteLine($l_h_File, "N|" & $g_amx2_ZS_Bond[$k][0] & "|" & $g_amx2_ZS_Bond[$k][1] & "   # " & ZS_SkillName($g_amx2_ZS_Bond[$k][0]))
	Next
	For $l_i_Slot = 1 To 8
		If $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] = 0 Then ContinueLoop
		FileWriteLine($l_h_File, "S|" & $l_i_Slot & "|" & $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID] & "|" & ($g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Recharged] ? 1 : 0) & _
				"|" & $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_RechargeMs] & "|" & $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_Adrenaline] & _
				"|" & $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_HealthCost] & "|" & $g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_OvercastCost] & _
				"   # " & ZS_SkillName($g_amx2_ZS_Slot[$l_i_Slot][$GC_ZS_S_SkillID]))
	Next
	For $l_i_Skill In MapKeys($g_m_ZS_SpiritOf)
		FileWriteLine($l_h_File, "B|" & $l_i_Skill & "|" & $g_m_ZS_SpiritOf[$l_i_Skill])
	Next
	For $l_i_ID In MapKeys($g_m_ZS_LastCastAt)
		FileWriteLine($l_h_File, "U|" & $l_i_ID & "|" & Round(ZS_SpentEnergy($l_i_ID), 1) & "|" & ($g_i_ZS_Now - $g_m_ZS_LastCastAt[$l_i_ID]))
	Next
	Local $l_as_Pair
	For $l_s_Key In MapKeys($g_m_ZS_Recent)
		If Not StringRegExp($l_s_Key, "^\d+:\d+$") Or $g_m_ZS_Recent[$l_s_Key] <= $g_i_ZS_Now Then ContinueLoop
		$l_as_Pair = StringSplit($l_s_Key, ":", 2)
		FileWriteLine($l_h_File, "R|" & $l_as_Pair[0] & "|" & $l_as_Pair[1] & "|" & ($g_m_ZS_Recent[$l_s_Key] - $g_i_ZS_Now) & _
				"   # " & ZS_SkillName(Int($l_as_Pair[0])))
	Next
	For $i = 0 To $g_i_ZS_HazardCount - 1
		FileWriteLine($l_h_File, "H|" & Round($g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_X]) & "|" & Round($g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_Y]) & "|" & _
				Round($g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_R]) & "|" & ($g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_Until] - $g_i_ZS_Now) & "|" & _
				$g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_Skill] & "   # " & ZS_SkillName($g_amx2_ZS_Hazard[$i][$GC_ZS_HZ_Skill]))
	Next
	For $i = 1 To $g_i_ZS_AgentCount
		FileWriteLine($l_h_File, "A|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_ID] & "|" & Round($g_amx2_ZS_Agent[$i][$GC_ZS_A_X]) & "|" & Round($g_amx2_ZS_Agent[$i][$GC_ZS_A_Y]) & _
				"|" & Round($g_amx2_ZS_Agent[$i][$GC_ZS_A_HP], 3) & "|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_MaxHP] & "|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_HPPips] & _
				"|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_Allegiance] & "|" & ZS_SnapshotIO_FlagsToText($g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags]) & _
				"|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_Skill] & "|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_CastMs] & "|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_Primary] & _
				"|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_Secondary] & "|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_Model] & "|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_WeaponType] & _
				"|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_Level] & "|" & $g_amx2_ZS_Agent[$i][$GC_ZS_A_LastStrike] & _
				"|" & Round($g_amx2_ZS_Agent[$i][$GC_ZS_A_RotCos], 3) & "|" & Round($g_amx2_ZS_Agent[$i][$GC_ZS_A_RotSin], 3) & _
				"|" & Round($g_amx2_ZS_Agent[$i][$GC_ZS_A_DmgRate], 4))
	Next
	For $i = 0 To $g_i_ZS_FxCount - 1
		FileWriteLine($l_h_File, "F|" & $g_amx2_ZS_Fx[$i][$GC_ZS_FX_AgentID] & "|" & $g_amx2_ZS_Fx[$i][$GC_ZS_FX_SkillID] & "|" & $g_amx2_ZS_Fx[$i][$GC_ZS_FX_RemainMs] & _
				"|" & $g_amx2_ZS_Fx[$i][$GC_ZS_FX_CasterID] & "|" & $g_amx2_ZS_Fx[$i][$GC_ZS_FX_Level] & "|" & $g_amx2_ZS_Fx[$i][$GC_ZS_FX_Age])
	Next
	FileClose($l_h_File)
	Return True
EndFunc   ;==>ZS_Snapshot_Save
#EndRegion Save
