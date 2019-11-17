﻿ZO_GAMEPAD_MARKET_SCENE_NAME = "gamepad_market"
ZO_GAMEPAD_MARKET_BUNDLE_CONTENTS_SCENE_NAME = "gamepad_market_bundle_contents"
ZO_GAMEPAD_MARKET_LOCKED_SCENE_NAME = "gamepad_market_locked"
ZO_GAMEPAD_MARKET_PRE_SCENE_NAME = "gamepad_market_pre_scene"

local FIRST_CATEGORY_INDEX = 1
local GAMEPAD_MARKET_LABELED_GROUP_LABEL_TEMPLATE = "ZO_GamepadMarket_GroupLabel"

local LABELED_GROUP_PADDING = 110 --padding from bottom of one gorup to the top of the next
local LABELED_GROUP_LABEL_PADDING = -10 --padding from the top of a group to the bottom of it's header

local MARKET_BUY_CROWNS_BUTTON =
{
    alignment = KEYBIND_STRIP_ALIGN_RIGHT,
    gamepadOrder = 1,
    name = GetString(SI_MARKET_BUY_CROWNS),
    keybind = "UI_SHORTCUT_TERTIARY",
    callback = function() ZO_GAMEPAD_MARKET:OnShowBuyCrownsDialogInternal() end
}

local g_activeMarketScreen = nil

--
--[[ Gamepad Market ]]--
--

local GamepadMarket = ZO_Object.MultiSubclass(ZO_GamepadMarket_GridScreen, ZO_Market_Shared)

function GamepadMarket:New(...)
    return ZO_Market_Shared.New(self, ...)
end

function GamepadMarket:Initialize(control)
    local EMPTY_TAB_HEADER = {}
    ZO_GamepadMarket_GridScreen.Initialize(self, control, EMPTY_TAB_HEADER)
    ZO_Market_Shared.Initialize(self)

    self:InitializeObjectPools()
    self:InitializeLabeledGroups()

    self.marketProductGroupTableSortFunction = function(entry1, entry2)
        return self:CompareMarketProducts(entry1, entry2)
    end
end

function GamepadMarket:InitializeLabeledGroups()
    self.labeledGroups = {}
    self.labeledGroupLabelPool = ZO_ControlPool:New(self:GetLabeledGroupLabelTemplate(), self.control)
end

function GamepadMarket:ClearLabeledGroups()
    ZO_Market_Shared.ClearLabeledGroups(self)

    ZO_ClearNumericallyIndexedTable(self.labeledGroups)
    self.labeledGroupLabelPool:ReleaseAllObjects()
end

function GamepadMarket:SetupSceneGroupCallback()
    self.marketSceneGroup = self.marketScene:GetSceneGroup()
    self.marketSceneGroup:RegisterCallback("StateChange", function(oldState, newState)
        self:PerformDeferredInitialization()
        if newState == SCENE_GROUP_SHOWING then
            self:OnInitialInteraction()
        elseif newState == SCENE_GROUP_HIDDEN then
            self:OnEndInteraction()
        end
    end)
end

function GamepadMarket:PerformDeferredInitialization()
    if self.isInitialized then
        return
    end

    self.isLockedForCategoryRefresh = false
    self.OnGamepadDialogHidden = function()
        self:AnchorCurrentCategoryControlToScrollChild()
    end
    self.categoryLabeledGroupTableMap = {} -- Used to lookup category "LabeledGroup" tables during category building
    self.subcategoryLabeledGroupTableMap = {} -- Used to lookup subcategory "LabeledGroup" tables during category building

    MARKET_CURRENCY_GAMEPAD:RegisterCallback("OnCurrencyUpdated", function() self:OnCurrencyUpdated() end)

    self.isInitialized = true
end

function GamepadMarket:IsShowing()
    return self.marketSceneGroup:IsShowing()
end

function GamepadMarket:GetLabeledGroupLabelTemplate()
    return GAMEPAD_MARKET_LABELED_GROUP_LABEL_TEMPLATE
end

function GamepadMarket:LayoutSelectedGridEntryTooltip()
    EVENT_MANAGER:UnregisterForUpdate("GamepadMarket_Tooltip")

    local selectedEntry = self.selectedGridEntry
    if selectedEntry ~= nil then
        if selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
            selectedEntry:LayoutTooltip(GAMEPAD_RIGHT_TOOLTIP)
        elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MEMBERSHIP_INFO_TILE then
            local statusText, generateTextFunction = ZO_MARKET_MANAGER:GetEsoPlusStatusText()
            GAMEPAD_TOOLTIPS:LayoutEsoPlusMembershipTooltip(GAMEPAD_RIGHT_TOOLTIP, statusText)

            if generateTextFunction then
                EVENT_MANAGER:RegisterForUpdate("GamepadMarket_Tooltip", ZO_ONE_SECOND_IN_MILLISECONDS, function()
                    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP, true)
                    GAMEPAD_TOOLTIPS:LayoutEsoPlusMembershipTooltip(GAMEPAD_RIGHT_TOOLTIP, generateTextFunction())
                end)
            end
        elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_FREE_TRIAL_TILE then
             -- the keybind here should match the actual keybind in the keybind strip to start the free trial
            local PREFER_GAMEPAD_MODE = true
            local TEXTURE_SCALE_PERCENT = 100
            local keybindString
            local key, mod1, mod2, mod3, mod4 = GetIngameHighestPriorityActionBindingInfoFromName("UI_SHORTCUT_PRIMARY", PREFER_GAMEPAD_MODE)
            if key ~= KEY_INVALID then
                keybindString = ZO_Keybindings_GetBindingStringFromKeys(key, mod1, mod2, mod3, mod4, KEYBIND_TEXT_OPTIONS_FULL_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, TEXTURE_SCALE_PERCENT, TEXTURE_SCALE_PERCENT)
            else
                keybindString = ZO_Keybindings_GenerateKeyMarkup(GetString(SI_ACTION_IS_NOT_BOUND))
            end
            GAMEPAD_TOOLTIPS:LayoutEsoPlusTrialNotification(GAMEPAD_RIGHT_TOOLTIP, ZO_MARKET_MANAGER:GetFreeTrialProductData():GetId(), keybindString)
        else
            GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        end
    else
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
    end
end

function GamepadMarket:OnSelectionChanged(selectedData)
    ZO_GamepadMarket_GridScreen.OnSelectionChanged(self, selectedData)
    local previouslySelectedEntry = self.selectedGridEntry
    if selectedData then
        self.selectedGridEntry = selectedData.object
        self:LayoutSelectedGridEntryTooltip()
    elseif not self.isLockedForCategoryRefresh then
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        self.selectedGridEntry = nil
    end

    self:UpdatePreviousAndNewlySelectedProducts(previouslySelectedEntry, self.selectedGridEntry)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptors)
end

function GamepadMarket:OnStateChanged(oldState, newState)
    if newState == SCENE_SHOWING then
        self:OnShowing()
    elseif newState == SCENE_SHOWN then
        self:OnShown()
    elseif newState == SCENE_HIDING then
        self:OnHiding()
    elseif newState == SCENE_HIDDEN then
        self:OnHidden()
    end
end

function GamepadMarket:OnInitialInteraction()
    SetSecureRenderModeEnabled(true)

    UpdateMarketDisplayGroup(MARKET_DISPLAY_GROUP_CROWN_STORE)

    -- ensure that we are in the correct state
    if self.marketState ~= GetMarketState(MARKET_DISPLAY_GROUP_CROWN_STORE) then
        self:UpdateMarket()
    elseif self.marketState == MARKET_STATE_OPEN then
        self:UpdateCurrentCategory()
    end
    
    if self.isInitialized and self.marketState == MARKET_STATE_OPEN then
        GAMEPAD_TOOLTIPS:ClearStatusLabel(GAMEPAD_LEFT_DIALOG_TOOLTIP) -- Clear status labels on entry to the market
        GAMEPAD_TOOLTIPS:ClearStatusLabel(GAMEPAD_RIGHT_TOOLTIP)
        self.isLockedForCategoryRefresh = false
    end
end

function GamepadMarket:OnEndInteraction()
    self:ClearProducts()
    self:ReleasePreviousCategoryProducts()
    self.currentCategoryMarketProductPool:ReleaseAllObjects()
    self.currentCategoryBlankProductPool:ReleaseAllObjects()
    self.lastCategoryData = nil
    self.currentCategoryData = nil
    self:ClearLastPreviewedMarketProductId()
    self.header.tabBar:Clear()
    g_activeMarketScreen = nil

    ZO_Market_Shared.OnEndInteraction(self)
    KEYBIND_STRIP:SetStyle(KEYBIND_STRIP_STANDARD_STYLE)
    ZO_GAMEPAD_MARKET_BUNDLE_CONTENTS:ClearLastPreviewedMarketProductId()
end

function GamepadMarket:OnShowing()
    self:PerformDeferredInitialization()
    ZO_Market_Shared.OnShowing(self)
    self:RefreshTabBarVisible()
end

function GamepadMarket:OnShown()
    if self.marketState == MARKET_STATE_OPEN then
        self:OnMarketOpen()
        self:ReleasePreviousCategoryProducts() -- Cleans up any products left over from entering submenus like bundle details or product preview
        self:Activate()
        self:AddKeybinds()

        g_activeMarketScreen = ZO_GAMEPAD_MARKET
        self:LayoutSelectedGridEntryTooltip()
        ZO_Market_Shared.OnShown(self)
        ZO_GamepadMarket_GridScreen.OnShown(self)
        self:RefreshKeybinds()
        CALLBACK_MANAGER:RegisterCallback("OnGamepadDialogHidden", self.OnGamepadDialogHidden)

        self:ProcessQueuedNavigation()
    else
        self:OnMarketLocked()
    end

    ForceCancelMounted()
end

function GamepadMarket:OnHiding()
    ZO_Market_Shared.OnHiding(self)
    if self.currentCategoryData then
        -- just fade out because we are hiding
        self.currentCategoryData.fragment:SetDirection(ZO_GAMEPAD_MARKET_PAGE_NO_DIRECTION)
    end

    self.queuedTutorial = nil
    ZO_GAMEPAD_MARKET_BUNDLE_CONTENTS:SetQueuedTutorial(nil)

    self.currentCategoryControl = nil
    self:Deactivate()
    self:RemoveKeybinds()
    self:ClearLastPreviewedMarketProductId()
    CALLBACK_MANAGER:UnregisterCallback("OnGamepadDialogHidden", self.OnGamepadDialogHidden)
    EVENT_MANAGER:UnregisterForUpdate("GamepadMarket_Tooltip")
