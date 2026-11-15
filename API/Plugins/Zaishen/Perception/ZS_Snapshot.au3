#include-once

; Zaishen perception: one frozen snapshot per tick.
; ZS_Perceive is the ONLY place that reads game memory, through Zaishen's own readers (ZS_Read.au3).
; Everything after it (evaluation, tests) reads the $g_*_ZS_* snapshot globals only.

Global $g_h_ZS_Clock = TimerInit()
Global $g_m_ZS_CastSkill[]        ; agent ID -> skill it was last seen activating
Global $g_m_ZS_CastStart[]        ; agent ID -> snapshot time that activation was first seen
Global $g_m_ZS_HpPrev[]           ; agent ID -> health fraction at the previous tick
Global $g_m_ZS_HpTime[]           ; agent ID -> time of that reading
Global $g_m_ZS_DmgRate[]          ; agent ID -> smoothed health loss per second
Global $g_i_ZS_CalledReadAt = -100000

#Region Build from the game
;~ Description: Take the snapshot of the current tick. Returns False when there is nothing to read
;~ (not in an explorable area, player not found).
Func ZS_Perceive($a_f_AggroRange = 1320)
	$g_f_ZS_AggroRange = $a_f_AggroRange
	$g_i_ZS_Now = Int(TimerDiff($g_h_ZS_Clock))

	If Not Map_GetInstanceInfo("IsExplorable") Then Return False

	; The skill bar dies with the instance: find it again when it no longer belongs to us
	Local $l_i_MyID = Agent_GetMyID()
	If $l_i_MyID = 0 Then Return False
	Local $l_b_NewInstance = False
	If Not ZS_Read_SkillbarValid($l_i_MyID) Then
		$l_b_NewInstance = True
		ZS_Perception_ForgetTracking()
		If Not ZS_Read_FindSkillbar($l_i_MyID) Then Return False
		; Attributes only change in an outpost: read once per instance
		$g_i_ZS_Expertise = Attribute_GetPartyAttributeInfo($GC_I_ATTRIBUTE_EXPERTISE, 0, "CurrentLevel")
		$g_i_ZS_FastCasting = Attribute_GetPartyAttributeInfo($GC_I_ATTRIBUTE_FAST_CASTING, 0, "CurrentLevel")
		; Activations (Fast Casting) and durations (attribute ranks) may have changed: resolve the bar again
		For $l_i_S = 1 To 8
			$g_amx2_ZS_Slot[$l_i_S][$GC_ZS_S_SkillID] = 0
		Next
		$g_i_ZS_PetReadAt = -100000
	EndIf

	; --- the player's pet (pets have the spirit allegiance: told apart by the pet list of the world) ---
	If $g_i_ZS_Now - $g_i_ZS_PetReadAt >= 1000 Then
		$g_i_ZS_PetReadAt = $g_i_ZS_Now
		$g_i_ZS_PetID = ZS_Read_MyPet($l_i_MyID)
	EndIf

	; --- agents ---
	Local $l_ax_Rows = ZS_Read_Agents($l_i_MyID, $g_f_ZS_PerceiveRange)
	Local $l_i_Me = @extended
	If @error Or $l_i_Me < 1 Then Return False
	Local $l_i_Count = $l_ax_Rows[0][0]

	$g_i_ZS_Ping = Other_GetPing()
	If $g_i_ZS_Now - $g_i_ZS_CalledReadAt >= 200 Then
		$g_i_ZS_CalledTarget = ZS_Read_CalledTarget()
		$g_i_ZS_CalledReadAt = $g_i_ZS_Now
	EndIf

	ZS_Snapshot_Reset($l_i_Count)
	$g_i_ZS_MyID = $l_i_MyID

	Local $l_m_IDs[]
	Local $l_i_Flags, $l_i_ID, $l_i_Skill
	For $i = 1 To $l_i_Count
		$l_i_ID = $l_ax_Rows[$i][$GC_ZS_R_ID]
		$l_i_Skill = $l_ax_Rows[$i][$GC_ZS_R_Skill]
		$l_m_IDs[$l_i_ID] = True

		$l_i_Flags = ZS_Read_AgentFlags($l_ax_Rows, $i)
		If $g_b_ZS_ReadVisibleEffects Then $l_i_Flags = BitOR($l_i_Flags, ZS_Read_VisibleFlags($l_ax_Rows[$i][$GC_ZS_R_Ptr]))

		$g_amx2_ZS_Agent[$i][$GC_ZS_A_ID] = $l_i_ID
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_X] = $l_ax_Rows[$i][$GC_ZS_R_X]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Y] = $l_ax_Rows[$i][$GC_ZS_R_Y]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_HP] = $l_ax_Rows[$i][$GC_ZS_R_HP]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_MaxHP] = $l_ax_Rows[$i][$GC_ZS_R_MaxHP]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_HPPips] = $l_ax_Rows[$i][$GC_ZS_R_HPPips]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Allegiance] = $l_ax_Rows[$i][$GC_ZS_R_Allegiance]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags] = $l_i_Flags
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Skill] = $l_i_Skill
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_CastMs] = ZS_Perception_TrackCast($l_i_ID, $l_i_Skill)
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Primary] = $l_ax_Rows[$i][$GC_ZS_R_Primary]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Secondary] = $l_ax_Rows[$i][$GC_ZS_R_Secondary]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Model] = $l_ax_Rows[$i][$GC_ZS_R_PlayerNumber]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_WeaponType] = $l_ax_Rows[$i][$GC_ZS_R_WeaponType]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Level] = $l_ax_Rows[$i][$GC_ZS_R_Level]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_LastStrike] = $l_ax_Rows[$i][$GC_ZS_R_LastStrike]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_RotCos] = $l_ax_Rows[$i][$GC_ZS_R_RotCos]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_RotSin] = $l_ax_Rows[$i][$GC_ZS_R_RotSin]
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_DmgRate] = ZS_Perception_TrackDamage($l_i_ID, $g_amx2_ZS_Agent[$i][$GC_ZS_A_HP], BitAND($l_i_Flags, $GC_ZS_AF_DEAD) <> 0)
	Next

	; --- player ---
	$g_f_ZS_MaxEnergy = $l_ax_Rows[$l_i_Me][$GC_ZS_R_MaxEnergy]
	$g_f_ZS_Energy = $l_ax_Rows[$l_i_Me][$GC_ZS_R_EnergyPercent] * $g_f_ZS_MaxEnergy
	$g_i_ZS_EnergyPips = $l_ax_Rows[$l_i_Me][$GC_ZS_R_EnergyRegen]
	$g_i_ZS_Overcast = $l_ax_Rows[$l_i_Me][$GC_ZS_R_Overcast]
	; --- weapon set in hand (the sets themselves are read once per instance) ---
	ZS_Weapon_Perceive($l_ax_Rows[$l_i_Me][$GC_ZS_R_WeaponItemId], $l_ax_Rows[$l_i_Me][$GC_ZS_R_OffhandItemId], $l_b_NewInstance)

	; --- effects (the client only knows them for the party) and the bonds the player keeps up ---
	ZS_Read_EffectsAndBonds($l_i_MyID, $l_m_IDs)

	; --- item in hand: an urn is ours only if we cast an item spell recently (never touch a quest bundle) ---
	$g_i_ZS_BundleItem = Item_GetInventoryInfo("BundleItemID")
	$g_i_ZS_HeldUrn = 0
	If $g_i_ZS_BundleItem <> 0 And $g_i_ZS_LastUrnSkill <> 0 And $g_i_ZS_Now - $g_i_ZS_LastUrnAt <= 300000 Then $g_i_ZS_HeldUrn = $g_i_ZS_LastUrnSkill
	If $g_i_ZS_BundleItem = 0 Then $g_i_ZS_LastUrnSkill = 0

	; --- skill bar ---
	ZS_Read_Skillbar()

	ZS_Snapshot_Finalize()
	Return True
