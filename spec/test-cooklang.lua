local cooklang_parser = require "cooklang-parser"
local example = [[
>> source: https://www.gimmesomeoven.com/baked-potato/
>> time required: 1.5 hours
>> course: dinner

// Source: https://www.jamieoliver.com/recipes/eggs-recipes/easy-pancakes/

Crack the @eggs{3} into a blender, then add the @flour{125%g}, @milk{250%ml} and @sea salt{1%pinch}, and blitz until smooth.

Pour into a #bowl and leave to stand for ~{15%minutes}.

Melt the @butter (or a drizzle of @oil if you want to be a bit healthier) in a #large non-stick frying pan{} on a medium heat, then tilt the pan so the butter coats the surface.

Pour in 1 ladle of batter and tilt again, so that the batter spreads all over the base, then cook for 1 to 2 minutes, or until it starts to come away from the sides.

Once golden underneath, flip the pancake over and cook for 1 further minute, or until cooked through.

Serve straightaway with your favourite topping. // Add your favorite topping here to make sure it's included in your meal plan!
]]

describe("It should parse full recipe", function()
  local parser = cooklang_parser:new(example)
  local data = parser:get_ast()
  it("Parser should return table", function()
    assert.same(type(data),"table")
  end)

  local function is_metadata(tbl)
    print(tbl[1])
  end
  for k,v in ipairs(data) do
    is_metadata(v)
    print(k,v)
  end
  

end)