end

function GamepadMarket:InitializeKeybindDescriptors()
    local function RefreshOnPurchase() -- Only called on transaction success
        self.selectedGridEntry:Refresh()
    end

    local function OnPurchaseEnd(reachedConfirmationScene, purchasedConsumables, triggerTutorialOnPurchase)
        self.isLockedForCategoryRefresh = reachedConfirmationScene

        if purchasedConsumables then
            self:SetQueuedTutorial(TUTORIAL_TRIGGER_CROWN_CONSUMABLE_PURCHASED)
        end

        -- Check if an item triggers a tutorial on purchase second, since that takes priority over the consumable tutorial
        if triggerTutorialOnPurchase then
            self:SetQueuedTutorial(triggerTutorialOnPurchase)
        end

        -- We push the purchase scene when we reach the confirmation step
        -- So when we show the market again we will reactivate.
        -- Otherwise, we need to reactivate since we are just hiding a dialog.
        if not reachedConfirmationScene then
            self:Activate()
        end
    end

    local function OnFreeTrialPurchaseEnd(reachedConfirmationScene, purchasedConsumables, triggerTutorialOnPurchase)
        self.forceRedisplayCategory = true
        OnPurchaseEnd(reachedConfirmationScene, purchasedConsumables, triggerTutorialOnPurchase)
    end

    self.keybindStripDescriptors =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Primary Action Keybind (purchase, start free trial, etc.)
        {
             name = function()
                local selectedEntry = self.selectedGridEntry
                if selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                    if selectedEntry:IsBundle() then
                        return GetString(SI_MARKET_PURCHASE_BUNDLE_KEYBIND_TEXT)
                    else
                        return GetString(SI_MARKET_PURCHASE_KEYBIND_TEXT)
                    end
                elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MEMBERSHIP_INFO_TILE then
                    return GetString(SI_GAMEPAD_MARKET_BUY_PLUS_KEYBIND_LABEL)
                elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_FREE_TRIAL_TILE then
                    return GetString(SI_MARKET_START_TRIAL_KEYBIND_TEXT)
                end
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                local selectedEntry = self.selectedGridEntry
                if selectedEntry then
                    if selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                        return not (selectedEntry:IsPurchaseLocked() or selectedEntry:IsHouseCollectible())
                    elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MEMBERSHIP_INFO_TILE then
                        return not IsESOPlusSubscriber() or IsOnESOPlusFreeTrial()
                    elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_FREE_TRIAL_TILE then
                        return not IsOnESOPlusFreeTrial()
                    end
                end
                return false
            end,
            enabled = function()
                if self:HasQueuedTutorial() then
                    return false
                elseif self.selectedGridEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                    return self.selectedGridEntry:CanBePurchased()
                else
                    return true
                end
            end,
            callback = function()
                local selectedEntry = self.selectedGridEntry
                if selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                    self.isLockedForCategoryRefresh = true
                    self:Deactivate()
                    self:PurchaseMarketProductInternal(self.selectedGridEntry:GetMarketProductData(), RefreshOnPurchase, OnPurchaseEnd)
                elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MEMBERSHIP_INFO_TILE then
                    ZO_GamepadMarket_ShowBuyPlusDialog()
                elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_FREE_TRIAL_TILE then
                    self.isLockedForCategoryRefresh = true
                    self:Deactivate()
                    self:PurchaseFreeTrialMarketProductInternal(ZO_MARKET_MANAGER:GetFreeTrialProductData(), function() self:RefreshProducts() end, OnFreeTrialPurchaseEnd)
                end
            end,
        },
        -- Gift Keybind
        {
             name = function()
                if self.selectedGridEntry:IsBundle() then
                    return GetString(SI_MARKET_GIFT_BUNDLE_KEYBIND_TEXT)
                else
                    return GetString(SI_MARKET_GIFT_KEYBIND_TEXT)
                end
            end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            visible = function()
                if self.selectedGridEntry and self.selectedGridEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                    return self.selectedGridEntry:IsGiftable()
                end
                return false
            end,
            enabled = function()
                return not self:HasQueuedTutorial()
            end,
            callback = function()
                self.isLockedForCategoryRefresh = true
                self:GiftMarketProductInternal(self.selectedGridEntry:GetMarketProductData(), RefreshOnPurchase, OnPurchaseEnd)
                self:Deactivate()
            end,
        },
        -- Secondary Action Keybind (preview, view benefits, etc.)
        {
            name = function()
                local selectedEntry = self.selectedGridEntry
                if selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                    local previewType = self.selectedGridEntry:GetMarketProductPreviewType()
                    if previewType == ZO_MARKET_PREVIEW_TYPE_BUNDLE or previewType == ZO_MARKET_PREVIEW_TYPE_BUNDLE_HIDES_CHILDREN then
                        return GetString(SI_MARKET_BUNDLE_DETAILS_KEYBIND_TEXT)
                    else
                        return GetString(SI_MARKET_PREVIEW_KEYBIND_TEXT)
                    end
                elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MEMBERSHIP_INFO_TILE then
                    return GetString(SI_GAMEPAD_MARKET_VIEW_BENEFITS_KEYBIND)
                end
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                local selectedEntry = self.selectedGridEntry
                if selectedEntry ~= nil then
                    return selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT or selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MEMBERSHIP_INFO_TILE
                end
                return false
            end,
            enabled = function()
                local selectedEntry = self.selectedGridEntry
                if selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                    local previewType = selectedEntry:GetMarketProductPreviewType()
                    if previewType == ZO_MARKET_PREVIEW_TYPE_PREVIEWABLE then
                        return selectedEntry:HasPreview() and IsCharacterPreviewingAvailable()
                    elseif previewType == ZO_MARKET_PREVIEW_TYPE_HOUSE then
                        return CanJumpToHouseFromCurrentLocation(), GetString(SI_MARKET_PREVIEW_ERROR_CANNOT_JUMP_FROM_LOCATION)
                    else
                        return true
                    end
                else
                    return true
                end
            end,
            callback = function()
                local selectedEntry = self.selectedGridEntry
                if selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                    local previewType = selectedEntry:GetMarketProductPreviewType()
                    if previewType == ZO_MARKET_PREVIEW_TYPE_BUNDLE then
                        self:ShowBundleContents(selectedEntry)
                    elseif previewType == ZO_MARKET_PREVIEW_TYPE_CROWN_CRATE or previewType == ZO_MARKET_PREVIEW_TYPE_BUNDLE_HIDES_CHILDREN then
                        self:ShowMarketProductContentsAsList(selectedEntry, previewType)
                    elseif previewType == ZO_MARKET_PREVIEW_TYPE_HOUSE then
                        self:ShowHousePreviewDialog(selectedEntry)
                    else -- ZO_MARKET_PREVIEW_TYPE_PREVIEWABLE
                        self:BeginPreview()
                    end
                elseif selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MEMBERSHIP_INFO_TILE then
                    ZO_ESO_PLUS_MEMBERSHIP_DIALOG:Show()
                end
            end,
        },
        MARKET_BUY_CROWNS_BUTTON,
        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor(),
    }
end

function GamepadMarket:GetPrimaryButtonDescriptor()
    return self.primaryButtonDescriptor
end

function GamepadMarket:BeginPreview()
    self.isLockedForCategoryRefresh = true
    self.currentCategoryData.fragment:SetDirection(ZO_GAMEPAD_MARKET_PAGE_NO_DIRECTION)
    g_activeMarketScreen = ZO_GAMEPAD_MARKET_PREVIEW
    ZO_GamepadMarket_GridScreen.BeginPreview(self)
end 

function GamepadMarket:OnCategorySelected(data)
    if self.marketScene:IsShowing() and self.marketState == MARKET_STATE_OPEN then
        self.lastCategoryData, self.currentCategoryData = self.currentCategoryData, data
        local lastCategoryControl = self.currentCategoryControl
        self.currentCategoryControl = data.control

        if self.lastCategoryData ~= self.currentCategoryData then
            self.isLockedForCategoryRefresh = false
        end

        if not self.isLockedForCategoryRefresh or self.forceRedisplayCategory then
            ZO_ClearTable(self.categoryLabeledGroupTableMap)
            ZO_ClearTable(self.subcategoryLabeledGroupTableMap)
            self:ClearLabeledGroups()
            self:ClearProducts()

            self:DisplayCategory(data)

            self:UpdateCategoryAnimationDirection()
            self.forceRedisplayCategory = false
        else
            self:UpdateScrollbarAlpha()
        end

        if lastCategoryControl ~= self.currentCategoryControl then
            -- This temporarily disables scrolling for the old and new categories, but allows for the paging animation to work correctly.
            -- The category controls will be re-anchored to the scroll child if/when they are shown
            if self.lastCategoryData then
                if not self.isLockedForCategoryRefresh then
                    lastCategoryControl:ClearAnchors()
                    lastCategoryControl:SetAnchorFill(self.contentContainer)
                end

                SCENE_MANAGER:RemoveFragment(self.lastCategoryData.fragment)
            end

            if not self.isLockedForCategoryRefresh then
                self.currentCategoryControl:ClearAnchors()
                self.currentCategoryControl:SetAnchorFill(self.contentContainer)
            end

            SCENE_MANAGER:AddFragment(data.fragment)
        end

        if not self.isLockedForCategoryRefresh then
            local categoryIndex, subcategoryIndex
            -- faked category types don't have real category indices so keep them as nil
            if data.type == ZO_MARKET_CATEGORY_TYPE_NONE then
                if data.parentData then
                    categoryIndex = data.parentData.categoryIndex
                    subcategoryIndex = data.categoryIndex
                else
                    categoryIndex = data.categoryIndex
                end
            end

            OnMarketCategorySelected(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryIndex, subcategoryIndex)
        end

        local queuedCategoryIndex, queuedSubcategoryIndex = self:GetQueuedCategoryIndices()
        if queuedCategoryIndex then
            self:ScrollToSubcategory(queuedCategoryIndex, queuedSubcategoryIndex) -- can't scroll instantly here, cause we just built the scroll
        else
            local queuedMarketProductId = self:GetQueuedMarketProductId()
            if queuedMarketProductId then
                self:ScrollToMarketProduct(queuedMarketProductId) -- can't scroll instantly here, cause we just built the scroll
            end
        end
    end
end

function GamepadMarket:DisplayCategory(data)
    if data.type == ZO_MARKET_CATEGORY_TYPE_ESO_PLUS then
        self:DisplayEsoPlusOffer()
    else
        ZO_Market_Shared.DisplayCategory(self, data)
    end
end

