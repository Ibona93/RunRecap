local _, ns = ...

--[[
Introduction tour: shown once at login instead of "What's new" (RunRecapDB.tourSeen).
German for German clients, English for all others (like the news pages). No page for the
success banner - it is only a visual effect (Felix, 22.11.2026).

Each page: title, text, optional green tip and `ill` = the illustration drawn by UI/Tour.lua.
`s` holds the words used inside the illustration; items carry their item ID, so icon and name
come from the game (client language). The facts picture uses the preview run (UI/Demo.lua).
]]

ns.TOUR_UI = {
	enUS = {
		title = "Welcome to Run Recap", back = "Back", next = "Next", done = "Done",
		whatsNew = "What's new?", options = "Open options", preview = "Show preview",
		combat = "Run Recap: the options can only be opened out of combat.",
	},
	deDE = {
		title = "Willkommen bei Run Recap", back = "Zurück", next = "Weiter", done = "Fertig",
		whatsNew = "Was ist neu?", options = "Optionen öffnen", preview = "Vorschau zeigen",
		combat = "Run Recap: Die Optionen lassen sich nur außerhalb des Kampfes öffnen.",
	},
}

ns.TOUR = {
	enUS = {
		{ ill = "bosses", title = "It runs by itself",
			text = "Enter a dungeon and Run Recap starts recording. After the last boss the summary opens: every boss with the minute in the run and the fight time.",
			tip = "Leaving as a ghost keeps the run going; hearthing out alive pauses it",
			s = { header = "Bosses & loot", final = "final boss", fight = "fight %s",
				rows = { { "5:12", "Rhahk'Zor", "0:41" }, { "28:08", "Mr. Smite", "0:48" }, { "42:17", "Edwin VanCleef", "1:11", true } } } },
		{ ill = "loot", title = "Who got what – and from whom",
			text = "Loot is listed under its boss, with the looter in class colour. Items from normal enemies go under \"Trash\". If the source is not certain, it is marked \"probably\".",
			tip = "Blue and better by default; green items can be switched on",
			s = { boss = "Edwin VanCleef", probably = "? probably from this boss", trash = "Trash",
				items = { { "Cape of the Brotherhood", 3, "Kesh", "ROGUE", 5193 }, { "Cruel Barb", 3, "Thorgar", "WARRIOR", 5191 } },
				unsure = { "Blackened Defias Armor", 3, "Bram", "HUNTER", 10399 },
				trashItem = { "Blackwater Cutlass", 3, "Lyss", "MAGE", 1951 } } },
		{ ill = "tooltip", title = "Short tooltip, details with Shift",
			text = "Hover an item name for the normal item tooltip with looter and source. Hover the rest of the row to see who won the roll – hold Shift for every roll.",
			tip = "Boss rows too: Shift shows wipes, deaths and items",
			s = { item = "Cruel Barb", itemID = 5191, won = "Thorgar won - Need 87",
				rolls = { { "Thorgar", "WARRIOR", "Need 87" }, { "Bram", "HUNTER", "Need 12" }, { "Kesh", "ROGUE", "Greed 90" }, { "Lyss", "MAGE", "Pass" } } } },
		{ ill = "facts", title = "Facts and highlights",
			text = "On the right: duration, bosses, wipes, deaths and your balance – your gold plus the vendor value of your loot minus repair costs. Below, the four most remarkable highlights of the run.",
			s = {} },
		{ ill = "options", title = "Almost done!",
			text = "In the options you choose the look (Blizzard or Run Recap dark & gold), the success sound and green items. You can start this introduction again there any time.",
			s = { head = "Try it right now:", line = "A made-up run with sound and summary.", slash = "/recap · /recap demo · /recap options" } },
	},
	deDE = {
		{ ill = "bosses", title = "Läuft von allein",
			text = "Betritt einen Dungeon, und Run Recap zeichnet mit. Nach dem Endboss öffnet sich die Übersicht: jeder Boss mit der Minute im Run und der Kampfdauer.",
			tip = "Als Geist raus läuft der Run weiter; lebend per Ruhestein raus pausiert er",
			s = { header = "Bosse & Beute", final = "Endboss", fight = "Kampf %s",
				rows = { { "5:12", "Rhahk'Zor", "0:41" }, { "28:08", "Mr. Smite", "0:48" }, { "42:17", "Edwin van Cleef", "1:11", true } } } },
		{ ill = "loot", title = "Wer hat was bekommen – und woher",
			text = "Beute steht unter ihrem Boss, der Plünderer in Klassenfarbe. Items von normalen Gegnern kommen unter „Trash“. Ist die Quelle nicht sicher, steht „vermutlich“ dabei.",
			tip = "Standardmäßig ab Blau; grüne Items lassen sich einschalten",
			s = { boss = "Edwin van Cleef", probably = "? vermutlich von diesem Boss", trash = "Trash",
				items = { { "Umhang der Bruderschaft", 3, "Kesh", "ROGUE", 5193 }, { "Grausamer Widerhaken", 3, "Thorgar", "WARRIOR", 5191 } },
				unsure = { "Geschwärzte Defiasrüstung", 3, "Bram", "HUNTER", 10399 },
				trashItem = { "Schwarzwasserentermesser", 3, "Lyss", "MAGE", 1951 } } },
		{ ill = "tooltip", title = "Kurzer Tooltip, Details mit Shift",
			text = "Über dem Itemnamen siehst du den normalen Item-Tooltip mit Plünderer und Quelle. Über dem Rest der Zeile, wer den Wurf gewonnen hat – mit Umschalt alle Würfe.",
			tip = "Auch auf Boss-Zeilen: Umschalt zeigt Wipes, Tode und Items",
			s = { item = "Grausamer Widerhaken", itemID = 5191, won = "Thorgar hat gewonnen - Bedarf 87",
				rolls = { { "Thorgar", "WARRIOR", "Bedarf 87" }, { "Bram", "HUNTER", "Bedarf 12" }, { "Kesh", "ROGUE", "Gier 90" }, { "Lyss", "MAGE", "Passen" } } } },
		{ ill = "facts", title = "Fakten und Highlights",
			text = "Rechts: Dauer, Bosse, Wipes, Tode und deine Bilanz – dein Gold plus der Händlerwert deiner Beute minus Reparaturkosten. Darunter die vier spannendsten Highlights des Runs.",
			s = {} },
		{ ill = "options", title = "Fast geschafft!",
			text = "In den Optionen wählst du die Darstellung (Blizzard oder Run Recap dunkel & gold), den Erfolgssound und grüne Items. Die Einführung kannst du dort jederzeit neu starten.",
			s = { head = "Gleich ausprobieren:", line = "Ein ausgedachter Run mit Sound und Übersicht.", slash = "/recap · /recap demo · /recap options" } },
	},
}

function ns.TourPages()
	return ns.TOUR[ns.NewsLang()] or ns.TOUR.enUS
end

function ns.TourUI()
	return ns.TOUR_UI[ns.NewsLang()] or ns.TOUR_UI.enUS
end
