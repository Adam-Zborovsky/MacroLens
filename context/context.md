# MacroLens — Product & Engineering Source of Truth

> Use the product's domain language in component names, variable names, API endpoints, and user-facing strings. Code should clearly belong to THIS product. Production-grade means specific and well-crafted, not just functional.

---

## 🎯 Product Identity & Vision
**MacroLens** is a vision-first companion for the performance-driven individual that eliminates the "logging tax" of nutrition tracking. It transforms the camera into a high-speed analytical interface, using Gemini 2.5 Flash to convert a single photo into a verified, granular nutritional breakdown in under five seconds.

**Core Conviction**: Consistency in performance nutrition is a math problem that should be solved by machines, not by manual data entry. Tracking nutrition should take less time than eating it.

**Character**: A **High-Precision Lab Tool**. The product is technical, fast, and authoritative. It uses clinical, objective language ("Analyzing Composition," "Verifying Volumetric Data") rather than "cute" wellness terminology. The UI feels like a professional camera interface combined with a financial terminal—dense, organized, and optimized for utility.

---

## 🧩 Feature Specification

### 1. Photo Meal Analysis (Core)
The camera interface with "Active Bounding Boxes." Estimates volume based on physical anchors (plate size, cutlery). Success triggers a "Verified" badge. Users can confirm or adjust individual items before logging.

### 2. Detective UI (Item Detection & Correction)
Bottom-sheet refinement modal. Features a "Notched Haptic Slider" (5g clicks) for precision weight adjustment. Odometer-style rolling numbers for macro updates.
- **Alternatives List**: Tapping an item reveals alternatives considered by the AI (e.g., Grilled Chicken → Turkey Breast).
- **Manual Entry Fallback**: Free-text input triggers a secondary AI call to find the closest USDA-valid food name.
- **Custom Values**: Last-resort manual entry for calories/macros.

### 3. Macro & Micro Dashboard
Data-dense terminal showing "Progress Rings" (Calories, Protein, Carbs, Fat) and a "Micro-Grid" heat-map (Sodium, Iron, Calcium, Vitamins). Shows meal-by-meal timeline and trends.

### 4. Meal History & Log (The "Case File" Archive)
Every analyzed meal is saved with the original photo, identified items, quantities, nutritional data, and user corrections. Searchable forensic log.

### 5. Personalized Nutrition Goals
Goals based on body stats and activity level. Contextualizes the dashboard (e.g., "80% of protein goal hit").

### 6. Smart Meal Suggestions
Lightweight nudges based on remaining macros (e.g., "You're 40g of protein short, consider a high-protein snack").

### 7. Water & Hydration Tracking
Manual water logging integrated into the daily dashboard with optional reminders.

### 8. Barcode Scanner
For packaged foods, scans pull data from Open Food Facts.

### 9. Restaurant Mode
Search restaurants/dishes for estimated macros powered by Nutritionix.

### 10. Progress & Insights
Weight tracking, body measurements, progress photos, and weekly digests of intake patterns.

### 11. Export & Integrations
CSV/PDF report exports; Apple Health / Google Fit sync.

---

## 🧠 AI Analysis & Prompting Strategy

### The Stack
- **Vision Model**: Gemini 2.5 Flash (multimodal) — handles food identification and portion estimation.
- **Nutrition Database**: USDA FoodData Central — authoritative, verified nutritional data (300K+ items).

### Prompting Principles
1. **Professional Role**: Act as a professional nutritionist performing a visual dietary assessment.
2. **Multi-Item Awareness**: Treat every image as potentially containing multiple food items.
3. **Portion Anchors**: Use plate size (23-27cm) and visible objects (hands, cutlery) to anchor volume.
4. **State of Food**: Distinguish between raw vs. cooked and cooking methods (grilled vs. fried).
5. **Confidence Reporting**: High/Medium/Low confidence per item.
6. **USDA-Safe Naming**: Output names must be valid USDA search terms (e.g., "beef burger" not "Big Mac").
7. **Structured JSON**: Enforcement of a strict schema with no preamble or commentary.

---

## 📦 Output Data Schema

```json
{
  "scan_id": "uuid",
  "timestamp": "ISO8601",
  "meal_type": "breakfast | lunch | dinner | snack | unknown",
  "overall_confidence": "high | medium | low",
  "items": [
    {
      "item_id": "uuid",
      "name": "string",
      "usda_search_term": "string",
      "usda_food_id": "string",
      "estimated_grams": 150,
      "confidence": "high | medium | low",
      "state": "cooked | raw | processed | unknown",
      "cooking_method": "grilled | fried | boiled | baked | raw | unknown",
      "alternatives": [
        {
          "name": "string",
          "usda_search_term": "string",
          "nutrition_per_100g": { ... }
        }
      ],
      "nutrition_per_100g": {
        "calories": 0, "protein_g": 0, "carbohydrates_g": 0, "fat_g": 0, "fiber_g": 0
      },
      "nutrition_total": { ... }
    }
  ],
  "meal_totals": { "calories": 0, "protein_g": 0, "carbohydrates_g": 0, "fat_g": 0 }
}
```

---

## 🛠️ Engineering Standards
- **Validation**: Strict schema validation using Zod for all API payloads and Mongoose for persistence.
- **Error Handling**: Clinical product voice (e.g., `ERR_VISUAL_OBSCURED: Subject matter unrecognizable`).
- **API Conventions**: Endpoints use domain vocabulary: `/api/v1/captures`, `/api/v1/meals/case-files`, `/api/v1/goals/phases`.
- **Security**: Pre-signed URLs for image uploads; metabolic metrics encrypted at rest.

### Tech Stack
- **Backend**: Node.js/Express (High-speed asynchronous handling).
- **Frontend**: Flutter (High-precision haptics and real-time AR "Detective Overlays").
- **AI**: Gemini 2.5 Flash.
- **Database**: MongoDB (Flexible storage for "Case Files").

### Architecture (Mobile)
```
macro_lens_mobile/
  lib/
    features/
      camera_vision/           # Viewfinder, AR bounding boxes
      detective_refinement/    # Bottom-sheet, haptic sliders
      nutrition_dashboard/     # Progress rings, macro-donuts
      meal_history/            # "Case File" views, photo timeline
      goal_engine/             # Phase selection, TDEE math
```