do
    local MARKET_PRODUCT_SORT_KEYS =
    {
        name = { tiebreaker = "stackCount", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
        stackCount = {},
    }

    function GamepadMarket:CompareMarketProducts(entry1, entry2)
        return ZO_TableOrderingFunction(entry1, entry2, "name", MARKET_PRODUCT_SORT_KEYS, ZO_SORT_ORDER_UP)
    end
end

function GamepadMarket:OnCurrencyUpdated()
    if not self.control:IsHidden() then
        self:RefreshKeybinds()
    elseif GAMEPAD_MARKET_BUNDLE_CONTENTS_SCENE and GAMEPAD_MARKET_BUNDLE_CONTENTS_SCENE:IsShowing() then
        ZO_GAMEPAD_MARKET_BUNDLE_CONTENTS:RefreshKeybinds()
    end
end

function GamepadMarket:CreateMarketScene()
    local scene = ZO_RemoteScene:New(ZO_GAMEPAD_MARKET_SCENE_NAME, SCENE_MANAGER)
    SYSTEMS:RegisterGamepadRootScene(ZO_MARKET_NAME, scene)
    self:SetMarketScene(scene)
end

function GamepadMarket:InitializeObjectPools()
    local PRODUCT_BASE_CONTROL_NAME = self.control:GetName() .. ZO_GAMEPAD_MARKET_PRODUCT_TEMPLATE
    local function CreateMarketProduct(objectPool)
        return ZO_GamepadMarketProduct:New(objectPool:GetNextControlId(), self.currentCategoryControl, PRODUCT_BASE_CONTROL_NAME)
    end

    local function ResetMarketProduct(marketProduct)
        marketProduct:Reset()
    end

    self.marketProductPool = ZO_ObjectPool:New(CreateMarketProduct, ResetMarketProduct)

    self.currentCategoryMarketProductPool = ZO_MetaPool:New(self.marketProductPool)
    self.lastCategoryMarketProductPool = ZO_MetaPool:New(self.marketProductPool)

    local BLANK_TILE_BASE_CONTROL_NAME = self.control:GetName() .. ZO_GAMEPAD_MARKET_BLANK_TILE_TEMPLATE
    local function CreateBlankTile(objectPool)
        local control = CreateControlFromVirtual(BLANK_TILE_BASE_CONTROL_NAME, self.currentCategoryControl, ZO_GAMEPAD_MARKET_BLANK_TILE_TEMPLATE, objectPool:GetNextControlId())
        return ZO_GamepadMarketBlankTile:New(control)
    end

    local function ResetBlankTile(blankTile)
        blankTile:Reset()
    end

    self.blankTilePool = ZO_ObjectPool:New(CreateBlankTile, ResetBlankTile)

    self.currentCategoryBlankProductPool = ZO_MetaPool:New(self.blankTilePool)
    self.lastCategoryBlankProductPool = ZO_MetaPool:New(self.blankTilePool)

    local GENERIC_TILE_BASE_CONTROL_NAME = self.control:GetName() .. "ZO_Gamepad_MarketGenericTileTemplate"
    local function CreateGenericTile(objectPool)
        local control = CreateControlFromVirtual(GENERIC_TILE_BASE_CONTROL_NAME, self.currentCategoryControl, "ZO_Gamepad_MarketGenericTileTemplate", objectPool:GetNextControlId())
        return ZO_GamepadMarketGenericTile:New(control)
    end

    local function ResetGenericTile(genericTile)
        genericTile:Reset()
    end

    self.genericTilePool = ZO_ObjectPool:New(CreateGenericTile, ResetGenericTile)

    self.currentCategoryGenericProductPool = ZO_MetaPool:New(self.genericTilePool)
    self.lastCategoryGenericProductPool = ZO_MetaPool:New(self.genericTilePool)
end

-- "Cache" the current products in lastCategoryMarketProductPool. These will be released after the category change animation has finished
function GamepadMarket:ReleaseAllProducts()
    self:ReleasePreviousCategoryProducts()
    self.currentCategoryMarketProductPool, self.lastCategoryMarketProductPool = self.lastCategoryMarketProductPool, self.currentCategoryMarketProductPool
    self.currentCategoryBlankProductPool, self.lastCategoryBlankProductPool = self.lastCategoryBlankProductPool, self.currentCategoryBlankProductPool
    self.currentCategoryGenericProductPool, self.lastCategoryGenericProductPool = self.lastCategoryGenericProductPool, self.currentCategoryGenericProductPool
end

function GamepadMarket:ReleasePreviousCategoryProducts()
    self.lastCategoryMarketProductPool:ReleaseAllObjects()
    self.lastCategoryBlankProductPool:ReleaseAllObjects()
    self.lastCategoryGenericProductPool:ReleaseAllObjects()
end

function GamepadMarket:AnchorCurrentCategoryControlToScrollChild()
    self.currentCategoryControl:ClearAnchors()
    self.currentCategoryControl:SetAnchor(TOPLEFT, self.contentContainer.scrollChild, TOPLEFT)
end

do
    local function CreateSubcategoryData(name, parentData, index, numProducts)
        return {
            text = name,
            numProducts = numProducts,
            soundId = SOUNDS.MARKET_SUB_CATEGORY_SELECTED,
            parentData = parentData,
            parent = parentData.control,
            categoryIndex = index,
        }
    end

    local GAMEPAD_MARKET_CATEGORY_TEMPLATE = "ZO_GamepadMarket_CategoryTemplate"
    local g_controlNameToFragment = {}
    local function GetOrCreateCategoryControlAndFragment(parent, marketCategoryIndex, categoryType)
        local currentControlName = GAMEPAD_MARKET_CATEGORY_TEMPLATE
        if marketCategoryIndex and marketCategoryIndex > 0 then
            currentControlName = currentControlName .. marketCategoryIndex
        else -- this is a faked category
            currentControlName = currentControlName .. categoryType
        end

        local currentControl = GetControl(currentControlName)
        if currentControl ~= nil then
            local currentFragment = g_controlNameToFragment[currentControlName]
            return currentControl, currentFragment
        else
            local newControl = CreateControlFromVirtual(currentControlName, parent, GAMEPAD_MARKET_CATEGORY_TEMPLATE)
            local ALWAYS_ANIMATE = true
            local newFragment = ZO_GamepadMarketPageFragment:New(newControl, ALWAYS_ANIMATE)
            g_controlNameToFragment[currentControlName] = newFragment
            return newControl, newFragment
        end
    end

    local function CreateCategoryData(name, parent, marketCategoryIndex, tabIndex, numSubcategories, categoryType)
        categoryType = categoryType or ZO_MARKET_CATEGORY_TYPE_NONE
        local control, fragment = GetOrCreateCategoryControlAndFragment(parent, marketCategoryIndex, categoryType)
        return {
            text = name,
            control = control,
            subCategories = {},
            numSubcategories = numSubcategories,
            soundId = SOUNDS.MARKET_CATEGORY_SELECTED,
            categoryIndex = marketCategoryIndex, -- Market category index used for def lookup
            tabIndex = tabIndex, -- Index in the tab header, as displayed. This can be different from the market category index when there are faked categories
            type = categoryType,
            fragment = fragment,
        }
    end

    local SUBCATEGORY_GEM_FORMATTED_ICON = ZO_Currency_GetGamepadFormattedCurrencyIcon(CURT_CROWN_GEMS)
    function GamepadMarket:AddTopLevelCategory(categoryIndex, tabIndex, name, numSubcategories, categoryType, containsNewProductsFunction)
        -- cache the possible category names so we don't reformat the string everytime we change categories
        local formattedBaseName = zo_strformat(SI_MARKET_PRODUCT_NAME_FORMATTER, name)
        local formattedNameWithNew = zo_iconTextFormat(ZO_GAMEPAD_NEW_ICON_32, 32, 32, name)
        local nameFunction = function()
            if containsNewProductsFunction and containsNewProductsFunction() then
                return formattedNameWithNew
            else
                return formattedBaseName
            end
        end

        local categoryData = CreateCategoryData(formattedBaseName, self.contentContainer.scrollChild, categoryIndex, tabIndex, numSubcategories, categoryType)

        local hasChildren = numSubcategories > 0
        if hasChildren then
            for i = 1, numSubcategories do
                local subCategoryName, numSubCategoryMarketProducts, showGemIcon = GetMarketProductSubCategoryInfo(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryIndex, i)
                if showGemIcon then
                    subCategoryName = string.format("%s %s", SUBCATEGORY_GEM_FORMATTED_ICON, zo_strformat(SI_MARKET_PRODUCT_NAME_FORMATTER, subCategoryName))
                else
                    subCategoryName = zo_strformat(SI_MARKET_PRODUCT_NAME_FORMATTER, subCategoryName)
                end
                local subCategoryData = CreateSubcategoryData(subCategoryName, categoryData, i, numSubCategoryMarketProducts)
                table.insert(categoryData.subCategories, subCategoryData)
            end
        end

        local function OnCategoryFragmentStateChanged(oldState, newState)
            if newState == SCENE_FRAGMENT_HIDDEN then
                self:ReleasePreviousCategoryProducts() -- Wait to release products until the after the animation has finished
            elseif newState == SCENE_FRAGMENT_SHOWN and not self.isLockedForCategoryRefresh then
                -- Re-anchoring after animation to enable scrolling of the category control
                self:AnchorCurrentCategoryControlToScrollChild()
            end
        end

        categoryData.fragment:RegisterCallback("StateChange", OnCategoryFragmentStateChanged)

        local tabEntry =
        {
            text = nameFunction,
            categoryData = categoryData,
            callback = function()
                self:OnCategorySelected(categoryData)
            end,
        }

        table.insert(self.headerData.tabBarEntries, tabEntry)
    end
end

do
    local currentTabIndex = FIRST_CATEGORY_INDEX
    local function GetFirstTabIndex()
        currentTabIndex = FIRST_CATEGORY_INDEX
        return currentTabIndex
    end

    local function GetNextTabIndex()
        currentTabIndex = currentTabIndex + 1
        return currentTabIndex
    end

    local ZERO_SUBCATEGORIES = 0
    function GamepadMarket:BuildCategories(control)
        if self.marketState == MARKET_STATE_OPEN then
            ZO_ClearTable(self.headerData.tabBarEntries)

            local firstIndex = GetFirstTabIndex()

            local numFeaturedMarketProducts = GetNumFeaturedMarketProducts()
            local hasFeaturedCategory = numFeaturedMarketProducts > 0
            self.featuredCategoryIndex = nil
            if hasFeaturedCategory then
                self.featuredCategoryIndex = firstIndex
                self:AddTopLevelCategory(ZO_MARKET_FEATURED_CATEGORY_INDEX, self.featuredCategoryIndex, GetString(SI_MARKET_FEATURED_CATEGORY), ZERO_SUBCATEGORIES, ZO_MARKET_CATEGORY_TYPE_FEATURED, function() return HasNewFeaturedMarketProducts() end)
            end

            local showNewOnEsoPlusCategoryFunction = function()
                ZO_MARKET_MANAGER:UpdateFreeTrialProduct()
                if ZO_MARKET_MANAGER:ShouldShowFreeTrial() then
                    local freeTrialIsNew = ZO_MARKET_MANAGER:GetFreeTrialProductData():IsNew()
                    if freeTrialIsNew then
                        return true
                    end
                end

                local numMarketCategories = GetNumMarketProductCategories(MARKET_DISPLAY_GROUP_CROWN_STORE)
                for categoryIndex = 1, numMarketCategories do
                    if DoesMarketProductCategoryOrSubcategoriesContainNewEsoPlusMarketProducts(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryIndex) then
                        return true
                    end
                end

                return false
            end

            self.esoPlusCategoryIndex = hasFeaturedCategory and GetNextTabIndex() or firstIndex
            self:AddTopLevelCategory(ZO_MARKET_ESO_PLUS_CATEGORY_INDEX, self.esoPlusCategoryIndex, GetString(SI_MARKET_ESO_PLUS_CATEGORY), ZERO_SUBCATEGORIES, ZO_MARKET_CATEGORY_TYPE_ESO_PLUS, showNewOnEsoPlusCategoryFunction)

            -- adding in the custom categories offsets our market product category indices
            -- so even though a category is index 1 from data, it might actually be index 3
            -- since we show a featured and ESO Plus category
            self.categoryIndexOffset = self.esoPlusCategoryIndex

            local numCategories = GetNumMarketProductCategories(MARKET_DISPLAY_GROUP_CROWN_STORE)
            for i = 1, numCategories do
                local name, numSubcategories = GetMarketProductCategoryInfo(MARKET_DISPLAY_GROUP_CROWN_STORE, i)
                self:AddTopLevelCategory(i, GetNextTabIndex(), name, numSubcategories, ZO_MARKET_CATEGORY_TYPE_NONE, function() return DoesMarketProductCategoryOrSubcategoriesContainNewMarketProducts(MARKET_DISPLAY_GROUP_CROWN_STORE, i) end)
            end

            self.categoriesInitialized = true

            self.refreshCategories = false
        end
    end
end

function GamepadMarket:BuildFeaturedMarketProductList()
    local numFeaturedMarketProducts = GetNumFeaturedMarketProducts()
    local marketProductPresentations = { self:GetFeaturedProductPresentations(numFeaturedMarketProducts) }

    for _, productData in ipairs(marketProductPresentations) do
        local marketProduct = self.currentCategoryMarketProductPool:AcquireObject()
        marketProduct:Show(productData)

        if productData:ContainsDLC() then
            self:AddMarketProductEntryToLabeledGroupTable(self.dlcProducts, marketProduct)
        elseif productData:IsLimitedTimeProduct() then
            self:AddMarketProductEntryToLabeledGroupTable(self.limitedTimedOfferProducts, marketProduct)
        elseif productData:IsFeatured() then
            self:AddMarketProductEntryToLabeledGroupTable(self.featuredProducts, marketProduct)
        else
            self:AddMarketProductEntryToLabeledGroupTable(self.marketProducts, marketProduct)
        end
    end

    self:SortMarketProductLabeledGroupTable(self.limitedTimedOfferProducts)
    self:SortMarketProductLabeledGroupTable(self.dlcProducts)
    self:SortMarketProductLabeledGroupTable(self.featuredProducts)
    self:SortMarketProductLabeledGroupTable(self.marketProducts)

    local labeledGroupTables =
    {
        {name = GetString(SI_MARKET_LIMITED_TIME_OFFER_CATEGORY), marketProducts = self.limitedTimedOfferProducts},
        {name = GetString(SI_MARKET_DLC_CATEGORY), marketProducts = self.dlcProducts},
        {name = GetString(SI_MARKET_FEATURED_CATEGORY), marketProducts = self.featuredProducts},
        {name = GetString(SI_MARKET_ALL_LABEL), marketProducts = self.marketProducts},
    }

    self:LayoutMarketProducts(labeledGroupTables)
end

local function SubcategoryListSort(firstEntry, secondEntry)
    return firstEntry.categoryIndex < secondEntry.categoryIndex
end

-- the table of subcategory data may have holes in it if a category ends up not displaying 
-- any market products (they were all featured for example) so we need to resort to get rid of holes
local function CreateSortedSubcategoryList(subcategoryData)
    local sortedList = {}
    for k, v in pairs(subcategoryData) do
        table.insert(sortedList, { categoryIndex = k, displayName = v.displayName, groupTable = v.groupTable})
    end
    table.sort(sortedList, SubcategoryListSort)
    return sortedList
end

function GamepadMarket:BuildMarketProductList(data)
    local parentCategoryIndex, parentSubcategoryIndex = self:GetCategoryIndices(data, data.parentData)

    -- subcategories will be accumulated into the parent categories, so ignore them
    if not parentSubcategoryIndex then
        -- For gamepad, if the top level category is set to disable the LTO grouping, we won't show it at all in the category
        -- so even though the subcategories aren't flagged as such their products won't go into a LTO grouping
        local disableLTOGrouping = IsLTODisabledForMarketProductCategory(MARKET_DISPLAY_GROUP_CROWN_STORE, parentCategoryIndex)

        -- iterate over all of the subcategories in this category to display all of their market products
        -- starting at 0 since that will indicate to GetCategoryProductIds that we also want the products under the parent category itself
        for subcategoryIndex = 0, data.numSubcategories do
            local marketProductPresentations = { self:GetCategoryProductIds(parentCategoryIndex, subcategoryIndex) }

            local subCategoryData = data.subCategories[subcategoryIndex]
            for index, productData in ipairs(marketProductPresentations) do
                local marketProduct = self.currentCategoryMarketProductPool:AcquireObject()
                marketProduct:Show(productData)

                if not disableLTOGrouping and productData:IsLimitedTimeProduct() then
                    self:AddMarketProductEntryToLabeledGroupTable(self.limitedTimedOfferProducts, marketProduct)
                elseif productData:IsFeatured() then
                    self:AddMarketProductEntryToLabeledGroupTable(self.featuredProducts, marketProduct)
                else
                    if subCategoryData then
                        self:AddMarketProductEntryToLabeledGroupTable(self:FindOrCreateSubCategoryLabeledGroupTable(subCategoryData.categoryIndex, subCategoryData.text), marketProduct)
                    else
                        self:AddMarketProductEntryToLabeledGroupTable(self.marketProducts, marketProduct)
                    end
                end
            end
        end

        self:SortMarketProductLabeledGroupTable(self.limitedTimedOfferProducts)
        self:SortMarketProductLabeledGroupTable(self.featuredProducts)

        local labeledGroupTables =
        {
            {name = GetString(SI_MARKET_LIMITED_TIME_OFFER_CATEGORY), marketProducts = self.limitedTimedOfferProducts},
            {name = GetString(SI_MARKET_FEATURED_CATEGORY), marketProducts = self.featuredProducts},
        }

        local sortedSubcategoryGroupTables = CreateSortedSubcategoryList(self.subcategoryLabeledGroupTableMap)
        for index, groupTableInfo in ipairs(sortedSubcategoryGroupTables) do
            local groupTable = groupTableInfo.groupTable
            self:SortMarketProductLabeledGroupTable(groupTable)
            table.insert(labeledGroupTables, {name = groupTableInfo.displayName, marketProducts = groupTable})
        end

        self:SortMarketProductLabeledGroupTable(self.marketProducts)
        table.insert(labeledGroupTables, {name = GetString(SI_MARKET_ALL_LABEL), marketProducts = self.marketProducts})

        self:LayoutMarketProducts(labeledGroupTables)
    end
end

-- ... is a list of MarketProductData
function GamepadMarket:GetCategoryProductIds(categoryIndex, subcategoryIndex, productFilterFunction, ...)
    if subcategoryIndex == 0 then
        local numMarketProducts = select(3, GetMarketProductCategoryInfo(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryIndex))
        return self:GetMarketProductPresentations(categoryIndex, nil, numMarketProducts, productFilterFunction, ...)
    else
        local numMarketProducts = select(2, GetMarketProductSubCategoryInfo(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryIndex, subcategoryIndex))
        return self:GetMarketProductPresentations(categoryIndex, subcategoryIndex, numMarketProducts, productFilterFunction, ...)
    end
end

-- ... is a list of MarketProductData
function GamepadMarket:GetMarketProductPresentations(categoryIndex, subcategoryIndex, index, productFilterFunction, ...)
    if index >= 1 then
        local id, presentationIndex = GetMarketProductPresentationIds(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryIndex, subcategoryIndex, index)
        local productData = ZO_MarketProductData:New(id, presentationIndex)
        index = index - 1
        if productFilterFunction and not productFilterFunction(productData) then
            return self:GetMarketProductPresentations(categoryIndex, subcategoryIndex, index, productFilterFunction, ...)
        else
            return self:GetMarketProductPresentations(categoryIndex, subcategoryIndex, index, productFilterFunction, productData, ...)
        end
    end
    return ...
end

-- override from ZO_GamepadMarket_GridScreen
function GamepadMarket:FinishBuild()
    self:FinishCurrentLabeledGroup() -- must come before call to parent's FinishBuild
    ZO_GamepadMarket_GridScreen.FinishBuild(self)
    self:RefreshKeybinds()
end

-- override from ZO_GamepadMarket_GridScreen
function GamepadMarket:EndCurrentPreview()
    ZO_GamepadMarket_GridScreen.EndCurrentPreview(self)
    self:RefreshKeybinds()
end

function GamepadMarket:AddLabel(labeledGroupName, parentControl, yPadding)
    local labeledGroupLabel = self.labeledGroupLabelPool:AcquireObject()
    labeledGroupLabel:SetText(labeledGroupName)
    labeledGroupLabel:SetParent(parentControl)
    labeledGroupLabel:ClearAnchors()
    labeledGroupLabel:SetAnchor(BOTTOMLEFT, parentControl, TOPLEFT, 0, yPadding)
end

function GamepadMarket:FinishRowWithBlankTiles()
    local currentItemRowIndex = #self.gridEntries % self.itemsPerRow
    if currentItemRowIndex > 0 then
        for i = currentItemRowIndex, self.itemsPerRow - 1 do
            local blankTile = self.currentCategoryBlankProductPool:AcquireObject()
            blankTile:Show()
            self:AddEntry(blankTile, blankTile:GetControl())
        end
    end
end

function GamepadMarket:FinishCurrentLabeledGroup()
    self:FinishRowWithBlankTiles()

    local currentLabeledGroup = self.labeledGroups[#self.labeledGroups]
    if currentLabeledGroup.numEntries > 0 then
        self.gridYPaddingOffset = self.gridYPaddingOffset + LABELED_GROUP_PADDING
    end
end

function GamepadMarket:AddLabeledGroupTable(labeledGroupName, labeledGroupTable)
    if #self.labeledGroups > 0 then
        self:FinishCurrentLabeledGroup()
    end

    local numEntries = #labeledGroupTable
    table.insert(self.labeledGroups, { name = labeledGroupName, table = labeledGroupTable, numEntries = numEntries })

    for i, entry in ipairs(labeledGroupTable) do
        self:AddEntry(entry.object, entry.control)

        if i == 1 and labeledGroupName then
            self:AddLabel(labeledGroupName, entry.control, LABELED_GROUP_LABEL_PADDING)
        end
    end
end

function GamepadMarket:AddMarketProductEntryToLabeledGroupTable(labeledGroupTable, marketProduct)
    local entryInfo = {
                            object = marketProduct,
                            control = marketProduct:GetControl(),
                            entryType = marketProduct:GetEntryType(),
                            -- for sorting
                            name = marketProduct:GetMarketProductDisplayName(),
                            stackCount = marketProduct:GetStackCount(),
                        }
    table.insert(labeledGroupTable, entryInfo)
end

function GamepadMarket:SortMarketProductLabeledGroupTable(labeledGroupTable)
    table.sort(labeledGroupTable, self.marketProductGroupTableSortFunction)
end

function GamepadMarket:FindOrCreateSubCategoryLabeledGroupTable(subcategoryIndex, displayName)
    if not self.subcategoryLabeledGroupTableMap[subcategoryIndex] then
        self.subcategoryLabeledGroupTableMap[subcategoryIndex] = { displayName = displayName, groupTable = {}}
    end

    return self.subcategoryLabeledGroupTableMap[subcategoryIndex].groupTable
end

function GamepadMarket:FindOrCreateCategoryLabeledGroupTable(categoryIndex, displayName)
    if not self.categoryLabeledGroupTableMap[categoryIndex] then
        self.categoryLabeledGroupTableMap[categoryIndex] = { displayName = displayName, groupTable = {}}
    end

    return self.categoryLabeledGroupTableMap[categoryIndex].groupTable
end

function GamepadMarket:UpdateCategoryAnimationDirection()
    local direction = ZO_GAMEPAD_MARKET_PAGE_LEFT_DIRECTION
    if self.lastCategoryData and self.lastCategoryData ~= self.currentCategoryData then
        -- We have to account for tab wrapping and perceived direction traversal
        local currentTabIndex = self.currentCategoryData.tabIndex
        local lastTabIndex = self.lastCategoryData.tabIndex
        if currentTabIndex < lastTabIndex then
            if currentTabIndex ~= FIRST_CATEGORY_INDEX or lastTabIndex ~= #self.headerData.tabBarEntries then
                direction = ZO_GAMEPAD_MARKET_PAGE_RIGHT_DIRECTION
            end
        elseif currentTabIndex == #self.headerData.tabBarEntries and lastTabIndex == FIRST_CATEGORY_INDEX then
            direction = ZO_GAMEPAD_MARKET_PAGE_RIGHT_DIRECTION
        end
    else -- we don't have a last category or its the same as the current so no need to animate
        direction = ZO_GAMEPAD_MARKET_PAGE_NO_DIRECTION
    end

    if self.lastCategoryData then
        self.lastCategoryData.fragment:SetDirection(direction)
    end

    self.currentCategoryData.fragment:SetDirection(self.isLockedForCategoryRefresh and ZO_GAMEPAD_MARKET_PAGE_NO_DIRECTION or direction)
end

function GamepadMarket:SetCurrentKeybinds(keybindDescriptor)
    if keybindDescriptor ~= self.currentKeybindDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currentKeybindDescriptor)
        KEYBIND_STRIP:AddKeybindButtonGroup(keybindDescriptor)

        self.currentKeybindDescriptor = keybindDescriptor
    end
end

do
    local function DoesMarketProductHaveEsoPlusPrice(productData)
        local marketCurrencyType, cost, costAfterDiscount, discountPercent, esoPlusCost = productData:GetMarketProductPricingByPresentation()
        return esoPlusCost ~= nil
    end

    local function IsFullEsoPlusMember()
        return IsESOPlusSubscriber() and not IsOnESOPlusFreeTrial()
    end

    function GamepadMarket:DisplayEsoPlusOffer()
        local esoPlusMembershipTiles = {}

        ZO_MARKET_MANAGER:UpdateFreeTrialProduct()

        local shouldShowFreeTrial = ZO_MARKET_MANAGER:HasFreeTrialProduct() and not IsFullEsoPlusMember()
        if shouldShowFreeTrial then
            local freeTrialTile = self.currentCategoryGenericProductPool:AcquireObject()
            freeTrialTile:SetEntryType(ZO_GAMEPAD_MARKET_ENTRY_FREE_TRIAL_TILE)
            freeTrialTile:SetBackground("EsoUI/Art/Market/Gamepad/gp_free_trial_tile_background.dds")
            freeTrialTile:SetTitle(GetString(SI_GAMEPAD_MARKET_FREE_TRIAL_TILE_TITLE))

            local function GetFreeTrialText()
                if IsOnESOPlusFreeTrial() then
                    return GetString(SI_GAMEPAD_MARKET_FREE_TRIAL_TILE_ACTIVE_TEXT)
                else
                    return GetString(SI_GAMEPAD_MARKET_FREE_TRIAL_TILE_TEXT)
                end
            end
            freeTrialTile:SetText(GetFreeTrialText)
            freeTrialTile:SetPurchaseCheckFunction(IsOnESOPlusFreeTrial)
            freeTrialTile:Show()

            local entryInfo = {
                            object = freeTrialTile,
                            control = freeTrialTile:GetControl(),
                        }
            table.insert(esoPlusMembershipTiles, entryInfo)
        end

        -- Add membership info tile
        local membershipInfoTile = self.currentCategoryGenericProductPool:AcquireObject()
        membershipInfoTile:SetEntryType(ZO_GAMEPAD_MARKET_ENTRY_MEMBERSHIP_INFO_TILE)
        membershipInfoTile:SetBackground("EsoUI/Art/Market/Gamepad/gp_membership_info_tile_background.dds")
        membershipInfoTile:SetTitle(GetString(SI_GAMEPAD_MARKET_MEMBERSHIP_INFO_TILE_TITLE))
        membershipInfoTile:SetTitleColors(ZO_MARKET_PRODUCT_ESO_PLUS_COLOR, ZO_MARKET_PRODUCT_ESO_PLUS_DIMMED_COLOR)

        local function GetMembershipInfoText()
            if IsFullEsoPlusMember() then
                return GetString(SI_GAMEPAD_MARKET_MEMBERSHIP_INFO_TILE_ACTIVE_TEXT)
            else
                return GetString(SI_GAMEPAD_MARKET_MEMBERSHIP_INFO_TILE_TEXT)
            end
        end
        membershipInfoTile:SetText(GetMembershipInfoText)

        membershipInfoTile:SetTextColors(ZO_MARKET_PRODUCT_ESO_PLUS_COLOR, ZO_MARKET_PRODUCT_ESO_PLUS_DIMMED_COLOR)
        membershipInfoTile:SetPurchaseCheckFunction(IsFullEsoPlusMember)
        membershipInfoTile:Show()

        local entryInfo = {
                        object = membershipInfoTile,
                        control = membershipInfoTile:GetControl(),
                    }
        table.insert(esoPlusMembershipTiles, entryInfo)

        local numCategories = GetNumMarketProductCategories(MARKET_DISPLAY_GROUP_CROWN_STORE)
        for categoryIndex = 1, numCategories do
            if DoesMarketProductCategoryOrSubcategoriesContainEsoPlusMarketProducts(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryIndex) then
                local categoryName, numSubcategories = GetMarketProductCategoryInfo(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryIndex)
                local formattedBaseName = zo_strformat(SI_MARKET_PRODUCT_NAME_FORMATTER, categoryName)

                -- iterate over all of the subcategories in this category to display all of their market products
                -- starting at 0 since that will indicate to GetCategoryProductIds that we also want the products under the parent category itself
                for subcategoryIndex = 0, numSubcategories do
                    if subcategoryIndex == 0 or DoesMarketProductCategoryOrSubcategoriesContainEsoPlusMarketProducts(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryIndex, subcategoryIndex) then
                        local marketProductPresentations = { self:GetCategoryProductIds(categoryIndex, subcategoryIndex, DoesMarketProductHaveEsoPlusPrice) }

                        for index, productData in ipairs(marketProductPresentations) do
                            local marketProduct = self.currentCategoryMarketProductPool:AcquireObject()
                            marketProduct:Show(productData)

                            if productData:IsLimitedTimeProduct() then
                                self:AddMarketProductEntryToLabeledGroupTable(self.limitedTimedOfferProducts, marketProduct)
                            elseif productData:IsFeatured() then
                                self:AddMarketProductEntryToLabeledGroupTable(self.featuredProducts, marketProduct)
                            else
                                self:AddMarketProductEntryToLabeledGroupTable(self:FindOrCreateCategoryLabeledGroupTable(categoryIndex, formattedBaseName), marketProduct)
                            end
                        end
                    end
                end
            end
        end

        self:SortMarketProductLabeledGroupTable(self.limitedTimedOfferProducts)
        self:SortMarketProductLabeledGroupTable(self.featuredProducts)

        local labeledGroupTables =
        {
            {name = GetString(SI_MARKET_ESO_PLUS_MEMBERSHIP_CATEGORY), marketProducts = esoPlusMembershipTiles},
            {name = GetString(SI_MARKET_LIMITED_TIME_OFFER_CATEGORY), marketProducts = self.limitedTimedOfferProducts},
            {name = GetString(SI_MARKET_FEATURED_CATEGORY), marketProducts = self.featuredProducts},
        }

        local sortedCategoryGroupTables = CreateSortedSubcategoryList(self.categoryLabeledGroupTableMap)
        for index, groupTableInfo in ipairs(sortedCategoryGroupTables) do
            local groupTable = groupTableInfo.groupTable
            self:SortMarketProductLabeledGroupTable(groupTable)
            table.insert(labeledGroupTables, {name = groupTableInfo.displayName, marketProducts = groupTable})
        end

        self:LayoutMarketProducts(labeledGroupTables)
    end
end

function GamepadMarket:LayoutMarketProducts(marketProductLabeledGroupTables)
    self:SetCurrentKeybinds(self.keybindStripDescriptors)

    self:PrepareGridForBuild(ZO_GAMEPAD_MARKET_INDIVIDUAL_PRODUCTS_PER_ROW, ZO_GAMEPAD_MARKET_INDIVIDUAL_PRODUCT_WIDTH, ZO_GAMEPAD_MARKET_INDIVIDUAL_PRODUCT_HEIGHT, ZO_GAMEPAD_MARKET_PRODUCT_PADDING)

    for i, labeledGroupTable in ipairs(marketProductLabeledGroupTables) do
        self:AddLabeledGroupTable(labeledGroupTable.name, labeledGroupTable.marketProducts)
    end

    self:FinishBuild()
end

function GamepadMarket:OnMarketOpen()
    if ZO_GAMEPAD_MARKET_LOCKED then -- This can be called before the lock screen has been initialized
        ZO_GAMEPAD_MARKET_LOCKED:OnMarketOpen()
    end

    if self.isInitialized then
        if not self.categoriesInitialized or self.refreshCategories then
            self:BuildCategories()
        else
            self:UpdateCurrentCategory()
        end

        self.isLockedForCategoryRefresh = true -- prevent double category initialization on first entry
        self:RefreshHeader()
        self:TrySelectLastPreviewedProduct()
        self.isLockedForCategoryRefresh = false
    end
end

function GamepadMarket:OnMarketLocked()
    if self.isInitialized then
        -- if the market locks while we are showing the Crown Store we want to switch to the locked screen
        if self.marketScene:IsShowing() then
            -- if we are in the base Crown Store we can just swap the current scene to the locked scene to preserve the stack
            SCENE_MANAGER:SwapCurrentScene(ZO_GAMEPAD_MARKET_LOCKED_SCENE_NAME)
        elseif GAMEPAD_MARKET_SCENE_GROUP:IsShowing() and not SCENE_MANAGER:IsShowing(ZO_GAMEPAD_MARKET_PURCHASE_SCENE_NAME) then
            -- otherwise if we are in another Crown Store scene then just show the lock screen since we don't
            -- know what's on the stack. Additionally, we won't interrupt the purchase dialog if that's showing.
            SCENE_MANAGER:Show(ZO_GAMEPAD_MARKET_LOCKED_SCENE_NAME)
        end
    end
end

-- If the Market is loading/updating switch to the pre-scene so we can show the loading info and then switch to the proper market state
function GamepadMarket:OnMarketLoading()
    if self.isInitialized and (self.marketScene:IsShowing() or ZO_GAMEPAD_MARKET_LOCKED_SCENE:IsShowing()) then
        SCENE_MANAGER:SwapCurrentScene(ZO_GAMEPAD_MARKET_PRE_SCENE_NAME)
    end
end

function GamepadMarket:OnMarketPurchaseResult()
    -- handled by GamepadMarketPurchaseManager
end

do
    local PURCHASE_MANAGER = ZO_GamepadMarketPurchaseManager:New() -- Singleton purchase manager
    local FROM_INGAME = true
    local FROM_CROWN_STORE = false
    function GamepadMarket:PurchaseMarketProduct(marketProductData)
        PURCHASE_MANAGER:BeginPurchase(marketProductData, FROM_INGAME)
    end

    function GamepadMarket:PurchaseMarketProductInternal(marketProductData, onPurchaseSuccessCallback, onPurchaseEndCallback)
        PURCHASE_MANAGER:BeginPurchase(marketProductData, FROM_CROWN_STORE, onPurchaseSuccessCallback, onPurchaseEndCallback)
    end

    function GamepadMarket:PurchaseFreeTrialMarketProductInternal(marketProductData, onPurchaseSuccessCallback, onPurchaseEndCallback)
        PURCHASE_MANAGER:BeginFreeTrialPurchase(marketProductData, FROM_CROWN_STORE, onPurchaseSuccessCallback, onPurchaseEndCallback)
    end

    function GamepadMarket:OnShowBuyCrownsDialog()
        PURCHASE_MANAGER:ShowBuyCrownsDialog(FROM_INGAME)
    end

    function GamepadMarket:OnShowBuyCrownsDialogInternal()
        PURCHASE_MANAGER:ShowBuyCrownsDialog(FROM_CROWN_STORE)
    end

    function GamepadMarket:GiftMarketProduct(marketProductData)
        PURCHASE_MANAGER:BeginGiftPurchase(marketProductData, FROM_INGAME)
    end

    function GamepadMarket:GiftMarketProductInternal(marketProductData, onPurchaseSuccessCallback, onPurchaseEndCallback)
        PURCHASE_MANAGER:BeginGiftPurchase(marketProductData, FROM_CROWN_STORE, onPurchaseSuccessCallback, onPurchaseEndCallback)
    end
end

do
    local DONT_ALLOW_IF_DISABLED = false
    local SCROLL_INSTANTLY = true
    function GamepadMarket:RequestShowCategory(categoryIndex, subcategoryIndex)
        if self.isInitialized and self.marketScene:IsShowing() and self.marketState == MARKET_STATE_OPEN then
            -- subcategories are displayed as part of the parent category, so for now we'll just show the whole category
            local categoryData = self:GetCategoryData(categoryIndex)

            if categoryData then
                local targetIndex = categoryData.tabIndex
                if self.header.tabBar:GetSelectedIndex() ~= targetIndex then
                    self:SetQueuedCategoryIndices(categoryIndex, subcategoryIndex)
                    self.header.tabBar:SetSelectedDataIndex(targetIndex, DONT_ALLOW_IF_DISABLED, SCROLL_INSTANTLY)
                else
                    self:ScrollToSubcategory(categoryIndex, subcategoryIndex, SCROLL_INSTANTLY)
                end
            end
        else
            self:SetQueuedCategoryIndices(categoryIndex, subcategoryIndex)
        end
    end
end

function GamepadMarket:RequestShowCategoryById(categoryId)
    if self.isInitialized and self.marketScene:IsShowing() and self.marketState == MARKET_STATE_OPEN then
        local categoryIndex, subcategoryIndex = GetCategoryIndicesFromMarketProductCategoryId(MARKET_DISPLAY_GROUP_CROWN_STORE, categoryId)
        self:RequestShowCategory(categoryIndex, subcategoryIndex)
        self:ClearQueuedCategoryId()
    else
        self:SetQueuedCategoryId(categoryId)
    end
end

function GamepadMarket:ShowBundleContents(bundleMarketProduct)
    self:Deactivate()
    self.isLockedForCategoryRefresh = true
    ZO_GAMEPAD_MARKET_BUNDLE_CONTENTS:SetBundle(bundleMarketProduct:GetMarketProductData())
    SCENE_MANAGER:Push(ZO_GAMEPAD_MARKET_BUNDLE_CONTENTS_SCENE_NAME)
end

function GamepadMarket:ShowMarketProductContentsAsList(marketProduct, previewType)
    self:Deactivate()
    self.isLockedForCategoryRefresh = true
    SCENE_MANAGER:Push(ZO_GAMEPAD_MARKET_CONTENT_LIST_SCENE_NAME)
    ZO_GAMEPAD_MARKET_PRODUCT_LIST:SetMarketProduct(marketProduct:GetId(), previewType)
end

function GamepadMarket:ShowHousePreviewDialog(marketProduct)
    local mainTextParams = { mainTextParams = ZO_MarketDialogs_Shared_GetPreviewHouseDialogMainTextParams(marketProduct:GetId()) }
    ZO_Dialogs_ShowGamepadDialog("CROWN_STORE_PREVIEW_HOUSE", { marketProductData = marketProduct:GetMarketProductData() }, mainTextParams)
end

function GamepadMarket:OnTutorialShowing()
    g_activeMarketScreen:RemoveKeybinds()
    g_activeMarketScreen:Deactivate()
end

function GamepadMarket:OnTutorialHidden()
    g_activeMarketScreen:Activate()
    g_activeMarketScreen:AddKeybinds()
end

function GamepadMarket:RestoreActionLayerForTutorial()
    PushActionLayerByName(GetString(SI_KEYBINDINGS_LAYER_GENERAL))
end

function GamepadMarket:RemoveActionLayerForTutorial()
    -- we exit the gamepad tutotial by pressing "A"
    RemoveActionLayerByName(GetString(SI_KEYBINDINGS_LAYER_GENERAL))
end

function GamepadMarket:ClearProducts()
    ZO_GamepadMarket_GridScreen.ClearProducts(self)
    self:ReleaseAllProducts()
    self.selectedGridEntry = nil
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptors)
end

