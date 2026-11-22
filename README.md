# Run Recap Forever

🇩🇪 [Deutsche Version](README.de.md)

An addon for **WoW Forever**: after the last boss of a dungeon, a summary of your run opens:
- which bosses you killed, and when
- who got which item from which boss
- fun facts about the run: duration, deaths, wipes, gold

> **Status: version 0.1.0 in testing**, not on CurseForge yet.

Author: **Ibona93** · License: MIT (see [`LICENSE`](LICENSE); bundled fonts: SIL OFL 1.1)
Game version: WoW Forever **1.60.1, Interface 16001**

Sister addon: [BGF – Better Group Finder Forever](https://github.com/Ibona93/BetterGroupFinder)

---

## 1. Installation

1. Close the game (or type `/reload` afterwards).
2. Unzip the file. You get a folder named `RunRecap`.
3. Copy this folder into the `Interface\AddOns` folder of your WoW Forever client.
4. The folder must contain `RunRecap.toc` directly. `RunRecap\RunRecap\…` does not work.
5. On the character selection screen, open **AddOns** and enable "Run Recap Forever".

## 2. How it works

- **Run start:** when you enter a dungeon (all 28 dungeons, including the Forever dungeons).
- **Completed:** when every required boss is dead (any order) or the end boss is dead. Optional and rare bosses don't count. Scarlet Monastery, Dire Maul, Stratholme and Blackrock Spire count per wing.
- **Success moment:** a sound (default "Quest complete"), then a "Dungeon completed!" banner for a few seconds, then the recap (after combat). Click the banner to skip it.
- **Recap:** on the left the bosses with the minute in the run and fight duration, below each the loot and who got it; uncertain sources under "? probably from this boss", loot from normal enemies under "Trash". On the right duration, bosses, wipes, gold, deaths and highlights.
- **Tooltips:** item name → the normal item tooltip plus looter and source. Rest of the row → who won; hold **Shift** for all rolls. Boss row with Shift → wipes, deaths in the fight, number of items.
- **Leaving the instance:** as a ghost the run keeps going; alive (e.g. hearthstone to a vendor) it is paused. It ends when you enter another instance, when the instance is reset, or after 30 minutes outside.
- Aborted runs get no recap.

## 3. Commands

| Command | Effect |
|---|---|
| `/recap` | Open/close the recap of the last completed run |
| `/recap options` | Open the options (also under Options → AddOns) |
| `/recap demo` | Preview: sound, banner and recap with a made-up run |
| `/recap debug` | Debug output on/off, shows version, client build, interface number and the current run |
| `/recap help` | List the commands |

**Options:** open automatically (on/off), show green items too (default: blue and better), success sound (7 game sounds or off, with preview), preview.

## 4. Known limitations

- The addon only sees what your own client sees: loot of other players only while you are nearby and in the group.
- The addon knows an item's source for sure from your own loot window and from rolls right after a boss kill. If another player takes an item without a roll, the source is only "probably". Items with a known source are remembered.
- If you join in the middle of a run, the recap starts where you joined.

## 5. Feedback and contributing

Bug reports and ideas: [GitHub Issues](https://github.com/Ibona93/RunRecap/issues). Technical notes and tests: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## 6. Changelog

### 0.1.0 (in testing)
- First version: recap after the last boss with bosses (minute in the run, fight duration, end boss), loot per boss with the looter in class colour, a "Trash" section and run facts (duration, bosses, wipes, gold, deaths, highlights).
- Success moment: sound and "Dungeon completed!" banner, then the recap.
- Rolls: who won, and with Shift every roll.
- All 28 dungeons, including the 9 new Forever dungeons (wings for Scarlet Monastery, Dire Maul, Stratholme and Blackrock Spire).
- Options: open automatically, green items, success sound, preview. Texts in 10 languages.
