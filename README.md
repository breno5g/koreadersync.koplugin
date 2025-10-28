# ✨ KOReader Sync

A plugin for [KOReader](https://koreader.rocks/) that exports your reading highlights and notes directly to a web server, allowing for easy integration with Obsidian or any other note-taking service.

This plugin extracts annotations from your current book's `.sdr` file, formats them as JSON, and sends them via an HTTP POST request to a configurable endpoint.

## 🚀 Features

* **One-Click Sync:** Send all highlights from the current book to your server at any time via the menu.
* **Easy Configuration:** Easily set the IP address and port of your destination server.
* **Device Identification:** Sends a unique device ID (the device's serial number or a generated ID) in the `Authorization` header so your server can identify where the notes are coming from.
* **Status Notifications:** Get instant feedback on whether the sync was successful or failed.
* **Debug Tool:** A "Debug info" panel to check your settings, document info, and highlight count.

## 🔧 Installation

1.  Ensure you have KOReader installed.
2.  Download this plugin (the `.koplugin` file).
3.  Place the `obsidiansync.koplugin` directory inside the `koreader/plugins/` folder on your device.
4.  Restart KOReader.

## ⚙️ How to Use

For the sync to work, you must have a server running that is listening for requests from this plugin (see the [How It Works (Server-Side)](#how-it-works-server-side) section below).

1.  With a document open in KOReader, access the top menu.
2.  Tap the menu icon (usually ☰ or ⚙️) and navigate to "Obsidian Sync".
3.  Select **"Configure"**.
4.  Enter the **IP Address** (e.g., `192.168.1.10`) and **Port** (e.g., `9090`) of your server. The defaults are `127.0.0.1` and `9090`.
5.  Save the settings.
6.  To send your notes, simply open the menu again and select **"Sync now"**.

You will receive a "✅ Sync successful!" notification if everything works, or an error message otherwise.

## 💡 How It Works (Server-Side)

This plugin is the *client*. You need to create a simple *server* that knows how to receive the data.

The plugin will make the following request:

* **Method:** `POST`
* **Endpoint:** `http://<your_ip>:<your_port>/sync`
* **Headers:**
    * `Content-Type: application/json`
    * `Content-Length: <payload_size>`
    * `Authorization: <device_id>` (Your e-reader's device ID)
* **Body:**
    A JSON object containing all data from the book's `.sdr/metadata.lua` file. This includes highlights, notes, bookmarks, and reading statistics.

Your server must:
1.  Listen on the `/sync` endpoint.
2.  Read the `Authorization` header to identify the device (optional, but recommended).
3.  Parse the incoming JSON `body`.
4.  Respond with an **HTTP `2xx` status code** (e.g., `200` or `204`) to indicate success.
5.  If something goes wrong, respond with an error code (e.g., `400`, `500`) and a plain text message in the body, which will be displayed in KOReader.

## 🐛 Debugging

If you run into trouble, use the **"Debug info"** option in the plugin menu.

This will show a window with:
* Your device ID.
* Your saved IP and Port settings.
* The open document's name and path.
* The count of highlights (annotations) found in the `.sdr` file.