function GamepadMarket:GetMarketProductFromCurrentCategoryById(productId)
    for index, entry in ipairs(self.gridEntries) do
        if entry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT and entry:GetId() == productId then
            return entry
        end
    end
end

function GamepadMarket:GetFirstMarketProductInSubcategoryFromCurrentCategory(categoryIndex, subcategoryIndex)
    for index, entry in ipairs(self.gridEntries) do
        if entry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
            local productData = entry:GetMarketProductData()
            local productCategoryIndex, productSubcategoryIndex = productData:GetCategoryIndicesFromPresentation()
            if productCategoryIndex == categoryIndex and productSubcategoryIndex == subcategoryIndex then
                return entry
            end
        end
    end
end

function GamepadMarket:RequestShowMarketProduct(marketProductId)
    if self.isInitialized and self.marketScene:IsShowing() and self.marketState == MARKET_STATE_OPEN then
        self:ShowMarketProduct(marketProductId)
    else
        self:SetQueuedMarketProductId(marketProductId)
    end
end

do
    local DONT_ALLOW_IF_DISABLED = false
    local SCROLL_INSTANTLY = true
    function GamepadMarket:ShowMarketProduct(marketProductId)
        local data = self:GetCategoryDataForMarketProduct(marketProductId)
        if data then
            -- check if we are already showing the correct category for the market product
            -- if we aren't, we need to select it before we can scroll to the product
            local targetIndex = data.tabIndex
            if self.header.tabBar:GetSelectedIndex() ~= targetIndex then
                self.header.tabBar:SetSelectedDataIndex(targetIndex, DONT_ALLOW_IF_DISABLED, SCROLL_INSTANTLY)
            else
                self:ScrollToMarketProduct(marketProductId, SCROLL_INSTANTLY)
            end
        end
    end
