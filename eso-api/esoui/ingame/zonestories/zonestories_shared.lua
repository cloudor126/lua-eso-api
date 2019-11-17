ZO_ZoneStories_Shared = ZO_Object:Subclass()

function ZO_ZoneStories_Shared:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function ZO_ZoneStories_Shared:Initialize(control, infoContainerControl)
    self.control = control
    self.infoContainerControl = infoContainerControl
    self.titleControl = infoContainerControl:GetNamedChild("Title")
    self.descriptionControl = infoContainerControl:GetNamedChild("Description")
    self.backgroundTexture = infoContainerControl:GetNamedChild("Background")

    self:InitializeZonesList()
    self:InitializeGridList()

    control:RegisterForEvent(EVENT_PLAYER_ACTIVATED, function() self:OnPlayerActivated() end)
end

function ZO_ZoneStories_Shared:InitializeGridList()
    -- Create Data Object Pool
    local function CreateEntryData()
        return ZO_GridSquareEntryData_Shared:New()
    end

    local function ResetEntryData(data)
        data:SetDataSource(nil)
    end

    self.entryDataObjectPool = ZO_ObjectPool:New(CreateEntryData, ResetEntryData)

    -- Initialize grid list object
    local gridListControl = self.infoContainerControl:GetNamedChild("GridList")
    self.gridListControl = gridListControl
    self.gridList = self.templateData.gridListClass:New(gridListControl)

    local HIDE_CALLBACK = nil
    local achievementData = self.templateData.achievements
    local activityCompletionData = self.templateData.activityCompletion
    self.gridList:AddEntryTemplate(achievementData.entryTemplate, achievementData.dimensionsX, achievementData.dimensionsY, ZO_DefaultGridTileEntrySetup, HIDE_CALLBACK, ZO_DefaultGridTileEntryReset, achievementData.gridPaddingX, achievementData.gridPaddingY)
    self.gridList:AddEntryTemplate(activityCompletionData.entryTemplate, activityCompletionData.dimensionsX, activityCompletionData.dimensionsY, ZO_DefaultGridTileEntrySetup, HIDE_CALLBACK, ZO_DefaultGridTileEntryReset, activityCompletionData.gridPaddingX, activityCompletionData.gridPaddingY)
    self.gridList:AddHeaderTemplate(activityCompletionData.headerTemplate, activityCompletionData.headerHeight, ZO_DefaultGridTileHeaderSetup)
    self.gridList:SetHeaderPrePadding(self.templateData.headerPrePadding)

    self:BuildGridList()
end

function ZO_ZoneStories_Shared:OnPlayerActivated()
    self:BuildZonesList()
end

function ZO_ZoneStories_Shared:BuildZonesList()
    -- To be overridden
end

function ZO_ZoneStories_Shared:GetSelectedZoneId()
    -- To be overridden
end

function ZO_ZoneStories_Shared:GetSelectedStoryData()
    -- To be overridden
end

function ZO_ZoneStories_Shared:UpdatePlayStoryButtonText()
    -- To be overridden
end

function ZO_ZoneStories_Shared:UpdateBackgroundTexture()
    -- To be overridden
end

function ZO_ZoneStories_Shared:GetPlayStoryButtonText()
    local selectedData = self:GetSelectedStoryData()
    if selectedData then
        if not ZO_ZoneStories_Shared.IsZoneCollectibleUnlocked(selectedData.id) then
            return ZO_ZoneStories_Shared.GetZoneCollectibleUnlockText(selectedData.id)
        elseif ZO_ZoneStories_Manager.IsZoneComplete(selectedData.id) then
            return zo_strformat(SI_ZONE_STORY_ZONE_COMPLETE_ACTION)
        elseif ZO_ZoneStories_Manager.IsZoneCompletionTypeComplete(selectedData.id, ZONE_COMPLETION_TYPE_PRIORITY_QUESTS)
                or not CanZoneStoryContinueTrackingActivitiesForCompletionType(selectedData.id, ZONE_COMPLETION_TYPE_PRIORITY_QUESTS) then
            return zo_strformat(SI_ZONE_STORY_EXPLORE_ZONE_ACTION)
        elseif not IsZoneStoryStarted(selectedData.id) then
            return zo_strformat(SI_ZONE_STORY_START_STORY_ACTION)
        else
            return zo_strformat(SI_ZONE_STORY_CONTINUE_STORY_ACTION)
        end
    end
    return ""
end

function ZO_ZoneStories_Shared.IsZoneCollectibleUnlocked(zoneId)
    local zoneIndex = GetZoneIndex(zoneId)
    local zoneCollectibleId = GetCollectibleIdForZone(zoneIndex)
    return zoneCollectibleId == 0 or IsCollectibleUnlocked(zoneCollectibleId)
