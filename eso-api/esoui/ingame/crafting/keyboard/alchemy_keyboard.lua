ZO_Alchemy = ZO_SharedAlchemy:Subclass()

function ZO_Alchemy:New(...)
    return ZO_SharedAlchemy.New(self, ...)
end

function ZO_Alchemy:Initialize(control)
    self.control = control
    self.sceneName = "alchemy"

    ZO_SharedAlchemy.Initialize(self, control)

    self:InitializeKeybindStripDescriptors()
    self:InitializeModeBar()
end

function ZO_Alchemy:InitializeInventory()
    self.inventory = ZO_AlchemyInventory:New(self, self.control:GetNamedChild("Inventory"))
end

function ZO_Alchemy:InitializeTooltip()
    self.tooltip = self.control:GetNamedChild("Tooltip")
    if IsChatSystemAvailableForCurrentPlatform() then
        local function OnTooltipMouseUp(control, button, upInside)
            if upInside and button == 2 then
                local link = ZO_LinkHandler_CreateChatLink(GetAlchemyResultingItemLink, self:GetAllCraftingBagAndSlots())
                if link ~= "" then
                    ClearMenu()

                    local function AddLink()
                        ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, link))
                    end

                    AddMenuItem(GetString(SI_ITEM_ACTION_LINK_TO_CHAT), AddLink)

                    ShowMenu(self)
                end
            end
        end

        self.tooltip:SetHandler("OnMouseUp", OnTooltipMouseUp)
        self.tooltip:GetNamedChild("Icon"):SetHandler("OnMouseUp", OnTooltipMouseUp)
    end
end

function ZO_Alchemy:InitializeScenes()
    ALCHEMY_SCENE = self:CreateInteractScene(self.sceneName)
    ALCHEMY_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)

            TriggerTutorial(TUTORIAL_TRIGGER_ALCHEMY_OPENED)
            self.inventory:SetActiveFilterByDescriptor(nil)

            -- Reselect so we re-add the temporary fragment for the recipe mode
            -- and setup/update the tooltip and corresponding sounds correctly
            local oldMode = self.mode
            self.mode = nil
            ZO_MenuBar_ClearSelection(self.modeBar)
            if not oldMode then
                ZO_MenuBar_SelectDescriptor(self.modeBar, ZO_ALCHEMY_MODE_CREATION)
            else
                ZO_MenuBar_SelectDescriptor(self.modeBar, oldMode)
            end
        elseif newState == SCENE_HIDDEN then
            ZO_InventorySlot_RemoveMouseOverKeybinds()
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)

            self.inventory:HandleDirtyEvent()

            CRAFTING_RESULTS:SetCraftingTooltip(nil)
        end
    end)

    self.control:RegisterForEvent(EVENT_TRAIT_LEARNED, function()
        if SYSTEMS:IsShowing("alchemy") then
            self:OnSlotChanged()
        end
    end)
end

