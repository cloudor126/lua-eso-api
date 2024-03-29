--[[
    The ActionBarAssignmentManager represents the the state of your skills on the AssignableActionBar, which is used inside the Skills UI.
    The skills UI is allowed to assign new skills without applying it to your "real" action bar, so this shouldn't be taken as the "truth" as the server sees it, but a pending state for the UI.
    This pending state is actually applied along with pending skill allocations inside of the SkillsAndActionBarManager.
]]--

-- These bars can be viewed inside of skills. This should be every bar used ingame.
internalassert(HOTBAR_CATEGORY_MAX_VALUE == 9, "Update hotbars")
local VIEWABLE_HOTBAR_CATEGORY_SET =
{
    [HOTBAR_CATEGORY_PRIMARY] = true,
    [HOTBAR_CATEGORY_BACKUP] = true,
    [HOTBAR_CATEGORY_OVERLOAD] = true,
    [HOTBAR_CATEGORY_WEREWOLF] = true,
    [HOTBAR_CATEGORY_TEMPORARY] = true,
    [HOTBAR_CATEGORY_DAEDRIC_ARTIFACT] = true,
}

-- These bars can be edited, and the server will persist those edits
internalassert(NUM_ASSIGNABLE_HOTBARS == 4, "Update hotbars")
local ASSIGNABLE_HOTBAR_CATEGORY_SET =
{
    [HOTBAR_CATEGORY_PRIMARY] = true,
    [HOTBAR_CATEGORY_BACKUP] = true,
    [HOTBAR_CATEGORY_OVERLOAD] = true,
    [HOTBAR_CATEGORY_WEREWOLF] = true,
}

-- These bars have an associated weapon pair with them
local WEAPON_PAIR_HOTBAR_CATEGORY_SET = {}
for hotbarCategory in pairs(ASSIGNABLE_HOTBAR_CATEGORY_SET) do
    if GetWeaponPairFromHotbarCategory(hotbarCategory) ~= ACTIVE_WEAPON_PAIR_NONE then
        WEAPON_PAIR_HOTBAR_CATEGORY_SET[hotbarCategory] = true
    end
end

local HOTBAR_CYCLE_ORDER =
{
    HOTBAR_CATEGORY_PRIMARY,
    HOTBAR_CATEGORY_BACKUP,
    HOTBAR_CATEGORY_OVERLOAD,
    HOTBAR_CATEGORY_WEREWOLF,
    HOTBAR_CATEGORY_TEMPORARY,
    HOTBAR_CATEGORY_DAEDRIC_ARTIFACT,
}
--------------------------------
-- Slottable Action Interface --
--------------------------------

--[[
    A slottable action represents any action you can put into an ActionSlot from inside the Skills UI, which include:
    * the empty action (aka, this slot does nothing)
    * active skills
    * ultimates
    * raw abilities
    This does not include quickslots, which aren't shown and have their own handling someplace else.
]]--
ZO_SLOTTABLE_ACTION_TYPE_EMPTY = 1
ZO_SLOTTABLE_ACTION_TYPE_SKILL = 2
ZO_SLOTTABLE_ACTION_TYPE_ABILITY = 3

ZO_BaseSlottableAction = ZO_Object:Subclass()

function ZO_BaseSlottableAction:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function ZO_BaseSlottableAction:Initialize()
    -- Can be overriden
end

function ZO_BaseSlottableAction:GetSlottableActionType()
    assert(false, "override me")
end

function ZO_BaseSlottableAction:GetActionType()
    assert(false, "override me")
end

function ZO_BaseSlottableAction:GetActionId()
    assert(false, "override me")
end

function ZO_BaseSlottableAction:EqualsSlot(otherSlottableAction)
    assert(false, "override me")
end

function ZO_BaseSlottableAction:EqualsSkillData(skillData)
    assert(false, "override me")
end

-- This can return nil
function ZO_BaseSlottableAction:GetIcon()
    assert(false, "override me")
end

function ZO_BaseSlottableAction:IsUsable(hotbarCategory)
    assert(false, "override me")
end

function ZO_BaseSlottableAction:IsStillValid()
    assert(false, "override me")
end

function ZO_BaseSlottableAction:LayoutGamepadTooltip()
    assert(false, "override me")
end

-- This can return nil
function ZO_BaseSlottableAction:GetKeyboardTooltipControl()
    assert(false, "override me")
end

function ZO_BaseSlottableAction:SetKeyboardTooltip()
    assert(false, "override me")
end

function ZO_BaseSlottableAction:TryCursorPickup()
    assert(false, "override me")
end

function ZO_BaseSlottableAction:IsEmpty()
    return self:GetSlottableActionType() == ZO_SLOTTABLE_ACTION_TYPE_EMPTY
end

function ZO_BaseSlottableAction:IsWerewolf()
    -- can be overridden
    return false
end

------------------
-- Empty Action --
------------------

--[[
    The empty action has no state, it's always action ID 0. To use it, use the ZO_EMPTY_SLOTTABLE_ACTION singleton instead of the class.
]]--
ZO_EmptySlottableAction = ZO_BaseSlottableAction:Subclass()

