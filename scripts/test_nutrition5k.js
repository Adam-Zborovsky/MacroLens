/**
 * test_nutrition5k.js
 * 
 * Benchmarks the backend's AnalyzerService against the Nutrition5k dataset.
 * 
 * Usage: node scripts/test_nutrition5k.js --dataset <path_to_nutrition5k> --count <number_of_images>
 */

require('dotenv').config({ path: require('path').join(__dirname, '../backend/.env') });
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { AnalyzerService } = require('../backend/src/services/analyzer');

async function parseMetadata(datasetPath) {
  const nutritionFile = path.join(datasetPath, 'dish_nutrition_values.csv');
  const ingredientsFile = path.join(datasetPath, 'dish_ingredients.csv');
  const dishMap = new Map();

  if (!fs.existsSync(nutritionFile)) {
    console.error(`Error: Metadata file not found at ${nutritionFile}`);
    process.exit(1);
  }

  // 1. Parse nutrition totals
  const nutritionStream = fs.createReadStream(nutritionFile);
  const rlNut = readline.createInterface({ input: nutritionStream, crlfDelay: Infinity });

  for await (const line of rlNut) {
    const parts = line.split(',');
    if (parts.length < 6 || parts[0] === 'dish_id') continue;
    const dishId = parts[0];
    dishMap.set(dishId, {
      calories: parseFloat(parts[1]),
      mass: parseFloat(parts[2]),
      fat: parseFloat(parts[3]),
      carbs: parseFloat(parts[4]),
      protein: parseFloat(parts[5]),
      ingredients: []
    });
  }

  // 2. Parse ingredient details
  if (fs.existsSync(ingredientsFile)) {
    const ingrStream = fs.createReadStream(ingredientsFile);
    const rlIngr = readline.createInterface({ input: ingrStream, crlfDelay: Infinity });
    for await (const line of rlIngr) {
      const parts = line.split(',');
      if (parts[0] === 'dish_id') continue;
      
      const dishId = parts[0];
      const dish = dishMap.get(dishId);
      if (dish) {
        dish.ingredients.push({
          name: parts[2] ? parts[2].toLowerCase() : 'unknown',
          grams: parseFloat(parts[3]) || 0
        });
      }
    }
  }

  return dishMap;
}

