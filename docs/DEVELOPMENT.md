# Run Recap – Development notes

Technical notes for working on Run Recap Forever: offline tests, the in-game test checklist and the file layout. For features and usage see the [README](../README.md).

## Fixed names (never change after the first release)

| What | Value |
|---|---|
| Addon folder / TOC | `RunRecap` / `RunRecap.toc` |
| Saved variables | `RunRecapDB` |
| Slash command | `/recap` (`SLASH_RUNRECAP1`, `SlashCmdList.RUNRECAP`) |

## Offline tests

Requirements: Lua 5.1 and [luacheck](https://github.com/lunarmodules/luacheck).

```sh
# Debian/Ubuntu
apt-get install -y lua5.1 luarocks
luarocks --lua-version=5.1 install luacheck

# from the repository root
lua5.1 tests/run.lua     # helpers, saved variables, completeness of all locale files
lua5.1 tests/smoke.lua   # whole addon loaded in TOC order against a mocked WoW API
luacheck . -q            # static checks (config in .luacheckrc)
```

All three must pass before a release.

| Test | Scope |
|---|---|
| `luacheck` | all Lua files |
| `tests/run.lua` | helpers (`MergeDefaults`, `CopyTable`, `NormalizeLocale`, `TryCall`), `RunRecapDB` creation and upgrade, every locale file has every English key with the same placeholders and no extra keys |
| `tests/smoke.lua` | every TOC file loads and runs, every addon `.lua` file is listed in the TOC, `ADDON_LOADED`, TOC version = `ns.VERSION`, `/recap` commands, fonts incl. CJK fallback |

New WoW globals used by the addon go into `.luacheckrc`. New features get new checks.

## In-game test checklist

Offline tests can't replace the game. Before testing, enter `/console taintLog 1`; afterwards the file `Logs\taint.log` is in the client folder. Install **BugSack + BugGrabber** to collect Lua errors.

| # | Test | Expected |
|---|---|---|
| 1 | Log in with the addon enabled | no Lua error, addon listed as "Run Recap Forever" |
| 2 | `/recap` | notice "no recap yet" + command list, in the client language |
| 3 | `/recap debug` twice | "on" with version 0.1.0, client build and interface 16001; then "off" |
| 4 | `/reload`, then `/recap debug` | setting survived the reload (saved variables work) |

## Files

```
RunRecap.toc        Interface 16001, SavedVariables RunRecapDB
Init.lua            namespace, version, locale registry, helpers (Print, Debug, MergeDefaults …)
Locales/*.lua       UI texts in 10 languages (enUS is the base and fallback)
Core.lua            defaults, locale selection, saved variables, events, /recap
UI/Fonts.lua        font objects: Philosopher (headings), Noto Sans (text), game font on CJK clients
Media/Fonts/        shipped fonts + SIL OFL licenses
tests/              offline tests (not shipped)
releases/           release ZIPs (not shipped)
```

## Release ZIP

Folder `RunRecap/` with all addon files, **without** `.git`, `.github`, `releases/`, `tests/`, `docs/`, `.luacheckrc`. Compare the file list with the previous version.

## Style

Follows BGF: dark brown/black windows, golden headings and borders, green hints; Philosopher + Noto Sans via `SetFontObject` only; own popups instead of Blizzard menus; links as copyable edit boxes; no `hooksecurefunc` on Blizzard functions; never touch Blizzard's loot or roll frames, only read events.