function ZO_EmptySlottableAction:New(...)
    return ZO_BaseSlottableAction.New(self, ...)
end

function ZO_EmptySlottableAction:GetSlottableActionType()
    return ZO_SLOTTABLE_ACTION_TYPE_EMPTY
end

function ZO_EmptySlottableAction:GetActionId()
    local NO_ACTION_ID = 0
    return NO_ACTION_ID
end

function ZO_EmptySlottableAction:GetActionType()
    return ACTION_TYPE_NOTHING
end

function ZO_EmptySlottableAction:EqualsSlot(otherSlottableAction)
    return otherSlottableAction ~= nil and otherSlottableAction:IsEmpty()
end

function ZO_EmptySlottableAction:EqualsSkillData(skillData)
    return false
end

function ZO_EmptySlottableAction:GetIcon()
    -- Empty slots have no icon
    return nil
end

function ZO_EmptySlottableAction:IsUsable(hotbarCategory)
    return false
end

function ZO_EmptySlottableAction:IsStillValid()
    return true -- It's always valid to have an empty slot
end

function ZO_EmptySlottableAction:LayoutGamepadTooltip(tooltipType)
    -- Empty out tooltips
    GAMEPAD_TOOLTIPS:ClearTooltip(tooltipType)
end

function ZO_EmptySlottableAction:GetKeyboardTooltipControl()
    -- Empty slots have no tooltip
    return nil
end

function ZO_EmptySlottableAction:SetKeyboardTooltip()
    -- Do nothing
end

function ZO_EmptySlottableAction:TryCursorPickup()
    return false -- pickup failed
end

ZO_EMPTY_SLOTTABLE_ACTION = ZO_EmptySlottableAction:New()

----------------------
-- Slottable Skills --
----------------------

ZO_SlottableSkill = ZO_BaseSlottableAction:Subclass()

function ZO_SlottableSkill:New(...)
    return ZO_BaseSlottableAction.New(self, ...)
end

function ZO_SlottableSkill:Initialize(skillData, hotbarCategory)
    assert(skillData ~= nil, "SlottableSkill requires a linked skillData, got nil")
    assert(skillData:IsPassive() == false, "Only actives/ultimates are slottable")
    assert(hotbarCategory, "SlottableSkill requires a hotbarCategory, got nil")
    self.skillData = skillData
    self.hotbarCategory = hotbarCategory -- used for visualization purposes, has no effect on things like equality or the resulting message
end

function ZO_SlottableSkill:GetSlottableActionType()
    return ZO_SLOTTABLE_ACTION_TYPE_SKILL
end

function ZO_SlottableSkill:GetActionId()
    local skillProgressionData = self.skillData:GetPointAllocatorProgressionData()
    return skillProgressionData:GetAbilityId()
end

function ZO_SlottableSkill:GetActionType()
    return ACTION_TYPE_ABILITY
end

function ZO_SlottableSkill:EqualsSlot(otherSlottableAction)
    return otherSlottableAction ~= nil and otherSlottableAction:GetSlottableActionType() == ZO_SLOTTABLE_ACTION_TYPE_SKILL and self.skillData == otherSlottableAction.skillData
end

function ZO_SlottableSkill:EqualsSkillData(skillData)
    return skillData == self.skillData
end

function ZO_SlottableSkill:GetEffectiveAbilityId()
    local skillProgressionData = self.skillData:GetPointAllocatorProgressionData()
    local rootAbilityId = skillProgressionData:GetAbilityId()
    if skillProgressionData:IsChainingAbility() then
        return GetEffectiveAbilityIdForAbilityOnHotbar(rootAbilityId, self.hotbarCategory)
    else
        return rootAbilityId
    end
end

function ZO_SlottableSkill:GetIcon()
    return GetAbilityIcon(self:GetEffectiveAbilityId())
end

function ZO_SlottableSkill:IsUsable()
    return CanAbilityBeUsedFromHotbar(self:GetEffectiveAbilityId(), self.hotbarCategory)
end

function ZO_SlottableSkill:IsStillValid()
    -- We should invalidate skills that have been refunded
    return self.skillData:GetPointAllocator():IsPurchased()
end

function ZO_SlottableSkill:LayoutGamepadTooltip(tooltipType)
    GAMEPAD_TOOLTIPS:LayoutAbilityWithSkillProgressionData(tooltipType, self:GetEffectiveAbilityId(), self.skillData:GetPointAllocatorProgressionData())
end

function ZO_SlottableSkill:GetKeyboardTooltipControl()
    return SkillTooltip
end

function ZO_SlottableSkill:SetKeyboardTooltip(tooltipControl)
    local DONT_SHOW_SKILL_POINT_COST = false
    local DONT_SHOW_UPGRADE_TEXT = false
    local DONT_SHOW_ADVISED = false
    local DONT_SHOW_BAD_MORPH = false
    local NO_OVERRIDE_RANK = nil
    self.skillData:GetPointAllocatorProgressionData():SetKeyboardTooltip(tooltipControl, DONT_SHOW_SKILL_POINT_COST, DONT_SHOW_UPGRADE_TEXT, DONT_SHOW_ADVISED, DONT_SHOW_BAD_MORPH, NO_OVERRIDE_RANK, self:GetEffectiveAbilityId())
