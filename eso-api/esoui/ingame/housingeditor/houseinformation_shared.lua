ZO_HouseInformation_Shared = ZO_Object:Subclass()

function ZO_HouseInformation_Shared:New(...)
    local houseInformation = ZO_Object.New(self)
    houseInformation:Initialize(...)
    return houseInformation
end

function ZO_HouseInformation_Shared:Initialize(control, fragment, rowTemplate, childVerticalPadding, sectionVerticalPadding)
    self.control = control
    self.rowTemplate = rowTemplate
    self.childVerticalPadding = childVerticalPadding
    self.sectionVerticalPadding = sectionVerticalPadding

    self:SetupControls()
    
    fragment:RegisterCallback("StateChange", function(oldState, newState)
                                                 if newState == SCENE_SHOWING then
                                                     self:UpdateHouseInformation()
                                                     self:UpdateHousePopulation()
                                                     self:UpdateLimits()
                                                 end
                                             end)
    
    local function RefreshItemLimits()
        if fragment:IsShowing() then
            self:UpdateLimits()
        end
    end

    local function RefreshHouseInformation()
        if fragment:IsShowing() then
            self:UpdateHouseInformation()
        end
    end

    local function RefreshHousePopulation(eventId, population)
        if fragment:IsShowing() then
            self:UpdateHousePopulation(population)
        end
    end

    control:RegisterForEvent(EVENT_HOUSING_FURNITURE_PLACED, RefreshItemLimits)
    control:RegisterForEvent(EVENT_HOUSING_FURNITURE_REMOVED, RefreshItemLimits)
    control:RegisterForEvent(EVENT_HOUSING_PRIMARY_RESIDENCE_SET, RefreshHouseInformation)
    control:RegisterForEvent(EVENT_HOUSING_POPULATION_CHANGED, RefreshHousePopulation)
end

do
    local function SetupRow(rootControl, controlName)
        local rowControl = rootControl:GetNamedChild(controlName)
        rowControl.nameLabel = rowControl:GetNamedChild("Name")
        rowControl.valueLabel = rowControl:GetNamedChild("Value")
        return rowControl
    end
    
    function ZO_HouseInformation_Shared:SetupControls()
        self.nameRow = SetupRow(self.control, "NameRow")
        self.locationRow = SetupRow(self.control, "LocationRow")
        self.ownerRow = SetupRow(self.control, "OwnerRow")
        self.infoSection = SetupRow(self.control, "InfoSection")
        self.primaryResidenceRow = SetupRow(self.control, "PrimaryResidenceRow")
        self.currentVisitorsRow = SetupRow(self.control, "CurrentVisitorsRow")
        self.overPopulationWarning = self.currentVisitorsRow:GetNamedChild("Help")
    
        local furnishingLimits = self.infoSection:GetNamedChild("FurnishingLimits")
        local lastRow = nil
        self.limitRows = {}
        for i = HOUSING_FURNISHING_LIMIT_TYPE_ITERATION_BEGIN, HOUSING_FURNISHING_LIMIT_TYPE_ITERATION_END do
            local furnishingLimitRow = CreateControlFromVirtual(furnishingLimits:GetName().."Row"..i, furnishingLimits, self.rowTemplate)
    
            if not lastRow then
                furnishingLimitRow:SetAnchor(TOPLEFT)
            else
                furnishingLimitRow:SetAnchor(TOPLEFT, lastRow, BOTTOMLEFT, 0, self.childVerticalPadding)
            end
            lastRow = furnishingLimitRow
            self.limitRows[i] = SetupRow(furnishingLimits, "Row"..i)
        end
    end
end

function ZO_HouseInformation_Shared:UpdateHouseInformation()
    local currentHouseId = GetCurrentZoneHouseId()
    local houseCollectibleId = GetCollectibleIdForHouse(currentHouseId)
    local houseCollectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(houseCollectibleId)

    local isPrimaryHouse = IsPrimaryHouse(currentHouseId)

    self.nameRow.valueLabel:SetText(houseCollectibleData:GetFormattedName())
    self.locationRow.valueLabel:SetText(houseCollectibleData:GetFormattedHouseLocation())
    self.primaryResidenceRow.valueLabel:SetText(isPrimaryHouse and GetString(SI_YES) or GetString(SI_NO))

    local ownerDisplayName = GetCurrentHouseOwner()
    if ownerDisplayName ~= "" then
        self.ownerRow.valueLabel:SetText(ZO_FormatUserFacingDisplayName(ownerDisplayName))
        self.ownerRow:SetHidden(false)
        self.infoSection:SetAnchor(TOPLEFT, self.ownerRow, BOTTOMLEFT, 0, self.sectionVerticalPadding)
    else
        self.ownerRow:SetHidden(true)
        self.infoSection:SetAnchor(TOPLEFT, self.locationRow, BOTTOMLEFT, 0, self.sectionVerticalPadding)
    end
end

function ZO_HouseInformation_Shared:UpdateHousePopulation(population)
    local currentPopulation = population or GetCurrentHousePopulation()
    local maxPopulation = GetCurrentHousePopulationCap()
    self.currentVisitorsRow.valueLabel:SetText(zo_strformat(SI_HOUSE_INFORMATION_COUNT_FORMAT, currentPopulation, maxPopulation));
    
    local overpopulated = currentPopulation > maxPopulation
    self.overPopulationWarning:SetHidden(not overpopulated)
end

do
    local function UpdateRow(rowControl, name, value)
        rowControl.nameLabel:SetText(name)
        rowControl.valueLabel:SetText(value)
    end
    
    function ZO_HouseInformation_Shared:UpdateLimits()
        local currentHouseId = GetCurrentZoneHouseId()
    
        for i = HOUSING_FURNISHING_LIMIT_TYPE_ITERATION_BEGIN, HOUSING_FURNISHING_LIMIT_TYPE_ITERATION_END do
            local limit = GetHouseFurnishingPlacementLimit(currentHouseId, i)
            local currentlyPlaced = GetNumHouseFurnishingsPlaced(i)
            UpdateRow(self.limitRows[i], GetString("SI_HOUSINGFURNISHINGLIMITTYPE", i), zo_strformat(SI_HOUSE_INFORMATION_COUNT_FORMAT, currentlyPlaced, limit))
        end
    end
end