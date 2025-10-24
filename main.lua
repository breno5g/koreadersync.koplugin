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
				text = _("Debug info"),
				callback = function()
					self:debug()
				end,
			},
		},
	}
end

function ObsidianSync:info(message)
	UIManager:show(InfoMessage:new({
		text = _(message),
	}))
end

function ObsidianSync:getFileNameAndExtension()
	local path = self.ui.document.file
	local info = {
		dirname = path:match("(.+)/[^/]+$"),
		filename = path:match("([^/]+)%."),
		extension = path:match("%.([^%.]+)$"),
	}

	return info
end

function ObsidianSync:getSDRData()
	if not self.ui.document then
		self:info("❌ Open a document to proced")
		return
	end

	local fileInfo = self:getFileNameAndExtension()
	local chunk, err =
		loadfile(fileInfo.dirname .. "/" .. fileInfo.filename .. ".sdr/metadata." .. fileInfo.extension .. ".lua")
	if not chunk then
		self:info("❌ Error to open sdr: " .. err)
		return
	end

	local metadata = chunk()
	self:info(metadata["annotations"][1]["text"])
end

function ObsidianSync:debug()
	local info = {}

	table.insert(info, "====== DEBUG INFO ======")
	table.insert(info, "")

	if not self.ui.document then
		table.insert(info, "❌ Open a document to proced")
		self:info(table.concat(info, "\n"))
		return
	end

	local fileInfo = self:getFileNameAndExtension()
	table.insert(info, "✅ Document infos:")
	table.insert(info, "- Dirname: " .. fileInfo.dirname)
	table.insert(info, "- Filename: " .. fileInfo.filename)
	table.insert(info, "- Extension: " .. fileInfo.extension)

	self:info(table.concat(info, "\n"))
end

return ObsidianSync
