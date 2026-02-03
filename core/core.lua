--[[-------------------------------------------------------------------
--  OhnoBloodlust - Copyright 2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

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
                spike_ratio = 160,
                jump_ratio = 140,
                fade_ratio = 115,
            },
        }
    }

    self.db = LibStub("AceDB-3.0"):New("OhnoBloodlustDB", self.defaults, true)
end

function addon:Enable()
    -- We're going to wait until after we load to kick in and register things <3
    self:SetupOptions()

    C_Timer.After(2.0, function()
        self:RegisterEvent("COMBAT_RATING_UPDATE", "UpdateHasteRating")
        self:RegisterEvent("UNIT_SPELL_HASTE", "UpdateHasteRating")
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "PLAYER_REGEN_ENABLED")
        self:RegisterUnitEvent("UNIT_AURA", "UNIT_AURA", "player")

        self:SetHasteBaseline()
        self:UpdateHasteRating()
    end)

    self.maybeHaste = false
    self.maybeSated = false
end

function addon.Timer_Callback(timer)
    local self = addon

    self:Printf("Tick: maybeHaste: %s, maybeSated: %s", tostring(self.maybeHaste), tostring(self.maybeSated))
    if self.maybeHaste and self.maybeSated then
        self:StartBloodlust()
        timer:Cancel()
    end
end

function addon:StartTimer()
    if self.timer and not self.timer:IsCancelled() then return end

    self:Printf("Started new timer")
    self.timer = C_Timer.NewTicker(0.1, self.Timer_Callback, 15)
    self.timer.start = GetTime()
end

function addon:StopTimer()
    self.timer:Cancel()
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

function addon:IsMaybeBloodlust(v, current)
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
    local maybeLust = self:IsMaybeBloodlust(v, current)

    -- START detection
    if not self.maybeHaste and maybeLust then
        if options.debug then
            self:Printf("Detected (maybe) a haste spike")
        end

        self.lockedBaseline = m
        self.maybeHaste = true
        self:StartTimer()

        if options.debug and current ~= v[5] then
            self:Printf("New rating: %0.2f, mean: %0.2f, maybeHaste: %s, maybeSated", current, m, tostring(self.maybeHaste), tostring(self.maybeSated))
        end
        return -- IMPORTANT: do not contaminate baseline
    end

    -- STOP detection
    if self.active then
        local ratio = current / self.lockedBaseline
        local fade_ratio = options.detection.fade_ratio / 100

        if ratio < fade_ratio then
            self:StopBloodlust()
            -- Resume baseline updates immediately
        else
            return -- Still active, do NOT update baseline
        end
    end

    if options.debug and current ~= v[5] then
        self:Printf("New rating: %0.2f, mean: %0.2f, maybeLust: %s", current, m, tostring(maybeLust))
    end

    -- Normal baseline update
    v[1] = v[2]
    v[2] = v[3]
    v[3] = v[4]
    v[4] = v[5]
    v[5] = current
end

function addon:StartBloodlust()
    self:Printf("Detected Bloodlust!")

    local v = self.values
    local m = mean(v)

    self.lockedBaseline = m
    self.active = true

    self:PlayConfiguredSoundAndChannel()
end

function addon:StopBloodlust()
    self.maybeHaste = false
    self.maybeSated = false
    self.lockedBaseline = nil
    self.active = false

    if self.db.profile.chat then
        self:Printf("Bloodlust faded")
    end
end

-- Compare the stored auras with the new ones, and guess if we have sated :)
local function maybeSatedInAuras(previous, current)
    -- They should be sorted by expiration time and stable
    -- walk through and see if we've gained a debuff in the
    -- first few slots

    local numCurrent = current and #current or 0
    local numPrevious = previous and #previous or 0

    --print(numCurrent, numPrevious)

    if numCurrent > numPrevious then
        -- We gained a buff, good enough for me :)
        return true
    elseif numCurrent < numPrevious then
        -- A debuff fell off, probably not Sated
        return false
    end

    -- Check to see if any of the auras changed (or changes order)
    for idx = 1, math.min(numCurrent, numPrevious) do
        if previous[idx].auraInstanceID ~= current[idx].auraInstanceID then
            return true
        end
    end
end

function addon:UNIT_AURA(event, unit)
    if unit ~= "player" then return end

    local current = C_UnitAuras.GetUnitAuras(unit, "HARMFUL", 4, Enum.UnitAuraSortRule.ExpirationOnly, Enum.UnitAuraSortDirection.Reverse)
    local maybeSated = maybeSatedInAuras(self.previous, current)

    if maybeSated then
        local options = self.db.profile
        if options.debug then
            self:Printf("Detected (maybe) Sated")
        end

        self.maybeSated = true
        self:StartTimer()
    end

    -- Store what we have for next time
    self.previous = current
end

function addon:PLAYER_REGEN_ENABLED()
    -- If we just exited combat, we can probably safely reset things
    self.active = false
    self.maybeHaste = false
    self.maybeSated = false
    self.lockedBaseline = nil
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

