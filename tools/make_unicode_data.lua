-- this file requires TeX distribution with LuaTeX and the unicode-data package
kpse.set_program_name "luatex"
local unicode_data = kpse.find_file("UnicodeData.txt")
print(unicode_data)
