********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: This do-file aggregates food and beverage product subcategories in 
*			the USDA Global Branded Food Products Database (GBFPD) and drops 
*			products without a proper category classification.
********************************************************************************

*Import the dta file created in the previous do file.
use ".../brandedfood_1.dta", clear

* First, drop products with a missing USDA branded food category
drop if branded_food_category=="" 
* Create the new variable "categories" with default value
gen categories = "Other" 
* Clean the original branded food category labels before assigning products * to the aggregated categories.
replace branded_food_category = subinstr(branded_food_category, "â", "-", .)
replace branded_food_category = ustrregexra(branded_food_category, "[[:cntrl:]]", "")

* --------- Baby Foods ---------
replace categories = "Baby" if inlist(branded_food_category, ///
	"Baby/Infant  Foods/Beverages")

* --------- Bakery Products ---------
replace categories = "Bakery" if inlist(branded_food_category, ///
	"Bread", ///
	"Bread/Bakery Products Variety Packs")
replace categories = "Bakery" if inlist(branded_food_category, ///
	"Breads & Buns", ///
	"Cakes - Sweet (Frozen)", ///
	"Cakes - Sweet (Shelf Stable)")
replace categories = "Bakery" if inlist(branded_food_category, ///
	"Cakes, Cupcakes, Snack Cakes", ///
	"Croissants, Sweet Rolls, Muffins & Other Pastries", ///
	"Crusts & Dough")
replace categories = "Bakery" if inlist(branded_food_category, ///
	"Frozen Bread & Dough", ///
	"Mexican Dinner Mixes", /// tortillas
	"Pastry Shells & Fillings")
replace categories = "Bakery" if inlist(branded_food_category, ///
	"Pies/Pastries - Sweet (Shelf Stable)", ///
	"Pies/Pastries/Pizzas/Quiches - Savoury (Frozen)", ///
	"Savoury Bakery Products", ///
	"Sweet Bakery Products")

* --------- Baking Supplies ----------
replace categories = "Baking" if inlist(branded_food_category, ///
	"Baking", ///
	"Baking Accessories", ///
	"Baking Additives & Extracts", ///
	"Baking Decorations & Dessert Toppings")
replace categories = "Baking" if inlist(branded_food_category, ///
	"Baking/Cooking Mixes (Perishable)")
replace categories = "Baking" if inlist(branded_food_category, ///
	"Baking/Cooking Mixes (Shelf Stable)", ///
	"Baking/Cooking Mixes/Supplies", ///
	"Baking/Cooking Mixes/Supplies Variety Packs", ///
	"Baking/Cooking Supplies (Shelf Stable)", ///
	"Flour - Cereal/Pulse (Shelf Stable)")
replace categories = "Baking" if inlist(branded_food_category, ///
	"Cake, Cookie & Cupcake Mixes", ///
	"Flours & Corn Meal", ///
	"Grains/Flour", ///
	"Granulated, Brown & Powdered Sugar")
replace categories = "Baking" if inlist(branded_food_category, ///
	"Sugars/Sugar Substitute Products", ///
	"Bread & Muffin Mixes", ///
	"Vinegars/Cooking Wines")

* --------- Breakfast Products -----------
replace categories = "Breakfast" if inlist(branded_food_category, ///
	"Breakfast Foods", ///
	"Breakfast Sandwiches, Biscuits & Meals", ///
	"Frozen Breakfast Sandwiches, Biscuits & Meals")

* --------- Cereals ----------------
replace categories = "Cereals" if inlist(branded_food_category, ///
	"Cereal", ///
	"Cereal/Muesli Bars", ///
	"Cereals Products - Not Ready to Eat (Shelf Stable)", ///
	"Cereals Products - Ready to Eat (Shelf Stable)")
replace categories = "Cereals" if inlist(branded_food_category, ///
	"Processed Cereal Products")

