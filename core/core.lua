--[[-------------------------------------------------------------------
--  OhnoBloodlust - Copyright 2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

local addonName = select(1, ...)

--- @class OhnoBloodlust: AddonCore
local addon = select(2, ...)

local L = addon.L

function addon:Initialize()
end

function addon:Enable()
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

local function stddev(v, m)
    local sum = 0
    for i = 1, 5 do
        local d = v[i] - m
        sum = sum + d * d
    end
    return math.sqrt(sum / 5)
end

local function isBloodlust(v, current)
    local m = mean(v)

    local maxv = math.max(v[1], v[2], v[3], v[4], v[5])

    local ratio = current / m
    local jump = current / maxv

    return ratio >= 1.9 and jump >= 1.4
end

function addon:UpdateHasteRating()
    local v = self.values
    local current = UnitSpellHaste("player")

    local m = mean(v)
    local s = stddev(v, m)
    local lust = isBloodlust(v, current)

    --self:Printf("New rating: %0.2f, mean: %0.2f, stddev: %0.2f, bloodlust: %s", current, m, s, tostring(lust))

    -- START detection
    if not self.bloodlustActive and lust then
        self:Printf("Bloodlust detected")

        self.bloodlustActive = true
        self.lockedBaseline = m

        PlaySoundFile("Interface/Sounds/WA/jump-bloodlust.ogg", "Master")

        return -- IMPORTANT: do not contaminate baseline
    end

    -- STOP detection
    if self.bloodlustActive then
        local ratio = current / self.lockedBaseline

        if ratio < 1.15 then
            self:Printf("Bloodlust faded")

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

