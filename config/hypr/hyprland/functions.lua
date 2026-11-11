local vars = require("variables")

-- workspace limit within a group of ten and wrap-around: set by the shell (Theme.workspaces → glyph_ws_limit, glyph_ws_wrap), without the shell — 10 and wrapping
local function ws_limit() return glyph_ws_limit or 10 end

local function wsaction(action, range, i)
    return function()
        local activews = hl.get_active_workspace()
        if activews then
            local id = activews.id
            -- Super+N past the limit — ignored (groups, Ctrl+Super+N, have no limit)
            if range ~= "group" and i > ws_limit() then return end
            local s  = (i - 1) * 10 + (id % 10)
            local t  = math.floor((id - 1) / 10) * 10 + i
            local z  = (range == "group") and s or t

            if action == "move" then
                return hl.dispatch(hl.dsp.window.move({ workspace = z }))
            else
                return hl.dispatch(hl.dsp.focus({ workspace = z }))
            end
        end
    end
end

-- neighbouring workspace ±1 within the group of ten: past the last — the first (and back), if glyph_ws_wrap; otherwise stay.
-- move — move the window there, otherwise go there
local function wsstep(d, move)
    return function()
        local a = hl.get_active_workspace()
        if not a or a.id < 1 then return end
        local base, n = math.floor((a.id - 1) / 10) * 10, ws_limit()
        local slot = a.id - base
        local t = slot + d
        if slot > n then t = (d > 0) and 1 or n -- we're past the limit (it was lowered) — back inside it
        elseif t > n then t = (glyph_ws_wrap == false) and n or 1
        elseif t < 1 then t = (glyph_ws_wrap == false) and 1 or n end
        if base + t == a.id then return end
        if move then
            return hl.dispatch(hl.dsp.window.move({ workspace = base + t }))
        end
        return hl.dispatch(hl.dsp.focus({ workspace = base + t }))
    end
end

local function resize_by_screen(x, y)
    local screen = hl.get_active_monitor()
    if screen and type(screen.width) == "number" and type(screen.height) == "number" then
        if not (x == 0 and y == 0) then
            local w = (x and x > 0) and math.floor(screen.width * x / 100) or screen.width
            local h = (y and y > 0) and math.floor(screen.height * y / 100) or screen.height
            return { x = w, y = h, relative = false }
        end
    end
end

local function resize_active_window(x, y)
    local win = hl.get_active_window()
    if win and win.size then
        local w = (win.size.x * (x / 100)) or 800
        local h = (win.size.y * (y / 100)) or 600

        return { x = w, y = h, relative = true }
    end
end

local function resizer(window, pattern, x_percent, y_percent, actions, exact)
    if (window and window.title) and string.find(window.title, pattern, 1, exact) then
        local disp = (type(actions) == "table") and actions or { actions }
        for _, x in ipairs(disp) do
            hl.dispatch(x)
        end

        hl.dispatch(hl.dsp.window.resize(resize_by_screen(x_percent, y_percent)))
        hl.dispatch(hl.dsp.window.set_prop({ prop = "keep_aspect_ratio", value = "true" }))
    end
end

local pip_windows = {}
local pip_state = (os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state") .. "/rice/pip-geometry"

local function restore_pip(win)
    if not win.title:lower():match("^picture[- ]in[- ]picture$") or pip_windows[win.address] then return end
    local screen = win.monitor
    if not screen or win.size.x <= 0 or win.size.y <= 0 then return end
    pip_windows[win.address] = true

    local x, y, width
    local saved = io.open(pip_state, "r")
    if saved then
        x, y, width = saved:read("n", "n", "n")
        saved:close()
    end
    local ratio = win.size.x / win.size.y
    local screen_w, screen_h = screen.width / screen.scale, screen.height / screen.scale
    local margin = math.floor(math.min(screen_w, screen_h) * 0.03)
    width = math.floor(math.min(screen_w, screen_h * ratio, math.max(200, width or screen_h * ratio / 4)))
    local height = math.floor(width / ratio + 0.5)
    local max_x, max_y = screen.x + screen_w - width, screen.y + screen_h - height
    x = math.floor(math.max(screen.x, math.min(max_x, x or max_x - margin)))
    y = math.floor(math.max(screen.y, math.min(max_y, y or max_y - margin)))

    hl.dispatch(hl.dsp.window.float({ action = "on", window = win }))
    hl.dispatch(hl.dsp.window.pin({ action = "on", window = win }))
    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = win }))
    hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = false, window = win }))
