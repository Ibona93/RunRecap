# Run Recap Forever

🇬🇧 [English version](README.md)

Ein Addon für **WoW Forever**: Nach dem Endboss eines Dungeons öffnet sich eine Zusammenfassung deines Runs:
- welche Bosse ihr besiegt habt und wann
- wer welches Item von welchem Boss bekommen hat
- Fakten zum Run: Dauer, Tode, Wipes, Gold

> **Stand: Version 0.1.0 im Test**, noch nicht auf CurseForge.

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

## 2. So funktioniert's

- **Run-Start:** beim Betreten eines Dungeons (alle 28 Dungeons, auch die Forever-Dungeons).
- **Geschafft:** wenn alle Pflichtbosse liegen (Reihenfolge egal) bzw. der Endboss tot ist. Optionale und seltene Bosse zählen nicht. Kloster, Düsterbruch, Stratholme und Schwarzfelsspitze zählen pro Flügel.
- **Erfolgsmoment:** Sound (Standard „Quest abgeschlossen“), dann ein Banner „Dungeon erfolgreich beendet!“ für ein paar Sekunden, danach die Übersicht (nach dem Kampf). Klick aufs Banner überspringt.
- **Übersicht:** links Bosse mit Minute im Run und Kampfdauer, darunter die Beute mit Plünderer; unsichere Zuordnungen unter „? vermutlich von diesem Boss“, Beute von normalen Gegnern unter „Trash“. Rechts Dauer, Bosse, Wipes, Gold, Tode und Highlights.
- **Tooltips:** Itemname → normaler Item-Tooltip plus Plünderer und Quelle. Rest der Zeile → wer gewonnen hat; mit **Umschalt** alle Würfe. Boss-Zeile mit Umschalt → Wipes, Tode im Kampf, Zahl der Items.
- **Instanz verlassen:** als Geist läuft der Run weiter; lebend (z. B. Ruhestein zum Händler) pausiert er. Er endet beim Betreten einer anderen Instanz, beim Zurücksetzen oder nach 30 Minuten draußen.
- Abgebrochene Runs bekommen keine Übersicht.

## 3. Befehle

| Befehl | Wirkung |
|---|---|
| `/recap` | Übersicht des letzten geschafften Runs öffnen/schließen |
| `/recap options` | Optionen öffnen (auch unter Optionen → AddOns) |
| `/recap demo` | Vorschau: Sound, Banner und Übersicht mit einem ausgedachten Run |
| `/recap debug` | Debug-Ausgabe an/aus, zeigt Version, Client-Build, Interface-Nummer und den laufenden Run |
| `/recap help` | Befehle auflisten |

**Optionen:** automatisch öffnen (an/aus), auch grüne Items zeigen (Standard: ab Blau), Darstellung (Blizzard oder Run Recap), Erfolgssound (7 Sounds aus dem Spiel oder aus, mit Probehören), Vorschau.

## 4. Bekannte Einschränkungen

- Das Addon sieht nur, was dein eigener Client mitbekommt: Beute anderer Spieler nur, wenn du in der Nähe und in der Gruppe bist.
- Woher ein Item stammt, weiß das Addon sicher aus deinem eigenen Lootfenster und aus dem Würfeln direkt nach einem Bosskill. Nimmt ein anderer Spieler ein Item ohne Würfeln, ist die Quelle nur „vermutlich“. Einmal sicher zugeordnete Items merkt sich das Addon.
- Wer mitten im Run dazukommt, bekommt die Übersicht ab dem Zeitpunkt des Beitritts.

## 5. Feedback und Mitmachen

Fehler und Ideen: [GitHub Issues](https://github.com/Ibona93/RunRecap/issues). Technische Hinweise und Tests: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) (Englisch).

## 6. Changelog

### 0.1.0 (im Test)
- Erste Version: Übersicht nach dem Endboss mit Bossen (Minute im Run, Kampfdauer, Endboss), Beute pro Boss mit Plünderer in Klassenfarbe, Abschnitt „Trash“ und Fakten zum Run (Dauer, Bosse, Wipes, Gold, Tode, Highlights).
- Erfolgsmoment: Sound und Banner „Dungeon erfolgreich beendet!“, danach die Übersicht.
- Würfe: wer gewonnen hat und mit Umschalt alle Würfe.
- Alle 28 Dungeons, auch die 9 neuen Forever-Dungeons (Flügel für Scharlachrotes Kloster, Düsterbruch, Stratholme und Schwarzfelsspitze).
- Zwei Darstellungen: Blizzard (Standard) oder Run Recap (dunkel & gold); Optionen: automatisch öffnen, grüne Items, Darstellung, Erfolgssound, Vorschau. Texte in 10 Sprachen.
