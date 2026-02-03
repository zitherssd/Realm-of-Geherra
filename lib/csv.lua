-- CSV Parser Utility
-- Simple CSV parser for importing data into Lua tables

local csv = {}

-- Parse a CSV string into a table of tables
function csv.parse(csvString)
    local lines = {}
    local currentLine = ""
    local inQuotes = false
    
    -- Split by lines, handling quoted fields that may contain newlines
    for i = 1, #csvString do
        local char = csvString:sub(i, i)
        
        if char == '"' then
            inQuotes = not inQuotes
        elseif char == '\n' and not inQuotes then
            if currentLine ~= "" then
                table.insert(lines, currentLine)
                currentLine = ""
            end
        else
            currentLine = currentLine .. char
        end
    end
    
    -- Add the last line if it exists
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end
    
    -- Parse each line into fields
    local result = {}
    local headers = {}
    
    for i, line in ipairs(lines) do
        if i == 1 then
            -- First line contains headers
            headers = csv.parseLine(line)
        else
            -- Parse data lines
            local fields = csv.parseLine(line)
            local row = {}
            
            for j, field in ipairs(fields) do
                local header = headers[j]
                if header then
                    -- Try to convert numeric fields
                    local num = tonumber(field)
                    if num then
                        row[header] = num
                    else
                        row[header] = field
                    end
                end
            end
            
            table.insert(result, row)
        end
    end
    
    return result
end

-- Parse a single CSV line into fields
function csv.parseLine(line)
    local fields = {}
    local currentField = ""
    local inQuotes = false
    
    for i = 1, #line do
        local char = line:sub(i, i)
        
        if char == '"' then
            inQuotes = not inQuotes
        elseif char == ',' and not inQuotes then
            table.insert(fields, currentField:gsub('^%s*(.-)%s*$', '%1')) -- trim whitespace
            currentField = ""
        else
            currentField = currentField .. char
        end
    end
    
    -- Add the last field
    table.insert(fields, currentField:gsub('^%s*(.-)%s*$', '%1')) -- trim whitespace
    
    return fields
end

-- Load and parse a CSV file
function csv.loadFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        error("Could not open CSV file: " .. filePath)
    end
    
    local content = file:read("*all")
    file:close()
    
    return csv.parse(content)
end

return csv 