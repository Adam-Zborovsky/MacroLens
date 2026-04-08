const { GoogleGenerativeAI } = require('@google/generative-ai');
const crypto = require('crypto');

const GEMINI_MODEL = 'gemini-2.5-flash';

// Post-processing mass clamps by food category (grams)
const MASS_CLAMPS = {
  // Single fruit pieces
  fruit: { max: 150, keywords: ['apple', 'pear', 'peach', 'plum', 'orange', 'banana', 'nectarine', 'kiwi', 'mango'] },
  fruitChunks: { max: 120, keywords: ['pineapple', 'melon', 'honeydew', 'cantaloupe', 'watermelon', 'papaya'] },
  berries: { max: 80, keywords: ['strawberr', 'blueberr', 'raspberr', 'blackberr', 'grape', 'cherry', 'tomato'] },
  // Vegetables
  leafy: { max: 60, keywords: ['lettuce', 'spinach', 'arugula', 'kale', 'mixed greens', 'salad'] },
  rootVeg: { max: 120, keywords: ['carrot', 'celery', 'radish', 'beet'] },
  cookedVeg: { max: 180, keywords: ['broccoli', 'cauliflower', 'green bean', 'asparagus', 'zucchini', 'squash', 'pepper', 'cucumber', 'mushroom'] },
  // Proteins
  meatPortion: { max: 200, keywords: ['chicken', 'beef', 'pork', 'turkey', 'lamb', 'steak', 'drumstick', 'thigh', 'breast', 'wing', 'fish', 'salmon', 'tuna', 'shrimp'] },
  // Starches
  potato: { max: 180, keywords: ['potato', 'sweet potato', 'fries', 'wedge'] },
  grains: { max: 200, keywords: ['rice', 'pasta', 'noodle', 'quinoa', 'couscous'] },
  bread: { max: 80, keywords: ['bread', 'toast', 'roll', 'bun', 'croissant', 'muffin', 'bagel'] },
  // Snacks
  chips: { max: 40, keywords: ['chip', 'crisp', 'tortilla chip', 'dorito', 'nacho'] },
  nuts: { max: 50, keywords: ['almond', 'walnut', 'cashew', 'peanut', 'pecan', 'pistachio', 'nut', 'seed'] },
  // Dairy / Fats
  cheese: { max: 60, keywords: ['cheese', 'cheddar', 'mozzarella', 'parmesan', 'brie'] },
  bacon: { max: 30, keywords: ['bacon'] },
};

const ANALYSIS_PROMPT = `You are a professional nutritionist performing a forensic visual dietary assessment.
Analyze the food in this image and return ONLY a valid JSON object — no preamble, no commentary, no markdown code fences.

CRITICAL CALIBRATION WARNING:
Vision models consistently OVERESTIMATE food portions by 1.5–3x. You MUST actively correct for this.
Before finalizing any mass estimate, HALVE your initial gut estimate, then verify it against the sanity checks below.
A typical single serving on a plate is SMALL — most individual food items weigh 30–120g, not 150–300g.

CORE METHODOLOGY (Volumetric Reasoning):
1. ANCHORING: Identify a physical anchor. A standard 25cm plate has a TOTAL SURFACE AREA of ~500cm². Use this as your absolute scale.
2. AREA % CHECK: First, estimate what % of the plate area the food covers. Be CONSERVATIVE — most single food items cover only 3–8% of a plate, NOT 15–30%.
3. PERSPECTIVE CORRECTION: In side-angle/45° views, food appears "taller" and "deeper" than it is. Reduce height estimates by 40% for angled views (not 20% — this is a common underadjustment).
4. VOLUME TO MASS: Convert Volume (Area x Height) to Grams using typical food densities:
   - Dense Proteins (Meat/Fish): ~1.0g/cm³
   - Cooked Grains/Pasta: ~0.7g/cm³
   - Fiber-rich Veggies (Carrots/Broccoli): ~0.5g/cm³
   - Leafy Greens/Shredded: ~0.15g/cm³
   - Fats/Oils: ~0.9g/cm³
   - Nuts/Seeds: ~0.6g/cm³
   - Chips/Crisps: ~0.1g/cm³ (very light, mostly air)
5. SANITY CHECK — apply ALL of these:
   - "Does this pile of [food] actually weigh [X] grams?"
   - A single chicken drumstick = 80–120g. A single fruit = 80–150g. A handful of nuts = 20–40g.
   - Flat foods (chips, bacon, sliced items): height is almost always <0.5cm.
   - If your total exceeds 300g for a single-plate meal with 2–3 items, double-check every estimate.

FEW-SHOT CALIBRATION EXAMPLES (side-angle photos on standard plates):
- 3 cherry tomatoes on a plate: ~45g total (each ~15g, area ~7cm² each, height ~2.5cm)
- 1 chicken drumstick with small potato portion: chicken ~100g (area 50cm², height 2.5cm), potatoes ~60g (area 40cm², height 1.5cm)
- Small pile of pineapple chunks: ~75g (area 60cm², height 1.5cm)
- Handful of almonds: ~30g (area 35cm², height 1.2cm)
- 2 strips of bacon: ~15g (area 40cm², height 0.2cm)
- Small pile of potato chips: ~20g (area 80cm², height 0.3cm)

Rules:
1. Identify ALL individual food components.
2. Report confidence per item: "high", "medium", "low".
3. Food names MUST be valid USDA FoodData Central search terms.
4. ATOMIC DECONSTRUCTION: Separate distinguishable items (e.g., cheese on toast = 2 items).
5. BOUNDING BOXES: Provide [ymin, xmin, ymax, xmax] normalized (0-1000).
6. TOTALS CONSISTENCY: "meal_totals" MUST be the exact sum of all "nutrition_total" values.

Required JSON schema (strict):
{
  "scan_id": "<uuid>",
  "timestamp": "<ISO8601>",
  "meal_type": "breakfast|lunch|dinner|snack|unknown",
  "overall_confidence": "high|medium|low",
  "items": [
    {
      "item_id": "<uuid>",
      "name": "<string>",
      "usda_search_term": "<string>",
      "bounding_box_2d": [<ymin>, <xmin>, <ymax>, <xmax>],
      "estimated_grams": <number>,
      "visual_dimensions": { "est_area_cm2": <number>, "est_height_cm": <number> },
      "confidence": "high|medium|low",
      "state": "cooked|raw|processed|unknown",
      "cooking_method": "grilled|fried|boiled|baked|raw|unknown",
      "nutrition_per_100g": {
        "calories": <number>, "protein_g": <number>, "carbohydrates_g": <number>, "fat_g": <number>, "fiber_g": <number>
      },
      "nutrition_total": {
        "calories": <number>, "protein_g": <number>, "carbohydrates_g": <number>, "fat_g": <number>, "fiber_g": <number>
      }
    }
  ],
  "meal_totals": {
    "calories": <number>, "protein_g": <number>, "carbohydrates_g": <number>, "fat_g": <number>, "fiber_g": <number>
  },
  "volumetric_calibration": {
    "plate_diameter_cm": <number|null>,
    "anchor_object": "plate|fork|hand|spoon|knife|other|null",
    "method": "plate_size|cutlery|hand|barcode|manual|unknown"
  }
}`;

