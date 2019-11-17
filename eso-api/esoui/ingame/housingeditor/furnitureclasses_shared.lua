ZO_PLACEABLE_HOUSING_DATA_TYPE = 1
ZO_RECALLABLE_HOUSING_DATA_TYPE = 2
ZO_SETTINGS_VISITOR_DATA_TYPE = 3
ZO_SETTINGS_BANLIST_DATA_TYPE = 4
ZO_SETTINGS_GUILD_VISITOR_DATA_TYPE = 5
ZO_SETTINGS_GUILD_BANLIST_DATA_TYPE = 6
ZO_HOUSING_MARKET_PRODUCT_DATA_TYPE = 7

--
--[[ FurnitureDataBase ]]--
--
ZO_FurnitureDataBase = ZO_Object:Subclass()

function ZO_FurnitureDataBase:New(...)
    local furniture = ZO_Object.New(self)
    furniture:Initialize(...)
    return furniture
end

function ZO_FurnitureDataBase:Initialize(...)
    self.passesTextFilter = true
    self.theme = FURNITURE_THEME_TYPE_ALL
end

function ZO_FurnitureDataBase:GetRawName()
    return self.rawName
end

do
    local g_nameCache = {}

    function ZO_FurnitureDataBase:GetFormattedName()
        local cachedName = self.formattedName
        if not cachedName then
            local rawName = self:GetRawName()
            cachedName = g_nameCache[rawName]
            if not cachedName then
                cachedName = zo_strformat(SI_HOUSING_FURNITURE_NAME_FORMAT, rawName)
                g_nameCache[rawName] = cachedName
            end

            self.formattedName = cachedName
        end

        return cachedName
    end
end

function ZO_FurnitureDataBase:GetIcon()
    return self.icon
end

function ZO_FurnitureDataBase:GetCategoryInfo()
    return self.categoryId, self.subcategoryId
end

function ZO_FurnitureDataBase:IsGemmable()
    return false
end

function ZO_FurnitureDataBase:IsStolen()
    return false
end

function ZO_FurnitureDataBase:IsFromCrownStore()
    return false
end

function ZO_FurnitureDataBase:GetQuality()
    return ITEM_QUALITY_NORMAL
end

function ZO_FurnitureDataBase:GetStackCount()
    return 1
end

function ZO_FurnitureDataBase:GetFormattedStackCount()
    return 1
end

function ZO_FurnitureDataBase:GetPassesTextFilter()
    return self.passesTextFilter
end

function ZO_FurnitureDataBase:SetPassesTextFilter(passesFilter)
    self.passesTextFilter = passesFilter
end

function ZO_FurnitureDataBase:IsPreviewable()
    return false
end

function ZO_FurnitureDataBase:IsBeingPreviewed()
    return false
end

function ZO_FurnitureDataBase:PassesTheme(theme)
    return theme == FURNITURE_THEME_TYPE_ALL or self.theme == theme
end

function ZO_FurnitureDataBase:GetRawNameFromCollectibleData(collectibleData)
    local categoryType = collectibleData:GetCategoryType()
    --Only house banks include the nickname
    if categoryType == COLLECTIBLE_CATEGORY_TYPE_HOUSE_BANK then
        return collectibleData:GetRawNameWithNickname()
    else
        return collectibleData:GetName()
    end
end

function ZO_FurnitureDataBase:RefreshInfo(...)
    assert(false)  --must be overridden
end

function ZO_FurnitureDataBase:Preview()
    assert(false)  --must be overridden
end

function ZO_FurnitureDataBase:SelectForPlacement()
    assert(false) --must be overridden
end

function ZO_FurnitureDataBase:GetDataType()
    assert(false)  --must be overridden
end

--
--[[ PlaceableFurnitureItem ]]--
--
ZO_PlaceableFurnitureItem = ZO_FurnitureDataBase:Subclass()

function ZO_PlaceableFurnitureItem:New(...)
    return ZO_FurnitureDataBase.New(self, ...)
end

function ZO_PlaceableFurnitureItem:Initialize(bagId, slotIndex)
    ZO_FurnitureDataBase.Initialize(self)
    self:RefreshInfo(bagId, slotIndex)
end

