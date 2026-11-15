# UtilityAI -> Zaishen : à relire

Généré par `Tools/ZS_ExtractUAI.ps1`. Conditions `CanUse_*` que l'outil ne sait pas traduire en paramètres :
à reprendre à la main dans `Knowledge/ZS_SkillDefs.au3` quand elles comptent.

## Filtres utilisés par UtilityAI mais jamais définis (le skill ne trouvait jamais de cible)

- `` : BestTarget_JununduFeast
- `UAI_Filter_HasCondition` : BestTarget_ClubStrike
- `UAI_Filter_IsAlly` : BestTarget_DenyHexes, BestTarget_DismissCondition, BestTarget_DivertHexes, BestTarget_EmpathicRemoval, BestTarget_ExpelHexes, BestTarget_FoulFeast, BestTarget_HexEaterVortex, BestTarget_InspiredHex, BestTarget_MendingTouch, BestTarget_PurifyingPrayer, BestTarget_Return, BestTarget_RevealedHex, BestTarget_ShatterHex, BestTarget_SmiteCondition, BestTarget_WithdrawHexes
- `UAI_Filter_IsWeakened` : BestTarget_FierceBlow, BestTarget_GravestoneMarker, BestTarget_HeavyBlow

## Conditions non traduites (31 fonctions)

