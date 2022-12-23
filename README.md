# filterTable
a lua/roblox function made to filter and deep search values inside a table with better acurracy

**documentation:**

            filterOptions = {
                type = <lua type>
                classname = <string>
                property = <<string> roblox property> to check for values inside objects, e.g checking the CFrame property of BasePart's -> {type = "Instance", classname = "BasePart", property = "CFrame"}
                firstmatchonly = <bool>
                logpath = <bool> logs the path taken by the filterTable, may decrease performance
                deepsearch = <bool> searches every function constants, upvalues, protos and env aswell, WILL DECREASE performance
                validator = <<bool> function(i,v)> validates an entry using a function **will override the default checking, so using any options presented below will not work**
            }

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

            return format = {
                {
                  Value,
                  Index,
                  Parent,
                  (additional values)
                },
                (...)
            }

                    
                    
usage example:
```lua
local tbl = {"testing", {"testing"}}
local results = filterTable(tbl, {type = "string", value = "testing", logpath = true})

for i,v in pairs(results) do
   table.foreach(v,print)
end
```

next scan usage example:
```lua
local tbl = {"testing", {"testing"}}

local results = filterTable(tbl, {type = "string", value = "testing", logpath = true}) -- will return 2 values

tbl[1] = "not testing" -- change one of the values

results = results.nextScan({type = "string", value = "testing", logpath = true}) -- will return 1 value

for i,v in pairs(results) do
   table.foreach(v,print)
end
```
