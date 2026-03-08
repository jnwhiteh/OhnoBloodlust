--[[-------------------------------------------------------------------
--  OhnoBloodlust - Copyright 2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

--- @class OhnoBloodlust: AddonCore
local addon = select(2, ...)

local L = addon.L

local LEM = LibStub("LibEditMode")

local CUSTOM_MP3_KEY = "CUSTOM MP3"
local CUSTOM_OGG_KEY = "CUSTOM OGG"
local RANDOM_KEY = "RANDOM"

local BLOODLUST_DEBUFFS = {
    [57723]  = true, -- Exhaustion: Shaman Heroism (Alliance) — the Alliance counterpart to Bloodlust, same cooldown family; both 57723 and 57724 prevent reuse of the effect
    [57724]  = true, -- Sated: Shaman Bloodlust (Horde)
    [80354]  = true, -- Temporal Displacement: Mage Time Warp
    [95809]  = true, -- Insanity: Hunter pet Ancient Hysteria
    [160455] = true, -- Fatigued: Hunter pet Primal Rage
    [264689] = true, -- Fatigued: Hunter pet Primal Rage (variant)
    [390435] = true, -- Exhaustion: Evoker Fury of the Aspects
}

function addon:Initialize()
    self.soundRegistry = {
        [RANDOM_KEY] = {
            name = L["Random: A random sound each time (excluding custom)"],
            sort_rank = 0,
        },
         ["FORTHEHORDE"] = {
            name = L["BLOODLUST - FOR THE HORDE"],
            file = "Interface\\AddOns\\OhnoBloodlust\\sounds\\BLOODLUST - FOR THE HORDE.ogg",
        },
        ["FORTHEHORSE"] = {
            name = L["FOR THE HORSE"],
            file = "Interface\\AddOns\\OhnoBloodlust\\sounds\\FOR THE HORSE.ogg",
        },
        ["HEROGOCRAZY"] = {
            name = L["HERO - GO CRAZY"],
            file = "Interface\\AddOns\\OhnoBloodlust\\sounds\\HERO - GO CRAZY.ogg",
        },
        ["RUSHSTART"] = {
            name = L["RUSH START"],
            file = "Interface\\AddOns\\OhnoBloodlust\\sounds\\RUSH START.ogg",
        },
        ["TIMEWARPGOGOGO"] = {
            name = L["TIME WARP - GO GO GO"],
            file = "Interface\\AddOns\\OhnoBloodlust\\sounds\\TIME WARP - GO GO GO.ogg",
        },
        [CUSTOM_OGG_KEY] = {
            name = L["Custom OGG sound file at Interface\\Sounds\\bloodlust.ogg"],
            file = "Interface\\Sounds\\bloodlust.ogg",
            sort_rank = 1,
        },
        [CUSTOM_MP3_KEY] = {
            name = L["Custom MP3 sound file at Interface\\Sounds\\bloodlust.mp3"],
            file = "Interface\\Sounds\\bloodlust.mp3",
            sort_rank = 1,
        },
   }

    self.defaultSound = "FORTHEHORSE"

    self.randomChoices = {}
    for k in pairs(self.soundRegistry) do
        if k ~= CUSTOM_MP3_KEY and k ~= CUSTOM_OGG_KEY and k ~= RANDOM_KEY then
            table.insert(self.randomChoices, k)
        end
    end

    self.channelRegistry = {
        ["Master"] = L["Master"],
        ["Music"] = L["Music"],
        ["SFX"] = L["SFX"],
        ["Ambience"] = L["Ambience"],
        ["Dialog"] = L["Dialog"],
    }
    self.defaultChannel = "Master"

    self.defaults = {
        profile = {
            enabled = true,
            sound = self.defaultSound,
            channel = self.defaultChannel,

            chat = false,
            visual = false,

            layoutPositions = {
            },
        }
    }

    self.db = LibStub("AceDB-3.0"):New("OhnoBloodlustDB", self.defaults, true)

    self.visual = CreateFrame("Frame", "OhnoBloodlustVisual", UIParent)
    self.visual:SetSize(200, 48)

    self.visual.text = self.visual:CreateFontString(nil, "ARTWORK")
    local text = self.visual.text
    text:SetFont("Fonts\\FRIZQT__.TTF", 48, "OUTLINE")
    text:SetPoint("CENTER")

    self.visual.text:SetText(L["|TInterface\\Icons\\spell_nature_bloodlust:18|t Bloodlust!!!"])
    self.visual.text:SetPoint("CENTER", self.visual, "CENTER", 0, 0)

    self.visual:SetPoint("CENTER", 0, 100)

    self.defaultPosition = {
        point = "CENTER",
        y = 285,
        x = 0,
    }

    self.visual:Hide()

    LEM:AddFrame(self.visual, self.OnPositionChanged, self.defaultPosition)
    LEM:RegisterCallback('enter', self.OnEditModeEnter)
    LEM:RegisterCallback('exit', self.OnEditModeExit)
    LEM:RegisterCallback('layout', self.OnLayoutChanged)
end

function addon:Enable()
    self:SetupOptions()
    self:RegisterUnitEvent("UNIT_AURA", "UNIT_AURA", "player")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "PLAYER_REGEN_ENABLED")
end

function addon.OnPositionChanged(frame, layoutName, point, x, y)
    local self = addon

    if not self.db.profile.layoutPositions[layoutName] then
        self.db.profile.layoutPositions[layoutName] = {}
    end
    self.db.profile.layoutPositions[layoutName].point = point
    self.db.profile.layoutPositions[layoutName].x = x
    self.db.profile.layoutPositions[layoutName].y = y
end

function addon.OnEditModeEnter()
    local self = addon
    self.visual:Show()
end

function addon.OnEditModeExit()
    local self = addon
    if not self.active then
        self.visual:Hide()
    end
end

function addon.OnLayoutChanged(layoutName)
    local self = addon
    local config = self.db.profile.layoutPositions[layoutName]
    if not config then
        config = self.defaultPosition
    end

    self.visual:ClearAllPoints()
    self.visual:SetPoint(config.point, config.x, config.y)
end

function addon:HasBloodlustDebuff()
    for spellID in pairs(BLOODLUST_DEBUFFS) do
        if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
            return true
        end
    end
    return false
end

function addon:UNIT_AURA(event, unit)
    if not self.db.profile.enabled then return end

    local hasBuff = self:HasBloodlustDebuff()

    if hasBuff and not self.active then
        self:StartBloodlust()
    elseif not hasBuff and self.active then
        self:StopBloodlust()
    end
end

function addon:StartBloodlust()
    if self.db.profile.chat then
        self:Printf("Detected Bloodlust!")
    end

    self.active = true

    self:PlayConfiguredSoundAndChannel()
    if self.db.profile.visual then
        self.visual:Show()
        C_Timer.After(5.0, function()
            self.visual:Hide()
        end)
    end
end

function addon:StopBloodlust()
    self.active = false

    if self.db.profile.chat then
        self:Printf("Bloodlust faded")
    end

    self.visual:Hide()
end

function addon:PLAYER_REGEN_ENABLED()
    self.active = false
end

function addon:GetRandomSoundFile()
    local choices = self.randomChoices
    local idx = math.random(#choices)
    local value = choices[idx]

    return self.soundRegistry[value].file
end

function addon:PlayConfiguredSoundAndChannel()
    local options = self.db.profile
    local soundFile

    if options.sound == RANDOM_KEY then
        soundFile = self:GetRandomSoundFile()
    else
        soundFile = self.soundRegistry[options.sound].file
    end
	local channel = options.channel

	if self.soundHandle then
		StopSound(self.soundHandle, 500)
	end

	if soundFile and channel then
		local willPlay, soundHandle = PlaySoundFile(soundFile, channel)
        if willPlay then
            self.soundHandle = soundHandle
        end
	end
end