EndFunc   ;==>ZS_Perceive

;~ Description: ms since $a_i_AgentID was first seen activating $a_i_SkillID (0 on the first tick).
Func ZS_Perception_TrackCast($a_i_AgentID, $a_i_SkillID)
	If $a_i_SkillID = 0 Then
		If MapExists($g_m_ZS_CastSkill, $a_i_AgentID) Then
			MapRemove($g_m_ZS_CastSkill, $a_i_AgentID)
			MapRemove($g_m_ZS_CastStart, $a_i_AgentID)
		EndIf
		Return 0
	EndIf
	If MapExists($g_m_ZS_CastSkill, $a_i_AgentID) And $g_m_ZS_CastSkill[$a_i_AgentID] = $a_i_SkillID Then
		Return $g_i_ZS_Now - $g_m_ZS_CastStart[$a_i_AgentID]
	EndIf
	$g_m_ZS_CastSkill[$a_i_AgentID] = $a_i_SkillID
	$g_m_ZS_CastStart[$a_i_AgentID] = $g_i_ZS_Now
	Return 0
EndFunc   ;==>ZS_Perception_TrackCast


;~ Description: Smoothed health loss of an agent, in fraction of its max health per second.
;~ Counts every source (melee, arrows, spells, degeneration) since it only looks at the health going down.
Func ZS_Perception_TrackDamage($a_i_AgentID, $a_f_HP, $a_b_Dead)
	If $a_b_Dead Then
		If MapExists($g_m_ZS_HpPrev, $a_i_AgentID) Then
			MapRemove($g_m_ZS_HpPrev, $a_i_AgentID)
			MapRemove($g_m_ZS_HpTime, $a_i_AgentID)
			MapRemove($g_m_ZS_DmgRate, $a_i_AgentID)
		EndIf
		Return 0
	EndIf
	If Not MapExists($g_m_ZS_HpPrev, $a_i_AgentID) Then
		$g_m_ZS_HpPrev[$a_i_AgentID] = $a_f_HP
		$g_m_ZS_HpTime[$a_i_AgentID] = $g_i_ZS_Now
		$g_m_ZS_DmgRate[$a_i_AgentID] = 0
		Return 0
	EndIf

	Local $l_f_Rate = $g_m_ZS_DmgRate[$a_i_AgentID]
	Local $l_i_Dt = $g_i_ZS_Now - $g_m_ZS_HpTime[$a_i_AgentID]
	If $l_i_Dt <= 0 Then Return $l_f_Rate

	; Instant rate over the last interval (heals count as no loss), blended so that ~1 s of history weighs in
	Local $l_f_Loss = $g_m_ZS_HpPrev[$a_i_AgentID] - $a_f_HP
	If $l_f_Loss < 0 Then $l_f_Loss = 0
	Local $l_f_Instant = $l_f_Loss / $l_i_Dt * 1000
	Local $l_f_Alpha = $l_i_Dt / 1000
	If $l_f_Alpha > 1 Then $l_f_Alpha = 1
	$l_f_Rate += $l_f_Alpha * ($l_f_Instant - $l_f_Rate)

	$g_m_ZS_HpPrev[$a_i_AgentID] = $a_f_HP
	$g_m_ZS_HpTime[$a_i_AgentID] = $g_i_ZS_Now
	$g_m_ZS_DmgRate[$a_i_AgentID] = $l_f_Rate
	Return $l_f_Rate
