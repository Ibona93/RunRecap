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
| `tests/run.lua` | helpers, `RunRecapDB`, locale completeness, dungeon data, **parsing** of loot/roll/money lines with the deDE global strings the probe recorded in the Forever client, **run logic**: replay of the Ragefire probe run (trash roll, boss roll + winner, loot window source, probable source, wipe, death, ghost run, pause/resume, completion in any order, summary), history, learned items, reset, other copy, other dungeon, login timeout, Deadmines end boss |
| `tests/smoke.lua` | every TOC file loads and runs, every addon `.lua` file is listed in the TOC, `ADDON_LOADED`, TOC version = `ns.VERSION`, `/recap` commands, probe, fonts incl. CJK fallback, **a whole run through real events** (enter, encounters, `START_LOOT_ROLL`, roll/loot/money lines, loot window, deaths, last boss → sound + banner in combat → recap after combat), tooltips (boss, item, rolls, Shift), options fallback window, leave + reset, preview |

New WoW globals used by the addon go into `.luacheckrc`. New features get new checks.

## Probe (hidden developer commands)

Finds out what the WoW Forever client really delivers before features are built on it. Only listens to events; never touches Blizzard frames.

| Command | Effect |
|---|---|
| `/recap probe` | start/stop recording; survives `/reload` |
| `/recap probe clear` | delete the recording |
| `/recap sounds` | play the success sound candidates, 3 s apart, and report which exist |
| `/recap sound <id>` | play one sound kit ID |

Recorded (in `RunRecapDB.probe`, max. 3000 lines): client build, which APIs exist, the loot/roll global strings, `GetInstanceInfo` on zone changes, `ENCOUNTER_START/END`, `BOSS_KILL`, `CHAT_MSG_LOOT`, `CHAT_MSG_MONEY`, roll events, combat start/end, deaths from the combat log (`UNIT_DIED`, `PARTY_KILL`), and per loot window every slot with `GetLootSourceInfo` (NPC ID of the source). Key events are also printed to chat.

The file is written on logout or `/reload`: `_forever_/WTF/Account/<ACCOUNT>/SavedVariables/RunRecap.lua`.

## Run logic (Logic/Run.lua)

| Step | Rule |
|---|---|
| start | entering a known dungeon (`GetInstanceInfo` type `party`, instance ID in `ns.DUNGEONS`) |
| completed | `ns.Dungeons.WingProgress` of the boss's wing; the run keeps recording afterwards (end boss loot is rolled later) |
| leave as ghost | run keeps going (`UnitIsDeadOrGhost("player")`) |
| leave alive | paused, pause time not counted; alive again outside after a ghost run = pause too |
| end | other instance, `INSTANCE_RESET_SUCCESS` while paused, 30 min paused, login ≥ 30 min after last activity; back in the same dungeon after a completed run (left alive) starts a new run. (The creature-GUID copy check was removed on 23.11.2026: it restarted a run in the middle of Dalaran.) |
| history | completed runs → `RunRecapDB.runs` (last 20 per character, `run.char` = name/realm/class; untagged pre-1.0.2 runs count as one group); aborted runs are dropped |
| characters (1.0.2) | `Run.Latest` (recap, `/recap`, minimap) = last run of the logged-in character plus untagged old runs; `RunRecapDB.allChars` = account-wide. Another character's run in progress is not `Run.Current()`: paused outside, ended when this character enters an instance |

Names: Forever's unit functions give the first name, chat lines the full name; a first name with exactly one matching full name is merged into it (`run.alias`).

Loot source, in this order: own loot window (`GetLootSourceInfo` → NPC → boss from the data or learned in `RunRecapDB.learnedNpc`; unknown NPC = trash only where the dungeon's boss NPC IDs are known – the Forever dungeons have none, there an unknown NPC decides nothing and a roll right after a kill teaches NPC → boss) · roll started ≤ 10 s after a kill → that boss, else trash · learned (`RunRecapDB.learned`, item ID → boss) · other players' direct loot ≤ 90 s after a kill → "probably" that boss, else trash. Only green or better items are stored; blue and better are shown by default. A finished roll and the following "X receives loot" line are one item (same item ID, winner, ≤ 300 s).

Deaths: `UnitIsDeadOrGhost` on `player`/`party1-4` at `PLAYER_DEAD`, `UNIT_HEALTH`, `UNIT_FLAGS`, counted once per dying (`run.deadNow`), feign death ignored. Deaths during an encounter are listed at that boss. The facts list at most 5 players under "Deaths" (most deaths first), the rest as "+N more" with the full list in its tooltip; if the box would still reach into the highlights (fonts, long labels), fewer rows are shown.

Roll and loot lines: the item argument of a global string is matched as a whole item link (`Parse.ITEM_CAPTURE`), not `(.-)` – item names can contain the format's own words (deDE "Wurf für Gold: %d für %s von %s" with [Mantel von Doan], 1.0.1). Names with `|`, `[` or `]` are never players (`Parse.IsBadName`, part of `Run.IsPlaceholder`); `Run.RepairNames` fixes runs saved before 1.0.1 on load (suffix match against the run's clean names, otherwise dropped).