end

function ZO_SlottableSkill:TryCursorPickup()
    PickupAbilityBySkillLine(self.skillData:GetIndices())
    return true
end

function ZO_SlottableSkill:IsWerewolf()
    return self.skillData:GetSkillLineData():IsWerewolf()
end

-----------------------
-- Slottable Ability --
-----------------------
--[[
    Slottable abilities are "loose", aka unassociated with a skill line. These should only show up on temp bars in normal play.
    These are built under the assumption that they can't be edited, because you can't edit temp bars.
]]--

ZO_SlottableAbility = ZO_BaseSlottableAction:Subclass()

function ZO_SlottableAbility:New(...)
    return ZO_BaseSlottableAction.New(self, ...)
end

function ZO_SlottableAbility:Initialize(abilityId)
    assert(abilityId ~= nil, "ZO_SlottableAbility requires an abilityId")
    self.abilityId = abilityId
end

function ZO_SlottableAbility:GetSlottableActionType()
    return ZO_SLOTTABLE_ACTION_TYPE_ABILITY
end

function ZO_SlottableAbility:GetActionId()
    return self.abilityId
end

function ZO_SlottableAbility:GetActionType()
    return ACTION_TYPE_ABILITY
end

function ZO_SlottableAbility:EqualsSlot(otherSlottableAction)
    return otherSlottableAction ~= nil and otherSlottableAction:GetSlottableActionType() == ZO_SLOTTABLE_ACTION_TYPE_ABILITY and self.abilityId == otherSlottableAction:GetActionId()
end

function ZO_SlottableAbility:EqualsSkillData(skillData)
    return false
end

function ZO_SlottableAbility:GetIcon()
    return GetAbilityIcon(self.abilityId)
end

function ZO_SlottableAbility:IsUsable(hotbarCategory)
    return true
end

function ZO_SlottableAbility:IsStillValid()
    return true
end

function ZO_SlottableAbility:LayoutGamepadTooltip(tooltipType)
    GAMEPAD_TOOLTIPS:LayoutSimpleAbility(tooltipType, self.abilityId)
end

function ZO_SlottableAbility:GetKeyboardTooltipControl()
    return AbilityTooltip
end

function ZO_SlottableAbility:SetKeyboardTooltip(tooltipControl)
    tooltipControl:SetAbilityId(self.abilityId)
end

function ZO_SlottableAbility:TryCursorPickup()
    return false
end

------------
-- Hotbar --
------------
--[[
    Hotbar objects model the subset of a server side hotbar that matters for the skills window: We only care about the 5 active slots and the one ultimate slot, and we only store SlottableActions.
]]--

ZO_ActionBarAssignmentManager_Hotbar = ZO_Object:Subclass()

function ZO_ActionBarAssignmentManager_Hotbar:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

local SKILL_BAR_SLOTS_START = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local SKILL_BAR_SLOTS_STOP = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
function ZO_ActionBarAssignmentManager_Hotbar:Initialize(hotbarCategory)
    self.hotbarCategory = hotbarCategory
    self.isInCycle = false
    self.slots = {}

    self.overrideSlotSkillDatas = {}
    for actionSlotIndex = SKILL_BAR_SLOTS_START, SKILL_BAR_SLOTS_STOP do
        local progressionId = GetSkillProgressionIdForHotbarSlotOverrideRule(actionSlotIndex, hotbarCategory)
        if progressionId ~= 0 then
            self.overrideSlotSkillDatas[actionSlotIndex] = SKILLS_DATA_MANAGER:GetSkillDataByProgressionId(progressionId)
        end
    end
end

function ZO_ActionBarAssignmentManager_Hotbar:Reset()
    ZO_ClearTable(self.slots)

    for actionSlotIndex = SKILL_BAR_SLOTS_START, SKILL_BAR_SLOTS_STOP do
        self:ResetSlot(actionSlotIndex)
    end
end

function ZO_ActionBarAssignmentManager_Hotbar:ResetSlot(actionSlotIndex)
    if actionSlotIndex < SKILL_BAR_SLOTS_START or actionSlotIndex > SKILL_BAR_SLOTS_STOP then
        -- We can't assign skills to this actionSlotIndex
        return
    end

    local overrideSkillData = self:GetOverrideSkillDataForSlot(actionSlotIndex)
    if overrideSkillData then
        self.slots[actionSlotIndex] = ZO_SlottableSkill:New(overrideSkillData, self.hotbarCategory)
        return
    end

    self.slots[actionSlotIndex] = ZO_EMPTY_SLOTTABLE_ACTION
    local actionType = GetSlotType(actionSlotIndex, self.hotbarCategory)
    if actionType == ACTION_TYPE_ABILITY then
        local abilityId = GetSlotBoundId(actionSlotIndex, self.hotbarCategory)
        local progressionData = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
        if progressionData then
            self.slots[actionSlotIndex] = ZO_SlottableSkill:New(progressionData:GetSkillData(), self.hotbarCategory)
        elseif not ASSIGNABLE_HOTBAR_CATEGORY_SET[self.hotbarCategory] then
            self.slots[actionSlotIndex] = ZO_SlottableAbility:New(abilityId)
        end
    end
