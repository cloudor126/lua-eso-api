ZO_RewardData = ZO_Object:Subclass()

function ZO_RewardData:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end


function ZO_RewardData:Initialize(rewardId, parentChoice)
    self.rewardId = rewardId
    self.parentChoice = parentChoice
end

function ZO_RewardData:SetQuantity(quantity)
    self.quantity = quantity
end

function ZO_RewardData:SetIcon(icon, gamepadIcon)
    self.icon = icon
    self.gamepadIcon = gamepadIcon
end

function ZO_RewardData:SetFormattedName(formattedName)
    self.formattedName = formattedName
end

function ZO_RewardData:SetFormattedNameWithStack(keyboardName, gamepadName)
    self.formattedNameWithStackKeyboard = keyboardName
    self.formattedNameWithStackGamepad = gamepadName
end

function ZO_RewardData:SetChoiceIndex(choiceIndex)
    self.choiceIndex = choiceIndex
end

function ZO_RewardData:SetItemQuality(itemQuality)
    self.quality = itemQuality
end

function ZO_RewardData:SetCurrencyInfo(currencyType)
    self.currencyType = currencyType
end

function ZO_RewardData:SetEquipSlot(equipSlot)
    self.equipSlot = equipSlot
end

function ZO_RewardData:SetChoices(rewardChoices)
    self.choices = rewardChoices
end

function ZO_RewardData:SetRewardType(rewardType)
    self.rewardType = rewardType
end

function ZO_RewardData:SetValidationFunction(validationFunction)
    self.validationFunction = validationFunction
end

function ZO_RewardData:SetIsSelectedChoice(isSelectedChoice)
    if self:GetParentChoice() then
        self.isSelectedChoice = isSelectedChoice
    end
end

function ZO_RewardData:SetAnnouncementBackground(announcementBackground)
    self.announcementBackground = announcementBackground
end

function ZO_RewardData:GetEquipSlot()
    return self.equipSlot
end

function ZO_RewardData:GetCurrencyType()
    return self.currencyType
end

function ZO_RewardData:GetItemQuality()
    return self.quality or ITEM_QUALITY_NORMAL
end

function ZO_RewardData:GetKeyboardIcon()
    return self.icon
end

function ZO_RewardData:GetGamepadIcon()
    -- if no gamepadIcon is used, icon is used for both
    return self.gamepadIcon or self.icon
end

function ZO_RewardData:GetQuantity()
    return self.quantity or 1
end

function ZO_RewardData:GetRewardId()
    return self.rewardId
end

function ZO_RewardData:GetParentChoice()
    return self.parentChoice
end

function ZO_RewardData:GetFormattedName()
    return self.formattedName
end

function ZO_RewardData:GetFormattedNameWithStack()
    return self.formattedNameWithStackKeyboard
end

function ZO_RewardData:GetFormattedNameWithStackGamepad()
    -- if there is no gamepad name, the keyboard name is used for both
    return self.formattedNameWithStackGamepad or self.formattedNameWithStackKeyboard
end

function ZO_RewardData:GetChoices()
    return self.choices
end

function ZO_RewardData:GetRewardType()
    return self.rewardType
end

function ZO_RewardData:IsValidReward()
    return not self.validationFunction or self.validationFunction() == true
end

function ZO_RewardData:GetAnnouncementBackground()
    return self.announcementBackground
end

---------------------
-- Rewards Manager
---------------------

ZO_RewardsManager = ZO_CallbackObject:Subclass()

function ZO_RewardsManager:New(...)
    local rewards = ZO_CallbackObject.New(self)
    rewards:Initialize(...)
    return rewards
end

function ZO_RewardsManager:Initialize()
    
end

do
    local PARENT_CHOICE = nil
    local VALIDATION_FUNCTION = nil
    local SELECTED_CHOICE_FUNCTION = nil
    function ZO_RewardsManager:GetInfoForDailyLoginReward(rewardId, quantity)
        return self:GetInfoForReward(rewardId, quantity, PARENT_CHOICE, VALIDATION_FUNCTION, SELECTED_CHOICE_FUNCTION)
    end
end

function ZO_RewardsManager:GetAllRewardInfoForRewardList(rewardListId, parentChoice, validationFunction, isSelectedChoiceFunction)
    local rewardListInfo = {}
    local numRewards = GetNumRewardListEntries(rewardListId)

    for rewardIndex = 1, numRewards do
        local rewardId, entryType, quantity = GetRewardListEntryInfo(rewardListId, rewardIndex)
        local rewardData = self:GetInfoForReward(rewardId, quantity, parentChoice, validationFunction, isSelectedChoiceFunction)

        if rewardData then
            rewardData:SetChoiceIndex(rewardIndex)
            table.insert(rewardListInfo, rewardData)
        end
    end
    return rewardListInfo