function ZO_Alchemy:InitializeModeBar()
    local function CreateButtonData(name, mode, normal, pressed, highlight, disabled)
        return {
            activeTabText = name,
            categoryName = name,

            descriptor = mode,
            normal = normal,
            pressed = pressed,
            highlight = highlight,
            disabled = disabled,
            callback = function(tabData)
                self.modeBarLabel:SetText(GetString(name))
                self:SetMode(mode)
            end,
        }
    end

    self.modeBar = self.control:GetNamedChild("ModeMenuBar")
    self.modeBarLabel = self.modeBar:GetNamedChild("Label")

    local creationTab = CreateButtonData(
        SI_ALCHEMY_CREATION,
        ZO_ALCHEMY_MODE_CREATION,
        "EsoUI/Art/Crafting/smithing_tabIcon_creation_up.dds",
        "EsoUI/Art/Crafting/smithing_tabIcon_creation_down.dds",
        "EsoUI/Art/Crafting/smithing_tabIcon_creation_over.dds",
        "EsoUI/Art/Crafting/smithing_tabIcon_creation_disabled.dds"
    )

    ZO_MenuBar_AddButton(self.modeBar, creationTab)

    local recipeCraftingSystem = GetTradeskillRecipeCraftingSystem(CRAFTING_TYPE_ALCHEMY)
    local recipeCraftingSystemNameStringId = _G["SI_RECIPECRAFTINGSYSTEM"..recipeCraftingSystem]
    local recipeTab = CreateButtonData(
        recipeCraftingSystemNameStringId,
        ZO_ALCHEMY_MODE_RECIPES,
        GetKeyboardRecipeCraftingSystemButtonTextures(recipeCraftingSystem))

    ZO_MenuBar_AddButton(self.modeBar, recipeTab)

    ZO_CraftingUtils_ConnectMenuBarToCraftingProcess(self.modeBar)

    ZO_MenuBar_SelectDescriptor(self.modeBar, ZO_ALCHEMY_MODE_CREATION)
end

function ZO_Alchemy:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor =
    {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,

        -- Perform craft
        {
            name = function()
                local cost = GetCostToCraftAlchemyItem(self.solventSlot:GetBagAndSlot())
                return ZO_CraftingUtils_GetCostToCraftString(cost)
            end,
            keybind = "UI_SHORTCUT_SECONDARY",

            callback = function()
                ZO_KeyboardCraftingUtils_RequestCraftingCreate(self, self:GetMultiCraftNumIterations())
            end,

            enabled = function()
                return self:ShouldCraftButtonBeEnabled()
            end,
        },

        -- Clear selections
        {
            name = GetString(SI_CRAFTING_CLEAR_SELECTIONS),
            keybind = "UI_SHORTCUT_NEGATIVE",

            callback = function() self:ClearSelections() end,

            visible = function() return not ZO_CraftingUtils_IsPerformingCraftProcess() and self:HasSelections() end,
        },
    }

    ZO_CraftingUtils_ConnectKeybindButtonGroupToCraftingProcess(self.keybindStripDescriptor)
end

function ZO_Alchemy:InitializeSlots()
    local slotContainer = self.control:GetNamedChild("SlotContainer")
    self.solventSlot = ZO_AlchemySlot:New(self, slotContainer:GetNamedChild("SolventSlot"), "EsoUI/Art/Crafting/alchemy_emptySlot_solvent.dds", SOUNDS.ALCHEMY_SOLVENT_PLACED, SOUNDS.ALCHEMY_SOLVENT_REMOVED, nil, self.inventory)
    self.solventSlot:RegisterCallback("ItemsChanged", function()
        self:OnSlotChanged()
    end)
    self.solventSlot:RegisterCallback("ItemSlotted", function(bagId, slotIndex)
        self:OnSolventSlotted(bagId, slotIndex)
    end)

    local REAGENT_TEXTURE = "EsoUI/Art/Crafting/alchemy_emptySlot_reagent.dds"
    local ALWAYS_USABLE = nil
    self.reagentSlots = {
        ZO_AlchemySlot:New(self, slotContainer:GetNamedChild("ReagentSlot1"), REAGENT_TEXTURE, SOUNDS.ALCHEMY_REAGENT_PLACED, SOUNDS.ALCHEMY_REAGENT_REMOVED, ALWAYS_USABLE, self.inventory),
        ZO_AlchemySlot:New(self, slotContainer:GetNamedChild("ReagentSlot2"), REAGENT_TEXTURE, SOUNDS.ALCHEMY_REAGENT_PLACED, SOUNDS.ALCHEMY_REAGENT_REMOVED, ALWAYS_USABLE, self.inventory),
        ZO_AlchemySlot:New(self, slotContainer:GetNamedChild("ReagentSlot3"), REAGENT_TEXTURE, SOUNDS.ALCHEMY_REAGENT_PLACED, SOUNDS.ALCHEMY_REAGENT_REMOVED, ZO_Alchemy_IsThirdAlchemySlotUnlocked, self.inventory),
    }
    for _, slot in pairs(self.reagentSlots) do
        slot:RegisterCallback("ItemsChanged", function()
            self:OnSlotChanged()
            self:UpdateReagentTraits()
        end)
    end

    self.multiCraftSpinner = ZO_MultiCraftSpinner:New(slotContainer:GetNamedChild("Spinner"))
    ZO_CraftingUtils_ConnectSpinnerToCraftingProcess(self.multiCraftSpinner)

    self.slotAnimation = ZO_CraftingCreateSlotAnimation:New(self.sceneName)

    self.control:RegisterForEvent(EVENT_NON_COMBAT_BONUS_CHANGED, function(eventCode, nonCombatBonusType)
        if nonCombatBonusType == NON_COMBAT_BONUS_ALCHEMY_THIRD_SLOT then
            self:UpdateThirdAlchemySlot()
        elseif nonCombatBonusType == NON_COMBAT_BONUS_ALCHEMY_LEVEL then
            self.inventory:HandleDirtyEvent()
        end
    end)

    self:UpdateThirdAlchemySlot()
