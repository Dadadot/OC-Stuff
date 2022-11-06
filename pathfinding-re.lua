local robot = require("robot")
local component = require("component")
local geo = component.geolyzer
local nav = component.navigation

local function dcopy(table_in)
    local copy = {}
    for k, v in pairs(table_in) do
        if type(v) == 'table' then
            copy[k] = dcopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function is_valid_coord(map, x, y, z)
    if map[x] and map[x][y] and map[x][y][z] then
        return true
    end
    return false
end

local function any(val, table)
    for _, v in pairs(table) do
        if val == v then
            return true
        end
    end
    return false
end

-- i don't know if this is even necessary
local function btn(bool)
    return bool and 1 or 0
end

local function ntb(num)
    return num == 1 and true or false
end

local function stb(str)
    return any(str, { "true", "1" }) and true or false
end

-- map[x][y][z] = {open, distance, hardness, traversable}
local function save_map(map)
    local file = assert(io.open("map.txt", "w"))
    io.output(file)
    for x, _ in pairs(map) do
        for y, _ in pairs(map[x]) do
            for z, m in pairs(map[x][y]) do
                io.write(x, " ", y, " ", z, " ", m[3], " ", btn(m[4]), " \n")
            end
        end
    end
end

local function read_map()
    local arr_return = {}
    local file = io.open("map.txt", "r")
    if not file then return {} end
    io.input(file)
    while true do
        local line = io.read('*line')
        if not line then break end
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
        local h, t = tonumber(arr_tmp[4]), stb(arr_tmp[5])
        arr_return[x] = arr_return[x] or {}
        arr_return[x][y] = arr_return[x][y] or {}
        arr_return[x][y][z] = arr_return[x][y][z] or { nil, nil, h, t }
    end
    return arr_return
end

-- match robots perceived coordinates with 'true' ingame coordinates
local function coord_correction()
    io.write("Enter robot x, y and z coordinates (seperated by spaces): \n")
    local io_x, io_y, io_z = io.read("*n", "*n", "*n")
    local nav_x, nav_y, nav_z = nav.getPosition()
    local offset_x = nav_x - io_x
    local offset_y = nav_y - io_y
    local offset_z = nav_z - io_z
    return { offset_x, offset_y, offset_z }
end

-- all coordinates +1000 because fuck negatives coordinates
local function get_coord(correction_coords)
    local nav_x, nav_y, nav_z = nav.getPosition()
    local x = nav_x - correction_coords[1] + 1000
    local y = nav_y - correction_coords[2] + 1000
    local z = nav_z - correction_coords[3] + 1000
    return { x, y, z }
end

-- robot moving stuff
local function turn_it(robotDir, targetDir)
    if robotDir == 5.0 then
        if targetDir == 4.0 then
            robot.turnAround()
        elseif targetDir == 3.0 then
            robot.turnRight()
        else
            robot.turnLeft()
        end
    elseif robotDir == 4.0 then
        if targetDir == 5.0 then
            robot.turnAround()
        elseif targetDir == 3.0 then
            robot.turnLeft()
        else
            robot.turnRight()
        end
    elseif robotDir == 3.0 then
        if targetDir == 5.0 then
            robot.turnLeft()
        elseif targetDir == 4.0 then
            robot.turnRight()
        else
            robot.turnAround()
        end
    else
        if targetDir == 5.0 then
            robot.turnRight()
        elseif targetDir == 4.0 then
            robot.turnLeft()
        else
            robot.turnAround()
        end
    end
end

local function move_it(target, r_coord)
    local target_x, target_y, target_z = target[1], target[2], target[3]
    local target_dir
    local r_dir = nav.getFacing()
    if r_coord[2] > target_y then
        return robot.down()
    elseif r_coord[2] < target_y then
        return robot.up()
    else
        if r_coord[1] > target_x then target_dir = 4.0
        elseif r_coord[1] < target_x then target_dir = 5.0
        elseif r_coord[3] > target_z then target_dir = 2.0
        elseif r_coord[3] < target_z then target_dir = 3.0
        end
        if r_dir ~= target_dir then
            turn_it(r_dir, target_dir)
        end
        return robot.forward()
    end
end

local function distance(self_in, start, target)
    local sd = (math.abs(start[1] - self_in[1]) + math.abs(start[2] - self_in[2]) +
        math.abs(start[3] - self_in[3]))
    local td = math.abs(target[1] - self_in[1]) + math.abs(target[2] - self_in[2]) +
        math.abs(target[3] - self_in[3])
    return td + sd