EndFunc   ;==>ZS_Perception_TrackDamage

;~ Description: Drop what was remembered between ticks (new instance: agent IDs are reused).
Func ZS_Perception_ForgetTracking()
	Local $l_m_Empty[]
	$g_m_ZS_CastSkill = $l_m_Empty
	$g_m_ZS_CastStart = $l_m_Empty
	$g_m_ZS_HpPrev = $l_m_Empty
	$g_m_ZS_HpTime = $l_m_Empty
	$g_m_ZS_DmgRate = $l_m_Empty
	$g_m_ZS_SeenSpirit = $l_m_Empty
	$g_m_ZS_SpiritOf = $l_m_Empty
	$g_i_ZS_PendingSpirit = 0
	$g_i_ZS_LastUrnSkill = 0
	$g_m_ZS_Recent = $l_m_Empty
	$g_i_ZS_LastFoeTarget = 0
	$g_i_ZS_AttackTarget = 0
	$g_i_ZS_CalledTarget = 0
EndFunc   ;==>ZS_Perception_ForgetTracking
#EndRegion Build from the game

#Region Snapshot container
;~ Description: Empty snapshot able to hold $a_i_AgentCount agents.
Func ZS_Snapshot_Reset($a_i_AgentCount)
	Global $g_amx2_ZS_Agent[$a_i_AgentCount + 1][$GC_ZS_A_COUNT]
	Global $g_amx2_ZS_Fx[1][$GC_ZS_FX_COUNT]
	Global $g_amx2_ZS_Bond[1][2]
	$g_i_ZS_AgentCount = $a_i_AgentCount
	$g_i_ZS_FxCount = 0
	$g_i_ZS_BondCount = 0
	$g_i_ZS_MeIdx = 0
