-- Changelog poster (server-side)
-- Usage:
-- 1) Set `WEBHOOK_URL` below to your Discord webhook URL.
-- 2) Use the command `postChangelog` (admin-only) to post all unposted entries.
-- 3) Use `postChangelogEntry <id>` command or exported `PostChangelogEntry(entryId)` to post a single entry.

local WEBHOOK_URL = "https://discord.com/api/webhooks/your/webhookurl" -- <-- Replace with your webhook
local MAX_CONTENT_LEN = 1900 -- Discord limit safety
local POSTED_FILE = 'posted_ids.json'

local function readFile(path)
    local content = LoadResourceFile(GetCurrentResourceName(), path)
    if not content then return nil end
    return content
end

local function saveFile(path, content)
    return SaveResourceFile(GetCurrentResourceName(), path, content, -1)
end

local function postToDiscord(payload)
    if WEBHOOK_URL == nil or WEBHOOK_URL == "" then
        print("[changelog] No webhook configured. Set WEBHOOK_URL in server.lua")
        return false, "no_webhook"
    end

    local ok = true
    local status = nil
    PerformHttpRequest(WEBHOOK_URL, function(statusCode, text, headers) status = statusCode end, 'POST', json.encode(payload), {['Content-Type'] = 'application/json'})

    if status == nil then
        -- best-effort: allow async; assume ok
        return true
    end

    if status >= 200 and status < 300 then return true end
    return false, tostring(status)
end

local function formatEntryToEmbed(entry)
    local description = ""
    if entry.changes and type(entry.changes) == 'table' then
        for i, change in ipairs(entry.changes) do
            description = description .. "• " .. change .. "\n"
        end
    elseif entry.changes and type(entry.changes) == 'string' then
        description = entry.changes
    end

    if #description > MAX_CONTENT_LEN then
        description = string.sub(description, 1, MAX_CONTENT_LEN-3) .. "..."
    end

    local embed = {
        title = entry.title or ("Changelog #" .. tostring(entry.id or "?")),
        description = description,
        color = 3447003,
        fields = {},
        footer = {
            text = (entry.author or "Unknown") .. " • " .. (entry.date or os.date('%Y-%m-%d'))
        }
    }

    return embed
end

local function loadChangelog()
    local raw = readFile('changelog.json')
    if not raw then
        print('[changelog] changelog.json not found in resource root')
        return nil
    end

    local ok, data = pcall(function() return json.decode(raw) end)
    if not ok or type(data) ~= 'table' then
        print('[changelog] failed to parse changelog.json')
        return nil
    end

    return data
end

local function loadPostedIds()
    local raw = readFile(POSTED_FILE)
    if not raw then return {} end
    local ok, data = pcall(function() return json.decode(raw) end)
    if not ok or type(data) ~= 'table' then return {} end
    -- normalize to map for quick lookup
    local map = {}
    for _, id in ipairs(data) do map[tostring(id)] = true end
    return map
end

local function savePostedIdsMap(map)
    local arr = {}
    for id, _ in pairs(map) do table.insert(arr, id) end
    local ok = saveFile(POSTED_FILE, json.encode(arr))
    if not ok then print('[changelog] failed to save posted ids') end
    return ok
end

local function postEntryAndMark(entry, postedMap)
    local embed = formatEntryToEmbed(entry)
    local payload = { embeds = { embed } }
    local ok, err = postToDiscord(payload)
    if ok then
        postedMap[tostring(entry.id)] = true
        savePostedIdsMap(postedMap)
        return true
    end
    return false, err
end

-- Post entire changelog but skip already posted entries
local function postEntireChangelog()
    local data = loadChangelog()
    if not data or not data.entries then return false, 'no_entries' end

    local posted = loadPostedIds()
    for _, entry in ipairs(data.entries) do
        if not posted[tostring(entry.id)] then
            local ok, err = postEntryAndMark(entry, posted)
            if not ok then
                print('[changelog] failed to post entry id=' .. tostring(entry.id) .. ' err=' .. tostring(err))
                return false, err
            end
            Wait(500)
        end
    end

    return true
end

-- Post a single entry by id and mark it
local function postChangelogEntryById(id)
    local data = loadChangelog()
    if not data or not data.entries then return false, 'no_entries' end
    local posted = loadPostedIds()

    for _, entry in ipairs(data.entries) do
        if tostring(entry.id) == tostring(id) then
            if posted[tostring(entry.id)] then return false, 'already_posted' end
            return postEntryAndMark(entry, posted)
        end
    end

    return false, 'entry_not_found'
end

-- Exports
exports('PostChangelogEntry', function(entryId)
    return postChangelogEntryById(entryId)
end)

-- Commands
RegisterCommand('postChangelog', function(source, args, raw)
    if source ~= 0 then
        local allowed = false
        if GetResourceState('qb-core') == 'started' then
            local QBCore = exports['qb-core']:GetCoreObject()
            local Player = QBCore.Functions.GetPlayer(source)
            if Player and Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.isboss then
                allowed = true
            end
        end
        if not allowed then
            TriggerClientEvent('chat:addMessage', source, { args = { '^1[Changelog]', 'Insufficient permissions' } })
            return
        end
    end

    local ok, err = postEntireChangelog()
    if ok then
        if source == 0 then print('[changelog] posted changelog to Discord') else TriggerClientEvent('chat:addMessage', source, { args = { '^2[Changelog]', 'Posted changelog to Discord' } }) end
    else
        if source == 0 then print('[changelog] failed to post changelog: '..tostring(err)) else TriggerClientEvent('chat:addMessage', source, { args = { '^1[Changelog]', 'Failed to post changelog: '..tostring(err) } }) end
    end
end, false)

-- Post single entry command
RegisterCommand('postChangelogEntry', function(source, args, raw)
    if not args[1] then
        if source == 0 then print('[changelog] usage: postChangelogEntry <id>') else TriggerClientEvent('chat:addMessage', source, { args = { '^1[Changelog]', 'Usage: postChangelogEntry <id>' } }) end
        return
    end
    local id = args[1]

    local ok, err = postChangelogEntryById(id)
    if ok then
        if source == 0 then print('[changelog] posted entry '..tostring(id)) else TriggerClientEvent('chat:addMessage', source, { args = { '^2[Changelog]', 'Posted entry '..tostring(id) } }) end
    else
        if source == 0 then print('[changelog] failed to post entry '..tostring(id)..' err='..tostring(err)) else TriggerClientEvent('chat:addMessage', source, { args = { '^1[Changelog]', 'Failed to post entry: '..tostring(err) } }) end
    end
end, false)

-- Auto-post on resource start: posts only unposted entries
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Citizen.SetTimeout(2000, function()
        local ok, err = postEntireChangelog()
        if not ok then print('[changelog] auto-post failed: '..tostring(err)) else print('[changelog] auto-posted changelog to Discord') end
    end)
end)

print('[changelog] server script loaded')
