# Run Recap Forever

🇩🇪 [Deutsche Version](README.de.md)

An addon for **WoW Forever**: after the last boss of a dungeon, a summary of your run opens:
- which bosses you killed, and when
- who got which item from which boss
- fun facts about the run: duration, deaths, wipes, gold

> **Status: in development.** The repository currently holds the basic framework only. The first playable version (0.1) is not released yet.

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

## 2. Commands

| Command | Effect |
|---|---|
| `/recap` | Open the recap of the last run (from 0.1 on; until then a short notice) |
| `/recap debug` | Debug output on/off, shows version, client build and interface number |
| `/recap help` | List the commands |

## 3. Known limitations

- The addon only sees what your own client sees: loot of other players only while you are nearby and in the group.
- If you join in the middle of a run, the recap starts where you joined.

## 4. Feedback and contributing

Bug reports and ideas: [GitHub Issues](https://github.com/Ibona93/RunRecap/issues). Technical notes and tests: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## 5. Changelog

### 0.1.0 (in development)
- Basic framework: saved variables `RunRecapDB`, `/recap` command, texts in 10 languages, fonts (Philosopher, Noto Sans, Cinzel), offline tests.
- Boss data for all 28 dungeons, including the 9 new Forever dungeons (wings for Scarlet Monastery, Dire Maul, Stratholme and Blackrock Spire).
