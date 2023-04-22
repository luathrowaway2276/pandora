local ffi = require("ffi")

local addresses = {
    -- x-ref "ClanTagChanged"
    send_clan_tag = client.find_sig("engine.dll", "53 56 57 8B DA 8B F9 FF")
}

local helpers = {
    set_clan_tag = ffi.cast("void(__fastcall*)(const char*, const char*)", addresses.send_clan_tag)
}

local config = {
    type = ui.add_dropdown("Clantag", {"Disabled", "Static", "Animated"}),
    text = ui.add_textbox("Clantag text"),
    animation_style = ui.add_dropdown("Clantag animation style", {"Scroll", "Spell"}),
    speed = ui.add_slider("Clantag animation speed", 1, 100),
}

local stored_clantag_type = -1
local function handle_ui()
    clantag_type = config.type:get()

    if stored_clantag_type ~= clantag_type then
        config.text:set_visible(clantag_type ~= 0)
        config.animation_style:set_visible(clantag_type == 2)
        config.speed:set_visible(clantag_type == 2)
        stored_clantag_type = clantag_type
    end
end

local wanted_clantag = ""
local last_clantag = ""
local function handle_clantag()
    local clantag_type = config.type:get()

    -- should we clear our clantag?
    if clantag_type == 0 then
        if last_clantag ~= "" then
            helpers.set_clan_tag("", "")
            last_clantag = ""
        end
        return
    elseif clantag_type == 1 then -- static
        wanted_clantag = config.text:get()
    elseif clantag_type == 2 then -- animated
        local animation_style = config.animation_style:get()
        local animation_speed = 1 - (config.speed:get() / 100)
        local text = config.text:get()

        if animation_style == 0 then -- scroll
            local index = math.floor((global_vars.curtime / animation_speed) % #text) + 1
            wanted_clantag = text:sub(index) .. text:sub(1, index - 1)
        elseif animation_style == 1 then -- spell
            wanted_clantag = text:sub(0, math.floor((global_vars.curtime / animation_speed) % #text))
        end
    end

    -- do we need to update our clantag?
    if last_clantag ~= wanted_clantag then
        helpers.set_clan_tag(wanted_clantag, wanted_clantag)
        last_clantag = wanted_clantag
    end
end

local function on_paint()
    handle_ui()
    handle_clantag()
end

callbacks.register("paint", on_paint)