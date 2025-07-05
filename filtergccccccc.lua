function bitEqual(a, b)
    if type(a) ~= type(b) then
        return false
    end

    return type(a) == "number" and string.format("%a", a) == string.format("%a", b) or a == b
end

getgenv().filtergc = function(typef, options, return_one) -- typef: string, options: table, return_one: boolean
    assert(typef == "function" or typef == "table", "Invalid type: " .. tostring(typef)) -- make sure user isnt a retard
    assert(typeof(options) == "table", "Options must be a table.") -- same here ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

    local filterFound = {}

    if options.IgnoreSyn ~= nil then options.IgnoreExecutor = options.IgnoreSyn end

    if typef == "function" then 
        for _,v in ipairs(getgc()) do
            if typeof(v) == "function" and islclosure(v) then
                local matches = true

                if options.IgnoreExecutor ~= false then options.IgnoreExecutor = true end
                
                if options.IgnoreExecutor and not isexecutorclosure(v) then
                    if options.Name and not bitEqual(debug.getinfo(v).name, options.Name) then
                        matches = false
                    end

                    if matches and options.Constants and not iscclosure(v) then 
                        local constants = debug.getconstants(v)
                        for _, k in ipairs(options.Constants) do
                            if not table.find(constants, k) then
                                matches = false
                                break
                            end
                        end
                    end

                    if matches and options.Upvalues and not iscclosure(v) then 
                        local upvalues = debug.getupvalues(v)
                        for _, k in ipairs(options.Upvalues) do
                            if not table.find(upvalues, k) then
                                matches = false
                                break
                            end
                        end
                    end

                    if matches then
                        table.insert(filterFound, v)
                        if return_one then
                            return v -- still kinda unclear of how return one works, docs dont touch up on if its false or true but im assuming it works like this
                        end
                    end
                elseif not options.IgnoreExecutor then
                    
                    if options.Name and debug.getinfo(v).name ~= options.Name then
                        matches = false
                    end

                    if matches and options.Constants and not iscclosure(v) then
                        local constants = debug.getconstants(v)
                        for _, k in ipairs(options.Constants) do
                            if not table.find(constants, k) then
                                matches = false
                                break
                            end
                        end
                    end

                    if matches and options.Upvalues and not iscclosure(v) then 
                        local upvalues = debug.getupvalues(v)
                        for _, k in ipairs(options.Upvalues) do
                            if not table.find(upvalues, k) then
                                matches = false
                                break
                            end
                        end
                    end

                    if matches then
                        table.insert(filterFound, v)
                        if return_one then
                            return v
                        end
                    end
                end
            end
        end
    elseif typef == "table" then
        for _,v in ipairs(getgc(true)) do
            if typeof(v) == "table" then
                local matches = true

                if options.Keys then
                    for _, key in ipairs(options.Keys) do
                        if not rawget(v, key) then
                            matches = false
                            break
                        end
                    end
                end

                if matches and options.Values then
                    for _, val in ipairs(options.Values) do
                        for _, tableVal in pairs(v) do
                            if bitEqual(tableVal, val) then
                                break
                            end
                        end

                        matches = false
                    end
                end

                if matches and options.KeyValuePairs then
                    for key, value in pairs(options.KeyValuePairs) do
                        if not bitEqual(rawget(v,key),value) then
                            matches = false
                            break
                        end
                    end
                end

                if matches and options.Metatable then
                    if not bitEqual(getmetatable(v), options.Metatable) then
                        matches = false
                    end
                end

                if matches then
                    table.insert(filterFound, v)
                    if return_one then
                        break
                    end
                end
            end
        end
    end

    return return_one and filterFound[1] or nil
end
