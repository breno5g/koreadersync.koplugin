local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local DeviceInfo = require("device")

local ObsidianSync = WidgetContainer:extend({
	name = "obsidiansync",
	is_doc_only = false,

	defaults = {
		address = "127.0.0.1",
		port = 9090,
	},
})

function ObsidianSync:init()
	self.settings = G_reader_settings:readSetting("obsidiansync_settings", ObsidianSync.defaults)
	self:getDeviceID()
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
				text = _("Sync now"),
				callback = function()
					self:sendToServer()
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

function ObsidianSync:showNotification(message, timeout)
	local Notification = require("ui/widget/notification")
	UIManager:show(Notification:new({
		text = _(message),
		timeout = timeout or 3,
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
		self:showNotification(_("❌ Please open a document to proceed"))
		return
	end

	local fileInfo = self:getFileNameAndExtension()
	local chunk, err =
		loadfile(fileInfo.dirname .. "/" .. fileInfo.filename .. ".sdr/metadata." .. fileInfo.extension .. ".lua")
	if not chunk then
		self:showNotification(_("❌ Error opening SDR file: ") .. err, 5)
		return
	end

	local metadata = chunk()

	return metadata
end

function ObsidianSync:configure(touchmenu_instance)
	local MultiInputDialog = require("ui/widget/multiinputdialog")
	local url_dialog

	local current_settings = self.settings
		or G_reader_settings:readSetting("obsidiansync_settings", ObsidianSync.defaults)

	local obsidian_url_address = current_settings.address
	local obsidian_url_port = current_settings.port

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

							-- Preserva o device_id existente ao salvar
							local new_settings = {
								address = fields[1],
								port = port,
								device_id = self.settings.device_id,
							}
							G_reader_settings:saveSetting("obsidiansync_settings", new_settings)
							self.settings = new_settings
							self:showNotification(_("✅ Settings saved!"))
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

function ObsidianSync:sendToServer()
	local json = require("json")

	local metadata = self:getSDRData()
	if not metadata then
		return
	end

	local body, err = json.encode(metadata)
	if not body then
		self:showNotification(_("❌ Error encoding JSON: ") .. (err or _("unknown")), 5)
		return
	end

	local device_id = self:getDeviceID()
	if not device_id or device_id == "" then
		self:showNotification(_("❌ Error: Could not get device ID."), 5)
		return
	end

	local settings = self.settings or G_reader_settings:readSetting("obsidiansync_settings", ObsidianSync.defaults)
	local url = "http://" .. settings.address .. ":" .. settings.port .. "/sync"

	self:showNotification(_("Syncing with server..."), 2)

	UIManager:scheduleIn(0.25, function()
		self:_doSyncRequest(url, body, device_id)
	end)
end

function ObsidianSync:debug()
	local info = {}

	table.insert(info, "====== DEBUG INFO ======")
	table.insert(info, "")

	local device_id = self:getDeviceID()
	table.insert(info, "📱 Device Info:")
	table.insert(info, "- ID: " .. (device_id or _("unknown")))
	table.insert(info, "")

	table.insert(info, "⚙️ Obsidian Settings:")
	local settings = self.settings or G_reader_settings:readSetting("obsidiansync_settings", ObsidianSync.defaults)

	table.insert(info, "- IP: " .. settings.address)
	table.insert(info, "- Port: " .. settings.port)

	table.insert(info, "")

	if not self.ui.document then
		table.insert(info, _("❌ Please open a document to proceed"))
		self:info(table.concat(info, "\n"))
		return
	end

	local fileInfo = self:getFileNameAndExtension()
	table.insert(info, "✅ Document Info:")
	table.insert(info, "- Dirname: " .. fileInfo.dirname)
	table.insert(info, "- Filename: " .. fileInfo.filename)
	table.insert(info, "- Extension: " .. fileInfo.extension)

	local metadata = self:getSDRData()

	if metadata and metadata.annotations then
		table.insert(info, "- Highlights count: " .. #metadata["annotations"])
	else
		table.insert(info, _("- Highlights count: (Error getting sdr data)"))
	end

	self:info(table.concat(info, "\n"))
end

function ObsidianSync:_doSyncRequest(url, body, device_id)
	local http = require("socket.http")
	local ltn12 = require("ltn12")

	http.TIMEOUT = 10
	local resp_body_table = {}
	local headers = {
		["Content-Type"] = "application/json",
		["Content-Length"] = #body,
		["Authorization"] = device_id,
	}

	local ok, code, headers_resp, status = http.request({
		url = url,
		method = "POST",
		headers = headers,
		source = ltn12.source.string(body),
		sink = ltn12.sink.table(resp_body_table),
	})

	if not ok then
		self:showNotification(_("❌ Connection error: ") .. (code or _("timeout")), 5)
		return
	end

	local response_message = table.concat(resp_body_table)
	local final_message = (response_message ~= "") and response_message or status
	local is_success = code >= 200 and code < 300

	if is_success then
		self:showNotification(_("✅ Sync successful!"))
	else
		self:showNotification(_("❌ Server error (") .. code .. "): " .. final_message, 5)
	end
end

function ObsidianSync:getDeviceID()
	local serial = DeviceInfo.serial_number

	if serial and serial ~= "" then
		return serial
	end

	if self.settings.device_id and self.settings.device_id ~= "" then
		return self.settings.device_id
	end

	local new_id = self:_generateRandomID()

	self.settings.device_id = new_id
	G_reader_settings:saveSetting("obsidiansync_settings", self.settings)

	return new_id
end

function ObsidianSync:_generateRandomID(length)
	length = length or 16
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local id = ""
	for _ = 1, length do
		local rand_idx = math.random(1, #chars)
		id = id .. chars:sub(rand_idx, rand_idx)
	end
	return "gen-" .. id
end

return ObsidianSync
