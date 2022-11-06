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

function usual_suspects.stb(str)
    return usual_suspects.any(str, { "true", "1" }) and true or false
end

return usual_suspects
