--[[
    Gamepad Trading House Filter differs from Trading House filter in some important ways. Trading House Filter utilizes static comboboxes that 
    are show/hidden/re-anchored according to the global filter data (found in TradingHouseFilter_Shared.lua). The gamepad design calls for the filter
    combo boxes to be used inside a parametric list. Because the filter Combo boxes are in a parametric list we have to be careful as the controls 
    will be reused by the parametric list internals. We also need to make sure that we ensure correct behavior regardless of the number of times initialize 
    is called. We also can't guarantee any order that these functions will be called in. All this requires extra book keeping and re-initializations.
--]]

local IGNORE_CALLBACK = true

local function InitializeComboBox(comboBox, data, callback, lastName, lastIndex)
    if not data then return end
    if lastIndex and lastIndex > comboBox:GetNumItems() then
        lastIndex = 1
    end

    comboBox:ClearItems()
    
    local selectFirstItem = lastName == nil or lastIndex == 1
    local DONT_SELECT_FIRST_ITEM = false
    ZO_TradingHouse_InitializeColoredComboBox(comboBox, data, callback, nil, nil, DONT_SELECT_FIRST_ITEM)
    --All of the selection callbacks depend on querying the highlighted item instead of the selected item so we have to set that first
    --before the selected item changed callback.
    comboBox:SetHighlightedItem(lastIndex)
    if selectFirstItem then
        comboBox:SelectFirstItem()
    else
        comboBox:SelectItemByIndex(lastIndex, IGNORE_CALLBACK)
    end
end

--[[ Gamepad Trading House Filter ]]--

ZO_GamepadTradingHouse_Filter = ZO_Object:Subclass()

function ZO_GamepadTradingHouse_Filter:New(...)
    local filter = ZO_Object.New(self)
    filter:Initialize(...)
    return filter
end

function ZO_GamepadTradingHouse_Filter:Initialize(traitType, enchantmentType)
    self.traitType = traitType
    self.enchantmentType = enchantmentType
    self.isInitialized = true
end

function ZO_GamepadTradingHouse_Filter:IsInitialized()
    return self.isInitialized
end

function ZO_GamepadTradingHouse_Filter:SetComboBoxes(filterComboBoxData)
    GAMEPAD_TRADING_HOUSE_BROWSE:ResetList(filterComboBoxData)
end

function ZO_GamepadTradingHouse_Filter:RemoveComboBoxes()
    GAMEPAD_TRADING_HOUSE_BROWSE:ResetList()
end

