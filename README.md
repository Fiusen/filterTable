![Top language](https://img.shields.io/github/languages/top/Fiusen/filterTable) ![File size](https://img.shields.io/github/size/Fiusen/filterTable/filterTable.lua)

# filterTable

A Lua/Roblox function made to ***filter and deep search values inside a table*** with blazing fast speed and custom filter options, including a "Next Scan" feature, making filtering dynamic values way easier.



### Documentation:

```py


    filterOptions = {
                type = <lua type> searches for the specific given type
                firstMatchOnly = <bool> whether or not only the first matched value will be returned
                logPath = <bool> logs the path taken by the filterTable, may decrease performance
                deepSearch = <bool> searches every function constants, upvalues, protos and env (will decrease performance)
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
```
                    
                    
### Usage:

```lua
local tbl = {"testing", {"testing"}}
local results = filterTable(tbl, {type = "string", value = "testing"})

for i,v in pairs(results) do -- you can also use results.print() instead of this
   table.foreach(v, print)
      -- expected output:
   
   --[[
        Index       1
        Value       testing
        Parent      table: 0x0000000000000000 (this is equivalent to tbl)
        SearchId    a7HS (random)
        
        Index       1
        Value       testing
        Parent      table: 0x0000000000000001 (this is equivalent to tbl[2])
        SearchId    a7HS (random)
   ]]
end
```

#### Next Scan usage example:
```lua
local tbl = {"testing", {"testing"}}

local results = filterTable(tbl, {type = "string", value = "testing"}) -- will return 2 values

tbl[1] = "not testing" -- change one of the values

results = results.nextScan({type = "string", value = "testing"}) -- will return only 1 value (the unchanged one)

for i,v in pairs(results) do
   table.foreach(v, print)
   -- expected output:
   
   --[[
        Index       1
        Value       testing
        Parent      table: 0x0000000000000001 (this is equivalent to tbl[2])
        SearchId    65CA (random)
   ]]
end
```

Example usage on a roblox game (searching every single lua object in the garbage collector with deepSearch in 0.03s)

https://user-images.githubusercontent.com/41023878/226069828-26dd80fa-7900-4c92-9ac3-89945e0d8f6c.mp4


##### Display Method

Instead of looping through results and printing each results table manually you can use the `display(limit)` method appended to every result of filterTable.

`limit` is the max amount of results to be displayed, if its nil, it will print every entry

```lua
local tbl = {"testing", {"testing"}}
local results = filterTable(tbl, {type = "string", value = "testing"})
results.display()

-- expected output:

--[[

filterTable (result #1)
Index       1
Value       testing
Parent      table: 0x0000000000000000 (this is equivalent to tbl)
SearchId    klF1 (random)
 
filterTable (result #2)
Index       1
Value       testing
Parent      table: 0x0000000000000001 (this is equivalent to tbl[2])
SearchId    klF1 (random)
]]
```

