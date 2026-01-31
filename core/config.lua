local addonName = ...

local db = {}

FOO_DB = db

--- @class OhnoBloodlust: AddonCore
local addon = select(2, ...)

local category = Settings.RegisterVerticalLayoutCategory(addonName)

local module = {}

function module:CreateDropdown(category)
    local function GetValue()
        if db.dropdown == "ALPHA" then
            return 1
        elseif db.dropdown == "BETA" then
            return 2
        elseif db.dropdown == "GAMMA" then
            return 3
        else
            return 2
        end
    end

    local function SetValue(value)
        if value == 1 then
            db.dropdown = "ALPHA"
        elseif value == 2 then
            db.dropdown = "BETA"
        elseif value == 3 then
            db.dropdown = "GAMMA"
        end
    end

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(1, "Alpha")
        container:Add(2, "Beta")
        container:Add(3, "Gamma")
        return container:GetData()
    end

    local defaultValue = 2
    local setting = Settings.RegisterProxySetting(
        category,
        string.format("%s_PROXY_%s", string.upper(addonName), "DROPDOWN_ALPHA"),
        Settings.VarType.Number,
        "Dropdown alpha beta gamma",
        defaultValue,
        GetValue,
        SetValue)
    Settings.CreateDropdown(category, setting, GetOptions, "Tooltip for alpha beta gamma dropdown")
end

function module:CreateCheckbox(category)

    local function GetValue()
        return not not db.checkbox
    end

    local function SetValue(value)
        db.checkbox = not not value
    end
    local defaultValue = false
    local setting = Settings.RegisterProxySetting(
        category,
        string.format("%s_PROXY_%s", string.upper(addonName), "CHECKBOX"),
        Settings.VarType.Boolean,
        "Checkbox control",
        defaultValue,
        GetValue,
        SetValue)
    Settings.CreateCheckbox(category, setting, "Tooltip for the dropdown")
end

function module:CreateSlider(category)
    local max = 3.0
    local default = 1.5

    local function GetValue()
        return db.slider and db.slider or default
    end

    local function SetValue(value)
        db.slider = value
    end 

    local setting = Settings.RegisterProxySetting(
        category,
        "PROXY_OHNOBLOODLUST_SLIDER",
        Settings.VarType.Number,
        "Slider control",
        default,
        GetValue,
        SetValue)

    local minValue, maxValue, step = 0, max, 0.01
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)

    local initializer = Settings.CreateSlider(category, setting, options, "Some tooltip for slider")

end

module:CreateDropdown(category)
module:CreateCheckbox(category)
module:CreateSlider(category)

Settings.RegisterAddOnCategory(category)
