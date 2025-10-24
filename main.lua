local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local ObsidianSync = WidgetContainer:extend({
	name = "obsidiansync",
	is_doc_only = false,

	defaults = {
		address = "127.0.0.1",
		port = 9090,
		password = "",
	},
})

function ObsidianSync:init()
	self.settings = G_reader_settings:readSetting("obsidian_sync_settings", ObsidianSync.defaults)
	self.ui.menu:registerToMainMenu(self)
end

function ObsidianSync:addToMainMenu(menu_items)
	menu_items.obsidiansync = {
		text = _("Obsidian Sync"),
		sorting_hint = "tools",
		sub_item_table = {
			{
				text = _("Configure"),
				callback = function(touchmenu_instance)
					self:configure(touchmenu_instance)
				end,
			},
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
		filename = path:match("/([^/]+)%.[^%.]+$"),
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

	return metadata
end

function ObsidianSync:configure(touchmenu_instance)
	local MultiInputDialog = require("ui/widget/multiinputdialog")
	local url_dialog

	local current_settings = self.settings or G_reader_settings:readSetting("obsidian_sync_settings", ObsidianSync.defaults)

	local obsidian_url_address = current_settings.address
	local obsidian_url_port = current_settings.port
	local obsidian_password = current_settings.password

	url_dialog = MultiInputDialog:new({
		title = _("Set custom obsidian address"),
		fields = {
			{
				text = obsidian_url_address,
				input_type = "string",
				hint = _("IP Address"),
			},
			{
				text = tostring(obsidian_url_port),
				input_type = "number",
				hint = _("Port"),
			},
			{
				text = obsidian_password,
				input_type = "string",
				hint = _("Password"),
			},
		},
		buttons = {
			{
				{
					text = _("Cancel"),
					id = "close",
					callback = function()
						UIManager:close(url_dialog)
					end,
				},
				{
					text = _("OK"),
					callback = function()
						local fields = url_dialog:getFields()
						if fields[1] ~= "" then
							local port = tonumber(fields[2])
							if not port or port < 1 or port > 65355 then
								port = ObsidianSync.defaults.port
							end

 						local new_settings = {
 							address = fields[1],
 							port = port,
 							password = fields[3],
 						}
 						G_reader_settings:saveSetting("obsidian_sync_settings", new_settings)
 						self.settings = new_settings
 						self:info("Settings saved!")
						end
						UIManager:close(url_dialog)
						if touchmenu_instance then
							touchmenu_instance:updateItems()
						end
					end,
				},
			},
		},
	})
	UIManager:show(url_dialog)
	url_dialog:onShowKeyboard()
end

function ObsidianSync:debug()
	local info = {}

	table.insert(info, "====== DEBUG INFO ======")
	table.insert(info, "")

	table.insert(info, "⚙️ Obsidian Settings:")
	local settings = self.settings or G_reader_settings:readSetting("obsidian_sync_settings", ObsidianSync.defaults)

	table.insert(info, "- IP: " .. settings.address)
	table.insert(info, "- Port: " .. settings.port)
	local pass_display = (settings.password ~= "" and "****** (hidden)" or "(not set)")
	table.insert(info, "- Password: " .. pass_display)

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

	local metadata = self:getSDRData()

	table.insert(info, "- Highlights count: " .. #metadata["annotations"])

	self:info(table.concat(info, "\n"))
end

return ObsidianSync
