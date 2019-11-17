--------------------------
-- Zone Stories Manager --
--------------------------

ZO_ZONE_STORY_ACTIVITY_COMPLETION_TYPES_SORTED_LIST = 
{
    ZONE_COMPLETION_TYPE_PRIORITY_QUESTS,
    ZONE_COMPLETION_TYPE_WAYSHRINES,
    ZONE_COMPLETION_TYPE_DELVES,
    ZONE_COMPLETION_TYPE_GROUP_DELVES,
    ZONE_COMPLETION_TYPE_POINTS_OF_INTEREST,
    ZONE_COMPLETION_TYPE_STRIKING_LOCALES,
    ZONE_COMPLETION_TYPE_SET_STATIONS,
    ZONE_COMPLETION_TYPE_MUNDUS_STONES,
    ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS,
    ZONE_COMPLETION_TYPE_WORLD_EVENTS,
    ZONE_COMPLETION_TYPE_GROUP_BOSSES,
    ZONE_COMPLETION_TYPE_SKYSHARDS,
    ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS,
}

ZO_ZoneStories_Manager = ZO_CallbackObject:Subclass()

function ZO_ZoneStories_Manager:New(...)
    local manager = ZO_CallbackObject.New(self)
    manager:Initialize(...)
    return manager
end

function ZO_ZoneStories_Manager:Initialize()
    self.zoneList = {}
    self.zoneMap = {}

    self:BuildZoneList()

    EVENT_MANAGER:RegisterForEvent("ZoneStoriesManager", EVENT_SHOW_ZONE_STORIES_SCENE, function(eventCode, zoneId) self:ShowZoneStoriesScene(zoneId) end)
    EVENT_MANAGER:RegisterForEvent("ZoneStoriesManager", EVENT_QUEST_ADDED, function(eventCode, ...) ZO_ZoneStories_Manager.OnQuestAdded(...) end)
end

function ZO_ZoneStories_Manager.GetDefaultZoneSelection()
    local zoneIndex = GetUnitZoneIndex("player")
    return ZO_ExplorationUtils_GetZoneStoryZoneIdByZoneIndex(zoneIndex)
end

function ZO_ZoneStories_Manager:ShowZoneStoriesScene(zoneId)
    zoneId = zoneId or self.GetDefaultZoneSelection()
    if IsInGamepadPreferredMode() then
        local CREATE_FULL_STACK = true
        SYSTEMS:GetObject("mainMenu"):ShowZoneStoriesEntry(CREATE_FULL_STACK)
        ZONE_STORIES_GAMEPAD:SetSelectedByZoneId(zoneId)
    else
        SYSTEMS:GetObject("mainMenu"):ShowScene("groupMenuKeyboard")
        GROUP_MENU_KEYBOARD:SetCategoryOnShow(ZONE_STORIES_FRAGMENT)
        ZONE_STORIES_KEYBOARD:SetSelectedByZoneId(zoneId)
    end
end

function ZO_ZoneStories_Manager.OnQuestAdded(questIndex)
    if IsZoneStoryActivelyTracking() and IsJournalQuestIndexInTrackedZoneStory(questIndex) then
        ClearTrackedZoneStory()
    end
end

function ZO_ZoneStories_Manager.StopZoneStoryTracking()
    if IsZoneStoryActivelyTracking() then
        ClearTrackedZoneStory()
    end
end

do
    local function GetNextZoneStoryZoneIdIter(_, lastZoneId)
        return GetNextZoneStoryZoneId(lastZoneId)
    end

    function ZO_ZoneStories_Manager:BuildZoneList()
        ZO_ClearNumericallyIndexedTable(self.zoneList)
        ZO_ClearTable(self.zoneMap)

        for zoneId in GetNextZoneStoryZoneIdIter do
            local zoneData =
            {
                id = zoneId,
                name = ZO_CachedStrFormat(SI_ZONE_NAME, GetZoneNameById(zoneId)),
                description = GetZoneDescriptionById(zoneId),
            }
            table.insert(self.zoneList, zoneData)
            self.zoneMap[zoneId] = zoneData
        end

        table.sort(self.zoneList, function(left, right)
            return left.name < right.name
        end)
    end
end

function ZO_ZoneStories_Manager:ZoneListIterator()
    return ZO_NumericallyIndexedTableIterator(self.zoneList)
end

function ZO_ZoneStories_Manager:GetZoneData(zoneId)
    return self.zoneMap[zoneId]
end

function ZO_ZoneStories_Manager.GetActivityCompletionProgressValues(zoneId, completionType)
    local numCompletedActivities = 0
    local totalActivities = 0
    local numUnblockedActivities = 0
    local blockingBranchErrorStringId = 0
    if completionType == ZONE_COMPLETION_TYPE_SKYSHARDS then
        local numAchievements = GetNumZoneActivitiesForZoneCompletionType(zoneId, completionType)
        for achievementIndex = 1, numAchievements do
            local achievementId = GetZoneActivityIdForZoneCompletionType(zoneId, completionType, achievementIndex)
            local numCriteria = GetAchievementNumCriteria(achievementId)
            for criterionIndex = 1, numCriteria do
                local _, numCompleted, numRequired = GetAchievementCriterion(achievementId, criterionIndex)
                numCompletedActivities = numCompletedActivities + numCompleted
                totalActivities = totalActivities + numRequired
            end
        end
        numUnblockedActivities = totalActivities
    else
        numCompletedActivities = GetNumCompletedZoneActivitiesForZoneCompletionType(zoneId, completionType)
        totalActivities = GetNumZoneActivitiesForZoneCompletionType(zoneId, completionType)
        numUnblockedActivities, blockingBranchErrorStringId = GetNumUnblockedZoneStoryActivitiesForZoneCompletionType(zoneId, completionType)
    end

    return numCompletedActivities, totalActivities, numUnblockedActivities, blockingBranchErrorStringId
