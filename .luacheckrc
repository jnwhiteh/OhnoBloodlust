std = "lua51"
max_line_length = false
codes = true
exclude_files = {
	"**/libs",
}
only = {
	"011", -- syntax
	"1", -- globals
}
ignore = {
	"11/SLASH_.*", -- slash handlers
	"1/[A-Z][A-Z][A-Z0-9_]+", -- three letter+ constants
}
globals = {
    "strsplit",
    "math",

    "FormatPercentage",
    "MinimalSliderWithSteppersMixin",
    "PlaySoundFile",
    "Settings",
    "UnitSpellHaste",
    "CreateSettingsButtonInitializer",
    "StopSound",

    "LibStub",
    "Enum",
    "C_UnitAuras",
    "C_Timer",
}
