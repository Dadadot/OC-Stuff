local usual_suspects = {}

-- deep copy without metatables
function usual_suspects.dcopy(table_in)
    local copy = {}
    for k, v in pairs(table_in) do
        if type(v) == 'table' then
            copy[k] = usual_suspects.dcopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- good ol'
function usual_suspects.any(val, table)
    for _, v in pairs(table) do
        if val == v then
            return true
        end
    end
    return false
end

-- bool conversion stuff
function usual_suspects.btn(bool)
    return bool and 1 or 0
end

function usual_suspects.ntb(num)
    return num == 1 and true or false
end

-- falsy = anything that == 0 and "false"(caseinsensitive), rest true
function usual_suspects.stb(str)
    assert(type(str) == "string", "stb expects a string.")
    str = string.upper(str)
    if tonumber(str) and tonumber(str) == 0 then return false end
    if str == "FALSE" then return false end
    return true
end

return usual_suspects
