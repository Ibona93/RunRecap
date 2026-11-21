# Run Recap Forever

🇬🇧 [English version](README.md)

Ein Addon für **WoW Forever**: Nach dem Endboss eines Dungeons öffnet sich eine Zusammenfassung deines Runs:
- welche Bosse ihr besiegt habt und wann
- wer welches Item von welchem Boss bekommen hat
- Fakten zum Run: Dauer, Tode, Wipes, Gold

> **Stand: in Entwicklung.** Im Repository liegt bisher nur das Grundgerüst. Die erste spielbare Version (0.1) ist noch nicht veröffentlicht.

Autor: **Ibona93** · Lizenz: MIT (siehe [`LICENSE`](LICENSE); mitgelieferte Schriften: SIL OFL 1.1)
Spielversion: WoW Forever **1.60.1, Interface 16001**

Schwester-Addon: [BGF – Better Group Finder Forever](https://github.com/Ibona93/BetterGroupFinder)

---

## 1. Installation

1. Spiel schließen (oder danach `/reload` eingeben).
2. Datei entpacken. Du bekommst einen Ordner `RunRecap`.
3. Diesen Ordner in den Ordner `Interface\AddOns` deines WoW-Forever-Clients kopieren.
4. Im Ordner muss direkt `RunRecap.toc` liegen. `RunRecap\RunRecap\…` funktioniert nicht.
5. In der Charakterauswahl unter **AddOns** „Run Recap Forever“ aktivieren.

## 2. Befehle

| Befehl | Wirkung |
|---|---|
| `/recap` | Übersicht des letzten Runs öffnen (ab 0.1; bis dahin ein kurzer Hinweis) |
| `/recap debug` | Debug-Ausgabe an/aus, zeigt Version, Client-Build und Interface-Nummer |
| `/recap help` | Befehle auflisten |

## 3. Bekannte Einschränkungen

- Das Addon sieht nur, was dein eigener Client mitbekommt: Beute anderer Spieler nur, wenn du in der Nähe und in der Gruppe bist.
- Wer mitten im Run dazukommt, bekommt die Übersicht ab dem Zeitpunkt des Beitritts.

## 4. Feedback und Mitmachen

Fehler und Ideen: [GitHub Issues](https://github.com/Ibona93/RunRecap/issues). Technische Hinweise und Tests: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) (Englisch).

## 5. Changelog

### 0.1.0 (in Entwicklung)
- Grundgerüst: SavedVariables `RunRecapDB`, Befehl `/recap`, Texte in 10 Sprachen, Schriften (Philosopher, Noto Sans, Cinzel), Offline-Tests.
- Bossdaten für alle 28 Dungeons, auch die 9 neuen Forever-Dungeons (Flügel für Scharlachrotes Kloster, Düsterbruch, Stratholme und Schwarzfelsspitze).