end

function ZO_Alchemy:UpdateTooltip()
    -- if we are in recipe mode then we shouldn't show the alchemy tooltip
    if self:IsCraftable() and self.mode ~= ZO_ALCHEMY_MODE_RECIPES then
        self.tooltip:SetHidden(false)
        self.tooltip:ClearLines()
        self.tooltip:SetPendingAlchemyItem(self:GetAllCraftingBagAndSlots())
    else
        self.tooltip:SetHidden(true)
    end
end

function ZO_Alchemy:UpdateThirdAlchemySlot()
    local SUPPRESS_SOUND = true
    local IGNORE_REQUIREMENTS = true
    self:ClearSelections(SUPPRESS_SOUND, IGNORE_REQUIREMENTS)

    local slotContainer = self.control:GetNamedChild("SlotContainer")
    local reagentsLabel = slotContainer:GetNamedChild("ReagentsLabel")
    local reagentSlot3Unlocked = ZO_Alchemy_IsThirdAlchemySlotUnlocked()

    self.slotAnimation:Clear()
    for i, slot in ipairs(self.reagentSlots) do
        slot:GetControl():ClearAnchors()
    end

    local reagentSlot1 = self.reagentSlots[1]
    local reagentSlot2 = self.reagentSlots[2]
    local reagentSlot3 = self.reagentSlots[3]

    local reagentSlotControl1 = reagentSlot1:GetControl()
    local reagentSlotControl2 = reagentSlot2:GetControl()
    local reagentSlotControl3 = reagentSlot3:GetControl()

    self.slotAnimation:AddSlot(self.solventSlot)
    self.slotAnimation:AddSlot(reagentSlot1)
    self.slotAnimation:AddSlot(reagentSlot2)

    local SLOT_OFFSET_X = 20
    local SLOT_OFFSET_Y = 20
    if reagentSlot3Unlocked then
        reagentSlotControl1:SetAnchor(RIGHT, reagentSlotControl2, LEFT, -SLOT_OFFSET_X, 0)
        reagentSlotControl2:SetAnchor(TOP, reagentsLabel, BOTTOM, 0, SLOT_OFFSET_Y)
        reagentSlotControl3:SetAnchor(LEFT, reagentSlotControl2, RIGHT, SLOT_OFFSET_X, 0)

        self.slotAnimation:AddSlot(reagentSlot3)
    else
        reagentSlotControl1:SetAnchor(TOPRIGHT, reagentsLabel, BOTTOM, -SLOT_OFFSET_X, SLOT_OFFSET_Y)
        reagentSlotControl2:SetAnchor(TOPLEFT, reagentsLabel, BOTTOM, SLOT_OFFSET_X, SLOT_OFFSET_Y)
    end
