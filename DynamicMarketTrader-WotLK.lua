--[[
DynamicMarketTrader-WotLK
    This script was originally developed by Dinkledork, all credit goes to him.
    Please support Dinkledork's work by visiting his Patreon page: https://www.patreon.com/Dinklepack5
    This script is maintained by Ghostsupthere
-----------------------------------------------------------------------------------------------------------------------------------------------

    Not every tradeskill item is included as this is meant to provide a basis but still require other tradeskills to make certain items
    Some items may be missing as this is a WIP by me
    I have left two of the categories as placeholders incase you wish to add potions or enchanted vellums or anything else
	
-----------------------------------------------------------------------------------------------------------------------------------------------
	
	This script was created for smaller private servers as a means to allow players some semblance of an auctionhouse. In its current interation, the ah module for Acore leaves a lot to be desired.
	Please feel free to adjust any values you see fit.
	
	Features include:
	The script uses a dynamic pricing system for items, with prices changing based on several factors, including the day of the week, the time of day, and a global fluctuation value. This means that prices will vary from month to month, day to day, hour to hour.
	1. Inflation: The script includes an inflation system that increases prices over time, based on a defined monthly inflation rate. The inflation system can be enabled or disabled as needed.
	2. Price Caps: The script includes a maximum inflation multiplier that limits the amount prices can increase due to inflation.
	3. Price Fluctuations: The script includes a system for randomly fluctuating prices. This feature can be enabled or disabled as needed.
	4. Detailed Item Categories: The script allows for detailed item categorization, with support for item icons and colors based on item quality.
	5. Quantity Selection: The script allows players to select the quantity of an item they wish to buy or sell, with the price per unit displayed.
	6. Mail Delivery: Items bought from the trader are delivered to the player's mailbox.
	7. Customization: Many aspects of the script can be customized, including the NPC IDs, buy and sell multipliers, inflation rate, the time at which the server started, 
	the maximum inflation multiplier, the multipliers for different days of the week and times of the day, and the items and categories available.
	8. Supports Multiple Currencies: The script supports a system where it can convert prices into different types of currency (gold, silver, copper) for display purposes, all of which mimic auctionhouse structure.
	9. GM Commands: The script includes GM commands for checking multipliers and updating global fluctuations.
	
	GM Commands:
	.vprices 
	This command provides the GM with a detailed breakdown of the current state of the price multipliers and percentages. When a GM enters "vprices", they'll receive a series of messages that include:
	-The day of the week and its associated multiplier
	-The current hour and its associated multiplier
	-The global fluctuation multiplier
	-The inflation multiplier
	-The total price multiplier
	-The buy and sell global multipliers
	
	.vprices shuffle
	This command allows the GM to shuffle the global fluctuation, effectively randomizing the current state of the economy. After using this command, the GM receives a message stating the new global fluctuation.
	
	.vbp
	This command allows the GM to set a new buy multiplier. 
	The GM needs to input the command followed by the desired value (e.g., "vbp 0.5" would set the buy multiplier to 0.5). After setting the new buy multiplier, the GM receives a message confirming the change. 
	The GM is also informed that this change will be reset when the server restarts.
	
	.vsp 
	This command is similar to "vbp", but it adjusts the sell multiplier instead. 
	After the GM enters the command and the desired value, they receive a confirmation message and a reminder that the change will be reset when the server restarts.	
]]