EndFunc   ;==>ZS_Snapshot_Reset

;~ Description: Compute what depends on the whole snapshot. Call once agents, effects and $g_i_ZS_MyID are set.
Func ZS_Snapshot_Finalize()
	Local $l_m_Map[]
	For $i = 1 To $g_i_ZS_AgentCount
		$l_m_Map[$g_amx2_ZS_Agent[$i][$GC_ZS_A_ID]] = $i
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Near240] = -1
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Near312] = -1
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Threat] = -1
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_AimIdx] = -1
	Next
	$g_m_ZS_IdToIdx = $l_m_Map
	$g_i_ZS_MeIdx = ZS_IdxOf($g_i_ZS_MyID)
	If $g_i_ZS_MeIdx = 0 Then Return False

	; The pet: from the game's pet list, or from the "pet" flag of a test snapshot
	$g_i_ZS_PetIdx = ($g_i_ZS_PetID <> 0 ? ZS_IdxOf($g_i_ZS_PetID) : 0)
	For $i = 1 To $g_i_ZS_AgentCount
		If $i = $g_i_ZS_PetIdx Then
			$g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags] = BitOR($g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags], $GC_ZS_AF_PET)
		ElseIf BitAND($g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags], $GC_ZS_AF_PET) Then
			If $g_i_ZS_PetID = 0 And $g_i_ZS_PetIdx = 0 Then
				$g_i_ZS_PetIdx = $i
			Else
				$g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags] -= $GC_ZS_AF_PET
			EndIf
		EndIf
	Next

	Local $l_f_MX = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_X], $l_f_MY = $g_amx2_ZS_Agent[$g_i_ZS_MeIdx][$GC_ZS_A_Y]
	Local $l_f_DX, $l_f_DY
	For $i = 1 To $g_i_ZS_AgentCount
		$l_f_DX = $g_amx2_ZS_Agent[$i][$GC_ZS_A_X] - $l_f_MX
		$l_f_DY = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Y] - $l_f_MY
		$g_amx2_ZS_Agent[$i][$GC_ZS_A_Dist] = Sqrt($l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY)
	Next

	Local $l_m_Self[], $l_m_SelfLvl[], $l_m_SelfAge[]
	For $i = 0 To $g_i_ZS_FxCount - 1
		If $g_amx2_ZS_Fx[$i][$GC_ZS_FX_AgentID] = $g_i_ZS_MyID Then
			$l_m_Self[$g_amx2_ZS_Fx[$i][$GC_ZS_FX_SkillID]] = $g_amx2_ZS_Fx[$i][$GC_ZS_FX_RemainMs]
			$l_m_SelfLvl[$g_amx2_ZS_Fx[$i][$GC_ZS_FX_SkillID]] = $g_amx2_ZS_Fx[$i][$GC_ZS_FX_Level]
			$l_m_SelfAge[$g_amx2_ZS_Fx[$i][$GC_ZS_FX_SkillID]] = $g_amx2_ZS_Fx[$i][$GC_ZS_FX_Age]
		EndIf
	Next
	$g_m_ZS_SelfFxAge = $l_m_SelfAge
	; Every bond is an enchantment the player keeps up: count it, and remember the skill can be kept up
	For $k = 0 To $g_i_ZS_BondCount - 1
		$g_m_ZS_Maintainable[$g_amx2_ZS_Bond[$k][0]] = True
	Next
	$g_m_ZS_SelfFx = $l_m_Self
	$g_m_ZS_SelfFxLvl = $l_m_SelfLvl
	$g_i_ZS_MaintainedCount = $g_i_ZS_BondCount

	ZS_Snapshot_TrackSpirits()
	$g_b_ZS_InCombat = ZS_Snapshot_DetectCombat()
	ZS_Weapon_ComputeHome()
	Return True
EndFunc   ;==>ZS_Snapshot_Finalize

