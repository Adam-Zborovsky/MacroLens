const express = require('express');
const https = require('https');
const { verifyFirebaseToken } = require('../middleware/firebaseAuth');

const router = express.Router();
router.use(verifyFirebaseToken);

/**
 * Fetch nutrition data from Open Food Facts by barcode.
 * Normalises the OpenFoodFacts response to the same NutritionProfile
 * shape the rest of the API uses, so the Flutter client can go straight
 * into the Detective UI.
 */
router.get('/:barcode', async (req, res, next) => {
  const { barcode } = req.params;

  if (!/^\d{8,14}$/.test(barcode)) {
    return res.status(400).json({
      error: { code: 'ERR_INVALID_BARCODE', message: 'Barcode must be 8–14 digits.' },
    });
  }

  try {
    const product = await fetchOpenFoodFacts(barcode);

    if (!product) {
      return res.status(404).json({
        error: {
          code: 'ERR_BARCODE_NOT_FOUND',
          message: `No product found for barcode ${barcode} in Open Food Facts.`,
        },
      });
    }

    const nutriments = product.nutriments ?? {};

    const nutritionPer100g = {
      calories:           sanitise(nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'] / 100),
      proteinGrams:       sanitise(nutriments['proteins_100g']     ?? nutriments['proteins']),
      carbohydratesGrams: sanitise(nutriments['carbohydrates_100g'] ?? nutriments['carbohydrates']),
      fatGrams:           sanitise(nutriments['fat_100g']           ?? nutriments['fat']),
      fiberGrams:         sanitise(nutriments['fiber_100g']         ?? nutriments['fiber'] ?? 0),
      sodiumMilligrams:   sanitise((nutriments['sodium_100g'] ?? 0) * 1000),
    };

    res.json({
      barcode,
      name:           product.product_name ?? product.product_name_en ?? 'Unknown Product',
      brand:          product.brands ?? null,
      imageUrl:       product.image_front_url ?? product.image_url ?? null,
      servingSizeG:   sanitise(product.serving_quantity),
      nutriscore:     product.nutriscore_grade?.toUpperCase() ?? null,
      nutritionPer100g,
      // Pre-filled defaults for Detective UI
      estimatedGrams: sanitise(product.serving_quantity) || 100,
    });
  } catch (err) {
    next(err);
  }
});

// ─── Open Food Facts HTTP helper ─────────────────────────────────────────────

function fetchOpenFoodFacts(barcode) {
  const url = `https://world.openfoodfacts.org/api/v2/product/${barcode}?fields=product_name,product_name_en,brands,nutriments,serving_quantity,image_front_url,image_url,nutriscore_grade`;

  return new Promise((resolve, reject) => {
    const req = https.get(url, { headers: { 'User-Agent': 'MacroLens/1.0 (https://macrolens.app)' } }, (resp) => {
      let data = '';
      resp.on('data', (chunk) => (data += chunk));
      resp.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.status === 0 || !json.product) return resolve(null);
          resolve(json.product);
        } catch (e) {
          reject(new Error('ERR_BARCODE_PARSE: Failed to parse Open Food Facts response'));
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(8000, () => {
      req.destroy();
      reject(new Error('ERR_BARCODE_TIMEOUT: Open Food Facts request timed out'));
    });
  });
}

function sanitise(v) {
  const n = parseFloat(v);
  return isNaN(n) ? 0 : Math.round(n * 10) / 10;
}

module.exports = router;