class AnalyzerService {
  constructor() {
    if (!process.env.GEMINI_API_KEY) {
      throw new Error('GEMINI_API_KEY is not defined in environment variables');
    }
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    this.model = this.genAI.getGenerativeModel({
      model: GEMINI_MODEL,
      generationConfig: { temperature: 0 },
    });
  }

  /**
   * Analyze one or more food images and return structured nutritional data.
   * @param {string[]} imagesBase64 - Array of Base64-encoded image data
   * @param {string} mimeType       - Image MIME type
   * @returns {Promise<object>}     - Parsed Gemini response matching the output schema
   */
  async analyzeCapture(imagesBase64, mimeType = 'image/jpeg') {
    const startTime = Date.now();

    const isMultiAngle = imagesBase64.length > 1;
    let prompt = ANALYSIS_PROMPT;

    if (isMultiAngle) {
      prompt = `MULTI-ANGLE ASSESSMENT MODE:
You are provided with ${imagesBase64.length} images of the same meal from different angles.
Use all available perspectives to:
1. Better resolve obscured or overlapping items.
2. Refine volume estimates (depth/height) by comparing different viewpoints.
3. Improve material/texture recognition.

${ANALYSIS_PROMPT}`;
    }

    const parts = [
      prompt,
      ...imagesBase64.map(data => ({
        inlineData: {
          data,
          mimeType,
        },
      })),
    ];

    const result = await this.model.generateContent(parts);

    const latencyMs = Date.now() - startTime;
    const rawText = result.response.text();

    let parsed;
    try {
      // Strip any accidental markdown fences Gemini might emit
      const cleaned = rawText.replace(/^```json\s*/i, '').replace(/```\s*$/, '').trim();
      parsed = JSON.parse(cleaned);
    } catch {
      const err = new Error('ERR_SCHEMA_INVALID: Gemini response could not be parsed as JSON');
      err.code = 'ERR_SCHEMA_INVALID';
      err.rawResponse = rawText;
      throw err;
    }

    // Surface Gemini-reported analysis errors
    if (parsed.error) {
      const err = new Error(`${parsed.error}: Visual analysis could not be completed`);
      err.code = parsed.error;
      err.status = 422;
      throw err;
    }

    // Post-processing: clamp unrealistic mass estimates and recalculate nutrition
    if (parsed.items && parsed.items.length > 0) {
      AnalyzerService._clampItemMasses(parsed);
    }

    return { ...parsed, analysisLatencyMs: latencyMs };
  }