end

function ZO_ZoneStories_Shared.GetZoneCollectibleUnlockText(zoneId)
    local zoneIndex = GetZoneIndex(zoneId)
    local zoneCollectibleId = GetCollectibleIdForZone(zoneIndex)
    if zoneCollectibleId ~= 0 then
        local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(zoneCollectibleId)
        local categoryType = collectibleData:GetCategoryType()
        if categoryType == COLLECTIBLE_CATEGORY_TYPE_CHAPTER then
            return zo_strformat(SI_ZONE_STORY_UPGRADE_ACTION)
        elseif categoryType == COLLECTIBLE_CATEGORY_TYPE_DLC then
            return zo_strformat(SI_ZONE_STORY_UNLOCK_ACTION)
        end
    end
    return ""
end

function ZO_ZoneStories_Shared:BuildGridList()
    if self.gridList then
        self.gridList:ClearGridList()
        self.entryDataObjectPool:ReleaseAllObjects()

        self:BuildAchievementList()
        self:BuildActivityCompletionList()

        self.gridList:CommitGridList()
    end
end

function ZO_ZoneStories_Shared:BuildAchievementList()
    if self.gridList then
        local zoneId = self:GetSelectedZoneId()
        local numAchievements = GetNumUnblockedZoneStoryActivitiesForZoneCompletionType(zoneId, ZONE_COMPLETION_TYPE_FEATURED_ACHIEVEMENTS)
        for i = 1, numAchievements do
            local entryData = self.entryDataObjectPool:AcquireObject()
            local achievementId = GetZoneActivityIdForZoneCompletionType(zoneId, ZONE_COMPLETION_TYPE_FEATURED_ACHIEVEMENTS, i)
            entryData:SetDataSource({ achievementId = achievementId, completionType = ZONE_COMPLETION_TYPE_FEATURED_ACHIEVEMENTS })
            entryData.gridHeaderName = ""
            self.gridList:AddEntry(entryData, self.templateData.achievements.entryTemplate)
        end
    end
end

function ZO_ZoneStories_Shared:BuildActivityCompletionList()
    if self.gridList then
        local zoneData = self:GetSelectedStoryData()
        if zoneData then
            for _, completionType in ipairs(ZO_ZONE_STORY_ACTIVITY_COMPLETION_TYPES_SORTED_LIST) do
                if GetNumZoneActivitiesForZoneCompletionType(zoneData.id, completionType) > 0 then
                    local entryData = self.entryDataObjectPool:AcquireObject()
                    local data = { zoneData = zoneData, completionType = completionType }
                    entryData:SetDataSource(data)
                    entryData.gridHeaderName = GetString(SI_ZONE_STORY_ACTIVITY_COMPLETION_HEADER)
                    entryData.gridHeaderTemplate = self.templateData.activityCompletion.headerTemplate
                    self.gridList:AddEntry(entryData, self.templateData.activityCompletion.entryTemplate)
                end
            end
        end
    end
end

function ZO_ZoneStories_Shared:UpdateZoneStory()
    local data = self:GetSelectedStoryData()

    local zoneData = ZONE_STORIES_MANAGER:GetZoneData(data.id)
    self.titleControl:SetText(zoneData.name)
    self.descriptionControl:SetText(zoneData.description)

    self:BuildGridList()
    self:UpdatePlayStoryButtonText()
    self:UpdateBackgroundTexture()
end

function ZO_ZoneStories_Shared:TrackNextActivity()
    local zoneId = self:GetSelectedZoneId()
    if zoneId then
        if ZO_ZoneStories_Shared.IsZoneCollectibleUnlocked(zoneId) then
            local SET_AUTO_MAP_NAVIGATION_TARGET = true
            local COMPLETION_TYPE_ALL = nil
            TrackNextActivityForZoneStory(zoneId, COMPLETION_TYPE_ALL, SET_AUTO_MAP_NAVIGATION_TARGET)
        else
            local zoneIndex = GetZoneIndex(zoneId)
            local zoneCollectibleId = GetCollectibleIdForZone(zoneIndex)
            local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(zoneCollectibleId)
            local categoryType = collectibleData:GetCategoryType()
            if categoryType == COLLECTIBLE_CATEGORY_TYPE_CHAPTER then
                ZO_ShowChapterUpgradePlatformScreen(MARKET_OPEN_OPERATION_ZONE_STORIES)
            else
                local searchTerm = zo_strformat(SI_CROWN_STORE_SEARCH_FORMAT_STRING, collectibleData:GetName())
                ShowMarketAndSearch(searchTerm, MARKET_OPEN_OPERATION_ZONE_STORIES)
            end
        end
    end
end