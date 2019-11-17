-- Globals
ZO_MODE_STORE_BUY              = 1
ZO_MODE_STORE_BUY_BACK         = 2
ZO_MODE_STORE_SELL             = 3
ZO_MODE_STORE_REPAIR           = 4
ZO_MODE_STORE_SELL_STOLEN      = 5
ZO_MODE_STORE_LAUNDER          = 6
ZO_MODE_STORE_STABLE           = 7

ZO_STORE_WINDOW_MODE_NORMAL = 1
ZO_STORE_WINDOW_MODE_STABLE = 2

STORE_INTERACTION =
{
    type = "Store",
    interactTypes = { INTERACTION_VENDOR, INTERACTION_STABLE },
}

-- Shared object
ZO_SharedStoreManager = ZO_Object:Subclass()

function ZO_SharedStoreManager:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function ZO_SharedStoreManager:Initialize(control)
    self.control = control
end

function ZO_SharedStoreManager:InitializeStore()
    self.storeUsedCurrencies = { GetStoreUsedCurrencyTypes() }
end

-- Shared global functions
function ZO_StoreManager_GetRequiredToBuyErrorText(buyStoreFailure, buyErrorStringId)
    if buyErrorStringId ~= 0 then
        local errorString = GetErrorString(buyErrorStringId)
        if errorString ~= "" then
            return errorString
        end
    end
    return GetString("SI_STOREFAILURE", buyStoreFailure)
end

