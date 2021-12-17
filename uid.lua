local uid = {}
uid.__index = uid

function uid.next()
    local id = ""
    for i = 1, 8 do
        id = id .. string.char(math.random(97, 122))
    end
    return id
end

return uid