end

function ZO_ZoneStories_Manager.GetActivityCompletionProgressValuesAndText(zoneId, completionType)
    local numCompletedActivities, totalActivities, numUnblockedActivities, blockingBranchErrorStringId = ZO_ZoneStories_Manager.GetActivityCompletionProgressValues(zoneId, completionType)
    local text = nil
    if DoesZoneCompletionTypeInZoneHaveBranchesWithDifferentLengths(zoneId, completionType) then
        text = zo_strformat(SI_ZONE_STORY_ACTIVITY_COMPLETION_VALUES_TOTAL_PLUS, numCompletedActivities, totalActivities)
    else
        text = zo_strformat(SI_ZONE_STORY_ACTIVITY_COMPLETION_VALUES, numCompletedActivities, totalActivities)
    end
    return numCompletedActivities, totalActivities, numUnblockedActivities, blockingBranchErrorStringId, text
end

function ZO_ZoneStories_Manager.GetActivityCompletionProgressText(zoneId, completionType)
    return select(5, ZO_ZoneStories_Manager.GetActivityCompletionProgressValuesAndText(zoneId, completionType))
end

function ZO_ZoneStories_Manager.IsZoneComplete(zoneId)
    return IsZoneStoryComplete(zoneId)
end

function ZO_ZoneStories_Manager.IsZoneCompletionTypeComplete(zoneId, completionType)
    return AreAllZoneStoryActivitiesCompleteForZoneCompletionType(zoneId, completionType)
end

function ZO_ZoneStories_Manager.GetZoneAvailability(zoneId)
    local isZoneAvailable, errorString = IsZoneStoryZoneAvailable(zoneId)
    return isZoneAvailable, errorString
end

function ZO_ZoneStories_Manager.GetZoneCompletionTypeBlockingInfo(zoneId, completionType)
    local blockingErrorStringText = nil

    local isCompletionTypeBlocked = not ZO_ZoneStories_Manager.IsZoneCompletionTypeComplete(zoneId, completionType)
                                    and not CanZoneStoryContinueTrackingActivitiesForCompletionType(zoneId, completionType)
    if isCompletionTypeBlocked then
        local numUnblockedActivities, blockingBranchErrorStringId = GetNumUnblockedZoneStoryActivitiesForZoneCompletionType(zoneId, completionType)
        if blockingBranchErrorStringId ~= 0 then
            blockingErrorStringText = GetErrorString(blockingBranchErrorStringId)
        end
    end

    return isCompletionTypeBlocked, blockingErrorStringText
end

do
    local ZONE_COMPLETION_TYPE_ICON_MAP =
    {
        [ZONE_COMPLETION_TYPE_PRIORITY_QUESTS] = "EsoUI/Art/ZoneStories/completionTypeIcon_priorityQuest.dds",
        [ZONE_COMPLETION_TYPE_POINTS_OF_INTEREST] = "EsoUI/Art/ZoneStories/completionTypeIcon_pointOfInterest.dds",
        [ZONE_COMPLETION_TYPE_WAYSHRINES] = "EsoUI/Art/ZoneStories/completionTypeIcon_wayshrine.dds",
        [ZONE_COMPLETION_TYPE_DELVES] = "EsoUI/Art/ZoneStories/completionTypeIcon_delve.dds",
        [ZONE_COMPLETION_TYPE_GROUP_DELVES] = "EsoUI/Art/ZoneStories/completionTypeIcon_groupDelve.dds",
        [ZONE_COMPLETION_TYPE_SKYSHARDS] = "EsoUI/Art/ZoneStories/completionTypeIcon_skyshard.dds",
        [ZONE_COMPLETION_TYPE_WORLD_EVENTS] = "EsoUI/Art/ZoneStories/completionTypeIcon_worldEvents.dds",
        [ZONE_COMPLETION_TYPE_GROUP_BOSSES] = "EsoUI/Art/ZoneStories/completionTypeIcon_groupBoss.dds",
        [ZONE_COMPLETION_TYPE_STRIKING_LOCALES] = "EsoUI/Art/ZoneStories/completionTypeIcon_strikingLocales.dds",
        [ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS] = "EsoUI/Art/ZoneStories/completionTypeIcon_lorebooks.dds",
        [ZONE_COMPLETION_TYPE_MUNDUS_STONES] = "EsoUI/Art/ZoneStories/completionTypeIcon_mundusStone.dds",
        [ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS] = "EsoUI/Art/ZoneStories/completionTypeIcon_publicDungeon.dds",
        [ZONE_COMPLETION_TYPE_SET_STATIONS] = "EsoUI/Art/ZoneStories/completionTypeIcon_setStation.dds",
    }

    function ZO_ZoneStories_Manager.GetCompletionTypeIcon(zoneCompletionType)
        return ZONE_COMPLETION_TYPE_ICON_MAP[zoneCompletionType]
    end
end

ZONE_STORIES_MANAGER = ZO_ZoneStories_Manager:New()