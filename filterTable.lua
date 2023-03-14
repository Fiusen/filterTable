local luaType = typeof and typeof or type;
local getinfo = getinfo or debug.getinfo or function(l) return {func = debug.info(l, "f")} end;

local placeholder = function(f) return {} end
local getconstants, getupvalues, getprotos = getconstants or debug.getconstants or placeholder, getupvalues or debug.getupvalues or placeholder, getprotos or debug.getprotos or placeholder;
local islclosure = islclosure or iscclosure and function(f) return not iscclosure(f) end or function(f) return true end
local unpack = unpack or table.unpack
local pairs = pairs;
local next = next;

local function areValuesInTable(original, toCheck)
    for i, v in pairs(toCheck) do
        if not table.find(original, v) then
            return false
        end
    end
    return true;
end

local function checkType(value, type, descr)
    err = "invalid argument to '"..descr.."' '"..type.."' expected got '%s'" or ""
    local typ = luaType(value)
    assert(typ == type, err:format(typ))
    return true;
end

local function checkExists(value)
    return value ~= nil;
end

local function checkIfType(value, type, descr)
    if not value then return end;
    err = "invalid argument to '"..descr.."' '"..type.."' expected got '%s'" or ""
    local typ = luaType(value)
    assert(typ == type, err:format(typ))
    return true;
end

local function getScript(f)
   local scr = rawget(getfenv(f), "script");
   return typeof(scr) == "Instance" and scr
end

local luaBaseTypes = {
    string = true,
    number = true,
    userdata = true,
    ["function"] = true,
    table = true,
}

local blacklistedFunctions = {}
local blacklistedTables = {}
local createdSignatures = {}

blacklistedTables[blacklistedTables] = true
blacklistedTables[blacklistedFunctions] = true


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

getgenv().blacklistedFunctions = blacklistedFunctions
getgenv().blacklistedTables = blacklistedTables
getgenv().createdSignatures = createdSignatures

local filterTable;

        --[[
            filterOptions = {
                type = <lua type>
                classname = <string>
                property = <<string> roblox property> to check for values inside objects, e.g checking the CFrame property of BasePart's -> {type = "Instance", classname = "BasePart", property = "CFrame"}
                firstmatchonly = <bool>
                logpath = <bool> logs the path taken by the filterTable, may decrease performance
                deepsearch = <bool> searches every function constants, upvalues, protos and env aswell, WILL DECREASE performance
                validator = <<bool> function(i,v)> validates an entry using a function **will override the default checking, so using any options presented below will not work**
            }
        ]]

        --[[
            Types and filterOptions:

                function -> 
                    name = <function name>
                    upvalues = <exact upvalues table of function>
                    constants = <exact constants table of function>
                    protos = <exact protos table of function>
                    matchupvalues = <table with required upvalues of function>
                    matchconstants = <table with required constants of function>
                    matchprotos = <table with required protos of function>
                    upvalueamount = <upvalue amount of function>
                    constantamount = <constant amount of function>
                    protoamount = <proto amount of function>
                    info = <exact debug.info table of function>
                    matchinfo = <table with required debug.info of function>
                    ignoreenv = <bool>
                    script = <Instance <script>> **only for functions with "script" defined in their env**


                table -> 
                    tablematch = {index = <table index>, value = <table value>, validator = (optional) <validator>}
                    tablesize = <size of table>
                    metatable = <exact metatable of table>
                    hasmetatable = <bool>

                userdata -> 
                    metatable = <exact metatable of table>
                    hasmetatable = <bool>
        ]]
