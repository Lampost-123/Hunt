local function MyRoutine()
	local Author = 'Lamp - Beast Mastery Hunter'
	local SpecID = 253

	-- Addon
	local Lib = LibStub("AceAddon-3.0"):GetAddon(Z_AddonName)
	local MainAddon = MainAddon
	-- HeroDBC
	local DBC = HeroDBC.DBC
	-- HeroLib
	local HL = HeroLibEx
	local Cache = HeroCache
	---@type Unit
	local Unit = HL.Unit
	---@type Unit
	local Player = Unit.Player
	---@type Unit
	local Target = Unit.Target
	---@type Unit
	local MouseOver = Unit.MouseOver
	---@type Pet
	local Pet = Unit.Pet
	---@type Spell
	local Spell = HL.Spell
	local Item = HL.Item
	local Cast = MainAddon.Cast
	local CastTargetIf = MainAddon.CastTargetIf
	local SmartAoE = MainAddon.SmartAoE
	local AoEON = MainAddon.AoEON
	local CDsON = MainAddon.CDsON

	local S = Spell.Hunter.BeastMastery
	local I = Item.Hunter.BeastMastery

	S.ThrilloftheHunt = Spell(257944)
	S.ThrilloftheHuntBuff = Spell(257946)
	-- Howl of the Pack Leader Summon Buffs
	S.HowlBearBuff = Spell(472325)
	S.HowlBoarBuff = Spell(472324)
	S.HowlWyvernBuff = Spell(471878)
	local color = '65b346'
	local Config = {
		key = 'Lamp_BM_Config',
		title = 'Hunter - Beast Mastery',
		subtitle = 'Lamp Custom',
		width = 400,
		height = 240,
		profiles = true,
		config = {
			{ type = 'header', text = 'Defensives', color = color },
			{ type = 'checkspin', text = ' Exhilaration', key = 'exhilaration', icon = Spell.Hunter.Commons.Exhilaration:ID(), min = 1, max = 100, default_spin = 45, default_check = true },
			{ type = 'checkspin', text = ' Aspect of the Turtle', key = 'turtle', icon = Spell.Hunter.Commons.AspectoftheTurtle:ID(), min = 1, max = 100, default_spin = 20, default_check = true },
		}
	}
	MainAddon.SetCustomConfig(Author, SpecID, Config)

	local BossFightRemains = 11111
	local FightRemains = 11111
	local Enemies40y = {}
	local ActiveEnemies40 = 1
	local TargetInRange = false

	local function IsOnEnabled() return MainAddon.MasterON() end
	local function AoEEnabled() return AoEON() end
	local function CDsEnabled() return CDsON() end

	local function Init()
		MainAddon:Print('LAMP Beast Mastery loaded')
	end

	HL:RegisterForEvent(function()
		BossFightRemains = 11111
		FightRemains = 11111
	end, "PLAYER_REGEN_ENABLED")

	local function Precombat()
		-- no pre-pull actions here
	end

	local function CDs()
		if S.Berserking and S.Berserking:IsReady() and (Player:BuffUp(S.BestialWrathBuff) or (Player:InBossEncounter() and BossFightRemains < 13)) then
			if Cast(S.Berserking) then return "berserking cds" end
		end
		if S.BloodFury and S.BloodFury:IsReady() and (Player:BuffUp(S.BestialWrathBuff) or S.BestialWrath:CooldownRemains() > 30 or (Player:InBossEncounter() and BossFightRemains < 16)) then
			if Cast(S.BloodFury) then return "blood_fury cds" end
		end
	end

	local function EvaluateTargetIfFilterBarbedShot(u)
		return u:DebuffRemains(S.BarbedShotDebuff)
	end

	local function IsNearCotWTick()
		if Player:BuffUp(S.CalloftheWildBuff) then
			local rem = Player:BuffRemains(S.CalloftheWildBuff)
			local mod = rem % 4
			return mod <= 0.5
		end
		return false
	end

	local function HasHowlBuff()
		return Player:BuffUp(S.HowlBearBuff) or Player:BuffUp(S.HowlBoarBuff) or Player:BuffUp(S.HowlWyvernBuff)
	end

	local RememberedUnit 
	local function CastL42(spell, targets, mode, filterFunc, predicate, ...)
		if spell == S.BarbedShot then
			if Target:DebuffRemains(S.BarbedShotDebuff) < 3 then
				if MainAddon.ForceCastDisplay and MainAddon.ForceCastDisplay(S.BarbedShot, 5) then return true end
			end
			if MouseOver and MouseOver:Exists() and MainAddon.SpellList and MainAddon.SpellList.GetSpellSetting and MainAddon.SpellList.GetSpellSetting(spell:ID(), "isMouseOver", false) and Player:CanAttack(MouseOver) and MouseOver:DebuffRemains(S.BarbedShotDebuff) < 3 then
				if MainAddon.ForceCastDisplay and MainAddon.ForceCastDisplay(S.BarbedShot, 5, MouseOver) then return true end
			end
			if ActiveEnemies40 > 1 and MainAddon.SpellList and MainAddon.SpellList.GetSpellSetting and MainAddon.SpellList.GetSpellSetting(spell:ID(), "isAutoswitch", false) then
				for _, u in pairs(targets) do
					if u:DebuffRemains(S.BarbedShotDebuff) < 3 then
						if MainAddon.SetTopColor then MainAddon.SetTopColor(1, "Target Enemy") end
						return true
					end
				end
			end
		end
		if spell == S.BarbedShot and RememberedUnit and RememberedUnit:Exists() and Player:CanAttack(RememberedUnit) then
			if (not predicate or predicate(RememberedUnit)) then
				if MainAddon.ForceCastDisplay and MainAddon.ForceCastDisplay(S.BarbedShot, 5, RememberedUnit) then return true end
			end
		end
		if spell == S.BarbedShot then
			if (not predicate or predicate(Target)) then
				if MainAddon.ForceCastDisplay and MainAddon.ForceCastDisplay(S.BarbedShot, 5) then return true end
			end
		end
		if spell == S.KillCommand or (S.KillShot and spell == S.KillShot) then
			if (not predicate or predicate(Target)) then
				return Cast(spell)
			end
		end
		return CastTargetIf(spell, targets, mode, filterFunc, predicate, ...)
	end

	local function CastBarbedShotMulti(targets, filterFunc)
		if Target:DebuffRemains(S.BarbedShotDebuff) < 3 then
			if MainAddon.ForceCastDisplay and MainAddon.ForceCastDisplay(S.BarbedShot, 5) then return true end
		end
		local MouseOver = Unit.MouseOver
		if MouseOver and MouseOver:Exists() and MainAddon.SpellList and MainAddon.SpellList.GetSpellSetting and MainAddon.SpellList.GetSpellSetting(S.BarbedShot:ID(), "isMouseOver", false) and MouseOver:DebuffRemains(S.BarbedShotDebuff) < 3 then
			if MainAddon.ForceCastDisplay and MainAddon.ForceCastDisplay(S.BarbedShot, 5, MouseOver) then return true end
		end
		if ActiveEnemies40 > 1 and MainAddon.SpellList and MainAddon.SpellList.GetSpellSetting and MainAddon.SpellList.GetSpellSetting(S.BarbedShot:ID(), "isAutoswitch", false) then
			for _, u in pairs(targets) do
				if u:DebuffRemains(S.BarbedShotDebuff) < 3 then
					if MainAddon.SetTopColor then MainAddon.SetTopColor(1, "Target Enemy") end
					return true
				end
			end
		end
		return CastTargetIf(S.BarbedShot, targets, "min", filterFunc, nil, not Target:IsSpellInRange(S.BarbedShot))
	end

	local function DRST()
		-- Withering Fire tick gating
		local WFTTR = 999
		if Player:BuffUp(S.WitheringFireBuff) then
			WFTTR = 4 - S.BlackArrow:TimeSinceLastCast()
		end
		-- Black Arrow first
		if S.BlackArrow:IsReady() then
			if Cast(S.BlackArrow) then return "black_arrow dr_st 2" end
		end
		-- Bestial Wrath on CD, hold up to 30s to sync with Call of the Wild (or if TTD short)
		if S.BestialWrath:IsCastable() and (S.CalloftheWild:CooldownRemains() > 30 or not S.CalloftheWild:IsAvailable() or Target:TimeToDie() < S.CalloftheWild:CooldownRemains()) then
			if Cast(S.BestialWrath) then return "bestial_wrath dr_st 4" end
		end
		-- Bloodshed only if CotW ready with CDs or CotW active
		if S.Bloodshed:IsCastable() and ((CDsEnabled() and S.CalloftheWild:IsCastable()) or Player:BuffUp(S.CalloftheWildBuff)) then
			if Cast(S.Bloodshed) then return "bloodshed dr_st 6" end
		end
		-- Call of the Wild whenever possible
		if S.CalloftheWild:IsCastable() then
			if Cast(S.CalloftheWild) then return "call_of_the_wild dr_st 8" end
		end
		-- Kill Command with Withering Fire gating
		if S.KillCommand:IsReady() and ((WFTTR > Player:GCD() and S.BlackArrow:CooldownRemains() > 0.5) or Player:BuffDown(S.WitheringFireBuff)) then
			if Cast(S.KillCommand) then return "kill_command dr_st 10" end
		end
		-- Barbed Shot with Withering Fire gating
		if S.BarbedShot:IsCastable() and (((WFTTR > 0.5) and (S.BlackArrow:CooldownRemains() > 0.5)) or Player:BuffDown(S.WitheringFireBuff)) then
			if Cast(S.BarbedShot) then return "barbed_shot dr_st 12" end
		end
		-- Cobra Shot filler only when Withering Fire is down and not during CotW
		if S.CobraShot:IsReady() and Player:BuffDown(S.WitheringFireBuff) and Player:BuffDown(S.CalloftheWildBuff) then
			if Cast(S.CobraShot) then return "cobra_shot dr_st 14" end
		end
	end

	local function BaseCleave()
		if S.BestialWrath:IsReady() and not HasHowlBuff() and (Player:BuffRemains(S.HowlofthePackLeaderCDBuff) - 12 < 12 / Player:GCD() * 0.5) then
			if Cast(S.BestialWrath) then return "bestial_wrath cleave 2" end
		end
		if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD() or S.BarbedShot:ChargesFractional() >= S.KillCommand:ChargesFractional() or (S.CalloftheWild:IsAvailable() and S.CalloftheWild:CooldownUp())) then
			if CastL42(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot cleave 4" end
		end
		if S.Bloodshed:IsCastable() then if Cast(S.Bloodshed) then return "bloodshed cleave 6" end end
		if S.MultiShot:IsReady() and (Pet:BuffRemains(S.BeastCleavePetBuff) <= 1 + Player:GCD()) then
			if Cast(S.MultiShot) then return "multishot cleave 8" end
		end
		if S.CalloftheWild:IsCastable() then if Cast(S.CalloftheWild) then return "call_of_the_wild cleave 10" end end
		if S.ExplosiveShot:IsReady() and S.ThunderingHooves:IsAvailable() then if Cast(S.ExplosiveShot) then return "explosive_shot cleave 12" end end
		if S.KillCommand:IsReady() then if Cast(S.KillCommand) then return "kill_command cleave 14" end end
		if S.CobraShot:IsReady() and (Player:FocusTimeToMax() < Player:GCD() * 2 or Player:BuffStack(S.HogstriderBuff) > 3 or not S.MultiShot:IsAvailable()) then
			if Cast(S.CobraShot) then return "cobra_shot cleave 16" end
		end
	end

	local function BaseST()
		if S.BestialWrath:IsReady() and not HasHowlBuff() and (Player:BuffRemains(S.HowlofthePackLeaderCDBuff) - 12 < (Player:BuffRemains(S.LeadFromTheFrontBuff) % Player:GCD()) * 0.5) then
			if Cast(S.BestialWrath) then return "bestial_wrath st 1" end
		end
		if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD()) then
			if CastL42(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot st 2" end
		end
		if S.CalloftheWild:IsCastable() then if Cast(S.CalloftheWild) then return "call_of_the_wild st 3" end end
		if S.Bloodshed:IsCastable() then if Cast(S.Bloodshed) then return "bloodshed st 4" end end
		if S.KillCommand:IsReady() and (S.KillCommand:ChargesFractional() >= S.BarbedShot:ChargesFractional()) then
			if Cast(S.KillCommand) then return "kill_command st 5" end
		end
		if S.BarbedShot:IsCastable() then
			if CastL42(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot st 6" end
		end
		if S.CobraShot:IsReady() then if Cast(S.CobraShot) then return "cobra_shot st 7" end end
	end

	local function DRCleave()
		-- Withering Fire tick gating
		local WFTTR = 999
		if Player:BuffUp(S.WitheringFireBuff) then
			WFTTR = 4 - S.BlackArrow:TimeSinceLastCast()
		end
		-- BW under CotW buff
		if S.BestialWrath:IsCastable() and Player:BuffUp(S.CalloftheWildBuff) then
			if Cast(S.BestialWrath) then return "bestial_wrath dr_cleave 1" end
		end
		-- Black Arrow whenever possible
		if S.BlackArrow:IsReady() then
			if Cast(S.BlackArrow) then return "kill_shot dr_cleave 2" end
		end
		-- Bestial Wrath on cooldown, hold up to 26s to sync with CotW when CDs ON
		if CDsEnabled() and S.BestialWrath:IsCastable() and (S.CalloftheWild:CooldownRemains() > 26 or not S.CalloftheWild:IsAvailable()) then
			if Cast(S.BestialWrath) then return "bestial_wrath dr_cleave 4" end
		end
		-- Early Barbed Shot: full recharge < GCD or Thrill of the Hunt low
		if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD() or Player:BuffRemains(S.ThrilloftheHuntBuff) < Player:GCD() * 1.5) then
			if CastL42(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot dr_cleave 6" end
		end
		-- Bloodshed only if CotW ready with CDs or CotW active
		if S.Bloodshed:IsCastable() and ((CDsEnabled() and S.CalloftheWild:IsCastable()) or Player:BuffUp(S.CalloftheWildBuff)) then
			if Cast(S.Bloodshed) then return "bloodshed dr_cleave 8" end
		end
		-- Maintain Beast Cleave; avoid if Black Arrow ready
		if S.MultiShot:IsReady() and ((Pet:BuffDown(S.BeastCleavePetBuff) or Pet:BuffRemains(S.BeastCleavePetBuff) <= 0.4) and (not S.BloodyFrenzy:IsAvailable() or S.CalloftheWild:CooldownDown()) and not S.BlackArrow:IsReady()) then
			if Cast(S.MultiShot) then return "multishot dr_cleave 10" end
		end
		-- Call of the Wild (when CDs ON)
		if CDsEnabled() and S.CalloftheWild:IsCastable() then
			if Cast(S.CalloftheWild) then return "call_of_the_wild dr_cleave 12" end
		end
		-- Explosive Shot if Thundering Hooves
		if S.ExplosiveShot:IsReady() and S.ThunderingHooves:IsAvailable() then
			if Cast(S.ExplosiveShot) then return "explosive_shot dr_cleave 14" end
		end
		-- Kill Command with Withering Fire gating
		if S.KillCommand:IsReady() and ((WFTTR > Player:GCD() and S.BlackArrow:CooldownRemains() > 0.5) or Player:BuffDown(S.WitheringFireBuff)) then
			if Cast(S.KillCommand) then return "kill_command dr_cleave 18" end
		end
		-- Barbed Shot with Withering Fire gating
		if S.BarbedShot:IsCastable() and (((WFTTR > 0.5) and (S.BlackArrow:CooldownRemains() > 0.5)) or Player:BuffDown(S.WitheringFireBuff)) then
			if CastL42(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot dr_cleave 16" end
		end
		-- Cobra Shot filler, not during CotW, only when Withering Fire down
		if S.CobraShot:IsReady() and Player:BuffDown(S.WitheringFireBuff) and (Player:FocusTimeToMax() < Player:GCD() * 2) and Player:BuffDown(S.CalloftheWildBuff) then
			if Cast(S.CobraShot) then return "cobra_shot dr_cleave 20" end
		end
		-- Explosive Shot fallback
		if S.ExplosiveShot:IsReady() then
			if Cast(S.ExplosiveShot) then return "explosive_shot dr_cleave 22" end
		end
	end

	local function MainAPL()
		local splash = Target:GetEnemiesInSplashRange(10)
		Enemies40y = Player:GetEnemiesInRangeFilter(40)
		ActiveEnemies40 = #Enemies40y
		if not IsOnEnabled() then return end
		if MainAddon.TargetIsValid() or Player:AffectingCombat() then
			BossFightRemains = HL.BossFightRemains()
			FightRemains = BossFightRemains
			if FightRemains == 11111 then
				FightRemains = HL.FightRemains(splash, false)
			end
		end

		if Player:AffectingCombat() then
			if Spell.Hunter.Commons.Exhilaration:IsCastable() and Player:HealthPercentage() <= (MainAddon.Config.GetClassSetting('exhilaration_spin') or 45) then
				if Cast(Spell.Hunter.Commons.Exhilaration) then return "Exhilaration LAMP BM" end
			end
			if Spell.Hunter.Commons.AspectoftheTurtle:IsCastable() and Player:HealthPercentage() <= (MainAddon.Config.GetClassSetting('turtle_spin') or 20) then
				if Cast(Spell.Hunter.Commons.AspectoftheTurtle) then return "Turtle LAMP BM" end
			end
		end

		if MainAddon.TargetIsValid() and not Player:AffectingCombat() then
			local r = Precombat(); if r then return r end
		end

		if CDsEnabled() then
			local cr = CDs(); if cr then return cr end
		end

		if MainAddon.TargetIsValid() then
			local enemies = Target:EnemiesAround(10)
			local useCleave = AoEEnabled() and enemies >= 3
			if S.BlackArrow:IsAvailable() then
				if useCleave then
					local r = DRCleave(); if r then return r end
				else
					local r = DRST(); if r then return r end
				end
			else
				if useCleave then
					local r = BaseCleave(); if r then return r end
				else
					local r = BaseST(); if r then return r end
				end
			end
		end
	end

	local OldPetBuffRemains
	OldPetBuffRemains = HL.AddCoreOverride("Pet.BuffRemains", function(unit, aura, anyCaster, offset)
		local remains = OldPetBuffRemains(unit, aura, anyCaster, offset)
		if aura == S.FrenzyPetBuff then
			if Player.IsPrevCastPending and Player:IsPrevCastPending() and Player.GCDStartTime then
				return remains + (GetTime() - Player:GCDStartTime())
			end
		elseif aura == S.BeastCleaveBuff then
			remains = math.max(remains, Player:BuffRemains(S.BeastCleaveBuff))
			if Player.IsPrevCastPending and Player:IsPrevCastPending() and Player.GCDStartTime then
				return remains + (GetTime() - Player:GCDStartTime())
			end
		end
		return remains
	end, 253)

	local OldIsCastable
	OldIsCastable = HL.AddCoreOverride("Spell.IsCastable", function(spell, BypassRecovery, Range, AoESpell, ThisUnit)
		local ok, reason = OldIsCastable(spell, BypassRecovery, Range, AoESpell, ThisUnit)
		if spell == S.SummonPet then
			return (not Pet:IsActive()) and (not Pet:IsDeadOrGhost()) and ok
		else
			local rangeCheck = MainAddon.Config and MainAddon.Config.GetClassSetting and MainAddon.Config.GetClassSetting('range_check') or false
			if rangeCheck and (spell == S.BestialWrath or (S.AMurderofCrows and spell == S.AMurderofCrows) or spell == S.KillCommand) then
				local inRange = (Target and Target:IsInRange(40)) or (spell == S.KillCommand and Target and Target:IsSpellInRange(S.KillCommand))
				if not inRange then return false, "not in range" end
			end
			return ok, reason
		end
	end, 253)

	local OldIsReady
	OldIsReady = HL.AddCoreOverride("Spell.IsReady", function(spell, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
		local ready, reason = OldIsReady(spell, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
		if spell == S.Bloodshed then
			if not Player:IsInRaidArea() and not (Target and Target.IsDummy and Target:IsDummy()) then
				local packTTD = Player.GetEnemiesRangeTTD and Player:GetEnemiesRangeTTD(30) or 9999
				if packTTD <= 21 then return false, "TTD too low" end
				if Target and Target:Health() and Target:Health() < 60000000 then return false, "Target HP too low" end
			end
		end
		if spell == S.BestialWrath then
			if not Player:IsInRaidArea() and not (Target and Target.IsDummy and Target:IsDummy()) then
				local packTTD = Player.GetEnemiesRangeTTD and Player:GetEnemiesRangeTTD(30) or 9999
				if packTTD <= 18 then return false, "Pack TTD too low" end
				if Target and Target:Health() and Target:Health() < 1000000 then return false, "Target HP too low" end
			end
		end
		if (spell == S.KillCommand or (S.AspectoftheWild and spell == S.AspectoftheWild) or spell == S.BestialWrath) and not Pet:IsActive() then
			return false, "Pet not active"
		end
		if spell == S.DireBeast and MainAddon.Config and MainAddon.Config.GetClassSetting and MainAddon.Config.GetClassSetting('savedb_check') and Player:BuffStack(S.HuntmastersCallBuff) == 2 then
			local avgTTD = MainAddon.TTDAverage and MainAddon.TTDAverage(Enemies40y) or 9999
			local thresh = MainAddon.Config.GetClassSetting('savedb_spin') or 0
			if avgTTD < thresh then return false, "Save KC" end
		end
		return ready, reason
	end, 253)

	MainAddon.SetCustomAPL(Author, SpecID, MainAPL, Init)
end

local function TryLoading ()
	C_Timer.After(1, function()
		if MainAddon then
			MyRoutine()
		else
			TryLoading()
		end
	end)
end
TryLoading()