end

function ZO_ActionBarAssignmentManager_Hotbar:GetHotbarCategory()
    return self.hotbarCategory
end

function ZO_ActionBarAssignmentManager_Hotbar:GetSlotData(actionSlotIndex)
    return self.slots[actionSlotIndex]
end

function ZO_ActionBarAssignmentManager_Hotbar:GetOverrideSkillDataForSlot(actionSlotIndex)
    local overrideSkillData = self.overrideSlotSkillDatas[actionSlotIndex]
    if overrideSkillData and overrideSkillData:GetPointAllocator():IsPurchased() then
        return overrideSkillData
    end
    return nil
end

function ZO_ActionBarAssignmentManager_Hotbar:SlotIterator(filterFunctions)
    return ZO_FilteredNonContiguousTableIterator(self.slots, filterFunctions)
end

function ZO_ActionBarAssignmentManager_Hotbar:DoesSlotHavePendingChanges(actionSlotIndex)
    local pendingAction = self:GetSlotData(actionSlotIndex)
    if pendingAction == nil then
        return false
    end

    local actionType = GetSlotType(actionSlotIndex, self.hotbarCategory)
    local actionId = GetSlotBoundId(actionSlotIndex, self.hotbarCategory)
    local pendingActionType = pendingAction:GetActionType()
    local pendingActionId = pendingAction:GetActionId()
    return pendingActionType ~= actionType or pendingActionId ~= actionId
end

function ZO_ActionBarAssignmentManager_Hotbar:IsEditable()
    return ASSIGNABLE_HOTBAR_CATEGORY_SET[self.hotbarCategory] == true -- coerce to bool
end

function ZO_ActionBarAssignmentManager_Hotbar:GetExpectedClearSlotResult(actionSlotIndex)
    if not self:IsEditable() then
        return HOT_BAR_RESULT_CANNOT_EDIT_HOTBAR
    end

    if self:GetOverrideSkillDataForSlot(actionSlotIndex) then
        return HOT_BAR_RESULT_CANNOT_EDIT_SLOT
    end

    if GetActionBarLockedReason() == ACTION_BAR_LOCKED_REASON_COMBAT then
        return HOT_BAR_RESULT_NO_COMBAT_SWAP
    end
    
    return HOT_BAR_RESULT_SUCCESS
end

function ZO_ActionBarAssignmentManager_Hotbar:GetExpectedSkillSlotResult(actionSlotIndex, skillData)
    local isWerewolfBar = self.hotbarCategory == HOTBAR_CATEGORY_WEREWOLF
    local isWerewolfSkill = skillData:GetSkillLineData():IsWerewolf()
    if isWerewolfBar and not isWerewolfSkill then
        return HOT_BAR_RESULT_CANNOT_USE_WHILE_WEREWOLF
    end

    if not self:IsEditable() then
        return HOT_BAR_RESULT_CANNOT_EDIT_HOTBAR
    end

    if self:GetOverrideSkillDataForSlot(actionSlotIndex) then
        return HOT_BAR_RESULT_CANNOT_EDIT_SLOT
    end

    local isUltimateSlot = ACTION_BAR_ASSIGNMENT_MANAGER:IsUltimateSlot(actionSlotIndex)
    if skillData:IsUltimate() ~= isUltimateSlot or skillData:IsPassive() then
        if isUltimateSlot then
            return HOT_BAR_RESULT_IS_NOT_ULTIMATE
        else
            return HOT_BAR_RESULT_IS_NOT_NORMAL
        end
    end

    if not skillData:GetPointAllocator():IsPurchased() then
        return HOT_BAR_RESULT_ABILITY_NOT_KNOWN
    end

    if GetActionBarLockedReason() == ACTION_BAR_LOCKED_REASON_COMBAT then
        return HOT_BAR_RESULT_NO_COMBAT_SWAP
    end

    return HOT_BAR_RESULT_SUCCESS
end

