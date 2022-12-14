local pathfinding = {}
pathfinding.robot = require("robot")
pathfinding.component = require("component")
pathfinding.geo = pathfinding.component.geolyzer
pathfinding.nav = pathfinding.component.navigation
pathfinding.us = require("usual_suspects")

-- IO-Stuff

-- map[x][y][z] = {open, distance, hardness, traversable}
function pathfinding.save_map(map)
    local file = assert(io.open("map.txt", "w"))
    io.output(file)
    for x, _ in pairs(map) do
        for y, _ in pairs(map[x]) do
            for z, m in pairs(map[x][y]) do
                io.write(x, " ", y, " ", z, " ", m[3], " ", pathfinding.us.btn(m[4]), " \n")
            end
        end
    end
end

function pathfinding.read_map()
    local arr_return = {}
    local file = io.open("map.txt", "r")
    if not file then return {} end
    io.input(file)
    while true do
        local line = io.read('*line')
        if not line or #line < 5 then break end
        local arr_tmp = {}
        local start = 1
        local stop = 1
        local s_string
        for _ = 1, 5 do
            stop = string.find(line, " ", stop + 1)
            s_string = string.sub(line, start, stop - 1)
            table.insert(arr_tmp, s_string)
            start = stop + 1
        end
        local x, y, z = tonumber(arr_tmp[1]), tonumber(arr_tmp[2]), tonumber(arr_tmp[3])
        local h, t = tonumber(arr_tmp[4]), pathfinding.us.stb(arr_tmp[5])
        arr_return[x] = arr_return[x] or {}
        arr_return[x][y] = arr_return[x][y] or {}
        arr_return[x][y][z] = arr_return[x][y][z] or { nil, nil, h, t }
    end
    return arr_return
end

function pathfinding.get_target_input()
    io.write("Target: \n")
    local fx, fy, fz = io.read("*n", "*n", "*n")
    fx, fy, fz = fx + 1000, fy + 1000, fz + 1000
    return { fx, fy, fz }
end

-- match robots perceived coordinates with 'true' ingame coordinates
function pathfinding.coord_correction()
    io.write("Enter robot x, y and z coordinates (seperated by spaces): \n")
    local io_x, io_y, io_z = io.read("*n", "*n", "*n")
    local nav_x, nav_y, nav_z = pathfinding.nav.getPosition()
    local offset_x = nav_x - io_x
    local offset_y = nav_y - io_y
    local offset_z = nav_z - io_z
    return { offset_x, offset_y, offset_z }
end

-- all coordinates +1000 because fuck negatives coordinates
function pathfinding.get_coord(correction_coords)
    local nav_x, nav_y, nav_z = pathfinding.nav.getPosition()
    local x = nav_x - correction_coords[1] + 1000
    local y = nav_y - correction_coords[2] + 1000
    local z = nav_z - correction_coords[3] + 1000
    return { x, y, z }
end

function pathfinding.is_valid_coord(map, x, y, z)
    if map[x] and map[x][y] and map[x][y][z] then
        return true
    end
    return false
end

-- /IO-Stuff


-- Robot Moving Stuff

function pathfinding.turn_it(robotDir, targetDir)
    -- turn -> {around, right, left}
    local dir = {
        [2] = { 3, 5, 4 },
        [3] = { 2, 4, 5 },
        [4] = { 5, 2, 3 },
        [5] = { 4, 3, 2 }
    }
    local dir_tmp = dir[robotDir]
    for k, v in pairs(dir_tmp) do
        if v == targetDir then
            if k == 1 then
                pathfinding.robot.turnAround()
            elseif k == 2 then
                pathfinding.robot.turnRight()
            else
                pathfinding.robot.turnLeft()
            end
        end
    end
end

function pathfinding.move_it(target, r_coord)
    local target_x, target_y, target_z = target[1], target[2], target[3]
    local target_dir
    local r_dir = pathfinding.nav.getFacing()
    local moved = false
    if r_coord[2] > target_y then
        moved = pathfinding.robot.down()
    elseif r_coord[2] < target_y then
        moved = pathfinding.robot.up()
    else
        if r_coord[1] > target_x then target_dir = 4.0
        elseif r_coord[1] < target_x then target_dir = 5.0
        elseif r_coord[3] > target_z then target_dir = 2.0
        elseif r_coord[3] < target_z then target_dir = 3.0
        end
        if r_dir ~= target_dir then
            pathfinding.turn_it(r_dir, target_dir)
            r_dir = pathfinding.nav.getFacing()
        end
        moved = pathfinding.robot.forward()
    end
    return moved and true or false
end

-- /Robot Moving Stuff


-- Different Helper Functions

function pathfinding.distance(self_in, start, target)
    -- local sd = (math.abs(start[1] - self_in[1]) + math.abs(start[2] - self_in[2]) +
    --     math.abs(start[3] - self_in[3]))
    local td = math.abs(target[1] - self_in[1]) + math.abs(target[2] - self_in[2]) +
        math.abs(target[3] - self_in[3])
    return td
end

