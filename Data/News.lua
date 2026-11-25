local _, ns = ...

--[[
"What's new" pages, one per release that reached CurseForge (newest first).
German clients get deDE, all other clients enUS (like BGF). Icons are game icons.
New versions: add the page here, put the version first in NEWS_ORDER.
]]

local ICON = {
	chest = ns.ICON or "Interface\\Icons\\INV_Box_02",
	scroll = "Interface\\Icons\\INV_Scroll_03",
	loot = "Interface\\Icons\\INV_Misc_Bag_10",
	dice = "Interface\\Icons\\INV_Misc_Coin_01",
	watch = "Interface\\Icons\\INV_Misc_PocketWatch_01",
	gear = "Interface\\Icons\\INV_Misc_Gear_01",
}
ns.NEWS_ICON = ICON

ns.NEWS_ORDER = { "1.0.2", "1.0.1", "1.0.0" }
ns.NEWS_FIRST = "1.0.0"   -- welcome page for new users

ns.NEWS_UI = {
	enUS = {
		subtitle = "Run Recap Forever",
		show = "Show this after updates", hint = "(also in the options)",
		options = "Open options", ok = "Got it!",
		versions = "Versions", latest = "latest", first = "first release",
	},
	deDE = {
		subtitle = "Run Recap Forever",
		show = "Nach Updates anzeigen", hint = "(auch in den Optionen)",
		options = "Optionen", ok = "Alles klar!",
		versions = "Versionen", latest = "aktuell", first = "erste Version",
	},
}

ns.NEWS = {
	["1.0.2"] = {
		enUS = { title = "Run Recap 1.0.2", items = {
			{ icon = ICON.chest, title = "Your runs per character",
				text = "/recap and the minimap button now show the last run of the character you are playing – your alts no longer see your main's runs. Runs from before this update are shown for every character." },
			{ icon = ICON.gear, title = "Runs of all characters",
				text = "Prefer it the old way? Options → \"Show runs of all characters\". The recap then shows whose run it is.",
				tip = "Options: right-click the minimap button" },
		} },
		deDE = { title = "Run Recap 1.0.2", items = {
			{ icon = ICON.chest, title = "Deine Runs pro Charakter",
				text = "/recap und der Minimap-Button zeigen jetzt den letzten Run des Charakters, den du gerade spielst – deine Twinks sehen nicht mehr die Runs deines Mains. Runs von vor diesem Update werden bei jedem Charakter gezeigt." },
			{ icon = ICON.gear, title = "Runs aller Charaktere",
				text = "Lieber wie vorher? Optionen → „Runs aller Charaktere anzeigen“. Die Übersicht zeigt dann, von wem der Run ist.",
				tip = "Optionen: Rechtsklick auf den Minimap-Button" },
		} },
	},
	["1.0.1"] = {
		enUS = { title = "Run Recap 1.0.1", items = {
			{ icon = ICON.dice, title = "Rolls under the right names",
				text = "Item names with the roll line's own words (in German e.g. \"of\" = \"von\") cut the line in the wrong place – rolls ended up under made-up player names. Fixed, and saved runs are repaired automatically." },
			{ icon = ICON.scroll, title = "Shorter deaths list",
				text = "\"Deaths\" shows at most 5 players, the rest as \"+N more\". The run facts no longer run into the highlights.",
				tip = "Hover \"+N more\" to see every player" },
		} },
		deDE = { title = "Run Recap 1.0.1", items = {
			{ icon = ICON.dice, title = "Würfe unter den richtigen Namen",
				text = "Items mit „von“ im Namen (z. B. „Mantel von Doan“) haben die Würfelzeile an der falschen Stelle getrennt – die Würfe landeten unter ausgedachten Spielernamen. Behoben, gespeicherte Runs werden automatisch repariert." },
			{ icon = ICON.scroll, title = "Kürzere Tode-Liste",
				text = "„Tode“ zeigt höchstens 5 Spieler, der Rest steht als „+N weitere“ da. Die Fakten zum Run laufen nicht mehr in die Highlights.",
				tip = "Maus über „+N weitere“ zeigt alle Spieler" },
		} },
	},
	["1.0.0"] = {
		enUS = { title = "Welcome to Run Recap", items = {
			{ icon = ICON.chest, title = "Your dungeon run at a glance",
				text = "After the last boss Run Recap opens a summary: every boss with the minute in the run and the fight time, who got which loot, and facts about the run." },
			{ icon = ICON.loot, title = "Who got what – and from whom",
				text = "Loot is listed under the boss it came from. Items from normal enemies are under \"Trash\", uncertain sources are marked \"probably\". Rare elites show up when you kill them.",
				tip = "Hold Shift over an item row to see every roll" },
			{ icon = ICON.watch, title = "Facts and highlights",
				text = "Duration, wipes, deaths, your gold, the vendor value of your loot and your repair costs – plus the four most remarkable moments of the run." },
			{ icon = ICON.gear, title = "Your look, your sound",
				text = "Blizzard look or Run Recap's dark & gold, the success sound, green items – all in the options.",
				tip = "/recap demo shows a preview any time" },
		} },
		deDE = { title = "Willkommen bei Run Recap", items = {
			{ icon = ICON.chest, title = "Dein Dungeon-Run auf einen Blick",
				text = "Nach dem Endboss öffnet Run Recap eine Zusammenfassung: jeder Boss mit Minute im Run und Kampfdauer, wer welche Beute bekommen hat und Fakten zum Run." },
			{ icon = ICON.loot, title = "Wer hat was bekommen – und woher",
				text = "Beute steht unter dem Boss, von dem sie kam. Items von normalen Gegnern stehen unter „Trash“, unsichere Quellen sind mit „vermutlich“ markiert. Seltene Elites erscheinen, wenn ihr sie legt.",
				tip = "Umschalt über einer Item-Zeile zeigt alle Würfe" },
			{ icon = ICON.watch, title = "Fakten und Highlights",
				text = "Dauer, Wipes, Tode, dein Gold, der Händlerwert deiner Beute und deine Reparaturkosten – dazu die vier spannendsten Momente des Runs." },
			{ icon = ICON.gear, title = "Dein Look, dein Sound",
				text = "Blizzard-Optik oder Run Recap dunkel & gold, Erfolgssound, grüne Items – alles in den Optionen.",
				tip = "/recap demo zeigt jederzeit eine Vorschau" },
		} },
	},
}

-- Page and UI texts for the client language (German or English).
function ns.NewsLang()
	return ns.clientLocale == "deDE" and "deDE" or "enUS"
end
