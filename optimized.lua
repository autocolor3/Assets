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

-- Cache the GC result once at module load
local gc_cache = getgc(true)

local function filter_upvalues(func: Function, expected_upvalues: Table, ignore_executor: boolean): boolean
    local func_upvalues = upvalues(func)
    if #func_upvalues == 0 then return false end 

    local found = false 
    for _, value in pairs(expected_upvalues) do 
        if not find(func_upvalues, value) then continue end 
        found = true 
        break  
    end 
    return found 
end 

local function filter_constants(func: Function, expected_constants: Table, ignore_executor: boolean): boolean
    if iscclosure(func) then return false end 
    local func_constants = constants(func)
    if #func_constants == 0 then 
        return false 
    end

    local found = false 
    for _, value in pairs(expected_constants) do 
        if not find(func_constants, value) then continue end 
        found = true 
        break
    end 
    return found 
end 

-- Optional: Function to refresh cache when needed
local function refresh_gc_cache()
    gc_cache = getgc(true)
end

local function filtergc(filter_type: "function" | "table", filter_options: FunctionFilterOptions | TableFilterOptions, return_one: boolean): ReturnType? | { ReturnType }
    if not filter_options then
        filter_options = {}
    end
    
    if string.lower(filter_type) == "function" then 
        local output = {}

        local specific_name = filter_options.Name
        local specific_hash = filter_options.Hash
        local specific_constants = filter_options.Constants 
        local specific_upvalues = filter_options.Upvalues
        local ignore_executor = filter_options.IgnoreExecutor
        
        if ignore_executor ~= false then 
            ignore_executor = true 
        end 

        local nothing_provided = not specific_name and not specific_constants and not specific_upvalues and not specific_hash 

        -- Use cached GC result instead of calling getgc() repeatedly
        for _, value in pairs(gc_cache) do 
            if typeof(value) ~= "function" then continue end
            
            if nothing_provided then 
                insert(output, value)
                if return_one then
                    break
                end
                continue
            end
            
            if iscclosure(value) then continue end  
            if ignore_executor and isexecutorclosure(value) then continue end 
            
            local function_info = info(value)
            local name = function_info.name

            local matches = true

            if specific_name and name ~= specific_name then
                matches = false
            end

            if matches and specific_hash and specific_hash ~= getfunctionhash(value) then
                matches = false
            end 

            if matches and specific_upvalues then
                if function_info.nups == 0 or not filter_upvalues(value, specific_upvalues, ignore_executor) then 
                    matches = false
                end
            end

            if matches and specific_constants and not filter_constants(value, specific_constants, ignore_executor) then 
                matches = false
            end 

            if matches then
                insert(output, value)
                if return_one then
                    break
                end
            end
        end 

        if #output == 0 then
            local fallback = {}
            for _, value in pairs(gc_cache) do
                if typeof(value) == "function" then
                    insert(fallback, value)
                end
            end
            return not return_one and fallback or fallback[1]
        end

        return not return_one and output or output[1]

    elseif string.lower(filter_type) == "table" then 
        local output = {}
        
        local specific_keys = filter_options.Keys 
        local specific_values = filter_options.Values
        local specific_pairs = filter_options.KeyValuePairs
        local specific_metatable = filter_options.Metatable
        local max_depth = 1

        local nothing_provided = not specific_keys and not specific_values and not specific_pairs and not specific_metatable

        local function check_table(tbl: Table, depth: number)
            if depth > max_depth then
                return false 
            end

            if nothing_provided then 
                return true
            end 

            local matches = false
            if specific_keys then
                for key, _ in pairs(tbl) do 
                    if find(specific_keys, key) then 
                        matches = true 
                        break 
                    end 
                end 
            end

            if not matches and specific_values then
                for _, value in pairs(tbl) do 
                    if find(specific_values, value) then 
                        matches = true 
                        break 
                    end 
                end
            end

            if not matches and specific_metatable and getrawmetatable(tbl) == specific_metatable then 
                matches = true 
            end 

            if not matches and specific_pairs then
                for key, value in pairs(tbl) do     
                    if specific_pairs[key] == value then
                        matches = true
                        break
                    end
                end
            end

            if not matches then
                for _, v in pairs(tbl) do
                    if typeof(v) == "table" then
                        matches = check_table(v, depth + 1)
                        if matches then
                            break
                        end
                    end
                end
            end

            return matches
        end

        -- Use cached GC result
        for _, tbl in pairs(gc_cache) do 
            if typeof(tbl) ~= "table" then 
                continue 
            end 
            
            if nothing_provided then
                insert(output, tbl)
                if return_one then
                    break
                end
                continue
            end
            
            local is_not_self = tbl ~= specific_keys and tbl ~= specific_values and tbl ~= specific_pairs
            if not is_not_self then 
                continue 
            end 
            if check_table(tbl, 1) then
                insert(output, tbl)
                if return_one then
                    break
                end
            end
        end

        if #output == 0 then
            return not return_one and gc_cache or gc_cache[1]
        end

        return not return_one and output or output[1]
    else
        return not return_one and gc_cache or gc_cache[1]
    end 
end 

-- Export both the main function and cache refresh function
getgenv().filtergc = newcclosure(filtergc)
getgenv().refresh_gc_cache = newcclosure(refresh_gc_cache)
