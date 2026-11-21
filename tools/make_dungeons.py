# Generates Data/Dungeons.lua for Run Recap from DBM-derived IDs plus curated final/optional flags.
# Each boss: key, ids (all known encounter IDs; Forever ID included where DBM lists two), npc IDs,
# req (counts toward "x/y" and the all-bosses rule), final (killing it completes the wing).
D = []
def dungeon(map_id, name, wings, verified=True): D.append((map_id, name, wings, verified))
def b(key, ids, npc, req=True, final=False): return dict(key=key, ids=ids, npc=npc, req=req, final=final)

dungeon(389, "Ragefire Chasm", [("main", [
    b("Oggleflint", [2732], [11517]), b("Taragaman", [2733], [11520]),
    b("Jergosh", [2734], [11518]), b("Bazzalan", [2735], [11519])])])
dungeon(36, "The Deadmines", [("main", [
    b("RhahkZor", [2741, 2967], [644]), b("MinerJohnson", [3676], [3586], req=False),
    b("Sneed", [2742, 2968], [642, 643]), b("Gilnid", [2743, 2969], [1763]),
    b("MrSmite", [2745, 2970], [646]), b("Greenskin", [2744, 2971], [647]),
    b("VanCleef", [2747, 2972], [639], final=True), b("Cookie", [2746, 2986], [645], req=False)])])
dungeon(43, "Wailing Caverns", [("main", [
    b("Anacondra", [585], [3671]), b("Pythas", [588], [3670]), b("Cobrahn", [586], [3669]),
    b("Kresh", [587], [3653], req=False), b("Skum", [589], [3674], req=False),
    b("Serpentis", [590], [3673]), b("Verdan", [591], [5775]),
    b("Mutanus", [592], [3654], final=True)])])
dungeon(48, "Blackfathom Deeps", [("main", [
    b("GhamooRa", [2916, 2761], [4887]), b("Serevess", [2915, 2762], [4831]),
    b("Gelihast", [2914, 2763], [6243]), b("Kelris", [2911, 2766], [4832]),
    b("OldSerrakis", [2912, 2765], [4830], req=False), b("Akumai", [2910, 2767], [4829], final=True)])])
dungeon(34, "The Stockade", [("main", [
    b("Targorr", [2756], [1696]), b("KamDeepfury", [2757], [1666]), b("Hamhock", [2758], [1717]),
    b("BazilThredd", [2760], [1716]), b("DextrenWard", [2759], [1663])])])
dungeon(33, "Shadowfang Keep", [("main", [
    b("Rethilgore", [2748], [3914]), b("Razorclaw", [2749], [3886]), b("Silverlaine", [2750], [3887]),
    b("Springvale", [2751], [4278]), b("Odo", [2752], [4279]), b("Fenrus", [2753], [4274]),
    b("Nandos", [2754], [3927]), b("Arugal", [2755], [4275], final=True)])])
dungeon(47, "Razorfen Kraul", [("main", [
    b("Roogug", [2773], [6168]), b("Aggem", [2774], [4424]), b("Jargba", [2775], [4428]),
    b("Ramtusk", [2776], [4420]), b("Agathelos", [2777], [4422]),
    b("Charlga", [2778], [4421], final=True)])])
dungeon(90, "Gnomeregan", [("main", [
    b("Grubbis", [2768, 379], [7361]), b("ViscousFallout", [2769, 378], [7079]),
    b("Electrocutioner", [2770, 380], [6235]), b("CrowdPummeler", [2771, 381], [6229]),
    b("Thermaplugg", [2772, 382], [7800], final=True)])])
dungeon(189, "Scarlet Monastery", [
    ("graveyard", [b("Vishas", [444], [3983]), b("Thalnos", [2779, 2818, 445], [4543], final=True)]),
    ("library", [b("Loksey", [446], [3974]), b("Doan", [447], [6487], final=True)]),
    ("armory", [b("Herod", [448], [3975], final=True)]),
    ("cathedral", [b("Fairbanks", [449], [4542], req=False),
                   b("MograineWhitemane", [450], [3977, 3976], final=True)])])
dungeon(129, "Razorfen Downs", [("main", [
    b("Tutenkash", [2780], [7355]), b("Plaguemaw", [2781], [7356], req=False),
    b("Mordresh", [2782], [7357]), b("Ragglesnout", [2783], [7354], req=False),
    b("Glutton", [2784], [8567]), b("Amnennar", [2785], [7358], final=True)])])
dungeon(70, "Uldaman", [("main", [
    b("Revelosh", [547], [6910]), b("LostDwarves", [548], [6906, 6907, 6908]),
    b("Ironaya", [549], [7228]), b("ObsidianSentinel", [1887], [7023]),
    b("StoneKeeper", [551], [7206]), b("Galgann", [552], [7291]), b("Grimlok", [553], [4854]),
    b("Archaedas", [554], [2748], final=True)])])
