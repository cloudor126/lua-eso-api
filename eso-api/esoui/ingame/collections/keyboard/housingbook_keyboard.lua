--Layout constants--
local BACKGROUND_IMAGE_FILE_WIDTH = 1024
local BACKGROUND_IMAGE_FILE_HEIGHT = 512
local BACKGROUND_IMAGE_CONTENT_WIDTH = 700
local BACKGROUND_IMAGE_CONTENT_HEIGHT = 350
local INFO_PANEL_WIDTH = 614
ZO_HOUSING_BOOK_IMAGE_TEXTURE_COORD_RIGHT = BACKGROUND_IMAGE_CONTENT_WIDTH / BACKGROUND_IMAGE_FILE_WIDTH
ZO_HOUSING_BOOK_IMAGE_TEXTURE_COORD_BOTTOM = BACKGROUND_IMAGE_CONTENT_HEIGHT / BACKGROUND_IMAGE_FILE_HEIGHT
ZO_HOUSING_BOOK_IMAGE_HEIGHT = (INFO_PANEL_WIDTH / BACKGROUND_IMAGE_CONTENT_WIDTH) * BACKGROUND_IMAGE_CONTENT_HEIGHT

--Housing Book

local HousingBook_Keyboard = ZO_SpecializedCollectionsBook_Keyboard:Subclass()

function HousingBook_Keyboard:New(...)
    return ZO_SpecializedCollectionsBook_Keyboard.New(self, ...)
end

function HousingBook_Keyboard:InitializeControls()
    ZO_SpecializedCollectionsBook_Keyboard.InitializeControls(self)
    
    local contents = self.control:GetNamedChild("Contents")
    self.nicknameLabel = contents:GetNamedChild("Nickname")

    local scrollSection = contents:GetNamedChild("ScrollContainer"):GetNamedChild("ScrollChild")
    self.locationLabel = scrollSection:GetNamedChild("LocationLabel")
    self.houseTypeLabel = scrollSection:GetNamedChild("HouseTypeLabel")
    self.primaryResidenceLabel = scrollSection:GetNamedChild("PrimaryResidenceLabel")
    self.hintLabel = scrollSection:GetNamedChild("HintLabel")

    local buttons = contents:GetNamedChild("HousingInteractButtons")
    self.travelToHouseButton = buttons:GetNamedChild("TravelToHouse")
    self.changeNicknameButton = buttons:GetNamedChild("ChangeNickname")

    self.previewHouseButton = contents:GetNamedChild("PreviewHouseButton")
end

function HousingBook_Keyboard:InitializeEvents()
    ZO_SpecializedCollectionsBook_Keyboard.InitializeEvents(self)

    ZO_COLLECTIBLE_DATA_MANAGER:RegisterCallback("PrimaryResidenceSet", function() self:RefreshList() end)
end

function HousingBook_Keyboard:RefreshDetails()
    ZO_SpecializedCollectionsBook_Keyboard.RefreshDetails(self)
    local collectibleData = self.navigationTree:GetSelectedData()

    if collectibleData then
        local nickname = collectibleData:GetFormattedNickname()
        local hasNickname = nickname ~= ""
        if hasNickname then
            self.nicknameLabel:SetText(nickname)
        end
        self.nicknameLabel:SetHidden(not hasNickname)
        
        local isUnlocked = collectibleData:IsUnlocked()
        local canJumpToHouse = CanJumpToHouseFromCurrentLocation()
        self.locationLabel:SetText(zo_strformat(SI_HOUSING_BOOK_LOCATION_FORMATTER, collectibleData:GetHouseLocation()))
        self.houseTypeLabel:SetText(zo_strformat(SI_HOUSING_BOOK_HOUSE_TYPE_FORMATTER, GetString("SI_HOUSECATEGORYTYPE", collectibleData:GetHouseCategoryType())))
        if not canJumpToHouse then
            local disableReason = isUnlocked and GetString(SI_COLLECTIONS_CANNOT_JUMP_TO_HOUSE_FROM_LOCATION) or GetString(SI_COLLECTIONS_CANNOT_PREVIEW_HOUSE_FROM_LOCATION)
            self.hintLabel:SetText(ZO_ERROR_COLOR:Colorize(disableReason))
            
            self.hintLabel:SetHidden(false)
            self.primaryResidenceLabel:SetHidden(true)
        elseif isUnlocked then
            local isPrimaryResidence = collectibleData:IsPrimaryResidence() and GetString(SI_YES) or GetString(SI_NO)
            self.primaryResidenceLabel:SetText(zo_strformat(SI_HOUSING_BOOK_PRIMARY_RESIDENCE_FORMATTER, isPrimaryResidence))
            
            self.primaryResidenceLabel:SetHidden(false)
            self.hintLabel:SetHidden(true)
        else
            self.hintLabel:SetText(collectibleData:GetHint())
            
            self.hintLabel:SetHidden(false)
            self.primaryResidenceLabel:SetHidden(true)
        end

        self.travelToHouseButton:SetHidden(not isUnlocked)
        self.changeNicknameButton:SetHidden(not isUnlocked)
        self.previewHouseButton:SetHidden(isUnlocked)

        self.travelToHouseButton:SetEnabled(canJumpToHouse)
        self.previewHouseButton:SetEnabled(canJumpToHouse)
    end
end

function HousingBook_Keyboard:RenameCurrentHouse()
    local collectibleData = self.navigationTree:GetSelectedData()
    if collectibleData then
        ZO_CollectionsBook.ShowRenameDialog(collectibleData:GetId())
    end
end

function HousingBook_Keyboard:RequestJumpToCurrentHouse()
    local collectibleData = self.navigationTree:GetSelectedData()
    if collectibleData then
        RequestJumpToHouse(collectibleData:GetReferenceId())
    end
end

function HousingBook_Keyboard:GetCategoryFilterFunctions()
    return { ZO_CollectibleCategoryData.IsHousingCategory }
end

function HousingBook_Keyboard:IsCollectibleRelevant(collectibleData)
    return collectibleData:IsHouse()
end

function ZO_HousingBook_Keyboard_OnRequestJumpToHouseClicked(control)
    HOUSING_BOOK_KEYBOARD:RequestJumpToCurrentHouse()
    SCENE_MANAGER:ShowBaseScene()
end

function ZO_HousingBook_Keyboard_OnChangNicknameClicked(control)
    HOUSING_BOOK_KEYBOARD:RenameCurrentHouse()
end

function ZO_HousingBook_Keyboard_OnInitialized(control)
    HOUSING_BOOK_KEYBOARD = HousingBook_Keyboard:New(control, "housingBook", ZO_SpecializedCollectionsBook_Keyboard_CategoryLayout_UnlockState)
end