function ZO_PlaceableFurnitureItem:RefreshInfo(bagId, slotIndex)
    self.bagId = bagId
    self.slotIndex = slotIndex

    self.furnitureDataId = GetItemFurnitureDataId(bagId, slotIndex)
    local categoryId, subcategoryId, furnitureTheme = GetFurnitureDataInfo(self.furnitureDataId)
    self.categoryId = categoryId
    self.subcategoryId = subcategoryId
    self.theme = furnitureTheme

    self.slotData = SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotIndex)

    local stackCount = self:GetStackCount()
    local USE_LOWERCASE_NUMBER_SUFFIXES = false
    self.formattedStackCount = zo_strformat(SI_NUMBER_FORMAT, ZO_AbbreviateNumber(stackCount, NUMBER_ABBREVIATION_PRECISION_TENTHS, USE_LOWERCASE_NUMBER_SUFFIXES))
end

function ZO_PlaceableFurnitureItem:Preview()
    SYSTEMS:GetObject("itemPreview"):PreviewInventoryItemAsFurniture(self.bagId, self.slotIndex)
end

function ZO_PlaceableFurnitureItem:SelectForPlacement()
    HousingEditorCreateItemFurnitureForPlacement(self.bagId, self.slotIndex)
end

function ZO_PlaceableFurnitureItem:GetRawName()
    if self.slotData then
        return self.slotData.rawName
    end
    return ""
end

function ZO_PlaceableFurnitureItem:GetFormattedName()
    if self.slotData then
        return self.slotData.name
    end
    return ""
end

function ZO_PlaceableFurnitureItem:GetIcon()
    if self.slotData then
        return self.slotData.iconFile
    end
    return nil
end

function ZO_PlaceableFurnitureItem:GetDataType()
    return ZO_PLACEABLE_HOUSING_DATA_TYPE
end

function ZO_PlaceableFurnitureItem:IsGemmable()
    if self.slotData then
        return self.slotData.isGemmable
    end
    return false
end

function ZO_PlaceableFurnitureItem:IsStolen()
    if self.slotData then
        return self.slotData.stolen
    end
    return false
end

function ZO_PlaceableFurnitureItem:IsFromCrownStore()
    if self.slotData then
        return self.slotData.isFromCrownStore
    end
    return false
end

function ZO_PlaceableFurnitureItem:IsPreviewable()
    return true
end

function ZO_PlaceableFurnitureItem:IsBeingPreviewed()
    return IsCurrentlyPreviewingInventoryItemAsFurniture(self.bagId, self.slotIndex)
end

function ZO_PlaceableFurnitureItem:GetQuality()
    if self.slotData then
        return self.slotData.quality
    end
    return ZO_FurnitureDataBase.GetQuality(self)
end

function ZO_PlaceableFurnitureItem:GetStackCount()
    if self.slotData then
        return self.slotData.stackCount
    end
    return 1
end

function ZO_PlaceableFurnitureItem:GetFormattedStackCount()
    return self.formattedStackCount
end

--
--[[ PlaceableFurnitureCollectible ]]--
--
ZO_PlaceableFurnitureCollectible = ZO_FurnitureDataBase:Subclass()

function ZO_PlaceableFurnitureCollectible:New(...)
    return ZO_FurnitureDataBase.New(self, ...)
end

function ZO_PlaceableFurnitureCollectible:Initialize(collectibleId)
    ZO_FurnitureDataBase.Initialize(self)
    self:RefreshInfo(collectibleId)
end

function ZO_PlaceableFurnitureCollectible:RefreshInfo(collectibleId)
    self.collectibleId = collectibleId

    local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(collectibleId)
    if collectibleData and collectibleData:IsPlaceableFurniture() then
        self.rawName = self:GetRawNameFromCollectibleData(collectibleData)
        self.formattedName = nil
        self.icon = collectibleData:GetIcon()

        self.furnitureDataId = GetCollectibleFurnitureDataId(collectibleId)
        local categoryId, subcategoryId, furnitureTheme = GetFurnitureDataInfo(self.furnitureDataId)
        self.categoryId = categoryId
        self.subcategoryId = subcategoryId
        self.theme = furnitureTheme
    end
end

function ZO_PlaceableFurnitureCollectible:IsPreviewable()
    return true
end

function ZO_PlaceableFurnitureCollectible:IsBeingPreviewed()
    return IsCurrentlyPreviewingCollectibleAsFurniture(self.collectibleId)
end

function ZO_PlaceableFurnitureCollectible:Preview()
    SYSTEMS:GetObject("itemPreview"):PreviewCollectibleAsFurniture(self.collectibleId)
end

function ZO_PlaceableFurnitureCollectible:SelectForPlacement()
    HousingEditorCreateCollectibleFurnitureForPlacement(self.collectibleId)
end

