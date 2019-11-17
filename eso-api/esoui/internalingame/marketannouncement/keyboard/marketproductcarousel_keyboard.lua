--
-- ZO_MarketProductCarousel_Keyboard
--

ZO_MarketProductCarousel_Keyboard = ZO_MarketProductCarousel_Shared:Subclass()

function ZO_MarketProductCarousel_Keyboard:New(...)
    return ZO_MarketProductCarousel_Shared.New(self, ...)
end

function ZO_MarketProductCarousel_Keyboard:Initialize(...)
    ZO_MarketProductCarousel_Shared.Initialize(self, ...)

    self.selectionIndicator:SetButtonControlName("MarketProduct_Indicator_Keyboard")
    self:SetOnControlClicked(function(clickedControl, button, upInside) clickedControl.object:OnMouseUp() end) 

    local function OnSelectedDataChanged()
        self:OnSelectedDataChanged()
    end

    self:SetOnSelectedDataChangedCallback(OnSelectedDataChanged)
end

function ZO_MarketProductCarousel_Keyboard:SetNumProductAnnouncements(numProducts)
    ZO_MarketProductCarousel_Shared.SetNumProductAnnouncements(self, numProducts)

    -- Add each pip button to each of the scroll list tile's mouseover group
    for _, control in ipairs(self.controls) do
        for i = 1, numProducts do
            local button = self.selectionIndicator:GetButtonByIndex(i)
            control.object:AddMouseOverElement(button)
        end
    end
end

function ZO_MarketProductCarousel_Keyboard:OnSelectedDataChanged()
    local centerControl = self:GetCenterControl()
    if centerControl and centerControl.object then
        centerControl.object:UpdateHelpVisibility(centerControl.object.isMousedOver)
    end
end

function ZO_MarketProductCarousel_Keyboard:UpdateSelection(index)
    ZO_MarketProductCarousel_Shared.UpdateSelection(self, index)

    self:OnSelectedDataChanged()
end

function ZO_MarketProductCarousel_Keyboard:ResetScrollToTop()
    local data = self:GetSelectedData()
    local marketProduct = data and data.marketProduct
    if marketProduct then
        local descriptionControl = marketProduct:GetDescriptionControl()
        if descriptionControl then
            ZO_Scroll_ResetToTop(descriptionControl)
        end
    end
end