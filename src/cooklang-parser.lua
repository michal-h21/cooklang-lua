-- parser for https://cooklang.org/

example = "Pour into a #bowl and leave to stand for ~{15%minutes}. #large non-stick frying pan{}"


local Recipe = {}
local unicode_data = require "cooklang-unicode-data"


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


-- we must support all punctuation and spacing characters from Unicode
-- it seems that Vítek Novotný was dealing with the same issue, so we could
-- find a solution: https://stackoverflow.com/q/39006753
local cont = lpeg.R("\128\191") -- continuation byte

local match_utf8 = lpeg.R("\0\127")
           + lpeg.R("\194\223") * cont
           + lpeg.R("\224\239") * cont * cont
           + lpeg.R("\240\244") * cont * cont * cont

          
local utf_char = utf8.char 

local function load_unicode_category(category)
  -- load characters of the given category and make table that we can query
  local data = {}
  local chars = unicode_data[category] or ""
  for _, codepoint in utf8.codes(chars) do
    data[utf_char(codepoint)] = true
  end
  return data
end

local space_chars = load_unicode_category("Z")
local punct_chars = load_unicode_category("P")


local punctuation = lpeg.Cmt(lpeg.C(match_utf8), function (s, i, c)
  if punct_chars[c] then
    return i
  end
end)

local spacechar = lpeg.Cmt(lpeg.C(match_utf8), function (s, i, c)
  if space_chars[c] then
    return i
  end
end)
-- end of Unicode handling


-- define grammar for Cooklang
local newline       = P("\n")
local any           = P(1)
local eof           = - any
local colon         = P(":")
local nocolon       = P(1 - colon - newline)
local optionalspace = spacechar^0
local linechar      = P(1 - newline)
local blankline     = (optionalspace * newline) ^ 2
local blanklines    = blankline^1/ mark "blankline"
local commentchar   = P("--")
local commentstart  = P("[-")
local commentend    = P("-]")
local metadatachar  = P(">>")
local ingredientchar= P("@")
local lbrace        = P("{")
local rbrace        = P("}")
local specialchars  = S(",.!?{}@#~")
local word          = any - spacechar - specialchars - punctuation ^ 1
local content       = any - specialchars ^ 1
local blockcommentcontent = any - commentend

-- handle @ingredients
local ingredient    = ingredientchar * (word ^ 1 / mark "ingredient")
local ingredientlong= ingredientchar * (content ^ 1 / mark "ingredient") * lbrace * optionalspace * rbrace

local multiply      = P("*")
local percent       = P("%")
local quantityspecials = multiply + percent -- S("%*")
local amount        = any - quantityspecials ^ 0
local notrbrace     = P(1 - rbrace)
local notrbracepercent = notrbrace - percent
--
local simplequantity= (notrbracepercent ^ 1 / mark "amount")
local unitquantity  = (notrbracepercent ^ 1 / mark "amount") *  percent * (notrbrace ^ 0 /mark "units")
local notmultiply   = notrbracepercent - multiply
local multiplyquantity = (notmultiply ^ 1 / mark "amount") * (multiply / mark "multiply") *  percent * (notrbrace ^ 0 /mark "units")
local quantity      = multiplyquantity + unitquantity + simplequantity 
-- 
local ingredientarg = ingredientchar * (content ^ 1 / mark "ingredientarg") 
                      * lbrace * (quantity / mark "quantity") * rbrace

local ingredients   = ingredientarg + ingredient 

-- handle #cookware
local cookwarechar  = "#"
local cookwaresimple= cookwarechar * (word ^ 1 / mark "cookware")
local cookwarelong  = cookwarechar * (content ^ 1 / mark "cookware") * lbrace * optionalspace * rbrace
local cookwarequantity = cookwarechar * (content ^ 1 / mark "cookware") * lbrace * (quantity / mark "quantity") * rbrace
local cookware      = cookwarequantity + cookwarelong + cookwaresimple

-- handle ~timers
local timerchar     = "~"
local timeamount    = (notrbracepercent ^ 1 / mark "value")
local timeunit      = (notrbrace ^ 1 / mark "units")
local timerquantity = timerchar * (content ^ 0 / mark "timerquantity") * lbrace * (timeamount * percent * timeunit / mark "quantity") * rbrace
local timernamed    = timerchar * (word ^ 1 / mark "timer")
local timer         = timerquantity + timernamed


local line          = linechar^0 - newline
                      + linechar^1 - eof
-- handle comments
local comment       = commentchar * optionalspace * (line / mark "comment")
local commentblock  = commentstart * (blockcommentcontent ^ 1 / mark "comment") * commentend
-- handle metadata
local metadata      = metadatachar * optionalspace * ( C( nocolon ^ 1) * optionalspace * colon ^ 0 * optionalspace * C (line) / mark "metadata")

-- supported inline content 
local inlines       = (comment + ingredientlong + ingredients + cookware + timer + commentblock) ^ 1
local text          = (any - newline - inlines -  metadata ) ^ 1 / mark "text"

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


-- trim spaces at the beginning and end of text
local function trim_spaces(text)
  -- don't try to process other types than strings
  if type(text) ~= "string" then return text end
  return text:gsub("^%s*", ""):gsub("%s*$","")
end

