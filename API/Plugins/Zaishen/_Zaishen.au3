#include-once

; Zaishen - autonomous combat AI for GwAu3. See CAHIER_DES_CHARGES.md and AVANCEMENT.md.
; Independent of the UtilityAI plugin: it reads the game with its own readers (Perception/ZS_Read.au3),
; built on the GwAu3 core only.

#include "ZS_Const.au3"
#include "Perception/ZS_Read.au3"
#include "Perception/ZS_Snapshot.au3"
#include "Perception/ZS_SnapshotIO.au3"
#include "Knowledge/ZS_Knowledge.au3"
#include "Knowledge/ZS_SkillDefs.au3"
#include "Knowledge/Generated/ZS_SkillDefs_UAI.au3"
#include "Knowledge/ZS_Costs.au3"
#include "Knowledge/ZS_Vetos.au3"
#include "Evaluation/ZS_Requirements.au3"
#include "Evaluation/ZS_Evaluate.au3"
#include "Evaluation/ZS_Dervish.au3"
#include "Evaluation/ZS_Position.au3"
#include "Equipment/ZS_Weapons.au3"
#include "Execution/ZS_Execute.au3"
#include "ZS_Core.au3"