* --------- Snacks, Sweet and Savory ---------
replace categories = "Snack" if inlist(branded_food_category, ///
	"Biscuits/Cookies", ///
	"Biscuits/Cookies (Shelf Stable)")
replace categories = "Snack" if inlist(branded_food_category, ///
	"Candy", ///
	"Chewing Gum & Mints", ///
	"Chips, Pretzels & Snacks", ///
	"Chips/Crisps/Snack Mixes - Natural/Extruded (Shelf Stable)")
replace categories = "Snack" if inlist(branded_food_category, ///
	"Chocolate", ///
	"Confectionery Products")
replace categories = "Snack" if inlist(branded_food_category, ///
	"Cookies & Biscuits", ///
	"Crackers & Biscotti", ///
	"Flavored Snack Crackers")
replace categories = "Snack" if inlist(branded_food_category, ///
	"Lunch Snacks & Combinations", ///
	"Other Snacks")
replace categories = "Snack" if inlist(branded_food_category, ///
	"Popcorn (Shelf Stable)", ///
	"Popcorn, Peanuts, Seeds & Related Snacks")
replace categories = "Snack" if inlist(branded_food_category, ///
	"Snack, Energy & Granola Bars", ///
	"Snacks")
replace categories = "Snack" if inlist(branded_food_category, ///
	"Wholesome Snacks")

* --------- Desserts and Ice Creams ---------
replace categories = "Dessert" if inlist(branded_food_category, ///
	"Desserts/Dessert Sauces/Toppings")
replace categories = "Dessert" if inlist(branded_food_category, ///
	"Gelatin, Gels, Pectins & Desserts", ///
	"Ice Cream & Frozen Yogurt", ///
	"Ice Cream/Ice Novelties (Shelf Stable)")
replace categories = "Dessert" if inlist(branded_food_category, ///
	"Other Frozen Desserts", ///
	"Puddings & Custards")

* --------- Convenience/Prepared Foods ----------
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Canned Condensed Soup", ///
	"Canned Soup", ///
	"Chili & Stew", ///
	"Cooked & Prepared")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Dough Based Products / Meals")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Dough Based Products / Meals - Not Ready to Eat - Savoury (Shelf Stable)", ///
	"Entrees, Sides & Small Meals", ///
	"Flavored Rice Dishes")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"French Fries, Potatoes & Onion Rings", ///
	"Frozen Appetizers & Hors D'oeuvres", ///
	"Frozen Dinners & Entrees")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Frozen Pancakes, Waffles, French Toast & Crepes", ///
	"Frozen Patties and Burgers")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Frozen Prepared Sides", ///
	"Grain Based Products / Meals", ///
	"Grain Based Products / Meals - Not Ready to Eat - Savoury (Shelf Stable)", ///
	"Other Soups")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Pancakes, Waffles, French Toast & Crepes", ///
	"Pizza", ///
	"Pizza Mixes & Other Dry Dinners")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Prepared Soups", ///
	"Prepared Subs & Sandwiches")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Prepared Wraps and Burittos", ///
	"Prepared/Preserved Foods Variety Packs", ///
	"Ready-Made Combination Meals")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Sandwiches/Filled Rolls/Wraps", ///
	"Soups - Prepared (Shelf Stable)", ///
	"Pasta Dinners", ///
	"Sushi")
replace categories = "Convenience" if inlist(branded_food_category, ///
	"Vegetable Based Products / Meals", ///
	"Vegetable Based Products / Meals - Not Ready to Eat (Frozen)")

* --------- Dairy Products ----------
replace categories = "Dairy" if inlist(branded_food_category, ///
	"Cheese", ///
	"Cheese/Cheese Substitutes", ///
	"Cream")
replace categories = "Dairy" if inlist(branded_food_category, ///
	"Cream/Cream Substitutes")
replace categories = "Dairy" if inlist(branded_food_category, ///
	"Dairy/Egg Based Products / Meals", ///
	"Milk")
