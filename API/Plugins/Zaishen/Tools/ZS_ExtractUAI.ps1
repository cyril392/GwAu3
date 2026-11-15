<#
.SYNOPSIS
    Extracts the skill knowledge of UtilityAI (CanUse_* / BestTarget_*) into Zaishen parameters.

.DESCRIPTION
    Reads API/Plugins/UtilityAI/Skills/*.au3 and the two UtilityAI dispatchers, then writes:
      Knowledge/Generated/ZS_SkillDefs_UAI.au3   one ZS_DefineParams(...) line per skill that has something to say
      Tools/uai_review.md                        what could not be translated, and UtilityAI bugs found

    Parameters produced (understood by Zaishen, see ZS_Eval_Requirements):
      Need=<q,q>      the target must show every qualifier (BestTarget filter when it is the only choice)
      Prefer=<q,q>    targets showing them are preferred (first choice of a BestTarget with a fallback)
      Avoid=<q,q>     never on a target showing one of them ("-UAI_Filter_..." in UtilityAI)
      Pick=lowest|highest   which health to prefer among the candidates
      Range=<n>       the target must be within n of the player
      SelfNeed=<id,id> / SelfNot=<id,id>   effects the player must have / must not have
      SelfIs=<q>      the player must show this qualifier (enchanted...)
      TargetBelow=<f> / TargetAbove=<f>    target health fraction bounds
      MyHPAbove=<f> / MyHPBelow=<f>        player health fraction bounds
      MinFoes=<n>     at least n foes around (area skills)
      MinAdjacent=<n> at least n foes adjacent to the player (Hundred Blades, Cyclone Axe...)
      MyEnergyBelow=<n>   only when the player has less energy than n (energy gain skills)
      BonusIf=<q>     the description gives a bonus on such a target ("if target foe is Burning")
      Only=Spell      an interrupt of spells only ("Interrupts a spell"); AnyIf=Hexed: any skill on a hexed foe

    Run from anywhere:
      powershell -ExecutionPolicy Bypass -File API\Plugins\Zaishen\Tools\ZS_ExtractUAI.ps1
#>
$ErrorActionPreference = 'Stop'
$zs = Split-Path $PSScriptRoot -Parent
$uai = Join-Path (Split-Path $zs -Parent) 'UtilityAI'
$api = Split-Path (Split-Path $zs -Parent) -Parent

# ---------- skill IDs ----------
$ids = @{}
Select-String -Path (Join-Path $api 'Constants\GwAu3_Const_Skill.au3') -Pattern '^\s*Global Const \$(GC_I_SKILL_ID_\w+)\s*=\s*(\d+)' | ForEach-Object {
    $ids[$_.Matches[0].Groups[1].Value] = [int]$_.Matches[0].Groups[2].Value
}

# ---------- dispatchers: function name -> skill constants ----------
function Read-Dispatcher([string]$file) {
    $map = @{}; $pending = @()
    foreach ($line in Get-Content $file) {
        if ($line -match '^\s*Case\s+(.+)$') { $pending = @([regex]::Matches($Matches[1], '\$(GC_I_SKILL_ID_\w+)') | ForEach-Object { $_.Groups[1].Value }) }
        elseif ($line -match '^\s*Return\s+"(\w+)"' -and $pending.Count) { foreach ($c in $pending) { $map[$Matches[1]] += @($c) }; $pending = @() }
    }
    $map
}
$btOf = Read-Dispatcher (Join-Path $uai 'Cache\UtilityAI_BestTargetCache.au3')
$cuOf = Read-Dispatcher (Join-Path $uai 'Cache\UtilityAI_CanUseCache.au3')

# ---------- function bodies ----------
$funcs = @{}
$descOf = @{}   # BestTarget function -> game description lines (comments)
foreach ($f in Get-ChildItem (Join-Path $uai 'Skills') -Filter *.au3) {
    $cur = $null; $buf = @()
    foreach ($l in Get-Content $f.FullName) {
        if ($l -match '^\s*Func\s+((CanUse|BestTarget)_\w+)') { $cur = $Matches[1]; $buf = @() }
        elseif ($l -match '^\s*EndFunc' -and $cur) { $funcs[$cur] = $buf; $cur = $null }
        elseif ($cur -and $l -match '^\s*;\s*(.+)$') { $descOf[$cur] += @($Matches[1]) }
        elseif ($cur -and $l.Trim() -ne '') { $buf += $l.Trim() }
    }
}

# "if target foe is Burning" in the description -> BonusIf=Burning (the skill does more on such a target)
$bonusWords = [ordered]@{
    'burning' = 'Burning'; 'on fire' = 'Burning'; 'bleeding' = 'Bleeding'; 'poisoned' = 'Poisoned'; 'crippled' = 'Crippled';
    'weakened' = 'Weakness'; 'suffering from weakness' = 'Weakness'; 'dazed' = 'Dazed'; 'blinded' = 'Blind';
    'diseased' = 'Diseased'; 'suffering from a deep wound' = 'DeepWounded'; 'deep wound' = 'DeepWounded';
    'knocked down' = 'Knocked'; 'hexed' = 'Hexed'; 'enchanted' = 'Enchanted'; 'casting a spell' = 'Casting'; 'casting' = 'Casting';
    'attacking' = 'Attacking'; 'moving' = 'Moving'; 'suffering from a condition' = 'Conditioned'; 'conditioned' = 'Conditioned'
}
function Get-BonusIf([string[]]$lines) {
    foreach ($line in $lines) {
        foreach ($m in [regex]::Matches($line, '(?i)\bif (?:target|that|the)(?: foe| ally| other ally)? (?:is|was) (?:already )?(not )?([a-z ]+?)(?:[,.;]|$| or | and | for | when )')) {
            if ($m.Groups[1].Value) { continue }   # "if target is not ..." is not a bonus
            $w = $m.Groups[2].Value.Trim().ToLower()
            foreach ($k in $bonusWords.Keys) { if ($w -eq $k -or $w.StartsWith("$k ") -or $w -eq "$k foe") { return $bonusWords[$k] } }
        }
    }
    ''
}

# ---------- filters UtilityAI really defines ----------
$definedFilters = @{}
Select-String -Path (Join-Path $uai 'Targeting\UtilityAI_AgentFilter.au3') -Pattern '^\s*Func\s+(UAI_Filter_\w+)' | ForEach-Object { $definedFilters[$_.Matches[0].Groups[1].Value] = $true }

# Filters that only say "enemy" / "ally" / "not me": the game target type already says it
$base = @('IsLivingEnemy', 'IsLivingAlly', 'ExcludeMe', 'IsAlly', 'IsDeadAlly', 'IsLivingNPC', 'IsGadgetOrLiving')
# UtilityAI names -> Zaishen qualifier names (anything else keeps its name without "Is")
$rename = @{ 'Weakened' = 'Weakness'; 'LivingEnemyCaster' = 'Caster'; 'Knocked' = 'Knocked'; 'LastStrikeIsLead' = 'AfterLead';
    'LastStrikeIsOffHand' = 'AfterOffHand'; 'LastStrikeIsDual' = 'AfterDual'; 'LastStrikeLeadOrOffHand' = 'AfterLeadOrOffHand'; 'IdConditionedOrEnchanted' = 'ConditionedOrEnchanted' }
$rangeConst = @{ 'GC_I_RANGE_ADJACENT' = 156; 'GC_I_RANGE_NEARBY' = 240; 'GC_I_RANGE_AREA' = 312; 'GC_I_RANGE_EARSHOT' = 1000 }

$brokenFilters = @{}
function Get-Qualifiers([string]$filterString, [string]$func) {
    $need = @(); $avoid = @()
    foreach ($tok in $filterString -split '\|') {
        $neg = $tok.StartsWith('-'); $name = $tok.TrimStart('-')
        if (-not $definedFilters.ContainsKey($name)) { $brokenFilters["$name"] += @($func) }
        $q = $name -replace '^UAI_Filter_', ''
        if ($base -contains $q) { continue }
        $q = $q -replace '^Is', ''
        if ($rename.ContainsKey($q)) { $q = $rename[$q] }
        if ($neg) { $avoid += $q } else { $need += $q }
    }
    , @($need, $avoid)
}

$results = [ordered]@{}   # skill constant -> params
$review = New-Object System.Collections.Generic.List[string]
$stats = @{ skills = 0; withParams = 0; canUseTranslated = 0; canUseLeft = 0 }

function Add-Param($consts, [string]$key, [string]$value) {
    foreach ($c in $consts) {
        if (-not $results.Contains($c)) { $results[$c] = [ordered]@{} }
        if ($results[$c].Contains($key)) {
            if ($results[$c][$key] -notmatch "(^|,)$([regex]::Escape($value))(,|$)") { $results[$c][$key] += ",$value" }
        } else { $results[$c][$key] = $value }
    }
}

# ---------- BestTarget ----------
foreach ($fn in $btOf.Keys) {
    if (-not $funcs.ContainsKey($fn)) { continue }
    $consts = $btOf[$fn]; $body = $funcs[$fn] -join "`n"
    $queries = [regex]::Matches($body, '\bUAI_(GetNearestAgent|GetAgentLowest|GetAgentHighest|GetBestAOETarget|GetBestSingleTarget|GetFarthestAgent)\(([^\n]*)')
    if ($queries.Count -eq 0) { continue }
    $first = $queries[0]
    $filters = [regex]::Matches($first.Groups[2].Value, '"((?:-?UAI_Filter_\w+\|?)+)"')
    $q = Get-Qualifiers ($(if ($filters.Count) { $filters[0].Groups[1].Value } else { '' })) $fn
    $need = $q[0]; $avoid = $q[1]
    # Same qualifier in every query = a requirement; only in the first = a preference
    $allSame = $true
    foreach ($m in $queries) {
        $fs = [regex]::Matches($m.Groups[2].Value, '"((?:-?UAI_Filter_\w+\|?)+)"')
        $qq = Get-Qualifiers ($(if ($fs.Count) { $fs[0].Groups[1].Value } else { '' })) $fn
        if (($qq[0] -join ',') -ne ($need -join ',')) { $allSame = $false }
    }
    $hasPlayerFallback = $body -match 'UAI_GetPlayerInfo\(\$GC_UAI_AGENT_ID\)'
    if ($need.Count) {
        if ($allSame -and -not $hasPlayerFallback) { Add-Param $consts 'Need' ($need -join ',') } else { Add-Param $consts 'Prefer' ($need -join ',') }
    }
    if ($avoid.Count) { Add-Param $consts 'Avoid' ($avoid -join ',') }
    switch ($first.Groups[1].Value) {
        'GetAgentLowest' { Add-Param $consts 'Pick' 'lowest' }
        'GetAgentHighest' { Add-Param $consts 'Pick' 'highest' }
    }
    if ($first.Groups[2].Value -match '^\s*-2\s*,\s*\$(GC_I_RANGE_\w+)' -and $rangeConst.ContainsKey($Matches[1])) {
        Add-Param $consts 'Range' $rangeConst[$Matches[1]]
    }
}

# ---------- conditional bonuses read in the descriptions ----------
foreach ($fn in $btOf.Keys) {
    if (-not $descOf.ContainsKey($fn)) { continue }
    $b = Get-BonusIf $descOf[$fn]
    if ($b) { Add-Param $btOf[$fn] 'BonusIf' $b; $stats['bonusIf'] = 1 + $stats['bonusIf'] }
    # "Interrupts a spell (or chant)": does nothing on an attack or a stance
    $txt = $descOf[$fn] -join ' '
    if ($txt -match '(?i)\binterrupts? (a|target foe''s) spell\b') {
        Add-Param $btOf[$fn] 'Only' 'Spell'
        if ($txt -match '(?i)any skill if target foe is hexed') { Add-Param $btOf[$fn] 'AnyIf' 'Hexed' }
    }
}

# ---------- CanUse ----------
foreach ($fn in $cuOf.Keys) {
    if (-not $funcs.ContainsKey($fn)) { continue }
    $consts = $cuOf[$fn]; $left = @()
    $body = $funcs[$fn] -join "`n"
    # Spirit rituals: "recast when our spirit is gone or under 20 %" is what Zaishen does for every ritual
    if ($body -match 'IsControlledSpirit|\$lSpirit|SpiritsAt') { $stats.canUseTranslated++; continue }
    # "N foes adjacent to me" written over two lines: Local $x = UAI_CountAgents(me, ADJACENT...) / If $x < N Then Return False
    if ($body -match 'Local (\$\w+) = UAI_CountAgents\((?:UAI_GetPlayerInfo\(\$GC_UAI_AGENT_ID\)|-2), \$GC_I_RANGE_ADJACENT, "UAI_Filter_IsLivingEnemy"\)\s*\n\s*If \1 (<|<=) (\d+) Then Return False') {
        $n = [int]$Matches[3]; if ($Matches[2] -eq '<=') { $n++ }
        Add-Param $consts 'MinAdjacent' $n; $stats.canUseTranslated++
        $funcs[$fn] = @($funcs[$fn] | Where-Object { $_ -notmatch 'UAI_CountAgents\(' -and $_ -notmatch "^If \$\w+ (<|<=) \d+ Then Return False$" })
    }
    foreach ($l in $funcs[$fn]) {
        if ($l -match '^If Anti_\w+\(\) Then Return False$' -or $l -match '^Return (True|False)$') { continue }
        if ($l -match '^If UAI_PlayerHasEffect\(\$(GC_I_SKILL_ID_\w+)\)( Or UAI_PlayerHasEffect\(\$(GC_I_SKILL_ID_\w+)\))? Then Return False$') {
            Add-Param $consts 'SelfNot' $ids[$Matches[1]]; if ($Matches[3]) { Add-Param $consts 'SelfNot' $ids[$Matches[3]] }; $stats.canUseTranslated++; continue
        }
        if ($l -match '^If Not UAI_PlayerHasEffect\(\$(GC_I_SKILL_ID_\w+)\) Then Return False$') { Add-Param $consts 'SelfNeed' $ids[$Matches[1]]; $stats.canUseTranslated++; continue }
        # "still active for more than N ms": Zaishen already never recasts an active effect
        if ($l -match '^If UAI_GetPlayerEffectInfo\(\$(GC_I_SKILL_ID_\w+), \$GC_UAI_EFFECT_TimeRemaining\) > \d+ Then Return False$' -and $consts -contains $Matches[1]) { $stats.canUseTranslated++; continue }
        if ($l -match '^If UAI_GetAgentInfoByID\(\$g_i_BestTarget, \$GC_UAI_AGENT_HP\) (>=?|<=?) ([\d.]+) Then Return False$') {
            if ($Matches[1].StartsWith('>')) { Add-Param $consts 'TargetBelow' $Matches[2] } else { Add-Param $consts 'TargetAbove' $Matches[2] }; $stats.canUseTranslated++; continue
        }
        if ($l -match '^If UAI_GetPlayerInfo\(\$GC_UAI_AGENT_HP\) (>=?|<=?) ([\d.]+) Then Return False$') {
            if ($Matches[1].StartsWith('>')) { Add-Param $consts 'MyHPBelow' $Matches[2] } else { Add-Param $consts 'MyHPAbove' $Matches[2] }; $stats.canUseTranslated++; continue
        }
        if ($l -match '^If Not UAI_GetPlayerInfo\(\$GC_UAI_AGENT_Is(\w+)\) Then Return False$') { Add-Param $consts 'SelfIs' $Matches[1]; $stats.canUseTranslated++; continue }
        # Assassin chains: the game data already carries them
        if ($l -match 'Agent_GetCurrentTarget\(\)' -or $l -match 'UAI_Filter_IsLastStrike') { $stats.canUseTranslated++; continue }
        if ($l -match 'UAI_CountAgents\(-2, \$GC_I_RANGE_ADJACENT, "UAI_Filter_IsLivingEnemy"\) (<|<=) (\d+) Then Return False') {
            $n = [int]$Matches[2]; if ($Matches[1] -eq '<=') { $n++ }
            Add-Param $consts 'MinAdjacent' $n; $stats.canUseTranslated++; continue
        }
        if ($l -match '^If Not UAI_IsAgentInRange\(-2, \$GC_I_RANGE_ADJACENT, "UAI_Filter_IsLivingEnemy"\) Then Return False$') { Add-Param $consts 'MinAdjacent' 1; $stats.canUseTranslated++; continue }
        if ($l -match 'UAI_CountAgents\(-2, \$(GC_I_RANGE_\w+), "UAI_Filter_IsLivingEnemy"\) < (\d+) Then Return False') {
            Add-Param $consts 'MinFoes' $Matches[2]; $stats.canUseTranslated++; continue
        }
        if ($l -match '^If UAI_GetPlayerInfo\(\$GC_UAI_AGENT_CurrentEnergy\) >=? (\d+) Then Return False$') { Add-Param $consts 'MyEnergyBelow' $Matches[1]; $stats.canUseTranslated++; continue }
        if ($l -match '^If UAI_AgentHasEffect\(UAI_GetPlayerInfo\(\$GC_UAI_AGENT_ID\), \$(GC_I_SKILL_ID_\w+)\) Then Return False$') { Add-Param $consts 'SelfNot' $ids[$Matches[1]]; $stats.canUseTranslated++; continue }
        if ($l -match '^If UAI_GetAgentInfoByID\(\$\w+, \$GC_UAI_AGENT_Distance\) > \$GC_I_RANGE_ADJACENT Then Return False$') { Add-Param $consts 'Range' 156; $stats.canUseTranslated++; continue }
        $left += $l
    }
    if ($left.Count) {
        $stats.canUseLeft++
        $names = ($consts | ForEach-Object { "$_ ($($ids[$_]))" }) -join ', '
        $review.Add("### $fn  —  $names")
        $review.Add('```autoit'); foreach ($x in $left) { $review.Add($x) }; $review.Add('```')
    }
}

# ---------- write the generated definitions ----------
$genDir = Join-Path $zs 'Knowledge\Generated'
New-Item -ItemType Directory -Force $genDir | Out-Null
$out = New-Object System.Collections.Generic.List[string]
$out.Add('#include-once')
$out.Add('')
$out.Add('; GENERATED by Tools/ZS_ExtractUAI.ps1 from the UtilityAI CanUse_* / BestTarget_* functions - do not edit by hand.')
$out.Add('; Fix a skill in Knowledge/ZS_SkillDefs.au3 instead: its parameters override these ones.')
$out.Add('')
$out.Add('Func ZS_Knowledge_LoadGenerated()')
$sorted = $results.Keys | Sort-Object { if ($ids.ContainsKey($_)) { $ids[$_] } else { 99999 } }
foreach ($c in $sorted) {
    if (-not $ids.ContainsKey($c)) { continue }
    $p = ($results[$c].Keys | ForEach-Object { "$_=$($results[$c][$_])" }) -join '|'
    $out.Add("`tZS_DefineParams(`$$c, `"$p`")")
    $stats.withParams++
}
$out.Add('EndFunc   ;==>ZS_Knowledge_LoadGenerated')
[System.IO.File]::WriteAllLines((Join-Path $genDir 'ZS_SkillDefs_UAI.au3'), $out, (New-Object System.Text.UTF8Encoding($false)))

# ---------- review ----------
$rev = New-Object System.Collections.Generic.List[string]
$rev.Add('# UtilityAI -> Zaishen : à relire')
$rev.Add('')
$rev.Add('Généré par `Tools/ZS_ExtractUAI.ps1`. Conditions `CanUse_*` que l''outil ne sait pas traduire en paramètres :')
$rev.Add('à reprendre à la main dans `Knowledge/ZS_SkillDefs.au3` quand elles comptent.')
$rev.Add('')
$rev.Add('## Filtres utilisés par UtilityAI mais jamais définis (le skill ne trouvait jamais de cible)')
$rev.Add('')
foreach ($k in ($brokenFilters.Keys | Sort-Object)) { $rev.Add("- ``$k`` : $(($brokenFilters[$k] | Sort-Object -Unique) -join ', ')") }
$rev.Add('')
$rev.Add("## Conditions non traduites ($($stats.canUseLeft) fonctions)")
$rev.Add('')
foreach ($x in $review) { $rev.Add($x) }
[System.IO.File]::WriteAllLines((Join-Path $PSScriptRoot 'uai_review.md'), $rev, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "skills with parameters: $($stats.withParams)"
Write-Host "CanUse lines translated: $($stats.canUseTranslated), functions left for review: $($stats.canUseLeft)"
Write-Host "undefined UtilityAI filters: $($brokenFilters.Count)"