function pathfinding.reset_map(map)
    for x, _ in pairs(map) do
        for y, _ in pairs(map[x]) do
            for z, _ in pairs(map[x][y]) do
                map[x][y][z][1] = nil
                map[x][y][z][2] = nil
            end
        end
    end
    return map
end

function pathfinding.prepare_map(map, rcoords, start, finish)
    for x, _ in pairs(map) do
        for y, _ in pairs(map[x]) do
            for z, _ in pairs(map[x][y]) do
                map[x][y][z][1] = map[x][y][z][3] == 0 and true or false
                map[x][y][z][2] = pathfinding.distance({ x, y, z }, start, finish)
            end
        end
    end
    return map
end

function pathfinding.find_near(target, offset_table)
    local arr_return = {}
    for _, v in pairs(offset_table) do
        local x = target[1] + v[1]
        local y = target[2] + v[2]
        local z = target[3] + v[3]
        table.insert(arr_return, { x, y, z })
    end
    return arr_return
end

-- if wp_name has multiple results the closest is chosen
function pathfinding.find_waypoint(wp_name, rcoords)
    local rx, ry, rz = rcoords[1], rcoords[2], rcoords[3]
    local waypoint_search
    local range = 10
    local dist_max = math.huge
    local arr_return = nil
    while true do
        waypoint_search = pathfinding.nav.findWaypoints(range)
        if #waypoint_search > 0 then
            break
        end
        range = range + 10
    end
    for i = 1, #waypoint_search do
        local v = waypoint_search[i]
        if string.find(v.label, wp_name) then
            local wpx, wpy, wpz = v.position[1], v.position[2] - 1, v.position[3]
            local dist_tmp = pathfinding.distance(rcoords, rcoords, { wpx, wpy, wpz })
            if dist_max > dist_tmp then
                wpx = wpx + rx
                wpy = wpy + ry
                wpz = wpz + rz
                arr_return = { wpx, wpy, wpz }
                dist_max = dist_tmp
            end
        end
    end
    return arr_return or false
end

-- /Different Helper Functions


-- Meat And Potatoes

-- map[x][y][z] = {open, distance, hardness, traversable}
function pathfinding.c_map_writer(map, scan, scan_off, rcoords, start, finish)
    local x_off, y_off, z_off = scan_off[1], scan_off[2], scan_off[3]
    local x = rcoords[1] + x_off
    local y = rcoords[2] + y_off
    local z = rcoords[3] + z_off
    map[x] = map[x] or {}
    map[x][y] = map[x][y] or {}
    map[x][y][z] = map[x][y][z] or {}
    local node = map[x][y][z]
    -- hardness [3]
    node[3] = scan
    -- traversability [4]
    if node[3] == 0 then
        node[4] = true
    else
        node[4] = false
    end
    -- open/closed [1]
    if node[1] == nil then
        if node[4] then
            node[1] = true
        else
            node[1] = false
        end
    end
    -- distance [2]
    if not node[2] then
        node[2] = pathfinding.distance({ x, y, z }, start, finish)
    end
end

-- create map of surrounding area and store it to pairs(map)
-- map[x][y][z] = {open, distance, hardness, traversable}
function pathfinding.c_map(map, offset_table, rcoords, start, finish)
    -- depth
    local dx, dz, dy = 3, 3, 3
    -- start
    local sx, sz, sy = -1, -1, -1
    local tmp_scan = pathfinding.geo.scan(sx, sz, sy, dx, dz, dy)
    local scan_out = {}
    scan_out[1] = tmp_scan[5]
    scan_out[2] = tmp_scan[11]
    scan_out[3] = tmp_scan[13]
    scan_out[4] = tmp_scan[15]
    scan_out[5] = tmp_scan[17]
    scan_out[6] = tmp_scan[23]
    for i = 1, 6 do
        pathfinding.c_map_writer(map, scan_out[i], offset_table[i], rcoords, start, finish)
    end
    pathfinding.c_map_writer(map, 0, { 0, 0, 0 }, rcoords, start, finish)
    return map
end