  /**
   * Clamp item masses to realistic maximums and recalculate nutrition totals.
   */
  static _clampItemMasses(parsed) {
    for (const item of parsed.items) {
      const name = (item.name || '').toLowerCase();
      let maxGrams = null;

      for (const category of Object.values(MASS_CLAMPS)) {
        if (category.keywords.some(kw => name.includes(kw))) {
          maxGrams = category.max;
          break;
        }
      }

      if (maxGrams !== null && item.estimated_grams > maxGrams) {
        const ratio = maxGrams / item.estimated_grams;
        item.estimated_grams = maxGrams;

        // Scale nutrition_total proportionally
        if (item.nutrition_total) {
          for (const key of Object.keys(item.nutrition_total)) {
            item.nutrition_total[key] = +(item.nutrition_total[key] * ratio).toFixed(2);
          }
        }
      }
    }

    // Recalculate meal_totals from clamped items
    const totals = { calories: 0, protein_g: 0, carbohydrates_g: 0, fat_g: 0, fiber_g: 0 };
    for (const item of parsed.items) {
      if (item.nutrition_total) {
        for (const key of Object.keys(totals)) {
          totals[key] += item.nutrition_total[key] || 0;
        }
      }
    }
    // Round totals
    for (const key of Object.keys(totals)) {
      totals[key] = +totals[key].toFixed(2);
    }
    parsed.meal_totals = totals;
  }

  /**
   * Map Gemini's snake_case output to the Mongoose schema shape.
   */
  static mapToMealSchema(geminiData, userId, captureId) {
    const items = (geminiData.items || []).map((item) => {
      const nutritionPer100g = item.nutrition_per_100g || {};
      const nutritionTotal = item.nutrition_total || {};

      return {
        itemId: item.item_id || crypto.randomUUID(),
        name:            item.name,
        usdaSearchTerm:  item.usda_search_term,
        boundingBox2D:   item.bounding_box_2d || [],
        massGrams:       item.estimated_grams || 0,
        compositionConfidence: item.confidence || 'medium',
        preparationState:  item.state || 'unknown',
        cookingMethod:     item.cooking_method || 'unknown',
        nutritionPer100g: {
          calories:           nutritionPer100g.calories || 0,
          proteinGrams:       nutritionPer100g.protein_g || 0,
          carbohydratesGrams: nutritionPer100g.carbohydrates_g || 0,
          fatGrams:           nutritionPer100g.fat_g || 0,
          fiberGrams:         nutritionPer100g.fiber_g ?? 0,
        },
        nutritionTotal: {
          calories:           nutritionTotal.calories || 0,
          proteinGrams:       nutritionTotal.protein_g || 0,
          carbohydratesGrams: nutritionTotal.carbohydrates_g || 0,
          fatGrams:           nutritionTotal.fat_g || 0,
          fiberGrams:         nutritionTotal.fiber_g ?? 0,
        },
        alternativeCandidates: (item.alternatives || []).map((alt) => {
          const altNut = alt.nutrition_per_100g || {};
          return {
            name:           alt.name,
            usdaSearchTerm: alt.usda_search_term,
            nutritionPer100g: {
              calories:           altNut.calories || 0,
              proteinGrams:       altNut.protein_g || 0,
              carbohydratesGrams: altNut.carbohydrates_g || 0,
              fatGrams:           altNut.fat_g || 0,
              fiberGrams:         altNut.fiber_g ?? 0,
            },
          };
        }),
        verificationStatus: 'ai_verified',
      };
    });

    // If Gemini's meal_totals are missing, we compute them from items
    const totals = geminiData.meal_totals || items.reduce((acc, item) => {
      acc.calories += item.nutritionTotal.calories;
      acc.protein_g += item.nutritionTotal.proteinGrams;
      acc.carbohydrates_g += item.nutritionTotal.carbohydratesGrams;
      acc.fat_g += item.nutritionTotal.fatGrams;
      acc.fiber_g += item.nutritionTotal.fiberGrams;
      return acc;
    }, { calories: 0, protein_g: 0, carbohydrates_g: 0, fat_g: 0, fiber_g: 0 });

    const calibration = geminiData.volumetric_calibration || {};

    return {
      userId,
      captureId,
      caseFileId:        geminiData.scan_id || crypto.randomUUID(),
      mealType:          geminiData.meal_type || 'unknown',
      loggedAt:          new Date().toISOString(),
      overallConfidence: geminiData.overall_confidence || 'medium',
      detectedItems:     items,
      mealTotals: {
        calories:           totals.calories || 0,
        proteinGrams:       totals.protein_g || 0,
        carbohydratesGrams: totals.carbohydrates_g || 0,
        fatGrams:           totals.fat_g || 0,
        fiberGrams:         totals.fiber_g ?? 0,
      },
      volumetricAnchors: {
        estimatedPlateDiameterCm: calibration.plate_diameter_cm || null,
        anchorObjectDetected:     calibration.anchor_object || null,
        calibrationMethod:        calibration.method || 'unknown',
      },
      entryMethod: 'vision_capture',
    };
  }
}

module.exports = { AnalyzerService };