end

function ZO_RewardsManager:GetInfoForReward(rewardId, quantity, parentChoice, validationFunction, isSelectedChoiceFunction)
    local entryType = GetRewardType(rewardId)
    local rewardData
    if entryType == REWARD_ENTRY_TYPE_ADD_CURRENCY then
        rewardData = self:GetCurrencyEntryInfo(rewardId, quantity, parentChoice)
    elseif entryType == REWARD_ENTRY_TYPE_COLLECTIBLE then
        rewardData = self:GetCollectibleEntryInfo(rewardId, parentChoice)
    elseif entryType == REWARD_ENTRY_TYPE_ITEM then
        rewardData = self:GetItemEntryInfo(rewardId, quantity, parentChoice)
    elseif entryType == REWARD_ENTRY_TYPE_LOOT_CRATE then
        rewardData = self:GetCrownCrateEntryInfo(rewardId, quantity, parentChoice)
    elseif entryType == REWARD_ENTRY_TYPE_CHOICE then
        rewardData = self:GetChoiceEntryInfo(rewardId, parentChoice, validationFunction, isSelectedChoiceFunction)
    elseif entryType == REWARD_ENTRY_TYPE_INSTANT_UNLOCK then
        rewardData = self:GetInstantUnlockEntryInfo(rewardId, parentChoice)
    end

    if rewardData then
        rewardData:SetRewardType(entryType)
        if validationFunction then
            rewardData:SetValidationFunction(function() return validationFunction(rewardId) end)
        end

        if parentChoice then
            rewardData:SetIsSelectedChoice(isSelectedChoiceFunction and isSelectedChoiceFunction(parentChoice.rewardId, rewardData.rewardId))
        end
    end
    return rewardData
end

function ZO_RewardsManager:GetChoiceEntryInfo(rewardId, parentChoice, validationFunction, isSelectedChoiceFunction)
    local choiceListId = GetChoiceRewardListId(rewardId)

    local rewardData = ZO_RewardData:New(rewardId, parentChoice)
    rewardData:SetFormattedName(GetChoiceRewardDisplayName(rewardId))
    rewardData:SetIcon(GetChoiceRewardIcon(rewardId))
    rewardData:SetAnnouncementBackground(GetRewardAnnouncementBackgroundFileIndex(rewardId))

    local choices = self:GetAllRewardInfoForRewardList(choiceListId, rewardData, validationFunction, isSelectedChoiceFunction)
    table.sort(choices, function(...) return self:SortChoiceRewardEntries(...) end)
    rewardData:SetChoices(choices)

    return rewardData
end

function ZO_RewardsManager:GetCurrencyEntryInfo(rewardId, quantity, parentChoice)
    local currencyType = GetAddCurrencyRewardInfo(rewardId)
    local IS_PLURAL = false
    local IS_UPPER = false
    local formattedName = zo_strformat(SI_CURRENCY_NAME_FORMAT, GetCurrencyName(currencyType, IS_PLURAL, IS_UPPER))
    local formattedNameWithStackKeyboard = zo_strformat(SI_NUMBER_FORMAT, ZO_Currency_FormatKeyboard(currencyType, quantity, ZO_CURRENCY_FORMAT_AMOUNT_NAME))
    local formattedNameWithStackGamepad = zo_strformat(SI_NUMBER_FORMAT, ZO_Currency_FormatGamepad(currencyType, quantity, ZO_CURRENCY_FORMAT_AMOUNT_NAME))

    local rewardData = ZO_RewardData:New(rewardId, parentChoice)
    rewardData:SetFormattedName(formattedName)
    rewardData:SetIcon(GetCurrencyLootKeyboardIcon(currencyType), GetCurrencyLootGamepadIcon(currencyType))
    rewardData:SetFormattedNameWithStack(formattedNameWithStackKeyboard, formattedNameWithStackGamepad)
    rewardData:SetQuantity(quantity)
    rewardData:SetCurrencyInfo(currencyType)
    rewardData:SetAnnouncementBackground(GetRewardAnnouncementBackgroundFileIndex(rewardId))

    return rewardData
end

