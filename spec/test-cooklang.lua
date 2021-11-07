local cooklang_parser = require "cooklang-parser"
local example = [[
>> source: https://www.jamieoliver.com/recipes/eggs-recipes/easy-pancakes/
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

  local function is_metadata(tbl)
    return tbl[1] == "metadata"
  end
  local function is_line(tbl)
    return tbl[1] == "line"
  end
  local function is_blank(tbl)
    return tbl[1] == "blankline"
  end


  it("Parser should return ast", function()
    assert.same(type(data),"table")
    assert.truthy(is_metadata(data[1]))
    assert.truthy(is_blank(data[4]))
    assert.truthy(is_line(data[5]))
  end)

  it("Should parse metadata", function()
    local meta = data[1]
    assert.truthy(is_metadata(meta))
    assert.same(meta[2], "source")
    assert.same(meta[3], "https://www.jamieoliver.com/recipes/eggs-recipes/easy-pancakes/")
  end)

  it("Should handle comments", function()
    local comment_line = data[5]
    assert.truthy(is_line(comment_line))
    -- first array value is "line", second is comment
    assert.same(#comment_line, 2)
    local comment = comment_line[2]
    assert.same(type(comment), "table")
    assert.same(comment[1], "comment")
    assert.same(comment[2], "Source: https://www.jamieoliver.com/recipes/eggs-recipes/easy-pancakes/")
  end)

  it("Should handle ingredients", function()
    local ingredients_line = data[7]
    assert.truthy(is_line(ingredients_line))
    local eggs = ingredients_line[3]
    local quantity = ingredients_line[4]
    assert.same(eggs[1], "ingredientarg")
    assert.same(eggs[2], "eggs")
    assert.same(quantity[1], "quantity")
    assert.same(type(quantity[2]), "table")
    assert.same(quantity[2][1], "amount")
    assert.same(quantity[2][2], "3")
    local flour = ingredients_line[6]
    local quantity = ingredients_line[7]
    assert.same(flour[1], "ingredientarg")
    assert.same(flour[2], "flour")
    assert.same(#quantity, 3)
    assert.same(quantity[2][1], "amount")
    assert.same(quantity[2][2], "125")
    assert.same(quantity[3][1], "unit")
    assert.same(quantity[3][2], "g")
    
  end)
  
  

end)
