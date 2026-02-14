local addonName = ...

--- @class OhnoBloodlust: AddonCore
local addon = select(2, ...)
local L = addon.L

local strsplit = strsplit

local function getValueFromAddonProfile(profilePath)
    return function()
        local profile = addon.db.profile
        local current = profile

        local path = {strsplit(".", profilePath)}
        for _, key in ipairs(path) do
            current = current[key]
            if current == nil then
                addon:Printf("Could not get settings key '%s' in path '%s'", tostring(key), tostring(profilePath))
            end
        end
        return current
    end
end

local function setValueInAddonProfile(profilePath)
    return function(value)
        local profile = addon.db.profile
        local current = profile

        local path = {strsplit(".", profilePath)}
        for idx = 1, #path - 1 do
            current = current[path[idx]]
            if current == nil then
                addon:Printf("Could not set settings key '%s' in path '%s'", tostring(path[idx]), tostring(profilePath))
            end
        end

        -- We're at the last step of the chain here
        local lastKey = path[#path]
        current[lastKey] = value
    end
end

local function createCheckbox(category, proxyKey, profilePath, defaultValue, name, tooltip)
    local getValue = getValueFromAddonProfile(profilePath)
    local setValue = setValueInAddonProfile(profilePath)
    local setting = Settings.RegisterProxySetting(
        category,
        string.format("%s_PROXY_%s", string.upper(addonName), proxyKey),
        Settings.VarType.Boolean,
        name,
        defaultValue,
        getValue,
        setValue)
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function FormatScaledPercentage(value)
    return FormatPercentage(value / 100)
end

local function createSlider(category, proxyKey, profilePath, defaultValue, minValue, maxValue, step, name, tooltip)
    local getValue = getValueFromAddonProfile(profilePath)
    local setValue = setValueInAddonProfile(profilePath)
    local setting = Settings.RegisterProxySetting(
        category,
        string.format("%s_PROXY_%s", string.upper(addonName), proxyKey),
        Settings.VarType.Number,
        name,
        defaultValue,
        getValue,
        setValue)

    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatScaledPercentage)
    Settings.CreateSlider(category, setting, options, tooltip)
end

local function createDropdown(category, proxyKey, profilePath, defaultValue, values, name, tooltip)
    local getValue = getValueFromAddonProfile(profilePath)
    local setValue = setValueInAddonProfile(profilePath)

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for _, opts in ipairs(values) do
            container:Add(opts.key, opts.name)
        end
        return container:GetData()
    end

    local setting = Settings.RegisterProxySetting(
        category,
        string.format("%s_PROXY_%s", string.upper(addonName), proxyKey),
        Settings.VarType.String,
        name,
        defaultValue,
        getValue,
        setValue)
    Settings.CreateDropdown(category, setting, GetOptions, tooltip)
end

--[[-------------------------------------------------------------------
-- Create addon options
-------------------------------------------------------------------]]--

function addon:SetupOptions()
    local category = Settings.RegisterVerticalLayoutCategory(addonName)

    createCheckbox(
        category,
        "ENABLED",
        "enabled",
        addon.defaults.profile.enabled,
        L["Enable Bloodlust detection"],
        L["Turns on the detection of Bloodlust-like effects on your character and playing of custom sounds"]
    )

    createCheckbox(
        category,
        "CHAT",
        "chat",
        addon.defaults.profile.chat,
        L["Show bloodlust detection messages in chat"],
        L["A message will be shown in chat when the addon detects a Bloodlist-like effect and when it fades"]
    )

    createCheckbox(
        category,
        "DEBUG",
        "debug",
        addon.defaults.profile.debug,
        L["Show debug messages in chat"],
        L["A message will be shown every time the player's haste rating changes, this can be spammy"]
    )

    createCheckbox(
        category,
        "VISUAL",
        "visual",
        addon.defaults.profile.visual,
        L["Show an icon and message when detected"],
        L["When bloodlust is detected an icon and message will appear. You can move this using Edit Mode"]
    )

    createSlider(
        category,
        "SPIKE_RATIO",
        "detection.spike_ratio",
        addon.defaults.profile.detection.spike_ratio,
        140,
        240,
        1.0,
        L["Bloodlust detection spike ratio"],
        L["This option specifies the ratio against baseline to detect the use of Bloodlust-like effects. Setting it lower will trigger more often on other types of effects, like Power Infusion.\n\nDefault value: %s"]:format(tostring(addon.defaults.profile.detection.spike_ratio))
    )

    createSlider(
        category,
        "JUMP_RATIO",
        "detection.jump_ratio",
        addon.defaults.profile.detection.jump_ratio,
        110,
        160,
        1.0,
        L["Haste jump/spike ratio"],
        L["This ratio can prevent gradual haste increases from triggering detection.\n\nDefault value: %s"]:format(tostring(addon.defaults.profile.detection.jump_ratio))
    )

    createSlider(
        category,
        "FADE_RATIO",
        "detection.fade_ratio",
        addon.defaults.profile.detection.fade_ratio,
        105,
        130,
        1.0,
        L["Fade ratio"],
        L["This option specifies how close to normal your haste must return before the Bloodlust-like event is considered over.\n\nDefault value: %s"]:format(tostring(addon.defaults.profile.detection.fade_ratio))
    )

    local soundOptions = {}
    for key, opts in pairs(self.soundRegistry) do
        table.insert(soundOptions, {key = key, name = opts.name})
    end

    local soundOptionComparator = function(opta,optb)
        local a = opta.key
        local b = optb.key
        local ra = self.soundRegistry[a].sort_rank or 2
        local rb = self.soundRegistry[b].sort_rank or 2

        if ra ~= rb then
            return ra < rb
        end

        local namea = (self.soundRegistry[a].name or ""):lower()
        local nameb = (self.soundRegistry[b].name or ""):lower()
        return namea < nameb
    end
    table.sort(soundOptions, soundOptionComparator)

    createDropdown(
        category,
        "SOUND_FILE",
        "sound",
        addon.defaults.profile.sound,
        soundOptions,
        L["Sound to play"],
        L["The sound to play when a Bloodlust-like effect is detected. The supplied soundfiles were created with Suno and are commercially licensed to the Addon author.\n\nFor the 'Custom' option, the file must be placed in Interface\\Sounds\\bloodlust.ogg"]
    )

    -- Sound channels
    local soundChannels = {}
    for key, name in pairs(self.channelRegistry) do
        table.insert(soundChannels, {key = key, name = name})
    end

    table.sort(soundChannels, function(a, b) return a.name < b.name end)

    createDropdown(
        category,
        "SOUND_CHANNEL",
        "channel",
        addon.defaults.profile.channel,
        soundChannels,
        L["Sound channel to use"],
        L["The sound channel to use when playing the sound. The volume of the sound will be affected your sound options for that channel."]
    )

    -- Create a button to preview the selected sound on the selected channel
    local function OnButtonClick()
        addon:PlayConfiguredSoundAndChannel()
    end

    local initializer = CreateSettingsButtonInitializer(L["Preview sound"], L["Preview sound"], OnButtonClick, L["Preview the selected sound file on the selected channel"], false)
    Settings.RegisterInitializer(category, initializer)

    Settings.RegisterAddOnCategory(category)
end
