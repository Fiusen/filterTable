local luaType = typeof and typeof or type;

local function areValuesInTable(original, toCheck)
    for i, v in pairs(toCheck) do
        if not table.find(original, v) then
            return false
        end
    end
    return true;
end

local function doConstantsMatch(func, tableOfConstants)
    local constants = getconstants(func)
    for i, v in pairs(tableOfConstants) do
        if not table.find(constants, v) then
            return false
        end
    end
    return true;
end

local function GetChildrenOfClass(obj, className)
    local children = {}
    for i, v in pairs(obj:GetChildren()) do
        if v.ClassName == className then
            table.insert(children, v)
        end
    end
    return children;
end

local function checkType(value, type, err)
    err = err or ""
    local typ = luaType(value)
    assert(typ == type, err:format(typ))
    return true;
end

local function checkExists(value)
    return value ~= nil;
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
                    index = <table index> or <filterOptions> or <validator>
                    value = <table value> or <filterOptions> or <validator>
                    tablesize = <size of table>
                    metatable = <exact metatable of table>
                    hasmetatable = <bool>

                userdata -> 
                    metatable = <exact metatable of table>
                    hasmetatable = <bool>
        ]]
do
    filterTable = function(target, filterOptions, nextScan)
        checkType(target, "table", "invalid argument to #1 'table' expected got %s")
        checkType(filterOptions, "table", "invalid argument to #2 'table' expected got %s")

        local placeholder = function(f) return {} end
        local pairs = pairs;
        local next = next;
        local getinfo = getinfo or debug.getinfo or placeholder;
        local getconstants, getupvalues, getprotos = getconstants or debug.getconstants or placeholder, getupvalues or debug.getupvalues or placeholder, getprotos or debug.getprotos or placeholder;
        local islclosure = islclosure or iscclosure and function(f) return not iscclosure(f) end or function(f) return true end
        local unpack = unpack or table.unpack

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

        function ft:insertToPath(path, pointer)
            table.insert(path, pointer);
            return path;
        end

        ft.filteredTables = ft:createWeakTable();
        ft.filteredFunctions = ft:createWeakTable();

        local checkIndex = filterOptions.type == "table" and checkExists(filterOptions.index);
        local checkValue = checkExists(filterOptions.value);

        local checkProperty = checkExists(filterOptions.property) and checkType(filterOptions.property, "string", "invalid argument to filterOptions.property 'string' expected got %s");
        local checkClassName = checkExists(filterOptions.classname) and checkType(filterOptions.classname, "string", "invalid argument to filterOptions.classname 'string' expected got %s");

        local deepSearch = checkExists(filterOptions.deepsearch) and checkType(filterOptions.deepsearch, "boolean", "invalid argument to filterOptions.deepsearch 'boolean' expected got %s");
        local logPath = checkExists(filterOptions.logpath) and checkType(filterOptions.logpath, "boolean", "invalid argument to filterOptions.logpath 'boolean' expected got %s");
        local validator = checkExists(filterOptions.validator) and checkType(filterOptions.validator, "function", "invalid argument to filterOptions.validator 'function' expected got %s");

        ft.mainScan = target;


        function ft:checkTable(target, path)
            if not self.running or self.filteredTables[target] then return end;

            self.filteredTables[target] = true
            self.parent = target;

            local deepFilter = self:createWeakTable();

            for i,v in next, target do

                if not self.filteredFunctions[v] then

                    local typ = luaType(v);
                    if typ == filterOptions.type and (not checkClassName or v.ClassName == filterOptions.classname) and ((not validator and (checkIndex and self:checkIndex(i) or not checkIndex) and (not checkProperty or self:checkProperty(v)) and self:checkValue(v)) or validator and filterOptions.validator(i,v)) then
                        self:writeMatch(i, v, path)
                        if filterOptions.firstmatchonly then
                            self.running = false;
                            break;
                        end
                    end

                    if deepSearch and typ == "function" and islclosure(v) then
                        self.filteredFunctions[v] = true
                        self:checkTable(getconstants(v), logPath and self:createPath(path, v));
                        self:checkTable(getupvalues(v), logPath and self:createPath(path, v));
                        self:checkTable(getprotos(v), logPath and self:createPath(path, v));
                        self:checkTable(getfenv(v), logPath and self:createPath(path, v));
                    end

                    if typ == "table" and (not nextScan or i ~= "Path") then
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

            if filterOptions.type == "function" then

                local checkName = checkExists(filterOptions.name) and checkType(filterOptions.name, "string", "invalid argument to filterOptions.name 'string' expected got %s");
                local checkUpvalues = checkExists(filterOptions.upvalues) and checkType(filterOptions.upvalues, "table", "invalid argument to filterOptions.upvalues 'table' expected got %s");
                local checkConstants = checkExists(filterOptions.constants) and checkType(filterOptions.constants, "table", "invalid argument to filterOptions.constants 'table' expected got %s")    
                local checkProtos = checkExists(filterOptions.protos) and checkType(filterOptions.protos, "table", "invalid argument to filterOptions.protos 'table' expected got %s");
                local checkMatchUpvalues = checkExists(filterOptions.matchupvalues) and checkType(filterOptions.matchupvalues, "table", "invalid argument to filterOptions.matchupvalues 'table' expected got %s")    
                local checkMatchConstants = checkExists(filterOptions.matchconstants) and checkType(filterOptions.matchconstants, "table", "invalid argument to filterOptions.matchconstants 'table' expected got %s");
                local checkMatchProtos = checkExists(filterOptions.matchprotos) and checkType(filterOptions.matchprotos, "table", "invalid argument to filterOptions.matchprotos 'table' expected got %s")    
                local checkUpvalueAmount = checkExists(filterOptions.upvalueamount) and checkType(filterOptions.upvalueamount, "number", "invalid argument to filterOptions.upvalueamount 'number' expected got %s");
                local checkConstantAmount = checkExists(filterOptions.constantamount) and checkType(filterOptions.constantamount, "number", "invalid argument to filterOptions.constantamount 'number' expected got %s")    
                local checkProtoAmount = checkExists(filterOptions.protoamount) and checkType(filterOptions.protoamount, "number", "invalid argument to filterOptions.protoamount 'boolean' expected got %s")    
                local checkInfo = checkExists(filterOptions.info) and checkType(filterOptions.info, "table", "invalid argument to filterOptions.info 'table' expected got %s")    
                local checkMatchInfo = checkExists(filterOptions.matchinfo) and checkType(filterOptions.matchinfo, "table", "invalid argument to filterOptions.matchinfo 'table' expected got %s")    
                local checkIgnoreEnv = checkExists(filterOptions.ignoreenv) and checkType(filterOptions.ignoreenv, "boolean", "invalid argument to filterOptions.ignoreenv 'boolean' expected got %s")    
                local checkScript = checkExists(filterOptions.script) and checkType(filterOptions.script, "Instance", "invalid argument to filterOptions.script 'Instance' expected got %s")    


                function ft:checkValue(value)

                    if not islclosure(value) then return end

                    if checkIgnoreEnv and table.find(self.env, value) then return end

                    local functionInfo = getinfo(value);
                    local upvalues = getupvalues(value);
                    local constants = getconstants(value);
                    local protos = getprotos(value);

                    if checkName and functionInfo.name ~= filterOptions.name then return end

                    if checkUpvalues and upvalues ~= filterOptions.upvalues then return end
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

                local checkTableSize = checkExists(filterOptions.tablesize) and checkType(filterOptions.tablesize, "number", "invalid argument to filterOptions.tablesize 'number' expected got %s");
                local checkMetatable = checkExists(filterOptions.metatable) and checkType(filterOptions.metatable, "table", "invalid argument to filterOptions.metatable 'table' expected got %s");
                local checkHasMetatable = checkExists(filterOptions.hasmetatable) and checkType(filterOptions.hasmetatable, "boolean", "invalid argument to filterOptions.hasmetatable 'boolean' expected got %s")

                function ft:checkValue(value)

                    if checkValue and value ~= filterOptions.value then return end

                    if checkTableSize and #self.parent ~= filterOptions.tablesize then return end

                    local metatable = getmetatable(value)

                    if checkMetatable and metatable ~= filterOptions.metatable then return end
                    if checkHasMetatable and metatable ~= filterOptions.hasmetatable then return end

                    return true
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

                local checkMetatable = checkExists(filterOptions.metatable) and checkType(filterOptions.metatable, "table", "invalid argument to filterOptions.metatable 'table' expected got %s");
                local checkHasMetatable = checkExists(filterOptions.hasmetatable) and checkType(filterOptions.hasmetatable, "boolean", "invalid argument to filterOptions.hasmetatable 'boolean' expected got %s")

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

        local results = ft.results; 

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

        return setmetatable(results, {__index = function(self, i) if i == "nextScan" then return nextScan end end, __mode = "kv"});
    end

end

local o = os.clock()

local tbl = {"testing", {"testing"}}

print("fitler table", tbl, tbl[2])

local results = filterTable(tbl, {type = "string", value = "testing", logpath = true})

for i,v in pairs(results) do
   table.foreach(v,print)
end

print("took", os.clock()-o)