do
    local IS_CHANGED_BY_PLAYER = true
    function ZO_ActionBarAssignmentManager_Hotbar:ClearSlot(actionSlotIndex)
        if self.slots[actionSlotIndex] == nil then
            internalassert(false, "Invalid slot ID")
            return
        end

        local expectedResult = self:GetExpectedClearSlotResult(actionSlotIndex, skillData)
        if expectedResult ~= HOT_BAR_RESULT_SUCCESS then
            ZO_AlertEvent(EVENT_HOT_BAR_RESULT, expectedResult)
            return false
        end

        self.slots[actionSlotIndex] = ZO_EMPTY_SLOTTABLE_ACTION
        ACTION_BAR_ASSIGNMENT_MANAGER:FireCallbacks("SlotUpdated", self.hotbarCategory, actionSlotIndex, IS_CHANGED_BY_PLAYER)
    end

    function ZO_ActionBarAssignmentManager_Hotbar:AssignSkillToSlot(actionSlotIndex, skillData)
        local currentAction = self:GetSlotData(actionSlotIndex)

        -- this slot already has this skill, skip
        if currentAction:EqualsSkillData(skillData) then
            return false
        end

        -- you can't slot this specific skill here
        local expectedResult = self:GetExpectedSkillSlotResult(actionSlotIndex, skillData)
        if expectedResult ~= HOT_BAR_RESULT_SUCCESS then
            ZO_AlertEvent(EVENT_HOT_BAR_RESULT, expectedResult)
            return false
        end

        -- the skill is already slotted on this bar, clear that instance out
        local oldactionSlotIndex = self:FindSlotMatchingSkill(skillData)
        if oldactionSlotIndex then
            self:ClearSlot(oldactionSlotIndex)
        end

        self.slots[actionSlotIndex] = ZO_SlottableSkill:New(skillData, self.hotbarCategory)
        ACTION_BAR_ASSIGNMENT_MANAGER:FireCallbacks("SlotUpdated", self.hotbarCategory, actionSlotIndex, IS_CHANGED_BY_PLAYER)
        return true
    end
end

function ZO_ActionBarAssignmentManager_Hotbar:FindEmptySlotForSkill(skillData)
    -- Can't slot passives
    if skillData:IsPassive() then
        return nil
    end

    if skillData:IsUltimate() then
        -- This is an ultimate, it can only be slotted in one place
        local ULTIMATE_SLOT_ID = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
        if self:GetSlotData(ULTIMATE_SLOT_ID):IsEmpty() then
            return ULTIMATE_SLOT_ID
        end
    else
        -- This is a normal active, slot it in the first empty slot
        local NORMAL_BAR_SLOTS_START = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
        local NORMAL_BAR_SLOTS_STOP = ACTION_BAR_ULTIMATE_SLOT_INDEX
        for actionSlotIndex = NORMAL_BAR_SLOTS_START, NORMAL_BAR_SLOTS_STOP do 
            if self:GetSlotData(actionSlotIndex):IsEmpty() then
                return actionSlotIndex
            end
        end
    end

    return nil
end

function ZO_ActionBarAssignmentManager_Hotbar:FindSlotMatchingSkill(skillData)
    for actionSlotIndex, slotAction in self:SlotIterator() do
        if slotAction:EqualsSkillData(skillData) then
            return actionSlotIndex
        end
    end
end

function ZO_ActionBarAssignmentManager_Hotbar:IsInCycle()
    return self.isInCycle
end

-- NumHotbarsInCycle is kept in sync by these two methods: if you manipulate isInCycle someplace else, you'll have a bad time
function ZO_ActionBarAssignmentManager_Hotbar:EnableInCycle()
    local wasInCycle = self.isInCycle
    self.isInCycle = true
    if wasInCycle ~= self.isInCycle then
        ACTION_BAR_ASSIGNMENT_MANAGER:ChangeNumHotbarsInCycle(1)
    end
end

function ZO_ActionBarAssignmentManager_Hotbar:DisableInCycle()
    local wasInCycle = self.isInCycle
    self.isInCycle = false
    if wasInCycle ~= self.isInCycle then
        ACTION_BAR_ASSIGNMENT_MANAGER:ChangeNumHotbarsInCycle(-1)
    end
end

-----------------------------------
-- Action Bar Assignment Manager --
-----------------------------------

ZO_ActionBarAssignmentManager = ZO_CallbackObject:Subclass()

function ZO_ActionBarAssignmentManager:New(...)
    ACTION_BAR_ASSIGNMENT_MANAGER = ZO_CallbackObject.New(self)
    ACTION_BAR_ASSIGNMENT_MANAGER:Initialize(...)
    return ACTION_BAR_ASSIGNMENT_MANAGER
end

function ZO_ActionBarAssignmentManager:Initialize()
    self.hotbars = {}
    for hotbarCategory in pairs(VIEWABLE_HOTBAR_CATEGORY_SET) do
        self.hotbars[hotbarCategory] = ZO_ActionBarAssignmentManager_Hotbar:New(hotbarCategory)
        self.hotbars[hotbarCategory]:Reset()
    end
    self:ResetCurrentHotbarToActiveBar()

    self.numHotbarsInCycle = 0
    self:GetHotbar(HOTBAR_CATEGORY_PRIMARY):EnableInCycle()
    self:UpdateBackupBarStateInCycle()

    self:RegisterForEvents()

    SKILLS_AND_ACTION_BAR_MANAGER:OnActionBarAssignmentManagerReady(self)
end

