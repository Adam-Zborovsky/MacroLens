const { GoogleGenerativeAI } = require('@google/generative-ai');
const crypto = require('crypto');

const GEMINI_MODEL = 'gemini-2.5-flash';

const ANALYSIS_PROMPT = `You are a professional nutritionist performing a forensic visual dietary assessment. Analyze the food in this image and return ONLY a valid JSON object — no preamble, no commentary, no markdown code fences.

Rules:
1. Identify ALL individual food components visible. Treat the image as a dataset to be solved.
2. Use plate size (~23–27cm), cutlery, or visible hands as volumetric anchors to estimate grams.
3. Distinguish raw vs cooked and identify cooking method where visible.
4. Report confidence per item: "high" (clear, well-lit, identifiable), "medium" (partially obscured or mixed dish), "low" (unclear).
5. Food names MUST be valid USDA FoodData Central search terms (e.g. "grilled chicken breast" not "BBQ chook").
6. For each item, provide 2–3 alternative candidates the AI considered.
7. Never fabricate nutritional values — use standard per-100g reference data.
8. If the image contains no recognizable food, return { "error": "ERR_NO_FOOD_DETECTED" }.
9. If the image is too obscured to analyze, return { "error": "ERR_VISUAL_OBSCURED" }.
10. ATOMIC DECONSTRUCTION (CRITICAL): You MUST deconstruct every dish into its constituent ingredients. NEVER group distinct foods into a single entry. 
    - Case A: One food is on top of another (e.g., cheese on toast). You MUST return TWO separate objects: one for "bread/toast" and one for "cheese".
    - Case B: Foods are mixed but distinguishable (e.g., a cobb salad). You MUST return separate objects for each major component (e.g., "egg", "bacon", "avocado", "lettuce").
    - Case C: Composite items (e.g., sandwich). You MUST return separate objects for "bread", "ham", "cheese", etc.
    This is critical for accurate macro tracking. Each item MUST have its own "bounding_box_2d" and "estimated_grams".
11. BOUNDING BOXES: Provide precise [ymin, xmin, ymax, xmax] coordinates for EACH atomic item. Coordinates must be normalized (0-1000).
12. TOTALS CONSISTENCY: Ensure the "meal_totals" object is the exact sum of all "nutrition_total" values from the "items" array.

Required JSON schema (strict — no additional fields):
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
      "confidence": "high|medium|low",
      "state": "cooked|raw|processed|unknown",
      "cooking_method": "grilled|fried|boiled|baked|raw|unknown",
      "alternatives": [
        {
          "name": "<string>",
          "usda_search_term": "<string>",
          "nutrition_per_100g": {
            "calories": <number>, "protein_g": <number>,
            "carbohydrates_g": <number>, "fat_g": <number>, "fiber_g": <number>
          }
        }
      ],
      "nutrition_per_100g": {
        "calories": <number>, "protein_g": <number>,
        "carbohydrates_g": <number>, "fat_g": <number>, "fiber_g": <number>
      },
      "nutrition_total": {
        "calories": <number>, "protein_g": <number>,
        "carbohydrates_g": <number>, "fat_g": <number>, "fiber_g": <number>
      }
    }
  ],
  "meal_totals": {
    "calories": <number>, "protein_g": <number>,
    "carbohydrates_g": <number>, "fat_g": <number>, "fiber_g": <number>
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
    this.model = this.genAI.getGenerativeModel({ model: GEMINI_MODEL });
  }

  /**
   * Analyze a food image and return structured nutritional data.
   * @param {string} imageBase64 - Base64-encoded image data
   * @param {string} mimeType    - Image MIME type
   * @returns {Promise<object>}  - Parsed Gemini response matching the output schema
   */
  async analyzeCapture(imageBase64, mimeType = 'image/jpeg') {
    const startTime = Date.now();

    const result = await this.model.generateContent([
      ANALYSIS_PROMPT,
      {
        inlineData: {
          data: imageBase64,
          mimeType,
        },
      },
    ]);

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

    return { ...parsed, analysisLatencyMs: latencyMs };
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
      mealType:          geminiData.meal_type || 'unknown',
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
