local pf = require("pathfinding")

local function main_loop()
local correction_coords = pf.coord_correction()
local target = pf.get_target_input()
pf.pathfinding(target, correction_coords)
end

main_loop()
