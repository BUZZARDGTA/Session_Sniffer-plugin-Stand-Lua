-- Author: IB_U_Z_Z_A_R_Dl
-- Description: Plugin for Session Sniffer project on GitHub.
-- Allows you to automatically have every usernames showing up on Session Sniffer project, by logging all players from your sessions to "Stand\Lua Scripts\Session_Sniffer-plugin\log.txt".
-- GitHub Repository: https://github.com/Illegal-Services/Session_Sniffer-plugin-Stand-Lua


-- Globals START
---- Global variables START
local mainLoopThread
local player_join__timestamps = {}
---- Global variables END

---- Global constants START
local SCRIPT_NAME <const> = "Session_Sniffer-plugin.lua"
local SCRIPT_TITLE <const> = "Session Sniffer"
local SCRIPT_LOG__PATH <const> = filesystem.scripts_dir() .. "Session_Sniffer-plugin\\log.txt"
---- Global constants END

---- Global functions START
-- Function to escape special characters in a string for Lua patterns
local function escape_magic_characters(str)
    local matches = {
        ["^"] = "%^",
        ["$"] = "%$",
        ["("] = "%(",
        [")"] = "%)",
        ["%"] = "%%",
        ["."] = "%.",
        ["["] = "%[",
        ["]"] = "%]",
        ["*"] = "%*",
        ["+"] = "%+",
        ["-"] = "%-",
        ["?"] = "%?"
    }
    return (str:gsub(".", matches))
end

function is_file_string_need_newline_ending(str)
    if #str == 0 then
        return false
    end

    return str:sub(-1) ~= "\n"
end

function read_file(file_path)
    local file, err = io.open(file_path, "r")
    if err then
        return nil, err
    end

    local content = file:read("*a")

    file:close()

    return content, nil
end

local function is_thread_running(threadId)
    if threadId and util.is_scheduled_in(threadId) then
        return true
    end

    return false
end

local function delete_thread(threadId)
    if threadId then
        util.shoot_thread(threadId)
    end
end

local function handle_script_exit(params)
    params = params or {}
    if params.hasScriptCrashed == nil then
        params.hasScriptCrashed = false
    end

    if is_thread_running(mainLoopThread) then
        delete_thread(mainLoopThread)
    end

    if params.hasScriptCrashed then
        util.toast("Oh no... Script crashed:(\nYou gotta restart it manually.")
    end

    util.stop_script()
end

local function create_empty_file(filepath)
    -- Extract the directory part from the filepath
    local dir = filepath:match("^(.*)[/\\]") -- Match up to the last slash or backslash

    if dir then
        -- Create only the directory
        filesystem.mkdirs(dir)
    end

    -- Create the file
    local file, err = io.open(filepath, "w")
    if err then
        handle_script_exit({ hasScriptCrashed = true })
        return
    end

    file:close()
end
---- Global functions END
-- Globals END


-- === Main Menu Features === --
local function handle_player_leave(playerID)
    player_join__timestamps[playerID] = nil
end

playerLeaveEventListener = players.on_leave(function(f)
    handle_player_leave(f)
end)


local function loggerPreTask(player_entries_to_log, log__content, currentTimestamp, playerID, playerSCID, playerName, playerIP)
    if (
        not playerSCID
        or not playerName
        or not playerIP
        or playerIP == "255.255.255.255"
    ) then
        return
    end

    if not player_join__timestamps[playerID] then
        player_join__timestamps[playerID] = util.current_unix_time_seconds()
    end

    local entry_pattern = string.format("user:(%s), scid:(%d), ip:(%s), timestamp:(%%d+)", escape_magic_characters(playerName), playerSCID, escape_magic_characters(playerIP))
    if not log__content:find("^" .. entry_pattern) and not log__content:find("\n" .. entry_pattern) then
        table.insert(player_entries_to_log, string.format("user:%s, scid:%d, ip:%s, timestamp:%d", playerName, playerSCID, playerIP, currentTimestamp))
    end
end

local function write_to_log_file(player_entries_to_log)
    if not filesystem.exists(SCRIPT_LOG__PATH) or not filesystem.is_regular_file(SCRIPT_LOG__PATH) then
        create_empty_file(SCRIPT_LOG__PATH)
    end

    local log_file, err = io.open(SCRIPT_LOG__PATH, "a")
    if err then
        handle_script_exit({ hasScriptCrashed = true })
        return
    end

    local combined_entries = table.concat(player_entries_to_log, "\n")
    log_file:write(combined_entries .. "\n")
    log_file:close()
end


-- === Main Loop === --
mainLoopThread = util.create_tick_handler(function()
    if not filesystem.exists(SCRIPT_LOG__PATH) or not filesystem.is_regular_file(SCRIPT_LOG__PATH) then
        create_empty_file(SCRIPT_LOG__PATH)
    end

    local log__content, err = read_file(SCRIPT_LOG__PATH)
    if err then
        handle_script_exit({ hasScriptCrashed = true })
        return
    end

    if is_file_string_need_newline_ending(log__content) then
        local file, err = io.open(SCRIPT_LOG__PATH, "a")
        if err then
            handle_script_exit({ hasScriptCrashed = true })
            return
        end

        file:write("\n")
        file:close()
    end

    if util.is_session_started() then
        local player_entries_to_log = {}
        local currentTimestamp = util.current_unix_time_seconds()

        for players.list() as playerID do
            local playerSCID = players.get_rockstar_id(playerID)
            local playerName = players.get_name(playerID)
            local playerIP = players.get_ip_string(playerID)

            loggerPreTask(player_entries_to_log, log__content, currentTimestamp, playerID, playerSCID, playerName, playerIP)

            util.yield()
        end

        if #player_entries_to_log > 0 then
            write_to_log_file(player_entries_to_log)
        end

    else
        player_join__timestamps = {}
    end

    util.yield()
end)
