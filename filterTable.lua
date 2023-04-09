local luaType = typeof or type;
local getinfo = getinfo or debug.getinfo
local getCaller = getinfo and function(l) return getinfo(l).func end or function(l) return debug.info(l, "f") end
local placeholder = function(f) return {} end
local getconstants, getupvalues, getprotos = getconstants or debug.getconstants or placeholder, getupvalues or debug.getupvalues or placeholder, getprotos or debug.getprotos or placeholder;
local islclosure = islclosure or iscclosure and function(f) return not iscclosure(f) end or function(f) return true end
local getgenv = getgenv or getfenv;
local getrawmetatable = getrawmetatable;

local oldGetScripts = getscripts;
local getscripts = getscripts and (function()
    return oldGetScripts();
end)

local rawget = rawget;
local unpack = unpack or table.unpack
local pairs = pairs;
local ipairs = ipairs;
local next = next;

local table_find = function(tbl, value) -- table.find skips over nil values (???) and constants could have them
    for i, v in pairs(tbl) do
        if v == value then
            return i
        end
    end
end

local tostr = function(str)
    if not getrawmetatable then return tostring(str) end
    local mt = getrawmetatable(str)
    local copy = mt and rawget(mt, "__tostring");
    if copy then 
        local isReadOnly = isreadonly(mt)
        setreadonly(mt, false)
        rawset(mt, "__tostring", nil)
        local r = tostring(str)
        rawset(mt, "__tostring", copy)
        setreadonly(mt, isReadOnly)
        return r
    else
        return tostring(str)
    end
end


local function areValuesInTable(original, toCheck)
    for i, v in pairs(toCheck) do
        if not table_find(original, v) then
            return false
        end
    end
    return true;
end

local function checkType(value, type, descr)
    local typ = luaType(value)
    return assert(typ == type, ("invalid argument to '%s' ('%s' expected got '%s')"):format(descr, type, typ))
end

local function checkExists(value)
    return value ~= nil;
end

local function checkIfType(value, type, descr)
    if not value then return end;
    local typ = luaType(value)
    return assert(typ == type, ("invalid argument to '%s' ('%s' expected got '%s')"):format(descr, type, typ))
end


local function returnIfType(value, type, descr, returnValue)
    if not value then return end;
    local typ = luaType(value)
    assert(typ == type, ("invalid argument to '%s' ('%s' expected got '%s')"):format(descr, type, typ))
    return value;
end

local function getScript(f)
   local scr = rawget(getfenv(f), "script");
   return typeof(scr) == "Instance" and scr
end

local luaBaseTypes = {
    ["string"] = true,
    ["number"] = true,
    ["userdata"] = true,
    ["function"] = true,
    ["table"] = true,
}

local blacklistedValues = {}
local blacklistedTables = {}
local createdSignatures = {}

blacklistedTables[blacklistedTables] = true
blacklistedTables[blacklistedValues] = true
blacklistedTables[createdSignatures] = true


local charset = {}  do -- [0-9a-zA-Z]
    for c = 48, 57  do table.insert(charset, string.char(c)) end
    for c = 65, 90  do table.insert(charset, string.char(c)) end
    for c = 97, 122 do table.insert(charset, string.char(c)) end
end