### CanUse_SpiritTransfer  —  GC_I_SKILL_ID_SPIRIT_TRANSFER (962)
```autoit
Local $l_i_SpiritCount = UAI_CountAgents(-2, $GC_I_RANGE_EARSHOT, "UAI_Filter_IsSpirit")
If $l_i_SpiritCount <= 0 Then Return False
```
### CanUse_EremitesZeal  —  GC_I_SKILL_ID_EREMITES_ZEAL (1524)
```autoit
If UAI_CountAgents(-2, $GC_I_RANGE_EARSHOT, "UAI_Filter_IsLivingEnemy") <= 0 Then Return False
```
### CanUse_TwinMoonSweep  —  GC_I_SKILL_ID_TWIN_MOON_SWEEP (1487)
```autoit
If Not UAI_GetFeederEnchOnTop() Then Return False
```
### CanUse_GhostmirrorLight  —  GC_I_SKILL_ID_GHOSTMIRROR_LIGHT (1741)
```autoit
Local $l_i_SpiritCount = UAI_CountAgents(-2, $GC_I_RANGE_EARSHOT, "UAI_Filter_IsSpirit")
If $l_i_SpiritCount <= 0 Then Return False
```
### CanUse_WearyingStrike  —  GC_I_SKILL_ID_WEARYING_STRIKE (1537)
```autoit
If Not UAI_GetFeederEnchOnTop() Then Return False
```
### CanUse_BrawlingJab2  —  GC_I_SKILL_ID_BRAWLING_JAB2 (2336)
```autoit
If UAI_GetDynamicSkillInfo(3, $GC_UAI_DYNAMIC_SKILL_IsRecharged) Then Return False
If UAI_GetDynamicSkillInfo(4, $GC_UAI_DYNAMIC_SKILL_Adrenaline) >= UAI_GetStaticSkillInfo(4, $GC_UAI_STATIC_SKILL_Adrenaline) Then Return False
If UAI_GetDynamicSkillInfo(5, $GC_UAI_DYNAMIC_SKILL_Adrenaline) >= UAI_GetStaticSkillInfo(5, $GC_UAI_STATIC_SKILL_Adrenaline) Then Return False
If UAI_GetDynamicSkillInfo(6, $GC_UAI_DYNAMIC_SKILL_Adrenaline) >= UAI_GetStaticSkillInfo(6, $GC_UAI_STATIC_SKILL_Adrenaline) Then Return False
```
### CanUse_GrenthsAura  —  GC_I_SKILL_ID_GRENTHS_AURA (2013)
```autoit
Local $l_i_NearestEnemy = UAI_GetNearestAgent(-2, 1320, "UAI_Filter_IsLivingEnemy")
```
### CanUse_PiousAssault  —  GC_I_SKILL_ID_PIOUS_ASSAULT (1490)
```autoit
If Not UAI_GetFeederEnchOnTop() Then Return False
```
### CanUse_JununduTunnel  —  GC_I_SKILL_ID_JUNUNDU_TUNNEL (1442)
```autoit
If UAI_IsAgentInRange(-2, $GC_I_RANGE_ADJACENT, "UAI_Filter_IsLivingEnemy") Then Return True
```
### CanUse_NaturalTemper  —  GC_I_SKILL_ID_NATURAL_TEMPER (1770)
```autoit
If UAI_GetPlayerInfo($GC_UAI_AGENT_IsEnchanted) Then Return False
```
### CanUse_ComfortAnimal  —  GC_I_SKILL_ID_COMFORT_ANIMAL (436)
```autoit
Local $l_i_PetSize = World_GetWorldInfo("PetInfoArraySize")
Local $lMyPet = 0
For $i = 1 To $l_i_PetSize
If Party_GetPetInfo($i, "OwnerAgentID") = UAI_GetPlayerInfo($GC_UAI_AGENT_ID) Then
$lMyPet = Party_GetPetInfo($i, "AgentID")
ExitLoop
EndIf
Next
If $lMyPet = 0 Then Return False
If Agent_GetAgentInfo($lMyPet, "HPPercent") < 0.5 Then Return True
```
### CanUse_VowOfStrength  —  GC_I_SKILL_ID_VOW_OF_STRENGTH (1759)
```autoit
Local $l_b_SkillSlot = Skill_GetSlotByID($GC_I_SKILL_ID_EXTEND_ENCHANTMENTS)
Local $l_b_HasEffect = UAI_GetPlayerEffectInfo($GC_I_SKILL_ID_EXTEND_ENCHANTMENTS, $GC_UAI_EFFECT_TimeRemaining) > 500
If $l_b_SkillSlot > 0 Then
If Not $l_b_HasEffect Then
Skill_UseSkill($l_b_SkillSlot)
EndIf
EndIf
```
### CanUse_RampageAsOne  —  GC_I_SKILL_ID_RAMPAGE_AS_ONE (1721)
```autoit
Local $l_i_PetSize = World_GetWorldInfo("PetInfoArraySize")
Local $lMyPet = 0
For $i = 1 To $l_i_PetSize
If Party_GetPetInfo($i, "OwnerAgentID") = UAI_GetPlayerInfo($GC_UAI_AGENT_ID) Then
$lMyPet = Party_GetPetInfo($i, "AgentID")
ExitLoop
EndIf
Next
If $lMyPet = 0 Then Return False
If Agent_GetAgentInfo($lMyPet, "HPPercent") = 0 Then Return False
```
### CanUse_PointBlankShot  —  GC_I_SKILL_ID_POINT_BLANK_SHOT (407)
```autoit
If UAI_CountAgents($g_i_BestTarget, $GC_I_RANGE_NEARBY, "UAI_Filter_IsLivingEnemy") < 1 Then Return False
```
### CanUse_IAmUnstoppable  —  GC_I_SKILL_ID_I_AM_UNSTOPPABLE (2356)
```autoit
If UAI_GetPlayerInfo($GC_UAI_AGENT_IsCrippled) Or UAI_GetPlayerInfo($GC_UAI_AGENT_IsKnockedDown) Then Return True
```
### CanUse_SmiteHex  —  GC_I_SKILL_ID_SMITE_HEX (302)
```autoit
If UAI_CountAgents($g_i_BestTarget, $GC_I_RANGE_AREA, "UAI_Filter_IsLivingEnemy") < 1 Then Return False
```
### CanUse_PowerBlock  —  GC_I_SKILL_ID_POWER_BLOCK (5)
```autoit
If Not UAI_GetAgentInfoByID($g_i_BestTarget, $GC_UAI_AGENT_IsCasting) Then Return False
```
### CanUse_PiousFury  —  GC_I_SKILL_ID_PIOUS_FURY (2146)
```autoit
If Not UAI_GetFeederEnchOnTop() Then Return False
```
### CanUse_PowerDrain  —  GC_I_SKILL_ID_POWER_DRAIN (25)
```autoit
Local $lSkillID = UAI_GetAgentInfoByID($g_i_BestTarget, $GC_UAI_AGENT_Skill)
Local $lRuptable = [$GC_I_SKILL_TYPE_HEX, $GC_I_SKILL_TYPE_SPELL, $GC_I_SKILL_TYPE_ENCHANTMENT, $GC_I_SKILL_TYPE_WELL, $GC_I_SKILL_TYPE_WARD, $GC_I_SKILL_TYPE_ITEM_SPELL, $GC_I_SKILL_TYPE_WEAPON_SPELL, $GC_I_SKILL_TYPE_CHANT]
For $i = 0 To UBound($lRuptable) - 1
If Skill_GetSkillInfo($lSkillID, "SkillType") = $i Then Return True
Next
```
### CanUse_ImbueHealth  —  GC_I_SKILL_ID_IMBUE_HEALTH (1526)
```autoit
Local $l_i_HP = UAI_GetPlayerInfo($GC_UAI_AGENT_HP)
If $l_i_HP < 0.6 Then Return False
```
### CanUse_ExtendEnchantments  —  GC_I_SKILL_ID_EXTEND_ENCHANTMENTS (1508)
```autoit
Local $l_i_VoSSlot = Skill_GetSlotByID($GC_I_SKILL_ID_VOW_OF_STRENGTH)
If $l_i_VoSSlot > 0 Then
EndIf
```
### CanUse_WeaponOfAggression  —  GC_I_SKILL_ID_WEAPON_OF_AGGRESSION (2073)
```autoit
If UAI_GetPlayerInfo($GC_UAI_AGENT_IsWeaponSpelled) Then Return False
```
### CanUse_IrresistibleSweep  —  GC_I_SKILL_ID_IRRESISTIBLE_SWEEP (1489)
```autoit
If Not UAI_GetFeederEnchOnTop() Then Return False
```
### CanUse_SpiritLight  —  GC_I_SKILL_ID_SPIRIT_LIGHT (915)
```autoit
Local $l_i_SpiritCount = UAI_CountAgents(-2, $GC_I_RANGE_EARSHOT, "UAI_Filter_IsSpirit")
Local $l_i_HP = UAI_GetPlayerInfo($GC_UAI_AGENT_HP)
If $l_i_SpiritCount <= 0 And $l_i_HP < 0.85 Then Return False
```
### CanUse_BrawlingJab1  —  GC_I_SKILL_ID_BRAWLING_JAB1 (2335)
```autoit
If UAI_GetDynamicSkillInfo(3, $GC_UAI_DYNAMIC_SKILL_IsRecharged) Then Return False
If UAI_GetDynamicSkillInfo(4, $GC_UAI_DYNAMIC_SKILL_Adrenaline) >= UAI_GetStaticSkillInfo(4, $GC_UAI_STATIC_SKILL_Adrenaline) Then Return False
If UAI_GetDynamicSkillInfo(5, $GC_UAI_DYNAMIC_SKILL_Adrenaline) >= UAI_GetStaticSkillInfo(5, $GC_UAI_STATIC_SKILL_Adrenaline) Then Return False
If UAI_GetDynamicSkillInfo(6, $GC_UAI_DYNAMIC_SKILL_Adrenaline) >= UAI_GetStaticSkillInfo(6, $GC_UAI_STATIC_SKILL_Adrenaline) Then Return False
```
### CanUse_BrawlingBlock  —  GC_I_SKILL_ID_BRAWLING_BLOCK (2334)
```autoit
If UAI_Filter_IsDazed(UAI_GetPlayerInfo($GC_UAI_AGENT_ID)) Then Return False
```
### CanUse_CycloneAxe  —  GC_I_SKILL_ID_CYCLONE_AXE (330)
```autoit
If UAI_CountAgents($g_i_BestTarget, $GC_I_RANGE_ADJACENT, "UAI_Filter_IsLivingEnemy") < 2 Then Return False
```
### CanUse_RendingSweep  —  GC_I_SKILL_ID_RENDING_SWEEP (1753)
```autoit
If Not UAI_GetFeederEnchOnTop() Then Return False
```
### CanUse_EremitesAttack  —  GC_I_SKILL_ID_EREMITES_ATTACK (1485)
```autoit
If Not UAI_GetFeederEnchOnTop() Then Return False
```
### CanUse_NeverRampageAlone  —  GC_I_SKILL_ID_NEVER_RAMPAGE_ALONE (2108)
```autoit
Local $l_i_PetSize = World_GetWorldInfo("PetInfoArraySize")
Local $lMyPet = 0
For $i = 1 To $l_i_PetSize
If Party_GetPetInfo($i, "OwnerAgentID") = UAI_GetPlayerInfo($GC_UAI_AGENT_ID) Then
$lMyPet = Party_GetPetInfo($i, "AgentID")
ExitLoop
EndIf
Next
If $lMyPet = 0 Then Return False
If Agent_GetAgentInfo($lMyPet, "HPPercent") = 0 Then Return False
```
### CanUse_LyssasHaste  —  GC_I_SKILL_ID_LYSSAS_HASTE (1512)
```autoit
Local $l_i_NearestEnemy = UAI_GetNearestAgent(-2, 1320, "UAI_Filter_IsLivingEnemy")
```
