local cooklang_parser = require "cooklang-parser"
local example = [[
>> source: https://www.jamieoliver.com/recipes/eggs-recipes/easy-pancakes/
>> time required: 1.5 hours
>> course: dinner

-- Source: https://www.jamieoliver.com/recipes/eggs-recipes/easy-pancakes/

Crack the @eggs{3} into a blender, then add the @flour{125%g}, @milk{250%ml} and @sea salt{1%pinch}, and blitz until smooth.

Pour into a #bowl and leave to stand for ~{15%minutes}.

Melt the @butter (or a drizzle of @oil if you want to be a bit healthier) in a #large non-stick frying pan{} on a medium heat, then tilt the pan so the butter coats the surface.

Pour in 1 ladle of batter and tilt again, so that the batter spreads all over the base, then cook for 1 to 2 minutes, or until it starts to come away from the sides.

Once golden underneath, flip the pancake over and cook for 1 further minute, or until cooked through.

Serve straightaway with your favourite topping. -- Add your favorite topping here to make sure it's included in your meal plan!
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
    local blockcommenttext = [[
    Hello, [- inline comment -]
    Try [- multi line
    comment -] ]]
    local commentparser = cooklang_parser:new(blockcommenttext)
    local data = commentparser:get_ast()
    -- data are two lines, as multiline comment eats lines
    local comment = data[1][3]
    assert.same(comment[1], "comment")
    assert.same(comment[2], " inline comment ")
    local comment = data[2][3]
    assert.same(comment[1], "comment")
    assert.same(comment[2], [[ multi line
    comment ]])
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
    local ingredients_line = data[11]
    local butter = ingredients_line[3]
    assert.same(butter[1], "ingredient")
    assert.same(butter[2], "butter")
    
  end)
  it("Should handle cookware and timers", function()
    local parser = cooklang_parser:new "Pour into a #bowl and leave to stand for ~{15%minutes}. Use #frying pan{}, ~bake{20%minutes}"
    local records = parser:get_ast()
    local line = records[1]
    assert.truthy(is_line(line))
    local cookware = line[3]
    assert.same(cookware[1], "cookware")
    assert.same(cookware[2], "bowl")
    local cookware = line[8]
    assert.same(cookware[1], "cookware")
    assert.same(cookware[2], "frying pan")
    local timer = line[5]
    assert.same(timer[1], "timer")
    local timer_quantity = line[6]
    assert.same(timer_quantity[1], "quantity")
    assert.same(timer_quantity[2][1], "value")
    assert.same(timer_quantity[2][2], "15")
    assert.same(timer_quantity[3][1], "unit")
    assert.same(timer_quantity[3][2], "minutes")
  end)
  
  

end)

describe("Test processed recipe", function()
  it("Should parse ingredients", function()
    local example = [[Add @water{3%l}, @water{2%l}, @water{100%ml}, @water, @milk]]
    local parser = cooklang_parser:new(example)
    local ingredients = parser.used_ingredients 
    assert.same(type(ingredients), "table")
    -- count number of ingredients. it is associative table, so we must use this trick
    -- to count it
    local count = 0
    for _, _ in pairs(ingredients) do count = count + 1 end
    assert.same(count, 2)
    assert.truthy(ingredients.water)
    assert.truthy(ingredients.milk)
    -- there are three different units of water - liters, mililiters, and without unit
    -- the water without unit is not saved, because it is just reference to water
    assert.same(#ingredients.water, 2)
    -- milk is used without any amount, so it has only one instance
    assert.same(#ingredients.milk, 1)
    local water = ingredients.water
    assert.same(water[1].amount, 5)
    assert.same(water[1].unit, "l")
    assert.same(water[2].amount, 100)
    assert.same(water[2].unit, "ml")
    -- test ingredient list
    local ingredients = parser.ingredients
    assert.same(#ingredients, 2)
    assert.same(ingredients[1].name, "water")
    assert.same(ingredients[2].name, "milk")
  end)
  it("Should parse cookware", function()
    local example = [[
    Pour into a #bowl{2} and leave to stand for ~{15%minutes}.

    Melt the @butter (or a drizzle of @oil if you want to be a bit healthier) in a #large non-stick frying pan{} on a medium heat, then tilt the pan so the butter coats the surface.
    ]]
    local parser = cooklang_parser:new(example)
    local cookware      = parser.cookware
    local used_cookware = parser.used_cookware 
    assert.same(#cookware, 2)
    local bowl = cookware[1]
    assert.same(bowl.name, "bowl")
    assert.same(bowl.amount, 2)
    assert.same(cookware[2].name, "large non-stick frying pan")
  end)
  it("Should parse timers", function()
    local example = [[
    ~cook{15%minutes} @potatoes. ~bake{75%minutes} @pork, unnamed timer ~{20%minutes}.
    ]]
    local parser = cooklang_parser:new(example)
    local timers = parser.timers
    assert.same(#timers, 3)
    local cook = timers[1]
    assert.same(cook.name, "cook")
    assert.same(cook.value, 15)
    assert.same(cook.unit, "minutes")
    local bake = timers[2]
    assert.same(bake.name, "bake")
    assert.same(bake.value, 75)
    assert.same(bake.unit, "minutes")
    local unnamed = timers[3]
    assert.same(unnamed.name, "")
    assert.same(unnamed.value, 20)
    assert.same(unnamed.unit, "minutes")
  end)
end)