replace categories = "Dairy" if inlist(branded_food_category, ///
	"Milk/Milk Substitutes", ///
	"Processed Cheese & Cheese Novelties")
replace categories = "Dairy" if inlist(branded_food_category, ///
	"Yogurt", ///
	"Yogurt/Yogurt Substitutes", ///
	"Yogurt/Yogurt Substitutes (Perishable)")

* --------- Milk Additives ----------
replace categories = "MilkAdditive" if inlist(branded_food_category, ///
	"Milk Additives")
 
* --------- Deli Foods ---------- 
replace categories = "Deli" if inlist(branded_food_category, ///
	"Deli Salads", ///
	"Other Deli")

* --------- Edible Oils and Fats ----------
replace categories = "Oil" if inlist(branded_food_category, ///
	"Butter & Spread", ///
	"Butter/Butter Substitutes", ///
	"Fats Edible")
replace categories = "Oil" if inlist(branded_food_category, ///
	"Nut & Seed Butters", ///
	"Oils Edible", ///
	"Vegetable & Cooking Oils")

* --------- Egg Products and Substitutes -------
replace categories = "Egg" if inlist(branded_food_category, ///
	"Egg Based Products / Meals - Not Ready to Eat (Frozen)", /// egg whites
	"Eggs & Egg Substitutes", ///
	"Eggs/Eggs Substitutes")
 
* --------- Seafood Products ------------
replace categories = "Seafood" if inlist(branded_food_category, ///
	"Aquatic Invertebrates/Fish/Shellfish/Seafood Combination", ///
	"Canned Seafood", ///
	"Canned Tuna")
replace categories = "Seafood" if inlist(branded_food_category, ///
	"Fish  Prepared/Processed", ///
	"Fish  Unprepared/Unprocessed", ///
	"Fish & Seafood", ///
	"Fish - Prepared/Processed")
replace categories = "Seafood" if inlist(branded_food_category, ///
	"Fish Substitutes", ///
	"Frozen Fish & Seafood")
replace categories = "Seafood" if inlist(branded_food_category, ///
	"Shellfish Prepared/Processed", ///
	"Shellfish Unprepared/Unprocessed")
	
* Manually reclassify two products listed under "Fish Substitutes" into the
* appropriate aggregated categories based on their actual product type.
replace categories = "Egg" if gtin_upc == "00049485051657"
replace categories = "Convenience" if gtin_upc == "00031000809263"

* --------- Fruits and Vegetables ----------
replace categories = "Fruit" if inlist(branded_food_category, ///
	"Berries/Small Fruit", ///
	"Canned & Bottled Beans", ///
	"Canned Fruit", ///
	"Canned Vegetables")
replace categories = "Fruit" if inlist(branded_food_category, ///
	"Chickpeas")
replace categories = "Fruit" if inlist(branded_food_category, ///
	"Frozen Vegetables", ///
	"Fruit  Prepared/Processed")
replace categories = "Fruit" if inlist(branded_food_category, ///
	"Fruit - Prepared/Processed", ///
	"Fruit - Prepared/Processed (Shelf Stable)")
replace categories = "Fruit" if inlist(branded_food_category, ///
	"Fruits - Unprepared/Unprocessed (Frozen)")
replace categories = "Fruit" if inlist(branded_food_category, ///
	"Fruits - Unprepared/Unprocessed (Shelf Stable)", ///
	"Gardening", ///
	"Peppers")
replace categories = "Fruit" if inlist(branded_food_category, ///
	"Pre-Packaged Fruit & Vegetables", ///
	"Tomatoes", ///
	"Vegetable and Lentil Mixes")
replace categories = "Fruit" if inlist(branded_food_category, ///
	"Vegetables  Prepared/Processed", ///
	"Vegetables  Unprepared/Unprocessed (Frozen)", ///
	"Vegetables - Prepared/Processed")
