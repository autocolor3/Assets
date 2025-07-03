type FunctionFilterOptions = {
    Name: string?, 
    Hash: string?,
    IgnoreExecutor: boolean?,
    Constants: { any }?,
    Upvalues: { any }?,
}

type TableFilterOptions = {
    Metatable: { any }?,
    Keys: { any }?,
    Values: { any }?,
    KeyValuePairs: { [any]: any }?,
}

type Function = ((...any) -> (...any))
type Table = ({ [any]: any })
type ReturnType = Function | Table

local info, find, insert = debug.getinfo, table.find, table.insert
local constants, upvalues = debug.getconstants, debug.getupvalues

local function filter_upvalues(func: Function, expected_upvalues: Table): boolean
    local func_upvalues = upvalues(func)
    if #func_upvalues == 0 then return false end 

    for _, value in pairs(expected_upvalues) do 
        if find(func_upvalues, value) then 
            return true 
        end 
    end 
    return false
end 

local function filter_constants(func: Function, expected_constants: Table): boolean
    if iscclosure(func) then return false end 
    local func_constants = constants(func)
    if #func_constants == 0 then return false end

    for _, value in pairs(expected_constants) do 
        if find(func_constants, value) then 
            return true
        end 
    end 
    return false
end 

local function filtergc(
    filter_type: "function" | "table", 
    filter_options: FunctionFilterOptions | TableFilterOptions?,
    return_one: boolean
): ReturnType? | { ReturnType }
    local output = {}

    if string.lower(filter_type) == "function" then
        local opts = filter_options or {}
        local name, hash = opts.Name, opts.Hash
        local constants, upvalues = opts.Constants, opts.Upvalues
        local ignore_executor = opts.IgnoreExecutor
        if ignore_executor == nil then ignore_executor = true end

        local no_filters = not name and not hash and not constants and not upvalues

        for _, v in pairs(getgc()) do
            if typeof(v) ~= "function" then continue end
            if ignore_executor and isexecutorclosure(v) then continue end

            local info = info(v)
            local matches = false

            if no_filters then
                matches = true
            else
                if name and info.name == name then matches = true end
                if hash and getfunctionhash and getfunctionhash(v) == hash then matches = true end
                if constants and filter_constants(v, constants) then matches = true end
                if upvalues and filter_upvalues(v, upvalues) then matches = true end
            end

            if matches then
                insert(output, v)
                if return_one then break end
            end
        end

    elseif string.lower(filter_type) == "table" then
        local opts = filter_options or {}
        local keys, values, pairs, meta = opts.Keys, opts.Values, opts.KeyValuePairs, opts.Metatable

        local no_filters = not keys and not values and not pairs and not meta
        local max_depth = 1

        local function check_table(tbl: Table, depth: number): boolean
            if depth > max_depth then return false end
            if no_filters then return true end

            local matches = false
            if keys then for k, _ in pairs(tbl) do if find(keys, k) then matches = true break end end end
            if values then for _, v in pairs(tbl) do if find(values, v) then matches = true break end end end
            if meta and getrawmetatable(tbl) == meta then matches = true end
            if pairs then for k, v in pairs(tbl) do if pairs[k] == v then matches = true break end end end

            if not matches then
                for _, v in pairs(tbl) do
                    if typeof(v) == "table" then
                        if check_table(v, depth + 1) then return true end
                    end
                end
            end

            return matches
        end

        for _, tbl in pairs(getgc(true)) do
            if typeof(tbl) ~= "table" then continue end
            if check_table(tbl, 1) then
                insert(output, tbl)
                if return_one then break end
            end
        end
    end

    return return_one and output[1] or output
end

getgenv().filtergc = newcclosure(filtergc)