end

function ZO_Alchemy:ResetSelectedTab()
    self:ClearSelections()
    self.mode = nil
end

function ZO_Alchemy:UpdateMultiCraft()
    self.multiCraftSpinner:SetMinMax(1, self:GetMultiCraftMaxIterations())
    self.multiCraftSpinner:UpdateButtons()
end

function ZO_Alchemy:GetMultiCraftNumIterations()
    return self.multiCraftSpinner:GetValue()
end

function ZO_Alchemy:ResetMultiCraftNumIterations()
    return self.multiCraftSpinner:SetValue(1)
end

function ZO_Alchemy:OnItemReceiveDrag(slotControl, bagId, slotIndex)
    local usedInCraftingType, craftingSubItemType, rankRequirement = GetItemCraftingInfo(bagId, slotIndex)
    if usedInCraftingType == CRAFTING_TYPE_ALCHEMY then
        if self.solventSlot:IsSlotControl(slotControl) then
            if IsAlchemySolvent(craftingSubItemType) and rankRequirement <= GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_LEVEL) then
                if not self.solventSlot:IsItemId(GetItemInstanceId(bagId, slotIndex)) then
                    self:SetSolventItem(bagId, slotIndex)
                end
            end
        elseif craftingSubItemType == ITEMTYPE_REAGENT then
            local reagentSlotIndex = self:FindReagentSlotIndexBySlotControl(slotControl)
            local existingReagentSlotIndex = self:FindAlreadySlottedReagent(bagId, slotIndex)
            if existingReagentSlotIndex then
                if reagentSlotIndex == existingReagentSlotIndex then
                    return
                end
                self:SetReagentItem(existingReagentSlotIndex, nil)
            end

            self:SetReagentItem(reagentSlotIndex, bagId, slotIndex)
        end
    end
end

function ZO_Alchemy:SetMode(mode)
    if self.mode ~= mode then
        local oldMode = self.mode
        self.mode = mode

        CRAFTING_RESULTS:SetCraftingTooltip(nil)

        if mode == ZO_ALCHEMY_MODE_RECIPES then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
            PROVISIONER:EmbedInCraftingScene()
        else -- mode is ZO_ALCHEMY_MODE_CREATION
            if oldMode == ZO_ALCHEMY_MODE_RECIPES then
                PROVISIONER:RemoveFromCraftingScene()
                KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
            end

            CRAFTING_RESULTS:SetCraftingTooltip(self.tooltip)
            CRAFTING_RESULTS:SetTooltipAnimationSounds(SOUNDS.ALCHEMY_CREATE_TOOLTIP_GLOW_SUCCESS, SOUNDS.ALCHEMY_CREATE_TOOLTIP_GLOW_FAIL)
            self:ResetMultiCraftNumIterations()
        end

        self.control:GetNamedChild("Inventory"):SetHidden(mode ~= ZO_ALCHEMY_MODE_CREATION)
        self.control:GetNamedChild("SlotContainer"):SetHidden(mode ~= ZO_ALCHEMY_MODE_CREATION)
        self:UpdateTooltip()
    end
end

--Alchemy Inventory
-------------------------

ZO_AlchemyInventory = ZO_CraftingInventory:Subclass()

local SCROLL_DATA_TYPE_SOLVENT = 1
local SCROLL_DATA_TYPE_REAGENT = 2

function ZO_AlchemyInventory:New(...)
    return ZO_CraftingInventory.New(self, ...)
end

