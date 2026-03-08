# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Linting

```
luacheck core/ i18n/
```

After modifying `.luacheckrc`, regenerate `.luarc.json` for the Lua LSP:

```
lua scripts/globalizer.lua .luacheckrc .luarc.json
```

## Localization

Never manually edit `i18n/Localization.enUS.lua`. Regenerate it from source using Babelfish:

```
lua scripts/Babelfish.lua core/core.lua core/config.lua > i18n/Localization.enUS.lua
```

## Architecture

This is a World of Warcraft addon. Load order is defined in `OhnoBloodlust.toc` and matters — libs load first, then localization, then addon code.

**`libs/AddonCore.lua`** — bootstraps the addon object (`addon`), sets up event registration, locale support (`addon.L`), and `addon:Printf`. All other files receive `addon` via `select(2, ...)`.

**`core/core.lua`** — defines `addon:Initialize()` (profile defaults, sound/channel registries, visual frame setup) and `addon:Enable()` (event registration). Event handlers `UNIT_AURA` and `PLAYER_REGEN_ENABLED` drive the bloodlust detection logic.

**`core/config.lua`** — builds the WoW Settings UI. Uses proxy settings to bridge the Settings API to `addon.db.profile`. `getValueFromAddonProfile`/`setValueInAddonProfile` accept dot-separated paths into the profile table.

**Profile** (`addon.db.profile`): `enabled`, `chat`, `visual`, `sound`, `channel`, `layoutPositions`. Backed by AceDB-3.0 with per-character defaults.

**Visual indicator** — a frameless `Frame` registered with `LibEditMode`, allowing the player to reposition it via WoW's Edit Mode. Positions are saved per-layout in `layoutPositions`.