do
    filterTable = function(target, filterOptions, nextScan)
        checkType(target, "table", "#1")
        checkType(filterOptions, "table", "#2")

        blacklistedFunctions[getinfo(2).func] = true; -- do not check the caller in next scans

        local ft = {}

        ft.bag = {}

        function ft:createWeakTable(...)
            local wt =  setmetatable({...}, {__mode = "kv"})
            table.insert(ft.bag, wt)
            return wt;
        end

        function ft:createPath(copy, ...)
            return self:createWeakTable((copy and unpack(copy) or nil), ...)
        end

        ft.filteredTables = ft:createWeakTable();
        ft.filteredFunctions = ft:createWeakTable();

        local checkIndex = filterOptions.type == "table" and checkExists(filterOptions.index);
        local checkValue = checkExists(filterOptions.value);

        local checkProperty = checkIfType(filterOptions.property, "string", "filterOptions.property");
        local checkClassName = checkIfType(filterOptions.classname, "string", "filterOptions.classname");

        local deepSearch = checkIfType(filterOptions.deepsearch, "boolean", "filterOptions.deepsearch");
        local logPath = checkIfType(filterOptions.logpath, "boolean", "filterOptions.logpath");
        local validator = checkIfType(filterOptions.validator, "function", "filterOptions.validator");

        ft.mainScan = target;


        function ft:checkTable(target, path)
            if not self.running or self.filteredTables[target] or createdSignatures[rawget(target, "SearchId")] then return end;

            self.filteredTables[target] = true
            self.parent = target;

            local deepFilter = self:createWeakTable();

            for i,v in next, target do

                if not self.filteredFunctions[v] and not blacklistedFunctions[v] then

                    local type = luaType(v);
                    if type == filterOptions.type and (not checkClassName or v.ClassName == filterOptions.classname) and ((not validator and (not checkIndex or self:checkIndex(i)) and (not checkProperty or self:checkProperty(v)) and self:checkValue(v)) or validator and filterOptions.validator(i,v)) then
                        self:writeMatch(i, v, path)
                        if filterOptions.firstmatchonly then
                            self.running = false;
                            break;
                        end
                    end

                    if deepSearch and type == "function" then
                        self.filteredFunctions[v] = true
                        if islclosure(v) then
                            self:checkTable(getconstants(v), logPath and self:createPath(path, v));
                            self:checkTable(getprotos(v), logPath and self:createPath(path, v));
                            self:checkTable(getfenv(v), logPath and self:createPath(path, v));
                        end
                        self:checkTable(getupvalues(v), logPath and self:createPath(path, v));
                    end

                    if type == "table" and (not nextScan or not blacklistedTables[v]) then
                        deepFilter[#deepFilter+1] = v
                    end

                end
            end

            if not self.running then return end

            for i,v in next, deepFilter do
                self:checkTable(v, logPath and self:createPath(path, v));
            end
        end

        function ft:checkIndex(index) -- only for "table" types
            return index == filterOptions.Index
        end

        local function loadTypes()

            -- this is where the actual checking of the values will happen, this function is for pre-loading settings and type checking them before the code actually runs and starts checking the values
            -- this huge amount of variables is created to avoid doing too many CALL's while the values are being checked, so we "inline" all the settings beforehand to increase performance

            if filterOptions.type == "function" then

                local checkName = checkIfType(filterOptions.name, "string", "filterOptions.name");
                local checkUpvalues = checkIfType(filterOptions.upvalues, "table", "filterOptions.upvalues");
                local checkConstants = checkIfType(filterOptions.constants, "table", "filterOptions.constants")    
                local checkProtos = checkIfType(filterOptions.protos, "table", "filterOptions.protos");
                local checkMatchUpvalues = checkIfType(filterOptions.matchupvalues, "table", "filterOptions.matchupvalues")    
                local checkMatchConstants = checkIfType(filterOptions.matchconstants, "table", "filterOptions.matchconstants");
                local checkMatchProtos = checkIfType(filterOptions.matchprotos, "table", "filterOptions.matchprotos")    
                local checkUpvalueAmount = checkIfType(filterOptions.upvalueamount, "number", "filterOptions.upvalueamount");
                local checkConstantAmount = checkIfType(filterOptions.constantamount, "number", "filterOptions.constantamount")    
                local checkProtoAmount = checkIfType(filterOptions.protoamount, "number", "filterOptions.protoamount")    
                local checkInfo = checkIfType(filterOptions.info, "table", "filterOptions.info")    
                local checkMatchInfo = checkIfType(filterOptions.matchinfo, "table", "filterOptions.matchinfo")    
                local checkIgnoreEnv = checkIfType(filterOptions.ignoreenv, "boolean", "filterOptions.ignoreenv")    
                local checkScript = checkIfType(filterOptions.script, "Instance", "filterOptions.script")    


                function ft:checkValue(value)

                    if checkValue then return value == filterOptions.value end

                    if checkIgnoreEnv and table.find(self.env, value) then return end

                    local functionInfo = getinfo(value);
                    local upvalues = getupvalues(value);

                    if checkName and functionInfo.name ~= filterOptions.name then return end

                    if checkUpvalues and upvalues ~= filterOptions.upvalues then return end

                    if not islclosure(value) then -- some of the others values below cant be checked in a cclosure
                        return 
                        (not checkMatchUpvalues or areValuesInTable(upvalues, filterOptions.matchupvalues)) and 
                        (not checkUpvalueAmount or #upvalues == filterOptions.upvalueamount) and 
                        (not checkInfo or functionInfo == filterOptions.info) and 
                        (not checkMatchInfo or areValuesInTable(functionInfo, filterOptions.info)) and 
                        (not checkScript or getScript(value) == filterOptions.script)
                    end

                    local constants = getconstants(value);
                    local protos = getprotos(value);

                    if checkConstants and constants ~= filterOptions.constants then return end
                    if checkProtos and protos ~= filterOptions.protos then return end

                    if checkMatchUpvalues and not areValuesInTable(upvalues, filterOptions.matchupvalues) then return end
                    if checkMatchConstants and not areValuesInTable(constants, filterOptions.matchconstants) then return end
                    if checkMatchProtos and not areValuesInTable(protos, filterOptions.matchprotos) then return end

                    if checkUpvalueAmount and #upvalues ~= filterOptions.upvalueamount then return end
                    if checkConstantAmount and #constants ~= filterOptions.constantamount then return end
                    if checkProtoAmount and #protos ~= filterOptions.protoamount then return end

                    if checkInfo and functionInfo ~= filterOptions.info then return end
                    if checkMatchInfo and not areValuesInTable(functionInfo, filterOptions.info) then return end

                    if checkScript and getScript(value) ~= filterOptions.script then return end

                    return true;
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = value;
                    match.Parent = self.parent;
                    if filterOptions.logpath then match.Path = path end
                    table.insert(self.results, match)
                end

            elseif filterOptions.type == "table" then

                local checkTableSize = checkIfType(filterOptions.tablesize, "number", "filterOptions.tablesize");
                local checkMetatable = checkIfType(filterOptions.metatable, "table", "filterOptions.metatable");
                local checkHasMetatable = checkIfType(filterOptions.hasmetatable, "boolean", "filterOptions.hasmetatable")
                
                
                local checkTableMatch = checkExists(filterOptions.tablematch) 
                local checkTableMatchIndex = checkTableMatch and checkExists(filterOptions.tablematch.index)
                local checkTableMatchValue = checkTableMatch and checkExists(filterOptions.tablematch.value)
                local checkTableMatchValidator = checkTableMatch and checkIfType(filterOptions.tablematch.validator, "function", "filterOptions.tablematch.validator")

                function ft:checkValue(value)

                    if checkValue and value ~= filterOptions.value then return end

                    if checkTableSize and #self.parent ~= filterOptions.tablesize then return end

                    local metatable = getmetatable(value)

                    if checkMetatable and metatable ~= filterOptions.metatable then return end
                    if checkHasMetatable and metatable ~= filterOptions.hasmetatable then return end

                    if checkTableMatch then

                        if checkTableMatchIndex and checkTableMatchValue and rawget(value, filterOptions.tablematch.index) == filterOptions.tablematch.value then
                            return not checkTableMatchValidator or filterOptions.tablematch.validator(filterOptions.tablematch.index, rawget(value, filterOptions.tablematch.index))
                        elseif not checkTableMatchIndex and checkTableMatchValue and table.find(value, filterOptions.tablematch.value) then
                            return not checkTableMatchValidator or filterOptions.tablematch.validator(table.find(value, filterOptions.tablematch.value), filterOptions.tablematch.value)
                        elseif checkTableMatchIndex and not checkTableMatchValue and checkExists(rawget(value, filterOptions.tablematch.index)) then
                            return not checkTableMatchValidator or filterOptions.tablematch.validator(filterOptions.tablematch.index, rawget(value, filterOptions.tablematch.index))
                        end

                        return false;
                        
                    end
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = value;
                    match.Parent = self.parent;
                    match.TableSize = #self.parent;
                    if filterOptions.logpath then match.Path = path end

                    table.insert(self.results, match)
                end

            elseif filterOptions.type == "userdata" then

                local checkMetatable = checkIfType(filterOptions.metatable, "table", "filterOptions.metatable");
                local checkHasMetatable = checkIfType(filterOptions.hasmetatable, "boolean", "filterOptions.hasmetatable")

                function ft:checkValue(value)

                    local metatable = getmetatable(value)

                    if checkMetatable and metatable ~= filterOptions.metatable then return end
                    if checkHasMetatable and not (filterOptions.hasmetatable and metatable or not filterOptions.hasmetatable and not metatable) then return end

                    if checkValue and value ~= filterOptions.value then return end

                    return true;
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = value;
                    match.Parent = self.parent;
                    if filterOptions.logpath then match.Path = path end

                    table.insert(self.results, match)
                end

            elseif not luaBaseTypes[filterOptions.type] then -- roblox types

                function ft:checkValue(value)
                    return not checkValue and true or not checkProperty and filterOptions.value == value or checkProperty and value[filterOptions.property] == filterOptions.value
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = filterOptions.value;
                    match.Object = value
                    match.Parent = self.parent;
                    if filterOptions.logpath then match.Path = path end

                    table.insert(self.results, match)
                end

                function ft:checkProperty(value)
                    return self:checkValue(value)
                end

            else

                function ft:checkValue(value)
                    return checkValue and filterOptions.value == value;
                end

                function ft:writeMatch(index, value, path)
                    local match = self:createWeakTable();
                    match.Index = index;
                    match.Value = value;
                    match.Parent = self.parent;
                    if filterOptions.logpath then match.Path = path end

                    table.insert(self.results, match)
                end
            end

        end

        loadTypes();

        ft.env = getfenv();
        ft.results = ft:createWeakTable();

        ft.running = true;
        ft:checkTable(target, ft:createPath({target}));

        local signature = generateSignature();
        --[[
            we use a signature since its not possible to just hold the results table into a secondary table (such as blacklistedTables),
            this will be too performance costly since the garbage collector wont be able to free the results
            and since the results will - sometimes - carry its path within, that means the original table will start getting saved in many different places
            resulting in a slower filterTable every time you execute you (incase you end up reaching it)
            to avoid all that we just append a SearchId value to our results table, that way we ensure we can detect it and cause no performance cost
        ]]

        local results = ft.results; 

        for i,v in pairs(results) do
            v.SearchId = signature;
        end

        for i,v in pairs(ft.bag) do
            ft.bag[i] = nil
        end

        local nextScan;

        nextScan = function(nextScanFilterOptions)

            local latestResults = ft.results;

            ft.running = true;

            ft.results = ft:createWeakTable(); -- clean for new entries

            ft.filteredTables = ft:createWeakTable()
            ft.filteredFunctions = ft:createWeakTable()

            filterOptions = {}
            for i,v in pairs(nextScanFilterOptions) do -- update new filterOptions
                filterOptions[i] = v
            end

            loadTypes();

            --[[
            local scanTarget = ft.mainScan;
            local beforeParents = {}
            for i,v in next, latestResults do
                table.insert(beforeParents, v.Parent)
            end

            local scanResults = filterTable(scanTarget, filterOptions)
            local keep = {}

            for i,v in next, scanResults do
                if table.find(beforeParents, v.Parent) then
                    table.insert(keep, v)
                end
            end
            ]]

            ft.results = {}

            for i,v in next, latestResults do
                if luaType(v) == filterOptions.type and (not checkClassName or v.ClassName == filterOptions.classname) and ((not validator and (checkIndex and ft:checkIndex(i) or not checkIndex) and (not checkProperty or self:checkProperty(v)) and self:checkValue(v)) or validator and filterOptions.validator(i,v)) then
                    table.insert(ft.results, v)
                end
            end

            return setmetatable(ft.results, {__index = function(self, i) if i == "nextScan" then return nextScan end end, __mode = "kv"})
        end

        return setmetatable(ft.results, {__index = function(self, i) if i == "nextScan" then return nextScan end end, __mode = "kv"});
    end

end

getgenv().filterTable = filterTable

return filterTable
