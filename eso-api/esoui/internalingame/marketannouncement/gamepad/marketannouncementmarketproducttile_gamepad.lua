----
-- ZO_MarketAnnouncementMarketProductTile_Gamepad
----

-- Primary logic class must be subclassed after the platform class so that platform specific functions will have priority over the logic class functionality
ZO_MarketAnnouncementMarketProductTile_Gamepad = ZO_Object.MultiSubclass(ZO_ActionTile_Gamepad, ZO_MarketAnnouncementMarketProductTile)

function ZO_MarketAnnouncementMarketProductTile_Gamepad:New(...)
    return ZO_MarketAnnouncementMarketProductTile.New(self, ...)
end

function ZO_MarketAnnouncementMarketProductTile_Gamepad:InitializePlatform()
    ZO_ActionTile_Gamepad.InitializePlatform(self)

    self.helpButtonKeybindDescriptor = 
    {
        name = GetString(SI_MARKET_ANNOUNCEMENT_HELP_BUTTON),
        keybind = "UI_SHORTCUT_SECONDARY",
        sound = function()
             if self:IsActionAvailable() then
                return SOUNDS.DIALOG_ACCEPT
            else
                return SOUNDS.DIALOG_DECLINE
            end
        end,
        visible = function()
            return self:IsHelpButtonKeybindVisible()
        end,
        callback = function()
            if self.marketProduct then
                local helpCategoryIndex, helpIndex = GetMarketAnnouncementHelpLinkIndices(self.marketProduct:GetId())
                RequestShowSpecificHelp(helpCategoryIndex, helpIndex)
            end
        end
    }
end

function ZO_MarketAnnouncementMarketProductTile_Gamepad:IsHelpButtonKeybindVisible()
    local helpCategoryIndex, helpIndex = GetMarketAnnouncementHelpLinkIndices(self.marketProduct:GetId())
    local hasHelpLink = helpCategoryIndex and helpIndex
    return self.marketProduct:IsPromo() and hasHelpLink
end

function ZO_MarketAnnouncementMarketProductTile_Gamepad:Layout(data)
    ZO_MarketAnnouncementMarketProductTile.Layout(self, data)

    local tile = self.control.object
    tile:SetActionCallback(function() ZO_GAMEPAD_MARKET_ANNOUNCEMENT:OnMarketAnnouncementViewCrownStoreKeybind() end)
end

function ZO_MarketAnnouncementMarketProductTile_Gamepad:LayoutPlatform(data)
    -- The Tile_Gamepad version of this function calls SetSelected. The overridden SetSelected in this class expects
    -- the marketProduct to be updated, but that update doesn't happen until after this function is called.
    -- So if SetSelected is called from this function it will set the wrong marketProduct to have focus.
    -- We are overriding this function to avoid that.
end

function ZO_MarketAnnouncementMarketProductTile_Gamepad:SetSelected(isSelected)
    ZO_ActionTile_Gamepad.SetSelected(self, isSelected)

    if self.marketProduct then
        self.marketProduct:SetIsFocused(isSelected)

        -- Set hidden state for help keybind if marketProduct is a promo product
        if self.keybindButton and self.keybindAnchorControl and self.keybindHelpButton and self.keybindHelpButton:GetKeybindButtonDescriptorReference() == self.helpButtonKeybindDescriptor then
            if isSelected then
                if self:IsHelpButtonKeybindVisible() then
                    self.keybindButton:SetAnchor(TOPRIGHT, self.keybindHelpButton, TOPLEFT)
                    self.keybindHelpButton:SetAnchor(TOPRIGHT, self.keybindAnchorControl, TOPLEFT)
                    self.keybindHelpButton:SetHidden(false)
                else
                    self.keybindButton:SetAnchor(TOPRIGHT, self.keybindAnchorControl, TOPLEFT)
                    self.keybindHelpButton:SetHidden(true)
                end
            end
        end
    end
end

function ZO_MarketAnnouncementMarketProductTile_Gamepad:UpdateKeybindButton()
    ZO_ActionTile_Gamepad.UpdateKeybindButton(self)

    if self.keybindHelpButton and self:IsSelected() then
        self.keybindHelpButton:SetKeybindButtonDescriptor(self.helpButtonKeybindDescriptor)
    end
end

function ZO_MarketAnnouncementMarketProductTile_Gamepad:SetHelpKeybindButton(keybindHelpButton)
    self.keybindHelpButton = keybindHelpButton
end

function ZO_MarketAnnouncementMarketProductTile_Gamepad:SetKeybindAnchorControl(keybindAnchorControl)
    self.keybindAnchorControl = keybindAnchorControl
end

-----
-- Global XML Functions
-----

function ZO_MarketAnnouncementMarketProductTile_Gamepad_OnInitialized(control)
    ZO_MarketAnnouncementMarketProduct_Shared_OnInitialized(control)
    ZO_MarketAnnouncementMarketProductTile_Gamepad:New(control)
end