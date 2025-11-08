# Changelog Discord Poster (FiveM)

Author: Wrathster2103

A small FiveM resource that reads `changelog.json` and posts entries to a Discord webhook. It supports manual posting via command/export and automatic posting on resource start while avoiding duplicates by persisting posted IDs to `posted_ids.json`.

### Installation
- Place this resource in your server `resources` folder (folder name is the resource name).
- Ensure the files `fxmanifest.lua`, `server.lua`, `changelog.json`, and `posted_ids.json` (optional) exist in the resource root.
- In your `server.cfg`, add: `start your-resource-name` (replace with the folder name).

### Configuration
- Open `server.lua` and set your Discord webhook URL in the `WEBHOOK_URL` variable.
- `changelog.json` is an array of entries. Example entry:

```json
{
  "id": "v1.0.0",
  "title": "Initial release",
  "date": "2025-01-01",
  "items": ["Added feature A","Fixed bug B" ]
}
```

- `posted_ids.json` is used to track which entries have been posted to Discord. If the file is missing an empty array `[]` will be created automatically on first post.

### Usage
- Automatic posting: On resource start the server will attempt to post all changelog entries that are not recorded in `posted_ids.json` (short delay after start).
- Manual command (server console or RCON):
  - `postChangelog` — posts all unposted entries.
  - `postChangelogEntry <id>` — posts a single changelog entry by `id` and records it.

- Exports (other resources can call):
  - `exports['your-resource-name']:PostChangelogEntry(entryId)` — posts the changelog entry with id `entryId`.

### How duplicates are avoided
- When an entry is posted successfully the resource writes its `id` to `posted_ids.json`. On next start or manual post the resource skips IDs already present.

### Troubleshooting
- If posts fail, check server console for errors and ensure the webhook URL is correct and reachable from your server.
- Ensure `SaveResourceFile` permission is available for the server process (default FiveM behavior for resources).

### Contributing
- Open a PR with improvements — keep changes focused and maintain backward compatibility.

### License
- Licensed under the MIT License. See LICENSE file for details.