function ZO_GamepadTradingHouse_Filter:AddMods(filterComboBoxData)
    if self.traitType then
        assert(not self.traitAdded) -- This should only ever be added once. Use SetVisible to control the trait filter combo box visibility

        local data = SYSTEMS:GetGamepadObject(ZO_TRADING_HOUSE_SYSTEM_NAME):GetTraitFilters():GetComboBoxData()
        table.insert(filterComboBoxData, data)
        self.traitComboBoxData = filterComboBoxData[#filterComboBoxData]
        self.traitAdded = true
    end

    if self.enchantmentType then
        assert(not self.enchantmentAdded) -- This should only ever be added once. Use SetVisible to control the enchantment filter combo box visibility
        
        local data = SYSTEMS:GetGamepadObject(ZO_TRADING_HOUSE_SYSTEM_NAME):GetEnchantmentFilters():GetComboBoxData()
        table.insert(filterComboBoxData, data)
        self.enchantmentComboBoxData = filterComboBoxData[#filterComboBoxData]
        self.enchantmentAdded = true
    end
end

function ZO_GamepadTradingHouse_Filter:SetTraitType(traitType)
    self.traitType = traitType
    local traits = SYSTEMS:GetGamepadObject(ZO_TRADING_HOUSE_SYSTEM_NAME):GetTraitFilters()

    if self.traitAdded and self.traitType then
        traits:SetType(self.traitType)
        traits:SetVisible(true)
    else
        traits:SetVisible(false)
    end
end
    
function ZO_GamepadTradingHouse_Filter:SetEnchantmentType(enchantmentType)
    self.enchantmentType = enchantmentType
    local enchantments = SYSTEMS:GetGamepadObject(ZO_TRADING_HOUSE_SYSTEM_NAME):GetEnchantmentFilters()

    if self.enchantmentAdded and self.enchantmentType then
        enchantments:SetType(self.enchantmentType)
        enchantments:SetVisible(true)
    else
        enchantments:SetVisible(false)
    end
end

function ZO_GamepadTradingHouse_Filter:ApplyToSearch(search)
    if self.traitType then
        SYSTEMS:GetGamepadObject(ZO_TRADING_HOUSE_SYSTEM_NAME):GetTraitFilters():ApplyToSearch(search)
    end

    if self.enchantmentType then
        SYSTEMS:GetGamepadObject(ZO_TRADING_HOUSE_SYSTEM_NAME):GetEnchantmentFilters():ApplyToSearch(search)
    end
end

function ZO_GamepadTradingHouse_Filter:SetHidden(hidden)
    if hidden then
        self:RemoveComboBoxes()
    else
        -- Update trait and enchantment filters
        self:SetTraitType(self.traitType)
        self:SetEnchantmentType(self.enchantmentType)
        self:SetComboBoxes(self:GetComboBoxData())
    end
end

--[[ Gamepad ModFilter ]]--

-- Used with enchantments and traits. These filters are requested to be added by other filters.

ZO_GamepadTradingHouse_ModFilter = ZO_TradingHouseSearchFieldSetter:Subclass()

function ZO_GamepadTradingHouse_ModFilter:New(...)
    return ZO_TradingHouseComboBoxSetter.New(self, ...)
end

function ZO_GamepadTradingHouse_ModFilter:Initialize(name, filterDataContainer, modFilterType)
    ZO_TradingHouseSearchFieldSetter.Initialize(self, modFilterType)
    self.filterDataContainer = filterDataContainer

    self.filterComboBoxData = 
    {
        name = name,
        initCallback = function(comboBox) self:InitializeComboBox(comboBox) end,
        visible = true
    }

    self.lastFilterIndex = 1
    self.isInitialized = true
end

function ZO_GamepadTradingHouse_ModFilter:IsInitialized()
    return self.isInitialized
end

function ZO_GamepadTradingHouse_ModFilter:SetVisible(visible)
    self.filterComboBoxData.visible = visible
end

function ZO_GamepadTradingHouse_ModFilter:GetComboBoxData()
    return self.filterComboBoxData
end

function ZO_GamepadTradingHouse_ModFilter:SetType(filterType)
	self.filterData = self.filterDataContainer[filterType]
    
    self.lastFilterEntryName = nil
    self.lastFilterIndex = 1
end

function ZO_GamepadTradingHouse_ModFilter:OnFilterSelectionChanged(comboBox, entryName, entry)
    local selectionChanged = self.lastFilterEntryName ~= entryName
    self.lastFilterEntryName = entryName
    self.m_min = entry.minValue
    self.m_max = entry.maxValue

    if selectionChanged then
        self.lastFilterIndex = comboBox:GetHighlightedIndex()
    end

    ZO_TradingHouse_SearchCriteriaChanged(selectionChanged)
end

function ZO_GamepadTradingHouse_ModFilter:InitializeComboBox(comboBox)
    self.m_comboBox = comboBox
    InitializeComboBox(comboBox, self.filterData, function(...) self:OnFilterSelectionChanged(...) end, self.lastFilterEntryName, self.lastFilterIndex)
end

--[[ Gamepad Category Filter ]]--

-- Used with Consumables, Misc. Filters, and Soul Gems

ZO_GamepadCategoryFilter = ZO_GamepadTradingHouse_Filter:Subclass()

function ZO_GamepadCategoryFilter:New(...)
    return ZO_GamepadTradingHouse_Filter.New(self, ...)
end

function ZO_GamepadCategoryFilter:Initialize(name, filterData, traitType, enchantmentType)
    ZO_GamepadTradingHouse_Filter.Initialize(self, traitType, enchantmentType)
    self.name = name
    self.filterData = filterData
    self.lastFilterCategoryIndex = 1

    self.filterComboBoxData = 
    { 
        {
            name = "GuildStoreBrowseFilterCategoryFilter" .. self.name, 
            initCallback = function(comboBox)
                self:InitializeFilterCategoryComboBox(comboBox)
            end,
            visible = true
        }
    }

    ZO_GamepadTradingHouse_Filter.AddMods(self, self.filterComboBoxData)
end

function ZO_GamepadCategoryFilter:GetComboBoxData()
    return self.filterComboBoxData
end

function ZO_GamepadCategoryFilter:InitializeFilterCategoryComboBox(comboBox)
    self.filterCategoryComboBox = comboBox
    InitializeComboBox(comboBox, self:GetFilterData(), function(...) self:OnCategorySelection(...) end, self.lastFilterCategoryName, self.lastFilterCategoryIndex)
end

function ZO_GamepadCategoryFilter:GetFilterData()
    return self.filterData
end

function ZO_GamepadCategoryFilter:SetCategoryType(entry)
    self.categoryType = entry.minValue
end

function ZO_GamepadCategoryFilter:OnCategorySelection(comboBox, entryName, entry)
	local selectionChanged = self.lastFilterCategoryName ~= entryName
    self.lastFilterCategoryName = entryName
    self.lastFilterCategoryIndex = comboBox:GetHighlightedIndex()
    self:SetCategoryType(entry)
    ZO_TradingHouse_SearchCriteriaChanged(selectionChanged)
end

function ZO_GamepadCategoryFilter:ApplyToSearch(search)
    search:SetFilter(TRADING_HOUSE_FILTER_TYPE_ITEM, self.categoryType)
    ZO_GamepadTradingHouse_Filter.ApplyToSearch(self, search)
end

function ZO_GamepadCategoryFilter:SetComboBoxes(comboBoxes)
    self.lastFilterCategoryIndex = 1
    self.lastFilterCategoryName = nil
    ZO_GamepadTradingHouse_Filter.SetComboBoxes(self, comboBoxes)
end

--Combo Box Data

ZO_TradingHouse_Gamepad_ComboBoxData = ZO_Object:Subclass()

function ZO_TradingHouse_Gamepad_ComboBoxData:New(...)
   local object = ZO_Object.New(self)
   object:Initialize(...)
   return object 
end

function ZO_TradingHouse_Gamepad_ComboBoxData:Initialize(name, onChangeCallback)
    self.name = name
    self.lastSelectionIndex = 1
    self.visible = true
    self.onChangeCallback = onChangeCallback

    self.initCallback = function(comboBox)
        self.comboBox = comboBox
        InitializeComboBox(comboBox, self.data, self.onChangeCallback, self.lastSelectionText, self.lastSelectionIndex)
    end
end

function ZO_TradingHouse_Gamepad_ComboBoxData:GetData()
    return self.data
end

function ZO_TradingHouse_Gamepad_ComboBoxData:SetData(data)
    self.data = data
end

function ZO_TradingHouse_Gamepad_ComboBoxData:IsVisible()
    return self.visible
end

function ZO_TradingHouse_Gamepad_ComboBoxData:SetVisible(visible)
    self.visible = visible
end

function ZO_TradingHouse_Gamepad_ComboBoxData:GetSelectedEntryDataFromMemory()
    return self.data[self.lastSelectionIndex]
end

function ZO_TradingHouse_Gamepad_ComboBoxData:UpdateSelectedEntryMemory(entryName, entryIndex)
    if entryName ~= self.lastSelectionText then
        self.lastSelectionText = entryName
        self.lastSelectionIndex = entryIndex
        return true
    else
        return false
    end
end

function ZO_TradingHouse_Gamepad_ComboBoxData:ClearSelectedEntryMemory()
    self.lastSelectionText = nil
    self.lastSelectionIndex = 1
end

function ZO_TradingHouse_Gamepad_ComboBoxData:ReInitializeComboBox()
    self:ClearSelectedEntryMemory()
    if self.comboBox then
		self.initCallback(self.comboBox)
	end
end

--[[ Gamepad Category With Subtype Filter ]]--

-- used by Weapon, Armor, and Crafting Filters

ZO_CategorySubtypeFilter = ZO_GamepadTradingHouse_Filter:Subclass()

function ZO_CategorySubtypeFilter:New(...)
    return ZO_GamepadTradingHouse_Filter.New(self, ...)
end

function ZO_CategorySubtypeFilter:Initialize(name, filterData, traitType, enchantmentType)
    ZO_GamepadTradingHouse_Filter.Initialize(self, traitType, enchantmentType)
    self.name = name
    self.filterComboBoxData = {}
    self.comboBoxNameToFilterComboBoxData = {}

    self:AddFilterComboBoxData("Category", function(...) self:PopulateSubTypes(...) end)
    self:AddFilterComboBoxData("SubType", function(...) self:SetFilterSubType(...) end)
    local categoryComboBoxData = self:GetFilterComboBoxData("Category")
    categoryComboBoxData:SetData(filterData)

    ZO_GamepadTradingHouse_Filter.AddMods(self, self.filterComboBoxData)
end

function ZO_CategorySubtypeFilter:GetComboBoxData()
    return self.filterComboBoxData
end

function ZO_CategorySubtypeFilter:AddFilterComboBoxData(comboBoxName, onChangeCallback)
    local fullName = string.format("GuildStoreBrowseFilter%sFilter%s", comboBoxName, self.name)
    local comboBoxData = ZO_TradingHouse_Gamepad_ComboBoxData:New(fullName, onChangeCallback)
    table.insert(self.filterComboBoxData, comboBoxData)
    self.comboBoxNameToFilterComboBoxData[comboBoxName] = comboBoxData
    return comboBoxData
end

function ZO_CategorySubtypeFilter:GetFilterComboBoxData(comboBoxName)
    return self.comboBoxNameToFilterComboBoxData[comboBoxName]
end

function ZO_CategorySubtypeFilter:PopulateSubTypes(comboBox, entryName, entry)
    local categoryComboBoxData = self:GetFilterComboBoxData("Category")
    local subTypeComboBoxData = self:GetFilterComboBoxData("SubType")

	if categoryComboBoxData:UpdateSelectedEntryMemory(entryName, comboBox:GetHighlightedIndex()) then
        self:SetCategoryTypeAndSubData(entry)
        subTypeComboBoxData:ReInitializeComboBox()
        ZO_TradingHouse_SearchCriteriaChanged(true)
	end

end

function ZO_CategorySubtypeFilter:SetCategoryTypeAndSubData(entry)
    self.categoryType = entry.minValue
    local subTypeComboBoxData = self:GetFilterComboBoxData("SubType")
    subTypeComboBoxData:SetData(entry.maxValue)
end

function ZO_CategorySubtypeFilter:SetFilterSubType(comboBox, entryName, entry)
    local subTypeComboBoxData = self:GetFilterComboBoxData("SubType")    
    if subTypeComboBoxData:UpdateSelectedEntryMemory(entryName, comboBox:GetHighlightedIndex()) then
        self:SetSubType(entry)
        ZO_TradingHouse_SearchCriteriaChanged(true)
    end
end

function ZO_CategorySubtypeFilter:SetSubType(entry)
    self.m_FilterSubType = entry.minValue
    self.subcategoryEntry = entry
end

function ZO_CategorySubtypeFilter:GetFilterData()
    return self.filterData
end

function ZO_CategorySubtypeFilter:SetComboBoxes(comboBoxes)
    --Only wipe out the combo boxes we added, the rest will be handled by the parent class
    for comboBoxName, comboBoxData in pairs(self.comboBoxNameToFilterComboBoxData) do
        comboBoxData:ClearSelectedEntryMemory()
    end
    ZO_GamepadTradingHouse_Filter.SetComboBoxes(self, comboBoxes)
end