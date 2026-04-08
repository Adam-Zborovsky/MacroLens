/**
 * show_nutrition_data.js
 * 
 * Displays the ground truth nutritional data for a given dish ID or image path from the local Nutrition5k folder.
 * 
 * Usage: node scripts/show_nutrition_data.js --id <dish_id> OR --path <image_path>
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

async function getDishData(datasetPath, dishId) {
  const nutritionFile = path.join(datasetPath, 'dish_nutrition_values.csv');
  const ingredientsFile = path.join(datasetPath, 'dish_ingredients.csv');

  if (!fs.existsSync(nutritionFile)) return null;

  let dishData = null;

  // 1. Find Totals
  const rlNut = readline.createInterface({ input: fs.createReadStream(nutritionFile), crlfDelay: Infinity });
  for await (const line of rlNut) {
    const parts = line.split(',');
    if (parts[0] === dishId && parts[0] !== 'dish_id') {
      dishData = {
        id: parts[0],
        total: {
          calories: parseFloat(parts[1]),
          mass: parseFloat(parts[2]),
          fat: parseFloat(parts[3]),
          carb: parseFloat(parts[4]),
          protein: parseFloat(parts[5])
        },
        ingredients: []
      };
      break;
    }
  }

  if (!dishData) return null;

  // 2. Find Ingredients
  if (fs.existsSync(ingredientsFile)) {
    const rlIngr = readline.createInterface({ input: fs.createReadStream(ingredientsFile), crlfDelay: Infinity });
    for await (const line of rlIngr) {
      const parts = line.split(',');
      if (parts[0] === dishId && parts[0] !== 'dish_id') {
        dishData.ingredients.push({
          name: parts[2] || 'unknown',
          mass: parseFloat(parts[3]) || 0,
          calories: parseFloat(parts[4]) || 0,
          fat: parseFloat(parts[5]) || 0,
          carb: parseFloat(parts[6]) || 0,
          protein: parseFloat(parts[7]) || 0
        });
      }
    }
  }

  return dishData;
}

async function run() {
  const args = process.argv.slice(2);
  let datasetPath = path.join(__dirname, '../nutrition5k');
  let dishId = '';
  let imagePath = '';

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--id' && args[i + 1]) {
      dishId = args[i + 1];
      i++;
    } else if (args[i] === '--path' && args[i + 1]) {
      imagePath = args[i + 1];
      i++;
    }
  }

  if (imagePath && !dishId) {
    const match = imagePath.match(/(dish_\d+)/);
    if (match) dishId = match[1];
  }

  if (!dishId) {
    console.error('Error: Provide --id <dish_id> or --path <path_to_image>');
    process.exit(1);
  }

  console.log(`Looking up local metadata for ${dishId}...`);
  const data = await getDishData(datasetPath, dishId);

  if (!data) {
    console.error(`Error: Dish ${dishId} not found in CSV files.`);
    process.exit(1);
  }

  console.log('\n================================================');
  console.log(`DISH ID: ${data.id}`);
  console.log('================================================');
  console.log(`TOTALS:`);
  console.log(`  Calories:     ${data.total.calories.toFixed(1)} kcal`);
  console.log(`  Mass:         ${data.total.mass.toFixed(1)} g`);
  console.log(`  Protein:      ${data.total.protein.toFixed(1)} g`);
  console.log(`  Carbs:        ${data.total.carb.toFixed(1)} g`);
  console.log(`  Fat:          ${data.total.fat.toFixed(1)} g`);
  console.log(`------------------------------------------------`);
  console.log(`INGREDIENTS (${data.ingredients.length}):`);
  
  data.ingredients.forEach(ingr => {
    console.log(`\n- ${ingr.name}`);
    console.log(`  Mass: ${ingr.mass.toFixed(1)}g | Cal: ${ingr.calories.toFixed(1)} | P: ${ingr.protein.toFixed(1)}g | C: ${ingr.carb.toFixed(1)}g | F: ${ingr.fat.toFixed(1)}g`);
  });
  console.log('================================================\n');
}

run().catch(console.error);
