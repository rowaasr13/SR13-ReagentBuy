local a_name, a_env = ...

-- BlizzardInterfaceCode\AddOns\Blizzard_TradeSkillUI\Blizzard_TradeSkillDetails.lua
-- /dump TradeSkillFrame.RecipeList.selectedRecipeID
-- /dump TradeSkillFrame.DetailsFrame.CreateMultipleInputBox:GetValue()

local need = {}

local function BuyReagentsForSelectedRecipe(cmd)
   if not TradeSkillFrame then return end
   local selectedRecipeID = TradeSkillFrame.RecipeList.selectedRecipeID
   if not selectedRecipeID then return end

   local recipeInfo = C_TradeSkillUI.GetRecipeInfo(selectedRecipeID)
   if not recipeInfo then return end
   if not recipeInfo.learned then return end

   wipe(need)

   local mult = tonumber(cmd) or TradeSkillFrame.DetailsFrame.CreateMultipleInputBox:GetValue() + 0
   print("Buying reagents to craft " .. mult)

   local numReagents = C_TradeSkillUI.GetRecipeNumReagents(selectedRecipeID)
   for reagentIndex = 1, numReagents do
      local reagentName, reagentTexture, reagentCount, playerReagentCount = C_TradeSkillUI.GetRecipeReagentInfo(selectedRecipeID, reagentIndex)
      local link = C_TradeSkillUI.GetRecipeReagentItemLink(selectedRecipeID, reagentIndex)
      local missing = playerReagentCount - (reagentCount * mult)
      if missing < 0 then
         local item_id = link:match("|Hitem:(%d+)")
         if item_id then
            need[item_id + 0] = -missing
         end
      end
   end
   DevTools_Dump(need)

   local cost = 0
   for merchant_idx = 1, GetMerchantNumItems() do
      local link = GetMerchantItemLink(merchant_idx)
      local item_id = link and link:match("|Hitem:(%d+)")
      if item_id then
         item_id = item_id + 0
         local need = need[item_id]
         if need then
            local name, texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost = GetMerchantItemInfo(merchant_idx)
            print(name, extendedCost)
            local maxStack = GetMerchantItemMaxStack(merchant_idx)
            -- TODO: numAvailable, maxStack, extendedCost
            if not extendedCost or extendedCost == 0 then
               cost = cost + (price / quantity) * need
               print("BuyMerchantItem", merchant_idx, need)
               BuyMerchantItem(merchant_idx, need)
            end
         end
      end
   end
   print(cost)
end
_G.BuyReagentsForSelectedRecipe = BuyReagentsForSelectedRecipe
a_env.register_slash("BuyReagents", { "/breg" }, BuyReagentsForSelectedRecipe)
a_env.register_slash = nil