;~ Description: Bind the spirit that just appeared next to the player to the ritual that was just cast.
;~ The game does not say which spirit a ritual created: the first new allied spirit within 350, shortly after the cast, is it.
Func ZS_Snapshot_TrackSpirits()
	Local $l_b_Pending = ($g_i_ZS_PendingSpirit <> 0 And $g_i_ZS_Now <= $g_i_ZS_PendingSpiritUntil)
	Local $l_i_ID
	For $i = 1 To $g_i_ZS_AgentCount
		If $g_amx2_ZS_Agent[$i][$GC_ZS_A_Allegiance] <> $GC_I_ALLEGIANCE_SPIRIT Then ContinueLoop
		If BitAND($g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags], $GC_ZS_AF_DEAD + $GC_ZS_AF_PET) Then ContinueLoop
		$l_i_ID = $g_amx2_ZS_Agent[$i][$GC_ZS_A_ID]
		If MapExists($g_m_ZS_SeenSpirit, $l_i_ID) Then ContinueLoop
		$g_m_ZS_SeenSpirit[$l_i_ID] = True
		If $l_b_Pending And $g_amx2_ZS_Agent[$i][$GC_ZS_A_Dist] <= 350 Then
			$g_m_ZS_SpiritOf[$g_i_ZS_PendingSpirit] = $l_i_ID
			$g_i_ZS_PendingSpirit = 0
			$l_b_Pending = False
		EndIf
	Next
	If $g_i_ZS_PendingSpirit <> 0 And Not $l_b_Pending Then $g_i_ZS_PendingSpirit = 0
EndFunc   ;==>ZS_Snapshot_TrackSpirits

;~ Description: True when a living foe is within aggro range of the player, or close to an ally that stands near the player.
Func ZS_Snapshot_DetectCombat()
	Local $l_f_Aggro = $g_f_ZS_AggroRange
	Local $l_f_AllySq = $GC_I_RANGE_EARSHOT * $GC_I_RANGE_EARSHOT
	Local $l_f_DX, $l_f_DY
	For $i = 1 To $g_i_ZS_AgentCount
		If Not ZS_IsFoe($i) Then ContinueLoop
		If $g_amx2_ZS_Agent[$i][$GC_ZS_A_Dist] <= $l_f_Aggro Then Return True
		For $j = 1 To $g_i_ZS_AgentCount
			If Not ZS_IsAlly($j) Then ContinueLoop
			If $g_amx2_ZS_Agent[$j][$GC_ZS_A_Dist] > $l_f_Aggro Then ContinueLoop
			$l_f_DX = $g_amx2_ZS_Agent[$i][$GC_ZS_A_X] - $g_amx2_ZS_Agent[$j][$GC_ZS_A_X]
			$l_f_DY = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Y] - $g_amx2_ZS_Agent[$j][$GC_ZS_A_Y]
			If $l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY <= $l_f_AllySq Then Return True
		Next
	Next
	Return False
EndFunc   ;==>ZS_Snapshot_DetectCombat
#EndRegion Snapshot container

#Region Accessors (pure)
Func ZS_IdxOf($a_i_AgentID)
	If MapExists($g_m_ZS_IdToIdx, $a_i_AgentID) Then Return $g_m_ZS_IdToIdx[$a_i_AgentID]
	Return 0
EndFunc   ;==>ZS_IdxOf

Func ZS_Is($a_i_Idx, $a_i_Flag)
	Return BitAND($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Flags], $a_i_Flag) <> 0
EndFunc   ;==>ZS_Is

;~ Description: Living enemy.
Func ZS_IsFoe($a_i_Idx)
	If $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Allegiance] <> $GC_I_ALLEGIANCE_ENEMY Then Return False
	Return BitAND($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Flags], $GC_ZS_AF_DEAD) = 0
EndFunc   ;==>ZS_IsFoe

;~ Description: Living ally that is neither the player nor a spawned creature.
Func ZS_IsAlly($a_i_Idx)
	If $a_i_Idx = $g_i_ZS_MeIdx Then Return False
	If $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Allegiance] <> $GC_I_ALLEGIANCE_ALLY Then Return False
	Return BitAND($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Flags], $GC_ZS_AF_DEAD + $GC_ZS_AF_SPAWNED) = 0
