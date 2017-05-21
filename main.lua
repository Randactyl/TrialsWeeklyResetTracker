--namespace
TrialsWeeklyResetTracker = {}
local TWRT = TrialsWeeklyResetTracker

--constants
TWRT.WEEK_IN_SECONDS = 604800
TWRT.DAY_IN_SECONDS = 86400
TWRT.HOUR_IN_SECONDS = 3600
TWRT.MINUTE_IN_SECONDS = 60
TWRT.MAX_DIFFERENCE = 5

--runtime data
TWRT.characterId = GetCurrentCharacterId()
TWRT.lastQuestId = nil
TWRT.lastLootId = nil
TWRT.questIds = {
    [5087] = "",
    [5102] = "",
    [5171] = "",
    [5352] = "",
    [5894] = "",
}
TWRT.lootIds = {
    [87703] = "",
    [87708] = "",
    [87702] = "",
    [87707] = "",
    [81187] = "",
    [81188] = "",
    [87705] = "",
    [87706] = "",
    [94089] = "",
    [94090] = "",
}

--saved data
TWRT.data = nil

--control data
local debug = false

local function toggleDebug()
    debug = not debug
    d("Debug set to "..tostring(debug))
end
SLASH_COMMANDS["/twrtdebug"] = toggleDebug

--turn a number representing seconds into a human readable string
--ex: 123456 == 1d 10h 17m 36s
local function secondsToCooldownString(seconds)
    local cooldownString, days, hours, minutes

    --get days, hours, and minutes
    days = zo_floor(seconds / TWRT.DAY_IN_SECONDS)
    seconds = seconds % TWRT.DAY_IN_SECONDS
    hours = zo_floor(seconds / TWRT.HOUR_IN_SECONDS)
    seconds = seconds % TWRT.HOUR_IN_SECONDS
    minutes = zo_floor(seconds / TWRT.MINUTE_IN_SECONDS)
    seconds = seconds % TWRT.MINUTE_IN_SECONDS

    cooldownString = ""

    --only add a part to the string if it is greater than 0
    if days > 0 then cooldownString = cooldownString..days.."d " end
    if hours > 0 then cooldownString = cooldownString..hours.."h " end
    if minutes > 0 then cooldownString = cooldownString..minutes.."m " end
    if seconds > 0 then cooldownString = cooldownString..seconds.."s" end

    return cooldownString
end