end

local function save_pip(win)
    if not pip_windows[win.address] then return end
    pip_windows[win.address] = nil
    if win.size.x <= 0 or win.size.y <= 0 then return end
    local file = io.open(pip_state .. ".tmp", "w")
    if not file then return end
    file:write(string.format("%.0f %.0f %.0f\n", win.at.x, win.at.y, win.size.x))
    if file:close() then os.rename(pip_state .. ".tmp", pip_state) end
end

-- special ws: open/close, and if it's empty — launch its program from vars.apps (replaces caelestia toggle).
-- apps are read on keypress, not at load: user.lua loads after the binds and changes them there
local function toggle_special(name)
    return function()
        local cmd = vars.apps[name]
        for _, ws in ipairs(hl.get_workspaces()) do
            if ws.name == "special:" .. name and ws.windows > 0 then cmd = nil end
        end
        -- show first, then launch: hypr opens the window where focus was at launch time,
        -- and in the reverse order it would hide the workspace as soon as the window appeared
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
        if cmd then hl.exec_cmd(cmd) end
    end
end

local spotify_background = hl.window_rule({
    name = "spotify-background",
    enabled = false,
    match = { class = [[(?i)(spotify|com\.spotify\.client)]] },
    workspace = "special:spotify-background silent",
    no_initial_focus = true,
})
local spotify_launch_timer
local spotify_reveal_pending = false

local function is_spotify(win)
    local class = (win.class or ""):lower()
    return class == "spotify" or class == "com.spotify.client"
end

local function finish_spotify_launch()
    spotify_background:set_enabled(false)
    spotify_launch_timer:set_enabled(false)
    spotify_launch_timer = nil
    spotify_reveal_pending = false
end

local function spotify(show_window)
    for _, win in ipairs(hl.get_windows()) do
        if win.mapped and is_spotify(win) then
            if not show_window then return end
            local window = "address:" .. win.address
            if win.pinned then
                hl.dispatch(hl.dsp.window.pin({ window = window, action = "off" }))
            end
            if win.workspace.special then
                local workspace = hl.get_active_workspace()
                if workspace then
                    hl.dispatch(hl.dsp.window.move({ window = window, workspace = workspace.addressable_name, follow = true }))
                end
            else
                hl.dispatch(hl.dsp.focus({ window = window }))
            end
            return
        end
    end

    if spotify_launch_timer then
        spotify_reveal_pending = spotify_reveal_pending or show_window == true
        return
    end

    -- Flatpak's Spotify window can appear outside the launch command's PID tree.
    spotify_background:set_enabled(not show_window)
    spotify_launch_timer = hl.timer(finish_spotify_launch, { timeout = 15000, type = "oneshot" })
    hl.exec_cmd(vars.apps.music)
    if show_window then return end
    hl.exec_cmd([[
        for attempt in $(seq 1 15); do
            [ "$(playerctl -p spotify status 2>/dev/null)" = Playing ] && exit 0
            playerctl -p spotify play 2>/dev/null
            sleep 1
        done
    ]])
end

hl.on("window.open", function(win)
    if not spotify_launch_timer or not is_spotify(win) then return end
    local reveal = spotify_reveal_pending
    finish_spotify_launch()
    if reveal then spotify(true) end
end)

-- gpu-screen-recorder screen recording: the same bind again — stop
local function record(region, sound)
    return function()
        local mon = hl.get_active_monitor()
        local w   = region and '-w region -region "$(slurp -f %wx%h+%x+%y)"' or "-w " .. (mon and mon.name or "region")
        hl.exec_cmd("pkill -INT -f '^gpu-screen-recorder' || gpu-screen-recorder " .. w ..
            (sound and " -a default_output" or "") .. ' -o "$(xdg-user-dir VIDEOS)/rec-$(date +%F_%H-%M-%S).mp4"')
    end
end

return {
    toggle_special       = toggle_special,
    spotify              = spotify,
    record               = record,
    resizer              = resizer,
    resize_by_screen     = resize_by_screen,
    resize_active_window = resize_active_window,
    wsaction             = wsaction,
    wsstep               = wsstep,
    restore_pip          = restore_pip,
    save_pip             = save_pip,
}