function ZO_AlchemyInventory:Initialize(owner, control, ...)
    ZO_CraftingInventory.Initialize(self, control, ...)

    self.owner = owner

    local function IngredientSortOrder(bagId, slotIndex)
        local itemType, _, requiredLevel, requiredChampionPoints = select(2, GetItemCraftingInfo(bagId, slotIndex))
        if requiredChampionPoints then
            requiredLevel = requiredLevel + requiredChampionPoints
        end

        if itemType == ITEMTYPE_POISON_BASE then
            return requiredLevel + 1 -- Kludge to make the poison of a required level always show up right after the potion of that level, regardless of what they're named
        else
            return requiredLevel
        end
    end

    self:SetCustomSort(IngredientSortOrder)
    self.sortKey = "custom"

    self:SetFilters{
        self:CreateNewTabFilterData(ITEMTYPE_REAGENT, GetString(SI_ALCHEMY_REAGENTS_TAB), "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_up.dds", "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_down.dds", "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_over.dds", "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_disabled.dds"),
        self:CreateNewTabFilterData(IsAlchemySolvent, GetString(SI_ALCHEMY_SOLVENT_TAB), "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_up.dds", "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_down.dds", "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_over.dds", "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_disabled.dds"),
        self:CreateNewTabFilterData(nil, GetString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_ALL), "EsoUI/Art/Inventory/inventory_tabIcon_all_up.dds", "EsoUI/Art/Inventory/inventory_tabIcon_all_down.dds", "EsoUI/Art/Inventory/inventory_tabIcon_all_over.dds", "EsoUI/Art/Inventory/inventory_tabIcon_all_disabled.dds"),
    }

    self:SetSortColumnHidden({ stackSellPrice = true, statusSortOrder = true, traitInformationSortOrder = true, sellInformationSortOrder = true, }, true)
end

function ZO_AlchemyInventory:IsLocked(bagId, slotIndex)
    return ZO_CraftingInventory.IsLocked(self, bagId, slotIndex) or self.owner:IsSlotted(bagId, slotIndex)
end

function ZO_AlchemyInventory:AddListDataTypes()
    local defaultSetup = self:GetDefaultTemplateSetupFunction()

    local function SolventSetup(rowControl, data)
        defaultSetup(rowControl, data)

        local levelLabel = rowControl:GetNamedChild("Level")

        local usedInCraftingType, craftingSubItemType, rankRequirement = GetItemCraftingInfo(data.bagId, data.slotIndex)

        if not rankRequirement or rankRequirement <= GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_LEVEL) then
            local craftingSubItemType, _, resultingItemLevel, requiredChampionPoints = select(2, GetItemCraftingInfo(data.bagId, data.slotIndex))
            local itemTypeString = GetString((craftingSubItemType == ITEMTYPE_POTION_BASE) and SI_ITEM_FORMAT_STR_POTION or SI_ITEM_FORMAT_STR_POISON)

            if requiredChampionPoints and requiredChampionPoints > 0 then
                levelLabel:SetText(zo_strformat(SI_ALCHEMY_CREATES_ITEM_OF_CHAMPION_POINTS, requiredChampionPoints, itemTypeString))
            else
                levelLabel:SetText(zo_strformat(SI_ALCHEMY_CREATES_ITEM_OF_LEVEL, resultingItemLevel, itemTypeString))
            end

            levelLabel:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_TOOLTIP, ITEM_TOOLTIP_COLOR_ACCENT))
        else
            levelLabel:SetText(zo_strformat(SI_REQUIRES_ALCHEMY_SOLVENT_PURIFICATION, rankRequirement))
            levelLabel:SetColor(ZO_ERROR_COLOR:UnpackRGBA())
        end

        ZO_ItemSlot_SetupTextUsableAndLockedColor(levelLabel, data.meetsUsageRequirements, self:IsLocked(data.bagId, data.slotIndex))
    end

    local function SetupTrait(traits, locked, ...)
        local numTraits = select("#", ...) / ALCHEMY_TRAIT_STRIDE
        for i, traitControl in ipairs(traits) do
            if i > numTraits then
                traitControl:SetHidden(true)
            else
                traitControl:SetHidden(false)

                local traitName, normalTraitIcon, traitMatchIcon, _, traitConflictIcon = ZO_Alchemy_GetTraitInfo(i, ...)

                if traitName and traitName ~= "" then
                    traitControl.label:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_TOOLTIP, ITEM_TOOLTIP_COLOR_ACCENT))
                    traitControl.label:SetText(traitName)

                    ALCHEMY:SetupTraitIcon(traitControl.icon, traitName, normalTraitIcon, traitMatchIcon, traitConflictIcon)
                    ZO_ItemSlot_SetupIconUsableAndLockedColor(traitControl.icon, true, locked)
                    traitControl.icon:SetHidden(false)
                else
                    traitControl.label:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_TOOLTIP, ITEM_TOOLTIP_COLOR_INACTIVE_BONUS))
                    traitControl.label:SetText(GetString(SI_CRAFTING_UNKNOWN_NAME))

                    traitControl.icon:SetHidden(true)
                end

                ZO_ItemSlot_SetupTextUsableAndLockedColor(traitControl.label, true, locked)
            end
        end
    end

    local function ReagentSetup(rowControl, data)
        defaultSetup(rowControl, data)
        local locked = self:IsLocked(data.bagId, data.slotIndex)
        SetupTrait(rowControl.traits, locked, GetAlchemyItemTraits(data.bagId, data.slotIndex))
    end

    ZO_ScrollList_AddDataType(self.list, SCROLL_DATA_TYPE_SOLVENT, "ZO_AlchemyInventorySolventRow", 72, SolventSetup, nil, nil, ZO_InventorySlot_OnPoolReset)
    ZO_ScrollList_AddDataType(self.list, SCROLL_DATA_TYPE_REAGENT, "ZO_AlchemyInventoryReagentRow", 108, ReagentSetup, nil, nil, ZO_InventorySlot_OnPoolReset)