EndFunc   ;==>ZS_IsAlly

;~ Description: Dead ally that can be resurrected.
Func ZS_IsDeadAlly($a_i_Idx)
	If $a_i_Idx = $g_i_ZS_MeIdx Then Return False
	If $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Allegiance] <> $GC_I_ALLEGIANCE_ALLY Then Return False
	Local $l_i_Flags = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Flags]
	Return BitAND($l_i_Flags, $GC_ZS_AF_DEAD) <> 0 And BitAND($l_i_Flags, $GC_ZS_AF_SPAWNED) = 0
EndFunc   ;==>ZS_IsDeadAlly

;~ Description: Remaining ms of $a_i_SkillID on the agent, 0 when it does not have it (or is not a party member).
;~ An enchantment the player keeps up on that agent counts as never ending ($GC_ZS_FX_MAINTAINED).
Func ZS_FxRemain($a_i_AgentID, $a_i_SkillID)
	If ZS_KeepsUp($a_i_SkillID, $a_i_AgentID) Then Return $GC_ZS_FX_MAINTAINED
	If $a_i_AgentID = $g_i_ZS_MyID Then
		If MapExists($g_m_ZS_SelfFx, $a_i_SkillID) Then Return $g_m_ZS_SelfFx[$a_i_SkillID]
		Return 0
	EndIf
	For $i = 0 To $g_i_ZS_FxCount - 1
		If $g_amx2_ZS_Fx[$i][$GC_ZS_FX_SkillID] = $a_i_SkillID And $g_amx2_ZS_Fx[$i][$GC_ZS_FX_AgentID] = $a_i_AgentID Then Return $g_amx2_ZS_Fx[$i][$GC_ZS_FX_RemainMs]
	Next
	Return 0
EndFunc   ;==>ZS_FxRemain

;~ Description: True when the player keeps up $a_i_SkillID on $a_i_AgentID (-1 = on anyone).
;~ A bond on the player itself may carry target 0.
Func ZS_KeepsUp($a_i_SkillID, $a_i_AgentID = -1)
	For $k = 0 To $g_i_ZS_BondCount - 1
		If $g_amx2_ZS_Bond[$k][0] <> $a_i_SkillID Then ContinueLoop
		If $a_i_AgentID = -1 Or $g_amx2_ZS_Bond[$k][1] = $a_i_AgentID Then Return True
		If $a_i_AgentID = $g_i_ZS_MyID And $g_amx2_ZS_Bond[$k][1] = 0 Then Return True
	Next
	Return False
EndFunc   ;==>ZS_KeepsUp

Func ZS_SelfHasFx($a_i_SkillID)
	Return MapExists($g_m_ZS_SelfFx, $a_i_SkillID)
EndFunc   ;==>ZS_SelfHasFx

;~ Description: Strength of an effect on the player at its attribute level (Scale, or BonusScale when $a_b_Bonus).
;~ Computed from the offline table: 0 when the player does not have the effect.
Func ZS_SelfFxScale($a_i_SkillID, $a_b_Bonus = False)
	If Not MapExists($g_m_ZS_SelfFxLvl, $a_i_SkillID) Then Return 0
	Local $l_i_Lvl = $g_m_ZS_SelfFxLvl[$a_i_SkillID]
	Local $l_i_C0 = ($a_b_Bonus ? $GC_I_SKILL_BONUS_SCALE_0 : $GC_I_SKILL_SCALE_0)
	Local $l_i_C15 = ($a_b_Bonus ? $GC_I_SKILL_BONUS_SCALE_15 : $GC_I_SKILL_SCALE_15)
	Local $l_f_S0 = ZS_SkillData($a_i_SkillID, $l_i_C0), $l_f_S15 = ZS_SkillData($a_i_SkillID, $l_i_C15)
	Return Floor($l_f_S0 + ($l_f_S15 - $l_f_S0) / 15 * $l_i_Lvl)
EndFunc   ;==>ZS_SelfFxScale

