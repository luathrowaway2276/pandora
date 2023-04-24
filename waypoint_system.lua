local json = require("json")
local file_system = require("Filesystem")

local fonts = 
{
    indicator = render.create_font("Tahoma", 12, 0, font_flags.outline)
}

local way_points = {}
local waypoint_names = {}

local config = 
{
    selected_waypoint = ui.add_dropdown("Selected waypoint", {}),
    point_name = ui.add_textbox("Point name"),
    point_max_distance = ui.add_slider("Point max distance", 0, 100),
    visualize_range = ui.add_checkbox("Visualize range"),
    create_point = ui.add_button("Create point"),
    delete_point = ui.add_button("Delete point"),
    refresh_points = ui.add_button("Refresh points"),
    save_points = ui.add_button("Save points"),
    load_points = ui.add_button("Load points")
}

local function refresh_points()
    waypoint_names = {}

    for k, v in ipairs(way_points[client.map_name()]) do
        table.insert(waypoint_names, v.name)
    end

    config.selected_waypoint:update_items(waypoint_names)

    if #waypoint_names > 0 then
        client.log(#waypoint_names .. " waypoints discovered!")
    end
end

local stored_map_name = ""
local function on_paint()
    local map_name = client.map_name()
  
    if not way_points[map_name] then
        way_points[map_name] = {}
    end

    if stored_map_name ~= map_name then
        refresh_points()
        stored_map_name = map_name
    end

    local local_player = entity_list.get_client_entity(engine.get_local_player())

    if not local_player then
        return
    end

    if local_player:get_prop("DT_CSPlayer", "m_iHealth"):get_int() < 1 then
        return
    end

    local origin = local_player:origin()

    for k, v in ipairs(way_points[client.map_name()]) do
        local screen_pos = vector2d.new(0, 0)

        -- calculate distance using the euclidean distance formula
        local distance = math.sqrt((v.x - origin.x)^2 + (v.y - origin.y)^2)

        if distance > 1000 then
            goto skip
        end

        local alpha = math.max(0, 255 - (255 / 1000) * distance)
        local in_range = distance < v.max_distance

        -- if we are in range, let the player know
        if config.visualize_range:get() and v.max_distance > 0 then
            if in_range then
                render.circle_world(vector.new(v.x, v.y, v.z), v.max_distance, color.new(0, 0, 0, 0), color.new(140, 235, 52, alpha * 0.33))
             else
                render.circle_world(vector.new(v.x, v.y, v.z), v.max_distance, color.new(0, 0, 0, 0), color.new(235, 64, 52, alpha * 0.33))
             end
        end

        if render.world_to_screen(vector.new(v.x, v.y, v.z + 15), screen_pos) then
            local text_width, text_height = fonts.indicator:get_size(v.name)
            local box_size = vector2d.new(text_width + 4, text_height + 6)
            local box_pos = vector2d.new(screen_pos.x - (box_size.x * 0.5), screen_pos.y)

            render.rectangle_filled(box_pos.x, box_pos.y, box_size.x, box_size.y, color.new(40, 40, 40, alpha))

            if in_range then
                render.rectangle_filled(box_pos.x, box_pos.y + (box_size.y - 2), box_size.x, 1, color.new(140, 235, 52, alpha))
            else
                render.rectangle_filled(box_pos.x, box_pos.y + (box_size.y - 2), box_size.x, 1, color.new(235, 64, 52, alpha))
            end

            render.rectangle(box_pos.x, box_pos.y, box_size.x, box_size.y, color.new(40, 40, 40, alpha))
            fonts.indicator:text(box_pos.x + 2, box_pos.y + 1, color.new(255, 255, 255, alpha), v.name)
        end

        ::skip::
    end
end

config.create_point:add_callback(
    function() 
        local local_player = entity_list.get_client_entity(engine.get_local_player())

        if not local_player then
            return
        end
    
        if local_player:get_prop("DT_CSPlayer", "m_iHealth"):get_int() < 1 then
            return
        end

        local origin = local_player:origin()

        local new_waypoint = 
        {
            x = origin.x,
            y = origin.y,
            z = origin.z,
            name = config.point_name:get(),
            max_distance = config.point_max_distance:get(),
            type = config.point_type:get()
        }

        for k, v in ipairs(way_points[client.map_name()]) do
            if v.name == new_waypoint.name then
                client.log("Waypoint with name \"" .. new_waypoint.name .. "\" already exists!")
                return
            end
        end

        table.insert(way_points[client.map_name()], new_waypoint)
        refresh_points()
        client.log("Waypoint \"" .. new_waypoint.name .. "\" created!")
    end
)

config.refresh_points:add_callback(refresh_points)

config.delete_point:add_callback(
    function()
        if #way_points[client.map_name()] == 0 then
            return
        end

        table.remove(way_points[client.map_name()], config.selected_waypoint:get() + 1)
        refresh_points()
        client.log("Waypoint discarded!")
    end
)

config.save_points:add_callback(
    function()
        local file_handle = file_system.open("waypoints/points.json", "w+", "")
        file_handle:write(json.encode(way_points))
        file_handle:close()
        client.log("Saved waypoints!")
    end
)

config.load_points:add_callback(
    function()
        local file_handle = file_system.open("waypoints/points.json", "r+", "")
        way_points = json.decode(file_handle:read())
        file_handle:close()
        client.log("Loaded waypoints!")
        refresh_points()
    end
)

-- do we have the waypoints directory?
if not file_system.exists("waypoints/") then
    client.log("Creating waypoint directory!")
    file_system.create_directory("waypoints")
end

callbacks.register("paint", on_paint)