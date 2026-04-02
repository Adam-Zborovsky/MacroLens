const { GoogleGenerativeAI } = require('@google/generative-ai');
const crypto = require('crypto');

const GEMINI_MODEL = 'gemini-2.5-flash';

const ANALYSIS_PROMPT = `You are a professional nutritionist performing a forensic visual dietary assessment. Analyze the food in this image and return ONLY a valid JSON object — no preamble, no commentary, no markdown code fences.

Rules:
1. Identify ALL food items visible. Treat the image as a dataset to be solved.
2. Use plate size (~23–27cm), cutlery, or visible hands as volumetric anchors to estimate grams.
3. Distinguish raw vs cooked and identify cooking method where visible.
4. Report confidence per item: "high" (clear, well-lit, identifiable), "medium" (partially obscured or mixed dish), "low" (unclear).
5. Food names MUST be valid USDA FoodData Central search terms (e.g. "grilled chicken breast" not "BBQ chook").
6. For each item, provide 2–3 alternative candidates the AI considered.
7. Never fabricate nutritional values — use standard per-100g reference data.
8. If the image contains no recognizable food, return { "error": "ERR_NO_FOOD_DETECTED" }.
9. If the image is too obscured to analyze, return { "error": "ERR_VISUAL_OBSCURED" }.

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
    "carbohydrates_g": <number>, "fat_g": <number>
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
    const items = geminiData.items.map((item) => ({
      itemId: item.item_id || crypto.randomUUID(),
      name:            item.name,
      usdaSearchTerm:  item.usda_search_term,
      massGrams:       item.estimated_grams,
      compositionConfidence: item.confidence,
      preparationState:  item.state,
      cookingMethod:     item.cooking_method,
      nutritionPer100g: {
        calories:           item.nutrition_per_100g.calories,
        proteinGrams:       item.nutrition_per_100g.protein_g,
        carbohydratesGrams: item.nutrition_per_100g.carbohydrates_g,
        fatGrams:           item.nutrition_per_100g.fat_g,
        fiberGrams:         item.nutrition_per_100g.fiber_g ?? 0,
      },
      nutritionTotal: {
        calories:           item.nutrition_total.calories,
        proteinGrams:       item.nutrition_total.protein_g,
        carbohydratesGrams: item.nutrition_total.carbohydrates_g,
        fatGrams:           item.nutrition_total.fat_g,
        fiberGrams:         item.nutrition_total.fiber_g ?? 0,
      },
      alternativeCandidates: (item.alternatives || []).map((alt) => ({
        name:           alt.name,
        usdaSearchTerm: alt.usda_search_term,
        nutritionPer100g: {
          calories:           alt.nutrition_per_100g.calories,
          proteinGrams:       alt.nutrition_per_100g.protein_g,
          carbohydratesGrams: alt.nutrition_per_100g.carbohydrates_g,
          fatGrams:           alt.nutrition_per_100g.fat_g,
          fiberGrams:         alt.nutrition_per_100g.fiber_g ?? 0,
        },
      })),
      verificationStatus: 'ai_verified',
    }));

    const totals = geminiData.meal_totals;

    return {
      userId,
      captureId,
      mealType:          geminiData.meal_type,
      overallConfidence: geminiData.overall_confidence,
      detectedItems:     items,
      mealTotals: {
        calories:           totals.calories,
        proteinGrams:       totals.protein_g,
        carbohydratesGrams: totals.carbohydrates_g,
        fatGrams:           totals.fat_g,
        fiberGrams:         0,
      },
      entryMethod: 'vision_capture',
    };
  }
}

module.exports = { AnalyzerService };
