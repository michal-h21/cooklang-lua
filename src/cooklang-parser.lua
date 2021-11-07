-- parser for https://cooklang.org/

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

example = "Crack the @eggs{3} into a blender, melt the @butter then add the @flour{125*%g}, @milk{250%ml} and @sea salt{1%pinch}, and blitz until smooth. @longer ingredient{22%}"


local Recipe = {}


local utfcodepoint = utf8.codepoint
local utfchar = utf8.char

local R, S, V, P
local C, Cs, Ct, Cmt, Cg, Cb, Cc, Cp
local lpeg = require("lpeg")
R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
C, Cs, Ct, Cmt, Cg, Cb, Cc, Cp = lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc, lpeg.Cp

-- declare special characters
-- local greaterthan = utfcodepoint ">"
-- local at = utfcodepoint "@" 
-- local hash = utfcodepoint "#" 
-- local tilde = utfcodepoint "~" 
-- local colon = utfcodepoint ":" 
-- local lbrace = utfcodepoint "{" 
-- local rbrace = utfcodepoint "}" 
-- local percent = utfcodepoint "%" 
-- local star = utfcodepoint "*"
-- local bar = utfcodepoint "|"
-- local space = utfcodepoint " "
-- local newline = utfcodepoint "\n"
-- local linefeed = utfcodepoint "\r"
--
local mark
mark = function(name)
  return function(...)
    return {
      name,
      ...
    }
  end
end

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
local cookware      = cookwaresimple 


local line          = linechar^0 - newline
                      + linechar^1 - eof
-- handle comments
local comment       = commentchar * optionalspace * (line / mark "comment")
-- handle metadata
local metadata      = metadatachar * optionalspace * ( C( nocolon ^ 1) * optionalspace * colon ^ 0 * optionalspace * C (line) / mark "metadata")

-- supported inline content 
local inlines       = (comment + ingredientlong + ingredients) ^ 1
local text          = (any - newline - inlines -  metadata) ^ 1 / mark "text"

-- mark lines
local linecontent   = (inlines +  text) ^ 1
local linex         = linecontent ^ 1 / mark "line"
local lines         = (linex + metadata + blanklines + newline) ^ 1
-- local block         = lines ^ 1 * blanklines / mark "block"




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

function Recipe:parse()
  -- remove linefeeds
  print(self.text)
  local pq = Ct(lines ^ 0)
  local res = pq:match(self.text)
  pretty(res)

end

function Recipe:new(text)
  local t = {
    text = text,
    steps = {},
    timers = {},
    metadata = {},
    cookware = {},
    ingredients = {},
    state = "init"
  }
  self.__index = self
  return setmetatable(t, self)
end

local r = Recipe:new(example)
r:parse()
return Recipe
