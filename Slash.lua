local a_name, a_env = ...

-- [AUTOLOCAL START]
local random = random
local strbyte = string.byte
local strchar = string.char
-- [AUTOLOCAL END]

local function uniq_slash_id(base, maxNumber)
   local clear = true
   for idx = 1, maxNumber do
      if _G["SLASH_" .. base .. idx] then clear = false break end
   end
   if SlashCmdList[base] then clear = false end
   if clear then return base end
   return uniq_slash_id(base .. (strchar(random(strbyte('a'), strbyte('z')))), maxNumber)
end

local function register_slash(id, command_list, func)
   assert(func, "func is not set")
   local command_count = #command_list
   local slash_id = uniq_slash_id(id, command_count)
   for idx = 1, command_count do
      _G["SLASH_" .. slash_id .. idx] = command_list[idx]
   end
   SlashCmdList[slash_id] = func
end
a_env.register_slash = register_slash