function ZO_PlaceableFurnitureCollectible:GetDataType()
    return ZO_PLACEABLE_HOUSING_DATA_TYPE
end

--
--[[ RetrievableFurniture ]]--
--
ZO_RetrievableFurniture = ZO_FurnitureDataBase:Subclass()

function ZO_RetrievableFurniture:New(...)
    return ZO_FurnitureDataBase.New(self, ...)
end

function ZO_RetrievableFurniture:Initialize(...)
    ZO_FurnitureDataBase.Initialize(self)
    self:RefreshInfo(...)
end

function ZO_RetrievableFurniture:RefreshInfo(retrievableFurnitureId)
    local rawName, icon, furnitureDataId = GetPlacedHousingFurnitureInfo(retrievableFurnitureId)

    --Only update these on id change. 
    if retrievableFurnitureId ~= self.retrievableFurnitureId then
        self.retrievableFurnitureId = retrievableFurnitureId
        self.icon = icon
        self.furnitureDataId = furnitureDataId
        self.quality = GetPlacedHousingFurnitureQuality(retrievableFurnitureId)
    
        local categoryId, subcategoryId, furnitureTheme = GetFurnitureDataInfo(furnitureDataId)
        self.categoryId = categoryId
        self.subcategoryId = subcategoryId
        self.theme = furnitureTheme

        local playerWorldX, playerWorldY, playerWorldZ = GetPlayerWorldPositionInHouse()
        self:RefreshPositionalData(playerWorldX, playerWorldY, playerWorldZ, GetPlayerCameraHeading())
    end

    --Refresh the name which depends on the collectible nickname.
    self.collectibleId = nil
    local itemLink, collectibleLink = GetPlacedFurnitureLink(retrievableFurnitureId)
    if collectibleLink ~= "" then
        local collectibleId = GetCollectibleIdFromLink(collectibleLink)
        if collectibleId then
            self.collectibleId = collectibleId
            local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(collectibleId)
            if collectibleData then
                rawName = self:GetRawNameFromCollectibleData(collectibleData)
            end
        end
    end
    self.rawName = rawName
    self.formattedName = nil
end

function ZO_RetrievableFurniture:GetFurnitureId()
    return self.retrievableFurnitureId
end

function ZO_RetrievableFurniture:GetCollectibleId()
    return self.collectibleId
end

function ZO_RetrievableFurniture:GetRetrievableFurnitureId()
    return self.retrievableFurnitureId
end

function ZO_RetrievableFurniture:GetDataType()
    return ZO_RECALLABLE_HOUSING_DATA_TYPE
end

function ZO_RetrievableFurniture:GetQuality()
    return self.quality
end

function ZO_RetrievableFurniture:IsPreviewable()
    return true
end

function ZO_RetrievableFurniture:IsBeingPreviewed()
    return IsCurrentlyPreviewingPlacedFurniture(self.retrievableFurnitureId)
end

function ZO_RetrievableFurniture:Preview()
    SYSTEMS:GetObject("itemPreview"):PreviewPlacedFurniture(self.retrievableFurnitureId)
end

function ZO_RetrievableFurniture:RefreshPositionalData(playerWorldX, playerWorldY, playerWorldZ, playerCameraHeadingRadians)
    local worldX, worldY, worldZ = HousingEditorGetFurnitureWorldPosition(self.retrievableFurnitureId)
    self.distanceFromPlayerCM = zo_floor(zo_distance3D(worldX, worldY, worldZ, playerWorldX, playerWorldY, playerWorldZ))
    self.distanceFromPlayerM = zo_floor(self.distanceFromPlayerCM / 100)

    local vectorToFurnitureX = worldX - playerWorldX
    local vectorToFurnitureZ = worldZ - playerWorldZ
    local angleRadians = math.atan2(vectorToFurnitureX, vectorToFurnitureZ)
    self.angleFromPlayerHeadingRadians = zo_mod(angleRadians - playerCameraHeadingRadians, math.pi * 2)
end

function ZO_RetrievableFurniture:GetDistanceFromPlayerM()
    return self.distanceFromPlayerM
end

function ZO_RetrievableFurniture:GetDistanceFromPlayerCM()
    return self.distanceFromPlayerCM
end

function ZO_RetrievableFurniture:GetAngleFromPlayerHeadingRadians()
    return self.angleFromPlayerHeadingRadians
end

