-- this file requires TeX distribution with LuaTeX and the unicode-data package
local unicode_txt 

if kpse then
  kpse.set_program_name "luatex"
  unicode_txt = kpse.find_file("UnicodeData.txt")
else
  unicode_txt = arg[1]
end

if not unicode_txt then
  print("Cannot find UnicodeData.txt. Do you have unicode-data package installed?")
  os.exit(1)
end

local data = {}

-- create table with all characters for each Unicode category
for line in io.lines(unicode_txt) do
  -- explode is included in LuaTeX
  local fields = line:explode(";")
  -- get Unicode char and category
  local char, category = fields[1], fields[3]
  current_data = data[category] or {}
  current_data[#current_data+1] = utf8.char(tonumber(char, 16))
  data[category] = current_data
end

-- create another table, saving only categories that we are interested in
local saved_categories = {"Zs",  "P." }
local saved_prefixes = {}
for category,chars in pairs(data) do
  -- only print these categories
    for _, pattern in pairs(saved_categories) do
      if category:match(pattern) then
        local prefix = category:match("^.")
        -- copy characters from category to the prefix table
        local data = saved_prefixes[prefix] or {}
        for _, char in ipairs(chars) do table.insert(data, char) end
        saved_prefixes[prefix] = data
      end
    end
end

-- now print Lua module which returns table with strings that contain each character for a given Unicode category
print "return {"
for prefix, chars in pairs(saved_prefixes) do
  print(prefix ..  "=[[" .. table.concat(chars) .. "]],")
end
print "}"

