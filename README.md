![Top language](https://img.shields.io/github/languages/top/Fiusen/filterTable) ![File size](https://img.shields.io/github/size/Fiusen/filterTable/filterTable.lua)

# filterTable

A Lua/Roblox function made to ***filter and deep search values inside a table*** with blazing fast speed and lots of options, including a way to "next scan" from older results, making filtering dynamic values way easier.


### Documentation:

```py


    filterOptions = {
                type = <lua type> searches for the specific given type
                firstmatchonly = <bool> whether or not only the first matched value will be returned
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
                ignorEenv = <bool>
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
```
                    
                    
### Usage:

```lua
local tbl = {"testing", {"testing"}}
local results = filterTable(tbl, {type = "string", value = "testing", logPath = true})

for i,v in pairs(results) do
   table.foreach(v, print)
end
```

nextScan usage example:
```lua
local tbl = {"testing", {"testing"}}

local results = filterTable(tbl, {type = "string", value = "testing", logPath = true}) -- will return 2 values

tbl[1] = "not testing" -- change one of the values

results = results.nextScan({type = "string", value = "testing", logPath = true}) -- will return only 1 value (the unchanged one)

for i,v in pairs(results) do
   table.foreach(v, print)
end
```