function ZO_RetrievableFurniture:CompareTo(other)
    local distanceToSelf = self:GetDistanceFromPlayerCM()
    local distanceToOther = other:GetDistanceFromPlayerCM()

    if distanceToSelf ~= distanceToOther then
        return distanceToSelf < distanceToOther
    end

    return self:GetRawName() < other:GetRawName()
end

--
--[[ HousingMarketProduct ]]--
--
ZO_HousingMarketProduct = ZO_FurnitureDataBase:Subclass()

function ZO_HousingMarketProduct:New(...)
    return ZO_FurnitureDataBase.New(self, ...)
end

function ZO_HousingMarketProduct:Initialize(marketProductId, presentationIndex)
    ZO_FurnitureDataBase.Initialize(self)
    self.marketProductId = marketProductId
    self.presentationIndex = presentationIndex
end

function ZO_HousingMarketProduct:RefreshInfo(marketProductId, presentationIndex)
    self.marketProductId = marketProductId
    self.presentationIndex = presentationIndex

    self.displayState = ZO_GetMarketProductDisplayState(marketProductId)

    self.rawName = GetMarketProductDisplayName(marketProductId)
    self.formattedName = nil

    self.icon = GetMarketProductIcon(marketProductId)

    local currencyType, cost, costAfterDiscount, discountPercent, esoPlusCost = self:GetMarketProductPricingByPresentation()
    self.isFree = costAfterDiscount == 0
    self.onSale = discountPercent > 0
    self.isNew = IsMarketProductNew(marketProductId)
    self.currencyType = currencyType
    self.cost = cost
    self.costAfterDiscount = costAfterDiscount
    self.discountPercent = discountPercent
    self.quality = GetMarketProductQuality(marketProductId)

    self.furnitureDataId = GetMarketProductFurnitureDataId(marketProductId)
    local categoryId, subcategoryId, furnitureTheme = GetFurnitureDataInfo(self.furnitureDataId)
    self.categoryId = categoryId
    self.subcategoryId = subcategoryId
    self.theme = furnitureTheme
end

function ZO_HousingMarketProduct:GetMarketProductId()
    return self.marketProductId
end

function ZO_HousingMarketProduct:Preview()
    SYSTEMS:GetObject("itemPreview"):PreviewFurnitureMarketProduct(self.marketProductId)
end

function ZO_HousingMarketProduct:Reset()
    self.marketProductId = nil
    self.presentationIndex = nil
end

function ZO_HousingMarketProduct:GetDataType()
    return ZO_HOUSING_MARKET_PRODUCT_DATA_TYPE
end

function ZO_HousingMarketProduct:IsFromCrownStore()
    return true
end

function ZO_HousingMarketProduct:IsPreviewable()
    return CanPreviewMarketProduct(self.marketProductId)
end

function ZO_HousingMarketProduct:IsBeingPreviewed()
    return IsPreviewingMarketProduct(self.marketProductId)
end

function ZO_HousingMarketProduct:GetQuality()
    return self.quality
end

function ZO_HousingMarketProduct:GetMarketProductPricingByPresentation()
    return GetMarketProductPricingByPresentation(self.marketProductId, self.presentationIndex)
end

function ZO_HousingMarketProduct:GetLTOTimeLeftInSeconds()
    return GetMarketProductLTOTimeLeftInSeconds(self.marketProductId)
end

function ZO_HousingMarketProduct:IsLimitedTimeProduct()
    local remainingTime = self:GetLTOTimeLeftInSeconds()
    return remainingTime > 0 and remainingTime <= ZO_ONE_MONTH_IN_SECONDS
end

function ZO_HousingMarketProduct:SetTimeLeftOnLabel(label)
    local remainingTime = self:GetLTOTimeLeftInSeconds()
    if remainingTime > 0 then
        if remainingTime >= ZO_ONE_DAY_IN_SECONDS then
            label:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
            label:SetText(zo_strformat(SI_TIME_DURATION_LEFT, ZO_FormatTime(remainingTime, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT_DESCRIPTIVE, TIME_FORMAT_PRECISION_SECONDS)))
        else
            label:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
            label:SetText(zo_strformat(SI_TIME_DURATION_LEFT, ZO_FormatTimeLargestTwo(remainingTime, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL)))
        end
    end
end

local TEXT_CALLOUT_BACKGROUND_ALPHA = 0.9
function ZO_HousingMarketProduct.SetCalloutBackgroundColor(leftBackground, rightBackground, centerBackground, backgroundColor)
    local r, g, b = backgroundColor:UnpackRGB()

    leftBackground:SetColor(r, g, b, TEXT_CALLOUT_BACKGROUND_ALPHA)
    rightBackground:SetColor(r, g, b, TEXT_CALLOUT_BACKGROUND_ALPHA)
    centerBackground:SetColor(r, g, b, TEXT_CALLOUT_BACKGROUND_ALPHA)