end

function GamepadMarket:ScrollToMarketProductEntry(marketProduct, scrollInstantly)
    if self.showScrollbar then
        self:ScrollToGridEntry(marketProduct:GetFocusData(), scrollInstantly)
    end
    local listIndex = marketProduct:GetListIndex()
    self.focusList:SetFocusByIndex(listIndex)
end

function GamepadMarket:ScrollToMarketProduct(marketProductId, scrollInstantly)
    local targetMarketProduct = self:GetMarketProductFromCurrentCategoryById(marketProductId)
    if targetMarketProduct then
        self:ScrollToMarketProductEntry(targetMarketProduct, scrollInstantly)
        self:ClearQueuedMarketProductId()
    end
end

function GamepadMarket:ScrollToSubcategory(categoryIndex, subcategoryIndex, scrollInstantly)
    local targetMarketProduct = self:GetFirstMarketProductInSubcategoryFromCurrentCategory(categoryIndex, subcategoryIndex)
    if targetMarketProduct then
        self:ScrollToMarketProductEntry(targetMarketProduct, scrollInstantly)
        self:ClearQueuedCategoryIndices()
    end
end

function GamepadMarket:GetCategoryData(categoryIndex)
    local normalizedCategoryIndex
    if categoryIndex > 0 then
       normalizedCategoryIndex = categoryIndex + self.categoryIndexOffset
    elseif categoryIndex == ZO_MARKET_ESO_PLUS_CATEGORY_INDEX then
        normalizedCategoryIndex = self.esoPlusCategoryIndex
    elseif categoryIndex == ZO_MARKET_FEATURED_CATEGORY_INDEX then
        normalizedCategoryIndex = self.featuredCategoryIndex
    end
    if normalizedCategoryIndex then
        local categoryTable = self.headerData.tabBarEntries[normalizedCategoryIndex]
        if categoryTable ~= nil then
            return categoryTable.categoryData
        end
    end