--output cooldown info for current character with slash command "/twrt"
--sample output:
--
--Assaulting the Citadel
--  - [Warrior's Dulled Coffer] is available!
--Into the Maw
--  - [Dro-m'Athra's Burnished Coffer] is available!
--  - [Dro-m'Athra's Shining Coffer] is available in 1d 10h 17m 36s.
local function getCooldownInfo()
    --for each quest saved to this character's cooldown data
    for questId, lootTable in pairs(TrialsWeeklyResetTrackerData[TWRT.characterId]) do
        --get and output the quest name
        local questName = GetCompletedQuestInfo(questId)
        d(questName)

        --for each coffer saved to this questId
        for lootId, cooldownEnd in pairs(lootTable) do
            --create itemLink for output and get current timestamp for comparison
            local itemLink = "|H1:item:"..lootId..":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
            local currentTime = GetTimeStamp()

            --output message based on cooldown state
            if cooldownEnd <= currentTime then
                d("  - "..itemLink.." is available!")
            else
                local difference = cooldownEnd - currentTime

                d("  - "..itemLink.." will be available in "..secondsToCooldownString(difference))
            end
        end
    end
end
SLASH_COMMANDS["/twrt"] = getCooldownInfo

local function updateCooldownInfo()
    --questIds and their matching lootIds
    local lookup = {
        --Hel Ra Citadel, "Assaulting the Citadel"
        [5087] = {
            [87703] = "", --Warrior's Dulled Coffer
            [87708] = "", --Warrior's Honed Coffer
        },
        --Atherian Archive, "The Mage's Tower"
        [5102] = {
            [87702] = "", --Mage's Ignorant Coffer
            [87707] = "", --Mage's Knowledgeable Coffer
        },
        --Sanctum Ophidia, "The Oldest Ghost"
        [5171] = {
            [81187] = "", --Serpent's Languid Coffer
            [81188] = "", --Serpent's Coiled Coffer
            [87705] = "", --Serpent's Languid Coffer
            [87706] = "", --Serpent's Coiled Coffer
        },
        --Maw of Lorkaj, "Into the Maw"
        [5352] = {
            [94089] = "", --Dro-m'Athra's Burnished Coffer
            [94090] = "", --Dro-m'Athra's Shining Coffer
        },
        --Halls of Fabrication, "Forging the Future"
        [5894] = {
            [126130] = "", --Fabricant's Burnished Coffer
            [126131] = "", --Fabricant's Shining Coffer
        }
    }

    --only continue if both quest and loot ids are initialized
    if not TWRT.lastQuestId or not TWRT.lastLootId then return end

    --only continue if we have matching information
    if not lookup[TWRT.lastQuestId][TWRT.lastLootId] then return end

    --get timestamps for comparison
    local lootTimestamp = tonumber(TWRT.lootIds[TWRT.lastLootId])
    local questTimestamp = tonumber(TWRT.questIds[TWRT.lastQuestId])

    --make sure they exist
    if not lootTimestamp or not questTimestamp then return end

    --calculate difference
    local difference = zo_abs(lootTimestamp - questTimestamp)

    --update cooldown info if difference is within acceptable margin
    if difference < TWRT.MAX_DIFFERENCE then
        --ensure there is a place to save cooldown
        TrialsWeeklyResetTrackerData[TWRT.characterId][TWRT.lastQuestId] = TrialsWeeklyResetTrackerData[TWRT.characterId][TWRT.lastQuestId] or {}

        --save the current time plus one week for the cooldown
        TrialsWeeklyResetTrackerData[TWRT.characterId][TWRT.lastQuestId][TWRT.lastLootId] = GetTimeStamp() + TWRT.WEEK_IN_SECONDS
    end
end

--triggered when someone in the group loots something
local function lootReceived(eventCode, receivedBy, itemName, quantity, itemSound, lootType, receivedBySelf, isPickpocketLoot, questItemIconPath, itemId)
    --only continue if the event was triggered for the player
    if not receivedBySelf then return end

    --if it is an item we're interested in
    if TWRT.lootIds[itemId] then
        --save timestamp and the itemId
        TWRT.lootIds[itemId] = GetTimeStamp()
        TWRT.lastLootId = itemId
    end

    --update the cooldown info
    updateCooldownInfo()
end
EVENT_MANAGER:RegisterForEvent("TWRT_LOOT_RECEIVED", EVENT_LOOT_RECEIVED, lootReceived)

--triggered on quest complete or abandon
local function questRemoved(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questId)
    --for getting a new trial quest
    if debug then d("questId: "..questId) end

    --only continue if quest is complete
    if not isCompleted then return end

    --if it is a quest we're interested in
    if TWRT.questIds[questId] then
        --save timestamp and the questId
        TWRT.questIds[questId] = GetTimeStamp()
        TWRT.lastQuestId = questId
    end

    --this is probably unnecessary, but in the event the loot is received before the quest is "completed" we'll call here as well
    updateCooldownInfo()
end
EVENT_MANAGER:RegisterForEvent("TWRT_QUEST_REMOVED", EVENT_QUEST_REMOVED, questRemoved)

local function addonLoaded(eventCode, addonName)
    if addonName ~= "TrialsWeeklyResetTracker" then return end

    --setup saved variables
    TrialsWeeklyResetTrackerData = TrialsWeeklyResetTrackerData or {}
    TWRT.data = TrialsWeeklyResetTrackerData
    TWRT.data[TWRT.characterId] = TWRT.data[TWRT.characterId] or {}
end
EVENT_MANAGER:RegisterForEvent("TWRT_ADDON_LOADED", EVENT_ADD_ON_LOADED, addonLoaded)