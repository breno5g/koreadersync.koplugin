local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local ObsidianSync = WidgetContainer:extend({
	name = "obsidiansync",
	is_doc_only = false,
})

function ObsidianSync:init()
	self.ui.menu:registerToMainMenu(self)
end

function ObsidianSync:addToMainMenu(menu_items)
	menu_items.obsidiansync = {
		text = _("Obsidian Sync"),
		sorting_hint = "tools",
		sub_item_table = {
			{
				text = _("Export Hightlights"),
				callback = function()
					self:hello()
				end,
			},
		},
	}
end

function ObsidianSync:hello()
	UIManager:show(InfoMessage:new({
		text = _("Hello, plugin world"),
	}))
end

return ObsidianSync