end

function GamepadMarket:RefreshEsoPlusPage()
    self:RefreshProducts()
end

-- overrides from ZO_Market_Shared

function GamepadMarket:AddKeybinds()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.currentKeybindDescriptor)
end

function GamepadMarket:RemoveKeybinds()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currentKeybindDescriptor)
end

function GamepadMarket:RefreshKeybinds()
    ZO_GamepadMarketKeybindStrip_RefreshStyle()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.currentKeybindDescriptor)
end

-- copy the standard gamepad style but change the center and right offsets
ZO_GAMEPAD_KEYBIND_STRIP_MARKET_GAMEPAD_STYLE = ZO_ShallowTableCopy(KEYBIND_STRIP_GAMEPAD_STYLE)
ZO_GAMEPAD_KEYBIND_STRIP_MARKET_GAMEPAD_STYLE.centerAnchorOffset = -230

function ZO_GamepadMarketKeybindStrip_RefreshStyle()
    local currencyStyle = MARKET_CURRENCY_GAMEPAD:ModifyKeybindStripStyleForCurrency(ZO_GAMEPAD_KEYBIND_STRIP_MARKET_GAMEPAD_STYLE)
    KEYBIND_STRIP:SetStyle(currencyStyle)
end

--
--[[ Gamepad Market Bundle Contents ]]--
--

