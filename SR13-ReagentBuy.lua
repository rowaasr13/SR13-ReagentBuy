local a_name, a_env = ...
_G[a_name] = {}
_G[a_name].debug = {}

local itemid_to_merchant_idx = {}
local function ScanMerchant()
   wipe(itemid_to_merchant_idx)
   local num_merchant_items = GetMerchantNumItems()
   if (not num_merchant_items) or (num_merchant_items < 1) then return nil, "no merchant" end
   for merchant_idx = 1, GetMerchantNumItems() do repeat -- break now goes to next iteration
      local link = GetMerchantItemLink(merchant_idx)
      local item_id = link and link:match("|Hitem:(%d+)")
      if not item_id then break end -- continue to next item
      item_id = item_id + 0

      local name, texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost = GetMerchantItemInfo(merchant_idx)
      if not isPurchasable then break end
      if extendedCost then break end
      if numAvailable == 0 then break end -- -1 == unlimited

      itemid_to_merchant_idx[item_id] = merchant_idx
   until true end
end

-- Scans currently opened recipe and intersect with merchant items
-- Sets table. Intersected item_ids as keys and amount required for ONE craft as values.
-- Interface\AddOns\Blizzard_Professions\Blizzard_ProfessionsCrafting.lua
-- /dump ProfessionsFrame.CraftingPage.SchematicForm.recipeSchematic -- does not include info on currently selected quality of reagents?
-- /dump ProfessionsFrame.CraftingPage.SchematicForm.recipeSchematic.reagentSlotSchematics
local intersected_recipe_merchant_quantity_required = {}
local function ScanCurrentRecipe(itemid_to_merchant_idx)
   wipe(intersected_recipe_merchant_quantity_required)
   if not ProfessionsFrame then return end
   if not ProfessionsFrame.CraftingPage then return end
   if not ProfessionsFrame.CraftingPage.SchematicForm then return end

   local recipe_schematic = ProfessionsFrame.CraftingPage.SchematicForm.recipeSchematic
   if not recipe_schematic then return end

   local reagent_slots = recipe_schematic.reagentSlotSchematics
   if not reagent_slots then return end

   for slot_idx = 1, #reagent_slots do repeat -- break now goes to next iteration
      local slot_data = reagent_slots[slot_idx]
      if not slot_data.required then break end
      if not slot_data.reagents then return end
      assert(#slot_data.reagents == 1, "can't work with more than ONE reagent per slot yet")

      local item_id = slot_data.reagents[1].itemID

      if not itemid_to_merchant_idx[item_id] then break end

      intersected_recipe_merchant_quantity_required[item_id] = slot_data.quantityRequired
   until true end
end

-- /run _G['SR13-ReagentBuy'].debug.TEST_SCAN()
_G[a_name].debug.TEST_SCAN = function()
   ScanMerchant()
   ScanCurrentRecipe(itemid_to_merchant_idx)
   DevTools_Dump(intersected_recipe_merchant_quantity_required)
end

local need = {}
local total_cost
local CONTINUE_UNIQ_TOKEN = {}
local function BuyReagentsForSelectedRecipe(cmd, edit_box, continue_buying)
   if continue_buying == CONTINUE_UNIQ_TOKEN then --[[]] else total_cost = 0 end
   ScanMerchant()
   ScanCurrentRecipe(itemid_to_merchant_idx)

   if not pairs(intersected_recipe_merchant_quantity_required) then return end

   local mult = tonumber(cmd)

   wipe(need)

   print("Buying reagents to craft " .. ProfessionsFrame.CraftingPage.SchematicForm.recipeSchematic.name .. ' * ' .. mult)

   for item_id, required_count in pairs(intersected_recipe_merchant_quantity_required) do
      local player_count = ItemUtil.GetCraftingReagentCount(item_id)
      local missing_count = player_count - (required_count * mult)
      if missing_count < 0 then
         need[item_id] = -missing_count
      end
   end

   local buy_more_stacks
   for merchant_idx = 1, GetMerchantNumItems() do
      local link = GetMerchantItemLink(merchant_idx)
      local item_id = link and link:match("|Hitem:(%d+)")
      if item_id then
         item_id = item_id + 0
         local buy_amount = need[item_id]
         if buy_amount then
            local name, texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost = GetMerchantItemInfo(merchant_idx)
            -- print(name, extendedCost)
            local maxStack = GetMerchantItemMaxStack(merchant_idx)
            if buy_amount > maxStack then
               buy_amount = maxStack
               buy_more_stacks = true
            end
            -- TODO: numAvailable, maxStack, extendedCost
            if not extendedCost or extendedCost == 0 then
               total_cost = total_cost + (price / quantity) * buy_amount
               print(name .. " x" .. buy_amount .. ": BuyMerchantItem", merchant_idx, buy_amount)
               BuyMerchantItem(merchant_idx, buy_amount)
            end
         end
      end
   end
   print("Expected total cost: " .. GetMoneyString(total_cost))

   if buy_more_stacks then
      C_Timer.After(0.2, function() return BuyReagentsForSelectedRecipe(cmd, edit_box, CONTINUE_UNIQ_TOKEN) end)
   end
end

_G.BuyReagentsForSelectedRecipe = BuyReagentsForSelectedRecipe
a_env.register_slash("BuyReagents", { "/regbuy", "/buyreg" }, BuyReagentsForSelectedRecipe)
a_env.register_slash = nil