function ZO_ActionBarAssignmentManager:RegisterForEvents()
    -- Action slot events
    local function OnActionSlotUpdated(_, actionSlotIndex)
        local hotbar = self:GetHotbar(self.playerActiveHotbarCategory)
        hotbar:ResetSlot(actionSlotIndex)
        self:FireCallbacks("SlotUpdated", self.playerActiveHotbarCategory, actionSlotIndex)
    end
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBarAssignmentManager", EVENT_ACTION_SLOT_UPDATED, OnActionSlotUpdated)

    local function OnActiveHotbarUpdated(_, didActiveHotbarChange, shouldUpdateSlotAssignments)
        local oldHotbarCategory = self.currentHotbarCategory
        self:ResetCurrentHotbarToActiveBar()
        if shouldUpdateSlotAssignments then
            self:GetCurrentHotbar():Reset()
        end
        self:FireCallbacks("CurrentHotbarUpdated", self.currentHotbarCategory, oldHotbarCategory)
    end
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBarAssignmentManager", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnActiveHotbarUpdated)

    local function ResetAllHotbars()
        self:ResetAllHotbars()
    end
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBarAssignmentManager", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, ResetAllHotbars)
    SKILLS_AND_ACTION_BAR_MANAGER:RegisterCallback("SkillPointAllocationModeChanged", ResetAllHotbars)
    SKILLS_AND_ACTION_BAR_MANAGER:RegisterCallback("RespecStateReset", ResetAllHotbars)

    local function OnSkillsDataFullUpdate()
        -- Current morph may have changed, refresh visuals
        self:FireCallbacks("CurrentHotbarUpdated", self.currentHotbarCategory, self.currentHotbarCategory)
    end
    SKILLS_DATA_MANAGER:RegisterCallback("FullSystemUpdated", OnSkillsDataFullUpdate)

    local function UpdateWeaponSwapState()
        self:UpdateWeaponSwapState()
    end
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBarAssignmentManager", EVENT_WEAPON_PAIR_LOCK_CHANGED, UpdateWeaponSwapState)

    local function HandleSlotChangeRequested(_, abilityId, actionSlotIndex, hotbarCategory)
        local hotbar = self:GetHotbar(hotbarCategory)
        if abilityId == 0 then
            if hotbar:ClearSlot(actionSlotIndex) then
                PlaySound(SOUNDS.ABILITY_SLOT_CLEARED)
            end
        else
            local progressionData = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
            if progressionData and hotbar:AssignSkillToSlot(actionSlotIndex, progressionData:GetSkillData())then
                PlaySound(SOUNDS.ABILITY_SLOTTED)
            end
        end
    end
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBarAssignmentManager", EVENT_HOTBAR_SLOT_CHANGE_REQUESTED, HandleSlotChangeRequested)

    -- Skill point Allocation events
    local function OnSkillPurchaseStateChanged(skillPointAllocator)
        local skillData = skillPointAllocator:GetSkillData()
        if skillData:IsPassive() then
            return
        end

        if skillPointAllocator:IsPurchased() then
            self:TryToSlotNewSkill(skillData)
        else
            self:ClearAllSlotsWithSkill(skillData)
        end
    end
    SKILL_POINT_ALLOCATION_MANAGER:RegisterCallback("PurchasedChanged", OnSkillPurchaseStateChanged)

    local function OnSkillProgressionStateChanged(skillPointAllocator)
        local skillData = skillPointAllocator:GetSkillData()
        if skillData:IsPassive() then
            return
        end

        for hotbarCategory, hotbar in pairs(self.hotbars) do
            for actionSlotIndex, slotData in hotbar:SlotIterator() do
                if slotData:EqualsSkillData(skillData) then
                    self:FireCallbacks("SlotUpdated", hotbarCategory, actionSlotIndex)
                end
            end
        end
    end
    SKILL_POINT_ALLOCATION_MANAGER:RegisterCallback("SkillProgressionKeyChanged", OnSkillProgressionStateChanged)

    local function OnSkillsCleared()
        for hotbarCategory, hotbar in pairs(self.hotbars) do
            for actionSlotIndex, slotData in hotbar:SlotIterator() do
                if slotData:IsStillValid() then
                    self:FireCallbacks("SlotUpdated", hotbarCategory, actionSlotIndex)
                else
                    hotbar:ClearSlot(actionSlotIndex)
                end
            end
        end
    end
    SKILL_POINT_ALLOCATION_MANAGER:RegisterCallback("OnSkillsCleared", OnSkillsCleared)

    -- weapon swapping unlocked state events
    local function OnUnitCreated(_, unitTag)
        if unitTag == "player" then
            self:UpdateBackupBarStateInCycle()
        end
    end
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBarAssignmentManager", EVENT_UNIT_CREATED, OnUnitCreated)

    local function OnLevelUpdate(_, unitTag, level)
        if unitTag == "player" then
            self:UpdateBackupBarStateInCycle()
        end
    end
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBarAssignmentManager", EVENT_LEVEL_UPDATE, OnLevelUpdate)

    local function OnPlayerActivated()
        self:ResetCurrentHotbarToActiveBar()
        self:ResetAllHotbars()
        self:UpdateBackupBarStateInCycle()
    end
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBarAssignmentManager", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

function ZO_ActionBarAssignmentManager:ResetCurrentHotbarToActiveBar()
    local playerActiveHotbarCategory = GetActiveHotbarCategory()
    self.playerActiveHotbarCategory = playerActiveHotbarCategory
    if VIEWABLE_HOTBAR_CATEGORY_SET[playerActiveHotbarCategory] then
        self.currentHotbarCategory = playerActiveHotbarCategory
    end
    self.shouldUpdateWeaponSwapState = false