local GamepadMarketBundleContents = ZO_GamepadMarket_GridScreen:Subclass()

function GamepadMarketBundleContents:New(...)
    local bundleContents = ZO_Object.New(self)
    bundleContents:Initialize(...)
    return bundleContents
end

function GamepadMarketBundleContents:Initialize(control)
    ZO_GamepadMarket_GridScreen.Initialize(self, control)

    self:InitializeMarketProductPool()

    GAMEPAD_MARKET_BUNDLE_CONTENTS_SCENE = ZO_RemoteScene:New(ZO_GAMEPAD_MARKET_BUNDLE_CONTENTS_SCENE_NAME, SCENE_MANAGER)
    GAMEPAD_MARKET_BUNDLE_CONTENTS_SCENE:RegisterCallback("StateChange", function(...) self:OnStateChanged(...) end)
end

function GamepadMarketBundleContents:InitializeMarketProductPool()
    local function ResetMarketProduct(marketProduct)
        marketProduct:Reset()
    end

    local BUNDLE_ATTACHMENT_NAME = self.control:GetName() .. ZO_GAMEPAD_MARKET_PRODUCT_BUNDLE_ATTACHMENT_TEMPLATE
    local function CreateMarketBundleAttachment(objectPool)
        return ZO_GamepadMarketProductBundleAttachment:New(objectPool:GetNextControlId(), self.currentCategoryControl, BUNDLE_ATTACHMENT_NAME)
    end

    self.marketBundleAttachmentPool = ZO_ObjectPool:New(CreateMarketBundleAttachment, ResetMarketProduct)

    local function ResetBlankTile(blankTile)
        blankTile:Reset()
    end

    local BLANK_TILE_NAME = self.control:GetName() .. ZO_GAMEPAD_MARKET_BLANK_TILE_TEMPLATE
    local function CreateBlankTile(objectPool)
        local control = CreateControlFromVirtual(BLANK_TILE_NAME, self.currentCategoryControl, ZO_GAMEPAD_MARKET_BLANK_TILE_TEMPLATE, objectPool:GetNextControlId())
        return ZO_GamepadMarketBlankTile:New(control)
    end

     self.blankTilePool = ZO_ObjectPool:New(CreateBlankTile, ResetBlankTile)
end

function GamepadMarketBundleContents:FinishRowWithBlankTiles()
    local currentItemRowIndex = #self.gridEntries % self.itemsPerRow

    if currentItemRowIndex > 0 then
        for i = currentItemRowIndex, self.itemsPerRow - 1 do
            local blankTile = self.blankTilePool:AcquireObject()
            blankTile:Show()
            self:AddEntry(blankTile, blankTile:GetControl())
        end
    end
end

function GamepadMarketBundleContents:OnStateChanged(oldState, newState)
    if newState == SCENE_SHOWING then
        self:OnShowing()
    elseif newState == SCENE_SHOWN then
        self:OnShown()
    elseif newState == SCENE_HIDING then
        self:OnHiding()
    end
end

function GamepadMarketBundleContents:PerformDeferredInitialization()
    if not self.isInitialized then
        self.titleControl = self.header:GetNamedChild("TitleContainerTitle")

        local function RefreshOnPurchase()
            self:RefreshProducts()
        end

        local function QueueTutorial(_, purchasedConsumables, triggerTutorialOnPurchase)
            if purchasedConsumables then
                self:SetQueuedTutorial(TUTORIAL_TRIGGER_CROWN_CONSUMABLE_PURCHASED)
            end

            if triggerTutorialOnPurchase then
                self:SetQueuedTutorial(triggerTutorialOnPurchase)
            end
        end

        self.keybindStripDescriptors =
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            -- Purchase Keybind
            {
                name = GetString(SI_MARKET_PURCHASE_BUNDLE_KEYBIND_TEXT),
                keybind = "UI_SHORTCUT_PRIMARY",
                visible = function()
                    return not self.marketProductData:IsPurchaseLocked()
                end,
                enabled = function() return not self:HasQueuedTutorial() end,
                callback = function()
                    self.prePurchaseSelectedIndex = self.focusList:GetSelectedIndex()
                    ZO_GAMEPAD_MARKET:PurchaseMarketProductInternal(self.marketProductData, RefreshOnPurchase, QueueTutorial)
                end,
            },
            -- Gift Keybind
            {
                 name = GetString(SI_MARKET_GIFT_BUNDLE_KEYBIND_TEXT),
                keybind = "UI_SHORTCUT_RIGHT_STICK",
                visible = function()
                                return self.marketProductData:IsGiftable()
                            end,
                enabled = function() return not self:HasQueuedTutorial() end,
                callback = function()
                    self.prePurchaseSelectedIndex = self.focusList:GetSelectedIndex()
                    ZO_GAMEPAD_MARKET:GiftMarketProductInternal(self.marketProductData, RefreshOnPurchase, QueueTutorial)
                end,
            },
            -- Preview keybind
            {
                name =  GetString(SI_MARKET_PREVIEW_KEYBIND_TEXT),
                keybind = "UI_SHORTCUT_SECONDARY",
                visible = function()
                    if self.selectedGridEntry then
                        return self.selectedGridEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT
                    end
                    return false
                end,
                enabled = function()
                    local selectedEntry = self.selectedGridEntry
                    if selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                        local previewType = selectedEntry:GetMarketProductPreviewType()
                        if previewType == ZO_MARKET_PREVIEW_TYPE_PREVIEWABLE then
                            return selectedEntry:HasPreview() and IsCharacterPreviewingAvailable()
                        elseif previewType == ZO_MARKET_PREVIEW_TYPE_HOUSE then
                            return CanJumpToHouseFromCurrentLocation(), GetString(SI_MARKET_PREVIEW_ERROR_CANNOT_JUMP_FROM_LOCATION)
                        end
                    end
        
                    return false
                end,
                callback = function()
                    local selectedEntry = self.selectedGridEntry
                    if selectedEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
                        local previewType = selectedEntry:GetMarketProductPreviewType()
                        if previewType == ZO_MARKET_PREVIEW_TYPE_HOUSE then
                            self:ShowHousePreviewDialog(selectedEntry)
                        elseif previewType == ZO_MARKET_PREVIEW_TYPE_PREVIEWABLE then
                            self:BeginPreview()
                        end
                    end
                end,
            },
            MARKET_BUY_CROWNS_BUTTON,
            KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor()
        }

        self.isInitialized = true
    end
end

function GamepadMarketBundleContents:SetBundle(marketProductData)
    self.marketProductData = marketProductData
    self.headerData.titleText = zo_strformat(SI_MARKET_PRODUCT_NAME_FORMATTER, marketProductData:GetDisplayName())
    self.prePurchaseSelectedIndex = nil
end

