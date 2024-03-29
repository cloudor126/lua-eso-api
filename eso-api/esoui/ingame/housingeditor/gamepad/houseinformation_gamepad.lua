ZO_HouseInformation_Gamepad = ZO_HouseInformation_Shared:Subclass()

local CHILD_VERTICAL_PADDING = 15
local SECTION_VERTICAL_PADDING = 70

function ZO_HouseInformation_Gamepad:New(...)
    return ZO_HouseInformation_Shared.New(self, ...)
end

function ZO_HouseInformation_Gamepad:Initialize(control)
    HOUSE_INFORMATION_FRAGMENT_GAMEPAD = ZO_FadeSceneFragment:New(control)
    
    ZO_HouseInformation_Shared.Initialize(self, control:GetNamedChild("Container"), HOUSE_INFORMATION_FRAGMENT_GAMEPAD, "ZO_HousingFurnitureBrowser_Gamepad_Row", CHILD_VERTICAL_PADDING, SECTION_VERTICAL_PADDING)
end

function ZO_HouseInformation_Gamepad_OnInitialize(control)
    HOUSE_INFORMATION_GAMEPAD = ZO_HouseInformation_Gamepad:New(control)
end