;~ Description: Number of OTHER living agents of the same side as $a_i_Idx within $a_f_Radius of it.
;~ Radii 240 and 312 are cached for the tick.
Func ZS_CountSameSideNear($a_i_Idx, $a_f_Radius)
	Local $l_i_Col = -1
	If $a_f_Radius = 240 Then $l_i_Col = $GC_ZS_A_Near240
	If $a_f_Radius = 312 Then $l_i_Col = $GC_ZS_A_Near312
	If $l_i_Col >= 0 And $g_amx2_ZS_Agent[$a_i_Idx][$l_i_Col] >= 0 Then Return $g_amx2_ZS_Agent[$a_i_Idx][$l_i_Col]

	Local $l_b_FoeSide = ($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Allegiance] = $GC_I_ALLEGIANCE_ENEMY)
	Local $l_i_Count = ZS_CountAround($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_X], $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Y], $a_f_Radius, $l_b_FoeSide, $a_i_Idx)
	If $l_i_Col >= 0 Then $g_amx2_ZS_Agent[$a_i_Idx][$l_i_Col] = $l_i_Count
	Return $l_i_Count
EndFunc   ;==>ZS_CountSameSideNear

;~ Description: Living foes ($a_b_Foes) or living allies incl. the player (Not $a_b_Foes) within $a_f_Radius of a point.
Func ZS_CountAround($a_f_X, $a_f_Y, $a_f_Radius, $a_b_Foes, $a_i_ExceptIdx = 0)
	Local $l_f_Sq = $a_f_Radius * $a_f_Radius, $l_f_DX, $l_f_DY, $l_i_Count = 0
	For $i = 1 To $g_i_ZS_AgentCount
		If $i = $a_i_ExceptIdx Then ContinueLoop
		If $a_b_Foes Then
			If Not ZS_IsFoe($i) Then ContinueLoop
		Else
			If $i <> $g_i_ZS_MeIdx And Not ZS_IsAlly($i) Then ContinueLoop
			If BitAND($g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags], $GC_ZS_AF_DEAD) Then ContinueLoop
		EndIf
		$l_f_DX = $g_amx2_ZS_Agent[$i][$GC_ZS_A_X] - $a_f_X
		$l_f_DY = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Y] - $a_f_Y
		If $l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY <= $l_f_Sq Then $l_i_Count += 1
	Next
	Return $l_i_Count
EndFunc   ;==>ZS_CountAround

;~ Description: 0..1 pressure on an agent of our side. Cached for the tick. Adds up:
;~   - foes in its face (within 300): 0.25 each when attacking, 0.1 otherwise
;~   - foes at range that attack or cast while FACING it: 0.2 each (the game gives no attack target, the facing is the best clue)
;~   - the health it is losing per second, whatever the source (up to 0.6 at 12 % per second)
;~   - degeneration and low health
Func ZS_Threat($a_i_Idx)
	If $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Threat] >= 0 Then Return $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Threat]

	Local $l_f_Threat = 0
	Local $l_f_X = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_X], $l_f_Y = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Y]
	Local $l_f_MeleeSq = 300 * 300, $l_f_RangedSq = 1350 * 1350
	Local $l_f_DX, $l_f_DY, $l_f_DistSq, $l_i_Flags
	For $i = 1 To $g_i_ZS_AgentCount
		If Not ZS_IsFoe($i) Then ContinueLoop
		$l_f_DX = $l_f_X - $g_amx2_ZS_Agent[$i][$GC_ZS_A_X]
		$l_f_DY = $l_f_Y - $g_amx2_ZS_Agent[$i][$GC_ZS_A_Y]
		$l_f_DistSq = $l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY
		$l_i_Flags = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags]
		If $l_f_DistSq <= $l_f_MeleeSq Then
			$l_f_Threat += (BitAND($l_i_Flags, $GC_ZS_AF_ATTACKING) ? 0.25 : 0.1)
		ElseIf $l_f_DistSq <= $l_f_RangedSq And BitAND($l_i_Flags, $GC_ZS_AF_ATTACKING + $GC_ZS_AF_CASTING) Then
			If ZS_AimOf($i) = $a_i_Idx Then $l_f_Threat += 0.2
		EndIf
	Next
	$l_f_Threat += 0.6 * ZS_Ramp01($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_DmgRate], 0.02, 0.12)
	If $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_HPPips] < 0 Then $l_f_Threat += 0.05 * Abs($g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_HPPips])
	If $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_HP] < 0.5 Then $l_f_Threat += 0.2
	If $l_f_Threat > 1 Then $l_f_Threat = 1

	$g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Threat] = $l_f_Threat
	Return $l_f_Threat
