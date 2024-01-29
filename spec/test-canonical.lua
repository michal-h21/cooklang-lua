local tinyyaml = require "tinyyaml"

local function get_yaml(filename)
  local f = io.open(filename, "r")
  if not f then return nil, "Cannot open yaml file: " .. filename end
  local text = f:read("*all")
  f:close()
  return tinyyaml.parse(text)
end

local data, msg = get_yaml("spec/canonical.yaml")

for k,v in pairs(data.tests) do
  print(k,v)
end