end

function ZO_HousingMarketProduct:CanBePurchased()
    return self.displayState == MARKET_PRODUCT_DISPLAY_STATE_NOT_PURCHASED
end

--
--[[ FurnitureCategory ]]--
--
ZO_FurnitureCategory = ZO_Object:Subclass()

function ZO_FurnitureCategory:New(...)
    local furnitureCategory = ZO_Object.New(self)
    furnitureCategory:Initialize(...)
    return furnitureCategory
end

function ZO_FurnitureCategory:Initialize(parent, categoryId)
    internalassert(parent ~= nil or self:IsRoot(), "Non-root categories must have a parent category")
    self.parentCategory = parent
    self.entriesData = {}
    self.subcategories = {}

    if categoryId then
        self.categoryId = categoryId
        if categoryId == ZO_FURNITURE_NEEDS_CATEGORIZATION_FAKE_CATEGORY then
            self.name = GetString(SI_HOUSING_FURNITURE_NEEDS_CATEGORIZATION)
            self.categoryOrder = 0
        else
            local categoryName, _, _, categoryOrder = GetFurnitureCategoryInfo(categoryId)
            self.name = categoryName
            self.categoryOrder = categoryOrder
        end
    end
end

function ZO_FurnitureCategory:GetName()
    return self.name
end

function ZO_FurnitureCategory:GetCategoryId()
    return self.categoryId
end

function ZO_FurnitureCategory:Clear()
    ZO_ClearTable(self.entriesData)
    for _,subcategory in ipairs(self.subcategories) do
        subcategory:Clear()
    end
    ZO_ClearNumericallyIndexedTable(self.subcategories)
end

function ZO_FurnitureCategory:AddEntry(entryData)
    table.insert(self.entriesData, entryData)
end

function ZO_FurnitureCategory:RemoveEntry(entryData)
    for i,entry in ipairs(self.entriesData) do
        if entry == entryData then
            table.remove(self.entriesData, i)
            if #self.entriesData == 0 then
                self.parentCategory:RemoveSubcategory(self.categoryId)
            end
            break
        end
    end
end

function ZO_FurnitureCategory:GetAllEntries()
    return self.entriesData
end

function ZO_FurnitureCategory:GetAllSubcategories()
    return self.subcategories
end

function ZO_FurnitureCategory:AddSubcategory(subcategoryId, subcategoryObject)
    table.insert(self.subcategories, subcategoryObject)
end

function ZO_FurnitureCategory:RemoveSubcategory(subcategoryId)
    local subcategory, index = self:GetSubcategory(subcategoryId)
    if subcategory then
        table.remove(self.subcategories, index)
        -- if nothing is left here, then there is no reason to keep it around, tell the parent to remove this dude
        if #self.subcategories == 0 and #self.entriesData == 0 and self.parentCategory then
            self.parentCategory:RemoveSubcategory(self.categoryId)
        end
    end
end

function ZO_FurnitureCategory:GetSubcategory(subcategoryId)
    local subcategories = self.subcategories
    -- inlined for performance
    for subcategoryIndex = 1, #self.subcategories do
        if subcategories[subcategoryIndex].categoryId == subcategoryId then
            return subcategories[subcategoryIndex], subcategoryIndex
        end
    end
end

function ZO_FurnitureCategory:GetHasSubcategories()
    return #self.subcategories > 0
end

function ZO_FurnitureCategory:IsRoot()
    return false
end

function ZO_FurnitureCategory:GetNumEntryItemsRecursive(filterFunction)
    local totalEntries = 0
    for _, subcategory in ipairs(self.subcategories) do
        totalEntries = totalEntries + subcategory:GetNumEntryItemsRecursive(filterFunction)
    end

    for _, entry in ipairs(self.entriesData) do
        if not filterFunction or filterFunction(entry) then
            totalEntries = totalEntries + entry:GetStackCount()
        end
    end

    return totalEntries
end

do
    local function SortCategories(a, b)
        if a.categoryOrder == b.categoryOrder then
            return a.name < b.name
        end

        return a.categoryOrder < b.categoryOrder
    end

    function ZO_FurnitureCategory:SortCategoriesRecursive()
        table.sort(self.subcategories, SortCategories)

        for i, subcategory in ipairs(self.subcategories) do
            subcategory:SortCategoriesRecursive()
        end
    end