end

function ZO_AlchemyInventory:GetScrollDataType(bagId, slotIndex)
    local usedInCraftingType, craftingSubItemType = GetItemCraftingInfo(bagId, slotIndex)
    if IsAlchemySolvent(craftingSubItemType) then
        return SCROLL_DATA_TYPE_SOLVENT
    elseif craftingSubItemType == ITEMTYPE_REAGENT then
        return SCROLL_DATA_TYPE_REAGENT
    end
end

function ZO_AlchemyInventory:ChangeFilter(filterData)
    ZO_CraftingInventory.ChangeFilter(self, filterData)
    self.filterType = filterData.descriptor

    if self.filterType == ITEMTYPE_REAGENT then
        self:SetNoItemLabelText(GetString(SI_ALCHEMY_NO_REAGENTS))
    elseif self.filterType == IsAlchemySolvent then
        self:SetNoItemLabelText(GetString(SI_ALCHEMY_NO_SOLVENTS))
    else
        self:SetNoItemLabelText(GetString(SI_ALCHEMY_NO_SOLVENTS_OR_REAGENTS))
    end

    self:HandleDirtyEvent()
end

function ZO_AlchemyInventory:Refresh(data)
    local validItemIds = self:EnumerateInventorySlotsAndAddToScrollData(ZO_Alchemy_IsAlchemyItem, ZO_Alchemy_DoesAlchemyItemPassFilter, self.filterType, data)
    self.owner:OnInventoryUpdate(validItemIds)

    self:SetNoItemLabelHidden(#data > 0)
end

function ZO_AlchemyInventory:ShowAppropriateSlotDropCallouts(bagId, slotIndex)
    local _, craftingSubItemType, rankRequirement = GetItemCraftingInfo(bagId, slotIndex)
    self.owner:ShowAppropriateSlotDropCallouts(craftingSubItemType, rankRequirement)
end

function ZO_AlchemyInventory:HideAllSlotDropCallouts()
    self.owner:HideAllSlotDropCallouts()
end

function ZO_Alchemy_Initialize(control)
    ALCHEMY = ZO_Alchemy:New(control)
end