Money (own only): looted gold share (`CHAT_MSG_MONEY`) + gold of quests handed in inside the instance (`QUEST_TURNED_IN`, not the reward items) + vendor value of own loot (`GetItemInfo` sell price, grey/white included, items won with a need roll excluded) − repair costs (sum of `repairCost` of the equipped gear from the item tooltips, read per equipment slot, sampled on durability/death/encounter/zone events; a slot only counts what goes above its highest value so far while the run is active - a slot reading low or not at all for a moment is not counted twice; another item in the slot (recognised by its item ID) only moves that slot's base, a vendor visit moves all bases; also sampled every 30 s while the run is active, because tooltips can lag behind the durability event) = balance.

Kills: `ENCOUNTER_END`; Forever sometimes sends none (Elektrokutionator 6000, Gnomeregan). Then a dead known boss NPC in sight (target, nameplate, mouseover: `UNIT_HEALTH`, `PLAYER_TARGET_CHANGED`) or its loot window adds the kill (`Run.OnBossDead`, no fight time); during its own encounter it waits for `ENCOUNTER_END`, which later adds the fight time. Wipes: `ENCOUNTER_END` with success 0, and outside a boss fight a group wipe (everyone dead, or all but one in a group of 4+), counted once until everyone is alive again. Placeholder names (`UNKNOWNOBJECT`) are ignored.

Rare elites (`rare = true` in the dungeon data, always optional): they have no encounter, so they are found the same way by NPC ID (dead in sight after combat, own loot window). They appear only when killed, with a silver "rare" tag, never count toward bosses x/y and never complete a wing. NPC IDs from Wowhead (Classic); the new Forever dungeons have none yet.

Secret values: in instances Forever seals some values (nameplate/target GUIDs in combat, some chat lines), like Retail. Touching them is blocked and logged as taint. Event arguments that are sealed arrive as nil (dispatcher in `Core.lua`), unit function results go through `ns.Plain`, `Parse.Match`/`Parse.CreatureGUID` skip them, and the dead-boss check runs only out of combat (again on `PLAYER_REGEN_ENABLED` for target and nameplates).

Highlights (`Run.Highlights`): candidates fastest boss, toughest boss (most wipes, else longest fight), most loot, most deaths, luckiest roll, unlucky (need rolls, never won), best item; each gets a 0-100 score for how remarkable it is, the 4 best are shown (ties: that order). The facts box is as tall as its content, the highlights box takes the rest.

`/recap demo` shows the success moment with a made-up Deadmines run (`UI/Demo.lua`); nothing is saved.

## Dungeon data

`Data/Dungeons.lua` is generated by `python3 tools/make_dungeons.py` - edit the script, not the Lua file. Sources: encounter and NPC IDs from [DBM-Dungeons](https://github.com/DeadlyBossMods/DBM-Dungeons) (`DBM-Party-Vanilla`, `DBM-Party-Forever`); where DBM lists two IDs (Forever and Classic Era/Retail) both are kept. Final and optional bosses are curated by hand. Forever dungeons: boss order, final and optional bosses checked against the client's DungeonEncounter data (build 1.60.1.70862, via [AdventureGuideClassic](https://github.com/fooxytv/AdventureGuideClassic)) and the ForeverDungeonJournal addon's notes; all encounter IDs of that client list are in the table. Final bosses of Ruins of Lordaeron (Rath'mael) and Alcaz Prison (Blazeroar) confirmed by the author. Forever has no Adventure Guide.

A wing is complete when its final boss dies, or - without a final boss (Ragefire Chasm, The Stockade) - when every non-optional boss is dead. Scarlet Monastery, Dire Maul, Stratholme and Blackrock Spire have several wings.

## In-game test checklist

Offline tests can't replace the game. Before testing, enter `/console taintLog 1`; afterwards the file `Logs\taint.log` is in the client folder. Install **BugSack + BugGrabber** to collect Lua errors.

| # | Test | Expected |
|---|---|---|
| 1 | Log in with the addon enabled | no Lua error, addon listed as "Run Recap Forever" |
| 2 | `/recap demo` | sound "Quest complete", banner fades in in the middle (Cinzel title, dungeon name, status line), ~3 s, fades out, recap opens at the same spot |
| 3 | Preview recap: hover item names, rest of item rows, boss rows; hold Shift | item tooltip + "Looted by"/"Source"; winner with roll, Shift: all rolls; boss: kill time, Shift: wipes/deaths/items |
| 4 | Recap: looks like a Blizzard window (frame, chest portrait, red buttons); drag, Escape, ✕, Close, Options | moves (position kept), closes with the window sound, options open |
| 5 | Options → AddOns → Run Recap Forever | page shows; "Look" and "Success sound" look like dropdowns; skin switch changes the open recap at once; sound list (7 sounds + Off) plays the choice; "Play"; "Show preview"; green items on/off changes the open recap |
| 6 | Run a dungeon to the end | banner + sound after the last boss, recap after combat; bosses with minute and fight time, end boss tag, loot with looters in class colours, late rolls fill in live |
| 7 | Leave as a ghost after a wipe, come back | the run goes on (bosses, deaths kept) |
| 8 | Hearth out alive, come back within 30 min | the run goes on; duration without the time outside |
| 9 | `/reload` in the middle of a run | nothing lost |
| 10 | Deaths in the group | counted once per death, at the boss if during the fight |
| 11 | Reset the instance after a run / enter a fresh copy | old run ends, new run starts |
| 12 | `/recap` after a completed run; `/recap` with none | toggles the recap; "No recap yet" |
| 13 | Taint log after the dungeon | no lines with RunRecap |
| 14 | Minimap button: left-click, right-click, drag, hide in the options, tooltip | recap of the last run; options (after combat if in combat); position kept after /reload; hidden after /reload |
| 15 | Runs per character (1.0.2): main with a run, log in an alt; alt does a run; option "all characters" on/off | alt: "no run with this character yet" (chat + minimap tooltip); then its own run; option on: account's newest run with the name in the header; main again: his run |

## Files

```
RunRecap.toc        Interface 16001, SavedVariables RunRecapDB, IconTexture Media/Icon
Libs/               LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (copied from BugSack, runs on Forever; not linted, not in the TOC check)
Init.lua            namespace, version, locale registry, helpers (Print, Debug, MergeDefaults …)
Locales/*.lua       UI texts in 10 languages (enUS is the base and fallback)
Core.lua            defaults, locale selection, saved variables, events -> run logic, /recap
Data/Dungeons.lua   all dungeons: instance ID -> wings -> bosses (encounter IDs, NPC IDs, optional, final)
Logic/Dungeons.lua  lookups: encounter/NPC ID -> boss, wing complete?
Logic/Parse.lua     global strings -> patterns; loot, roll and money lines; item links; GUIDs; clock, coins
Logic/Run.lua       the run: start/pause/end, bosses, wipes, deaths, loot sources, rolls, summary
Dev/Probe.lua       hidden developer probe: /recap probe, /recap sounds, /recap sound <id>
UI/Fonts.lua        font objects: game font (skin "blizzard", options), Philosopher/Noto Sans (skin "recap"), Cinzel (banner title)
UI/Widgets.lua      skins (native Blizzard templates with fallbacks / dark & gold), dropdown look, colours, Escape handling, popup menu
UI/Banner.lua       success sound + banner, then the recap (after combat)
UI/Recap.lua        recap window, one per skin (bosses & loot, run facts, highlights box) with tooltips
UI/Options.lua      options page (Settings → AddOns, fallback window; in combat it opens after the fight)
UI/Minimap.lua      minimap button (LibDataBroker launcher + LibDBIcon, RunRecapDB.minimap)
Media/Icon.tga      addon icon (minimap button, window portrait, addon list) - tools/make_icon.py from docs/curseforge/icon.svg
UI/Demo.lua         preview with a made-up run (/recap demo)
UI/Tour.lua         introduction tour, once at login (RunRecapDB.tourSeen), /recap tour
UI/WhatsNew.lua     "What's new" once per version at login, version badge lists all releases, /recap news
Data/News.lua       release notes per version (deDE/enUS) - add a page for every CurseForge release
Data/Tour.lua       tour pages (deDE/enUS)
Media/Fonts/        shipped fonts + SIL OFL licenses
Media/Banner*.tga   banner band, gold line, glow (made by tools/make_banner_textures.py)
tests/              offline tests (not shipped)
tools/              generators: make_dungeons.py -> Data/Dungeons.lua, make_banner_textures.py -> Media/Banner*.tga (not shipped)
releases/           release ZIPs (not shipped)
```

## Release ZIP

Folder `RunRecap/` with all addon files, **without** `.git`, `.github`, `releases/`, `tests/`, `docs/`, `tools/`, `.luacheckrc`. Compare the file list with the previous version.

## Style

Two skins for the recap window (`RunRecapDB.skin`): "blizzard" (default) = Blizzard window templates (`ButtonFrameTemplate` → `BasicFrameTemplateWithInset` → dialog backdrop), `InsetFrameTemplate`, `UIPanelButtonTemplate`, game font; "recap" = dark brown, golden borders, Philosopher/Noto Sans. Options and popups always native, dropdowns look like the game's (dark field, yellow arrow) but open our own popup; the success banner has its own look (Cinzel title, TGA band); fonts via `SetFontObject` only; own popups instead of Blizzard menus; links as copyable edit boxes; no `hooksecurefunc` on Blizzard functions; never touch Blizzard's loot or roll frames, only read events.

## Releases (CurseForge)

`.github/workflows/release.yml` (taken over from BGF) uploads every version listed in `releases/notes/releases.txt` to CurseForge (project 1824577, game version 1.60.1) once, with `releases/notes/<version>.md` as changelog (English, `---`, German), records it in `releases/notes/uploaded/<version>` and creates the GitHub release. Line format: `<version> <commit> [release|beta|alpha]`. The ZIP must be `releases/RunRecap-<version>.zip`. Secret `CF_API_TOKEN` (set). Discord announcements are prepared but skipped until webhook secrets exist. A line is only added after the author tested the version and said to upload it. Every release also needs a page in `Data/News.lua`.