local NPCIDs = {180002} -- add more npcids with commas as needed. .npc add 180000 in the world where desired (for my repack users, I've already done so).
local BUY_PERCENTAGE = 0.90  -- Define the buy constant multiplier. I have this set lower due to inflation. If disabled, maybe set it higher.
local SELL_PERCENTAGE = 0.80  -- Define the sell constant multiplier. Sell is lower to mimic auctionhouse cuts and to prevent cheating. Players can still make profit but they have to be more methodical. ah cut is 5% but I like 10% better.
local INFLATION_RATE = 0.033 -- monthly percentage increase in prices of 3.3% is default. Inflation increases in real time. Can change to be higher or lower.
local FLUCTUATION_ENABLED = true -- enable or disable hourly price fluctuations
local INFLATION_ENABLED = true -- enable or disable inflation
local ORIGINAL_TIMESTAMP = 1690504446 -- Time in unix, currently set to Sat Jun 27 2023. You'll want to set the time in unix for when your server started https://www.unixtimestamp.com/ Inflation will be calculated based on the time difference from this point.
local MAX_INFLATION_MULTIPLIER = 2.0  -- Maximum price multiplier due to inflation. 2.0 corresponds to 100% inflation. 3.0 would be 200%, etc. This ensures inflation never goes to rediculous amounts. You can adjust as necessary. Doubtful many will play for that length of time.


-- Mapping day of the week to the multiplier. Adjust as you see fit. See further below for time of day multipliers.
local DAY_MULTIPLIER = {
    [1] = 1.0,  -- Sunday (Quiet, weekend over)
    [2] = 1.03, -- Monday (Regular day, pre-reset prep)
    [3] = 1.12,  -- Tuesday (Server reset day, high demand)
    [4] = 1.09, -- Wednesday (Popular raid day)
    [5] = 1.07, -- Thursday (Popular raid day)
    [6] = 1.05, -- Friday (Beginning of the weekend, player count rises)
    [7] = 1.02, -- Saturday (Typical day, demand stabilizes)
}


local ITEM_QUALITY_COLORS = {
    [0] = "9d9d9d", -- Poor, Gray
    [1] = "ffffff", -- Common, White
    [2] = "1eff00", -- Uncommon, Green
    [3] = "0070dd", -- Rare, Blue
    [4] = "a335ee", -- Epic, Purple
    [5] = "ff8000", -- Legendary, Orange
    [6] = "e6cc80"  -- Artifact, Light Yellow
}

-- Constants for sender id
local BUY_SELL = 1
local BUY_CATEGORY = 2
local SELL_CATEGORY = 3
local BUY_SUBCATEGORY = 4
local SELL_SUBCATEGORY = 5
local BUY_QUANTITY = 6
local SELL_QUANTITY = 7

local GLOBAL_FLUCTUATION = 0 -- Don't change


-- Pricing will need adjusted based on your servers needs if you are forking this
-- Please note that certain items are not included, some may be oversight as this is a WIP, but certain items such as epic gems are not included on purpose
-- If you wish to add them, just copy a line and use WoWhead for the iconID, itemID and then price accordingly to your needs
-- Feel free to disable any item by commenting it out.

local categories = {
  { name = "|TInterface\\Icons\\inv_misc_herb_goldclover:40:40:-42|t|cff006400Herbs|r", intid = 100, items = { 
        { name = "|TInterface\\Icons\\inv_misc_herb_goldclover:36:36:-42|tGoldclover", id = 36901, price = 45000 },
        { name = "|TInterface\\Icons\\inv_misc_herb_constrictorgrass:36:36:-42|tDeadnettle", id = 37921, price = 45000 },
        { name = "|TInterface\\Icons\\inv_misc_herb_11a:36:36:-42|tFire Leaf", id = 39970, price = 45000 },
		{ name = "|TInterface\\Icons\\inv_misc_herb_tigerlily:36:36:-42|tTiger Lily", id = 36904, price = 45000 },
        { name = "|TInterface\\Icons\\inv_misc_herb_talandrasrose:36:36:-42|tTalandra's Rose", id = 36907, price = 45000 },
        { name = "|TInterface\\Icons\\inv_misc_herb_evergreenmoss:36:36:-42|tAdder's Tongue", id = 36903, price = 45000 },
        { name = "|TInterface\\Icons\\inv_misc_herb_whispervine:36:36:-42|tLichbloom", id = 36905, price = 45000 },
        { name = "|TInterface\\Icons\\inv_misc_herb_icethorn:36:36:-42|tIcethorn", id = 36906, price = 45000 },
        { name = "|TInterface\\Icons\\inv_misc_herb_frostlotus:36:36:-42|tFrost Lotus", id = 36908, price = 75000 },
    }},
	{ name = "|TInterface\\Icons\\inv_inscription_pigment_azure:40:40:-42|t|cff483D8BPigments|r", intid = 900, items = { 
        { name = "|TInterface\\Icons\\inv_inscription_pigment_azure:36:36:-42|tAzure Pigment", id = 39343, price = 150000 },
		{ name = "|TInterface\\Icons\\inv_inscription_pigment_icy:36:36:-42|tIcy Pigment", id = 43109, price = 200000 },
    }},
	{ name = "|TInterface\\Icons\\inv_inscription_inkpurple01:40:40:-42|t|cff00008BInk|r", intid = 800, items = {
		{ name = "|TInterface\\Icons\\inv_inscription_inkpurple01:36:36:-42|tInk of the Sea", id = 43124, price = 300000 },
        { name = "|TInterface\\Icons\\inv_inscription_inkbluewhite01:36:36:-42|tSnowfall Ink", id = 57716, price = 400000 },
    }},
    { name = "|TInterface\\Icons\\inv_fabric_soulcloth:40:40:-42|t|cffFFFFFFCloth|r", intid = 200, items = {
        { name = "|TInterface\\Icons\\inv_fabric_soulcloth:36:36:-42|tFrostweave Cloth", id = 33470, price = 8700 }, 
        { name = "|TInterface\\Icons\\inv_fabric_frostweave_bolt:36:36:-42|tBolt of Frostweave", id = 41510, price = 43500 }, 
        { name = "|TInterface\\Icons\\inv_fabric_frostweave_imbuedbolt:36:36:-42|tBolt of Imbued Frostweave", id = 41511, price = 48500 },
        { name = "|TInterface\\Icons\\inv_fabric_ebonweave:36:36:-42|tEbonweave", id = 41593, price = 80000 },
        { name = "|TInterface\\Icons\\inv_fabric_moonshroud:36:36:-42|tMoonshroud", id = 56001, price = 150000 },
        { name = "|TInterface\\Icons\\inv_fabric_spellweave:36:36:-42|tSpellweave", id = 56003, price = 150000 },
    }},
    { name = "|TInterface\\Icons\\inv_misc_leatherscrap_15:40:40:-42|t|cffFFFF00Skinning - Basic|r", intid = 300, items = { 
        { name = "|TInterface\\Icons\\inv_misc_leatherscrap_15:36:36:-42|tBorean Leather", id = 33568, price = 90000 },
        { name = "|TInterface\\Icons\\inv_misc_leatherscrap_19:36:36:-42|tHeavy Borean Leather", id = 38425, price = 180000 },
    }},
	{ name = "|TInterface\\Icons\\inv_misc_pelt_14:40:40:-42|t|cff333300Skinning - Advanced|r", intid = 400, items = { 
	    { name = "|TInterface\\Icons\\inv_misc_pelt_14:36:36:-42|tArctic Fur", id = 44128, price = 750000 },
        { name = "|TInterface\\Icons\\inv_misc_monsterscales_19:36:36:-42|tIcy Dragonscale", id = 38557, price = 80000 },
        { name = "|TInterface\\Icons\\inv_misc_monsterscales_18:36:36:-42|tJormungar Scale", id = 38561, price = 80000 },
        { name = "|TInterface\\Icons\\inv_misc_nerubianchitin_01:36:36:-42|tNerubian Chitin", id = 38558, price = 80000 },
	}},
    { name = "|TInterface\\Icons\\inv_misc_food_119_rhinoMeat:40:40:-42|t|cff8B0000Cooking Ingredients - Meat|r", intid = 500, items = {
        { name = "|TInterface\\Icons\\inv_misc_ammo_gunpowder_05:36:36:-42|tNorthern Spices", id = 43007, price = 500000 }, -- This is a daily reward, comment if you dont want it
        { name = "|TInterface\\Icons\\inv_misc_food_137_meat:36:36:-42|tWorm Meat", id = 43010, price = 50000 }, 
        { name = "|TInterface\\Icons\\inv_misc_food_135_meat:36:36:-42|tShoveltusk Flank", id = 43009, price = 50000 },
        { name = "|TInterface\\Icons\\inv_misc_food_107_venison:36:36:-42|tChunk o' Mammoth", id = 34736, price = 50000 },
		{ name = "|TInterface\\Icons\\inv_misc_food_72:36:36:-42|tWorg Haunch", id = 43011, price = 50000 },
        { name = "|TInterface\\Icons\\inv_misc_food_119_rhinomeat:36:36:-42|tRhino Meat", id = 43012, price = 50000 },
    }},
    { name = "|TInterface\\Icons\\inv_misc_fish_51:40:40:-42|t|cff0000CDCooking Ingredients - Seafood|r", intid = 600, items = {
        { name = "|TInterface\\Icons\\inv_misc_ammo_gunpowder_05:36:36:-42|tNorthern Spices", id = 43007, price = 50000 }, -- This is a daily reward, comment if you dont want it
        { name = "|TInterface\\Icons\\inv_misc_fish_54:36:36:-42|tDragonfin Angelfish", id = 41807, price = 50000 },
        { name = "|TInterface\\Icons\\inv_misc_fish_70:36:36:-42|tMoonglow Cuttlefish", id = 41801, price = 50000 },
        { name = "|TInterface\\Icons\\inv_misc_fish_51:36:36:-42|tGlacial Salmon", id = 41809, price = 50000 },	
        { name = "|TInterface\\Icons\\inv_misc_food_126_clammeat:36:36:-42|tSucculent Clam Meat", id = 36782, price = 50000 },
        { name = "|TInterface\\Icons\\inv_misc_fish_67:36:36:-42|tFangtooth Herring", id = 41810, price = 50000 }, 
        { name = "|TInterface\\Icons\\inv_misc_fish_48:36:36:-42|tBonescale Snapper", id = 41808, price = 50000 }, 
        { name = "|TInterface\\Icons\\inv_misc_fish_59:36:36:-42|tImperial Manta Ray", id = 41802, price = 50000 }, 
        { name = "|TInterface\\Icons\\inv_misc_fish_72:36:36:-42|tNettlefish", id = 41813, price = 50000 }, 
        { name = "|TInterface\\Icons\\inv_misc_fish_62:36:36:-42|tMusselback Sculpin", id = 41806, price = 50000 }, 
    }},
    { name = "|TInterface\\Icons\\inv_misc_dust_infinite:40:40:-42|t|cff9400D3Enchanting|r", intid = 700, items = {
        { name = "|TInterface\\Icons\\inv_misc_dust_infinite:36:36:-42|tInfinite Dust", id = 34054, price = 50000 },
        { name = "|TInterface\\Icons\\inv_enchant_essencecosmiclesser:36:36:-42|tLesser Cosmic Essence", id = 34056, price = 100000 },
        { name = "|TInterface\\Icons\\inv_enchant_essencecosmicgreater:36:36:-42|tGreater Cosmic Essence", id = 34055, price = 300000 },
        { name = "|TInterface\\Icons\\inv_enchant_dreamshard_01:36:36:-42|tSmall Dream Shard", id = 34053, price = 150000 },
        { name = "|TInterface\\Icons\\inv_enchant_dreamshard_02:36:36:-42|tDream Shard", id = 34052, price = 450000 },
        { name = "|TInterface\\Icons\\inv_enchant_abysscrystal:36:36:-42|tAbyss Crystal", id = 34057, price = 5000000 },
    }},
    { name = "|TInterface\\Icons\\inv_rod_platinum:40:40:-42|t|cff006400Rods|r", intid = 1400, items = {
        { name = "|TInterface\\Icons\\inv_rod_platinum:36:36:-42|tTitanium Rod", id = 41745, price = 300000 }, 
    }},
    { name = "|TInterface\\Icons\\inv_ore_cobalt:40:40:-42|t|cff004C99Ore|r", intid = 1000, items = {
        { name = "|TInterface\\Icons\\inv_ore_cobalt:36:36:-42|tCobalt Ore", id = 36909, price = 75000 },
        { name = "|TInterface\\Icons\\inv_ore_saronite_01:36:36:-42|tSaronite Ore", id = 36912, price = 100000 },
        { name = "|TInterface\\Icons\\inv_ore_platinum_01:36:36:-42|tTitanium Ore", id = 36910, price = 150000 },
    }},
   { name = "|TInterface\\Icons\\inv_ingot_cobalt:40:40:-42|t|cff2F4F4FIngots|r", intid = 1100, items = {
        { name = "|TInterface\\Icons\\inv_ingot_cobalt:36:36:-42|tCobalt Bar", id = 36916, price = 150000 }, 
        { name = "|TInterface\\Icons\\inv_ingot_yoggthorite:36:36:-42|tSaronite Bar", id = 36913, price = 200000 },
        { name = "|TInterface\\Icons\\inv_ingot_platinum:36:36:-42|tTitanium Bar", id = 41163, price = 300000 },
        { name = "|TInterface\\Icons\\inv_ingot_titansteel_blue:36:36:-42|tTitansteel Bar", id = 37663, price = 7500000 },
    }},
    { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_04:40:40:-42|t|cff800080Gems|r", intid = 1200, items = {
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_12:36:36:-42|tBloodstone", id = 36917, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_10:36:36:-42|tChalcedony", id = 36923, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_07:36:36:-42|tDark Jade", id = 36932, price = 350000 }, 
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_09:36:36:-42|tHuge Citrine", id = 36929, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_11:36:36:-42|tShadow Crystal", id = 36926, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_08:36:36:-42|tSun Crystal", id = 36920, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_03:36:36:-42|tAutumn's Glow", id = 36921, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_01:36:36:-42|tForest Emerald", id = 36933, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_02:36:36:-42|tMonarch Topaz", id = 36930, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_04:36:36:-42|tScarlet Ruby", id = 36918, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_05:36:36:-42|tSky Sapphire", id = 36924, price = 350000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_gem_06:36:36:-42|tTwilight Opal", id = 36927, price = 350000 },
        { name = "|TInterface\\Icons\\inv_misc_gem_pearl_09:36:36:-42|tNorthsea Pearl", id = 36783, price = 400000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_icediamond_01:36:36:-42|tSkyflare Diamond", id = 41266, price = 500000 },
        { name = "|TInterface\\Icons\\inv_jewelcrafting_shadowspirit_01:36:36:-42|tEarthsiege Diamond", id = 41334, price = 500000 },
    }},
	{ name = "|TInterface\\Icons\\inv_elemental_primal_shadow:40:40:-42|t|cff6600CCEssences & Elementals|r", intid = 1500, items = {
        { name = "|TInterface\\Icons\\inv_elemental_crystal_fire:36:36:-42|tCrystallized Fire", id = 37702, price = 200000 },
        { name = "|TInterface\\Icons\\inv_elemental_crystal_water:36:36:-42|tCrystallized Water", id = 37705, price = 200000 },
        { name = "|TInterface\\Icons\\inv_elemental_crystal_life:36:36:-42|tCrystallized Life", id = 37704, price = 200000 },
        { name = "|TInterface\\Icons\\inv_elemental_crystal_shadow:36:36:-42|tCrystallized Shadow", id = 37703, price = 200000 },
        { name = "|TInterface\\Icons\\inv_elemental_crystal_air:36:36:-42|tCrystallized Air", id = 37700, price = 200000 },
        { name = "|TInterface\\Icons\\inv_elemental_crystal_earth:36:36:-42|tCrystallized Earth", id = 37701, price = 200000 },
        { name = "|TInterface\\Icons\\spell_shadow_manaburn:36:36:-42|tEternal Might", id = 40248, price = 4000000 },
    }},
        { name = "|TInterface\\Icons\\inv_inscription_weaponscroll03:40:40:-42|t|cff8B008BVellum|r", intid = 1300, items = {
        { name = "|TInterface\\Icons\\inv_inscription_weaponscroll03:36:36:-42|tWeapon Vellum III", id = 43146, price = 450000 },
        { name = "|TInterface\\Icons\\inv_inscription_armorscroll03:36:36:-42|tArmor Vellum III", id = 43145, price = 150000 },
    }}, 
    { name = "|TInterface\\Icons\\Ability_seal:40:40:-42|t|cff606060WIP|r", intid = 1600, items = {  --Placeholders \ WIP
    }},
}

local function UpdateFluctuation()
    if FLUCTUATION_ENABLED then
        GLOBAL_FLUCTUATION = math.random(-5, 5) / 100
    end
end

local function OnServerStartupWotLKFluctuation(event)
	print("WoTLK Trader startup event triggered.")
    UpdateFluctuation()
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:19:19:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:19:19:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:19:19:2:0|t"

local function convertMoney(copper)
    local gold = math.floor(copper / 10000)
    copper = copper - gold * 10000
    local silver = math.floor(copper / 100)
    copper = copper - silver * 100

    local moneyStr = ""

    if gold > 0 then
        moneyStr = moneyStr .. gold .. GOLD_ICON .. " "
    end

    if silver > 0 then
        moneyStr = moneyStr .. silver .. SILVER_ICON .. " "
    end

    if copper > 0 or moneyStr == "" then
        moneyStr = moneyStr .. math.floor(copper) .. COPPER_ICON
    end

    return moneyStr
end

local function GetItemColor(quality)
    return ITEM_QUALITY_COLORS[quality] or "ffffff" -- White color by default if no quality match
end

local function GetItemString(item)
    local itemTemplate = GetItemTemplate(item.id) -- Get the item template
    local quality = itemTemplate:GetQuality() -- Get the item quality from the item template
    local color = GetItemColor(quality)
    local itemName = string.match(item.name, "|t(.*)") -- Exclude the icon from the item name
    return "|cff" .. color .. " [" .. itemName .. "]|r"
end


local intidToEntity = {}
for _, category in ipairs(categories) do
    intidToEntity[category.intid] = category
    for i, item in ipairs(category.items) do
        intidToEntity[category.intid * 100 + i] = item
    end
end

local function getDayOfWeek()
    return os.date("*t").wday
end

local function getCurrentHour()
    return os.date("*t").hour
end

-- Get time of day multiplier. Adjust as you see fit.
local function getTimeMultiplier()
    local hour = getCurrentHour()
    local TIME_MULTIPLIER = {
        [0] = 0.96,   -- 12am
        [1] = 0.96,  -- 1am
        [2] = 0.96,  -- 2am
        [3] = 0.96,  -- 3am
        [4] = 0.96,   -- 4am
        [5] = 0.97,   -- 5am
        [6] = 0.97,  -- 6am
        [7] = 0.98,   -- 7am
        [8] = 0.98,  -- 8am
        [9] = 0.99,   -- 9am
        [10] = 1.00, -- 10am
        [11] = 1.01, -- 11am
        [12] = 1.02, -- 12pm
        [13] = 1.03,  -- 1pm
        [14] = 1.04,  -- 2pm
        [15] = 1.05, -- 3pm
        [16] = 1.05, -- 4pm
        [17] = 1.06,  -- 5pm (peak time start)
        [18] = 1.06,  -- 6pm
        [19] = 1.07,  -- 7pm
        [20] = 1.07,  -- 8pm
        [21] = 1.06, -- 9pm
        [22] = 1.05, -- 10pm (peak time end)
        [23] = 1.04  -- 11pm
    }
    return TIME_MULTIPLIER[hour]
end

local function getPriceMultiplier()
    local dayOfWeek = getDayOfWeek()
    local elapsedTimeInMonths = os.difftime(os.time(), ORIGINAL_TIMESTAMP) / (30 * 24 * 60 * 60)
    local inflationMultiplier = 1
    if INFLATION_ENABLED then
        inflationMultiplier = (1 + INFLATION_RATE) ^ elapsedTimeInMonths
        inflationMultiplier = math.min(inflationMultiplier, MAX_INFLATION_MULTIPLIER)
    end
    return DAY_MULTIPLIER[dayOfWeek] * getTimeMultiplier() * inflationMultiplier + GLOBAL_FLUCTUATION
end

local function ShowMainMenu(player, unit)
    player:GossipClearMenu()
    player:GossipMenuAddItem(1, "Buy", 1, 0)
    player:GossipMenuAddItem(1, "Sell", 1, 1)
    player:GossipSendMenu(1, unit)
end

local function ShowItemMenu(player, unit, items, intid)
    for i, item in ipairs(items) do
        player:GossipMenuAddItem(1, item.name .. " - " .. convertMoney(item.price * getPriceMultiplier()), intid, i)
    end
    player:GossipSendMenu(1, unit)
end

local function OnGossipHelloWotLKTrader(event, player, object)
    ShowMainMenu(player, object)
end

local function OnGossipSelectWotLKTrader(event, player, object, sender, intid, code, menu_id)
    player:GossipClearMenu()
    if sender == BUY_SELL then
        local buyOrSell = intid == 0 and "Buy" or "Sell"
        player:GossipMenuAddItem(3, "Current Page: |cff" .. (buyOrSell == "Buy" and "0000ff" or "006400") .. buyOrSell .. "|r | Switch to |cff" .. (buyOrSell == "Sell" and "0000ff" or "006400") .. (buyOrSell == "Buy" and "Sell" or "Buy") .. "|r Page", BUY_SELL, intid == 0 and 1 or 0)

        for _, category in ipairs(categories) do
            player:GossipMenuAddItem(0, category.name, buyOrSell == "Buy" and BUY_CATEGORY or SELL_CATEGORY, category.intid)
        end
        player:GossipMenuAddItem(3, "Current Page: |cff" .. (buyOrSell == "Buy" and "0000ff" or "006400") .. buyOrSell .. "|r | Switch to |cff" .. (buyOrSell == "Sell" and "0000ff" or "006400") .. (buyOrSell == "Buy" and "Sell" or "Buy") .. "|r Page", BUY_SELL, intid == 0 and 1 or 0)

        player:GossipSendMenu(1, object)
    elseif sender == BUY_CATEGORY or sender == SELL_CATEGORY then
        local category = intidToEntity[intid]
        if category then
            for i, item in ipairs(category.items) do
                local price = item.price * (sender == BUY_CATEGORY and BUY_PERCENTAGE or SELL_PERCENTAGE) * getPriceMultiplier()
                if sender == BUY_CATEGORY or (sender == SELL_CATEGORY and player:HasItem(item.id)) then
                    player:GossipMenuAddItem(1, item.name .. "\n       |cff006400Price:|r " .. convertMoney(price), sender == BUY_CATEGORY and BUY_QUANTITY or SELL_QUANTITY, intid * 100 + i, true, "How many do you want to " .. (sender == BUY_CATEGORY and "buy" or "sell") .. "? \nPrice per unit " .. convertMoney(price))
                end
            end
            player:GossipMenuAddItem(7, "|cff8b0000Back|r", BUY_SELL, sender == BUY_CATEGORY and 0 or 1)
        end
        player:GossipSendMenu(1, object)
    elseif sender == BUY_QUANTITY or sender == SELL_QUANTITY then
        local quantity = tonumber(code)
        local item = intidToEntity[intid]
        if quantity and item then
            local unitPrice = item.price * (sender == BUY_QUANTITY and BUY_PERCENTAGE or SELL_PERCENTAGE) * getPriceMultiplier()
            local totalPrice = unitPrice * quantity
            if sender == BUY_QUANTITY then 
                if player:GetCoinage() < totalPrice then
                    player:SendBroadcastMessage("You do not have enough money.")
                    ShowMainMenu(player, object)
                    return
                end
                player:ModifyMoney(-totalPrice)
                local maxStackSize = 20
                local numFullStacks = math.floor(quantity / maxStackSize)
                local remainder = quantity % maxStackSize
                for i = 1, numFullStacks do
                    SendMail("Your purchased item", "Here is a stack of items you purchased.", player:GetGUIDLow(), player:GetGUIDLow(), 62, 0, 0, 0, item.id, maxStackSize)
                end
                if remainder > 0 then
                    SendMail("Your purchased item", "Here is the remaining items you purchased.", player:GetGUIDLow(), player:GetGUIDLow(), 62, 0, 0, 0, item.id, remainder)
                end
                player:SendBroadcastMessage("You bought |cffffffff" .. quantity .. "x|r " .. GetItemString(item) .. " for |cffffffff" .. convertMoney(totalPrice) .. "|r. The items were sent to your mailbox.")
            else
                if not player:HasItem(item.id, quantity) then
                    player:SendBroadcastMessage("You do not have enough items.")
                    ShowMainMenu(player, object)
                    return
                end
                player:RemoveItem(item.id, quantity) 
                player:ModifyMoney(totalPrice) 
                player:SendBroadcastMessage("You sold |cffffffff" .. quantity .. "x|r " .. GetItemString(item) .. " for |cffffffff" .. convertMoney(totalPrice) .. "|r.")
            end
            player:GossipClearMenu()
            ShowMainMenu(player, object)
        else
            ShowMainMenu(player, object)
        end
    else
        ShowMainMenu(player, object)
    end
end



local eventId = CreateLuaEvent(UpdateFluctuation, 3600000, 0)

-- GM Commands for checking multipliers and updating the global fluctuation

local REQUIRED_GM_RANK = 3

local function HandleFluctuationsCommandWotLKTrader(event, player, command)
    if (command:lower() == "vprices") then
        if player:GetGMRank() < REQUIRED_GM_RANK then
            player:SendBroadcastMessage("You do not have permission to use this command.")
            return false
        end
        local dayOfWeek = getDayOfWeek()
        local dayMultiplier = DAY_MULTIPLIER[dayOfWeek]
        local timeMultiplier = getTimeMultiplier()
        local priceMultiplier = getPriceMultiplier()
        local currentTime = os.time()
        local elapsedTimeInMonths = os.difftime(currentTime, ORIGINAL_TIMESTAMP) / (30 * 24 * 60 * 60)
        local inflationMultiplier = 1
        if INFLATION_ENABLED then
            inflationMultiplier = (1 + INFLATION_RATE) ^ elapsedTimeInMonths
            inflationMultiplier = math.min(inflationMultiplier, MAX_INFLATION_MULTIPLIER)
        end
        player:SendBroadcastMessage("Day of the week Multiplier: " .. dayOfWeek .. " (multiplier: " .. dayMultiplier .. ")")
        player:SendBroadcastMessage("Current hour Multiplier: " .. getCurrentHour() .. " (multiplier: " .. timeMultiplier .. ")")
        player:SendBroadcastMessage("Global fluctuation Multiplier: " .. GLOBAL_FLUCTUATION)
        player:SendBroadcastMessage("Inflation Multiplier: " .. inflationMultiplier)
        player:SendBroadcastMessage("Total of Price multiplier: " .. priceMultiplier)
        player:SendBroadcastMessage("Buy percentage: " .. BUY_PERCENTAGE)
        player:SendBroadcastMessage("Sell percentage: " .. SELL_PERCENTAGE)
        player:SendBroadcastMessage("GMs can shuffle the Global Fluctuation with the '.vprices shuffle' command.")
        return false
    end
end

local function HandleShufflePricesCommandWotLKTrader(event, player, command)
    if (command:lower() == "vprices shuffle") then
        if player:GetGMRank() < REQUIRED_GM_RANK then
            player:SendBroadcastMessage("You do not have permission to use this command.")
            return false
        end
        UpdateFluctuation()
        player:SendBroadcastMessage("Prices have been shuffled. New global fluctuation: " .. GLOBAL_FLUCTUATION)
        return false
    end
end

local function HandleBuyPercentageCommandWotLKTrader(event, player, command)
    if command:find("vbp") then
        if player:GetGMRank() < REQUIRED_GM_RANK then
            player:SendBroadcastMessage("You do not have permission to use this command.")
            return false
        end
        local _, _, value = command:find("(%S+)$")
        if value then
            BUY_PERCENTAGE = tonumber(value)
            player:SendBroadcastMessage("Buy multiplier has been set to: " .. BUY_PERCENTAGE)
            player:SendBroadcastMessage("Please note that this change will be reset to script values on server restart.")
            return false
        end
    end
end

local function HandleSellPercentageCommandWotLKTrader(event, player, command)
    if command:find("vsp") then
        if player:GetGMRank() < REQUIRED_GM_RANK then
            player:SendBroadcastMessage("You do not have permission to use this command.")
            return false
        end
        local _, _, value = command:find("(%S+)$")
        if value then
            SELL_PERCENTAGE = tonumber(value)
            player:SendBroadcastMessage("Sell multiplier has been set to: " .. SELL_PERCENTAGE)
            player:SendBroadcastMessage("Please note that this change will be reset to script values on server restart.")
            return false
        end
    end
end

RegisterPlayerEvent(42, HandleBuyPercentageCommandWotLKTrader)
RegisterPlayerEvent(42, HandleSellPercentageCommandWotLKTrader)
RegisterPlayerEvent(42, HandleFluctuationsCommandWotLKTrader)
RegisterPlayerEvent(42, HandleShufflePricesCommandWotLKTrader)
RegisterServerEvent(14, OnServerStartupWotLKFluctuation)

for _, NPCID in ipairs(NPCIDs) do
    RegisterCreatureGossipEvent(NPCID, 1, OnGossipHelloWotLKTrader)
    RegisterCreatureGossipEvent(NPCID, 2, OnGossipSelectWotLKTrader)
end
