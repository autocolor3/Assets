local cached_gc = nil
local last_gc_fetch_time = 0
local cache_ttl = 5
local last_ignore_executor = nil

local function get_cached_gc(ignore_executor)
    if ignore_executor ~= last_ignore_executor then
        cached_gc = nil
        last_ignore_executor = ignore_executor
    end

    if not cached_gc or (tick() - last_gc_fetch_time) > cache_ttl then
        cached_gc = getgc(true)
        last_gc_fetch_time = tick()
    end

    return cached_gc
end

local function filtergc(filter_type, filter_options, return_one)
    filter_options = filter_options or {}

    if string.lower(filter_type) == "function" then 
        local output = {}
        local specific_name = filter_options.Name
        local specific_hash = filter_options.Hash
        local specific_constants = filter_options.Constants 
        local specific_upvalues = filter_options.Upvalues
        local ignore_executor = filter_options.IgnoreExecutor
        ignore_executor = ignore_executor ~= false

        local nothing_provided = not specific_name and not specific_constants and not specific_upvalues and not specific_hash 

        local gc_data = get_cached_gc(ignore_executor)

        for _, value in pairs(gc_data) do 
            if typeof(value) ~= "function" then continue end

            if nothing_provided then 
                table.insert(output, value)
                if return_one then break end
                continue
            end

            if iscclosure(value) then continue end  
            if ignore_executor and isexecutorclosure(value) then continue end 

            local function_info = debug.getinfo(value)
            local name = function_info.name

            local matches = true
            if specific_name and name ~= specific_name then matches = false end
            if matches and specific_hash and specific_hash ~= getfunctionhash(value) then matches = false end 
            if matches and specific_upvalues and (function_info.nups == 0 or not filter_upvalues(value, specific_upvalues, ignore_executor)) then matches = false end
            if matches and specific_constants and not filter_constants(value, specific_constants, ignore_executor) then matches = false end

            if matches then
                table.insert(output, value)
                if return_one then break end
            end
        end

        if #output == 0 then
            local fallback = {}
            for _, value in pairs(gc_data) do
                if typeof(value) == "function" then
                    table.insert(fallback, value)
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

        local nothing_provided = not specific_keys and not specific_values and not specific_pairs and not specific_metatable

        local gc_data = get_cached_gc(false)

        for _, tbl in pairs(gc_data) do
            if typeof(tbl) ~= "table" then continue end

            if nothing_provided then
                table.insert(output, tbl)
                if return_one then break end
                continue
            end

            local matches = false
            if specific_keys then
                for key in pairs(tbl) do
                    if table.find(specific_keys, key) then
                        matches = true
                        break
                    end
                end
            end

            if not matches and specific_values then
                for _, value in pairs(tbl) do
                    if table.find(specific_values, value) then
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

            if matches then
                table.insert(output, tbl)
                if return_one then break end
            end
        end

        if #output == 0 then
            return not return_one and gc_data or gc_data[1]
        end

        return not return_one and output or output[1]
    else
        local gc_data = get_cached_gc(false)
        return not return_one and gc_data or gc_data[1]
    end
end

getgenv().filtergc = newcclosure(filtergc)