dungeon(209, "Zul'Farrak", [("main", [
    b("Velrath", [593], [7795], req=False), b("Gahzrilla", [594], [7273], req=False),
    b("Antusul", [595], [8127]), b("Theka", [596], [7272]), b("Zumrah", [597], [7271]),
    b("NekrumSezzziz", [598, 599], [7796, 7275]), b("Ukorz", [600], [7267], final=True)])])
dungeon(349, "Maraudon", [("main", [
    b("Noxxion", [422], [13282]), b("Razorlash", [423], [12258]), b("Vyletongue", [424], [12236]),
    b("Celebras", [425], [12225]), b("Landslide", [426], [12203]), b("Gizlock", [427], [13601]),
    b("Rotgrip", [428], [13596]), b("Theradras", [429], [12201], final=True)])])
dungeon(109, "The Temple of Atal'Hakkar", [("main", [
    b("Atalalarion", [3582], [8580], req=False), b("Dreamscythe", [486, 3588], [5721]),
    b("Weaver", [487, 3587], [5720]), b("Jammalan", [488, 3589], [5710]),
    b("Morphaz", [490, 3586], [5719]), b("Hazzas", [491, 3585], [5722]),
    b("AvatarOfHakkar", [492, 3583], [8443]), b("Eranikus", [493, 3584], [5709], final=True)])])
dungeon(230, "Blackrock Depths", [("main", [
    b("Gerstahn", [227], [9018]), b("Roccor", [228], [9025]), b("Grebmar", [229], [9319]),
    b("RingOfLaw", [230], [9028, 9031, 9029, 9030, 9032, 9027]), b("Loregrain", [231], [9024]),
    b("Incendius", [232], [9017]), b("Stilgiss", [233], [9041]), b("Fineous", [234], [9056], req=False),
    b("BaelGar", [235], [9016]), b("Angerforge", [236], [9033]), b("Argelmach", [237], [8983]),
    b("Hurley", [238], [9537], req=False), b("Phalanx", [239], [9502]), b("Plugger", [241], [9499], req=False),
    b("Flamelash", [242], [9156]), b("TheSeven", [243], [9035, 9039, 9040, 9037, 9034, 9038, 9036]),
    b("Magmus", [244], [9938]), b("Thaurissan", [245, 2790], [9019], final=True)])])
dungeon(229, "Blackrock Spire", [
    ("lower", [b("Omokk", [267], [9196]), b("Voshgajin", [268], [9236]), b("Voone", [269], [9237]),
               b("Smolderweb", [270], [10596]), b("Urok", [271], [10584], req=False),
               b("Zigris", [272], [9736]), b("Gizrul", [273], [10268], req=False),
               b("Halycon", [274], [10220]), b("Wyrmthalak", [275], [9568], final=True)]),
    ("upper", [b("Emberseer", [3062], [9816]), b("Rend", [3063], [10339, 10429]),
               b("TheBeast", [3068], [10430]), b("Valthalak", [3070], [16042], req=False),
               b("Drakkisath", [3069], [10363], final=True)])])
dungeon(429, "Dire Maul", [
    ("east", [b("Zevrim", [343], [11490]), b("Hydrospawn", [344], [13280]),
              b("Lethtendris", [345], [14327]), b("Alzzin", [346], [11492], final=True)]),
    ("west", [b("Tendris", [350], [11489]), b("Illyanna", [347], [11488]), b("Kelendris", [348], [11487]),
              b("Immolthar", [349], [11496]), b("Tortheldrin", [361], [11486], final=True)]),
    ("north", [b("Moldar", [362], [14326]), b("Kreeg", [363], [14322]), b("Fengus", [364], [14321]),
               b("Slipkik", [365], [14323]), b("Kromcrush", [366], [14325]), b("ChoRush", [367], [14324]),
               b("Gordok", [368], [11501], final=True)])])
dungeon(289, "Scholomance", [("main", [
    b("Kirtonos", [2805, 451], [10506]), b("Jandice", [2804, 452], [10503]), b("Rattlegore", [2811, 453], [11622]),
    b("Marduk", [2809, 454], [10433]), b("Vectus", [2813, 455], [10432]), b("Ras", [2810, 456], [10508]),
    b("Malicia", [2803, 457], [10505]), b("Krastinov", [2802, 458], [11261]), b("Polkelt", [2808, 459], [10901]),
    b("Ravenian", [2812, 460], [10507]), b("AlexeiBarov", [2807, 461], [10504]),
    b("IlluciaBarov", [2806, 462], [10502]), b("Gandling", [2801, 463], [1853], final=True)])])
dungeon(329, "Stratholme", [
    ("live", [b("Timmy", [474], [10808], req=False), b("Forresten", [473], [10558], req=False),
              b("Unforgiven", [472], [10516], req=False), b("Willey", [475], [10997]),
              b("Malor", [476], [11032], req=False), b("Galford", [477], [10811]),
              b("Postmaster", [1885], [11143], req=False),
              b("Balnazzar", [478], [10813, 10812], final=True)]),
    ("undead", [b("Barthilas", [482], [10435], req=False), b("Anastari", [479], [10436]),
                b("Nerubenkan", [480], [10437]), b("Maleki", [481], [10438]),
                b("Ramstein", [483], [10439]), b("Rivendare", [484], [10440], final=True)])])