end

--
--[[ RootFurnitureCategory ]]--
--
ZO_RootFurnitureCategory = ZO_FurnitureCategory:Subclass()

function ZO_RootFurnitureCategory:New(...)
    return ZO_FurnitureCategory.New(self, ...)
end

function ZO_RootFurnitureCategory:Initialize(rootCategoryName)
    local NO_PARENT = nil
    local NO_CATEGORY_ID = nil
    ZO_FurnitureCategory.Initialize(self, NO_PARENT, NO_CATEGORY_ID)
    self.rootCategoryName = rootCategoryName
end

function ZO_RootFurnitureCategory:GetRootCategoryName()
    return self.rootCategoryName
end

-- Override
function ZO_RootFurnitureCategory:IsRoot()
    return true
end

function ZO_RootFurnitureCategory:GetOrCreateMostSpecificCategory(categoryId, subcategoryId)
    if categoryId and categoryId > 0 then
        local categoryData = self:GetSubcategory(categoryId)
        if not categoryData then
            self:AddSubcategory(categoryId, ZO_FurnitureCategory:New(self, categoryId))
            categoryData = self:GetSubcategory(categoryId)
        end

        if subcategoryId and subcategoryId > 0 then
            local subcategoryData = categoryData:GetSubcategory(subcategoryId)
            if not subcategoryData then
                categoryData:AddSubcategory(subcategoryId, ZO_FurnitureCategory:New(categoryData, subcategoryId))
                subcategoryData = categoryData:GetSubcategory(subcategoryId)
            end
            return subcategoryData
        else
            return categoryData
        end
    else
        local categoryData = self:GetSubcategory(ZO_FURNITURE_NEEDS_CATEGORIZATION_FAKE_CATEGORY)
        if not categoryData then
            self:AddSubcategory(ZO_FURNITURE_NEEDS_CATEGORIZATION_FAKE_CATEGORY, ZO_FurnitureCategory:New(self, ZO_FURNITURE_NEEDS_CATEGORIZATION_FAKE_CATEGORY))
            categoryData = self:GetSubcategory(ZO_FURNITURE_NEEDS_CATEGORIZATION_FAKE_CATEGORY)
        end
        return categoryData
    end
end

-- HousingSettingsList Shared Functions --
------------------------------------------

function ZO_HousingSettings_FilterScrollList(list, masterList, rowDataType, filterFunction)
    local scrollData = ZO_ScrollList_GetDataList(list)
    ZO_ClearNumericallyIndexedTable(scrollData)

    for i, data in ipairs(masterList) do
        if not filterFunction or (filterFunction and filterFunction(data)) then
            table.insert(scrollData, ZO_ScrollList_CreateDataEntry(rowDataType, data))
        end
    end
end

function ZO_HousingSettings_BuildMasterList_Visitor(currentHouse, userGroup, numPermissions, masterList, createScrollDataFunction)
    ZO_ClearNumericallyIndexedTable(masterList)

    for i = 1, numPermissions do
        local canAccess = DoesHousingUserGroupHaveAccess(currentHouse, userGroup, i)
        if canAccess then
            local markedForDelete = IsHousingPermissionMarkedForDelete(currentHouse, userGroup, i)
            if not markedForDelete then
                local displayName = ZO_FormatUserFacingDisplayName(GetHousingUserGroupDisplayName(currentHouse, userGroup, i))
                local permissionPresetName = HOUSE_SETTINGS_MANAGER:GetPresetNameFromPermissionData(currentHouse, userGroup, i)
                local nextData = createScrollDataFunction(displayName, currentHouse, userGroup, i, permissionPresetName)
                table.insert(masterList, nextData)
            end
        end
    end
end

function ZO_HousingSettings_BuildMasterList_Ban(currentHouse, userGroup, numPermissions, masterList, createScrollDataFunction)
    ZO_ClearNumericallyIndexedTable(masterList)

    for i = 1, numPermissions do
        local canAccess = DoesHousingUserGroupHaveAccess(currentHouse, userGroup, i)
        if not canAccess then
            local markedForDelete = IsHousingPermissionMarkedForDelete(currentHouse, userGroup, i)
            if not markedForDelete then
                local displayName = ZO_FormatUserFacingDisplayName(GetHousingUserGroupDisplayName(currentHouse, userGroup, i))
                local nextData = createScrollDataFunction(displayName, currentHouse, userGroup, i)
                table.insert(masterList, nextData)
            end
        end
    end
end