-- map[x][y][z] = {open, distance, hardness, traversable}
-- path[x][y][z] = {open, distance, stepcount, traversable}
function pathfinding.search_next(map)
    local distance_min = math.huge
    local candidates = {}
    for x, _ in pairs(map) do
        for y, _ in pairs(map[x]) do
            for z, _ in pairs(map[x][y]) do
                local open = map[x][y][z][1]
                local dist = map[x][y][z][2]
                if distance_min >= dist and open then
                    distance_min = dist
                    candidates[distance_min] = candidates[distance_min] or {}
                    table.insert(candidates[distance_min], { x, y, z })
                end
            end
        end
    end
    local return_coords = candidates[distance_min][math.random(1, #candidates[distance_min])]
    return return_coords
end

-- produces path
function pathfinding.search_path_helper(path_in, target, steps_in, offset_table)
    local return_path = {}
    table.insert(return_path, target)
    steps_in = steps_in - 1
    while true do
        if steps_in == 0 then
            return return_path
        end
        for i = 1, #offset_table do
            local x = target[1] + offset_table[i][1]
            local y = target[2] + offset_table[i][2]
            local z = target[3] + offset_table[i][3]
            if pathfinding.is_valid_coord(path_in, x, y, z) then
                if path_in[x][y][z][3] == steps_in then
                    table.insert(return_path, 1, { x, y, z })
                    target = { x, y, z }
                    steps_in = steps_in - 1
                    break
                end
            end
        end
    end
end

-- map[x][y][z] = {open, distance, hardness, traversable}
-- path[x][y][z] = {open, distance, stepcount}
function pathfinding.search_path(map, target, rcoords, offset_table)
    local path_tmp = {}
    local final_step
    -- target coords
    local tx, ty, tz = target[1], target[2], target[3]
    -- robot coords
    local rx, ry, rz = rcoords[1], rcoords[2], rcoords[3]
    -- virtual coords
    local vx, vy, vz = rx, ry, rz
    -- write robot current to path_tmp
    path_tmp[rx] = {}
    path_tmp[rx][ry] = {}
    path_tmp[rx][ry][rz] = {}
    path_tmp[rx][ry][rz][2] = math.huge
    path_tmp[rx][ry][rz][3] = 0
    while true do
        if vx == tx and vy == ty and vz == tz then
            break
        end
        -- virtual current
        local vc = path_tmp[vx][vy][vz]
        vc[1] = false
        for _, v in pairs(offset_table) do
            local x = vx + v[1]
            local y = vy + v[2]
            local z = vz + v[3]
            if pathfinding.is_valid_coord(map, x, y, z) then
                local map_trav = map[x][y][z][4]
                if map_trav then
                    path_tmp[x] = path_tmp[x] or {}
                    path_tmp[x][y] = path_tmp[x][y] or {}
                    path_tmp[x][y][z] = path_tmp[x][y][z] or {}
                    local node_tmp = path_tmp[x][y][z]
                    -- open
                    if node_tmp[1] == nil then
                        node_tmp[1] = true
                    end
                    -- distance
                    if not node_tmp[2] then
                        node_tmp[2] = pathfinding.distance({ x, y, z }, rcoords, target)
                    end
                    -- stepcount
                    if not node_tmp[3]
                        or node_tmp[3] > vc[3] + 1 then
                        node_tmp[3] = vc[3] + 1
                    end
                end
            end
        end
        local next_step = pathfinding.search_next(path_tmp)
        vx, vy, vz = next_step[1], next_step[2], next_step[3]
    end
    final_step = path_tmp[tx][ty][tz][3]
    local path_return = pathfinding.search_path_helper(path_tmp, target, final_step, offset_table)
    return path_return
end

function pathfinding.pathfinding_loop(map, rcoords, start, finish, offset_table, correction_coords)
    local fx, fy, fz = finish[1], finish[2], finish[3]
    local repeats = 1
    while true do
        rcoords = pathfinding.get_coord(correction_coords)
        local rx, ry, rz = rcoords[1], rcoords[2], rcoords[3]
        if rx == fx and ry == fy and rz == fz then
            break
        end
        map = pathfinding.c_map(pathfinding.us.dcopy(map), offset_table, rcoords, start, finish)
        map[rx][ry][rz][1] = false
        next = pathfinding.search_next(map)
        rcoords = pathfinding.get_coord(correction_coords)
        local path = pathfinding.search_path(map, next, rcoords, offset_table)
        for _, v in pairs(path) do
            local moved = pathfinding.move_it(v, rcoords)
            -- !! if robot hasn't moved wipe map (something changed)
            if not moved then
                -- if next to last move then don't wipe map
                local x, y, z = v[1], v[2], v[3]
                local stepcount = map[x][y][z][2]
                if stepcount == 0 then
                    break
                end
                map = {}
                rcoords = pathfinding.get_coord(correction_coords)
                map = pathfinding.c_map(pathfinding.us.dcopy(map), offset_table, rcoords, rcoords, finish)
                break
            end
            rcoords = pathfinding.get_coord(correction_coords)
            map = pathfinding.c_map(pathfinding.us.dcopy(map), offset_table, rcoords, start, finish)
        end
    end
    return map
end

function pathfinding.pathfinding(target, correction_coords)
    local offset_table = {
        [1] = { 0, -1, 0 },
        [2] = { 0, 0, -1 },
        [3] = { -1, 0, 0 },
        [4] = { 1, 0, 0 },
        [5] = { 0, 0, 1 },
        [6] = { 0, 1, 0 }
    }
    local start = {}
    local rcoords = {}
    local map = {}
    -- rcoord, start
    rcoords = pathfinding.get_coord(correction_coords)
    start = rcoords
    -- map
    map = pathfinding.read_map()
    map = pathfinding.prepare_map(pathfinding.us.dcopy(map), rcoords, start, target)
    -- !! if robot position is not in saved map wipe map
    if not pathfinding.is_valid_coord(map, rcoords[1], rcoords[2], rcoords[3]) then
        map = {}
    end
    map = pathfinding.pathfinding_loop(map, rcoords, start, target, offset_table, correction_coords)
    pathfinding.save_map(map)
end

-- /Meat And Potatoes

return pathfinding