function GamepadMarketBundleContents:LayoutBundleProducts()
    self:ClearProducts()
    self:PrepareGridForBuild(ZO_GAMEPAD_MARKET_INDIVIDUAL_PRODUCTS_PER_ROW, ZO_GAMEPAD_MARKET_INDIVIDUAL_PRODUCT_WIDTH, ZO_GAMEPAD_MARKET_INDIVIDUAL_PRODUCT_HEIGHT, ZO_GAMEPAD_MARKET_PRODUCT_PADDING)

    local numChildren = self.marketProductData:GetNumChildren()
    if numChildren > 0 then
        local childTiles = {}
        for childIndex = 1, numChildren do
            local childMarketProductId = self.marketProductData:GetChildMarketProductId(childIndex)
            local productData = ZO_MarketProductData:New(childMarketProductId, ZO_INVALID_PRESENTATION_INDEX)
            local displayName = productData:GetDisplayName()

            local marketProduct = self.marketBundleAttachmentPool:AcquireObject()
            marketProduct:SetBundleMarketProductId(self.marketProductData:GetId())
            marketProduct:Show(productData)
            table.insert(childTiles, {displayName = displayName, marketProduct = marketProduct})
        end

        -- Sort the child tiles alphabetically
        table.sort(childTiles, function(a,b)
                                        return a.displayName < b.displayName
                                    end)

        for i = 1, #childTiles do
            local marketProduct = childTiles[i].marketProduct
            self:AddEntry(marketProduct, marketProduct:GetControl())
        end
    end

    self:FinishRowWithBlankTiles()
    self:FinishBuild()
end

function GamepadMarketBundleContents:OnShowing()
    self:PerformDeferredInitialization()
    self:LayoutBundleProducts()
    self.titleControl:SetText(self.headerData.titleText)
    self:AddKeybinds()
    self:Activate()
    if self.prePurchaseSelectedIndex then
        self.focusList:SetFocusByIndex(self.prePurchaseSelectedIndex)
        self.prePurchaseSelectedIndex = nil
    end
    self:TrySelectLastPreviewedProduct()
end

function GamepadMarketBundleContents:OnShown()
    g_activeMarketScreen = ZO_GAMEPAD_MARKET_BUNDLE_CONTENTS
    ZO_GamepadMarket_GridScreen.OnShown(self)
    self:RefreshKeybinds()
end

function GamepadMarketBundleContents:OnHiding()
    self:RemoveKeybinds()
    self:Deactivate()
    self:ClearLastPreviewedMarketProductId()
end

function GamepadMarketBundleContents:LayoutSelectedGridEntryTooltip()
    if self.selectedGridEntry ~= nil and self.selectedGridEntry:GetEntryType() == ZO_GAMEPAD_MARKET_ENTRY_MARKET_PRODUCT then
        self.selectedGridEntry:LayoutTooltip(GAMEPAD_RIGHT_TOOLTIP)
    else
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
    end
end

function GamepadMarketBundleContents:OnSelectionChanged(selectedData)
    ZO_GamepadMarket_GridScreen.OnSelectionChanged(self, selectedData)
    local previouslySelectedEntry = self.selectedGridEntry
    if selectedData then
        self.selectedGridEntry = selectedData.object
        self:LayoutSelectedGridEntryTooltip()
    else
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        self.selectedGridEntry = nil
    end

    self:UpdatePreviousAndNewlySelectedProducts(previouslySelectedEntry, self.selectedGridEntry)
    self:RefreshKeybinds()
end

function GamepadMarketBundleContents:ReleaseAllProducts()
    self.marketBundleAttachmentPool:ReleaseAllObjects()
    self.blankTilePool:ReleaseAllObjects()
end

function GamepadMarketBundleContents:ClearProducts()
    ZO_GamepadMarket_GridScreen.ClearProducts(self)
    self:ReleaseAllProducts()
end

function GamepadMarketBundleContents:AddKeybinds()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptors)
end

function GamepadMarketBundleContents:RemoveKeybinds()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptors)
end

function GamepadMarketBundleContents:RefreshKeybinds()
    ZO_GamepadMarketKeybindStrip_RefreshStyle()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptors)
end

function GamepadMarketBundleContents:ShowHousePreviewDialog(marketProduct)
    local mainTextParams = { mainTextParams = ZO_MarketDialogs_Shared_GetPreviewHouseDialogMainTextParams(marketProduct:GetId()) }
    ZO_Dialogs_ShowGamepadDialog("CROWN_STORE_PREVIEW_HOUSE", { marketProductData = marketProduct:GetMarketProductData() }, mainTextParams)
end

-- override from ZO_GamepadMarket_GridScreen
function GamepadMarketBundleContents:FinishBuild()
    ZO_GamepadMarket_GridScreen.FinishBuild(self)
    self:RefreshKeybinds()
end

-- override from ZO_GamepadMarket_GridScreen
function GamepadMarketBundleContents:EndCurrentPreview()
    ZO_GamepadMarket_GridScreen.EndCurrentPreview(self)
    self:RefreshKeybinds()
end

-- MarketClasses_Shared expects us to have this function (because Market_Shared does)
function GamepadMarketBundleContents:RefreshActions()
    self:RefreshKeybinds()
end

--
-- [[ Market Locked Screen ]]--
--

local GamepadMarketLockedScreen = ZO_Object:New()

function GamepadMarketLockedScreen:New(...)
    local locked = ZO_Object.New(self)
    locked:Initialize(...)
    return locked
end

function GamepadMarketLockedScreen:Initialize(control)
    control.owner = self
    self.control = control

    self.keybindStripDescriptors =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor()
    }

    ZO_GAMEPAD_MARKET_LOCKED_SCENE = ZO_RemoteScene:New(ZO_GAMEPAD_MARKET_LOCKED_SCENE_NAME, SCENE_MANAGER)
    ZO_GAMEPAD_MARKET_LOCKED_SCENE:RegisterCallback("StateChange", function(...) self:OnStateChanged(...) end)
end

function GamepadMarketLockedScreen:OnStateChanged(oldState, newState)
    if newState == SCENE_SHOWN then
        if GetMarketState(MARKET_DISPLAY_GROUP_CROWN_STORE) == MARKET_STATE_OPEN then
            self:OnMarketOpen()
        else
            ZO_GamepadMarketKeybindStrip_RefreshStyle()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptors)
        end
    elseif newState == SCENE_HIDDEN then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptors)
        KEYBIND_STRIP:SetStyle(KEYBIND_STRIP_STANDARD_STYLE)
    end
end

function GamepadMarketLockedScreen:OnMarketOpen()
    if ZO_GAMEPAD_MARKET_LOCKED_SCENE:IsShowing() then
        SCENE_MANAGER:SwapCurrentScene(ZO_GAMEPAD_MARKET_SCENE_NAME)
    end
end

--
-- [[ Market Pre Scene ]]--
--

local GamepadMarketPreScene = ZO_Object:New()

function GamepadMarketPreScene:New(...)
    local preScene = ZO_Object.New(self)
    preScene:Initialize(...)
    return preScene
end

function GamepadMarketPreScene:Initialize(control)
    self.control = control

    self.keybindStripDescriptors =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor()
    }

    ZO_GAMEPAD_MARKET_PRE_SCENE = ZO_RemoteScene:New(ZO_GAMEPAD_MARKET_PRE_SCENE_NAME, SCENE_MANAGER)
    ZO_GAMEPAD_MARKET_PRE_SCENE:RegisterCallback("StateChange", function(...) self:OnStateChanged(...) end)
end

function GamepadMarketPreScene:OnStateChanged(oldState, newState)
    if newState == SCENE_SHOWN then
        self:OnShown()
    elseif newState == SCENE_HIDING then
        self:OnHiding()
    end
end

function GamepadMarketPreScene:OnShown()
    self.marketState = GetMarketState(MARKET_DISPLAY_GROUP_CROWN_STORE)
    self.loadingStartTime = nil
    EVENT_MANAGER:RegisterForEvent(ZO_GAMEPAD_MARKET_PRE_SCENE_NAME, EVENT_MARKET_STATE_UPDATED, function(eventId, ...) self:OnMarketStateUpdated(...) end)
    EVENT_MANAGER:RegisterForUpdate(ZO_GAMEPAD_MARKET_PRE_SCENE_NAME, 0, function(...) self:OnUpdate(...) end)
    ZO_MARKET_MANAGER:RequestOpenMarket()
    SetSecureRenderModeEnabled(true)

    self:TrySwapToMarketScene()
end

function GamepadMarketPreScene:OnHiding()
    SetSecureRenderModeEnabled(false)
    EVENT_MANAGER:UnregisterForUpdate(ZO_GAMEPAD_MARKET_PRE_SCENE_NAME)
    EVENT_MANAGER:UnregisterForEvent(ZO_GAMEPAD_MARKET_PRE_SCENE_NAME, EVENT_MARKET_STATE_UPDATED)
    ZO_GAMEPAD_MARKET_PRE_SCENE:RemoveFragment(GAMEPAD_MARKET_PRE_SCENE_FRAGMENT)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptors)
end

function GamepadMarketPreScene:OnMarketStateUpdated(displayGroup, marketState)
    if displayGroup == MARKET_DISPLAY_GROUP_CROWN_STORE then
        self.marketState = marketState
        self:TrySwapToMarketScene()
    end
end

function GamepadMarketPreScene:OnUpdate(currentMs)
    if self.loadingStartTime == nil then
        self.loadingStartTime = currentMs
    end

    if currentMs - self.loadingStartTime >= ZO_MARKET_DISPLAY_LOADING_DELAY_MS then
        -- show the loading text
        ZO_GAMEPAD_MARKET_PRE_SCENE:AddFragment(GAMEPAD_MARKET_PRE_SCENE_FRAGMENT)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptors)
    end
end

function GamepadMarketPreScene:TrySwapToMarketScene()
    if ZO_GAMEPAD_MARKET_PRE_SCENE:IsShowing() then
        if self.marketState == MARKET_STATE_OPEN then
            SCENE_MANAGER:SwapCurrentScene(ZO_GAMEPAD_MARKET_SCENE_NAME)
        elseif self.marketState == MARKET_STATE_LOCKED then
            SCENE_MANAGER:SwapCurrentScene(ZO_GAMEPAD_MARKET_LOCKED_SCENE_NAME)
        end
    end
end

--
--[[ XML Handlers ]]--
--
function ZO_Market_Gamepad_OnInitialize(control)
    ZO_GAMEPAD_MARKET = GamepadMarket:New(control)
    SYSTEMS:RegisterGamepadObject(ZO_MARKET_NAME, ZO_GAMEPAD_MARKET)
end

function ZO_GamepadMarket_BundleContents_OnInitialize(control)
    ZO_GAMEPAD_MARKET_BUNDLE_CONTENTS = GamepadMarketBundleContents:New(control)
end

function ZO_GamepadMarket_Locked_OnInitialize(control)
    ZO_GAMEPAD_MARKET_LOCKED = GamepadMarketLockedScreen:New(control)
end

function ZO_GamepadMarket_PreScene_OnInitialize(control)
    ZO_MARKET_PRE_SCENE = GamepadMarketPreScene:New(control)
end