end

function ZO_ActionBarAssignmentManager:ResetAllHotbars()
    for _, hotbar in pairs(self.hotbars) do
        hotbar:Reset()
    end
    self:FireCallbacks("CurrentHotbarUpdated", self.currentHotbarCategory, self.currentHotbarCategory)
end

function ZO_ActionBarAssignmentManager:ShouldSubmitChangesForHotbarCategory(hotbarCategory)
    -- Don't perform werewolf changes if the werewolf line isn't unlocked
    -- this solves an issue where characters that have refunded werewolf still try to place their auto-grant ultimate on the werewolf bar
    if hotbarCategory == HOTBAR_CATEGORY_WEREWOLF then
        local werewolfSkillLineData = SKILLS_DATA_MANAGER:GetWerewolfSkillLineData()
        return werewolfSkillLineData and werewolfSkillLineData:IsAvailable()
    end

    return true -- most hotbars are cool
end

function ZO_ActionBarAssignmentManager:IsAnyChangePending()
    for hotbarCategory in pairs(ASSIGNABLE_HOTBAR_CATEGORY_SET) do
        if self:ShouldSubmitChangesForHotbarCategory(hotbarCategory) then
            local hotbar = self.hotbars[hotbarCategory]
            for actionSlotIndex in hotbar:SlotIterator() do
                if hotbar:DoesSlotHavePendingChanges(actionSlotIndex) then
                    return true
                end
            end
        end
    end
    return false
end

function ZO_ActionBarAssignmentManager:AddChangesToMessage()
    local anyChangesAdded = false
    for hotbarCategory in pairs(ASSIGNABLE_HOTBAR_CATEGORY_SET) do
        if self:ShouldSubmitChangesForHotbarCategory(hotbarCategory) then
            local hotbar = self.hotbars[hotbarCategory]
            for actionSlotIndex, action in hotbar:SlotIterator() do
                if hotbar:DoesSlotHavePendingChanges(actionSlotIndex) then
                    anyChangesAdded = true
                    AddHotbarSlotChangeToAllocationRequest(actionSlotIndex, hotbarCategory, action:GetActionType(), action:GetActionId())
                end
            end
        end
    end
    return anyChangesAdded
end

function ZO_ActionBarAssignmentManager:GetCurrentHotbarCategory()
    return self.currentHotbarCategory
end

function ZO_ActionBarAssignmentManager:GetCurrentHotbarName()
    return GetString("SI_HOTBARCATEGORY", self.currentHotbarCategory)
end

function ZO_ActionBarAssignmentManager:GetCurrentHotbar()
    return self.hotbars[self.currentHotbarCategory]
end

function ZO_ActionBarAssignmentManager:GetHotbar(hotbarCategory)
    local hotbar = self.hotbars[hotbarCategory]
    internalassert(hotbar ~= nil, "invalid hotbar category")
    return hotbar
end

function ZO_ActionBarAssignmentManager:UpdateWeaponSwapState()
    if self.shouldUpdateWeaponSwapState ~= true then
        return
    end
    local _, weaponSwapDisabled = GetActiveWeaponPairInfo()

    if not weaponSwapDisabled then
        if self.currentHotbarCategory == HOTBAR_CATEGORY_PRIMARY then
            OnWeaponSwapToSet1()
        elseif self.currentHotbarCategory == HOTBAR_CATEGORY_BACKUP then
            OnWeaponSwapToSet2()
        end
        self.shouldUpdateWeaponSwapState = false
    end
end

function ZO_ActionBarAssignmentManager:CancelPendingWeaponSwap()
    if self.shouldUpdateWeaponSwapState then
        local oldHotbarCategory = self.currentHotbarCategory
        self:ResetCurrentHotbarToActiveBar()
        self:FireCallbacks("CurrentHotbarUpdated", self.currentHotbarCategory, oldHotbarCategory)
    end
end

function ZO_ActionBarAssignmentManager:ChangeNumHotbarsInCycle(numHotbarsEnabled)
    local oldShouldShowHotbarSwap = self:ShouldShowHotbarSwap()

    self.numHotbarsInCycle = self.numHotbarsInCycle + numHotbarsEnabled

    if oldShouldShowHotbarSwap ~= self:ShouldShowHotbarSwap() then
        self:FireCallbacks("HotbarSwapVisibleStateChanged")
    end
end

function ZO_ActionBarAssignmentManager:EnableHotbarInCycle(hotbarCategory)
    self:GetHotbar(hotbarCategory):EnableInCycle()
end

function ZO_ActionBarAssignmentManager:DisableAndSwitchOffHotbarInCycle(hotbarCategory)
    self:GetHotbar(hotbarCategory):DisableInCycle()

    if hotbarCategory == self.currentHotbarCategory then
        -- category is stale, switch to the active hotbar
        self:ResetCurrentHotbarToActiveBar()
        self:FireCallbacks("CurrentHotbarUpdated", self.currentHotbarCategory, hotbarCategory)
    end
end

