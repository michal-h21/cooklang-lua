local tinyyaml = require "tinyyaml"
local cooklang_parser = require "cooklang-parser"

local function get_yaml(filename)
  local f = io.open(filename, "r")
  if not f then return nil, "Cannot open yaml file: " .. filename end
  local text = f:read("*all")
  f:close()
  return tinyyaml.parse(text)
end

local function fix_source(source)
  -- the test suite doesn't contain newlines between steps, so we will add them in this function
  local lines = {}
  for line in source:gmatch("([^\n]*)") do
    -- don't add extra lines to metadata
    if not line:match("^%s*>>") then
      lines[#lines+1] = ""
    end
    lines[#lines+1] = line
  end
  return table.concat(lines, "\n")
end

local function remove_comments(steps)
  -- in the test, comments should be removed
  for _, step in ipairs(steps) do
    for i, what in ipairs(step) do
      if what.type == "comment" then table.remove(step, i) end
    end 
  end
  return steps
end

local function compare(parser, tbl)
  -- compare data from YAML with parsed data
  for i, step in ipairs(tbl.result.steps) do
    -- get corresponding step from parser
    local parser_step = parser.steps[i] or {}
    for x, object in ipairs(step) do
      -- compare particular objects in step
      local parser_object = parser_step[x] or {}
      for k,v in pairs(object) do
        assert.same(v, parser_object[k])
      end
    end
  end
  -- now compare metadata
  local parser_metadata = parser.metadata
  for k,v in pairs(tbl.result.metadata) do
    assert.same(v, parser_metadata[k])
  end
end

local function run_test(k,v)
  describe(k , function()
    print("***********************", k)
    print(v.source)
    local x = cooklang_parser:new(fix_source(v.source))
    x.steps = remove_comments(x.steps)
    compare(x, v)
  end)
end



local data, msg = get_yaml("spec/canonical.yaml")

for k,v in pairs(data.tests) do
-- local k, v = "hello", data.tests["testCommentsAfterIngredients"]
  run_test(k,v)
end