replace categories = "Fruit" if inlist(branded_food_category, ///
	"Vegetables - Prepared/Processed (Shelf Stable)", ///
	"Vegetables - Unprepared/Unprocessed (Frozen)", ///
	"Vegetables - Unprepared/Unprocessed (Shelf Stable)")

* --------- Nuts, Seeds and Grains -----------
replace categories = "Nut" if inlist(branded_food_category, ///
	"Fruit/Nuts/Seeds Combination", ///
	"Fruits/Vegetables/Nuts/Seeds Variety Packs", ///
	"Nuts/Seeds  Prepared/Processed", ///
	"Nuts/Seeds - Prepared/Processed")
replace categories = "Nut" if inlist(branded_food_category, ///
	"Nuts/Seeds - Prepared/Processed (Shelf Stable)", ///
	"Nuts/Seeds - Unprepared/Unprocessed (In Shell)", ///
	"Other Grains & Seeds")

* --------- Syrup and Molassess --------------
replace categories = "Syrup" if inlist(branded_food_category, ///
	"Syrups & Molasses")

* --------- Honey ----------
replace categories = "Honey" if inlist(branded_food_category, ///
	"Honey")
 
* --------- Meat Products ----------
replace categories = "Meat" if inlist(branded_food_category, ///
	"Bacon, Sausages & Ribs", ///
	"Beef - Prepared/Processed", ///
	"Canned Meat")
replace categories = "Meat" if inlist(branded_food_category, ///
	"Frozen Bacon, Sausages & Ribs")
replace categories = "Meat" if inlist(branded_food_category, ///
	"Frozen Poultry, Chicken & Turkey", ///
	"Frozen Sausages, Hotdogs & Brats", ///
	"Meat/Poultry/Other Animals  Prepared/Processed")
replace categories = "Meat" if inlist(branded_food_category, ///
	"Meat/Poultry/Other Animals  Unprepared/Unprocessed", ///
	"Meat/Poultry/Other Animals - Prepared/Processed")
replace categories = "Meat" if inlist(branded_food_category, ///
	"Meat/Poultry/Other Animals - Unprepared/Unprocessed", ///
	"Meat/Poultry/Other Animals Sausages  Prepared/Processed", ///
	"Meat/Poultry/Other Animals Sausages - Prepared/Processed", ///
	"Other Frozen Meats", ///
	"Other Meats")
replace categories = "Meat" if inlist(branded_food_category, ///
	"Pepperoni, Salami & Cold Cuts", ///
	"Pork - Prepared/Processed", ///
	"Pork - Unprepared/Unprocessed", ///
	"Pork Sausages - Prepared/Processed")
replace categories = "Meat" if inlist(branded_food_category, ///
	"Poultry, Chicken & Turkey", ///
	"Sausages, Hotdogs & Brats", ///
	"Turkey - Unprepared/Unprocessed")

* --------- Plant Based Meat Products ---------
replace categories = "PlantBasedMeat" if inlist(branded_food_category, ///
	"Meat Substitutes", ///
	"Vegetarian Frozen Meats")

* --------- Sauces, Dressings, Dips and Condiments --------
replace categories = "Sauce" if inlist(branded_food_category, ///
	"Dips & Salsa", ///
	"Dressings/Dips (Shelf Stable)")
replace categories = "Sauce" if inlist(branded_food_category, ///
	"Jam, Jelly & Fruit Spreads", ///
	"Ketchup, Mustard, BBQ & Cheese Sauce", ///
	"Oriental, Mexican & Ethnic Sauces")
replace categories = "Sauce" if inlist(branded_food_category, ///
	"Other Condiments", ///
	"Other Cooking Sauces", ///
	"Prepared Pasta & Pizza Sauces")
replace categories = "Sauce" if inlist(branded_food_category, ///
	"Salad Dressing & Mayonnaise")
replace categories = "Sauce" if inlist(branded_food_category, ///
	"Sauces - Cooking (Shelf Stable)")