function ZO_ActionBarAssignmentManager:UpdateBackupBarStateInCycle()
    local backupBar = self:GetHotbar(HOTBAR_CATEGORY_BACKUP)

    if GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel() then
        backupBar:EnableInCycle()
    else
        backupBar:DisableInCycle()
    end
end

function ZO_ActionBarAssignmentManager:IsWerewolfUltimateSlottedOnAnyWeaponBar()
    for hotbarCategory in pairs(WEAPON_PAIR_HOTBAR_CATEGORY_SET) do
        local ultimateSlotData = self:GetHotbar(hotbarCategory):GetSlotData(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
        if ultimateSlotData:IsWerewolf() then
            return true
        end
    end
    return false
end

function ZO_ActionBarAssignmentManager:UpdateWerewolfBarStateInCycle(selectedSkillLineData)
    if selectedSkillLineData and selectedSkillLineData:IsWerewolf() then
        self:EnableHotbarInCycle(HOTBAR_CATEGORY_WEREWOLF)
        if ACTION_BAR_ASSIGNMENT_MANAGER:IsWerewolfUltimateSlottedOnAnyWeaponBar() then
            self:SetCurrentHotbar(HOTBAR_CATEGORY_WEREWOLF)
        end
    else
        self:DisableAndSwitchOffHotbarInCycle(HOTBAR_CATEGORY_WEREWOLF)
    end
end

function ZO_ActionBarAssignmentManager:ShouldShowHotbarSwap()
    return self.numHotbarsInCycle > 1
end

function ZO_ActionBarAssignmentManager:CanCycleHotbars()
    if self:IsHotbarSwapAnimationPlaying() or not self:ShouldShowHotbarSwap() then
        return false
    end
    -- Normally you can only hotbar cycle from your weapon bars, so preserve that behavior here
    return WEAPON_PAIR_HOTBAR_CATEGORY_SET[self.playerActiveHotbarCategory] == true
end

function ZO_ActionBarAssignmentManager:CycleCurrentHotbar()
    if self:CanCycleHotbars() then
        local oldCycleIndex = ZO_IndexOfElementInNumericallyIndexedTable(HOTBAR_CYCLE_ORDER, self.currentHotbarCategory)
        if internalassert(oldCycleIndex ~= nil, "Current hotbar isn't defined in cycle") then
            local newCycleIndex = oldCycleIndex
            local cycleLength = #HOTBAR_CYCLE_ORDER
            repeat
                newCycleIndex = (newCycleIndex % cycleLength) + 1
            until newCycleIndex == oldCycleIndex or self:GetHotbar(HOTBAR_CYCLE_ORDER[newCycleIndex]):IsInCycle()

            internalassert(newCycleIndex ~= oldCycleIndex, "no other hotbar found in cycle, cycling requires at least 2 hotbars")
            self:SetCurrentHotbar(HOTBAR_CYCLE_ORDER[newCycleIndex])
        end
    end
end

function ZO_ActionBarAssignmentManager:SetIsHotbarSwapAnimationPlaying(isHotbarSwapAnimationPlaying)
    self.isHotbarSwapAnimationPlaying = isHotbarSwapAnimationPlaying
end

function ZO_ActionBarAssignmentManager:IsHotbarSwapAnimationPlaying()
    return self.isHotbarSwapAnimationPlaying
end

function ZO_ActionBarAssignmentManager:SetCurrentHotbar(hotbarCategory)
    if self.hotbars[hotbarCategory] == nil then
        internalassert(false, "Invalid hotbar category")
        return
    end

    local oldHotbarCategory = self.currentHotbarCategory
    self.currentHotbarCategory = hotbarCategory
    self.shouldUpdateWeaponSwapState = true
    
    self:UpdateWeaponSwapState()
    self:FireCallbacks("CurrentHotbarUpdated", hotbarCategory, oldHotbarCategory)
end

function ZO_ActionBarAssignmentManager:IsUltimateSlot(actionSlotIndex)
    return actionSlotIndex == ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
end

function ZO_ActionBarAssignmentManager:TryToSlotNewSkill(skillData)
    local hotbar = self:GetCurrentHotbar()
    local actionSlotIndex = hotbar:FindEmptySlotForSkill(skillData)
    -- We check if GetExpectedSkillSlotResult() here is valid ahead of time to supress the alert the Assign() would otherwise trigger for an invalid result. If we would fail, fail silently instead.
    -- There is also an encoded assumption here that any empty slot is as good as any other slot for the GetExpectedSkillSlotResult(), so we only need to check one before bailing out.
    if actionSlotIndex and hotbar:GetExpectedSkillSlotResult(actionSlotIndex, skillData) == HOT_BAR_RESULT_SUCCESS then
        hotbar:AssignSkillToSlot(actionSlotIndex, skillData)
        return true
    end
    return false
end

function ZO_ActionBarAssignmentManager:ClearAllSlotsWithSkill(skillData)
    for _, hotbar in pairs(self.hotbars) do
        local actionSlotIndex = hotbar:FindSlotMatchingSkill(skillData)
        if actionSlotIndex then
            hotbar:ClearSlot(actionSlotIndex)
        end
    end
end

ZO_ActionBarAssignmentManager:New()