local function randomString(length)
    local s = "";
    for i = 1, length do
        s = s .. charset[math.random(1, #charset)]
    end
    return s
end

local function generateSignature()
    local sig = randomString(4);
    createdSignatures[sig] = true
    return sig
end

local function checkSignature(sig)
    return createdSignatures[sig]
end

getgenv().blacklistedValues = blacklistedValues
getgenv().blacklistedTables = blacklistedTables
getgenv().createdSignatures = createdSignatures

local filterTable;

        --[[
              filterOptions = {
                type = <lua type> searches for the specific given type
                returnFirst = <bool> whether or not only the first matched value will be returned
                logpath = <bool> logs the path taken by the filterTable, may decrease performance
                deepsearch = <bool> searches every function constants, upvalues, protos and env (will decrease performance)
                validator = <<bool> function(i,v)> validates an entry using a function **will override the default checking, so using any options presented below will not work**
            }

     extra filterOptions for specific types:

            function -> 
                name = <function name>
                upvalues = <exact upvalues table of function>
                constants = <exact constants table of function>
                protos = <exact protos table of function>
                matchUpvalues = <table with required upvalues of function>
                matchConstants = <table with required constants of function>
                matchProtos = <table with required protos of function>
                upvalueAmount = <upvalue amount of function>
                constantAmount = <constant amount of function>
                protoAmount = <proto amount of function>
                info = <exact debug.info table of function>
                matchInfo = <table with required debug.info of function>
                ignoreEnv = <bool>
                script = <Instance <script>> **only for functions with "script" defined in their env**


            table -> 
                tableMatch = {index = <table index>, value = <table value>, validator = <validator>}
                tableSize = <size of table>
                metatable = <exact metatable of table>
                hasMetatable = <bool>

            userdata -> 
                metatable = <exact metatable of table>
                hasMetatable = <bool>

            [roblox type] ->
                className = <string>
                property = <<string> roblox property name> for checking properties of objects, e.g checking the CFrame property of BasePart's -> {type = "Instance", classname = "BasePart", property = "CFrame", value = CFrame.new()} 

      return format =  {
          {
             Value,
             Index,
             Parent,
             SearchId,
             (additional values)
          },
          (...)
     }
        ]]
do
    filterTable = function(target, filterOptions, isNextScan)
        checkType(target, "table", "#1")
        checkType(filterOptions, "table", "#2")

        local caller = getCaller(2)
        local fenv = getfenv(isNextScan and 1 or 2)

        if caller then
            blacklistedValues[caller] = true; -- do not check the caller in next scans
        end
        
        if fenv and fenv.script then
            blacklistedValues[fenv.script] = true; -- do not check the caller script in next scans
        end

        local ft = {}

        ft.bag = {}

        function ft:createWeakTable(...)
            local wt =  setmetatable({...}, {__mode = "v"})
            table.insert(ft.bag, wt)
            return wt;
        end

        function ft:createPath(copy, ...)
            return self:createWeakTable((copy and unpack(copy) or nil), ...)
        end

        ft.filteredTables = ft:createWeakTable();
        ft.filteredFunctions = ft:createWeakTable();

        local checkValue = checkExists(filterOptions.value);

        local deepSearch = checkIfType(filterOptions.deepSearch, "boolean", "filterOptions.deepSearch");
        local searchScripts = checkIfType(filterOptions.searchScripts, "boolean", "filterOptions.searchScripts");
        local searchEnv = checkIfType(filterOptions.searchEnv, "boolean", "filterOptions.searchEnv");

        local logPath = checkIfType(filterOptions.logPath, "boolean", "filterOptions.logPath");
        local validator = checkIfType(filterOptions.validator, "function", "filterOptions.validator");
            
        if validator then -- do not search on validator function
            blacklistedValues[filterOptions.validator] = true 
        end

        local noType = not filterOptions.type and validator -- filterTable will only work based on validator, any type would pass

        ft.mainScan = target;

        function ft:checkTable(target, path)
            if not self.running or self.filteredTables[target] or blacklistedTables[target] or checkSignature(rawget(target, "SearchId")) then return end;

            self.filteredTables[target] = true

            local currentParent = target; -- unfortunate but needed for performance gain (see below)
            self.parent = target;

            for i,v in next, target do

                if not self.filteredFunctions[v] and not blacklistedValues[v] then

                    local type = luaType(v);
                    if (type == filterOptions.type or noType) and (validator and filterOptions.validator(i, v) or not validator and self:checkValue(v)) then
                        
                        if isNextScan and checkSignature(rawget(currentParent, "ScanId")) then
                            local info = currentParent;
                            self.parent = info.Parent self:writeMatch(info.Index, v, path) self.parent = currentParent;
                        else
                            self:writeMatch(i, v, path)
                        end

                        if filterOptions.returnFirst then
                            self.running = false;
                            break;
                        end
                    end

                    if deepSearch and type == "function" then
                        self.filteredFunctions[v] = true
                        local newPath = logPath and self:createPath(path, v);
                        if islclosure(v) then
                            self:checkTable(getconstants(v), newPath) self.parent = currentParent;
                            self:checkTable(getprotos(v), newPath) self.parent = currentParent;
                            self:checkTable(getfenv(v), newPath) self.parent = currentParent;
                        end
                        self:checkTable(getupvalues(v), newPath) self.parent = currentParent;
                    end

                    if searchScripts and type == "Instance" and (v.ClassName == "LocalScript" or v.ClassName == "ModuleScript") then
                        self.filteredFunctions[v] = true;

                        local newPath = logPath and self:createPath(path, v);

                        local scriptClosure = getscriptclosure(v);
                        if scriptClosure then
                            self:checkTable(self:createWeakTable(scriptClosure), newPath) self.parent = currentParent;
                        end

                        if searchEnv then -- waiting on syn fix...
                            local scriptEnv;
            
                            local s, e = pcall(getsenv, v); -- no other way to check if script is running
                            scriptEnv = s and e;

                            if scriptEnv then
                                self:checkTable(scriptEnv, newPath) self.parent = currentParent
                            end
                        end

                    end

                    if (type == "table" and not blacklistedTables[v] and not (isNextScan and checkSignature(rawget(currentParent, "ScanId")) and v == currentParent.Parent)) then
                        self:checkTable(v, logPath and self:createPath(path, v)) self.parent = currentParent;
                    end

                end


            end


            if not self.running then return end

        end

        local function loadTypes()

            -- this is where the actual checking of the values will happen, this function is for pre-loading settings and type checking them before the code actually runs and starts checking the values
            -- this huge amount of variables is created to avoid doing too many CALL's while the values are being checked, so we "inline" all the settings beforehand to increase performance

            if filterOptions.type == "function" then

                local checkName = returnIfType(filterOptions.name, "string", "filterOptions.name");
                local checkUpvalues = returnIfType(filterOptions.upvalues, "table", "filterOptions.upvalues");
                local checkConstants = returnIfType(filterOptions.constants, "table", "filterOptions.constants")    
                local checkProtos = returnIfType(filterOptions.protos, "table", "filterOptions.protos");
                local checkMatchUpvalues = returnIfType(filterOptions.matchUpvalues, "table", "filterOptions.matchUpvalues")    
                local checkMatchConstants = returnIfType(filterOptions.matchConstants, "table", "filterOptions.matchConstants");
                local checkMatchProtos = returnIfType(filterOptions.matchProtos, "table", "filterOptions.matchProtos")    
                local checkUpvalueAmount = returnIfType(filterOptions.upvalueAmount, "number", "filterOptions.upvalueAmount");
                local checkConstantAmount = returnIfType(filterOptions.constantAmount, "number", "filterOptions.constantAmount")    
                local checkProtoAmount = returnIfType(filterOptions.protoAmount, "number", "filterOptions.protoAmount")    
                local checkInfo = returnIfType(filterOptions.info, "table", "filterOptions.info")    
                local checkMatchInfo = returnIfType(filterOptions.matchInfo, "table", "filterOptions.matchInfo")    
                local checkIgnoreEnv = returnIfType(filterOptions.ignoreEnv, "boolean", "filterOptions.ignoreEnv")    
                local checkScript = returnIfType(filterOptions.script, "Instance", "filterOptions.script")    

                function ft:checkValue(value)

                    if checkValue then return value == filterOptions.value end

                    if checkIgnoreEnv and (rawget(self.env, value) or table_find(self.env, value)) then return end

                    local functionInfo = getinfo(value);
                    local upvalues = getupvalues(value);

                    if checkName and functionInfo.name ~= checkName then return end

                    if checkUpvalues and upvalues ~= checkUpvalues then return end

                    if not islclosure(value) then -- some of the others values below cant be checked in a cclosure

                        -- cant check those in c closures
                        if (checkConstantAmount or checkConstants or checkMatchConstants or checkProtoAmount or checkProtos or checkMatchProtos) then
                            return false;
                        end

                        return
                        (not checkMatchUpvalues or areValuesInTable(upvalues, checkMatchUpvalues)) and 
                        (not checkUpvalueAmount or #upvalues == checkUpvalueAmount) and 
                        (not checkInfo or functionInfo == checkInfo) and 
                        (not checkMatchInfo or areValuesInTable(functionInfo, checkMatchInfo)) and 
                        (not checkScript or getScript(value) == checkScript)
                    end

                    local constants = getconstants(value);
                    local protos = getprotos(value);

                    if checkConstants and constants ~= checkConstants then return end
                    if checkProtos and protos ~= checkProtos then return end

                    if checkMatchUpvalues and not areValuesInTable(upvalues, checkMatchUpvalues) then return end
                    if checkMatchConstants and not areValuesInTable(constants, checkMatchConstants) then return end
                    if checkMatchProtos and not areValuesInTable(protos, checkMatchProtos) then return end

                    if checkUpvalueAmount and #upvalues ~= checkUpvalueAmount then return end
                    if checkConstantAmount and #constants ~= checkConstantAmount then return end
                    if checkProtoAmount and #protos ~= checkProtoAmount then return end

                    if checkInfo and functionInfo ~= checkInfo then return end
                    if checkMatchInfo and not areValuesInTable(functionInfo, checkMatchInfo) then return end

                    if checkScript and getScript(value) ~= checkScript then return end

                    return true;
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = value;
                    match.Parent = self.parent;
                    if filterOptions.logPath then match.Path = path end
                    table.insert(self.results, match)
                end

            elseif filterOptions.type == "table" then
                
                local checkTableSize = returnIfType(filterOptions.tableSize, "number", "filterOptions.tableSize");
                local checkMetatable = returnIfType(filterOptions.metatable, "table", "filterOptions.metatable");
                local checkHasMetatable = returnIfType(filterOptions.hasMetatable, "boolean", "filterOptions.hasMetatable")
                
                
                local checkTableMatch = checkExists(filterOptions.tableMatch) 
                local checkTableMatchIndex = checkTableMatch and checkExists(filterOptions.tableMatch.index)
                local checkTableMatchValue = checkTableMatch and checkExists(filterOptions.tableMatch.value)
                local checkTableMatchValidator = checkTableMatch and checkIfType(filterOptions.tableMatch.validator, "function", "filterOptions.tableMatch.validator")
                
                local checkValues = checkIfType(filterOptions.matchValues, "table", "filterOptions.values")    
                local checkMatchValues = checkIfType(filterOptions.matchValues, "table", "filterOptions.matchValues")    
                    
                local matchIndex = checkTableMatchIndex and filterOptions.tableMatch.index
                local matchValue = checkTableMatchValue and filterOptions.tableMatch.value

                function ft:checkValue(value)

                    if checkMatchValues and not areValuesInTable(value, checkMatchValues) then return end

                    if checkValues and not areValuesInTable(checkValues, value) then return end

                    if checkValue and value ~= filterOptions.value then return end

                    if checkTableSize and #self.parent ~= checkTableSize then return end

                    local metatable = getmetatable(value)

                    if checkMetatable and metatable ~= checkMetatable then return end
                    if checkHasMetatable and metatable ~= checkHasMetatable then return end

                    if checkTableMatch then

                        if checkTableMatchIndex and checkTableMatchValue and rawget(value, matchIndex) == matchValue then
                            return not checkTableMatchValidator or filterOptions.tableMatch.validator(matchIndex, rawget(value, matchIndex))
                        elseif not checkTableMatchIndex and checkTableMatchValue and table_find(value, matchValue) then
                            return not checkTableMatchValidator or filterOptions.tableMatch.validator(table_find(value, matchValue), matchValue)
                        elseif checkTableMatchIndex and not checkTableMatchValue and checkExists(rawget(value, matchIndex)) then
                            return not checkTableMatchValidator or filterOptions.tableMatch.validator(matchIndex, rawget(value, matchIndex))
                        end

                        return;
                        
                    end
                    
                    return true;
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = value;
                    match.Parent = self.parent;
                    match.TableSize = #self.parent;
                    if filterOptions.logPath then match.Path = path end

                    table.insert(self.results, match)
                end

            elseif filterOptions.type == "userdata" then

                local checkMetatable = returnIfType(filterOptions.metatable, "table", "filterOptions.metatable");
                local checkHasMetatable = returnIfType(filterOptions.hasMetatable, "boolean", "filterOptions.hasMetatable")

                function ft:checkValue(value)

                    local metatable = getmetatable(value)

                    if checkMetatable and metatable ~= checkMetatable then return end
                    if checkHasMetatable and checkHasMetatable == (metatable ~= nil) then return end

                    if checkValue and value ~= filterOptions.value then return end

                    return true;
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = value;
                    match.Parent = self.parent;
                    if filterOptions.logPath then match.Path = path end

                    table.insert(self.results, match)
                end

            elseif not luaBaseTypes[filterOptions.type] then -- roblox types

                local checkProperty = returnIfType(filterOptions.property, "string", "filterOptions.property");
                local checkClassName = returnIfType(filterOptions.className, "string", "filterOptions.className");

                function ft:checkValue(value)
                    return not checkClassName or value.ClassName == checkClassName and (checkProperty and value[checkProperty] == filterOptions.value or not checkProperty and checkValue and filterOptions.value == value or not checkProperty and not checkValue)
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = value;
                    match.Parent = self.parent;
                    if filterOptions.logPath then match.Path = path end

                    table.insert(self.results, match)
                end

            else

                function ft:checkValue(value)
                    return not checkValue or filterOptions.value == value;
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = value;
                    match.Parent = self.parent;
                    if filterOptions.logPath then match.Path = path end

                    table.insert(self.results, match)
                end
            end

        end

        loadTypes();

        ft.env = getfenv();
        ft.results = ft:createWeakTable();
        blacklistedTables[filterOptions] = true


        ft.running = true;
        ft:checkTable(target, logPath and ft:createPath(ft:createWeakTable(target)));


        local signature = generateSignature(); --[[
            we use a signature since its not possible to just hold the results table into a secondary table (such as blacklistedTables),
            this will be too performance costly since the garbage collector wont be able to free the results
            and since the results will - sometimes - carry its path within, that means the original table will start getting saved in many different places
            resulting in a slower filterTable every time you execute you (incase you end up reaching it)
            to avoid all that we just append a SearchId value to our results table, that way we ensure we can detect it and cause no performance cost
        ]]

        local results = ft.results; 

        for i,v in ipairs(results) do
            v.SearchId = signature;
        end

        for i,v in ipairs(ft.bag) do
            ft.bag[i] = nil
        end

        local nextScan, display;

        do -- extra functions

            nextScan = function(nextScanFilterOptions) -- scans latest results with given filterOptions

                nextScanFilterOptions = returnIfType(nextScanFilterOptions, "table", "#1")

                local foundValues = ft:createWeakTable();

                for i,v in ipairs(ft.results) do
                    table.insert(foundValues, { -- made to mantain index and parent static in-between scans
                        Value = v.Parent and rawget(v.Parent, v.Index),
                        Parent = v.Parent,
                        Index = v.Index,
                        ScanId = v.SearchId,
                    })
                end

                return filterTable(foundValues, nextScanFilterOptions or filterOptions, true);
            end

            display = function(limit) -- displays all (or limit) results found in console

                limit = returnIfType(limit, "number", "#1")

                local warn = warn or print;

                if #ft.results == 0 then
                    return warn("\nfilterTable found #0 entries\n")
                else
                    warn("\nfilterTable found #"..#ft.results.." entries")
                end

                print("\n")

                for i, v in ipairs(ft.results) do
                    warn("filterTable (result #"..i..")")
                    for i, v in pairs(v) do
                        if i == "Path" then
                            warn("", i, tostr(v), "->\n")
                            for i, v in pairs(v) do
                                print(" ", i, tostr(v))
                            end
                            print("\n")
                        else
                            print(i, tostr(v))
                        end
                    end
                    print("\n")
                    if limit and i == limit then break end
                end

            end

        end

        return setmetatable(ft.results, {__index = function(self, i) if i == "nextScan" then return nextScan elseif i == "display" then return display end end})
    end
    
end

getgenv().filterTable = filterTable

return filterTable;