replace categories = "Sauce" if inlist(branded_food_category, ///
	"Sauces/Spreads/Dips/Condiments", ///
	"Sweet Spreads")

* --------- Seasonings ---------------
replace categories = "Seasoning" if inlist(branded_food_category, ///
	"Herbs & Spices", ///
	"Herbs/Spices/Extracts", ///
	"Seasoning Mixes, Salts, Marinades & Tenderizers", ///
	"Seasonings/Preservatives/Extracts Variety Packs")

* --------- Stuffings and Gravy---------
replace categories = "Stuffing" if inlist(branded_food_category, ///
	"Gravy Mix", ///
	"Stuffing")

* --------- Supplements and Vitamins --------
replace categories = "Supplement" if inlist(branded_food_category, ///
	"Amino Acid Supplements", ///
	"Antioxidant Supplements", ///
	"Children's Natural Remedies", ///
	"Children's Nutritional Supplements", ///
	"Digestive & Fiber Supplements")
replace categories = "Supplement" if inlist(branded_food_category, ///
	"Fatty Acid Supplements", ///
	"Green Supplements", ///
	"Health Care", ///
	"Herbal Supplements")
replace categories = "Supplement" if inlist(branded_food_category, ///
	"Meal Replacement Supplements", ///
	"Minerals", ///
	"Specialty Formula Supplements", ///
	"Vitamins")
replace categories = "Supplement" if inlist(branded_food_category, ///
	"Vitamins/Minerals/Nutritional Supplements", ///
	"Weight Control")

* --------- Pasta, Noodles, and Rice -----------
replace categories = "Pasta" if inlist(branded_food_category, ///
	"All Noodles")
replace categories = "Pasta" if inlist(branded_food_category, ///
	"Pasta by Shape & Type", ///
	"Pasta/Noodles", ///
	"Rice")

* --------- Pickled Foods -------------
replace categories = "Pickled" if inlist(branded_food_category, ///
	"Pickles, Olives, Peppers & Relishes", ///
	"Pickles/Relishes/Chutneys/Olives")

* --------- Alcoholic Beverages ---------
replace categories = "Alcohol" if inlist(branded_food_category, ///
	"Alcohol", ///
	"Alcoholic Beverages", ///
	"Beer")
	
* --------- Energy Drinks -----------
replace categories = "Energy" if inlist(branded_food_category, ///
	"Energy, Protein & Muscle Recovery Drinks", ///
	"Sport Drinks")

* --------- Other Non-Alcoholic Beverages ----------
replace categories = "NonAlcohol" if inlist(branded_food_category, ///
	"Breakfast Drinks", ///
	"Fruit & Vegetable Juice, Nectars & Fruit Drinks")
replace categories = "NonAlcohol" if inlist(branded_food_category, ///
	"Drinks Flavoured - Ready to Drink", ///
	"Frozen Fruit & Fruit Juice Concentrates", ///
	"Non Alcoholic Beverages  Not Ready to Drink")
replace categories = "NonAlcohol" if inlist(branded_food_category, ///
	"Non Alcoholic Beverages  Ready to Drink", ///
	"Non Alcoholic Beverages - Not Ready to Drink", ///
	"Non Alcoholic Beverages - Ready to Drink", ///
	"Other Drinks")
replace categories = "NonAlcohol" if inlist(branded_food_category, ///
	"Powdered Drinks")

* --------- Soft Beverages -------------
replace categories = "Soft" if inlist(branded_food_category, ///
	"Soda")

* --------- Tea and Coffee Beverages---------------
replace categories = "TeaCoffee" if inlist(branded_food_category, ///
	"Coffee", ///
	"Coffee/Coffee Substitutes", ///
	"Coffee/Tea/Substitutes")
replace categories = "TeaCoffee" if inlist(branded_food_category, ///
	"Iced & Bottle Tea", ///
	"Tea Bags", ///
	"Tea and Infusions/Tisanes")
 