EndFunc   ;==>ZS_Threat

;~ Description: Row of the agent of our side (player, allies, minions, spirits) that foe $a_i_FoeIdx faces best,
;~ within 1350 and $g_f_ZS_FacingCos. 0 when it faces none of us. Cached for the tick.
;~ The game gives no attack target: when two of us stand in the same direction, the best aligned one takes it.
Func ZS_AimOf($a_i_FoeIdx)
	If $g_amx2_ZS_Agent[$a_i_FoeIdx][$GC_ZS_A_AimIdx] >= 0 Then Return $g_amx2_ZS_Agent[$a_i_FoeIdx][$GC_ZS_A_AimIdx]

	Local $l_i_Best = 0
	Local $l_f_Cos = $g_amx2_ZS_Agent[$a_i_FoeIdx][$GC_ZS_A_RotCos], $l_f_Sin = $g_amx2_ZS_Agent[$a_i_FoeIdx][$GC_ZS_A_RotSin]
	If $l_f_Cos <> 0 Or $l_f_Sin <> 0 Then ; 0, 0 = facing unknown
		Local $l_f_BestDot = $g_f_ZS_FacingCos
		Local $l_f_FX = $g_amx2_ZS_Agent[$a_i_FoeIdx][$GC_ZS_A_X], $l_f_FY = $g_amx2_ZS_Agent[$a_i_FoeIdx][$GC_ZS_A_Y]
		Local $l_f_DX, $l_f_DY, $l_f_Dist, $l_f_Dot, $l_i_All
		For $i = 1 To $g_i_ZS_AgentCount
			$l_i_All = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Allegiance]
			If $l_i_All <> $GC_I_ALLEGIANCE_ALLY And $l_i_All <> $GC_I_ALLEGIANCE_MINION And $l_i_All <> $GC_I_ALLEGIANCE_SPIRIT Then ContinueLoop
			If BitAND($g_amx2_ZS_Agent[$i][$GC_ZS_A_Flags], $GC_ZS_AF_DEAD) Then ContinueLoop
			$l_f_DX = $g_amx2_ZS_Agent[$i][$GC_ZS_A_X] - $l_f_FX
			$l_f_DY = $g_amx2_ZS_Agent[$i][$GC_ZS_A_Y] - $l_f_FY
			$l_f_Dist = Sqrt($l_f_DX * $l_f_DX + $l_f_DY * $l_f_DY)
			If $l_f_Dist <= 0 Or $l_f_Dist > 1350 Then ContinueLoop
			$l_f_Dot = ($l_f_DX * $l_f_Cos + $l_f_DY * $l_f_Sin) / $l_f_Dist
			If $l_f_Dot >= $l_f_BestDot Then
				$l_f_BestDot = $l_f_Dot
				$l_i_Best = $i
			EndIf
		Next
	EndIf
	$g_amx2_ZS_Agent[$a_i_FoeIdx][$GC_ZS_A_AimIdx] = $l_i_Best
	Return $l_i_Best
EndFunc   ;==>ZS_AimOf

;~ Description: 0 below $a_f_From, 1 above $a_f_To, linear in between.
Func ZS_Ramp01($a_f_X, $a_f_From, $a_f_To)
	If $a_f_X <= $a_f_From Then Return 0
	If $a_f_X >= $a_f_To Then Return 1
	Return ($a_f_X - $a_f_From) / ($a_f_To - $a_f_From)
EndFunc   ;==>ZS_Ramp01

;~ Description: True when the model of the agent is in $a_v_Models (single value or array).
Func ZS_ModelIn($a_i_Idx, $a_v_Models)
	Local $l_i_Model = $g_amx2_ZS_Agent[$a_i_Idx][$GC_ZS_A_Model]
	If IsArray($a_v_Models) Then
		For $i = 0 To UBound($a_v_Models) - 1
			If $a_v_Models[$i] = $l_i_Model Then Return True
		Next
		Return False
	EndIf
	Return $a_v_Models <> 0 And $a_v_Models = $l_i_Model
EndFunc   ;==>ZS_ModelIn
#EndRegion Accessors (pure)
