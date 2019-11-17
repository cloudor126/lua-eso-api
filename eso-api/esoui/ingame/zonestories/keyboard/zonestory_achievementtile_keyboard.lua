ZO_ZONE_STORIES_ACHIEVEMENT_TILE_KEYBOARD_DIMENSIONS_X = 284
ZO_ZONE_STORIES_ACHIEVEMENT_TILE_KEYBOARD_DIMENSIONS_Y = 64
ZO_ZONE_STORIES_ACHIEVEMENT_TILE_KEYBOARD_ICON_DIMENSIONS = 64

-- Primary logic class must be subclassed after the platform class so that platform specific functions will have priority over the logic class functionality
ZO_ZoneStory_AchievementTile_Keyboard = ZO_Object.MultiSubclass(ZO_Tile_Keyboard, ZO_ZoneStory_AchievementTile)

function ZO_ZoneStory_AchievementTile_Keyboard:New(...)
    return ZO_ZoneStory_AchievementTile.New(self, ...)
end

function ZO_ZoneStory_AchievementTile_Keyboard:OnMouseEnter()
    ZO_Tile_Keyboard.OnMouseEnter(self)

    local offsetX = self.control:GetParent():GetLeft() - self.control:GetLeft() - 15
    local anchor = ZO_Anchor:New(RIGHT, self.control, LEFT, offsetX)

    ACHIEVEMENTS:ShowAchievementDetailedTooltip(self.achievementId, anchor)
end

function ZO_ZoneStory_AchievementTile_Keyboard:OnMouseExit()
    ZO_Tile_Keyboard.OnMouseExit(self)

    ACHIEVEMENTS:HideAchievementDetailedTooltip()
end

function ZO_ZoneStory_AchievementTile_Keyboard_OnInitialized(control)
    ZO_ZoneStory_AchievementTile_Keyboard:New(control)
end