local function fix_spaces(tbl)
  -- sometimes some fields contain extra spaces. we need to remove them
  for k,v in ipairs(tbl) do 
    v.name = trim_spaces(v.name)
    v.quantity = trim_spaces(v.quantity)
  end
  return tbl
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
  local quantity = ingredient 
  local saved_ingredient = self.used_ingredients[name] or {}
  saved_ingredient.name = saved_ingredient.name or name
  local saved_quantity = saved_ingredient or {}
  local unit = quantity.units 
  local amount = tonumber(quantity.amount) 
  -- if amount is numerical and has unit, try to update already existing
  --
  if amount and unit then
    -- find if the same unit was  used
    -- increase amounts for the same units of the ingredient
    local updated = false
    for k, v in ipairs(saved_quantity) do
      if unit == v.units then
        updated = true
        saved_quantity[k].amount = (saved_quantity[k].amount or 0) + amount
      end
    end
    -- if we couldn't find the same unit, just add the quantity
    if not updated then
      -- save the numeric amount
      quantity.amount = amount
      saved_quantity[#saved_quantity+1] = quantity
    end

  else
    -- in this case, we ei
    if quantity.amount then
      -- if amount is numeric, use the number instead of string, for consistency
      if amount then 
        quantity.amount = amount 
      end
      saved_quantity[#saved_quantity+1] = quantity
    else
      -- if quantity doesn't have any amount, save it to the list of
      -- ingredients only when it isn't already here
      if #saved_quantity == 0 then
        saved_quantity[#saved_quantity+1] = quantity
      end
    end
  end
    
  -- saved_ingredient.quantity = saved_quantity
  if not self.used_ingredients[name] then
    -- save ingredient to hash table for quick access,
    -- and also to ingredient list, so we can keep their order
    self.used_ingredients[name] = saved_quantity
    self.ingredients[#self.ingredients+1] = saved_quantity
  end
end

-- test if current node is quantity
local function is_quantity(quantity)
  if type(quantity) == "table" and #quantity > 0 and quantity[1] == "quantity" then return true end
end

-- convert parsed array from lpeg to hash table
local function tbl_to_keys(quantity, tbl)
  local tbl = tbl or {}
  for i = 2, #quantity do
    local el = quantity[i]
    key, value = el[1], el[2]
    -- convert value to number, if possible
    value = tonumber(value) or value
    tbl[key] = value
  end
  return tbl
end

function Recipe:process_ingredient(ingredient, quantity)
  local name = ingredient[2]
  local newquantity = {}
  -- process quantity
  local newingredient =  {type = "ingredient", name = name}
  if is_quantity(quantity) then
    tbl_to_keys(quantity, newingredient)
    -- cooklang test suite uses quantity instead of amount 
    newingredient.quantity = newingredient.amount or ""
    newingredient.units = newingredient.units or ""
  else
    -- ingredients without speicified amount still should have a quantity of "some"
    newingredient.quantity = self.some
    newingredient.units = ""
  end
  -- add new ingredient to list of ingredients
  self:add_ingredient(newingredient)
  return newingredient
end

function Recipe:process_cookware(cookware, quantity)
  name = cookware[2]
  local newcookware = {type = "cookware", name = name}
  -- just mark cookware as used and insert it to the list of cookware
  if not self.used_cookware[name] then
    self.cookware[#self.cookware+1] = newcookware
    self.used_cookware[name] = newcookware
    if quantity and is_quantity(quantity) then tbl_to_keys(quantity, newcookware) end
  end
  return newcookware
end


function Recipe:process_timers(timer, quantity)
  local newtimer = {type = "timer"}
  newtimer.name = timer[2]
  -- convert parsed info from timer to key-val list
  if type(quantity) == "table" then
    tbl_to_keys(quantity, newtimer)
  end
  -- try to convert the numerical value to number
  newtimer.value = tonumber(newtimer.value) or newtimer.value or ""
  -- again, make the name consistent with the cooklang test suite
  newtimer.quantity = newtimer.value
  newtimer.units = newtimer.units or ""
  -- save timer
  self.timers[#self.timers+1] = newtimer
  return newtimer
end

function Recipe:process_element(element)
  local newelement = {name = element[1]}
  tbl_to_keys(element, newelement)
  return newelement
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
        newstep[#newstep+1] = self:process_ingredient(element, step[i+1])
      elseif typ == "cookware" then
        newstep[#newstep+1] = self:process_cookware(element, step[i+1])
      elseif typ == "timerquantity" then
        -- we must process also next step, which contains quantity
        newstep[#newstep+1] = self:process_timers(element, step[i+1])
      elseif typ == "timer" then
        -- we must process also next step, which contains quantity
        newstep[#newstep+1] = self:process_timers(element, {})
      elseif typ == "comment" then
        newstep[#newstep+1] = {type="comment", value=element[2]}
      elseif typ == "text" then
        newstep[#newstep+1] = {type="text", value=element[2]}
      elseif typ == "quantity" then
        -- ignore quantity, it should be handled by ingredient, cookware or timer 
        -- handlers
      else
        -- this shouldn't happen
        newstep[#newstep+1] = self:process_element(element)
      end
      -- print(typ)
    end
    -- pretty(newstep)
    -- replace original steps with processed data
    self.steps[i] = fix_spaces(newstep)
  end
end

function Recipe:process()
  self:process_lines()
  self:process_steps()
  -- for k,v in ipairs(self.steps) do print(k, #v) end
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
    -- these are lists that hold cookware and ingredients sorted by their first use in the recipe
    cookware = {},
    ingredients = {},
    -- these are hash table for fast access to cookware and ingredients by name
    used_cookware = {},
    used_ingredients = {},
    some = "some" -- amount used for ingredients without explicit quantity
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
