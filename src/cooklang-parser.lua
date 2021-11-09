-- parser for https://cooklang.org/

example = "Pour into a #bowl and leave to stand for ~{15%minutes}. #large non-stick frying pan{}"


local Recipe = {}


local utfcodepoint = utf8.codepoint
local utfchar = utf8.char

-- these methods come from https://github.com/michal-h21/LuaXML/blob/master/luaxml-parse-query.lua
local R, S, V, P
local C, Cs, Ct, Cmt, Cg, Cb, Cc, Cp
local lpeg = require("lpeg")
R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
C, Cs, Ct, Cmt, Cg, Cb, Cc, Cp = lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc, lpeg.Cp

local mark
mark = function(name)
  return function(...)
    return {
      name,
      ...
    }
  end
end

-- define grammar for Cooklang
local newline       = P("\n")
local any           = P(1)
local eof           = - any
local spacechar     = S("\t ")
local colon         = P(":")
local nocolon       = P(1 - colon - newline)
local optionalspace = spacechar^0
local linechar      = P(1 - newline)
local blankline     = (optionalspace * newline) ^ 2
local blanklines    = blankline^1/ mark "blankline"
local commentchar   = P("//")
local metadatachar  = P(">>")
local ingredientchar= P("@")
local lbrace        = P("{")
local rbrace        = P("}")
local specialchars  = S(",.!?{}@#~")
local word          = any - spacechar ^ 1
local content       = any - specialchars ^ 1

-- handle @ingredients
local ingredient    = ingredientchar * (word ^ 1 / mark "ingredient")
local ingredientlong= ingredientchar * (content ^ 1 / mark "ingredient") * lbrace * optionalspace * rbrace

local quantityspecials = S("%*")
local amount        = any - quantityspecials ^ 0
local multiply      = P("*")
local percent       = P("%")
local notrbrace     = P(1 - rbrace)
local notrbracepercent = notrbrace - percent
--
local simplequantity= (notrbracepercent ^ 1 / mark "amount")
local unitquantity  = (notrbracepercent ^ 1 / mark "amount") *  percent * (notrbrace ^ 0 /mark "unit")
local notmultiply   = notrbracepercent - multiply
local multiplyquantity = (notmultiply ^ 1 / mark "amount") * (multiply / mark "multiply") *  percent * (notrbrace ^ 0 /mark "unit")
local quantity      = multiplyquantity + unitquantity + simplequantity 
-- 
local ingredientarg = ingredientchar * (content ^ 1 / mark "ingredientarg") 
                      * lbrace * (quantity / mark "quantity")  * rbrace

local ingredients   = ingredientarg + ingredient 

-- handle #cookware
local cookwarechar  = "#"
local cookwaresimple= cookwarechar * (word ^ 1 / mark "cookware")
local cookwarelong  = cookwarechar * (content ^ 1 / mark "cookware") * lbrace * optionalspace * rbrace
local cookware      = cookwarelong + cookwaresimple

-- handle ~timers
local timerchar     = "~"
local timeamount    = (notrbracepercent ^ 1 / mark "value")
local timeunit      = (notrbrace ^ 1 / mark "unit")
local timer         = timerchar * lbrace * (timeamount * percent * timeunit / mark "timer") * rbrace


local line          = linechar^0 - newline
                      + linechar^1 - eof
-- handle comments
local comment       = commentchar * optionalspace * (line / mark "comment")
-- handle metadata
local metadata      = metadatachar * optionalspace * ( C( nocolon ^ 1) * optionalspace * colon ^ 0 * optionalspace * C (line) / mark "metadata")

-- supported inline content 
local inlines       = (comment + ingredientlong + ingredients + cookware + timer) ^ 1
local text          = (any - newline - inlines -  metadata) ^ 1 / mark "text"

-- mark lines
local linecontent   = (inlines +  text) ^ 1
local linex         = linecontent ^ 1 / mark "line"
local lines         = (linex + metadata + blanklines + newline) ^ 1
local grammar       = Ct(lines ^ 0)
-- local block         = lines ^ 1 * blanklines / mark "block"