end

local function reset_map(map)
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

local function prepare_map(map, rcoords, start, finish)
    for x, _ in pairs(map) do
        for y, _ in pairs(map[x]) do
            for z, _ in pairs(map[x][y]) do
                map[x][y][z][1] = map[x][y][z][3] == 0 and true or false
                map[x][y][z][2] = distance({ x, y, z }, start, finish)
            end
        end
    end
    return map
end

-- map[x][y][z] = {open, distance, hardness, traversable}
-- impure
local function c_map_writer(map, scan, scan_off, rcoords, start, finish)
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
        node[2] = distance({ x, y, z }, start, finish)
    end
end

-- create map of surrounding area and store it to pairs(map)
-- map[x][y][z] = {open, distance, hardness, traversable}
local function c_map(map, offset_table, rcoords, start, finish)
    -- depth
    local dx, dz, dy = 3, 3, 3
    -- start
    local sx, sz, sy = -1, -1, -1
    local tmp_scan = geo.scan(sx, sz, sy, dx, dz, dy)
    local scan_out = {}
    scan_out[1] = tmp_scan[5]
    scan_out[2] = tmp_scan[11]
    scan_out[3] = tmp_scan[13]
    scan_out[4] = tmp_scan[15]
    scan_out[5] = tmp_scan[17]
    scan_out[6] = tmp_scan[23]
    for i = 1, 6 do
        c_map_writer(map, scan_out[i], offset_table[i], rcoords, start, finish)
    end
    c_map_writer(map, 0, { 0, 0, 0 }, rcoords, start, finish)
    return map
end

-- map[x][y][z] = {open, distance, hardness, traversable}
-- path[x][y][z] = {open, distance, stepcount, traversable}
local function search_next(map)
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
local function search_path_helper(path_in, target, steps_in, offset_table)
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
            if is_valid_coord(path_in, x, y, z) then
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
local function search_path(map, target, rcoords, offset_table)
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
            if is_valid_coord(map, x, y, z) then
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
                        node_tmp[2] = distance({ x, y, z }, rcoords, target)
                    end
                    -- stepcount
                    if not node_tmp[3]
                        or node_tmp[3] > vc[3] + 1 then
                        node_tmp[3] = vc[3] + 1
                    end
                end
            end
        end
        local next_step = search_next(path_tmp)
        vx, vy, vz = next_step[1], next_step[2], next_step[3]
    end
    final_step = path_tmp[tx][ty][tz][3]
    local path_return = search_path_helper(path_tmp, target, final_step, offset_table)
    return path_return
end

local function main()
    local offset_table = {
        [1] = { 0, -1, 0 },
        [2] = { 0, 0, -1 },
        [3] = { -1, 0, 0 },
        [4] = { 1, 0, 0 },
        [5] = { 0, 0, 1 },
        [6] = { 0, 1, 0 }
    }
    local start = {}
    local finish = {}
    local correction_coords = {}
    local rcoords = {}
    local map = {}
    local path = {}
    -- rcoord, start
    correction_coords = coord_correction()
    rcoords = get_coord(correction_coords)
    start = rcoords
    -- finish
    io.write("Target: \n")
    local fx, fy, fz = io.read("*n", "*n", "*n")
    fx, fy, fz = fx + 1000, fy + 1000, fz + 1000
    finish = { fx, fy, fz }
    -- map
    map = read_map()
    map = prepare_map(dcopy(map), rcoords, start, finish)

    while true do
        rcoords = get_coord(correction_coords)
        local rx, ry, rz = rcoords[1], rcoords[2], rcoords[3]
        if rx == fx and ry == fy and rz == fz then
            save_map(map)
            break
        end
        map = c_map(dcopy(map), offset_table, rcoords, start, finish)
        map[rx][ry][rz][1] = false
        next = search_next(map)
        rcoords = get_coord(correction_coords)
        path = search_path(map, next, rcoords, offset_table)
        for k, _ in pairs(path) do
            local moved = move_it(path[k], rcoords)
            if not moved then
                map = {}
                rcoords = get_coord(correction_coords)
                map = c_map(dcopy(map), offset_table, rcoords, rcoords, finish)
                break
            end
            rcoords = get_coord(correction_coords)
            map = c_map(dcopy(map), offset_table, rcoords, start, finish)
        end
    end
end

main()
