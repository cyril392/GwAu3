#include-once

Func Anti_Shout()
	If UAI_PlayerHasEffect($GC_I_SKILL_ID_CACOPHONY) Then
		If Effect_GetEffectArg($GC_I_SKILL_ID_CACOPHONY, "Scale") > (UAI_GetPlayerInfo($GC_UAI_AGENT_CurrentHP) + 50) Then Return True
	EndIf
	If UAI_PlayerHasEffect($GC_I_SKILL_ID_VOCAL_MINORITY) Then Return True
	If UAI_PlayerHasEffect($GC_I_SKILL_ID_WELL_OF_SILENCE) Then Return True
	Return False
EndFunc   ;==>Anti_Shout

Func CanUse_ToTheLimit()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ToTheLimit

Func BestTarget_ToTheLimit($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ToTheLimit

Func CanUse_IWillAvengeYou()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_IWillAvengeYou

Func BestTarget_IWillAvengeYou($a_f_AggroRange)
	; Description
	; Shout. For each dead ally, you gain 10 seconds of +3...6...7 Health regeneration and your attack speed increases by 25%.
	; Concise description
	; Shout. You have +3...6...7 Health regeneration and attack 25% faster (10 seconds for each dead ally).
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_IWillAvengeYou

Func CanUse_ForGreatJustice()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ForGreatJustice

Func BestTarget_ForGreatJustice($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ForGreatJustice

Func CanUse_WatchYourself()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_WatchYourself

Func BestTarget_WatchYourself($a_f_AggroRange)
	; Description
	; Shout. Party members within earshot gain +5...21...25 armor for 10 seconds. This shout ends after 10 incoming attacks.
	; Concise description
	; Shout. (10 seconds.) Party members in earshot have +5...21...25 armor. Ends after 10 incoming attacks.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_WatchYourself

Func CanUse_Charge()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_Charge

Func BestTarget_Charge($a_f_AggroRange)
	; Description
	; Elite Shout. Allies in earshot lose the Crippled condition. For 5...11...13 seconds, these allies move 33% faster.
	; Concise description
	; Elite Shout. (5...11...13 seconds.) Allies in earshot move 33% faster. Initial effect: these allies lose the Crippled condition.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_Charge

Func CanUse_VictoryIsMine()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_VictoryIsMine

Func BestTarget_VictoryIsMine($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_VictoryIsMine

Func CanUse_FearMe()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_FearMe

Func BestTarget_FearMe($a_f_AggroRange)
	; Description
	; Shout. All nearby foes lose 1...3...4 Energy. For 1...12...15 second[s], your melee attacks gain +5...25...30% chance of a critical hit against stationary foes.
	; Concise description
	; Shout. (1...12...15 second[s].) You have +5...25...30% chance of a critical hit with melee attacks against stationary foes. Initial effect: nearby foes lose 1...3...4 Energy.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_FearMe

Func CanUse_ShieldsUp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ShieldsUp

Func BestTarget_ShieldsUp($a_f_AggroRange)
	; Description
	; Shout. For 5...10...11 seconds, you and all party members within earshot gain +60 armor against incoming projectile attacks.
	; Concise description
	; Shout. (5...10...11 seconds.) Party members in earshot have +60 armor against projectile attacks.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ShieldsUp

Func CanUse_IWillSurvive()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_IWillSurvive

Func BestTarget_IWillSurvive($a_f_AggroRange)
	; Description
	; Shout. You gain +3 Health regeneration for each condition you are suffering. This regeneration expires after 5...10...11 seconds.
	; Concise description
	; Shout. (5...10...11 seconds.) You have +3 Health regeneration for each condition on you.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_IWillSurvive

Func CanUse_DontBelieveTheirLies()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_DontBelieveTheirLies

Func BestTarget_DontBelieveTheirLies($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_DontBelieveTheirLies

Func CanUse_CallOfFerocity()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfFerocity

Func BestTarget_CallOfFerocity($a_f_AggroRange)
	; Description
	; Ranger
	; Concise description
	; green; font-weight: bold;">5%...50%
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfFerocity

Func CanUse_CallOfProtection()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfProtection

Func BestTarget_CallOfProtection($a_f_AggroRange)
	; Description
	; Shout. For 120 seconds, your animal companion has a 5...17...20 base damage reduction.
	; Concise description
	; Shout. (120 seconds.) Your pet has 5...17...20 damage reduction.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfProtection

Func CanUse_CallOfElementalProtection()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfElementalProtection

Func BestTarget_CallOfElementalProtection($a_f_AggroRange)
	; Description
	; Ranger
	; Concise description
	; green; font-weight: bold;">1...11...14
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfElementalProtection

Func CanUse_CallOfVitality()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfVitality

Func BestTarget_CallOfVitality($a_f_AggroRange)
	; Description
	; Ranger
	; Concise description
	; green; font-weight: bold;">1...11...14
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfVitality

Func CanUse_CallOfHaste()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfHaste

Func BestTarget_CallOfHaste($a_f_AggroRange)
	; Description
	; Shout. For 30 seconds, your animal companion has a 33% faster attack speed and moves 33% faster.
	; Concise description
	; Shout. (30 seconds.) Your pet moves and attacks 33% faster.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfHaste

Func CanUse_CallOfHealing()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfHealing

Func BestTarget_CallOfHealing($a_f_AggroRange)
	; Description
	; Ranger
	; Concise description
	; green; font-weight: bold;">1...11...14
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfHealing

Func CanUse_CallOfResilience()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfResilience

Func BestTarget_CallOfResilience($a_f_AggroRange)
	; Description
	; Ranger
	; Concise description
	; Trivia">edit
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfResilience

Func CanUse_CallOfFeeding()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfFeeding

Func BestTarget_CallOfFeeding($a_f_AggroRange)
	; Description
	; Ranger
	; Concise description
	; green; font-weight: bold;">1...11...14
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfFeeding

Func CanUse_CallOfTheHunter()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfTheHunter

Func BestTarget_CallOfTheHunter($a_f_AggroRange)
	; Description
	; Ranger
	; Concise description
	; green; font-weight: bold;">5...41...50
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfTheHunter

Func CanUse_CallOfBrutality()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfBrutality

Func BestTarget_CallOfBrutality($a_f_AggroRange)
	; Description
	; Ranger
	; Concise description
	; green; font-weight: bold;">5...41...50
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfBrutality

Func CanUse_CallOfDisruption()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfDisruption

Func BestTarget_CallOfDisruption($a_f_AggroRange)
	; Description
	; Ranger
	; Concise description
	; green; font-weight: bold;">5...41...50
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfDisruption

Func CanUse_SymbioticBond()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_SymbioticBond

Func BestTarget_SymbioticBond($a_f_AggroRange)
	; Description
	; Shout. For 120...264...300 seconds, your animal companion gains 1...3...3 Health regeneration, and half of all damage dealt to your animal companion is redirected to you.
	; Concise description
	; Shout. (120...264...300 seconds.) Your pet has +1...3...3 Health regeneration. Half of all damage dealt to your pet is redirected to you.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_SymbioticBond

Func CanUse_OtyughsCry()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_OtyughsCry

Func BestTarget_OtyughsCry($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_OtyughsCry

Func CanUse_Retreat()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_Retreat

Func BestTarget_Retreat($a_f_AggroRange)
	; Description
	; Shout. If there are any dead allies within earshot, your party moves 33% faster for 5...10...11 seconds.
	; Concise description
	; Shout. (5...10...11 seconds.) Party members in earshot move 33% faster. No effect unless there are dead allies within earshot.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_Retreat

Func CanUse_KilroyStonekin()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_KilroyStonekin

Func BestTarget_KilroyStonekin($a_f_AggroRange)
	; Description
	; This article is about the NPC. For the quest, see Kilroy Stonekin (quest).
	; Concise description
	; This article is about the NPC. For the quest, see Kilroy Stonekin (quest).
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_KilroyStonekin

Func CanUse_AimTrue()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_AimTrue

Func BestTarget_AimTrue($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_AimTrue

Func CanUse_Coward()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_Coward

Func BestTarget_Coward($a_f_AggroRange)
	; Description
	; Elite Shout. If target foe is moving, that foe is knocked down.
	; Concise description
	; Elite Shout. Causes knock-down if target foe is moving.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_Coward

Func CanUse_Headshot()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_Headshot

Func BestTarget_Headshot($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_Headshot

Func CanUse_NoneShallPass()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_NoneShallPass

Func BestTarget_NoneShallPass($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_NoneShallPass

Func CanUse_OnYourKnees()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_OnYourKnees

Func BestTarget_OnYourKnees($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_OnYourKnees

Func CanUse_RemoveWithHaste()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_RemoveWithHaste

Func BestTarget_RemoveWithHaste($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_RemoveWithHaste

Func CanUse_MmmmSnowcone()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_MmmmSnowcone

Func BestTarget_MmmmSnowcone($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_MmmmSnowcone

Func CanUse_LetsGetEm()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_LetsGetEm

Func BestTarget_LetsGetEm($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_LetsGetEm

Func CanUse_YouWillDie()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_YouWillDie

Func BestTarget_YouWillDie($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_YouWillDie

Func CanUse_SongOfTheMists()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_SongOfTheMists

Func BestTarget_SongOfTheMists($a_f_AggroRange)
	; Description
	; Shout. For 10 seconds, each nearby ally gains +6 Energy regeneration. If an ally successfully uses a skill, Song of The Mists ends and steals 20 Health from the nearest foe.
	; Concise description
	; Shout. (10 seconds.) +6 Energy regeneration to nearby allies. If an ally successfully uses a skill, Song of The Mists ends and steals 20 Health from the nearest foe.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_SongOfTheMists

Func CanUse_PredatoryBond()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_PredatoryBond

Func BestTarget_PredatoryBond($a_f_AggroRange)
	; Description
	; Shout. For 5...17...20 seconds, your animal companion attacks 25% faster and heals you for 1...25...31 Health with each successful attack.
	; Concise description
	; Shout. (5...17...20 seconds.) Your pet attacks 25% faster and you gain 1...25...31 Health whenever your pet makes a successful attack.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_PredatoryBond

Func CanUse_EchoingBanishment()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_EchoingBanishment

Func BestTarget_EchoingBanishment($a_f_AggroRange)
	; Description
	; Shout. Target foe is banished to the mists and his spirit bound to Shiro. If the Spirit Binder is destroyed, the spirit is freed.
	; Concise description
	; Shout. Target foe is banished to the mists and his spirit bound to Shiro. If the Spirit Binder is destroyed, the spirit is freed.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_EchoingBanishment

Func CanUse_YoureAllAlone()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_YoureAllAlone

Func BestTarget_YoureAllAlone($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_YoureAllAlone

Func CanUse_EnemiesMustDie()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_EnemiesMustDie

Func BestTarget_EnemiesMustDie($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_EnemiesMustDie

Func CanUse_StrikeAsOne()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_StrikeAsOne

Func BestTarget_StrikeAsOne($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_StrikeAsOne

Func CanUse_Godspeed()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_Godspeed

Func BestTarget_Godspeed($a_f_AggroRange)
	; Description
	; Shout. For 5...17...20 seconds, all allies within earshot move 25% faster while under the effects of an enchantment.
	; Concise description
	; Shout. (5...17...20 seconds.) Allies in earshot move 25% faster while enchanted.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_Godspeed

Func CanUse_GoForTheEyes()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_GoForTheEyes

Func BestTarget_GoForTheEyes($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_GoForTheEyes

Func CanUse_BraceYourself()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_BraceYourself

Func BestTarget_BraceYourself($a_f_AggroRange)
	; Description
	; Shout. For 5...13...15 seconds, the next time target other ally would be knocked down, all nearby foes take 15...63...75 damage instead.
	; Concise description
	; Shout. (5...13...15 seconds.) Prevents the next knock-down and deals 15...63...75 damage to all foes near target ally. Cannot self-target.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_BraceYourself

Func CanUse_StandYourGround()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_StandYourGround

Func BestTarget_StandYourGround($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_StandYourGround

Func CanUse_LeadTheWay()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_LeadTheWay

Func BestTarget_LeadTheWay($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_LeadTheWay

Func CanUse_MakeHaste()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_MakeHaste

Func BestTarget_MakeHaste($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_MakeHaste

Func CanUse_WeShallReturn()
	If Anti_Shout() Then Return False
	If UAI_PlayerHasEffect($GC_I_SKILL_ID_CURSE_OF_DHUUM) Or UAI_PlayerHasEffect($GC_I_SKILL_ID_FROZEN_SOIL) Then Return False
	Return True
EndFunc   ;==>CanUse_WeShallReturn

Func BestTarget_WeShallReturn($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_WeShallReturn

Func CanUse_NeverGiveUp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_NeverGiveUp

Func BestTarget_NeverGiveUp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_NeverGiveUp

Func CanUse_HelpMe()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_HelpMe

Func BestTarget_HelpMe($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_HelpMe

Func CanUse_FallBack()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_FallBack

Func BestTarget_FallBack($a_f_AggroRange)
	; Description
	; Shout. For 4...9...10 seconds, all allies within earshot gain 5...13...15 Health per second while moving and move 33% faster. "Fall Back!" ends on an ally affected by this shout when that ally successfully hits with an attack.
	; Concise description
	; Shout. (4...9...10 seconds.) Allies in earshot gain 5...13...15 Health per second while moving and move 33% faster. Ends for an ally if that ally hits with an attack.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_FallBack

Func CanUse_Incoming()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_Incoming

Func BestTarget_Incoming($a_f_AggroRange)
	; Description
	; Elite Shout. For 4...9...10 seconds, all allies within earshot move 33% faster, and gain 5...13...15 Health while moving.
	; Concise description
	; Elite Shout. (4...9...10 seconds) Allies in earshot move 33% faster and gain 5...13...15 Health while moving.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_Incoming

Func CanUse_TheyreOnFire()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_TheyreOnFire

Func BestTarget_TheyreOnFire($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_TheyreOnFire

Func CanUse_NeverSurrender()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_NeverSurrender

Func BestTarget_NeverSurrender($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_NeverSurrender

Func CanUse_ItsJustAFleshWound()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ItsJustAFleshWound

Func BestTarget_ItsJustAFleshWound($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ItsJustAFleshWound

Func CanUse_RemoveQueenWail()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_RemoveQueenWail

Func BestTarget_RemoveQueenWail($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_RemoveQueenWail

Func CanUse_QueenWail()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_QueenWail

Func BestTarget_QueenWail($a_f_AggroRange)
	; Description
	; Monster skill
	; Concise description
	; Trivia">edit
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_QueenWail

Func CanUse_MakeYourTime()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_MakeYourTime

Func BestTarget_MakeYourTime($a_f_AggroRange)
	; Description
	; Shout. You gain 1 strike of adrenaline for each party member within earshot (maximum 1...4...5 adrenaline).
	; Concise description
	; Shout. You gain one adrenaline (maximum 1...4...5) for each party member in earshot.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_MakeYourTime

Func CanUse_CantTouchThis()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CantTouchThis

Func BestTarget_CantTouchThis($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CantTouchThis

Func CanUse_FindTheirWeakness()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_FindTheirWeakness

Func BestTarget_FindTheirWeakness($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_FindTheirWeakness

Func CanUse_ThePowerIsYours()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ThePowerIsYours

Func BestTarget_ThePowerIsYours($a_f_AggroRange)
	; Description
	; Elite Shout. For 3 seconds, all allies within earshot gain 0...1...1 Energy regeneration.
	; Concise description
	; Elite Shout. (3 seconds.) Allies within earshot gain 0...1...1 Energy regeneration.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ThePowerIsYours

Func CanUse_ForgeTheWay()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ForgeTheWay

Func BestTarget_ForgeTheWay($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ForgeTheWay

Func CanUse_SteadyAim()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_SteadyAim

Func BestTarget_SteadyAim($a_f_AggroRange)
	; Description
	; Shout. For 10 seconds, the next time each ally within earshot throws a snowball, that snowball moves 100% faster.
	; Concise description
	; Shout. (10 seconds.) The next time each ally in earshot throws a snowball, that snowball moves 100% faster.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_SteadyAim

Func CanUse_SaveYourselvesLuxon()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_SaveYourselvesLuxon

Func BestTarget_SaveYourselvesLuxon($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_SaveYourselvesLuxon

Func CanUse_SaveYourselvesKurzick()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_SaveYourselvesKurzick

Func BestTarget_SaveYourselvesKurzick($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_SaveYourselvesKurzick

Func CanUse_IMeantToDoThat()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_IMeantToDoThat

Func BestTarget_IMeantToDoThat($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_IMeantToDoThat

Func CanUse_TheresNothingToFear()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_TheresNothingToFear

Func BestTarget_TheresNothingToFear($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_TheresNothingToFear

Func CanUse_SpiritRoar()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_SpiritRoar

Func BestTarget_SpiritRoar($a_f_AggroRange)
	; Description
	; Shout. This shout deals 50 holy damage to nearby foes, and 25 more holy damage to affected foes that have an enchantment on them.
	; Concise description
	; Shout. Deals 50 holy damage to nearby foes, and 25 more holy damage for each enchantment on them.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_SpiritRoar

Func CanUse_VolfenBloodlustCurseOfTheNornbear()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_VolfenBloodlustCurseOfTheNornbear

Func BestTarget_VolfenBloodlustCurseOfTheNornbear($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_VolfenBloodlustCurseOfTheNornbear

Func CanUse_RavenShriekAGateTooFar()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_RavenShriekAGateTooFar

Func BestTarget_RavenShriekAGateTooFar($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_RavenShriekAGateTooFar

Func CanUse_Tremor()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_Tremor

Func BestTarget_Tremor($a_f_AggroRange)
	; Description
	; Shout. All foes within earshot are knocked down for 4 seconds.
	; Concise description
	; Shout. Causes knock-down (4 seconds) to foes in earshot.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_Tremor

Func CanUse_ThunderingRoar()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ThunderingRoar

Func BestTarget_ThunderingRoar($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ThunderingRoar

Func CanUse_DontTrip()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_DontTrip

Func BestTarget_DontTrip($a_f_AggroRange)
	; Description
	; Shout. For 3...5 seconds, party members within earshot cannot be knocked down.
	; Concise description
	; Shout. (3...5 seconds.) Prevents knock-down; affects party members within earshot.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_DontTrip

Func CanUse_ByUralsHammer()
	If Anti_Shout() Then Return False
	If UAI_PlayerHasEffect($GC_I_SKILL_ID_CURSE_OF_DHUUM) Or UAI_PlayerHasEffect($GC_I_SKILL_ID_FROZEN_SOIL) Then Return False
	Return True
EndFunc   ;==>CanUse_ByUralsHammer

Func BestTarget_ByUralsHammer($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ByUralsHammer

Func CanUse_KraksCharge()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_KraksCharge

Func BestTarget_KraksCharge($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_KraksCharge

Func CanUse_StandUp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_StandUp

Func BestTarget_StandUp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_StandUp

Func CanUse_FinishHim()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_FinishHim

Func BestTarget_FinishHim($a_f_AggroRange)
	Local $l_i_TargetID = UAI_GetBestSingleTarget(-2, $a_f_AggroRange, $GC_UAI_AGENT_HP, "UAI_Filter_IsLivingEnemy|UAI_Filter_IsBelow50HP|UAI_Filter_NotIsDeepWounded")
	If $l_i_TargetID = 0 Then Return UAI_GetBestSingleTarget(-2, $a_f_AggroRange, $GC_UAI_AGENT_HP, "UAI_Filter_IsLivingEnemy|UAI_Filter_IsBelow50HP")
	Return $l_i_TargetID
EndFunc   ;==>BestTarget_FinishHim

Func CanUse_DodgeThis()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_DodgeThis

Func BestTarget_DodgeThis($a_f_AggroRange)
	; Description
	; Shout. For 16...20 seconds, your next attack cannot be blocked and does +14...20 damage.
	; Concise description
	; Shout. (16...20 seconds.) Your next attack is unblockable and deals +14...20 damage.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_DodgeThis

Func CanUse_IAmTheStrongest()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_IAmTheStrongest

Func BestTarget_IAmTheStrongest($a_f_AggroRange)
	; Description
	; Shout. Your next 5...8 attacks do an additional +14...20 damage.
	; Concise description
	; Shout. Your next 5...8 attacks deal +14...20 damage.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_IAmTheStrongest

Func CanUse_IAmUnstoppable()
	If Anti_Shout() Then Return False
	If UAI_GetPlayerInfo($GC_UAI_AGENT_IsCrippled) Or UAI_GetPlayerInfo($GC_UAI_AGENT_IsKnockedDown) Then Return True
	If UAI_GetPlayerInfo($GC_UAI_AGENT_HP) >= 0.95 Then Return False
	Return True
EndFunc   ;==>CanUse_IAmUnstoppable

Func BestTarget_IAmUnstoppable($a_f_AggroRange)
	; Description
	; Shout. For 16...20 seconds, you have +24 armor and cannot be knocked down or Crippled.
	; Concise description
	; Shout. (16...20 seconds.) You have +24 armor and cannot be knocked-down or Crippled.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_IAmUnstoppable

Func CanUse_YouMoveLikeADwarf()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_YouMoveLikeADwarf

Func BestTarget_YouMoveLikeADwarf($a_f_AggroRange)
	; Description
	; Shout. Target foe is knocked down and takes 44...80 damage. That foe is also Crippled for 8...15 seconds.
	; Concise description
	; Shout. Deals 44...80 damage, causes knock-down, and inflicts Crippled condition (8...15 seconds).

	; Priority 1: Monks (interrupt healers)
	Local $l_i_Target = UAI_GetBestSingleTarget(-2, $a_f_AggroRange, $GC_UAI_AGENT_HP, "UAI_Filter_IsLivingEnemy|UAI_Filter_IsMonk")
	If $l_i_Target <> 0 Then Return $l_i_Target

	; Priority 2: Casters (interrupt spellcasters)
	$l_i_Target = UAI_GetBestSingleTarget(-2, $a_f_AggroRange, $GC_UAI_AGENT_HP, "UAI_Filter_IsLivingEnemy|UAI_Filter_IsCaster")
	If $l_i_Target <> 0 Then Return $l_i_Target

	; Priority 3: Melee (War, Sin, Derv)
	$l_i_Target = UAI_GetBestSingleTarget(-2, $a_f_AggroRange, $GC_UAI_AGENT_HP, "UAI_Filter_IsLivingEnemy|UAI_Filter_IsMelee")
	If $l_i_Target <> 0 Then Return $l_i_Target

	; Fallback: Any enemy
	Return UAI_GetBestSingleTarget(-2, $a_f_AggroRange, $GC_UAI_AGENT_HP, "UAI_Filter_IsLivingEnemy")
EndFunc   ;==>BestTarget_YouMoveLikeADwarf

Func CanUse_YouAreAllWeaklings()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_YouAreAllWeaklings

Func BestTarget_YouAreAllWeaklings($a_f_AggroRange)
	; Description
	; Shout. Target foe and foes adjacent to target are Weakened for 8...12 seconds.
	; Concise description
	; Shout. Inflicts Weakness condition (8...12 seconds). Also affects adjacent foes.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_YouAreAllWeaklings

Func CanUse_UrsanRoar()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_UrsanRoar

Func BestTarget_UrsanRoar($a_f_AggroRange)
	; Description
	; Shout. For 2...5 seconds, all enemies within earshot are Weakened and all allies deal +5...15 damage per attack.
	; Concise description
	; Shout. (2...5 seconds) Inflicts Weakness condition to foes in earshot. Allies in earshot deal +5...15 damage per attack.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_UrsanRoar

Func CanUse_VolfenBloodlust()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_VolfenBloodlust

Func BestTarget_VolfenBloodlust($a_f_AggroRange)
	; Description
	; Shout. For 2...7 seconds, you and all nearby allies attack 33% faster.
	; Concise description
	; Shout. (2...7 seconds.) You and nearby allies attack 33% faster.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_VolfenBloodlust

Func CanUse_RavenShriek()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_RavenShriek

Func BestTarget_RavenShriek($a_f_AggroRange)
	; Description
	; Shout. Remove Blindness from all allies within earshot. Cause Blindness to nearby foes for 4...10 seconds.
	; Concise description
	; Shout. Removes Blindness from allies in earshot. Inflicts Blindness condition (4...10 seconds) to nearby enemies.
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_RavenShriek

Func CanUse_UrsanRoarBloodWashesBlood()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_UrsanRoarBloodWashesBlood

Func BestTarget_UrsanRoarBloodWashesBlood($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_UrsanRoarBloodWashesBlood

Func CanUse_DestroyTheHumans()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_DestroyTheHumans

Func BestTarget_DestroyTheHumans($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_DestroyTheHumans

Func CanUse_TengusMimicry()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_TengusMimicry

Func BestTarget_TengusMimicry($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_TengusMimicry

Func CanUse_CallOfHastePvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CallOfHastePvp

Func BestTarget_CallOfHastePvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CallOfHastePvp

Func CanUse_FormUpAndAdvance()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_FormUpAndAdvance

Func BestTarget_FormUpAndAdvance($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_FormUpAndAdvance

Func CanUse_Advance()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_Advance

Func BestTarget_Advance($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_Advance

Func CanUse_ForElona()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ForElona

Func BestTarget_ForElona($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ForElona

Func CanUse_CryOfMadness()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CryOfMadness

Func BestTarget_CryOfMadness($a_f_AggroRange)
	; Description
	; Elite Shout. Scream like a madman! Foes in the area lose 10 Energy and all adrenaline. For 10 seconds, allies within earshot move 25% faster and have +5 Health regeneration and +1 Energy regeneration.
	; Concise description
	; Elite Shout. Foes in the area lose 10 Energy and all adrenaline. Allies within earshot move 25% faster and have +5 Health regeneration and +1 Energy regeneration. (10 seconds.)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CryOfMadness

Func CanUse_MotivatingInsults()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_MotivatingInsults

Func BestTarget_MotivatingInsults($a_f_AggroRange)
	; Description
	; Monster
	; Concise description
	; Notes">edit
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_MotivatingInsults

Func CanUse_ItsGoodToBeKing()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ItsGoodToBeKing

Func BestTarget_ItsGoodToBeKing($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ItsGoodToBeKing

Func CanUse_MaddeningLaughter()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_MaddeningLaughter

Func BestTarget_MaddeningLaughter($a_f_AggroRange)
	; Description
	; Monster
	; Concise description
	; Related skills">edit
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_MaddeningLaughter

Func CanUse_WatchYourselfPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_WatchYourselfPvp

Func BestTarget_WatchYourselfPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_WatchYourselfPvp

Func CanUse_IncomingPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_IncomingPvp

Func BestTarget_IncomingPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_IncomingPvp

Func CanUse_NeverSurrenderPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_NeverSurrenderPvp

Func BestTarget_NeverSurrenderPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_NeverSurrenderPvp

Func CanUse_ForGreatJusticePvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_ForGreatJusticePvp

Func BestTarget_ForGreatJusticePvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_ForGreatJusticePvp

Func CanUse_GoForTheEyesPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_GoForTheEyesPvp

Func BestTarget_GoForTheEyesPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_GoForTheEyesPvp

Func CanUse_BraceYourselfPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_BraceYourselfPvp

Func BestTarget_BraceYourselfPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_BraceYourselfPvp

Func CanUse_CantTouchThisPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_CantTouchThisPvp

Func BestTarget_CantTouchThisPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_CantTouchThisPvp

Func CanUse_StandYourGroundPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_StandYourGroundPvp

Func BestTarget_StandYourGroundPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_StandYourGroundPvp

Func CanUse_WeShallReturnPvp()
	If Anti_Shout() Then Return False
	If UAI_PlayerHasEffect($GC_I_SKILL_ID_CURSE_OF_DHUUM) Or UAI_PlayerHasEffect($GC_I_SKILL_ID_FROZEN_SOIL) Then Return False
	Return True
EndFunc   ;==>CanUse_WeShallReturnPvp

Func BestTarget_WeShallReturnPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_WeShallReturnPvp

Func CanUse_FindTheirWeaknessPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_FindTheirWeaknessPvp

Func BestTarget_FindTheirWeaknessPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_FindTheirWeaknessPvp

Func CanUse_NeverGiveUpPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_NeverGiveUpPvp

Func BestTarget_NeverGiveUpPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_NeverGiveUpPvp

Func CanUse_HelpMePvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_HelpMePvp

Func BestTarget_HelpMePvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_HelpMePvp

Func CanUse_FallBackPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_FallBackPvp

Func BestTarget_FallBackPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_FallBackPvp

Func CanUse_PredatoryBondPvp()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_PredatoryBondPvp

Func BestTarget_PredatoryBondPvp($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_PredatoryBondPvp

Func CanUse_StickyGround()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_StickyGround

Func BestTarget_StickyGround($a_f_AggroRange)
	; Description
	; Agent of the Mad King skill
	; Concise description
	; //en.wikipedia.org/wiki/Sic" class="extiw" title="w:Sic">
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_StickyGround

Func CanUse_SugarShock()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_SugarShock

Func BestTarget_SugarShock($a_f_AggroRange)
	; Description
	; Shout. Knocks down target foe for 10 seconds.
	; Concise description
	; Shout. Causes knock-down (10 seconds).
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_SugarShock

Func CanUse_TheMadKingsInfluence()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_TheMadKingsInfluence

Func BestTarget_TheMadKingsInfluence($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_TheMadKingsInfluence

Func CanUse_TheresNotEnoughTime()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_TheresNotEnoughTime

Func BestTarget_TheresNotEnoughTime($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_TheresNotEnoughTime

Func CanUse_FindTheirWeaknessThackeray()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_FindTheirWeaknessThackeray

Func BestTarget_FindTheirWeaknessThackeray($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_FindTheirWeaknessThackeray

Func CanUse_TheresNothingToFearThackeray()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_TheresNothingToFearThackeray

Func BestTarget_TheresNothingToFearThackeray($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_TheresNothingToFearThackeray

Func CanUse_TangoDown()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_TangoDown

Func BestTarget_TangoDown($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_TangoDown

Func CanUse_IllBeBack()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_IllBeBack

Func BestTarget_IllBeBack($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_IllBeBack

Func CanUse_TogetherAsOne()
	If Anti_Shout() Then Return False
	Return True
EndFunc   ;==>CanUse_TogetherAsOne

Func BestTarget_TogetherAsOne($a_f_AggroRange)
	Return UAI_GetPlayerInfo($GC_UAI_AGENT_ID)
EndFunc   ;==>BestTarget_TogetherAsOne
