local _, ns = ...

--[[
Preview (options button, /recap demo): plays the success moment with a made-up Deadmines run,
so banner, sound and recap window can be checked without a dungeon. The demo run is never
saved and changes nothing in RunRecapDB.
]]

local Demo = {}
ns.Demo = Demo

local function link(id, q, name)
	local hex = ({ [2] = "1eff00", [3] = "0070dd", [4] = "a335ee" })[q]
	return ("|cff%s|Hitem:%d::::::::|h[%s]|h|r"):format(hex, id, name)
end

local function item(id, q, name, looter, source, sure, extra)
	local it = { link = link(id, q, name), itemID = id, quality = q, count = 1, looter = looter, source = source,
		sure = sure, rolls = {} }
	for k, v in pairs(extra or {}) do it[k] = v end
	return it
end

function Demo.Run()
	local now = ns.Now()
	local run = {
		id = 0, demo = true, mapID = 36, name = "The Deadmines", date = now, startedAt = now - 2537,
		pausedTotal = 0, state = "active", completed = true, completedAt = 2537,
		kills = {
			{ key = "RhahkZor", name = "Rhahk'Zor", at = 312, fight = 41, wing = "main" },
			{ key = "Sneed", name = "Sneed", at = 905, fight = 63, wing = "main" },
			{ key = "Gilnid", name = "Gilnid", at = 1270, fight = 52, wing = "main" },
			{ key = "MrSmite", name = "Mr. Smite", at = 1688, fight = 48, wing = "main" },
			{ key = "Greenskin", name = "Captain Greenskin", at = 2101, fight = 39, wing = "main" },
			{ key = "VanCleef", name = "Edwin VanCleef", at = 2537, fight = 71, wing = "main", final = true },
		},
		killed = { RhahkZor = 1, Sneed = 2, Gilnid = 3, MrSmite = 4, Greenskin = 5, VanCleef = 6 },
		wings = { main = true }, completedWings = { main = 2537 },
		wipes = 1, bossWipes = { MrSmite = 1 }, bossDeaths = { MrSmite = { "Mirela", "Kesh" } },
		deaths = { Mirela = 2, Kesh = 1 }, deadNow = {},
		players = { Kesh = "ROGUE", Mirela = "PRIEST", Thorgar = "WARRIOR", Lyss = "MAGE", Bram = "HUNTER" },
		money = 41387, vendor = 23510, repair = 12040,
		items = {
			item(5187, 3, "Rhahk'Zor's Hammer", "Thorgar", 1, true,
				{ historyID = 1, rolls = { Thorgar = { choice = "need", value = 64 }, Kesh = { choice = "greed", value = 90 } } }),
			item(5195, 2, "Gold-flecked Gloves", "Lyss", 2, true),
			item(5194, 3, "Taskmaster Axe", "Thorgar", 2, true,
				{ historyID = 2, rolls = { Thorgar = { choice = "need", value = 87 }, Bram = { choice = "need", value = 12 },
					Lyss = { choice = "pass" } } }),
			item(5199, 3, "Smelting Pants", "Mirela", 3, false),
			item(7230, 3, "Smite's Mighty Hammer", "Thorgar", 4, true,
				{ historyID = 3, rolls = { Thorgar = { choice = "need", value = 55 }, Kesh = { choice = "greed", value = 71 } } }),
			item(5193, 3, "Cape of the Brotherhood", "Kesh", 6, true,
				{ historyID = 4, rolls = { Kesh = { choice = "need", value = 98 }, Mirela = { choice = "greed", value = 33 } } }),
			item(5191, 3, "Cruel Barb", "Kesh", 6, true, { historyID = 5, rolls = { Kesh = { choice = "need", value = 77 } } }),
			item(10399, 3, "Blackened Defias Armor", "Bram", 6, false),
			item(2169, 2, "Buzzer Blade", "Bram", 2, true),
			item(1951, 3, "Blackwater Cutlass", "Kesh", "trash", true,
				{ historyID = 6, rolls = { Kesh = { choice = "greed", value = 59 }, Bram = { choice = "greed", value = 22 } } }),
		},
	}
	return run
end

function Demo.Show()
	local run = Demo.Run()
	ns.Banner.PlaySound()
	ns.Banner.Show(run, function(r)
		if InCombatLockdown and InCombatLockdown() then return end
		ns.Recap.Show(r)
	end)
	return run
end