async function runBenchmark() {
  const args = process.argv.slice(2);
  let datasetPath = path.join(__dirname, '../nutrition5k');
  let count = 5;
  let useMulti = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--dataset' && args[i + 1]) {
      datasetPath = args[i + 1];
      i++;
    } else if (args[i] === '--count' && args[i + 1]) {
      count = parseInt(args[i + 1]);
      i++;
    } else if (args[i] === '--multi') {
      useMulti = true;
    }
  }

  console.log(`Loading metadata from ${datasetPath}...`);
  const dishMap = await parseMetadata(datasetPath);
  console.log(`Loaded metadata for ${dishMap.size} dishes.`);

  const analyzer = new AnalyzerService();
  const dishIds = Array.from(dishMap.keys());
  
  // Updated path to side_angles
  const sideAnglesPath = path.join(datasetPath, 'side_angles');
  const availableDishes = dishIds.filter(id => fs.existsSync(path.join(sideAnglesPath, id)));
  
  if (availableDishes.length === 0) {
    console.error('Error: No dish folders found in nutrition5k/side_angles.');
    process.exit(1);
  }

  const selectedDishes = availableDishes.slice(0, count);
  console.log(`Starting forensic benchmark on ${selectedDishes.length} dishes using ${useMulti ? 'multiple' : 'single'} side-angle frames...\n`);

  const results = [];

  for (const dishId of selectedDishes) {
    const truth = dishMap.get(dishId);
    const dishFolder = path.join(sideAnglesPath, dishId);
    
    const files = fs.readdirSync(dishFolder).filter(f => 
      f.toLowerCase().endsWith('.jpeg') || f.toLowerCase().endsWith('.jpg') || f.toLowerCase().endsWith('.png')
    );

    if (files.length === 0) {
      console.log(`[${dishId}] Skipped: No images found in folder.`);
      continue;
    }

    // Pick images
    let imagesToProcess = [];
    if (useMulti) {
      // Pick up to 4 images from different frames
      imagesToProcess = files.slice(0, 4);
    } else {
      // Prefer camera_Aframe001.jpeg for consistency, fallback to any image
      const imageFile = files.find(f => f === 'camera_Aframe001.jpeg') || files[0];
      imagesToProcess = [imageFile];
    }

    console.log(`[${dishId}] Analyzing ${imagesToProcess.length} images: ${imagesToProcess.join(', ')}...`);
    
    try {
      const imagesBase64 = imagesToProcess.map(imgFile => 
        fs.readFileSync(path.join(dishFolder, imgFile)).toString('base64')
      );
      const mimeType = imagesToProcess[0].endsWith('.png') ? 'image/png' : 'image/jpeg';
      
      const analysis = await analyzer.analyzeCapture(imagesBase64, mimeType);
      
      const pred = analysis.meal_totals;
      const predItems = analysis.items || [];
      
      const totalPredMass = predItems.reduce((s, i) => s + (i.estimated_grams || 0), 0);
      const res = {
        dishId,
        macroError: {
          cal: Math.abs(pred.calories - truth.calories),
          pro: Math.abs(pred.protein_g - truth.protein),
          calPct: (Math.abs(pred.calories - truth.calories) / truth.calories) * 100
        },
        massError: Math.abs(totalPredMass - truth.mass),
        massPct: (Math.abs(totalPredMass - truth.mass) / truth.mass) * 100
      };
      
      results.push(res);
      
      console.log(`------------------------------------------------`);
      console.log(`[${dishId}] Forensic Comparison:`);
      console.log(`  MACROS:`);
      console.log(`    Calories: ${pred.calories.toFixed(1)} (Truth: ${truth.calories.toFixed(1)}) | Error: ${res.macroError.calPct.toFixed(1)}%`);
      console.log(`    Protein:  ${pred.protein_g.toFixed(1)}g (Truth: ${truth.protein.toFixed(1)}g)`);
      console.log(`  MASS:`);
      console.log(`    Total:    ${totalPredMass.toFixed(1)}g (Truth: ${truth.mass.toFixed(1)}g) | Error: ${res.massPct.toFixed(1)}%`);
      
      console.log(`  SPATIAL REASONING (AI ESTIMATES):`);
      predItems.forEach(item => {
        const dims = item.visual_dimensions || {};
        const area = dims.est_area_cm2 || 0;
        const platePct = (area / 500) * 100;
        console.log(`    - ${item.name}: ${area}cm² (${platePct.toFixed(1)}% of plate) x ${dims.est_height_cm || '?'}cm height`);
      });

      console.log(`  INGREDIENTS:`);
      const truthNames = truth.ingredients.map(i => `${i.name} (${i.grams}g)`).join(', ');
      const predNames = predItems.map(i => `${i.name} (${i.estimated_grams}g)`).join(', ');
      console.log(`    Expected: [${truthNames}]`);
      console.log(`    Detected: [${predNames}]`);
      console.log(`------------------------------------------------\n`);
      
    } catch (err) {
      console.error(`  - Error: ${err.message}\n`);
    }
  }

  if (results.length > 0) {
    const totals = results.reduce((acc, r) => {
      acc.cal += r.macroError.cal;
      acc.pro += r.macroError.pro;
      acc.mass += r.massError;
      return acc;
    }, { cal: 0, pro: 0, mass: 0 });

    const n = results.length;
    console.log('--- FORENSIC SUMMARY ---');
    console.log(`Total Samples:   ${n}`);
    console.log(`MAE Calories:    ${(totals.cal / n).toFixed(2)} kcal`);
    console.log(`MAE Protein:     ${(totals.pro / n).toFixed(2)} g`);
    console.log(`MAE Total Mass:  ${(totals.mass / n).toFixed(2)} g`);
    console.log('------------------------');
  }
}

runBenchmark().catch(console.error);