* --------- Plant Based Milk Products ---------
replace categories = "PlantBasedMilk" if inlist(branded_food_category, ///
	"Plant Based Milk")

* --------- Liquid Water Enhances --------------
replace categories = "WaterEnhancer" if inlist(branded_food_category, ///
	"Liquid Water Enhancer")

* --------- Water Beverages -----------
replace categories = "Water" if inlist(branded_food_category, ///
	"Plant Based Water", ///
	"Water")
 
* -------------Others---------------
 *Food/Beverage/Tobacco Variety Packs*
replace categories = "Snack" if gtin_upc=="00013562302475"
replace categories = "Snack" if gtin_upc=="00013562302437"
replace categories = "Convenience" if gtin_upc=="10852777002919"
replace categories = "Convenience" if gtin_upc=="10852777002667"
replace categories = "Convenience" if gtin_upc=="10852777002322"
replace categories = "Convenience" if gtin_upc=="10852777002315"
replace categories = "Convenience" if gtin_upc=="10852777005972"

* Display to verify the categorization
list branded_food_category categories if _n <= 20

tab branded_food_category if categories=="Other"
drop if categories=="Other" 

 * Create a dictionary for readable categories names
gen category_name = categories
  replace category_name = "Bakery Products" if categories == "Bakery"
  replace category_name = "Alcoholic Beverages" if categories == "Alcohol"
  replace category_name = "Soft Beverages" if categories == "Soft"
  replace category_name = "Energy Drinks" if categories == "Energy"
  replace category_name = "Tea and Coffee Beverages" if categories == "TeaCoffee"
  replace category_name = "Other Non-Alcoholic Beverages" if categories == "NonAlcohol"
  replace category_name = "Baby/Infant Foods" if categories == "Baby"
  replace category_name = "Baking Supplies" if categories == "Baking"
  replace category_name = "Cereals" if categories == "Cereals"
  replace category_name = "Breakfast Foods" if categories == "Breakfast"
  replace category_name = "Pickled Foods" if categories == "Pickled"
  replace category_name = "Snacks, Sweet or Savory" if categories == "Snack"
  replace category_name = "Desserts and Ice Creams" if categories == "Dessert"
  replace category_name = "Convenience/Prepared Foods" if categories == "Convenience"
  replace category_name = "Dairy Products" if categories == "Dairy"
  replace category_name = "Plant-Based Milk Products" if categories == "PlantBasedMilk"
  replace category_name = "Egg Products and Substitutes" if categories == "Egg"
  replace category_name = "Meat Products" if categories == "Meat"
  replace category_name = "Plant-Based Meat Products" if categories == "PlantBasedMeat"
  replace category_name = "Seafood Products" if categories == "Seafood"
  replace category_name = "Deli Foods" if categories == "Deli"
  replace category_name = "Sauces, Dressings, Dips, and Condiments" if categories == "Sauce"
  replace category_name = "Edible Oils and Fats" if categories == "Oil"
  replace category_name = "Fruits and Vegetables" if categories == "Fruit"
  replace category_name = "Pasta, Noodles and Rice" if categories == "Pasta"
  replace category_name = "Seasonings" if categories == "Seasoning"
  replace category_name = "Stuffings and Gravy" if categories == "Stuffing"
  replace category_name = "Syrups and Molasses" if categories == "Syrup"
  replace category_name = "Honey" if categories == "Honey"
  replace category_name = "Nuts, Seeds and Grains" if categories == "Nut"
  replace category_name = "Supplements and Vitamins" if categories == "Supplement"
  replace category_name = "Water Beverages" if categories == "Water"
  replace category_name = "Liquid Water Enhancers" if categories == "WaterEnhancer"
  replace category_name = "Milk Additives" if categories == "MilkAdditive"

save ".../brandedfood_2.dta", replace

