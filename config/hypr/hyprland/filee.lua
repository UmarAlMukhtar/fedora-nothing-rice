local vars = require("variables")
if not vars.fedora then return end

local data = os.getenv("XDG_DATA_HOME")
if not data or data == "" then data = os.getenv("HOME") .. "/.local/share" end
local extension = io.open(data .. "/nautilus-python/extensions/filee_middle_click.py")
if not extension then return end
extension:close()

hl.window_rule({
    name = "filee-donut",
    match = { class = "Filee", initial_title = "Filee Donut" },
    float = true,
    move = {
        "min(max(cursor_x - window_w * 0.5, 0), monitor_w - window_w)",
        "min(max(cursor_y - window_h * 0.5, 0), monitor_h - window_h)",
    },
    suppress_event = "x11configurerequest",
    border_size = 0,
    no_blur = true,
    no_shadow = true,
    animation = "popin 82%",
})

-- Filee may map after the pointer has already moved off the clicked file.
local filee_click
hl.bind("mouse:274", function()
    local window = hl.get_active_window()
    filee_click = window and window.class == "org.gnome.Nautilus" and {
        point = hl.get_cursor_pos(),
        workspace = window.workspace.id,
        time = os.time(),
    } or nil
end, { non_consuming = true })

hl.on("window.open", function(window)
    if window.class ~= "Filee" or window.title ~= "Filee Donut" then return end
    local click = filee_click
    filee_click = nil
    local screen = window.monitor
    if not click or os.time() - click.time > 3 or click.workspace ~= window.workspace.id or not screen then return end
    local x = math.floor(math.max(screen.x, math.min(screen.x + screen.width / screen.scale - window.size.x,
        click.point.x - window.size.x / 2)))
    local y = math.floor(math.max(screen.y, math.min(screen.y + screen.height / screen.scale - window.size.y,
        click.point.y - window.size.y / 2)))
    if math.abs(window.at.x - x) > 1 or math.abs(window.at.y - y) > 1 then
        hl.dispatch(hl.dsp.window.move({ window = window, x = x, y = y, relative = false }))
    end
end)
