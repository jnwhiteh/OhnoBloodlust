--[[-------------------------------------------------------------------
--  OhnoBloodlust - Copyright 2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

local addonName = select(1, ...)

--- @class OhnoBloodlust: AddonCore
local addon = select(2, ...)

local L = addon.L

function addon:Initialize()
    self.soundRegistry = {
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
        ["CUSTOM OGG"] = {
            name = L["Custom sound file at Interface\\Sounds\\bloodlust.ogg"],
            file = "Interface\\Sounds\\bloodlust.ogg",
        },
        ["CUSTOM MP3"] = {
            name = L["Custom sound file at Interface\\Sounds\\bloodlust.mp3"],
            file = "Interface\\Sounds\\bloodlust.mp3",
        },
    }
    self.defaultSound = "FORTHEHORSE"

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
            debug = false,

            detection = {
                spike_ratio = 190,
                jump_ratio = 140,
                fade_ratio = 115,
            },
        }
    }

    self.db = LibStub("AceDB-3.0"):New("OhnoBloodlustDB", self.defaults, true)
end

function addon:Enable()
    self:SetupOptions()
    self:RegisterEvent("COMBAT_RATING_UPDATE", "UpdateHasteRating")
    self:RegisterEvent("UNIT_SPELL_HASTE", "UpdateHasteRating")

    self.bloodlustActive = false

    self:SetHasteBaseline()
    self:UpdateHasteRating()
end

function addon:SetHasteBaseline()
    local haste = UnitSpellHaste("player")
    self.values = {haste, haste, haste, haste, haste}
end

local function mean(v)
    local sum = 0
    for i = 1, 5 do
        sum = sum + v[i]
    end
    return sum / 5
end

function addon:IsBloodlust(v, current)
    local options = self.db.profile.detection
    local m = mean(v)

    local maxv = math.max(v[1], v[2], v[3], v[4], v[5])

    local ratio = current / m
    local jump = current / maxv

    local spike_ratio = options.spike_ratio / 100
    local jump_ratio = options.jump_ratio / 100
    return ratio >= spike_ratio and jump >= jump_ratio
end

function addon:UpdateHasteRating()
    local options = self.db.profile

    if not options.enabled then
        return
    end

    local v = self.values
    local current = UnitSpellHaste("player")

    local m = mean(v)
    local lust = self:IsBloodlust(v, current)

    if options.debug then
        self:Printf("New rating: %0.2f, mean: %0.2f, bloodlust: %s", current, m, tostring(lust))
    end

    -- START detection
    if not self.bloodlustActive and lust then
        if options.chat then
            self:Printf("Bloodlust detected")
        end

        self.bloodlustActive = true
        self.lockedBaseline = m

		self:PlayConfiguredSoundAndChannel()

        return -- IMPORTANT: do not contaminate baseline
    end

    -- STOP detection
    if self.bloodlustActive then
        local ratio = current / self.lockedBaseline
        local fade_ratio = options.fade_ratio / 100

        if ratio < fade_ratio then
            if options.chat then
                self:Printf("Bloodlust faded")
            end

            self.bloodlustActive = false
            self.lockedBaseline = nil

            -- Resume baseline updates immediately
        else
            return -- Still active, do NOT update baseline
        end
    end

    -- Normal baseline update
    v[1] = v[2]
    v[2] = v[3]
    v[3] = v[4]
    v[4] = v[5]
    v[5] = current
end

function addon:PlayConfiguredSoundAndChannel()
    local options = self.db.profile
	local soundFile = self.soundRegistry[options.sound].file
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