-- auxilary table pretty printer used for debugging
local function pretty(tbl, level)
  local level = level or 0
  local start = string.rep("  ", level)
  for k,v in pairs(tbl) do
    if type(v) ~= "table" then
      print(start .. k, v)
    else
      pretty(v, level + 1)
    end
  end
end

local function copy_table(tbl)
  local t = {}
  for k,v in pairs(tbl) do
    if type(v) == "table" then
      t[k] = copy_table(v)
    else
      t[k] = v
    end
  end
  return t
end

function Recipe:parse(text)
  local text = text or self.text
  -- parse text and return AST
  local res = grammar:match(text)
  return res
end

function Recipe:process_lines()
  -- turn ast into useful data
  local block = {}
  for _, line in ipairs(self.ast) do
    -- turn lines into steps
    local typ = line[1]
    if typ == "line" then
      -- copy line contents to the current block. ignore first item, as it is line type
      for i = 2, #line do
        -- we make deep copy of each element, because we will change them in later processing
        -- and we want to keep AST in the original form
        block[#block+1] = copy_table(line[i])
      end
    else
      -- close current block when we find metadata or blank line
      if #block > 0 then table.insert(self.steps, block) end
      block = {}
      if typ == metadata then
        -- insert metadata to the metadata table
        local key = line[2]
        local value = line[3]
        self.metadata[key] = value
      end
    end
  end
  -- insert also last block
  if #block > 0 then table.insert(self.steps, block) end
end

function Recipe:add_ingredient(ingredient)
  -- add ingredient into list of ingredients. 
  -- sum amounts of the same units
  local name = ingredient.name
  local quantity = ingredient.quantity or {}
  local amount = tonumber(quantity.amount) or quantity.amount
  print(name, amount)
  local saved_ingredient = self.ingredients[name] or {}
  saved_ingredient.name = saved_ingredient.name or name
  self.ingredients[name] = saved_ingredient
end

function Recipe:process_ingredient(ingredient, quantity)
  local name = ingredient[2]
  local newquantity = {}
  -- process quantity
  if #quantity > 0 and quantity[1] == "quantity" then
    -- first table item in quantity is "quantitity" string, we can skip that
    for i = 2, #quantity do
      local key = quantity[i][1]
      local value = quantity[i][2]
      newquantity[key] = value
    end
  end
  local newingredient =  {type = "ingredient", name = name, quantity = newquantity}
  -- add new ingredient to list of ingredients
  self:add_ingredient(newingredient)
  return newingredient
end

function Recipe:process_steps()
  -- extract ingredients, timers and cookware
  for i, step in ipairs(self.steps) do
    local newstep = {}
    for i=1, #step do
      local element = step[i]
      local typ = element[1]
      if typ == "ingredient" then
        newstep[#newstep+1] = self:process_ingredient(element, {})
      elseif typ == "ingredientarg" then
        -- we must process also next step, which contains quantity
        i = i + 1
        newstep[#newstep+1] = self:process_ingredient(element, step[i])
      elseif typ == "cookware" then
      elseif typ == "timer" then
      end
      -- print(typ)
    end
    -- replace original steps with processed data
    self.steps[i] = newstep
  end
end

function Recipe:process()
  self:process_lines()
  self:process_steps()
  for k,v in ipairs(self.steps) do print(k, #v) end
end

function Recipe:render(rules)
  -- ToDo: make renderer
end

function Recipe:get_ast()
  return self.ast
end

function Recipe:new(text)
  local t = {
    text = text,
    steps = {},
    timers = {},
    metadata = {},
    cookware = {},
    ingredients = {},
  }
  self.__index = self
  setmetatable(t, self)
  t.ast = t:parse()
  t:process()
  return t
end

-- local r = Recipe:new(example)
-- r:parse()
return Recipe