function ZO_StoreManager_GetStoreItems()
    local items = {}
    local usedFilterTypes = {}

    for entryIndex = 1, GetNumStoreItems() do
        local icon, name, stack, price, sellPrice, meetsRequirementsToBuy, meetsRequirementsToEquip, quality, questNameColor, currencyType1, currencyQuantity1,
            currencyType2, currencyQuantity2, entryType, buyStoreFailure, buyErrorStringId = GetStoreEntryInfo(entryIndex)
        local requiredToBuyErrorText
        if not meetsRequirementsToBuy then
            requiredToBuyErrorText = ZO_StoreManager_GetRequiredToBuyErrorText(buyStoreFailure, buyErrorStringId)
        end

        if stack > 0 then
            local itemLink = GetStoreItemLink(entryIndex)
            local traitInformation = GetItemTraitInformationFromItemLink(itemLink)
            local sellInformation = GetItemLinkSellInformation(itemLink)
            local itemData =
            {
                entryType = entryType,
                slotIndex = entryIndex,
                icon = icon,
                name = name,
                stack = stack,
                price = price,
                sellPrice = sellPrice,
                meetsRequirementsToBuy = meetsRequirementsToBuy,
                buyStoreFailure = buyStoreFailure,
                requiredToBuyErrorText = requiredToBuyErrorText,
                meetsRequirementsToEquip = meetsRequirementsToEquip,
                quality = quality,
                questNameColor = questNameColor,
                currencyType1 = currencyType1,
                currencyQuantity1 = currencyQuantity1,
                currencyType2 = currencyType2,
                currencyQuantity2 = currencyQuantity2,
                stackBuyPrice = stack * price,
                stackBuyPriceCurrency1 = stack * currencyQuantity1,
                stackBuyPriceCurrency2 = stack * currencyQuantity2,
                filterData = { GetStoreEntryTypeInfo(entryIndex) },
                statValue = GetStoreEntryStatValue(entryIndex),
                isUnique = IsItemLinkUnique(itemLink),
                traitInformation = traitInformation,
                itemTrait = GetItemLinkTraitInfo(itemLink),
                traitInformationSortOrder = ZO_GetItemTraitInformation_SortOrder(traitInformation),
                sellInformation = sellInformation,
                sellInformationSortOrder = ZO_GetItemSellInformationCustomSortOrder(sellInformation),
            }

            if entryType == STORE_ENTRY_TYPE_QUEST_ITEM then
                itemData.questItemId = GetStoreEntryQuestItemId(entryIndex)
            end

            items[#items + 1] = itemData
            for i = 1, #itemData.filterData do
                usedFilterTypes[itemData.filterData[i]] = true
            end
        end
    end

    return items, usedFilterTypes
end

function ZO_StoreManager_GetStoreFilterTypes()
    local usedFilterTypes = {}
    for entryIndex = 1, GetNumStoreItems() do
        local filterData = { GetStoreEntryTypeInfo(entryIndex) }
        for i = 1, #filterData do
            usedFilterTypes[filterData[i]] = true
        end
    end
    return usedFilterTypes
end

local DOES_STORE_MODE_REPRESENT_INVENTORY =
{
    [ZO_MODE_STORE_BUY]              = false,
    [ZO_MODE_STORE_BUY_BACK]         = true,
    [ZO_MODE_STORE_SELL]             = true,
    [ZO_MODE_STORE_REPAIR]           = true,
    [ZO_MODE_STORE_SELL_STOLEN]      = true,
    [ZO_MODE_STORE_LAUNDER]          = true,
    [ZO_MODE_STORE_STABLE]           = false,
}

function ZO_StoreManager_IsInventoryStoreMode(mode)
    return DOES_STORE_MODE_REPRESENT_INVENTORY[mode]
end

internalassert(CURT_MAX_VALUE == 10, "Check if new currency requires unique transaction sound hook")
local CURRENCY_TYPE_TO_SOUND_ID =
{
    [CURT_TELVAR_STONES] = SOUNDS.TELVAR_TRANSACT,
    [CURT_ALLIANCE_POINTS] = SOUNDS.ALLIANCE_POINT_TRANSACT,
    [CURT_WRIT_VOUCHERS] = SOUNDS.WRIT_VOUCHER_TRANSACT,
    [CURT_UNDAUNTED_KEYS] = SOUNDS.UNDAUNTED_KEY_TRANSACT,
}

local function PlayItemAcquisitionSound(eventId, itemSoundCategory, specialCurrencyType1, specialCurrencyType2)
    --As of right now there are no stores that use both special currency types and it doesn't make sense
    --to play two currency transact sounds at once, so we only only keying off type1 for now.
    local soundId = CURRENCY_TYPE_TO_SOUND_ID[specialCurrencyType1]
    if soundId then
        PlaySound(soundId)
    else
        PlaySound(SOUNDS.ITEM_MONEY_CHANGED)
    end
end

function ZO_StoreManager_OnPurchased(eventId, entryName, entryType, entryQuantity, money, specialCurrencyType1, specialCurrencyInfo1, specialCurrencyQuantity1, specialCurrencyType2, specialCurrencyInfo2, specialCurrencyQuantity2, itemSoundCategory)
    PlayItemAcquisitionSound(eventId, itemSoundCategory, specialCurrencyType1, specialCurrencyType2)
end

ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE = 1
ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE = 2

function ZO_StoreManager_DoPreviewAction(action, storeEntryIndex)
    local entryType = select(14, GetStoreEntryInfo(storeEntryIndex))
    local itemPreview = SYSTEMS:GetObject("itemPreview")

    local itemLink
    local collectibleId
    if entryType == STORE_ENTRY_TYPE_ITEM then
        itemLink = GetStoreItemLink(storeEntryIndex)
        local containerCollectibleId = GetItemLinkContainerCollectibleId(itemLink)
        if containerCollectibleId ~= 0 then
            collectibleId = containerCollectibleId
            itemLink = nil
        end 
    elseif entryType == STORE_ENTRY_TYPE_COLLECTIBLE then
        collectibleId = GetStoreCollectibleInfo(storeEntryIndex)
    end

    if itemLink then
        if ZO_ItemPreview_Shared.CanItemLinkBePreviewedAsFurniture(itemLink) then
            if action == ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE then
                return true
            elseif action == ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE then
                itemPreview:PreviewStoreEntryAsFurniture(storeEntryIndex)
            end
        end 
    elseif collectibleId then
        local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(collectibleId)
        if collectibleData  then
            if collectibleData:GetCategoryType() == COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE then
                if action == ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE then
                    return true
                elseif action == ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE then
                    itemPreview:PreviewOutfit(ZO_OUTFIT_MANAGER:GetEquippedOutfitIndex())
                    local NO_DYE = 0
                    local REFRESH_IMMEDIATELY = true
                    local outfitSlot = ZO_OUTFIT_MANAGER:GetPreferredOutfitSlotForStyle(collectibleData)
                    itemPreview:AddOutfitSlotPreviewElement(outfitSlot, collectibleId, ZO_OUTFIT_STYLE_DEFAULT_ITEM_MATERIAL_INDEX, NO_DYE, NO_DYE, NO_DYE, REFRESH_IMMEDIATELY)
                end
            elseif GetCollectibleFurnitureDataId(collectibleId) ~= 0 then
                if action == ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE then
                    return true
                elseif action == ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE then
                    itemPreview:PreviewStoreEntryAsFurniture(storeEntryIndex)
                end
            end
        end
    end

    if action == ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE then
        return false
    end
end