# Forever dungeons (IDs from DBM-Party-Forever; boss order = DBM order; FINAL BOSS UNVERIFIED)
def fdun(map_id, name, bosses, final_key):
    dungeon(map_id, name, [("main", [b(k, [i], [], final=(k == final_key)) for k, i in bosses])], verified=False)
fdun(3065, "Hall of Thanes", [("FaldrimAnvilmar", 3493), ("Infurnus", 3495), ("Plunder", 3494), ("DurgenDirgehammer", 3496)], "DurgenDirgehammer")
fdun(2999, "Ruins of Lordaeron", [("Witherfang", 3353), ("TheAbandoned", 3357), ("TheButcher", 3355), ("Rathmael", 3354), ("LordaeronCaptain", 3408), ("ViktorTheVile", 3411), ("Bjork", 3412)], "ViktorTheVile")
fdun(2998, "Excavation Site: Wetlands", [("Saltspine", 3480), ("Shadetooth", 3481), ("HighlandHorror", 3644), ("RelicGuardian", 3482)], "RelicGuardian")
fdun(2959, "City of Dalaran", [("ArcaneAnomaly", 3298), ("FelAncient", 3299), ("ManaDevourer", 3300), ("ManaElemental", 3301), ("UnstableSentinel", 3302), ("ShadeOfTheArchmage", 3303), ("LynTheIgnored", 3310), ("Atrexis", 3311), ("ManaWraith", 3312)], "ShadeOfTheArchmage")
fdun(2970, "The Drowned City", [("ZulAlai", 3474), ("VarTaka", 3475), ("CaptainDreadrise", 3476), ("DeathlessGuardians", 3478), ("PrimevalElemental", 3511), ("Minloth", 3479)], "Minloth")
fdun(3039, "Krol'dok Stronghold", [("SlavecrusherGrox", 3450), ("TwilightCommanderZarmok", 3452), ("HandlerAshka", 3453), ("Nargurk", 3449), ("OverseerMugg", 3451)], "OverseerMugg")
fdun(2994, "Alcaz Prison", [("OverseerWrex", 3403), ("TidemistressCazass", 3410), ("KaterinaTheCleaner", 3418), ("TheQuestioner", 3415), ("Blazeroar", 3409)], "Blazeroar")
fdun(2974, "Blackmaw Hold", [("Withermaw", 3315), ("Impaan", 3316), ("Bloodmane", 3327), ("Bonesnout", 3322), ("Varrox", 3334), ("BlackmawBehemoth", 3323), ("UnboundSpirit", 3336)], "UnboundSpirit")
fdun(3001, "Shaper's Terrace", [("Titanosaur", 3498), ("RavasaurHunters", 3499), ("Thunderhoof", 3500), ("Venomridge", 3501), ("DirehornMatriarch", 3507), ("Cinder", 3503), ("KingOp", 3504), ("Snowtalon", 3597), ("Bolt", 3505), ("Vitrix", 3600), ("Nanaya", 3502)], "Nanaya")

def lua_list(xs): return "{ " + ", ".join(str(x) for x in xs) + " }"
out = ["local _, ns = ...", "",
"--[[",
"Dungeon data: instance (map) ID from GetInstanceInfo() -> wings -> bosses.",
"Generated by tools/make_dungeons.py (not shipped) from DeadlyBossMods/DBM-Dungeons encounter IDs,",
"cross-checked against the Ragefire Chasm probe run (22.11.2026).",
"",
"Boss fields:  key   stable internal name (never shown; names come from ENCOUNTER_END)",
"              ids   every known encounter ID (Forever, Classic Era and older variants)",
"              npc   NPC IDs (for GetLootSourceInfo)",
"              opt   optional/rare: does not count toward x/y or the all-bosses rule",
"              final killing it completes the wing",
"A wing is complete when a final boss dies, or - if the wing has no final boss - when every",
"non-optional boss is dead. verified = false: Forever dungeon, final boss is a guess.",
"]]", "",
"ns.DUNGEONS = {"]
for map_id, name, wings, verified in D:
    out.append(f"\t[{map_id}] = {{ name = \"{name}\"" + ("" if verified else ", verified = false") + ", wings = {")
    for wkey, bosses in wings:
        out.append(f"\t\t{{ key = \"{wkey}\", bosses = {{")
        for x in bosses:
            parts = [f'key = "{x["key"]}"', f"ids = {lua_list(x['ids'])}"]
            if x["npc"]: parts.append(f"npc = {lua_list(x['npc'])}")
            if not x["req"]: parts.append("opt = true")
            if x["final"]: parts.append("final = true")
            out.append("\t\t\t{ " + ", ".join(parts) + " },")
        out.append("\t\t} },")
    out.append("\t} },")
out.append("}")
open(__import__("os").path.join(__import__("os").path.dirname(__file__), "..", "Data", "Dungeons.lua"), "w").write("\n".join(out) + "\n")
n = sum(len(bs) for _, _, ws, _ in D for _, bs in ws)
print(len(D), "dungeons,", n, "bosses")