function ZO_RewardsManager:GetItemEntryInfo(rewardId, quantity, parentChoice)
    local itemLink = GetItemRewardItemLink(rewardId, quantity)
    local displayName = GetItemLinkName(itemLink)
    local itemQuality = GetItemLinkQuality(itemLink)
    local icon = GetItemLinkIcon(itemLink)
    local equipType = GetItemLinkEquipType(itemLink)
    local equipSlot = ZO_Character_GetEquipSlotForEquipType(equipType)

    local rewardData = ZO_RewardData:New(rewardId, parentChoice)
    rewardData:SetFormattedName(zo_strformat(SI_TOOLTIP_ITEM_NAME, displayName))
    rewardData:SetIcon(icon)
    rewardData:SetItemQuality(itemQuality)
    rewardData:SetEquipSlot(equipSlot)
    rewardData:SetQuantity(quantity)
    rewardData:SetFormattedNameWithStack(zo_strformat(SI_REWARDS_FORMAT_REWARD_WITH_AMOUNT, displayName, ZO_SELECTED_TEXT:Colorize(quantity)))
    rewardData:SetAnnouncementBackground(GetRewardAnnouncementBackgroundFileIndex(rewardId))

    return rewardData
end

function ZO_RewardsManager:GetCrownCrateEntryInfo(rewardId, quantity, parentChoice)
    local crateId = GetCrownCrateRewardCrateId(rewardId)
    local icon = GetCrownCrateIcon(crateId)

    local displayName = GetCrownCrateName(crateId)
    local formattedDisplayName = zo_strformat(SI_TOOLTIP_ITEM_NAME, displayName)
    local formattedNameWithStack = zo_strformat(SI_REWARDS_FORMAT_REWARD_WITH_AMOUNT, displayName, ZO_SELECTED_TEXT:Colorize(quantity))
    
    local rewardData = ZO_RewardData:New(rewardId, parentChoice)
    rewardData:SetFormattedName(formattedDisplayName)
    rewardData:SetFormattedNameWithStack(formattedNameWithStack)
    rewardData:SetIcon(icon)
    rewardData:SetQuantity(quantity)
    rewardData:SetAnnouncementBackground(GetRewardAnnouncementBackgroundFileIndex(rewardId))

    return rewardData
end

function ZO_RewardsManager:GetInstantUnlockEntryInfo(rewardId, parentChoice)
    local instantUnlockId = GetInstantUnlockRewardInstantUnlockId(rewardId)
    local icon = GetInstantUnlockRewardIcon(instantUnlockId)
    local displayName = GetInstantUnlockRewardDisplayName(instantUnlockId)
    local formattedDisplayName = zo_strformat(SI_TOOLTIP_ITEM_NAME, displayName)
    
    local rewardData = ZO_RewardData:New(rewardId, parentChoice)
    rewardData:SetFormattedName(formattedDisplayName)
    rewardData:SetIcon(icon)
    rewardData:SetAnnouncementBackground(GetRewardAnnouncementBackgroundFileIndex(rewardId))
    
    return rewardData
end

function ZO_RewardsManager:SortChoiceRewardEntries(data1, data2)
    return data1.choiceIndex < data2.choiceIndex
end

function ZO_RewardsManager:GetCollectibleEntryInfo(rewardId, parentChoice)
    assert(false) -- must be implemented on specific gui version of this manager
end

------------------
-- XML Functions
------------------

function ZO_Rewards_Shared_OnMouseEnter(control, anchorPoint, anchorPointRelativeTo)
    local rewardData = control.data
    if rewardData then
        local rewardType = rewardData:GetRewardType()
        if rewardType and rewardType ~= REWARD_ENTRY_TYPE_CHOICE then
            anchorPoint = anchorPoint or LEFT
            anchorPointRelativeTo = anchorPointRelativeTo or RIGHT
            local rewardId = rewardData:GetRewardId()
            local quantity = rewardData:GetQuantity()
            InitializeTooltip(ItemTooltip, control, anchorPoint, 0, 0, anchorPointRelativeTo)
            ItemTooltip:SetReward(rewardId, quantity)
            if rewardType == REWARD_ENTRY_TYPE_ITEM then
                ItemTooltip:ShowComparativeTooltips()
                ZO_PlayShowAnimationOnComparisonTooltip(ComparativeTooltip1)
                ZO_PlayShowAnimationOnComparisonTooltip(ComparativeTooltip2)
                ZO_Tooltips_SetupDynamicTooltipAnchors(ItemTooltip, control, ComparativeTooltip1, ComparativeTooltip2)
            end
        end
    end
end

function ZO_Rewards_Shared_OnMouseExit(control)
    ClearTooltip(ItemTooltip)
    ItemTooltip:HideComparativeTooltips()
end